#!/usr/bin/env python3
import argparse, hashlib, io, struct, subprocess, tarfile, tempfile
from pathlib import Path

def ar(data):
    if not data.startswith(b'!<arch>\n'): raise SystemExit('not ar')
    p=8; out={}
    while p < len(data):
        h=data[p:p+60]; p+=60
        if len(h)!=60 or h[58:60]!=b'`\n': raise SystemExit('invalid ar header')
        n=h[:16].decode('ascii').strip().rstrip('/')
        try:
            size=int(h[48:58].decode('ascii').strip())
            mode=int(h[40:48].decode('ascii').strip(), 8)
        except ValueError:
            raise SystemExit('invalid ar size or mode')
        if size<0 or p+size>len(data): raise SystemExit('truncated ar member')
        if n in out: raise SystemExit('duplicate ar member')
        if mode!=0o100644: raise SystemExit('invalid ar mode')
        out[n]=data[p:p+size]; p+=size
        if size&1:
            if data[p:p+1]!=b'\n': raise SystemExit('invalid ar padding')
            p+=1
    if p!=len(data): raise SystemExit('invalid ar end offset')
    return out

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('deb'); a=ap.parse_args(); p=Path(a.deb); d=p.read_bytes(); m=ar(d)
    assert set(m)=={'debian-binary','control.tar.gz','data.tar.gz'}
    assert m['debian-binary']==b'2.0\n'
    ct=tarfile.open(fileobj=io.BytesIO(__import__('gzip').decompress(m['control.tar.gz'])))
    assert len(ct.getmembers())==1 and ct.getmembers()[0].name=='./control'
    control=ct.extractfile('./control').read().decode()
    fields=dict(line.split(': ',1) for line in control.splitlines() if line)
    assert fields['Version']=='1.0.1-15' and fields['Architecture']=='iphoneos-arm64e'
    assert fields['Package']=='com.oakstheawesome.solo' and fields['Author']=='Ning&OaksTheAwesome' and fields['Maintainer']=='Ning'
    root=Path(__file__).resolve().parents[1]
    assert control==(root/'control').read_text(), 'control metadata differs from source'
    dt=tarfile.open(fileobj=io.BytesIO(__import__('gzip').decompress(m['data.tar.gz'])))
    items=dt.getmembers(); names={x.name.rstrip('/') for x in items}
    assert len(names)==len(items)==24, 'unexpected payload count'
    required=['Library','Library/MobileSubstrate','Library/MobileSubstrate/DynamicLibraries','Library/PreferenceBundles','Library/PreferenceBundles/SoloPrefs.bundle','Library/PreferenceLoader','Library/PreferenceLoader/Preferences','Library/MobileSubstrate/DynamicLibraries/Solo.dylib','Library/MobileSubstrate/DynamicLibraries/SoloEnhancements.dylib','Library/PreferenceBundles/SoloPrefs.bundle/SoloPrefs','Library/PreferenceLoader/Preferences/SoloPrefs.plist']
    programs={'Library/MobileSubstrate/DynamicLibraries/Solo.dylib','Library/MobileSubstrate/DynamicLibraries/SoloEnhancements.dylib','Library/PreferenceBundles/SoloPrefs.bundle/SoloPrefs'}
    for x in required: assert x in names, x
    seen=set()
    for x in items:
        rel=x.name.rstrip('/')
        assert rel.startswith('Library') and not rel.startswith('/') and '..' not in Path(rel).parts, rel
        assert x.uid==x.gid==0 and x.uname=='root' and x.gname=='wheel', rel
        assert x.isdir() or x.isfile(), rel
        assert x.mode==(0o755 if x.isdir() or rel in programs else 0o644), rel
        parent=str(Path(rel).parent)
        assert parent=='.' or parent in seen, 'missing earlier parent directory: '+rel
        seen.add(rel)
    assert sum(x.isdir() for x in items)==7 and sum(x.isfile() for x in items)==17
    bundle='Library/PreferenceBundles/SoloPrefs.bundle/'
    import plistlib
    info=plistlib.loads(dt.extractfile(bundle+'Info.plist').read())
    assert info['CFBundleVersion']==info['CFBundleShortVersionString']=='1.0.1-15'
    for resource in (root/'Resources/SoloPrefs.bundle').iterdir():
        if resource.is_file(): assert dt.extractfile(bundle+resource.name).read()==resource.read_bytes(), resource.name
    for rel,src in (('Library/MobileSubstrate/DynamicLibraries/Solo.plist',root/'Solo.plist'),('Library/MobileSubstrate/DynamicLibraries/SoloEnhancements.plist',root/'SoloEnhancements.plist'),('Library/PreferenceLoader/Preferences/SoloPrefs.plist',root/'Resources/SoloPrefs.plist')):
        assert dt.extractfile(rel).read()==src.read_bytes(), rel

    print('PASS package entries=%d sha256=%s' % (len(names), hashlib.sha256(d).hexdigest()))
if __name__=='__main__': main()
