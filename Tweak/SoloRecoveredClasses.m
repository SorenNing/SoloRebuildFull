#import "RecoveredInterfaces.h"
#import "SOLHome.h"
#import <QuartzCore/QuartzCore.h>

/* Original class metadata gives handler ABI; the replacement UI is owned by
 * SOLHomeController rather than pretending original C globals were recovered. */
@implementation UnduoWeatherLocationDelegate
@end
@implementation UnduoPlusTapHandler
- (void)handleTap:(id)sender { SOLHomeHandleAction(@"manage",sender); }
@end
@implementation UnduoSearchButtonTapHandler
@end
@implementation UnduoWidgetPlatterTapHandler
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture { return YES; }
- (void)handleTap:(id)sender { SOLHomeHandleAction(@"expand",sender); }
@end
@implementation UnduoStatusRingTapHandler
- (void)handleRingTap:(id)sender { SOLHomeHandleAction(@"clock",sender); }
@end
@implementation UnduoWelcomeViewController
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }
- (BOOL)shouldAutorotate { return NO; }
@end
@implementation UnduoWelcomeSheet
@end
@implementation UnduoWidgetTapHandler
- (void)handleWidgetTap:(id)sender { SOLHomeHandleAction(@"expand",sender); }
@end
@implementation UnduoWidgetRemoveTapHandler
- (void)handleRemoveTap:(id)sender { SOLHomeHandleAction(@"hide",sender); }
@end
/* Native WidgetKit drag/drop model is deliberately not claimed recovered. */
@implementation UnduoCarouselDropTarget
@end
@implementation UnduoMediaRemoteObserver
- (void)unduoNowPlayingInfoChanged:(NSNotification *)note { SOLHomeTick(); }
- (void)unduoNowPlayingApplicationIsPlayingChanged:(NSNotification *)note { SOLHomeTick(); }
@end
@implementation UnduoMediaProgressTickHandler
- (void)tick { SOLHomeTick(); }
@end
@implementation UnduoGradientView
+ (Class)layerClass { return CAGradientLayer.class; }
@end
@implementation UnduoMediaPlayerContainerView
- (void)traitCollectionDidChange:(UITraitCollection *)previous { [super traitCollectionDidChange:previous]; SOLHomeRefresh(); }
@end
@implementation UnduoMediaTransportHandler
- (void)handleArtTap:(id)sender { SOLHomeHandleAction(@"artwork",sender); }
- (void)handlePlayPause:(id)sender { SOLHomeHandleAction(@"playPause",sender); }
- (void)handleBack:(id)sender { SOLHomeHandleAction(@"previous",sender); }
- (void)handleSkip:(id)sender { SOLHomeHandleAction(@"next",sender); }
- (void)handleTouchDown:(UIControl *)control { control.alpha=.55; }
- (void)handleTouchUp:(UIControl *)control { control.alpha=1; }
@end
/* Scrubbing is implemented by the reachable UISlider in SOLHome.m. */
@implementation UnduoMediaScrubHandler
@end
@implementation UnduoPassthroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { UIView *hit=[super hitTest:point withEvent:event]; return hit==self ? nil:hit; }
@end
@implementation UnduoMediaPaneSwipeHandler
- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)pan { return SOLHomeShouldBeginPan(pan); }
- (void)handlePan:(UIPanGestureRecognizer *)pan { if (pan.state==UIGestureRecognizerStateEnded) SOLHomeHandleAction(@"expand",pan); }
@end
@implementation UnduoClockTapHandler
- (void)handleClockTap:(id)sender { SOLHomeHandleAction(@"clock",sender); }
- (void)handleDateTap:(id)sender { SOLHomeHandleAction(@"calendar",sender); }
- (void)handleFaceTap:(id)sender { SOLHomeHandleAction(@"clock",sender); }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch { return SOLHomeGestureShouldReceiveTouch(touch); }
@end
@implementation UnduoAppearanceObserverView
- (void)traitCollectionDidChange:(UITraitCollection *)previous { [super traitCollectionDidChange:previous]; SOLHomeRefresh(); }
- (void)didMoveToWindow { [super didMoveToWindow]; if (self.window) SOLHomeRefresh(); }
@end
@implementation UnduoWiggleExitCorrectionTickHandler
- (void)tick { SOLHomeTick(); }
@end
@implementation UnduoRemoveButtonMaskTickHandler
- (void)tick { SOLHomeTick(); }
@end
@implementation UnduoCalendarTapHandler
- (void)handleRowTap:(id)sender { SOLHomeHandleAction(@"event",sender); }
- (void)handleBadgeTap:(id)sender { SOLHomeHandleAction(@"calendar",sender); }
- (void)handleMonthTap:(id)sender { SOLHomeHandleAction(@"calendar",sender); }
@end
@implementation UnduoShortcutTapHandler
- (void)handleTap:(id)sender { SOLHomeHandleAction(@"shortcut",sender); }
@end
@implementation UnduoPlatterFrameDriver
- (void)tick:(CADisplayLink *)link { SOLHomeTick(); }
- (void)applyFrame:(CGFloat)progress { SOLHomeApplyExpansion(progress); }
@end
@implementation UnduoPlatterPagePanHandler
- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)pan { return SOLHomeShouldBeginPan(pan); }
- (void)handlePan:(UIPanGestureRecognizer *)pan { if (pan.state==UIGestureRecognizerStateEnded) SOLHomeHandleAction(@"expand",pan); }
@end
