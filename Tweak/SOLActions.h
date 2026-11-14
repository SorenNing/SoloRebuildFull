#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
/* These C entry points are exported by SoloEnhancements. Main dylib may use
 * dlsym(RTLD_DEFAULT, "SOLActionPerform") without adding a link dependency. */
FOUNDATION_EXPORT BOOL SOLActionPerform(NSDictionary *record);
FOUNDATION_EXPORT BOOL SOLActionPerformWithError(NSDictionary *record, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT NSArray<NSDictionary *> *SOLActionCatalog(void);
FOUNDATION_EXPORT NSArray<NSDictionary *> *SOLActionRecords(NSString *preferenceKey);
FOUNDATION_EXPORT BOOL SOLActionSaveRecords(NSString *preferenceKey, NSArray<NSDictionary *> *records, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT UIImage * _Nullable SOLActionImage(NSDictionary *record);
FOUNDATION_EXPORT NSNumber * _Nullable SOLActionState(NSDictionary *record);
FOUNDATION_EXPORT NSString * _Nullable SOLActionUnavailableReason(NSDictionary *record);
FOUNDATION_EXPORT UIView *SOLCreateActionView(BOOL vertical, NSString *preferenceKey);
FOUNDATION_EXPORT void SOLPresentActionEditor(NSString *preferenceKey, UIViewController * _Nullable presenter);
FOUNDATION_EXPORT NSArray<NSDictionary *> *SOLInstalledApplicationRecords(void);
FOUNDATION_EXPORT BOOL SOLLaunchApplication(NSString *bundleID, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT void SOLActionShowMessage(NSString *message);
FOUNDATION_EXPORT NSString * const SOLActionsChangedNotification;
NS_ASSUME_NONNULL_END
