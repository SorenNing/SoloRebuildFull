import json
from pathlib import Path
root=Path('/var/minis/workspace/solo-rebuild')
main=json.loads((root/'evidence/Solo.icj.json').read_text())
enh=json.loads((root/'evidence/SoloEnhancements.icj.json').read_text())
main_actual={'UnduoBackdropBlurView','UnduoGlassBackingView','UnduoRadialShadowView','UnduoWelcomeGradientView','UnduoClockMirroredLabel','UnduoClockMirroredImageView'}
enh_actual={'SXShortcutBackdropView','SXGridLayout','SXAxisCollection','SXActionCell','SXActionView','SXVerticalPanProxy'}
def emit(items, excluded, path):
    lines=['#import "RecoveredInterfaces.h"','']
    for c in items:
        n=c['classname']
        if n in excluded: continue
        lines += [f'@implementation {n}', '@end', '']
    Path(path).write_text('\n'.join(lines))
emit(main,main_actual,root/'Tweak/SoloRecoveredClasses.m')
emit(enh,enh_actual,root/'Tweak/EnhancementsRecoveredClasses.m')
print('written')
