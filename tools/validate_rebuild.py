#!/usr/bin/env python3
import json, re, hashlib, os, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
errors=[]
classes=[]
for rel in ('evidence/Solo.icj.json','evidence/SoloEnhancements.icj.json'):
    classes += json.loads((ROOT/rel).read_text())
expected={x['classname'] for x in classes}
text=(ROOT/'Tweak/RecoveredInterfaces.h').read_text()
actual=set(re.findall(r'^@interface (\w+)', text, re.M)) - {'PSListController','PSViewController'}
if expected != actual: errors.append('interface class set mismatch')
for rel in ('Tweak/SoloCore.m','Tweak/SoloEnhancements.m','Tweak/SOLPreferences.m','Tweak/SOLHookRuntime.m','Prefs/SoloPrefs.m'):
    if not (ROOT/rel).exists(): errors.append('missing '+rel)
for rel in ('Resources/SoloPrefs.bundle/icon.png','Resources/SoloPrefs.bundle/icon@2x.png','Resources/SoloPrefs.bundle/icon@3x.png','Resources/SoloPrefs.plist'):
    if not (ROOT/rel).exists(): errors.append('missing resource '+rel)
if 'setWithSharedKeyPool' in (ROOT/'Tweak/SOLHookRuntime.m').read_text(): errors.append('invalid NSMutableSet initializer remains')
if errors:
    print('FAIL')
    print('\n'.join(errors)); sys.exit(1)
print('PASS')
print('classes=',len(expected))
for rel in ('Makefile','control','Tweak/RecoveredInterfaces.h','Tweak/SoloCore.m','Tweak/SoloEnhancements.m','Prefs/SoloPrefs.m'):
    d=hashlib.sha256((ROOT/rel).read_bytes()).hexdigest(); print(rel,d)
