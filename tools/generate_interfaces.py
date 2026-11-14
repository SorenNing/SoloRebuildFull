#!/usr/bin/env python3
import json, os, re
ROOT='/var/minis/workspace/solo-rebuild'
OUT=os.path.join(ROOT,'Tweak','RecoveredInterfaces.h')
files=[os.path.join(ROOT,'evidence','Solo.icj.json'),os.path.join(ROOT,'evidence','SoloEnhancements.icj.json')]
classes=[]
for p in files:
    with open(p) as f: classes += json.load(f)
by={c['classname']:c for c in classes}
base_known={'NSObject','UIView','UIViewController','UILabel','UIImageView','UIVisualEffectView','UICollectionViewLayout','UICollectionView','UICollectionViewCell','UITableViewController','PSListController','PSViewController'}

def typ(t):
    if not t: return 'id'
    if t.startswith('@"'):
        n=t[2:-1]
        # Protocol-qualified object types need an explicit id spelling.
        if '<' in n and n.endswith('>'):
            return 'id'
        return n+' *'
    if t.startswith('@<') or t=='@': return 'id'
    if t=='B': return 'BOOL'
    if t in ('q','i','s','l'): return 'NSInteger'
    if t in ('Q','I','S','L'): return 'NSUInteger'
    if t in ('d','f'): return 'CGFloat'
    if 'objc_class' in t: return 'Class'
    return 'id'

def safe(n):
    return re.sub(r'[^A-Za-z0-9_]','_',n)

# Topological order for reconstructed superclass dependencies.
ordered=[]; pending=dict(by)
while pending:
    progress=False
    for name,c in list(pending.items()):
        sup=(c.get('super') or ['NSObject'])[0]
        if sup in base_known or sup not in pending or sup in [x['classname'] for x in ordered]:
            ordered.append(c); del pending[name]; progress=True
    if not progress:
        ordered.extend(pending.values()); break

with open(OUT,'w') as o:
    o.write('/*\n * SoloRebuild recovered interfaces.\n * Generated from Objective-C metadata in Solo 1.0.1-12.\n * Method bodies, private ABI details and original source names are not recovered here.\n */\n')
    o.write('#import <Foundation/Foundation.h>\n#import <UIKit/UIKit.h>\n#if __has_include(<Preferences/Preferences.h>)\n#import <Preferences/Preferences.h>\n#else\n@interface PSListController : UIViewController @end\n@interface PSViewController : UIViewController @end\n#endif\n\n')
    for c in ordered:
        name=c['classname']; sup=(c.get('super') or ['NSObject'])[0]
        if sup not in by and sup not in base_known: sup='NSObject'
        o.write('@interface %s : %s\n' % (name,sup))
        fields={}
        for f in c.get('fields',[]):
            if f.get('kind')=='var' and f.get('name')!='isa': fields[f['name']]=typ(f.get('type'))
        if fields:
            o.write('{\n')
            for n,t in fields.items(): o.write('    %s %s;\n' % (t,n))
            o.write('}\n')
        for f in c.get('fields',[]):
            if f.get('kind')!='property': continue
            n=f.get('name','')
            if n in {'hash','superclass','description','debugDescription'}: continue
            iv='_'+n
            t=fields.get(iv,'id')
            attr='nonatomic'
            if t.endswith('*') or t=='id': attr += ', strong'
            elif t in ('BOOL','NSInteger','NSUInteger','CGFloat','double','float'): attr += ', assign'
            o.write('@property(%s) %s %s;\n' % (attr,t,n))
        o.write('// Recovered selectors:\n')
        for m in c.get('methods',[]):
            n=m.get('name','')
            if n and n!='.cxx_destruct': o.write('//   %s\n' % n)
        o.write('@end\n\n')

stub=os.path.join(ROOT,'Tweak','RecoveredClassStubs.m')
with open(stub,'w') as o:
    o.write('#import "RecoveredInterfaces.h"\n\n')
    for c in ordered: o.write('@implementation %s\n@end\n\n' % c['classname'])
print('generated',OUT,'and',stub,'classes',len(ordered))
