#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

BOOL SOLIsBundle(NSString *bundleID);
Class _Nullable SOLClass(NSString *name);
SEL SOLSelector(NSString *name);
BOOL SOLInstallMessageHookOnce(NSString *key, Class _Nullable cls, SEL sel, IMP replacement, IMP _Nullable * _Nullable original);
BOOL SOLMethodMatchesEncoding(Class _Nullable cls, SEL sel, const char *types);
BOOL SOLInstallTypedMessageHookOnce(NSString *key, Class _Nullable cls, SEL sel, const char *types, IMP replacement, IMP _Nullable * _Nullable original);
void SOLObserveReload(void (^handler)(void));
void SOLLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);

NS_ASSUME_NONNULL_END
