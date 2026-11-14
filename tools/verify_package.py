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
    assert m['debian-binary']==b'2.0\n'
    control=tarfile.open(fileobj=io.BytesIO(__import__('gzip').decompress(m['control.tar.gz']))).extractfile('./control').read().decode()
    assert 'Version: 1.0.1-14' in control and 'Architecture: iphoneos-arm64e' in control and 'Author: Ning&OaksTheAwesome' in control
    dt=tarfile.open(fileobj=io.BytesIO(__import__('gzip').decompress(m['data.tar.gz'])))
    items=dt.getmembers(); names={x.name.rstrip('/') for x in items}
    required=['Library','Library/MobileSubstrate','Library/MobileSubstrate/DynamicLibraries','Library/PreferenceBundles','Library/PreferenceBundles/SoloPrefs.bundle','Library/PreferenceLoader','Library/PreferenceLoader/Preferences','Library/MobileSubstrate/DynamicLibraries/Solo.dylib','Library/MobileSubstrate/DynamicLibraries/SoloEnhancements.dylib','Library/PreferenceBundles/SoloPrefs.bundle/SoloPrefs','Library/PreferenceLoader/Preferences/SoloPrefs.plist']
    for x in required: assert x in names, x
    for x in items:
        assert not x.name.startswith('var/jb/'), x.name
        if x.isdir(): assert x.mode == 0o755

    print('PASS package entries=%d sha256=%s' % (len(names), hashlib.sha256(d).hexdigest()))
if __name__=='__main__': main()
