#!/usr/bin/env python3
import importlib.util
import io
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('package', ROOT / 'tools/package.py')
pkg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pkg)

members = [
    ('debian-binary', b'2.0\n'),
    ('control.tar.gz', b'c' * 211),
    ('data.tar.gz', b'd' * 4097),
]
archive = b'!<arch>\n' + b''.join(pkg.ar_member(name, data) for name, data in members)
with tempfile.TemporaryDirectory() as td:
    ar_path = Path(td) / 'fixture.deb'
    ar_path.write_bytes(archive)
    listed = subprocess.check_output(['ar', 't', str(ar_path)], text=True).splitlines()
    listed = [name.rstrip('/') for name in listed]
    assert listed == [name for name, _ in members], listed
    parsed = {}
    pos = 8
    while pos < len(archive):
        header = archive[pos:pos + 60]
        assert len(header) == 60 and header[58:60] == b'`\n'
        name = header[:16].decode().strip().rstrip('/')
        size = int(header[48:58].decode().strip())
        pos += 60
        parsed[name] = archive[pos:pos + size]
        pos += size + (size & 1)
        if size & 1:
            assert archive[pos - 1:pos] == b'\n'
    assert parsed == dict(members)

with tempfile.TemporaryDirectory() as td:
    build = Path(td) / 'build'
    build.mkdir()
    for name in ('Solo.dylib', 'SoloEnhancements.dylib', 'SoloPrefs'):
        (build / name).write_bytes(b'fixture-' + name.encode())
    out = Path(td) / 'fixture.deb'
    subprocess.check_call(['python3', str(ROOT / 'tools/package.py'), '--root', str(ROOT), '--build', str(build), '--output', str(out)])
    subprocess.check_call(['python3', str(ROOT / 'tools/verify_package.py'), str(out)])
    subprocess.check_call(['dpkg-deb', '--info', str(out)], stdout=subprocess.DEVNULL)
    subprocess.check_call(['dpkg-deb', '--contents', str(out)], stdout=subprocess.DEVNULL)
    extract = Path(td) / 'extract'
    extract.mkdir()
    import gzip, os, sys, tarfile
    deb = out.read_bytes()
    pos = 8; ar_members = {}
    while pos < len(deb):
        header = deb[pos:pos + 60]
        name = header[:16].decode().strip().rstrip('/')
        size = int(header[48:58].decode().strip())
        pos += 60; ar_members[name] = deb[pos:pos + size]; pos += size + (size & 1)
    data_tar = tarfile.open(fileobj=io.BytesIO(gzip.decompress(ar_members['data.tar.gz'])))
    data_members = data_tar.getmembers()
    needed_dirs = ('Library', 'Library/MobileSubstrate', 'Library/MobileSubstrate/DynamicLibraries', 'Library/PreferenceBundles', 'Library/PreferenceBundles/SoloPrefs.bundle', 'Library/PreferenceLoader', 'Library/PreferenceLoader/Preferences')
    actual_dirs = {m.name.rstrip('/') for m in data_members if m.isdir()}
    assert set(needed_dirs) <= actual_dirs, actual_dirs
    data_tar.extractall(extract, filter='data')
    for rel in ('Library/MobileSubstrate/DynamicLibraries', 'Library/PreferenceBundles/SoloPrefs.bundle', 'Library/PreferenceLoader/Preferences'):
        assert (extract / rel).is_dir(), rel
    assert (extract / 'Library/PreferenceBundles/SoloPrefs.bundle/Calendar.plist').is_file()
    if sys.platform.startswith('linux') and os.geteuid() == 0:
        with tempfile.TemporaryDirectory(prefix='solo-dpkg-', dir='/tmp') as install_td:
            install_root = Path(install_td)
            admin = install_root / 'var/lib/dpkg'
            for rel in ('info', 'updates', 'triggers'):
                (admin / rel).mkdir(parents=True, exist_ok=True)
            (admin / 'status').touch()
            subprocess.check_call(['dpkg', '--force-architecture', '--root=' + str(install_root), '--admindir=' + str(admin), '--unpack', str(out)])
            assert (install_root / 'Library/PreferenceBundles/SoloPrefs.bundle/Calendar.plist').is_file()
            assert 'Status: install ok unpacked' in (admin / 'status').read_text()

print('PASS: ar odd/even, dpkg-deb, explicit directories and extraction; Linux root also checks real dpkg --unpack under /tmp')
