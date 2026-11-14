#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "RecoveredInterfaces.h"
#import "SOLPreferences.h"
#import "SOLHookRuntime.h"
#import "SOLHome.h"

/* Source-level recovery, not a byte-equivalent reconstruction. Original
 * arm64e constructor 0x11aa8 installs SBDockView.layoutSubviews -> 0x14a88;
 * that reaches C home-layout function 0x1c638. Root lifecycle hooks below
 * provide an earlier/reliable mount on OS versions exposing SBRootFolderView.
 * Every retry uses the shared once-only, normalized-encoding installer. */
static void SOLInstallCoreHooks(void);
static void (*SOLOriginalRootLayout)(id,SEL);
static void (*SOLOriginalRootMove)(id,SEL);
static void (*SOLOriginalDockLayout)(id,SEL);
static void (*SOLOriginalSearchPresent)(id,SEL,id,BOOL);
static void (*SOLOriginalSearchDismiss)(id,SEL,id,BOOL);
static void (*SOLOriginalSetEditing)(id,SEL,BOOL);
static void (*SOLOriginalCoverEnd)(id,SEL,id,BOOL);
static void (*SOLOriginalPageManagementBegin)(id,SEL,id,id,id,id);
static void (*SOLOriginalPageManagementEnd)(id,SEL,id,id,id);
static BOOL SOLCoreStarted;
static BOOL SOLCoreRetryScheduled;
static NSUInteger SOLCoreRetryCount;

@implementation UnduoBackdropBlurView
+ (Class)layerClass {
    Class c = NSClassFromString(@"CABackdropLayer");
    return c ?: [CALayer class];
}
@end

@implementation UnduoRadialShadowView
+ (Class)layerClass { return [CAGradientLayer class]; }
@end

