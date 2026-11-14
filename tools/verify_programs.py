#!/usr/bin/env python3
"""Verify Solo's three universal programs without loading or executing them.

stdlib only; Python 3.8+ on Linux/macOS. Exit 0 = all static checks and any
available macOS codesign checks passed; 1 = invalid input; 2 = CLI/output error.
This checks integrity, not CMS trust, execution, or the whole preference bundle.
"""
import argparse
import bz2
import gzip
import hashlib
import io
import json
import lzma
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import uuid

PROGRAMS = (
    "Library/MobileSubstrate/DynamicLibraries/Solo.dylib",
    "Library/MobileSubstrate/DynamicLibraries/SoloEnhancements.dylib",
    "Library/PreferenceBundles/SoloPrefs.bundle/SoloPrefs",
)
MAX_ARCHIVE = 256 * 1024 * 1024
MAX_TAR = 512 * 1024 * 1024
MAX_PROGRAM = 64 * 1024 * 1024
CPU = 0x0100000C
SUBTYPES = {0: "arm64", 0x80000002: "arm64e"}
# dyld's mach-o/fixup-chains.h; also LLVM BinaryFormat/MachO.h.
# 6 is DYLD_CHAINED_PTR_64_OFFSET and is NOT an ARM64E encoding.
POINTER_FORMATS = {1: "ARM64E", 2: "64", 6: "64_OFFSET",
                   7: "ARM64E_KERNEL", 9: "ARM64E_USERLAND",
                   10: "ARM64E_FIRMWARE", 12: "ARM64E_USERLAND24"}
ARM64E_FORMATS = {1, 7, 9, 10, 12}
FORMAT_REFERENCE = "https://codebrowser.dev/llvm/llvm/include/llvm/BinaryFormat/MachO.h.html"


class Invalid(ValueError):
    pass


def need(ok, message):
    if not ok:
        raise Invalid(message)


def span(total, offset, size, label):
    need(0 <= offset <= total and 0 <= size <= total - offset,
         label + ": range outside enclosing data")


def unpack(fmt, data, offset=0):
    span(len(data), offset, struct.calcsize(fmt), "structure " + fmt)
    return struct.unpack_from(fmt, data, offset)


def disjoint(ranges, label):
    previous = 0
    for start, end in sorted((a, b) for a, b in ranges if a != b):
        need(start >= previous and end >= start, label + ": overlapping ranges")
        previous = end


def textz(data, offset, end, label):
    need(0 <= offset < end <= len(data), label + ": invalid string offset")
    last = data.find(b"\0", offset, end)
    need(last >= 0, label + ": unterminated string")
    try:
        return data[offset:last].decode("utf-8"), last + 1
    except UnicodeError as exc:
        raise Invalid(label + ": invalid UTF-8") from exc


def sha(data):
    return hashlib.sha256(data).hexdigest()


def parse_ar(data):
    need(data[:8] == b"!<arch>\n", "deb: missing ar magic")
    pos, names, longnames = 8, {}, b""
    while pos < len(data):
        span(len(data), pos, 60, "ar header")
        h = data[pos:pos + 60]
        need(h[58:] == b"`\n", "ar: invalid header trailer")
        try:
            name = h[:16].decode("ascii").rstrip(" ")
            field = h[48:58].strip()
            need(field and field.isdigit(), "ar: invalid member size")
            size = int(field)
        except UnicodeError as exc:
            raise Invalid("ar: non-ASCII member name") from exc
        pos += 60
        span(len(data), pos, size, "ar member")
        payload = data[pos:pos + size]
        pos += size
        if size & 1:
            need(data[pos:pos + 1] == b"\n", "ar: invalid alignment padding")
            pos += 1
        if name == "//":
            need(not longnames, "ar: duplicate long name table")
            longnames = payload
            continue
        if name.startswith("#1/"):
            need(name[3:].isdigit(), "ar: invalid BSD name length")
            n = int(name[3:])
            span(len(payload), 0, n, "ar BSD name")
            try:
                name = payload[:n].rstrip(b"\0").decode("ascii")
            except UnicodeError as exc:
                raise Invalid("ar: invalid BSD name") from exc
            payload = payload[n:]
        elif name.startswith("/") and name[1:].isdigit():
            offset = int(name[1:])
            need(offset < len(longnames), "ar: missing GNU long name")
            end = longnames.find(b"/\n", offset)
            need(end >= 0, "ar: unterminated GNU long name")
            try:
                name = longnames[offset:end].decode("ascii")
            except UnicodeError as exc:
                raise Invalid("ar: invalid GNU name") from exc
        else:
            name = name.rstrip("/")
        need(name and "/" not in name and "\\" not in name and "\0" not in name,
             "ar: unsafe member name")
        need(name not in names, "ar: duplicate member " + name)
        names[name] = payload
    return names


