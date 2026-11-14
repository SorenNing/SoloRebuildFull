#import "SOLHookRuntime.h"
#import "SOLPreferences.h"
#import "../Vendor/Headers/substrate.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <string.h>

typedef void (*SOLHookMessageFn)(Class, SEL, IMP, IMP *);

static NSString *SOLNormalizedType(const char *type) {
    if (!type) return @"";
    // A method_copyArgumentType result has no frame offsets. Strip qualifiers
    // but preserve object/block, pointer, scalar and aggregate distinctions.
    while (*type && strchr("rnNoORV", *type)) type++;
    if (*type == '@' && type[1] == '"') return @"@";
    return [NSString stringWithUTF8String:type] ?: @"";
}

BOOL SOLMethodMatchesEncoding(Class cls, SEL sel, const char *types) {
    if (!cls || !sel || !types) return NO;
    Method method = class_getInstanceMethod(cls, sel);
    const char *actual = method ? method_getTypeEncoding(method) : NULL;
    if (!actual) return NO;
    @try {
        NSMethodSignature *a = [NSMethodSignature signatureWithObjCTypes:actual];
        NSMethodSignature *e = [NSMethodSignature signatureWithObjCTypes:types];
        if (a.numberOfArguments != e.numberOfArguments ||
            ![SOLNormalizedType(a.methodReturnType) isEqual:SOLNormalizedType(e.methodReturnType)]) return NO;
        for (NSUInteger i = 0; i < a.numberOfArguments; ++i) {
            if (![SOLNormalizedType([a getArgumentTypeAtIndex:i]) isEqual:SOLNormalizedType([e getArgumentTypeAtIndex:i])]) return NO;
        }
        return YES;
    } @catch (__unused NSException *exception) { return NO; }
}

static SOLHookMessageFn SOLResolveHookEngine(void) {
    SOLHookMessageFn hook = (SOLHookMessageFn)dlsym(RTLD_DEFAULT, "MSHookMessageEx");
    if (hook) return hook;
    static void *engine;
    if (!engine) {
        Dl_info info = {0};
        if (dladdr((const void *)&SOLResolveHookEngine, &info) && info.dli_fname) {
            NSString *directory = [[NSString stringWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
            NSString *path = [directory stringByAppendingPathComponent:@".jbroot/usr/lib/libsubstrate.dylib"];
            engine = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
        }
        const char *paths[] = {"/var/jb/usr/lib/libsubstrate.dylib", "/usr/lib/libsubstrate.dylib", "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate"};
        for (NSUInteger i = 0; !engine && i < sizeof(paths)/sizeof(paths[0]); ++i) engine = dlopen(paths[i], RTLD_NOW | RTLD_GLOBAL);
    }
    return (SOLHookMessageFn)dlsym(engine ?: RTLD_DEFAULT, "MSHookMessageEx");
}

BOOL SOLIsBundle(NSString *bundleID) {
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:bundleID];
}

Class SOLClass(NSString *name) { return NSClassFromString(name); }
SEL SOLSelector(NSString *name) { return NSSelectorFromString(name); }

BOOL SOLInstallMessageHookOnce(NSString *key, Class cls, SEL sel, IMP replacement, IMP *original) {
    if (!cls || !sel || !replacement || ![cls instancesRespondToSelector:sel]) return NO;
    SOLHookMessageFn hook = SOLResolveHookEngine();
    if (!hook) return NO;
    static NSMutableDictionary *installed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ installed = [NSMutableDictionary dictionary]; });
    @synchronized (installed) {
        NSString *slot = [NSString stringWithFormat:@"%p:%@", cls, NSStringFromSelector(sel)];
        NSValue *existing = installed[slot];
        if (existing) return existing.pointerValue == (const void *)replacement;
        if (class_getMethodImplementation(cls, sel) == replacement) return NO;
        hook(cls, sel, replacement, original);
        installed[slot] = [NSValue valueWithPointer:(const void *)replacement];
    }
    return YES;
}

BOOL SOLInstallTypedMessageHookOnce(NSString *key, Class cls, SEL sel, const char *types, IMP replacement, IMP *original) {
    return SOLMethodMatchesEncoding(cls, sel, types) && SOLInstallMessageHookOnce(key, cls, sel, replacement, original);
}

void SOLObserveReload(void (^handler)(void)) {
    if (!handler) return;
    [[NSNotificationCenter defaultCenter] addObserverForName:SOLPreferencesDidReloadNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *n) {
        handler();
    }];
}

void SOLLog(NSString *format, ...) {
    va_list ap; va_start(ap, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    if ([[SOLPreferences shared] boolForKey:@"debugLogging" defaultValue:NO]) NSLog(@"[SoloRebuild] %@", s);
}
