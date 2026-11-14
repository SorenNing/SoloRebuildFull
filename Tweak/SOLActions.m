#import "SOLActionsInternal.h"
#import "SOLPreferences.h"
#import "SOLHookRuntime.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <notify.h>
#import <math.h>
#import <string.h>

NSString * const SOLActionsChangedNotification = @"SoloEnhancements.ActionStateChanged";
static const char *SOLAUnqualified(const char *type) {
    while (type && *type && strchr("rnNoORV", *type)) ++type;
    return type ?: "";
}
static BOOL SOLAType(const char *raw, NSString *kind) {
    const char *t = SOLAUnqualified(raw);
    if ([kind isEqualToString:@"object"]) return t[0] == '@' && t[1] != '?';
    if ([kind isEqualToString:@"block"]) return !strcmp(t, "@?");
    if ([kind isEqualToString:@"void"]) return !strcmp(t, "v");
    if ([kind isEqualToString:@"number"]) return strlen(t) == 1 && strchr("BcCsSiIlLqQfd", *t);
    if ([kind isEqualToString:@"bool"]) return !strcmp(t, "B") || !strcmp(t, "c");
    return NO;
}
NSError *SOLAError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"Solo.Actions" code:code userInfo:@{NSLocalizedDescriptionKey:message ?: @"操作不可用"}];
}
/* Exact arity/return/argument kinds are checked before even setting arguments.
 * Supported scalar widths are marshalled separately (including FP registers). */
