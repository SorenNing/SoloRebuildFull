#import "SOLPreferences.h"
#import <CoreFoundation/CoreFoundation.h>

static void reloadDarwin(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

NSString * const SOLPreferenceDomain = @"com.oakstheawesome.solo";
NSString * const SOLReloadNotification = @"com.oakstheawesome.solo/ReloadPrefs";
NSString * const SOLPreferencesDidReloadNotification = @"com.oakstheawesome.solo/preferencesDidReload";

@implementation SOLPreferences {
    NSDictionary *_values;
}

+ (instancetype)shared {
    static SOLPreferences *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [self new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:SOLReloadNotification object:nil];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, reloadDarwin, (__bridge CFStringRef)SOLReloadNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        [self reload];
    }
    return self;
}

static void reloadDarwin(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ [(__bridge SOLPreferences *)observer reload]; });
}

- (void)dealloc {
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, (__bridge CFStringRef)SOLReloadNotification, NULL);
}

- (void)reload {
    CFPreferencesAppSynchronize((__bridge CFStringRef)SOLPreferenceDomain);
    NSDictionary *d = [[NSUserDefaults standardUserDefaults] persistentDomainForName:SOLPreferenceDomain];
    NSDictionary *next = [d isKindOfClass:NSDictionary.class] ? [d copy] : @{};
    BOOL changed = NO;
    @synchronized (self) {
        changed = ![_values isEqualToDictionary:next];
        _values = next;
    }
    if (changed) {
        // Publish only after the immutable snapshot is visible.  Always async:
        // a subscriber may call +shared while its dispatch_once is completing.
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SOLPreferencesDidReloadNotification object:self];
        });
    }
}

- (id)objectForKey:(NSString *)key { @synchronized (self) { return _values[key]; } }
- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)value { id x = [self objectForKey:key]; return [x respondsToSelector:@selector(boolValue)] ? [x boolValue] : value; }
- (double)doubleForKey:(NSString *)key defaultValue:(double)value { id x = [self objectForKey:key]; return [x respondsToSelector:@selector(doubleValue)] ? [x doubleValue] : value; }
- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)value { id x = [self objectForKey:key]; return [x respondsToSelector:@selector(integerValue)] ? [x integerValue] : value; }
- (BOOL)enabled { return [self boolForKey:@"enabled" defaultValue:YES]; }
- (BOOL)enhancementsEnabled { return [self boolForKey:@"sxEnhancementsEnabled" defaultValue:YES]; }
@end
