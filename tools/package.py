#!/usr/bin/env python3
import argparse, gzip, io, os, stat, struct, tarfile
from pathlib import Path

CONTROL = '''Package: com.oakstheawesome.solo
Name: Solo Enhanced Rebuild
Description: Reconstructed and maintainable Solo source baseline.
Depends: firmware (>= 15.0), ellekit | mobilesubstrate, preferenceloader
Section: Tweaks
Author: Ning&OaksTheAwesome
Maintainer: Ning
Architecture: iphoneos-arm64e
Version: 1.0.1-15
'''

def tar_bytes(entries):
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode='w', format=tarfile.USTAR_FORMAT) as t:
        for name, source, mode in entries:
            is_dir = source is None
            data = b'' if is_dir else (source if isinstance(source, bytes) else Path(source).read_bytes())
            tar_name = name.rstrip('/') + ('/' if is_dir else '')
            ti = tarfile.TarInfo(tar_name)
            ti.size = len(data); ti.mode = mode; ti.uid = 0; ti.gid = 0
            ti.uname = 'root'; ti.gname = 'wheel'; ti.mtime = 0
            if is_dir: ti.type = tarfile.DIRTYPE
            t.addfile(ti, io.BytesIO(data))
    return raw.getvalue()

def gzip_bytes(data):
    out = io.BytesIO()
    with gzip.GzipFile(fileobj=out, mode='wb', compresslevel=9, mtime=0) as g: g.write(data)
    return out.getvalue()

def ar_member(name, data):
    if not name.isascii() or '/' in name or len(name) > 15:
        raise ValueError('invalid ar member name: ' + name)
    name = name + '/'
    mode = format(0o100644, 'o')
    header = f'{name:<16}{0:<12}{0:<6}{0:<6}{mode:<8}{len(data):<10}`\n'.encode('ascii')
    if len(header) != 60: raise RuntimeError('bad ar header')
    return header + data + (b'\n' if len(data) & 1 else b'')

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--root', required=True); ap.add_argument('--build', required=True); ap.add_argument('--output', required=True)
    a = ap.parse_args(); root = Path(a.root); build = Path(a.build); out = Path(a.output); out.parent.mkdir(parents=True, exist_ok=True)
    files = []
    def add(rel, src, mode=0o644): files.append((rel, src, mode))
    def add_dir(rel): files.append((rel, None, 0o755))
    for d in ('Library', 'Library/MobileSubstrate', 'Library/MobileSubstrate/DynamicLibraries', 'Library/PreferenceBundles', 'Library/PreferenceBundles/SoloPrefs.bundle', 'Library/PreferenceLoader', 'Library/PreferenceLoader/Preferences'):
        add_dir(d)
    add('Library/MobileSubstrate/DynamicLibraries/Solo.dylib', build/'Solo.dylib', 0o755)
    add('Library/MobileSubstrate/DynamicLibraries/Solo.plist', root/'Solo.plist')
    add('Library/MobileSubstrate/DynamicLibraries/SoloEnhancements.dylib', build/'SoloEnhancements.dylib', 0o755)
    add('Library/MobileSubstrate/DynamicLibraries/SoloEnhancements.plist', root/'SoloEnhancements.plist')
    bundle = root/'Resources/SoloPrefs.bundle'
    for p in sorted(bundle.rglob('*')):
        if p.is_file(): add('Library/PreferenceBundles/SoloPrefs.bundle/'+str(p.relative_to(bundle)), p, 0o755 if p.name == 'SoloPrefs' else 0o644)
    add('Library/PreferenceBundles/SoloPrefs.bundle/SoloPrefs', build/'SoloPrefs', 0o755)
    add('Library/PreferenceLoader/Preferences/SoloPrefs.plist', root/'Resources/SoloPrefs.plist')
    control = gzip_bytes(tar_bytes([('./control', CONTROL.encode(), 0o644)]))
    data = gzip_bytes(tar_bytes(files))
    deb = b'!<arch>\n' + ar_member('debian-binary', b'2.0\n') + ar_member('control.tar.gz', control) + ar_member('data.tar.gz', data)
    out.write_bytes(deb)
    print(out, len(deb))
if __name__ == '__main__': main()