id SOLAInvoke(id target, NSString *name, NSString *returnKind, NSArray<NSString *> *kinds, NSArray *args, BOOL *accepted) {
    if (accepted) *accepted = NO;
    if (!target || args.count != kinds.count) return nil;
    SEL sel = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(object_getClass(target), sel);
    if (!method) return nil;
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    if (!sig || sig.numberOfArguments != args.count + 2 || !SOLAType(sig.methodReturnType, returnKind)) return nil;
    for (NSUInteger i=0; i<args.count; ++i) if (!SOLAType([sig getArgumentTypeAtIndex:i+2], kinds[i])) return nil;
    @try {
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        inv.target = target; inv.selector = sel;
        for (NSUInteger i=0; i<args.count; ++i) {
            id a = args[i] == NSNull.null ? nil : args[i];
            const char *t = SOLAUnqualified([sig getArgumentTypeAtIndex:i+2]);
            if (*t == '@') { __unsafe_unretained id object = a; [inv setArgument:&object atIndex:i+2]; continue; }
            if (![a isKindOfClass:NSNumber.class]) return nil;
#define SOLA_ARG(C, T, M) case C: { T v = [a M]; [inv setArgument:&v atIndex:i+2]; break; }
            switch (*t) {
                SOLA_ARG('B', BOOL, boolValue) SOLA_ARG('c', char, charValue)
                SOLA_ARG('C', unsigned char, unsignedCharValue) SOLA_ARG('s', short, shortValue)
                SOLA_ARG('S', unsigned short, unsignedShortValue) SOLA_ARG('i', int, intValue)
                SOLA_ARG('I', unsigned int, unsignedIntValue) SOLA_ARG('l', long, longValue)
                SOLA_ARG('L', unsigned long, unsignedLongValue) SOLA_ARG('q', long long, longLongValue)
                SOLA_ARG('Q', unsigned long long, unsignedLongLongValue)
                SOLA_ARG('f', float, floatValue) SOLA_ARG('d', double, doubleValue)
                default: return nil;
            }
#undef SOLA_ARG
        }
        [inv retainArguments]; [inv invoke];
        if (accepted) *accepted = YES;
        const char *t = SOLAUnqualified(sig.methodReturnType);
        if (*t == 'v') return nil;
        if (*t == '@') { __unsafe_unretained id value = nil; [inv getReturnValue:&value]; return value; }
#define SOLA_RET(C, T) case C: { T v=0; [inv getReturnValue:&v]; return @(v); }
        switch (*t) {
            SOLA_RET('B', BOOL) SOLA_RET('c', char) SOLA_RET('C', unsigned char)
            SOLA_RET('s', short) SOLA_RET('S', unsigned short) SOLA_RET('i', int)
            SOLA_RET('I', unsigned int) SOLA_RET('l', long) SOLA_RET('L', unsigned long)
            SOLA_RET('q', long long) SOLA_RET('Q', unsigned long long)
            SOLA_RET('f', float) SOLA_RET('d', double)
        }
#undef SOLA_RET
    } @catch (NSException *ex) { SOLLog(@"action %@ rejected: %@", name, ex.reason); if (accepted) *accepted=NO; }
    return nil;
}
id SOLAObject(id target, NSString *selector) { return SOLAInvoke(target,selector,@"object",@[],@[],NULL); }
NSNumber *SOLANumber(id target, NSString *selector) { return SOLAInvoke(target,selector,@"number",@[],@[],NULL); }
BOOL SOLACommand(id target, NSString *selector) {
    BOOL sent=NO; SOLAInvoke(target,selector,@"void",@[],@[],&sent);
    if (sent) return YES;
    NSNumber *result=SOLAInvoke(target,selector,@"bool",@[],@[],&sent);
    return sent && result.boolValue;
}
BOOL SOLASetNumber(id target, NSString *selector, NSNumber *value) {
    BOOL sent=NO; SOLAInvoke(target,selector,@"void",@[@"number"],@[value],&sent);
    if (sent) return YES;
    NSNumber *result=SOLAInvoke(target,selector,@"bool",@[@"number"],@[value],&sent);
    return sent && result.boolValue;
}
id SOLAShared(NSString *name) {
    Class cls=NSClassFromString(name);
    for (NSString *selector in @[@"sharedInstance",@"sharedInstanceIfExists",@"sharedManager",@"sharedController",@"defaultWorkspace"]) {
        id instance=SOLAObject(cls,selector); if (instance) return instance;
    }
    return nil;
}
BOOL SOLAIsSpringBoard(void) { return [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]; }
BOOL SOLAIsUnlocked(NSError **error) {
    if (!SOLAIsSpringBoard()) { if (error) *error=SOLAError(10,@"系统动作需要由 SpringBoard 中的 Solo 执行"); return NO; }
    id manager=SOLAShared(@"SBLockScreenManager");
    NSNumber *locked=SOLANumber(manager,@"isUILocked");
    if (!locked) {
        int token=-1; uint64_t state=0;
        if (notify_register_check("com.apple.springboard.lockstate",&token)==NOTIFY_STATUS_OK) {
            if (notify_get_state(token,&state)==NOTIFY_STATUS_OK) locked=@(state != 0);
            notify_cancel(token);
        }
    }
    if (!locked) { if (error) *error=SOLAError(11,@"无法核验系统锁屏状态，动作不可用"); return NO; }
    if (locked.boolValue) { if (error) *error=SOLAError(12,@"请解锁后再执行快捷操作"); return NO; }
    return YES;
}
UIViewController *SOLAPresenter(void) {
    for (UIWindow *window in UIApplication.sharedApplication.windows.reverseObjectEnumerator) {
        if (window.hidden || !window.rootViewController || window.alpha <= 0) continue;
        UIViewController *vc=window.rootViewController;
        while (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) vc=vc.presentedViewController;
        return vc;
    }
    return nil;
}
void SOLActionShowMessage(NSString *message) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{ SOLActionShowMessage(message); }); return; }
    UIViewController *vc=SOLAPresenter();
    if (!vc || [vc isKindOfClass:UIAlertController.class]) { SOLLog(@"%@",message); return; }
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Solo" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:alert animated:YES completion:nil];
}

static NSString *SOLAText(id value) {
    return [value isKindOfClass:NSString.class] ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}