def safe_path(name):
    need(len(name) <= 4096 and not name.startswith("/") and
         "\\" not in name and "\0" not in name, "tar: unsafe path " + repr(name))
    parts = name.split("/")
    need(".." not in parts, "tar: parent traversal " + repr(name))
    return "/".join(p for p in parts if p not in ("", "."))


def read_tar(member_name, payload):
    codecs = {".gz": gzip.GzipFile, ".xz": lzma.LZMAFile, ".bz2": bz2.BZ2File}
    suffix = next((x for x in codecs if member_name.endswith(".tar" + x)), None)
    if suffix:
        source = io.BytesIO(payload)
        stream = (gzip.GzipFile(fileobj=source, mode="rb") if suffix == ".gz"
                  else codecs[suffix](source, "rb"))
        with stream:
            raw = stream.read(MAX_TAR + 1)
        need(len(raw) <= MAX_TAR, "tar: decompression size limit exceeded")
    else:
        need(member_name.endswith(".tar"), "unsupported deb compression: " + member_name)
        raw = payload
    need(len(raw) <= MAX_TAR and len(raw) >= 1024 and len(raw) % 512 == 0,
         "tar: invalid archive size")
    result = {}
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
        for index, entry in enumerate(archive):
            need(index < 10000, "tar: too many entries")
            name = safe_path(entry.name)
            need(name not in result, "tar: duplicate normalized path " + name)
            need(entry.isdir() or entry.isfile(), "tar: links/devices/unsupported entry " + name)
            need(not getattr(entry, "sparse", None), "tar: sparse files unsupported")
            if not name:
                need(entry.isdir(), "tar: empty regular file name")
            span(len(raw), entry.offset_data, entry.size, "tar member " + name)
            if entry.isfile():
                need(entry.size <= MAX_PROGRAM, "tar: file too large " + name)
                # Direct byte read avoids all filesystem extraction and link following.
                result[name] = raw[entry.offset_data:entry.offset_data + entry.size]
            else:
                need(entry.size == 0, "tar: directory has payload")
                result[name] = None
        need(len(raw) - archive.offset >= 1024 and not any(raw[archive.offset:]),
             "tar: missing end blocks or nonzero trailing data")
    for name in result:
        parts = name.split("/")
        for n in range(1, len(parts)):
            parent = "/".join(parts[:n])
            need(parent not in result or result[parent] is None,
                 "tar: regular file used as directory " + parent)
    return result


def read_deb(data):
    ar = parse_ar(data)
    need(ar.get("debian-binary") == b"2.0\n", "deb: unsupported debian-binary")
    contents = {}
    for base in ("control", "data"):
        matches = [n for n in ar if n == base + ".tar" or n.startswith(base + ".tar.")]
        need(len(matches) == 1, "deb: expected one " + base + " archive")
        contents[base] = read_tar(matches[0], ar[matches[0]])
    need(isinstance(contents["control"].get("control"), bytes), "deb: missing control file")
    files = contents["data"]
    for path in PROGRAMS:
        need(isinstance(files.get(path), bytes), "deb: missing regular program " + path)
    return files