@implementation UnduoWelcomeGradientView
+ (Class)layerClass { return [CAGradientLayer class]; }
- (id)gradient { return objc_getAssociatedObject(self, @selector(gradient)); }
- (void)setGradient:(id)value { objc_setAssociatedObject(self, @selector(gradient), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

@implementation UnduoGlassBackingView
- (void)layoutSubviews {
    [super layoutSubviews];
    self.glassView.frame = self.bounds;
    self.glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}
@end

@implementation UnduoClockMirroredLabel
- (void)setText:(NSString *)text {
    self.unduoRawText = [text copy];
    [super setText:text];
    [self unduoRender];
}
- (void)unduoRender {
    NSString *text = self.unduoRawText ?: self.text ?: @"";
    if (self.unduoUppercase) text = text.uppercaseString;
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    if (self.font) attrs[NSFontAttributeName] = self.font;
    if (self.textColor) attrs[NSForegroundColorAttributeName] = self.textColor;
    if (self.unduoKern != 0) attrs[NSKernAttributeName] = @(self.unduoKern);
    self.attributedText = [[NSAttributedString alloc] initWithString:text attributes:attrs];
}
- (void)setFont:(UIFont *)font { [super setFont:font]; [self unduoRender]; }
- (void)setTextColor:(UIColor *)color { [super setTextColor:color]; [self unduoRender]; }
- (void)setUnduoUppercase:(BOOL)value { _unduoUppercase = value; [self unduoRender]; }
- (void)setUnduoKern:(CGFloat)value { _unduoKern = value; [self unduoRender]; }
- (void)setUnduoSuffixScale:(CGFloat)value { _unduoSuffixScale = value; [self unduoRender]; }
@end

@implementation UnduoClockMirroredImageView
- (void)setImage:(UIImage *)image { [super setImage:image]; }
@end

static void SOLRootLayout(id self, SEL cmd) {
    if (SOLOriginalRootLayout) SOLOriginalRootLayout(self,cmd);
    SOLHomeObserveRoot(self);
}
static void SOLRootMove(id self, SEL cmd) {
    if (SOLOriginalRootMove) SOLOriginalRootMove(self,cmd);
    SOLHomeObserveRoot(self);
}
static void SOLDockLayout(id self, SEL cmd) {
    if (SOLOriginalDockLayout) SOLOriginalDockLayout(self,cmd);
    SOLHomeObserveDock(self);
}
/* Original 0x1b0b4 / 0x1b168: two pointer args, BOOL in w3. */
static void SOLSearchPresent(id self, SEL cmd, id presenter, BOOL animated) {
    SOLHomeSetSuppressed(@"search",YES);
    if (SOLOriginalSearchPresent) SOLOriginalSearchPresent(self,cmd,presenter,animated);
}
static void SOLSearchDismiss(id self, SEL cmd, id presenter, BOOL animated) {
    if (SOLOriginalSearchDismiss) SOLOriginalSearchDismiss(self,cmd,presenter,animated);
    SOLHomeSetSuppressed(@"search",NO);
}
/* Original SBHIconManager.setEditing: replacement 0x186a0. */
static void SOLSetEditing(id self, SEL cmd, BOOL editing) {
    if (SOLOriginalSetEditing) SOLOriginalSetEditing(self,cmd,editing);
    SOLHomeSetSuppressed(@"editing",editing);
}
/* Original 0x1439c: (controller, BOOL toPresented), no CGFloat guessing. */
static void SOLCoverEnd(id self, SEL cmd, id controller, BOOL presented) {
    if (SOLOriginalCoverEnd) SOLOriginalCoverEnd(self,cmd,controller,presented);
    SOLHomeSetSuppressed(@"coverSheet",presented);
    if (!presented) SOLHomeRefresh();
}
static void SOLPageManagementBegin(id self, SEL cmd, id root, id manager, id animator, id context) {
    SOLHomeSetSuppressed(@"pageManagement",YES);
    if (SOLOriginalPageManagementBegin) SOLOriginalPageManagementBegin(self,cmd,root,manager,animator,context);
}
static void SOLPageManagementEnd(id self, SEL cmd, id root, id manager, id context) {
    if (SOLOriginalPageManagementEnd) SOLOriginalPageManagementEnd(self,cmd,root,manager,context);
    SOLHomeSetSuppressed(@"pageManagement",NO);
}
static void SOLInstallCoreHooks(void) {
    if (!SOLIsBundle(@"com.apple.springboard")) return;
    if (!SOLCoreStarted) {
        SOLCoreStarted=YES;
        SOLObserveReload(^{ SOLInstallCoreHooks(); SOLHomeRefresh(); });
    }
    /* Install even while disabled: enabling after launch must be reachable. */
    Class root=SOLClass(@"SBRootFolderView");
    BOOL mounted=SOLInstallTypedMessageHookOnce(@"Solo.Home.Root.layout",root,@selector(layoutSubviews),"v@:",(IMP)SOLRootLayout,(IMP *)&SOLOriginalRootLayout);
    SOLInstallTypedMessageHookOnce(@"Solo.Home.Root.move",root,@selector(didMoveToWindow),"v@:",(IMP)SOLRootMove,(IMP *)&SOLOriginalRootMove);
    BOOL dock=SOLInstallTypedMessageHookOnce(@"Solo.Home.Dock.layout",SOLClass(@"SBDockView"),@selector(layoutSubviews),"v@:",(IMP)SOLDockLayout,(IMP *)&SOLOriginalDockLayout);
    Class controller=SOLClass(@"SBIconController");
    if (![controller instancesRespondToSelector:NSSelectorFromString(@"searchPresenterWillPresentSearch:animated:")]) controller=SOLClass(@"SBHomeScreenController");
    SOLInstallTypedMessageHookOnce(@"Solo.Home.Search.present",controller,SOLSelector(@"searchPresenterWillPresentSearch:animated:"),"v@:@B",(IMP)SOLSearchPresent,(IMP *)&SOLOriginalSearchPresent);
    SOLInstallTypedMessageHookOnce(@"Solo.Home.Search.dismiss",controller,SOLSelector(@"searchPresenterWillDismissSearch:animated:"),"v@:@B",(IMP)SOLSearchDismiss,(IMP *)&SOLOriginalSearchDismiss);
    SOLInstallTypedMessageHookOnce(@"Solo.Home.Editing",SOLClass(@"SBHIconManager"),SOLSelector(@"setEditing:"),"v@:B",(IMP)SOLSetEditing,(IMP *)&SOLOriginalSetEditing);
    SOLInstallTypedMessageHookOnce(@"Solo.Home.Cover.end",SOLClass(@"SBCoverSheetPresentationManager"),SOLSelector(@"coverSheetSlidingViewControllerDidEndTransition:toPresented:"),"v@:@B",(IMP)SOLCoverEnd,(IMP *)&SOLOriginalCoverEnd);
    Class folder=SOLClass(@"SBRootFolderController");
    SOLInstallTypedMessageHookOnce(@"Solo.Home.Page.begin",folder,SOLSelector(@"rootFolderView:willPresentPageManagementWithLayoutManager:animator:context:"),"v@:@@@@",(IMP)SOLPageManagementBegin,(IMP *)&SOLOriginalPageManagementBegin);
    SOLInstallTypedMessageHookOnce(@"Solo.Home.Page.end",folder,SOLSelector(@"rootFolderView:didDismissPageManagementWithLayoutManager:context:"),"v@:@@@",(IMP)SOLPageManagementEnd,(IMP *)&SOLOriginalPageManagementEnd);
    SOLHomeRefresh();
    if ((!mounted || !dock) && !SOLCoreRetryScheduled && SOLCoreRetryCount<12) {
        SOLCoreRetryScheduled=YES; ++SOLCoreRetryCount;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{ SOLCoreRetryScheduled=NO; SOLInstallCoreHooks(); });
    }
}
__attribute__((constructor)) static void SoloCoreConstructor(void) {
    dispatch_async(dispatch_get_main_queue(),^{ SOLInstallCoreHooks(); });
}