static NSDictionary *SOLATool(NSString *value) {
    for (NSDictionary *r in SOLActionCatalog()) if ([r[@"value"] isEqual:value]) return r;
    return nil;
}
NSDictionary *SOLANormalizeRecord(id input) {
    if (![input isKindOfClass:NSDictionary.class]) return nil;
    NSString *type=SOLAText(input[@"type"]), *value=SOLAText(input[@"value"]);
    if (!value.length || [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound) return nil;
    if (![@[@"tool",@"app",@"url",@"shortcut",@"cc",@"solo"] containsObject:type]) return nil;
    if ([type isEqual:@"tool"] && !SOLATool(value)) return nil;
    if ([type isEqual:@"url"] && ![NSURLComponents componentsWithString:value].scheme.length) return nil;
    NSMutableDictionary *record=[NSMutableDictionary dictionaryWithDictionary:@{@"type":type,@"value":value}];
    NSString *title=SOLAText(input[@"title"]);
    record[@"title"]=title.length ? title : (SOLATool(value)[@"title"] ?: value);
    NSString *identifier=SOLAText(input[@"id"]);
    record[@"id"]=identifier.length ? identifier : [NSString stringWithFormat:@"%@:%@",type,value];
    record[@"enabled"]=[input[@"enabled"] isKindOfClass:NSNumber.class] ? @([input[@"enabled"] boolValue]) : @YES;
    for (NSString *key in @[@"mode",@"shortcutIdentifier",@"iconPNG",@"iconSourcePNG"]) {
        NSString *s=SOLAText(input[key]); if (s.length) record[key]=s;
    }
    if ([input[@"iconTransform"] isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *transform=[NSMutableDictionary dictionary];
        for (NSString *key in @[@"zoom",@"x",@"y"]) {
            id n=input[@"iconTransform"][key]; if ([n isKindOfClass:NSNumber.class] && isfinite([n doubleValue])) transform[key]=n;
        }
        if (transform.count) record[@"iconTransform"]=transform;
    }
    return record;
}
NSArray<NSDictionary *> *SOLActionRecords(NSString *key) {
    if (!key.length) key=@"sxShortcutActions";
    id stored=[[SOLPreferences shared] objectForKey:key];
    NSMutableArray *result=[NSMutableArray array];
    if ([stored isKindOfClass:NSArray.class]) {
        for (id input in stored) { NSDictionary *r=SOLANormalizeRecord(input); if (r) [result addObject:r]; }
        return result;
    }
    if (![key isEqual:@"sxShortcutActions"]) return @[];
    id legacy=[[SOLPreferences shared] objectForKey:@"shortcuts"];
    if (![legacy isKindOfClass:NSArray.class]) legacy=[[SOLPreferences shared] objectForKey:@"shortcutOrder"];
    if (![legacy isKindOfClass:NSArray.class]) legacy=@[@"wifi",@"bluetooth",@"airplane",@"lowPower",@"rotationLock",@"darkMode"];
    NSDictionary *map=@{@"airplane":@"airplane-mode",@"lowPower":@"low-power-mode",@"rotationLock":@"rotation-lock",@"darkMode":@"dark-mode",@"nightShift":@"night-shift",@"lock":@"lock-screen",@"location":@"location-services"};
    for (id old in legacy) {
        if ([old isKindOfClass:NSDictionary.class]) { NSDictionary *r=SOLANormalizeRecord(old); if (r) [result addObject:r]; continue; }
        NSString *s=SOLAText(old); NSDictionary *tool=SOLATool(map[s] ?: s);
        if (tool) [result addObject:tool];
    }
    return result;
}
BOOL SOLAWritePreference(NSString *key, id value, NSError **error) {
    if (!key.length || ![NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
        if (error) *error=SOLAError(20,@"配置无法保存"); return NO;
    }
    CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFPropertyListRef)value,(__bridge CFStringRef)SOLPreferenceDomain);
    if (!CFPreferencesAppSynchronize((__bridge CFStringRef)SOLPreferenceDomain)) {
        if (error) *error=SOLAError(21,@"系统拒绝写入 Solo 配置"); return NO;
    }
    [[SOLPreferences shared] reload];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge CFStringRef)SOLReloadNotification,NULL,NULL,YES);
    [[NSNotificationCenter defaultCenter] postNotificationName:SOLActionsChangedNotification object:nil];
    return YES;
}
BOOL SOLActionSaveRecords(NSString *key, NSArray<NSDictionary *> *records, NSError **error) {
    if (![records isKindOfClass:NSArray.class]) { if (error) *error=SOLAError(22,@"动作列表无效"); return NO; }
    NSMutableArray *clean=[NSMutableArray array]; NSMutableSet *ids=[NSMutableSet set];
    for (id input in records) {
        NSMutableDictionary *r=[SOLANormalizeRecord(input) mutableCopy];
        if (!r) { if (error) *error=SOLAError(23,@"动作配置无效，请重新选择"); return NO; }
        if ([ids containsObject:r[@"id"]]) r[@"id"]=NSUUID.UUID.UUIDString;
        [ids addObject:r[@"id"]]; [clean addObject:r];
    }
    return SOLAWritePreference(key.length ? key : @"sxShortcutActions",clean,error);
}
NSArray<NSDictionary *> *SOLInstalledApplicationRecords(void) {
    SXLAppCenter *center=[SXLAppCenter sharedCenter];
    if (![center.installedApplications count]) [center reloadInstalledApplications];
    NSMutableArray *out=[NSMutableArray array];
    for (SXLAppInfo *app in center.installedApplications) {
        if (app.bundleIdentifier.length) [out addObject:@{@"type":@"app",@"value":app.bundleIdentifier,@"title":app.displayName ?: app.bundleIdentifier,@"id":[@"app:" stringByAppendingString:app.bundleIdentifier],@"mode":@"fullscreen",@"enabled":@YES}];
    }
    return out;
}
BOOL SOLLaunchApplication(NSString *bundleID, NSError **error) {
    if (!NSThread.isMainThread) {
        __block BOOL result=NO; __block NSError *failure=nil;
        dispatch_sync(dispatch_get_main_queue(),^{result=SOLLaunchApplication(bundleID,&failure);});
        if (error) *error=failure; return result;
    }
    if (!SOLAIsUnlocked(error)) return NO;
    return [[SXLAppCenter sharedCenter] launchBundleID:bundleID error:error];
}
UIImage *SOLActionImage(NSDictionary *record) {
    NSString *png=SOLAText(record[@"iconPNG"]);
    if (png.length && png.length<6000000) {
        NSData *data=[[NSData alloc] initWithBase64EncodedString:png options:0];
        UIImage *custom=data ? [UIImage imageWithData:data] : nil; if (custom) return custom;
    }
    if ([record[@"type"] isEqual:@"app"]) return [[SXLAppCenter sharedCenter] iconForBundleID:SOLAText(record[@"value"])];
    NSString *symbol=SOLATool(SOLAText(record[@"value"]))[@"icon"];
    if (!symbol.length) symbol=[record[@"type"] isEqual:@"url"] ? @"link" : @"square.stack.3d.up";
    return [UIImage systemImageNamed:symbol];
}

