#!/usr/bin/env python3
import json, re, hashlib, os, sys, plistlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
errors=[]
manifest=json.loads((ROOT/'tools/reviewed-source.json').read_text())
for rel, entry in manifest['files'].items():
    path=ROOT/rel
    if not path.is_file() or path.stat().st_size!=entry['size'] or hashlib.sha256(path.read_bytes()).hexdigest()!=entry['sha256']:
        errors.append('source hash mismatch: '+rel)
class_manifest=json.loads((ROOT/'tools/recovered-classes.json').read_text())
expected=set(class_manifest['classes'])
if len(expected)!=64: errors.append('recovered class count mismatch')
control=(ROOT/'control').read_text()
if 'Version: '+manifest['version']+'\n' not in control: errors.append('control version mismatch')
for rel in ('Resources/SoloPrefs.bundle/Info.plist','Resources/Prefs/Info.plist'):
    info=plistlib.loads((ROOT/rel).read_bytes())
    if any(info.get(k)!=manifest['version'] for k in ('CFBundleVersion','CFBundleShortVersionString')):
        errors.append('bundle version mismatch: '+rel)
ci=(ROOT/'tools/ci-build.sh').read_text()
for rel in ('Tweak/SOLHome.m','Tweak/SOLActions.m','Tweak/SOLActionsCatalog.m','Tweak/SOLActionsRail.m'):
    if rel not in ci: errors.append('missing compile input: '+rel)
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