def code_directory(cd, image, signature_offset, blobs, external):
    magic, length, version, flags, hoff, ident, ns, nc, limit = unpack(">9I", cd)
    need(magic == 0xFADE0C02 and length == len(cd), "CodeDirectory: invalid header")
    need(0x20000 <= version <= 0x20600, "CodeDirectory: unsupported version")
    header = 44
    for since, size in ((0x20100, 48), (0x20200, 52), (0x20300, 64),
                        (0x20400, 88), (0x20500, 96), (0x20600, 108)):
        if version >= since:
            header = size
    span(len(cd), 0, header, "CodeDirectory header")
    hs, ht, platform, exponent = unpack("4B", cd, 36)
    algorithms = {1: (hashlib.sha1, 20, "SHA1"), 2: (hashlib.sha256, 32, "SHA256"),
                  3: (hashlib.sha256, 20, "SHA256_TRUNCATED")}
    need(ht in algorithms, "CodeDirectory: unsupported hash type " + str(ht))
    hf, expected_size, hash_name = algorithms[ht]
    need(hs == expected_size, "CodeDirectory: incorrect hash size")
    need(unpack(">I", cd, 40)[0] == 0, "CodeDirectory: nonzero spare2")
    if version >= 0x20100:
        need(unpack(">I", cd, 44)[0] == 0, "CodeDirectory: scatter vectors unsupported")
    if version >= 0x20300:
        spare, limit64 = unpack(">IQ", cd, 52)
        need(spare == 0, "CodeDirectory: nonzero spare3")
        if limit == 0xFFFFFFFF:
            need(limit64 > 0xFFFFFFFF, "CodeDirectory: invalid extended codeLimit")
            limit = limit64
        else:
            need(limit64 in (0, limit), "CodeDirectory: contradictory codeLimit64")
    need(0 < limit == signature_offset, "CodeDirectory: codeLimit must cover every byte before signature")
    need(0 <= exponent <= 30, "CodeDirectory: invalid page size exponent")
    page_size = (1 << exponent) if exponent else limit  # 0 means one unpaged slot.
    need(nc == (limit + page_size - 1) // page_size, "CodeDirectory: nCodeSlots/codeLimit mismatch")
    need(ns <= 4096, "CodeDirectory: unreasonable special slot count")
    first = hoff - ns * hs
    need(first >= header, "CodeDirectory: hashes overlap header")
    span(len(cd), first, (ns + nc) * hs, "CodeDirectory hash table")
    need(header <= ident < first, "CodeDirectory: identifier overlaps hashes")
    identifier, end = textz(cd, ident, first, "CodeDirectory identifier")
    need(identifier, "CodeDirectory: empty identifier")
    metadata = [(ident, end)]
    team = None
    if version >= 0x20200:
        team_offset = unpack(">I", cd, 48)[0]
        if team_offset:
            need(header <= team_offset < first, "CodeDirectory: invalid team offset")
            team, end = textz(cd, team_offset, first, "CodeDirectory team")
            metadata.append((team_offset, end))
    disjoint(metadata, "CodeDirectory strings")
    if version >= 0x20400:
        base, size, exec_flags = unpack(">3Q", cd, 64)
        span(limit, base, size, "CodeDirectory executable region")
    if version >= 0x20500:
        need(unpack(">I", cd, 92)[0] == 0, "CodeDirectory: pre-encryption hashes unsupported")
    if version >= 0x20600:
        need(not any(cd[96:108]), "CodeDirectory: linkage hashes unsupported")
    for index in range(nc):
        actual = hf(image[index * page_size:min((index + 1) * page_size, limit)]).digest()[:hs]
        expected = cd[hoff + index * hs:hoff + (index + 1) * hs]
        need(actual == expected, "CodeDirectory: code page hash mismatch at page " + str(index))
    special = []
    for slot in blobs:
        if 0 < slot < 0x1000:
            need(slot <= ns, "CodeDirectory: embedded special blob has no hash slot " + str(slot))
    for slot in range(1, ns + 1):
        expected = cd[hoff - slot * hs:hoff - (slot - 1) * hs]
        blob = blobs.get(slot)
        source = "embedded_blob"
        if blob is None and slot in external:
            blob = external[slot]
            source = "deb_external_file"
        if blob is not None:
            # An unsealed Info.plist is allowed, but must not be claimed verified.
            if not any(expected) and source == "deb_external_file":
                special.append({"slot": slot, "status": "unsealed", "source": source})
                continue
            need(hf(blob).digest()[:hs] == expected,
                 "CodeDirectory: special slot hash mismatch at slot " + str(slot))
            special.append({"slot": slot, "status": "verified", "source": source})
        else:
            need(not any(expected), "CodeDirectory: sealed special slot data missing at slot " + str(slot))
            special.append({"slot": slot, "status": "absent_unsealed"})
    info_sealed = any(s["slot"] == 1 and s["status"] == "verified" for s in special)
    return {"version": hex(version), "flags": hex(flags), "identifier": identifier,
            "team_identifier": team, "hash_type": ht, "hash_name": hash_name,
            "hash_size": hs, "code_limit": limit, "page_size_exponent": exponent,
            "page_size": page_size if exponent else "unpaged", "code_pages_verified": nc,
            "special_slots": special, "info_plist_sealed_and_verified": info_sealed,
            "sha256": sha(cd), "cdhash": hf(cd).digest()[:20].hex()}


def verify_signature(image, offset, size, external):
    span(len(image), offset, size, "LC_CODE_SIGNATURE")
    need(size >= 12 and offset % 16 == 0 and offset + size == len(image),
         "LC_CODE_SIGNATURE: signature must be aligned and at slice end")
    data = image[offset:offset + size]
    magic, length, count = unpack(">3I", data)
    need(magic == 0xFADE0CC0, "signature: expected embedded SuperBlob")
    need(12 <= length <= size and 0 < count <= (length - 12) // 8,
         "SuperBlob: invalid length/count")
    need(not any(data[length:]), "SuperBlob: nonzero signature allocation padding")
    index_end = 12 + count * 8
    blobs, ranges = {}, [(0, index_end)]
    for i in range(count):
        kind, pos = unpack(">2I", data, 12 + i * 8)
        need(kind not in blobs and pos >= index_end, "SuperBlob: duplicate slot or index overlap")
        span(length, pos, 8, "SuperBlob child header")
        child_magic, child_size = unpack(">2I", data, pos)
        need(child_size >= 8, "SuperBlob: invalid child length")
        span(length, pos, child_size, "SuperBlob child")
        if kind == 0 or 0x1000 <= kind < 0x1005:
            need(child_magic == 0xFADE0C02, "SuperBlob: invalid CodeDirectory magic")
        else:
            need(child_magic != 0xFADE0C02, "SuperBlob: misplaced CodeDirectory")
        expected_magic = {2: 0xFADE0C01, 5: 0xFADE7171, 7: 0xFADE7172, 0x10000: 0xFADE0B01}
        if kind in expected_magic:
            need(child_magic == expected_magic[kind], "SuperBlob: invalid special blob magic")
        blobs[kind] = data[pos:pos + child_size]
        ranges.append((pos, pos + child_size))
    disjoint(ranges, "SuperBlob children")
    need(0 in blobs, "signature: missing primary CodeDirectory")
    directories = []
    for kind, blob in sorted(blobs.items()):
        if kind == 0 or 0x1000 <= kind < 0x1005:
            result = code_directory(blob, image, offset, blobs, external)
            result["slot"] = kind
            directories.append(result)
    cms = blobs.get(0x10000)
    return {"offset": offset, "allocated_size": size, "superblob_length": length,
            "blob_slots": sorted(blobs), "code_directories": directories,
            "code_pages_verified": sum(x["code_pages_verified"] for x in directories),
            "cms": "present_not_cryptographically_verified" if cms and len(cms) > 8 else "absent_or_empty_ad_hoc",
            "whole_bundle_verified": False}


def verify_fixups(image, offset, size, segments, subtype):
    span(len(image), offset, size, "LC_DYLD_CHAINED_FIXUPS")
    data = image[offset:offset + size]
    version, starts, imports, symbols, count, impfmt, symfmt = unpack("<7I", data)
    need(version == 0, "fixups: unsupported header version")
    need(impfmt in (1, 2, 3) and symfmt == 0,
         "fixups: unsupported imports or compressed symbols format")
    need(28 <= starts < imports <= symbols <= len(data), "fixups: invalid header offsets")
    stride = {1: 4, 2: 8, 3: 16}[impfmt]
    span(symbols, imports, count * stride, "fixups imports")
    seg_count = unpack("<I", data, starts)[0]
    need(seg_count == len(segments), "fixups: segment count mismatch")
    span(imports, starts + 4, seg_count * 4, "fixups segment table")
    table_end = starts + 4 + seg_count * 4
    for index in range(count):
        raw = unpack("<Q" if impfmt == 3 else "<I", data, imports + index * stride)[0]
        if impfmt == 3:
            need(((raw >> 17) & 0x7FFF) == 0, "fixups: reserved import bits")
        name_offset = (raw >> 32) if impfmt == 3 else (raw >> 9)
        textz(data, symbols + name_offset, len(data), "fixups import name")
    bases = [s["vmaddr"] for s in segments if s["fileoff"] == 0 and s["filesize"]]
    need(len(bases) == 1, "fixups: ambiguous image base")
    base = bases[0]
    records, formats, regions, chain_count, pointer_count = [], set(), [], 0, 0
    for index, segment in enumerate(segments):
        relative = unpack("<I", data, starts + 4 + index * 4)[0]
        if relative == 0:
            continue
        pos = starts + relative
        need(pos >= table_end, "fixups: segment record overlaps table")
        span(imports, pos, 22, "fixups segment record")
        length, page_size, fmt, seg_offset, max_valid, pages = unpack("<IHHQIH", data, pos)
        need(length >= 22 + 2 * pages and length % 2 == 0,
             "fixups: invalid starts_in_segment size")
        span(imports, pos, length, "fixups segment record")
        regions.append((pos, pos + length))
        need(page_size in (4096, 16384), "fixups: invalid page size")
        need(fmt in POINTER_FORMATS, "fixups: unsupported pointer format " + str(fmt))
        allowed = ARM64E_FORMATS if subtype == 0x80000002 else {2, 6}
        need(fmt in allowed, "fixups: pointer_format " + str(fmt) + " incompatible with " + SUBTYPES[subtype])
        need(max_valid == 0, "fixups: max_valid_pointer must be zero for 64-bit pointers")
        need(seg_offset == segment["vmaddr"] - base, "fixups: segment_offset mismatch")
        need(0 < pages <= (segment["vmsize"] + page_size - 1) // page_size,
             "fixups: page count outside segment")
        entries = (length - 22) // 2
        values = unpack("<" + str(entries) + "H", data, pos + 22)
        used, chains_here, pointers_here = set(), 0, 0
        pointer_stride = 8 if fmt in (1, 9, 12) else 4
        for page in range(pages):
            first = values[page]
            if first == 0xFFFF:
                continue
            chain_starts = [first]
            if first & 0x8000:
                k = first & 0x7FFF
                need(k >= pages, "fixups: multi-start points into page table")
                chain_starts = []
                while True:
                    need(k < entries, "fixups: unterminated multi-start overflow")
                    value = values[k]
                    chain_starts.append(value & 0x7FFF)
                    k += 1
                    if value & 0x8000:
                        break
            for first in chain_starts:
                need(first < page_size and first % pointer_stride == 0,
                     "fixups: invalid chain page start")
                at = first
                chains_here += 1
                while True:
                    need(at + 8 <= page_size, "fixups: pointer crosses page boundary")
                    relative_file = page * page_size + at
                    span(segment["filesize"], relative_file, 8, "fixups pointer in segment")
                    file_at = segment["fileoff"] + relative_file
                    need(file_at not in used, "fixups: intersecting pointer chains")
                    used.add(file_at)
                    raw = unpack("<Q", image, file_at)[0]
                    if fmt in ARM64E_FORMATS:
                        bind = (raw >> 62) & 1
                        following = (raw >> 51) & 0x7FF
                        ordinal_bits = 24 if fmt == 12 else 16
                        if bind:
                            ordinal = raw & ((1 << ordinal_bits) - 1)
                            zero = (raw >> ordinal_bits) & ((1 << (32 - ordinal_bits)) - 1)
                            need(zero == 0, "fixups: nonzero ARM64E bind reserved bits")
                    else:
                        bind = raw >> 63
                        following = (raw >> 51) & 0xFFF
                        ordinal = raw & 0xFFFFFF
                        if bind:
                            need(((raw >> 32) & 0x7FFFF) == 0, "fixups: nonzero 64 bind reserved bits")
                        else:
                            need(((raw >> 44) & 0x7F) == 0, "fixups: nonzero 64 rebase reserved bits")
                    if bind:
                        need(ordinal < count, "fixups: bind ordinal outside imports")
                    pointers_here += 1
                    if not following:
                        break
                    at += following * pointer_stride
        formats.add(fmt)
        chain_count += chains_here
        pointer_count += pointers_here
        records.append({"segment": segment["name"], "page_size": page_size,
                        "page_count": pages, "pointer_format": fmt,
                        "pointer_format_name": POINTER_FORMATS[fmt],
                        "chains_checked": chains_here, "pointers_checked": pointers_here})
    disjoint(regions, "fixups segment records")
    if subtype == 0x80000002:
        need(formats and chain_count > 0 and pointer_count > 0,
             "fixups: arm64e needs actual ARM64E pointer chains")
    return {"offset": offset, "size": size, "version": version, "imports_count": count,
            "imports_format": impfmt, "symbols_format": symfmt,
            "pointer_formats": sorted(formats), "segments": records,
            "chains_checked": chain_count, "pointers_checked": pointer_count}


def verify_slice(image, subtype, external):
    magic, cpu, sub, filetype, ncmds, sizeofcmds, flags, reserved = unpack("<8I", image)
    need(magic == 0xFEEDFACF and cpu == CPU and sub == subtype,
         "Mach-O: header CPU/subtype differs from fat table (ABI bits included)")
    need(filetype in (6, 8) and reserved == 0, "Mach-O: expected dylib or bundle header")
    span(len(image), 32, sizeofcmds, "Mach-O load commands")
    need(0 < ncmds <= sizeofcmds // 8, "Mach-O: invalid ncmds")
    end, pos = 32 + sizeofcmds, 32
    segments, deps, uuids, links = [], [], [], {}
    for _ in range(ncmds):
        span(end, pos, 8, "load command header")
        cmd, size = unpack("<II", image, pos)
        need(size >= 8 and size % 8 == 0, "Mach-O: invalid cmdsize/alignment")
        span(end, pos, size, "load command")
        if cmd == 0x19:  # LC_SEGMENT_64
            need(size >= 72, "segment: truncated command")
            name = image[pos + 8:pos + 24].split(b"\0")[0].decode("ascii", "replace")
            vm, vs, fo, fs, maxprot, initprot, nsects, segflags = unpack("<4Q4I", image, pos + 24)
            need(size == 72 + 80 * nsects, "segment: nsects/cmdsize mismatch")
            span(len(image), fo, fs, "segment " + name)
            need(fs <= vs and vm + vs <= 1 << 64, "segment: invalid VM size")
            section_files, section_vms = [], []
            for index in range(nsects):
                at = pos + 72 + index * 80
                secname = image[at:at + 16].split(b"\0")[0].decode("ascii", "replace")
                secseg = image[at + 16:at + 32].split(b"\0")[0].decode("ascii", "replace")
                addr, ss, so, align, reloc, nr, sf, r1, r2, r3 = unpack("<2Q8I", image, at + 32)
                label = "section " + name + "/" + secname
                need(secseg == name and align <= 30, label + ": segment name/alignment invalid")
                span(vs, addr - vm, ss, label + " VM")
                need(addr % (1 << align) == 0, label + ": unaligned VM address")
                section_vms.append((addr, addr + ss))
                if sf & 0xFF not in (1, 0xC, 0x12):  # zerofill has no file bytes
                    span(fs, so - fo, ss, label + " segment file")
                    span(len(image), so, ss, label + " file")
                    need(so % (1 << align) == 0, label + ": unaligned file offset")
                    section_files.append((so, so + ss))
                span(len(image), reloc, nr * 8, label + " relocations")
            disjoint(section_files, "section files in " + name)
            disjoint(section_vms, "section VMs in " + name)
            segments.append({"name": name, "vmaddr": vm, "vmsize": vs,
                             "fileoff": fo, "filesize": fs, "section_count": nsects})
        elif cmd == 0x1B:
            need(size == 24, "LC_UUID: invalid size")
            uuids.append(str(uuid.UUID(bytes=image[pos + 8:pos + 24])))
        elif cmd in (0x1D, 0x80000034, 0x80000033, 0x26, 0x29, 0x1E, 0x2E):
            need(size == 16 and cmd not in links, "linkedit: invalid/duplicate command")
            off, length = unpack("<II", image, pos + 8)
            span(len(image), off, length, "linkedit data")
            need(not length or off >= end, "linkedit data overlaps load commands")
            links[cmd] = (off, length)
        elif cmd in (0xC, 0x80000018, 0x8000001F, 0x80000023, 0x20, 0xD):
            need(size >= 24, "dylib: truncated command")
            nameoff = unpack("<I", image, pos + 8)[0]
            need(24 <= nameoff < size, "dylib: invalid name offset")
            name, _ = textz(image, pos + nameoff, pos + size, "dylib name")
            if cmd != 0xD:
                deps.append({"name": name, "load_command": hex(cmd)})
        elif cmd == 0x2:  # LC_SYMTAB
            need(size == 24, "symtab: invalid command size")
            symoff, nsyms, stroff, strsize = unpack("<4I", image, pos + 8)
            span(len(image), symoff, nsyms * 16, "symbol table")
            span(len(image), stroff, strsize, "string table")
        elif cmd in (0x21, 0x2C):
            need(size >= 20, "encryption: truncated command")
            cryptoff, cryptsize, cryptid = unpack("<3I", image, pos + 8)
            span(len(image), cryptoff, cryptsize, "encrypted range")
            need(cryptid == 0, "encrypted programs unsupported")
        pos += size
    need(pos == end, "Mach-O: sizeofcmds/ncmds mismatch")
    need(len(uuids) == 1, "Mach-O: expected one UUID")
    need(segments and len({s["name"] for s in segments}) == len(segments),
         "Mach-O: missing/duplicate segments")
    disjoint([(s["fileoff"], s["fileoff"] + s["filesize"]) for s in segments], "segment files")
    disjoint([(s["vmaddr"], s["vmaddr"] + s["vmsize"]) for s in segments], "segment VMs")
    need(any(s["fileoff"] == 0 and s["filesize"] >= end for s in segments),
         "Mach-O: header/load commands not in file-backed segment")
    linkedit = [s for s in segments if s["name"] == "__LINKEDIT"]
    need(len(linkedit) == 1 and 0x1D in links, "Mach-O: missing __LINKEDIT/code signature")
    le = linkedit[0]
    for off, length in links.values():
        if length:
            span(le["filesize"], off - le["fileoff"], length, "linkedit segment containment")
    disjoint([(a, a + b) for a, b in links.values()], "linkedit commands")
    need(subtype != 0x80000002 or 0x80000034 in links, "arm64e: missing chained fixups")
    fixups = None
    if 0x80000034 in links:
        fixups = verify_fixups(image, *links[0x80000034], segments, subtype)
    signature = verify_signature(image, *links[0x1D], external)
    return {"architecture": SUBTYPES[subtype], "cpu_type": hex(cpu), "cpu_subtype": "0x%08x" % sub,
            "abi_high_bit_present": bool(sub & 0x80000000), "uuid": uuids[0],
            "file_type": filetype, "sha256": sha(image), "size": len(image),
            "load_commands": ncmds, "segments": segments, "dependencies": deps,
            "chained_fixups": fixups, "signature": signature, "success": True}


def verify_program(data, external=None):
    external = external or {}
    magic = data[:4]
    kinds = {b"\xca\xfe\xba\xbe": (">", False), b"\xbe\xba\xfe\xca": ("<", False),
             b"\xca\xfe\xba\xbf": (">", True), b"\xbf\xba\xfe\xca": ("<", True)}
    need(magic in kinds, "program: expected universal/fat Mach-O")
    endian, wide = kinds[magic]
    count = unpack(endian + "I", data, 4)[0]
    need(count == 2, "fat: expected exactly two architectures")
    entry_size = 32 if wide else 20
    table_end = 8 + count * entry_size
    span(len(data), 0, table_end, "fat architecture table")
    arches, ranges, subs = [], [], set()
    for i in range(count):
        values = unpack(endian + ("IIQQII" if wide else "5I"), data, 8 + i * entry_size)
        cpu, subtype, offset, size, align = values[:5]
        need(not wide or values[5] == 0, "fat64: nonzero reserved field")
        need(cpu == CPU and subtype in SUBTYPES and subtype not in subs,
             "fat: expected exact arm64 sub0 and arm64e sub0x80000002 including ABI high bit")
        subs.add(subtype)
        need(align <= 30 and offset >= table_end and offset % (1 << align) == 0 and size >= 32,
             "fat: invalid slice alignment/offset/size")
        span(len(data), offset, size, "fat slice")
        ranges.append((offset, offset + size))
        arches.append((subtype, offset, size, align))
    disjoint(ranges, "fat slices")
    results = []
    for subtype, offset, size, align in arches:
        try:
            result = verify_slice(data[offset:offset + size], subtype, external)
        except Invalid as exc:
            raise Invalid(SUBTYPES[subtype] + ": " + str(exc)) from exc
        result.update({"fat_offset": offset, "fat_alignment_exponent": align})
        results.append(result)
    return {"sha256": sha(data), "size": len(data), "slices": results, "success": True}


def apple_codesign(files):
    result = {"platform": sys.platform, "available": False, "performed": False,
              "status": "not_run_non_macos", "programs": {}}
    if sys.platform != "darwin":
        return result
    executable = shutil.which("codesign")
    if not executable:
        result["status"] = "not_run_codesign_unavailable"
        return result
    result.update({"available": True, "performed": True, "status": "passed"})
    with tempfile.TemporaryDirectory(prefix="solo-program-verifier-") as temporary:
        for name in PROGRAMS:
            # Isolate executable files: do not manufacture a sealed bundle context.
            target = Path(temporary) / Path(name).name
            target.write_bytes(files[name])
            target.chmod(0o600)
            command = [executable, "--verify", "--strict", "--all-architectures", str(target)]
            try:
                run = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     timeout=60, check=False)
                item = {"returncode": run.returncode,
                        "stdout": run.stdout[:65536].decode("utf-8", "replace"),
                        "stderr": run.stderr[:65536].decode("utf-8", "replace"),
                        "success": run.returncode == 0}
            except (OSError, subprocess.TimeoutExpired) as exc:
                item = {"error": str(exc), "success": False}
            item["arguments"] = ["--verify", "--strict", "--all-architectures", Path(name).name]
            result["programs"][name] = item
            if not item["success"]:
                result["status"] = "failed"
    return result


def verify_deb(path):
    report = {"schema_version": 1, "deb": str(path), "success": False,
              "status": "failed", "programs": {}, "errors": [],
              "verification_scope": "static Mach-O architecture, ranges, chained fixups, CodeDirectory code/special hashes",
              "whole_bundle_verified": False, "cms_trust_verified_by_python": False,
              "fixup_format_reference": FORMAT_REFERENCE,
              "limits": ["No sample execution or device/install test.",
                         "CMS certificates, trust chain and notarization are not verified by Python.",
                         "Info.plist/resources without sealed slots are not authenticated; no whole-bundle claim.",
                         "Scattered/pre-encryption/linkage CodeDirectories and compressed fixup symbols are rejected.",
                         "deb compression: tar, gzip, xz, bz2; zstd/lzma-alone are not supported."]}
    try:
        with open(path, "rb") as stream:
            data = stream.read(MAX_ARCHIVE + 1)
        need(len(data) <= MAX_ARCHIVE, "deb: archive size limit exceeded")
        report.update({"deb_size": len(data), "deb_sha256": sha(data)})
        files = read_deb(data)
    except (OSError, ValueError, EOFError, tarfile.TarError, lzma.LZMAError) as exc:
        report["errors"].append(str(exc))
        report["apple_codesign"] = {"performed": False, "status": "not_run_invalid_deb"}
        return report
    for name in PROGRAMS:
        external = {}
        if ".bundle/" in name:
            bundle = name.rsplit("/", 1)[0]
            for slot, relative in ((1, "Info.plist"), (3, "_CodeSignature/CodeResources")):
                if isinstance(files.get(bundle + "/" + relative), bytes):
                    external[slot] = files[bundle + "/" + relative]
        try:
            report["programs"][name] = verify_program(files[name], external)
        except (ValueError, struct.error) as exc:
            report["programs"][name] = {"success": False, "sha256": sha(files[name]), "error": str(exc)}
            report["errors"].append(name + ": " + str(exc))
    try:
        report["apple_codesign"] = apple_codesign(files)
    except OSError as exc:
        report["apple_codesign"] = {"performed": False, "status": "failed", "error": str(exc)}
    report["slice_count"] = sum(len(p.get("slices", [])) for p in report["programs"].values())
    report["code_pages_verified"] = sum(
        s["signature"]["code_pages_verified"] for p in report["programs"].values() for s in p.get("slices", []))
    report["success"] = (not report["errors"] and report["slice_count"] == 6 and
                         report["apple_codesign"]["status"] != "failed")
    report["status"] = "passed" if report["success"] else "failed"
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("deb", type=Path)
    parser.add_argument("--output", type=Path, help="also write the JSON report to this file")
    args = parser.parse_args(argv)
    if args.output and args.output.resolve() == args.deb.resolve():
        parser.error("--output must not overwrite the deb input")
    report = verify_deb(args.deb)
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        try:
            args.output.write_text(rendered, encoding="utf-8")
        except OSError as exc:
            print("cannot write report: " + str(exc), file=sys.stderr)
            return 2
    print(rendered, end="")
    return 0 if report["success"] else 1


if __name__ == "__main__":
    sys.exit(main())