static void SOLALoadFramework(NSString *name) {
    static NSMutableSet *loaded; static dispatch_once_t once; dispatch_once(&once,^{loaded=[NSMutableSet set];});
    @synchronized(loaded) {
        if ([loaded containsObject:name]) return;
        [loaded addObject:name];
        NSString *path=[NSString stringWithFormat:@"/System/Library/PrivateFrameworks/%@.framework/%@",name,name];
        dlopen(path.UTF8String,RTLD_LAZY|RTLD_LOCAL);
    }
}
static id SOLARadios(void) {
    static id radios; static dispatch_once_t once;
    dispatch_once(&once,^{ SOLALoadFramework(@"AppSupport"); radios=[NSClassFromString(@"RadiosPreferences") new]; });
    return radios;
}
static NSNumber *SOLAFirstNumber(id target, NSArray *selectors) {
    for (NSString *s in selectors) { NSNumber *n=SOLANumber(target,s); if (n) return n; }
    return nil;
}
NSNumber *SOLActionState(NSDictionary *record) {
    if (!SOLAIsSpringBoard() || ![record[@"type"] isEqual:@"tool"]) return nil;
    NSString *value=SOLAText(record[@"value"]);
    if ([value isEqual:@"wifi"]) return SOLAFirstNumber(SOLAShared(@"SBWiFiManager"),@[@"isWiFiEnabled",@"wiFiEnabled",@"wifiEnabled"]);
    if ([value isEqual:@"bluetooth"]) { SOLALoadFramework(@"BluetoothManager"); return SOLAFirstNumber(SOLAShared(@"BluetoothManager"),@[@"enabled",@"powered"]); }
    if ([value isEqual:@"rotation-lock"]) return SOLAFirstNumber(SOLAShared(@"SBOrientationLockManager"),@[@"isUserLocked",@"isLocked"]);
    if ([value isEqual:@"flashlight"]) { NSNumber *n=SOLANumber(SOLAShared(@"SBUIFlashlightController"),@"level"); return n ? @(n.doubleValue>0) : nil; }
    if ([value isEqual:@"airplane-mode"]) { id r=SOLARadios(); SOLACommand(r,@"refresh"); return SOLANumber(r,@"airplaneMode"); }
    if ([value isEqual:@"low-power-mode"]) return @(NSProcessInfo.processInfo.lowPowerModeEnabled);
    if ([value isEqual:@"dark-mode"]) return @(UIScreen.mainScreen.traitCollection.userInterfaceStyle==UIUserInterfaceStyleDark);
    if ([value isEqual:@"silent-mode"]) return SOLANumber(SOLAObject(SOLAShared(@"SBControlCenterController"),@"systemAgent"),@"isRingerMuted");
    return nil;
}
static BOOL SOLAToggle(id target, NSArray *getters, NSArray *setters) {
    NSNumber *current=SOLAFirstNumber(target,getters); if (!current) return NO;
    for (NSString *setter in setters) if (SOLASetNumber(target,setter,@(!current.boolValue))) return YES;
    return NO;
}
static BOOL SOLAArgs(id target, NSString *selector, NSArray *kinds, NSArray *args) {
    BOOL sent=NO; SOLAInvoke(target,selector,@"void",kinds,args,&sent); if (sent) return YES;
    NSNumber *result=SOLAInvoke(target,selector,@"bool",kinds,args,&sent); return sent && result.boolValue;
}
static BOOL SOLAOpenURL(NSString *text, NSError **error) {
    NSURL *url=[NSURL URLWithString:text]; if (!url.scheme.length) { if (error) *error=SOLAError(30,@"URL 格式无效"); return NO; }
    UIApplication *app=UIApplication.sharedApplication;
    /* Original 0x268a0..0x269ec: SpringBoard's private URL dispatcher.
     * ABI is checked even for these same-process system entry points. */
    if (SOLAArgs(app,@"applicationOpenURL:",@[@"object"],@[url])) return YES;
    if (SOLAArgs(app,@"applicationOpenURL:publicURLsOnly:",@[@"object",@"bool"],@[url,@NO])) return YES;
    if (![app canOpenURL:url]) { if (error) *error=SOLAError(31,@"未安装处理此 URL 的应用或系统拒绝打开"); return NO; }
    [app openURL:url options:@{} completionHandler:^(BOOL success){
        if (!success) SOLActionShowMessage(@"系统未接受打开 URL 的请求");
    }];
    return YES; /* Request submitted; asynchronous rejection is shown above. */
}
static BOOL SOLASystemTool(NSDictionary *tool, NSError **error) {
    NSString *value=tool[@"value"]; UIApplication *app=UIApplication.sharedApplication;
    if ([value isEqual:@"home"]) return SOLACommand(app,@"_simulateHomeButtonPress");
    if ([value isEqual:@"switcher"]) return SOLACommand(SOLAShared(@"SBUIController"),@"handleHomeButtonDoublePressDown");
    if ([value isEqual:@"control-center"]) {
        id controller=SOLAShared(@"SBControlCenterController");
        return SOLASetNumber(controller,@"presentAnimated:",@YES) || SOLAArgs(controller,@"presentAnimated:completion:",@[@"bool",@"block"],@[@YES,NSNull.null]);
    }
    if ([value isEqual:@"notification-center"]) {
        id manager=SOLAShared(@"SBCoverSheetPresentationManager");
        if (SOLAArgs(manager,@"setCoverSheetPresented:animated:withCompletion:",@[@"bool",@"bool",@"block"],@[@YES,@YES,NSNull.null])) return YES;
        return SOLASetNumber(SOLAShared(@"SBNotificationCenterController"),@"presentAnimated:",@YES);
    }
    if ([value isEqual:@"lock-screen"]) return SOLACommand(app,@"_simulateLockButtonPress") || SOLAArgs(SOLAShared(@"SBLockScreenManager"),@"lockUIFromSource:withOptions:",@[@"number",@"object"],@[@1,@{}]);
    if ([value isEqual:@"system-screenshot"] || [value isEqual:@"screenshot-edit"]) return SOLASetNumber(app,@"_takeScreenshotAndEdit:",@([value isEqual:@"screenshot-edit"])) || SOLACommand(app,@"takeScreenshot");
    if ([value isEqual:@"rotation-lock"]) {
        id manager=SOLAShared(@"SBOrientationLockManager");
        if (SOLAToggle(manager,@[@"isUserLocked",@"isLocked"],@[@"setUserLocked:"])) return YES;
        NSNumber *state=SOLAFirstNumber(manager,@[@"isUserLocked",@"isLocked"]);
        return state ? SOLACommand(manager,state.boolValue ? @"unlock" : @"lock") : NO;
    }
    if ([value isEqual:@"wifi"]) return SOLAToggle(SOLAShared(@"SBWiFiManager"),@[@"isWiFiEnabled",@"wiFiEnabled",@"wifiEnabled"],@[@"setWiFiEnabled:",@"setWiFiEnabledAndPowered:"]);
    if ([value isEqual:@"bluetooth"]) { SOLALoadFramework(@"BluetoothManager"); return SOLAToggle(SOLAShared(@"BluetoothManager"),@[@"enabled",@"powered"],@[@"setEnabled:",@"setPowered:"]); }
    if ([value isEqual:@"flashlight"]) {
        id controller=SOLAShared(@"SBUIFlashlightController"); NSNumber *level=SOLANumber(controller,@"level");
        return level ? SOLASetNumber(controller,@"setLevel:",@(level.doubleValue>0 ? 0.0 : 1.0)) : NO;
    }
    if ([value isEqual:@"airplane-mode"]) { id radios=SOLARadios(); SOLACommand(radios,@"refresh"); return SOLAToggle(radios,@[@"airplaneMode"],@[@"setAirplaneMode:"]); }
    if ([value isEqual:@"low-power-mode"]) {
        SOLALoadFramework(@"LowPowerMode"); id controller=SOLAShared(@"_PMLowPowerMode"); NSNumber *state=SOLANumber(controller,@"getPowerMode");
        return state && SOLAArgs(controller,@"setPowerMode:fromSource:",@[@"number",@"object"],@[@(!state.boolValue),@"SpringBoard"]);
    }
    if ([value isEqual:@"silent-mode"]) {
        id agent=SOLAObject(SOLAShared(@"SBControlCenterController"),@"systemAgent"); NSNumber *state=SOLANumber(agent,@"isRingerMuted");
        if (state && SOLAArgs(agent,@"setRingerMuted:reason:",@[@"bool",@"object"],@[@(!state.boolValue),@"QuickLaunch"])) return YES;
        return SOLAToggle(SOLAObject(app,@"ringerControl"),@[@"isRingerMuted"],@[@"setRingerMuted:"]);
    }
    if ([value isEqual:@"dark-mode"]) {
        SOLALoadFramework(@"UIKitServices");
        id current=SOLAObject(SOLAShared(@"UIUserInterfaceStyleArbiter"),@"currentStyle");
        NSNumber *state=SOLANumber(current,@"modeValue");
        id mode=[NSClassFromString(@"UISUserInterfaceStyleMode") new];
        return SOLASetNumber(mode,@"setModeValue:",@((state ? state.integerValue : UIScreen.mainScreen.traitCollection.userInterfaceStyle)==2 ? 1 : 2));
    }
    if ([value hasPrefix:@"brightness-"]) {
        CGFloat delta=[value hasSuffix:@"up"] ? 0.0625 : -0.0625;
        UIScreen.mainScreen.brightness=MIN(1,MAX(0,UIScreen.mainScreen.brightness+delta)); return YES;
    }
    if ([value hasPrefix:@"volume-"]) return SOLACommand(SOLAShared(@"SBVolumeControl"),[value hasSuffix:@"up"] ? @"increaseVolume" : @"decreaseVolume");
    NSString *systemSelector=tool[@"systemSelector"];
    if (systemSelector.length) {
        if ([tool[@"ipadOnly"] boolValue] && UIDevice.currentDevice.userInterfaceIdiom!=UIUserInterfaceIdiomPad) return NO;
        SOLALoadFramework(@"AccessibilityPhysicalInteraction");
        return SOLACommand(SOLAShared(@"AXPISystemActionHelper"),systemSelector);
    }
    if (error) *error=SOLAError(32,@"当前系统动作后端尚未恢复");
    return NO;
}

