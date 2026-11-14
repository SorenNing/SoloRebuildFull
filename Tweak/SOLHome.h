#import <UIKit/UIKit.h>

/* Main-thread API. Refresh schedules itself on main when necessary. */
FOUNDATION_EXPORT void SOLHomeRefresh(void);
FOUNDATION_EXPORT void SOLHomeObserveRoot(UIView *root);
FOUNDATION_EXPORT void SOLHomeObserveDock(UIView *dock);
FOUNDATION_EXPORT CGRect SOLHomeAdjustedNativeFrame(UIView *view, CGRect requestedFrame);
FOUNDATION_EXPORT void SOLHomeSetSuppressed(NSString *reason, BOOL suppressed);
FOUNDATION_EXPORT void SOLHomeHandleAction(NSString *action, id sender);
FOUNDATION_EXPORT void SOLHomeTick(void);
FOUNDATION_EXPORT void SOLHomeApplyExpansion(CGFloat progress);
FOUNDATION_EXPORT BOOL SOLHomeShouldBeginPan(UIPanGestureRecognizer *pan);
FOUNDATION_EXPORT BOOL SOLHomeGestureShouldReceiveTouch(UITouch *touch);

/* Optional enhancement integration uses dlsym(RTLD_DEFAULT, ...) with
 * SOLCreateActionView(NO,@"sxShortcutActions"), SOLActionRecords(key), and
 * SOLActionPerform(record). No hard link between Solo/SoloEnhancements.
 * Record schema is the SOLActions.h type/value/title/id schema.
 * carouselPages retains original string kinds widget/media/clock/calendar/
 * shortcuts and original default first four entries. */
