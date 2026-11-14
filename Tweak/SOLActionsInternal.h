#import "SOLActions.h"
#import "RecoveredInterfaces.h"
#import <objc/runtime.h>

/* Every private message is backed by an original Solo selector. NSInvocation
 * marshals the inspected scalar ABI; no untyped objc_msgSend casts. */
id _Nullable SOLAInvoke(id _Nullable target, NSString *selector, NSString *returnKind, NSArray<NSString *> *argumentKinds, NSArray *arguments, BOOL * _Nullable accepted);
id _Nullable SOLAShared(NSString *className);
BOOL SOLASetNumber(id _Nullable target, NSString *selector, NSNumber *value);
NSNumber * _Nullable SOLANumber(id _Nullable target, NSString *selector);
id _Nullable SOLAObject(id _Nullable target, NSString *selector);
BOOL SOLACommand(id _Nullable target, NSString *selector);
BOOL SOLAIsSpringBoard(void);
BOOL SOLAIsUnlocked(NSError * _Nullable * _Nullable error);
NSError *SOLAError(NSInteger code, NSString *message);
BOOL SOLAWritePreference(NSString *key, id value, NSError * _Nullable * _Nullable error);
UIViewController * _Nullable SOLAPresenter(void);
NSDictionary * _Nullable SOLANormalizeRecord(id record);

@interface SXActionView (SOLRecovered)
- (instancetype)initVertical:(BOOL)vertical;
- (void)reloadActions:(nullable NSArray *)actions;
- (void)refreshToolStates;
- (void)sol_setPreferenceKey:(NSString *)key;
@end
@interface SXActionEditor (SOLRecovered)
- (void)configureNavigation:(UIViewController *)controller;
- (void)add;
- (void)save;
@end
@interface SXPicker (SOLRecovered)
- (void)done;
@end
@interface SXLAppCenter (SOLRecovered)
+ (instancetype)sharedCenter;
- (void)reloadInstalledApplications;
- (void)reloadFromApplicationWorkspace;
- (nullable SXLAppInfo *)applicationForBundleID:(NSString *)bundleID;
- (nullable SXLAppInfo *)ensureApplicationForBundleID:(NSString *)bundleID;
- (nullable UIImage *)iconForBundleID:(NSString *)bundleID;
- (nullable UIImage *)iconForPrivateApplication:(id)application bundleID:(NSString *)bundleID;
- (BOOL)launchBundleID:(NSString *)bundleID error:(NSError **)error;
- (void)requestIconForBundleID:(NSString *)bundleID size:(CGFloat)size completion:(void (^)(UIImage * _Nullable))completion;
- (void)requestIconForBundleID:(NSString *)bundleID size:(CGFloat)size isCurrent:(BOOL (^)(void))isCurrent completion:(void (^)(UIImage * _Nullable))completion;
@end
@interface SXLLockStateMonitor (SOLRecovered)
- (void)start;
- (void)refresh;
- (void)stop;
@end
@interface SXLOverlayController (SOLRecovered)
- (void)startMonitoring;
- (void)stopMonitoring;
- (void)refreshGeometry;
@end
@interface SXModuleController (SOLRecovered)
- (void)close;
@end