NSString *SOLActionUnavailableReason(NSDictionary *record) {
    NSDictionary *r=SOLANormalizeRecord(record); if (!r) return @"动作配置无效，请重新选择";
    NSString *type=r[@"type"], *value=r[@"value"];
    if ([type isEqual:@"app"]) {
        NSString *mode=r[@"mode"];
        if (mode.length && ![@[@"fullscreen",@"normal"] containsObject:mode]) return @"此第三方应用打开模式尚未完成运行环境与 ABI 验证，请选择全屏打开";
        return nil;
    }
    if ([type isEqual:@"cc"] || [type isEqual:@"solo"]) return @"此模块承载接口尚未恢复";
    NSDictionary *tool=SOLATool(value);
    if (tool[@"requires"]) return [NSString stringWithFormat:@"%@ 适配尚未在当前环境核验，暂不可用",tool[@"requires"]];
    if ([@[@"auto-brightness",@"night-shift",@"true-tone"] containsObject:value]) return @"显示服务结构与权限尚未核验，此工具暂不可用";
    if ([value isEqual:@"region-screenshot"]) return @"区域截图框选承载尚未恢复；可以使用系统截图或截图复制";
    return nil;
}
static BOOL SOLARecordScreen(BOOL microphone, NSError **error) {
    dlopen("/System/Library/Frameworks/ReplayKit.framework/ReplayKit",RTLD_LAZY|RTLD_LOCAL);
    id recorder=SOLAObject(NSClassFromString(@"RPScreenRecorder"),@"sharedRecorder");
    NSNumber *recording=SOLAFirstNumber(recorder,@[@"isRecording",@"systemRecording"]);
    if (!recording) { if (error) *error=SOLAError(36,@"系统录屏服务不可用"); return NO; }
    void (^handler)(NSError *)=^(NSError *failure) { if (failure) SOLActionShowMessage(failure.localizedDescription); };
    if (recording.boolValue) return SOLAArgs(recorder,@"stopSystemRecording:",@[@"block"],@[handler]);
    return SOLAArgs(recorder,@"startSystemRecordingWithMicrophoneEnabled:handler:",@[@"bool",@"block"],@[@(microphone),handler]);
}
static BOOL SOLACopyScreenshot(NSError **error) {
    /* Original 0x24c90 + block 0x28db4: symbol, w0=1, UIImage return. */
    UIImage *(*capture)(BOOL)=(UIImage *(*)(BOOL))dlsym(RTLD_DEFAULT,"_UICreateScreenUIImageWithRotation");
    if (!capture) { if (error) *error=SOLAError(37,@"系统截图函数不可用"); return NO; }
    UIImage *image=capture(YES);
    if (![image isKindOfClass:UIImage.class] || !image.CGImage) { if (error) *error=SOLAError(38,@"系统未返回有效截图"); return NO; }
    UIPasteboard.generalPasteboard.image=image;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,@"截图已复制，未保存到相册");
    return YES;
}
BOOL SOLActionPerformWithError(NSDictionary *record, NSError **error) {
    if (error) *error=nil;
    if (!NSThread.isMainThread) {
        __block NSError *failure=nil; __block BOOL success=NO;
        dispatch_sync(dispatch_get_main_queue(),^{success=SOLActionPerformWithError(record,&failure);});
        if (error) *error=failure; return success;
    }
    NSDictionary *r=SOLANormalizeRecord(record);
    if (!r) { if (error) *error=SOLAError(40,@"动作配置无效，请重新选择"); return NO; }
    NSString *reason=SOLActionUnavailableReason(r);
    if (reason) { if (error) *error=SOLAError(41,reason); return NO; }
    if (!SOLAIsUnlocked(error)) return NO;
    NSString *type=r[@"type"], *value=r[@"value"];
    BOOL success=NO;
    if ([type isEqual:@"app"]) success=SOLLaunchApplication(value,error);
    else if ([type isEqual:@"url"]) success=SOLAOpenURL(value,error);
    else if ([type isEqual:@"shortcut"]) {
        NSURLComponents *url=[NSURLComponents componentsWithString:@"shortcuts://run-shortcut"];
        url.queryItems=@[[NSURLQueryItem queryItemWithName:@"name" value:value]];
        /* Public Shortcuts URL fallback. Submitted != workflow completion. */
        success=SOLAOpenURL(url.URL.absoluteString,error);
    } else if ([type isEqual:@"tool"]) {
        NSDictionary *tool=SOLATool(value);
        if ([tool[@"url"] length]) success=SOLAOpenURL(tool[@"url"],error);
        else if ([value isEqual:@"screen-record"] || [value isEqual:@"screen-record-mic"]) success=SOLARecordScreen([value isEqual:@"screen-record-mic"],error);
        else if ([value isEqual:@"screenshot-copy"]) success=SOLACopyScreenshot(error);
        else success=SOLASystemTool(tool,error);
    }
    if (!success && error && !*error) *error=SOLAError(42,@"当前系统缺少兼容接口，动作未执行");
    if (success) [[NSNotificationCenter defaultCenter] postNotificationName:SOLActionsChangedNotification object:nil];
    return success;
}
BOOL SOLActionPerform(NSDictionary *record) {
    NSError *error=nil; BOOL success=SOLActionPerformWithError(record,&error);
    if (!success) SOLActionShowMessage(error.localizedDescription ?: @"动作未执行");
    return success;
}
UIView *SOLCreateActionView(BOOL vertical, NSString *key) {
    SXActionView *view=[[SXActionView alloc] initVertical:vertical];
    [view sol_setPreferenceKey:key.length ? key : @"sxShortcutActions"];
    return view;
}
void SOLPresentActionEditor(NSString *key, UIViewController *presenter) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{SOLPresentActionEditor(key,presenter);}); return; }
    SXActionEditor *editor=[SXActionEditor new]; editor.preferenceKey=key.length ? key : @"sxShortcutActions";
    UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:editor];
    navigation.modalPresentationStyle=UIModalPresentationPageSheet;
    UIViewController *host=presenter ?: SOLAPresenter();
    if (host && !host.presentedViewController) [host presentViewController:navigation animated:YES completion:nil];
}
