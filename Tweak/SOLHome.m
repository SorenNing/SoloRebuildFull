#import "SOLHome.h"
#import "SOLPreferences.h"
#import "SOLHookRuntime.h"
#import <EventKit/EventKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <math.h>

@class SOLHomeController;
static SOLHomeController *SOLHomeSharedController(void);
static id SOLHomeObject(id object, NSString *selector);
static UIView *SOLHomeFindView(UIView *view, NSString *name, NSUInteger depth);
static BOOL SOLHomeOpenURL(NSURL *url);
static void SOLHomeExecuteShortcut(NSDictionary *action, UIView *source);
static NSString *SOLHomeString(id value);
static NSArray<NSString *> *SOLHomePageKinds(void);
static NSString *SOLHomeStatePath(void);
static void SOLHomeSetFrameIfChanged(UIView *view, CGRect frame);
static void SOLHomeCalendarRequested(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

@interface SOLHomeSurface : UIView
@end
@implementation SOLHomeSurface
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}
@end

@interface SOLHomeClockFace : UIView
@property(nonatomic) BOOL secondHand;
@property(nonatomic) NSInteger face;
@property(nonatomic, strong) NSDate *date;
@end
@implementation SOLHomeClockFace
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext(); if (!c) return;
    CGFloat radius = MIN(self.bounds.size.width, self.bounds.size.height) * .46;
    CGPoint mid = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    UIColor *ink = UIColor.labelColor;
    CGContextSetStrokeColorWithColor(c, ink.CGColor);
    for (NSInteger n = 0; n < 60; n++) {
        CGFloat a = n * M_PI / 30 - M_PI_2;
        CGFloat length = n % 5 ? 3 : 8;
        CGContextSetLineWidth(c, n % 5 ? .8 : 2);
        CGContextMoveToPoint(c, mid.x + cos(a)*(radius-length), mid.y + sin(a)*(radius-length));
        CGContextAddLineToPoint(c, mid.x + cos(a)*radius, mid.y + sin(a)*radius);
        CGContextStrokePath(c);
    }
    NSDateComponents *d = [NSCalendar.currentCalendar components:NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:self.date ?: NSDate.date];
    CGFloat angles[] = {(d.hour%12 + d.minute/60.0)*M_PI/6-M_PI_2,
                        (d.minute+d.second/60.0)*M_PI/30-M_PI_2, d.second*M_PI/30-M_PI_2};
    CGFloat lengths[] = {radius*.48, radius*.74, radius*.85};
    for (NSInteger n=0; n<(self.secondHand ? 3:2); n++) {
        CGContextSetStrokeColorWithColor(c, (n==2 ? UIColor.systemOrangeColor:ink).CGColor);
        CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineWidth(c,n==0?4:n==1?2.5:1);
        CGContextMoveToPoint(c, mid.x, mid.y);
        CGContextAddLineToPoint(c,mid.x+cos(angles[n])*lengths[n],mid.y+sin(angles[n])*lengths[n]);
        CGContextStrokePath(c);
    }
    CGContextSetFillColorWithColor(c,ink.CGColor); CGContextFillEllipseInRect(c,CGRectMake(mid.x-3,mid.y-3,6,6));
}
@end

@interface SOLHomeController : NSObject <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property(nonatomic, weak) UIView *root;
@property(nonatomic, weak) UIView *dock;
@property(nonatomic, strong) SOLHomeSurface *surface;
@property(nonatomic, strong) UIVisualEffectView *material;
@property(nonatomic, strong) UIScrollView *pager;
@property(nonatomic, strong) UIPageControl *dots;
@property(nonatomic, strong) UIButton *expandButton;
@property(nonatomic, strong) UIButton *manageButton;
@property(nonatomic, strong) UIButton *restoreButton;
@property(nonatomic, strong) UILabel *heading;
@property(nonatomic, strong) NSMutableDictionary<NSString *,UIView *> *panes;
@property(nonatomic, strong) NSArray<NSString *> *kinds;
@property(nonatomic, strong) NSMutableSet<NSString *> *hiddenKinds;
@property(nonatomic, strong) NSMutableSet<NSString *> *suppression;
@property(nonatomic, strong) NSMapTable<UIView *, NSValue *> *nativeFrames;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) BOOL expanded;
@property(nonatomic) BOOL applyingLayout;
@property(nonatomic) BOOL rebuilding;
@property(nonatomic) NSInteger selected;
@property(nonatomic, copy) NSString *selectedKind;
@property(nonatomic, strong) UILabel *clockTime;
@property(nonatomic, strong) UIButton *clockDate;
@property(nonatomic, strong) SOLHomeClockFace *clockFace;
@property(nonatomic, strong) UIImageView *clockBackground;
@property(nonatomic, strong) UIView *clockShade;
@property(nonatomic, strong) UIView *enhancedActions;
@property(nonatomic, strong) UILabel *mediaTitle;
@property(nonatomic, strong) UILabel *mediaArtist;
@property(nonatomic, strong) UIImageView *artwork;
@property(nonatomic, strong) UIButton *playButton;
@property(nonatomic, strong) UISlider *scrubber;
@property(nonatomic, strong) UILabel *mediaTime;
@property(nonatomic, strong) NSDictionary *mediaInfo;
@property(nonatomic) NSTimeInterval mediaSample;
@property(nonatomic) BOOL mediaRequestPending;
@property(nonatomic) BOOL mediaPlaying;
@property(nonatomic, strong) UIView *calendarRows;
@property(nonatomic, strong) UILabel *calendarStatus;
@property(nonatomic, strong) UIButton *calendarPermission;
@property(nonatomic, strong) EKEventStore *eventStore;
@property(nonatomic, strong) NSArray<EKEvent *> *events;
@property(nonatomic, strong) dispatch_queue_t calendarQueue;
@property(nonatomic) NSUInteger calendarGeneration;
@property(nonatomic) BOOL calendarPending;
@property(nonatomic, strong) UIView *shortcutGrid;
@property(nonatomic, strong) NSArray<NSDictionary *> *shortcuts;
@property(nonatomic, strong) NSMutableArray *observers;
@property(nonatomic) NSUInteger ticks;
- (void)refresh;
- (void)observeRoot:(UIView *)root;
- (void)restoreNativeFrames;
- (void)applyLayout;
- (void)rebuild;
- (void)tick;
- (void)action:(NSString *)action sender:(id)sender;
- (void)saveState;
- (void)requestMedia;
- (void)reloadCalendar;
- (void)renderCalendar;
- (void)layoutPanes;
- (void)updateSelection;
- (void)setExpanded:(BOOL)expanded animated:(BOOL)animated;
- (void)requestCalendarAccess;
- (void)publishCalendars;
- (void)mediaChanged:(NSNotification *)note;
- (void)button:(UIButton *)button;
- (void)pageChanged:(UIPageControl *)control;
- (void)seek:(UISlider *)slider;
- (void)verticalSwipe:(UISwipeGestureRecognizer *)gesture;
- (void)managePages;
- (UIViewController *)presenter;
- (UILabel *)labelIn:(UIView *)parent size:(CGFloat)size weight:(UIFontWeight)weight;
- (UIButton *)buttonIn:(UIView *)parent title:(NSString *)title symbol:(NSString *)symbol action:(NSString *)action;
- (UIView *)buildPane:(NSString *)kind;
@end

static void *SOLHomeActionKey = &SOLHomeActionKey;
static void *SOLHomePayloadKey = &SOLHomePayloadKey;
static void *SOLHomeMediaHandle;
static void (*SOLMRInfo)(dispatch_queue_t, void (^)(CFDictionaryRef));
static void (*SOLMRPlaying)(dispatch_queue_t, void (^)(BOOL));
static BOOL (*SOLMRCommand)(uint32_t, CFDictionaryRef);
static void (*SOLMRSeek)(double);
static void (*SOLMRPID)(dispatch_queue_t, void (^)(int));
static void (*SOLMRRegister)(dispatch_queue_t);
static NSString *SOLMRKey(const char *symbol);
static void SOLHomeLoadMedia(void);

@implementation SOLHomeController
- (instancetype)init {
    if ((self = [super init])) {
        _suppression = [NSMutableSet set]; _hiddenKinds=[NSMutableSet set];
        _nativeFrames=[NSMapTable weakToStrongObjectsMapTable]; _panes=[NSMutableDictionary dictionary];
        _observers=[NSMutableArray array]; _calendarQueue=dispatch_queue_create("com.oakstheawesome.solo.home.calendar",DISPATCH_QUEUE_SERIAL);
        NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:SOLHomeStatePath()];
        if ([state isKindOfClass:NSDictionary.class]) {
            _selectedKind=SOLHomeString(state[@"selectedKind"]); _expanded=[state[@"expanded"] boolValue];
            if ([state[@"hiddenKinds"] isKindOfClass:NSArray.class]) for (id x in state[@"hiddenKinds"]) if ([x isKindOfClass:NSString.class]) [_hiddenKinds addObject:x];
        }
        NSNotificationCenter *nc=NSNotificationCenter.defaultCenter;
        __weak typeof(self) weakSelf=self;
        for (NSString *name in @[NSSystemTimeZoneDidChangeNotification,NSCurrentLocaleDidChangeNotification,UIApplicationSignificantTimeChangeNotification,UIApplicationDidBecomeActiveNotification]) {
            id token=[nc addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { [weakSelf tick]; [weakSelf reloadCalendar]; [weakSelf refresh]; }];
            [_observers addObject:token];
        }
        [_observers addObject:[nc addObserverForName:EKEventStoreChangedNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { [weakSelf reloadCalendar]; }]];
        SOLHomeLoadMedia();
        const char *mediaSymbols[]={"kMRMediaRemoteNowPlayingInfoDidChangeNotification","kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"};
        for (NSUInteger i=0;i<sizeof(mediaSymbols)/sizeof(mediaSymbols[0]);i++) {
            NSString *name=SOLMRKey(mediaSymbols[i]);
            if (name.length) [_observers addObject:[nc addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { [weakSelf requestMedia]; }]];
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge const void *)self,SOLHomeCalendarRequested,CFSTR("com.oakstheawesome.solo/RequestCalendars"),NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}
- (void)dealloc { [_timer invalidate]; for (id token in _observers) [NSNotificationCenter.defaultCenter removeObserver:token]; }
- (void)observeRoot:(UIView *)root {
    if (![root isKindOfClass:UIView.class] || !root.window || root.bounds.size.width<100 || root.bounds.size.height<200) return;
    if (self.root != root) {
        [self restoreNativeFrames]; [self.surface removeFromSuperview]; self.root=root;
        if (self.surface) [root addSubview:self.surface];
    }
    if (!self.surface) [self rebuild];
    [self applyLayout];
}
- (void)refresh {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; }); return; }
    if (!self.root) return;
    [self restoreNativeFrames]; [self rebuild]; [self applyLayout]; [self tick];
    [self requestMedia]; [self reloadCalendar]; [self.root setNeedsLayout];
}
- (void)restoreNativeFrames {
    if (self.applyingLayout) return;
    self.applyingLayout=YES;
    for (UIView *view in self.nativeFrames.keyEnumerator.allObjects) {
        NSValue *value=[self.nativeFrames objectForKey:view]; if (view.superview && value) SOLHomeSetFrameIfChanged(view,value.CGRectValue);
    }
    [self.nativeFrames removeAllObjects]; self.applyingLayout=NO;
}
- (void)saveState {
    NSString *path=SOLHomeStatePath();
    NSDictionary *state=@{@"version":@1,@"selectedKind":self.selectedKind ?: @"clock",@"expanded":@(self.expanded),@"hiddenKinds":self.hiddenKinds.allObjects};
    NSError *error=nil;
    [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error];
    if (![state writeToFile:path atomically:YES]) SOLLog(@"home state write failed %@",error);
}
- (UILabel *)labelIn:(UIView *)parent size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label=[UILabel new]; label.textColor=UIColor.labelColor; label.font=[UIFont systemFontOfSize:size weight:weight];
    label.adjustsFontSizeToFitWidth=YES; label.minimumScaleFactor=.65; [parent addSubview:label]; return label;
}
- (UIButton *)buttonIn:(UIView *)parent title:(NSString *)title symbol:(NSString *)symbol action:(NSString *)action {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; [button setTitle:title forState:UIControlStateNormal];
    if (symbol.length) [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    button.tintColor=UIColor.labelColor; button.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    button.accessibilityLabel=title.length ? title : action; button.layer.cornerRadius=12;
    objc_setAssociatedObject(button,SOLHomeActionKey,action,OBJC_ASSOCIATION_COPY_NONATOMIC);
    [button addTarget:self action:@selector(button:) forControlEvents:UIControlEventTouchUpInside]; [parent addSubview:button]; return button;
}
- (void)rebuild {
    if (self.rebuilding) return; self.rebuilding=YES;
    [self.timer invalidate]; self.timer=nil; [self.surface removeFromSuperview]; [self.panes removeAllObjects];
    self.clockTime=nil; self.clockDate=nil; self.clockFace=nil; self.clockBackground=nil; self.clockShade=nil; self.enhancedActions=nil; self.mediaTitle=nil; self.mediaArtist=nil;
    self.artwork=nil; self.playButton=nil; self.scrubber=nil; self.mediaTime=nil; self.calendarRows=nil;
    self.calendarStatus=nil; self.calendarPermission=nil; self.shortcutGrid=nil;
    NSMutableArray *kinds=[NSMutableArray array];
    for (NSString *kind in SOLHomePageKinds()) if (![self.hiddenKinds containsObject:kind]) [kinds addObject:kind];
    self.kinds=kinds; self.selected=0;
    if (self.selectedKind && [kinds containsObject:self.selectedKind]) self.selected=[kinds indexOfObject:self.selectedKind];
    if (!self.selectedKind && [kinds containsObject:@"clock"]) self.selected=[kinds indexOfObject:@"clock"];
    self.selectedKind=kinds.count ? kinds[self.selected]:nil;
    self.surface=[[SOLHomeSurface alloc] initWithFrame:CGRectZero]; self.surface.accessibilityIdentifier=@"Solo.Home.Surface";
    self.material=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    self.material.layer.cornerRadius=28; self.material.layer.cornerCurve=kCACornerCurveContinuous; self.material.clipsToBounds=YES;
    [self.surface addSubview:self.material];
    self.heading=[self labelIn:self.surface size:12 weight:UIFontWeightSemibold]; self.heading.text=@"SOLO";
    self.heading.textColor=UIColor.secondaryLabelColor;
    self.expandButton=[self buttonIn:self.surface title:@"" symbol:self.expanded?@"chevron.down":@"chevron.up" action:@"expand"];
    self.expandButton.accessibilityLabel=@"展开或收起 Solo";
    self.manageButton=[self buttonIn:self.surface title:@"" symbol:@"ellipsis.circle" action:@"manage"];
    self.manageButton.accessibilityLabel=@"管理轮播页面";
    self.pager=[[UIScrollView alloc] initWithFrame:CGRectZero]; self.pager.pagingEnabled=YES; self.pager.delegate=self;
    self.pager.showsHorizontalScrollIndicator=NO; self.pager.showsVerticalScrollIndicator=NO; self.pager.bounces=YES;
    self.pager.directionalLockEnabled=YES; self.pager.accessibilityIdentifier=@"Solo.Home.Carousel";
    [self.surface addSubview:self.pager];
    self.dots=[UIPageControl new]; self.dots.numberOfPages=kinds.count; self.dots.currentPage=self.selected;
    self.dots.pageIndicatorTintColor=[UIColor.secondaryLabelColor colorWithAlphaComponent:.3]; self.dots.currentPageIndicatorTintColor=UIColor.labelColor;
    [self.dots addTarget:self action:@selector(pageChanged:) forControlEvents:UIControlEventValueChanged]; [self.surface addSubview:self.dots];
    self.restoreButton=[self buttonIn:self.surface title:@"恢复轮播页面" symbol:@"plus.circle" action:@"restore"];
    self.restoreButton.hidden=kinds.count!=0;
    for (NSString *kind in kinds) { UIView *pane=[self buildPane:kind]; if (pane) { self.panes[kind]=pane; [self.pager addSubview:pane]; } }
    for (NSNumber *direction in @[@(UISwipeGestureRecognizerDirectionUp),@(UISwipeGestureRecognizerDirectionDown)]) {
        UISwipeGestureRecognizer *swipe=[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(verticalSwipe:)];
        swipe.direction=direction.unsignedIntegerValue; swipe.delegate=self; [self.surface addGestureRecognizer:swipe];
    }
    if (self.root) [self.root addSubview:self.surface]; self.rebuilding=NO;
}
- (void)applyLayout {
    if (self.applyingLayout || self.rebuilding || !self.root) return;
    SOLPreferences *p=SOLPreferences.shared;
    BOOL visible=p.enabled && [p boolForKey:@"carouselEnabled" defaultValue:YES] && self.suppression.count==0 && self.root.window;
    self.surface.hidden=!visible;
    if (!visible) { [self.timer invalidate]; self.timer=nil; [self restoreNativeFrames]; return; }
    self.applyingLayout=YES;
    UIView *root=self.root; CGFloat width=CGRectGetWidth(root.bounds); CGFloat total=CGRectGetHeight(root.bounds);
    CGFloat top=MAX(root.safeAreaInsets.top,36)+8;
    CGFloat height=self.kinds.count ? (self.expanded ? MIN(370,total*.46):226):74;
    if (width>total) height=self.expanded?210:170;
    height=MIN(height,MAX(100,total-top-200));
    SOLHomeSetFrameIfChanged(self.surface,CGRectMake(16,top,width-32,height)); self.material.frame=self.surface.bounds;
    self.heading.frame=CGRectMake(18,8,100,24); self.manageButton.frame=CGRectMake(width-134,2,42,38);
    self.expandButton.frame=CGRectMake(width-88,2,42,38);
    self.pager.frame=CGRectMake(0,38,width-32,MAX(1,height-62));
    self.dots.frame=CGRectMake(40,height-26,width-112,24); self.dots.hidden=self.kinds.count<2;
    self.restoreButton.frame=CGRectMake(120,20,MAX(80,width-180),38);
    [self layoutPanes];
    UIView *scroll=SOLHomeFindView(root,@"SBIconScrollView",0);
    if (scroll && scroll.superview && ![scroll isDescendantOfView:self.surface]) {
        NSValue *saved=[self.nativeFrames objectForKey:scroll];
        CGRect original=saved ? saved.CGRectValue:scroll.frame;
        if (!saved) [self.nativeFrames setObject:[NSValue valueWithCGRect:original] forKey:scroll];
        CGRect frame=[scroll.superview convertRect:original toView:root]; CGFloat bottom=CGRectGetMaxY(frame);
        CGFloat desired=MAX(CGRectGetMinY(frame),CGRectGetMaxY(self.surface.frame)+8);
        if (bottom-desired>=100) { frame.origin.y=desired; frame.size.height=bottom-desired; SOLHomeSetFrameIfChanged(scroll,[root convertRect:frame toView:scroll.superview]); }
    }
    [root bringSubviewToFront:self.surface]; self.applyingLayout=NO;
    if (!self.timer) {
        __weak typeof(self) weakSelf=self;
        self.timer=[NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) { [weakSelf tick]; }];
        [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
        [self requestMedia]; [self reloadCalendar];
    }
}
- (UIView *)buildPane:(NSString *)kind {
    UIView *pane=[UIView new]; pane.accessibilityIdentifier=[@"Solo.Home." stringByAppendingString:kind];
    if ([kind isEqualToString:@"clock"]) {
        id jpeg=[SOLPreferences.shared objectForKey:@"sxClockBackgroundJPEG"];
        UIImage *image=[jpeg isKindOfClass:NSData.class] ? [UIImage imageWithData:jpeg]:nil;
        if (image) {
            self.clockBackground=[[UIImageView alloc] initWithImage:image]; self.clockBackground.contentMode=UIViewContentModeScaleAspectFill;
            self.clockBackground.clipsToBounds=YES; self.clockBackground.layer.cornerRadius=16; [pane addSubview:self.clockBackground];
            self.clockShade=[UIView new]; self.clockShade.backgroundColor=UIColor.blackColor;
            self.clockShade.alpha=MIN(1,MAX(0,[SOLPreferences.shared doubleForKey:@"sxClockBackdropOpacity" defaultValue:.55]));
            self.clockShade.userInteractionEnabled=NO; self.clockShade.layer.cornerRadius=16; [pane addSubview:self.clockShade];
        }
        self.clockTime=[self labelIn:pane size:62 weight:UIFontWeightLight]; self.clockTime.font=[UIFont monospacedDigitSystemFontOfSize:62 weight:UIFontWeightLight];
        self.clockTime.userInteractionEnabled=YES; [self.clockTime addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clockTap:)]];
        self.clockTime.accessibilityTraits=UIAccessibilityTraitButton; self.clockTime.accessibilityLabel=@"打开时钟";
        self.clockDate=[self buttonIn:pane title:@"" symbol:nil action:@"calendar"];
        self.clockFace=[SOLHomeClockFace new]; self.clockFace.backgroundColor=UIColor.clearColor; [pane addSubview:self.clockFace];
        self.clockFace.userInteractionEnabled=YES; [self.clockFace addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clockTap:)]];
    } else if ([kind isEqualToString:@"media"]) {
        self.artwork=[UIImageView new]; self.artwork.layer.cornerRadius=14; self.artwork.clipsToBounds=YES; self.artwork.contentMode=UIViewContentModeScaleAspectFill;
        self.artwork.backgroundColor=[UIColor.secondaryLabelColor colorWithAlphaComponent:.15]; [pane addSubview:self.artwork];
        self.artwork.userInteractionEnabled=YES; [self.artwork addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(artTap:)]];
        self.mediaTitle=[self labelIn:pane size:18 weight:UIFontWeightSemibold]; self.mediaTitle.text=@"暂无正在播放";
        self.mediaArtist=[self labelIn:pane size:13 weight:UIFontWeightRegular]; self.mediaArtist.textColor=UIColor.secondaryLabelColor;
        self.playButton=[self buttonIn:pane title:@"" symbol:@"play.fill" action:@"playPause"];
        self.playButton.accessibilityLabel=@"播放或暂停";
        UIButton *back=[self buttonIn:pane title:@"" symbol:@"backward.fill" action:@"previous"]; back.tag=310;
        UIButton *next=[self buttonIn:pane title:@"" symbol:@"forward.fill" action:@"next"]; next.tag=311;
        self.scrubber=[UISlider new]; [self.scrubber addTarget:self action:@selector(seek:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        self.scrubber.accessibilityLabel=@"播放进度"; [pane addSubview:self.scrubber];
        self.mediaTime=[self labelIn:pane size:11 weight:UIFontWeightRegular]; self.mediaTime.textColor=UIColor.secondaryLabelColor;
    } else if ([kind isEqualToString:@"calendar"]) {
        UIButton *header=[self buttonIn:pane title:@"日历" symbol:@"calendar" action:@"calendar"]; header.tag=320;
        self.calendarStatus=[self labelIn:pane size:14 weight:UIFontWeightRegular]; self.calendarStatus.numberOfLines=2;
        self.calendarRows=[UIView new]; [pane addSubview:self.calendarRows];
        self.calendarPermission=[self buttonIn:pane title:@"允许读取日历" symbol:nil action:@"calendarAccess"]; self.calendarPermission.hidden=YES;
        [self renderCalendar];
    } else if ([kind isEqualToString:@"widget"]) {
        UILabel *label=[self labelIn:pane size:15 weight:UIFontWeightMedium]; label.tag=330; label.numberOfLines=3;
        label.text=@"原生小组件拖放尚未恢复\n可切换到媒体、时钟、日历，或在页面管理中隐藏此页。";
        label.textAlignment=NSTextAlignmentCenter;
    } else if ([kind isEqualToString:@"shortcuts"]) {
        UIView *(*createActions)(BOOL,NSString *)=dlsym(RTLD_DEFAULT,"SOLCreateActionView");
        if (createActions) {
            self.enhancedActions=createActions(NO,@"sxShortcutActions");
            if (self.enhancedActions) { [pane addSubview:self.enhancedActions]; return pane; }
        }
        self.shortcutGrid=[UIView new]; [pane addSubview:self.shortcutGrid];
        NSArray *(*records)(NSString *)=dlsym(RTLD_DEFAULT,"SOLActionRecords");
        id configured=records ? records(@"sxShortcutActions"):[SOLPreferences.shared objectForKey:@"sxShortcutActions"];
        NSMutableArray *actions=[NSMutableArray array];
        if ([configured isKindOfClass:NSArray.class]) for (id item in configured) {
            if ([item isKindOfClass:NSDictionary.class]) [actions addObject:item];
            if (actions.count>=12) break;
        }
        if (!actions.count) {
            UILabel *missing=[self labelIn:pane size:14 weight:UIFontWeightRegular]; missing.tag=331; missing.numberOfLines=2;
            missing.text=@"快捷动作后端尚未加载\n启用增强层后刷新本页。"; missing.textAlignment=NSTextAlignmentCenter;
        }
        self.shortcuts=actions;
        for (NSDictionary *entry in actions) {
            NSString *title=SOLHomeString(entry[@"title"]) ?: SOLHomeString(entry[@"name"]) ?: SOLHomeString(entry[@"id"]) ?: @"快捷入口";
            UIButton *button=[self buttonIn:self.shortcutGrid title:title symbol:SOLHomeString(entry[@"symbol"]) ?: @"arrow.up.forward.app" action:@"shortcut"];
            button.backgroundColor=[UIColor.secondaryLabelColor colorWithAlphaComponent:.08];
            objc_setAssociatedObject(button,SOLHomePayloadKey,entry,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return pane;
}
- (void)layoutPanes {
    CGFloat w=self.pager.bounds.size.width,h=self.pager.bounds.size.height; if (w<=0) return;
    self.pager.contentSize=CGSizeMake(w*self.kinds.count,h);
    self.clockBackground.frame=CGRectMake(8,0,w-16,h); self.clockShade.frame=self.clockBackground.frame;
    if (self.clockBackground.image) { self.clockTime.textColor=UIColor.whiteColor; self.clockDate.tintColor=UIColor.whiteColor; }
    [self.panes[@"widget"] viewWithTag:330].frame=CGRectMake(20,12,w-40,MAX(40,h-24));
    self.enhancedActions.frame=CGRectMake(10,0,w-20,h);
    [self.panes[@"shortcuts"] viewWithTag:331].frame=CGRectMake(20,12,w-40,MAX(40,h-24));
    for (NSUInteger n=0;n<self.kinds.count;n++) self.panes[self.kinds[n]].frame=CGRectMake(w*n,0,w,h);
    if (!self.pager.dragging && !self.pager.decelerating) self.pager.contentOffset=CGPointMake(w*self.selected,0);
    BOOL analog=[SOLPreferences.shared integerForKey:@"clockFace" defaultValue:0]!=0;
    self.clockFace.hidden=!analog; self.clockTime.hidden=analog;
    self.clockFace.frame=CGRectMake((w-138)/2,0,138,MIN(138,h-26)); self.clockFace.secondHand=[SOLPreferences.shared boolForKey:@"secondHand" defaultValue:YES];
    self.clockTime.frame=CGRectMake(20,MAX(0,(h-104)/2-10),w-40,80);
    self.clockTime.textAlignment=[SOLPreferences.shared integerForKey:@"clockLayout" defaultValue:0]==0 ? NSTextAlignmentLeft:NSTextAlignmentCenter;
    self.clockDate.frame=CGRectMake(14,h-35,w-28,32);
    BOOL modern=[SOLPreferences.shared integerForKey:@"mediaStyle" defaultValue:0]!=0;
    CGFloat art=self.expanded?MIN(124,h-94):64; if (modern && self.expanded) art=MIN(142,h-94);
    self.artwork.frame=CGRectMake(18,5,art,art); self.mediaTitle.frame=CGRectMake(art+30,6,MAX(30,w-art-46),26);
    self.mediaArtist.frame=CGRectMake(art+30,34,MAX(30,w-art-46),35); self.mediaArtist.numberOfLines=2;
    CGFloat controlsY=self.expanded ? MAX(art+9,h-93):72;
    UIView *media=self.panes[@"media"];
    [media viewWithTag:310].frame=CGRectMake(w/2-90,controlsY,54,38); self.playButton.frame=CGRectMake(w/2-27,controlsY,54,38);
    [media viewWithTag:311].frame=CGRectMake(w/2+36,controlsY,54,38);
    self.scrubber.frame=CGRectMake(18,h-42,w-36,26); self.mediaTime.frame=CGRectMake(23,h-18,w-46,16);
    UIView *calendar=self.panes[@"calendar"]; [calendar viewWithTag:320].frame=CGRectMake(14,0,w-28,30);
    self.calendarStatus.frame=CGRectMake(20,40,w-40,50); self.calendarPermission.frame=CGRectMake(20,h-44,w-40,38);
    self.calendarRows.frame=CGRectMake(16,34,w-32,h-36); [self renderCalendar];
    self.shortcutGrid.frame=CGRectMake(14,8,w-28,h-12);
    NSUInteger count=self.shortcutGrid.subviews.count; NSUInteger columns=self.expanded?3:4;
    NSUInteger rows=MAX(1,(count+columns-1)/columns); CGFloat cellW=self.shortcutGrid.bounds.size.width/columns;
    CGFloat cellH=MAX(40,self.shortcutGrid.bounds.size.height/rows);
    for (NSUInteger i=0;i<count;i++) {
        UIButton *b=(id)self.shortcutGrid.subviews[i]; b.frame=CGRectMake((i%columns)*cellW+3,(i/columns)*cellH+3,cellW-6,cellH-6);
        b.titleLabel.numberOfLines=2; b.titleLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        b.imageEdgeInsets=UIEdgeInsetsMake(-20,0,0,-25); b.titleEdgeInsets=UIEdgeInsetsMake(28,-26,0,0);
    }
}
- (void)tick {
    if (!self.root.window || self.surface.hidden) { [self.timer invalidate]; self.timer=nil; return; }
    NSDate *now=NSDate.date; NSDateFormatter *f=[NSDateFormatter new]; f.timeStyle=NSDateFormatterShortStyle;
    self.clockTime.text=[f stringFromDate:now]; self.clockFace.date=now; [self.clockFace setNeedsDisplay];
    f.timeStyle=NSDateFormatterNoStyle; f.dateStyle=NSDateFormatterFullStyle; [self.clockDate setTitle:[f stringFromDate:now] forState:UIControlStateNormal];
    NSTimeInterval duration=[self.mediaInfo[SOLMRKey("kMRMediaRemoteNowPlayingInfoDuration") ?: @"duration"] doubleValue];
    NSTimeInterval elapsed=[self.mediaInfo[SOLMRKey("kMRMediaRemoteNowPlayingInfoElapsedTime") ?: @"elapsedTime"] doubleValue];
    if (self.mediaPlaying) elapsed+=MAX(0,CACurrentMediaTime()-self.mediaSample);
    elapsed=MIN(MAX(0,elapsed),MAX(0,duration));
    if (!self.scrubber.tracking) self.scrubber.value=duration>0 ? elapsed/duration:0;
    self.scrubber.enabled=SOLMRSeek && duration>0;
    self.mediaTime.text=duration>0 ? [NSString stringWithFormat:@"%ld:%02ld / %ld:%02ld",(long)elapsed/60,(long)elapsed%60,(long)duration/60,(long)duration%60]:@"";
    if (++self.ticks%10==0) [self requestMedia];
    if (self.ticks%60==0) [self reloadCalendar];
}
- (void)updateSelection {
    CGFloat w=self.pager.bounds.size.width; if (w<=0 || !self.kinds.count) return;
    self.selected=MAX(0,MIN((NSInteger)self.kinds.count-1,(NSInteger)llround(self.pager.contentOffset.x/w)));
    self.selectedKind=self.kinds[self.selected]; self.dots.currentPage=self.selected; [self saveState];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView { [self updateSelection]; }
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate { if (!decelerate) [self updateSelection]; }
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView { [self updateSelection]; }
- (void)pageChanged:(UIPageControl *)control {
    if (!self.kinds.count) return; self.selected=MIN((NSInteger)self.kinds.count-1,MAX(0,control.currentPage));
    self.selectedKind=self.kinds[self.selected]; [self saveState];
    [self.pager setContentOffset:CGPointMake(self.selected*self.pager.bounds.size.width,0) animated:YES];
}
- (void)setExpanded:(BOOL)expanded animated:(BOOL)animated {
    self.expanded=expanded; [self saveState]; [self restoreNativeFrames];
    [self.expandButton setImage:[UIImage systemImageNamed:expanded?@"chevron.down":@"chevron.up"] forState:UIControlStateNormal];
    void (^layout)(void)=^{ [self applyLayout]; };
    if (animated) [UIView animateWithDuration:.3 delay:0 usingSpringWithDamping:.9 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:layout completion:nil];
    else layout();
}
- (void)verticalSwipe:(UISwipeGestureRecognizer *)gesture { [self setExpanded:gesture.direction==UISwipeGestureRecognizerDirectionUp animated:YES]; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch { return SOLHomeGestureShouldReceiveTouch(touch); }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return NO; }
- (void)button:(UIButton *)button { [self action:objc_getAssociatedObject(button,SOLHomeActionKey) sender:button]; }
- (void)clockTap:(id)sender { [self action:@"clock" sender:sender]; }
- (void)artTap:(id)sender { [self action:@"artwork" sender:sender]; }
- (UIViewController *)presenter {
    UIResponder *r=self.root;
    while (r && ![r isKindOfClass:UIViewController.class]) r=r.nextResponder;
    UIViewController *vc=[r isKindOfClass:UIViewController.class] ? (id)r:self.root.window.rootViewController;
    while (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) vc=vc.presentedViewController;
    return vc;
}
- (void)managePages {
    UIViewController *presenter=[self presenter]; if (!presenter || [presenter isKindOfClass:UIAlertController.class]) return;
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Solo 轮播" message:@"隐藏项可在这里恢复；左右滑动切换，向上滑动展开。" preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;
    NSArray *names=@[@"小组件（拖放尚未恢复）",@"时钟",@"媒体",@"日历",@"快捷入口"]; NSArray *all=@[@"widget",@"clock",@"media",@"calendar",@"shortcuts"];
    for (NSUInteger i=0;i<all.count;i++) {
        NSString *kind=all[i]; BOOL hidden=[self.hiddenKinds containsObject:kind] || ![SOLHomePageKinds() containsObject:kind];
        NSString *title=[NSString stringWithFormat:@"%@%@",hidden?@"恢复":@"隐藏",names[i]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            SOLHomeController *s=weakSelf; if (!s) return;
            if (hidden) {
                [s.hiddenKinds removeObject:kind];
                if (![SOLHomePageKinds() containsObject:kind]) {
                    NSMutableArray *pages=[SOLHomePageKinds() mutableCopy]; [pages addObject:kind];
                    CFPreferencesSetAppValue(CFSTR("carouselPages"),(__bridge CFArrayRef)pages,(__bridge CFStringRef)SOLPreferenceDomain);
                    CFPreferencesAppSynchronize((__bridge CFStringRef)SOLPreferenceDomain); [SOLPreferences.shared reload];
                }
            } else [s.hiddenKinds addObject:kind];
            [s saveState]; [s refresh];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:self.expanded?@"收起":@"展开" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { SOLHomeController *s=weakSelf; [s setExpanded:!s.expanded animated:YES]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView=self.manageButton; sheet.popoverPresentationController.sourceRect=self.manageButton.bounds;
    [presenter presentViewController:sheet animated:YES completion:nil];
}
- (void)requestMedia {
    if (self.mediaRequestPending || self.surface.hidden || !self.mediaTitle) return;
    SOLHomeLoadMedia();
    self.playButton.enabled=SOLMRCommand!=NULL;
    if (!SOLMRInfo) { self.mediaArtist.text=@"系统媒体接口不可用"; return; }
    self.mediaRequestPending=YES; __weak typeof(self) weakSelf=self;
    SOLMRInfo(dispatch_get_main_queue(), ^(CFDictionaryRef info) {
        SOLHomeController *s=weakSelf; if (!s) return;
        s.mediaRequestPending=NO; s.mediaInfo=info ? [(__bridge NSDictionary *)info copy]:@{}; s.mediaSample=CACurrentMediaTime();
        NSString *title=SOLHomeString(s.mediaInfo[SOLMRKey("kMRMediaRemoteNowPlayingInfoTitle") ?: @"title"]);
        NSString *artist=SOLHomeString(s.mediaInfo[SOLMRKey("kMRMediaRemoteNowPlayingInfoArtist") ?: @"artist"]);
        s.mediaTitle.text=title.length?title:@"暂无正在播放"; s.mediaArtist.text=artist ?: @"打开音乐，开始播放";
        id data=s.mediaInfo[SOLMRKey("kMRMediaRemoteNowPlayingInfoArtworkData") ?: @"artworkData"];
        s.artwork.image=[data isKindOfClass:NSData.class] ? [UIImage imageWithData:data]:[UIImage systemImageNamed:@"music.note"];
        if (![SOLPreferences.shared boolForKey:@"colorWash" defaultValue:YES]) s.artwork.backgroundColor=UIColor.clearColor;
        else s.artwork.backgroundColor=[UIColor.systemIndigoColor colorWithAlphaComponent:.15];
        double rate=[s.mediaInfo[SOLMRKey("kMRMediaRemoteNowPlayingInfoPlaybackRate") ?: @"playbackRate"] doubleValue]; s.mediaPlaying=rate>0;
        [s.playButton setImage:[UIImage systemImageNamed:s.mediaPlaying?@"pause.fill":@"play.fill"] forState:UIControlStateNormal]; [s tick];
    });
    if (SOLMRPlaying) SOLMRPlaying(dispatch_get_main_queue(), ^(BOOL playing) {
        SOLHomeController *s=weakSelf; s.mediaPlaying=playing;
        [s.playButton setImage:[UIImage systemImageNamed:playing?@"pause.fill":@"play.fill"] forState:UIControlStateNormal];
    });
}
- (void)mediaChanged:(NSNotification *)note { [self requestMedia]; }
- (void)seek:(UISlider *)slider {
    NSTimeInterval duration=[self.mediaInfo[SOLMRKey("kMRMediaRemoteNowPlayingInfoDuration") ?: @"duration"] doubleValue];
    if (SOLMRSeek && duration>0 && isfinite(duration)) { SOLMRSeek(slider.value*duration); [self requestMedia]; }
}
- (void)publishCalendars {
    __weak typeof(self) weakSelf=self;
    dispatch_async(self.calendarQueue, ^{
        SOLHomeController *s=weakSelf; if (!s) return;
        NSMutableArray *published=[NSMutableArray array];
        if ([EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent]==EKAuthorizationStatusAuthorized) {
            if (!s.eventStore) s.eventStore=[EKEventStore new];
            @try {
                for (EKCalendar *calendar in [s.eventStore calendarsForEntityType:EKEntityTypeEvent]) {
                    CGFloat r=0,g=0,b=0,a=1;
                    UIColor *color=calendar.CGColor ? [UIColor colorWithCGColor:calendar.CGColor]:UIColor.systemBlueColor;
                    [color getRed:&r green:&g blue:&b alpha:&a];
                    NSString *hex=[NSString stringWithFormat:@"#%02X%02X%02X",(unsigned)lrint(r*255),(unsigned)lrint(g*255),(unsigned)lrint(b*255)];
                    if (calendar.calendarIdentifier.length) [published addObject:@{@"id":calendar.calendarIdentifier,@"title":calendar.title ?: @"日历",@"color":hex,@"account":calendar.source.title ?: @""}];
                }
            } @catch (NSException *exception) { SOLLog(@"calendar publication failed %@",exception.name); }
        }
        CFPreferencesSetAppValue(CFSTR("knownCalendars"),(__bridge CFArrayRef)published,(__bridge CFStringRef)SOLPreferenceDomain);
        CFPreferencesAppSynchronize((__bridge CFStringRef)SOLPreferenceDomain);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.oakstheawesome.solo/CalendarsPublished"),NULL,NULL,YES);
    });
}
- (void)reloadCalendar {
    if (!self.calendarRows || self.calendarPending || self.surface.hidden) return;
    EKAuthorizationStatus auth=[EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    self.calendarPermission.hidden=auth==EKAuthorizationStatusAuthorized;
    if (auth!=EKAuthorizationStatusAuthorized) {
        self.events=@[]; self.calendarStatus.hidden=NO; self.calendarRows.hidden=YES;
        self.calendarStatus.text=auth==EKAuthorizationStatusNotDetermined ? @"允许日历访问后，显示今天与明天的真实日程。":@"日历访问未授权，请在隐私设置中允许读取。";
        [self.calendarPermission setTitle:auth==EKAuthorizationStatusNotDetermined?@"允许读取日历":@"打开日历隐私设置" forState:UIControlStateNormal]; return;
    }
    self.calendarPending=YES; NSUInteger generation=++self.calendarGeneration;
    BOOL tomorrow=[SOLPreferences.shared boolForKey:@"calendarTomorrow" defaultValue:YES];
    BOOL allDay=[SOLPreferences.shared boolForKey:@"calendarAllDay" defaultValue:YES];
    id hidden=[SOLPreferences.shared objectForKey:@"hiddenCalendars"];
    NSSet *hiddenIDs=[hidden isKindOfClass:NSArray.class] ? [NSSet setWithArray:hidden]:[NSSet set];
    __weak typeof(self) weakSelf=self;
    dispatch_async(self.calendarQueue, ^{
        SOLHomeController *s=weakSelf; if (!s) return;
        if (!s.eventStore) s.eventStore=[EKEventStore new];
        NSArray *events=@[]; NSString *failure=nil;
        @try {
            NSDate *start=[NSCalendar.currentCalendar startOfDayForDate:NSDate.date];
            NSDate *end=[NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay value:tomorrow?2:1 toDate:start options:0];
            NSMutableArray *calendars=[NSMutableArray array];
            for (EKCalendar *c in [s.eventStore calendarsForEntityType:EKEntityTypeEvent]) if (![hiddenIDs containsObject:c.calendarIdentifier]) [calendars addObject:c];
            if (calendars.count) {
                NSPredicate *predicate=[s.eventStore predicateForEventsWithStartDate:start endDate:end calendars:calendars];
                NSArray *found=[s.eventStore eventsMatchingPredicate:predicate]; NSMutableArray *filtered=[NSMutableArray array];
                for (EKEvent *e in found) if ((allDay || !e.allDay) && [e.endDate compare:NSDate.date]!=NSOrderedAscending) [filtered addObject:e];
                events=[filtered sortedArrayUsingComparator:^NSComparisonResult(EKEvent *a,EKEvent *b) { return [a.startDate compare:b.startDate]; }];
            }
        } @catch (NSException *exception) { failure=@"无法读取日历，请检查系统日历权限。"; }
        dispatch_async(dispatch_get_main_queue(), ^{
            SOLHomeController *current=weakSelf; if (!current || generation!=current.calendarGeneration) return;
            current.calendarPending=NO; current.events=events;
            current.calendarStatus.text=failure ?: (events.count?@"":@"今天没有更多日程"); [current renderCalendar];
        });
    });
}
- (void)requestCalendarAccess {
    EKAuthorizationStatus auth=[EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if (auth!=EKAuthorizationStatusNotDetermined) {
        if (auth!=EKAuthorizationStatusAuthorized) SOLHomeOpenURL([NSURL URLWithString:@"App-prefs:Privacy&path=CALENDARS"]);
        else [self reloadCalendar]; return;
    }
    __weak typeof(self) weakSelf=self;
    dispatch_async(self.calendarQueue, ^{
        SOLHomeController *s=weakSelf; if (!s) return; if (!s.eventStore) s.eventStore=[EKEventStore new];
        void (^completion)(BOOL,NSError *)=^(BOOL granted,NSError *error) { dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf publishCalendars]; [weakSelf reloadCalendar]; }); };
        SEL modern=NSSelectorFromString(@"requestFullAccessToEventsWithCompletion:");
        if (SOLMethodMatchesEncoding(s.eventStore.class,modern,"v@:@?")) ((void (*)(id,SEL,id))objc_msgSend)(s.eventStore,modern,completion);
        else [s.eventStore requestAccessToEntityType:EKEntityTypeEvent completion:completion];
    });
}
- (void)renderCalendar {
    if (!self.calendarRows) return;
    for (UIView *v in self.calendarRows.subviews) [v removeFromSuperview];
    BOOL authorized=[EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent]==EKAuthorizationStatusAuthorized;
    self.calendarStatus.hidden=authorized && self.events.count>0; self.calendarRows.hidden=!authorized;
    self.calendarPermission.hidden=authorized;
    if (!authorized) return;
    if (!self.events.count) { if (!self.calendarStatus.text.length) self.calendarStatus.text=@"今天没有更多日程"; return; }
    CGFloat h=self.calendarRows.bounds.size.height,w=self.calendarRows.bounds.size.width;
    BOOL compact=[SOLPreferences.shared integerForKey:@"calendarLayout" defaultValue:0]!=0;
    CGFloat rowH=compact?35:45; NSUInteger count=MIN(self.events.count,(NSUInteger)MAX(1,floor(h/rowH)));
    NSDateFormatter *f=[NSDateFormatter new]; f.timeStyle=NSDateFormatterShortStyle;
    for (NSUInteger i=0;i<count;i++) {
        EKEvent *e=self.events[i]; NSString *time=e.allDay?@"全天":[f stringFromDate:e.startDate];
        if (![NSCalendar.currentCalendar isDateInToday:e.startDate]) time=[@"明天 " stringByAppendingString:time];
        NSString *title=[NSString stringWithFormat:@"%@  %@",time,e.title ?: @"未命名日程"];
        UIButton *button=[self buttonIn:self.calendarRows title:title symbol:nil action:@"event"];
        button.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft; button.titleLabel.font=[UIFont systemFontOfSize:compact?13:14 weight:UIFontWeightMedium];
        button.frame=CGRectMake(4,i*rowH,MAX(0,w-8),rowH-2); button.titleLabel.lineBreakMode=NSLineBreakByTruncatingTail;
        objc_setAssociatedObject(button,SOLHomePayloadKey,e.startDate,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIView *stripe=[[UIView alloc] initWithFrame:CGRectMake(0,7,3,rowH-14)];
        stripe.backgroundColor=e.calendar.CGColor ? [UIColor colorWithCGColor:e.calendar.CGColor]:UIColor.systemBlueColor;
        stripe.layer.cornerRadius=1.5; [button addSubview:stripe];
    }
}
- (void)action:(NSString *)action sender:(id)sender {
    if (![action isKindOfClass:NSString.class]) return;
    if ([action isEqualToString:@"expand"]) { [self setExpanded:!self.expanded animated:YES]; return; }
    if ([action isEqualToString:@"collapse"]) { [self setExpanded:NO animated:YES]; return; }
    if ([action isEqualToString:@"manage"]) { [self managePages]; return; }
    if ([action isEqualToString:@"restore"]) { [self.hiddenKinds removeAllObjects]; [self saveState]; [self refresh]; return; }
    if ([action isEqualToString:@"hide"]) { if (self.selectedKind) [self.hiddenKinds addObject:self.selectedKind]; [self saveState]; [self refresh]; return; }
    if ([action isEqualToString:@"clock"]) { SOLHomeOpenURL([NSURL URLWithString:@"clock-alarm:"]); return; }
    if ([action isEqualToString:@"calendar"]) { SOLHomeOpenURL([NSURL URLWithString:@"calshow:"]); return; }
    if ([action isEqualToString:@"calendarAccess"]) { [self requestCalendarAccess]; return; }
    if ([action isEqualToString:@"event"]) {
        id date=objc_getAssociatedObject(sender,SOLHomePayloadKey);
        NSTimeInterval t=[date isKindOfClass:NSDate.class] ? [date timeIntervalSinceReferenceDate]:NSDate.date.timeIntervalSinceReferenceDate;
        SOLHomeOpenURL([NSURL URLWithString:[NSString stringWithFormat:@"calshow:%.0f",t]]); return;
    }
    if ([action isEqualToString:@"shortcut"]) {
        NSDictionary *entry=objc_getAssociatedObject(sender,SOLHomePayloadKey); if (entry) SOLHomeExecuteShortcut(entry,[sender isKindOfClass:UIView.class]?sender:self.surface); return;
    }
    if ([action isEqualToString:@"playPause"] || [action isEqualToString:@"previous"] || [action isEqualToString:@"next"]) {
        if (SOLMRCommand) { uint32_t command=[action isEqualToString:@"playPause"]?2:[action isEqualToString:@"previous"]?5:4; SOLMRCommand(command,NULL); [self requestMedia]; }
        return;
    }
    if ([action isEqualToString:@"artwork"]) {
        if (SOLMRPID) SOLMRPID(dispatch_get_main_queue(), ^(int pid) {
            id controller=SOLHomeObject(NSClassFromString(@"SBApplicationController"),@"sharedInstance");
            SEL selector=NSSelectorFromString(@"applicationWithPid:"); id app=nil;
            if (pid>0 && SOLMethodMatchesEncoding([controller class],selector,"@@:i")) app=((id (*)(id,SEL,int))objc_msgSend)(controller,selector,pid);
            NSString *identifier=SOLHomeString(SOLHomeObject(app,@"bundleIdentifier"));
            if (identifier) SOLHomeExecuteShortcut(@{@"bundleID":identifier},self.artwork); else SOLHomeOpenURL([NSURL URLWithString:@"music:"]);
        }); else SOLHomeOpenURL([NSURL URLWithString:@"music:"]);
    }
}
@end

static void SOLHomeCalendarRequested(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(),^{ [(__bridge SOLHomeController *)observer publishCalendars]; });
}
static SOLHomeController *SOLHomeSharedController(void) {
    static SOLHomeController *controller; static dispatch_once_t once;
    dispatch_once(&once,^{ controller=[SOLHomeController new]; }); return controller;
}
static NSString *SOLHomeString(id value) { return [value isKindOfClass:NSString.class] ? value:nil; }
static id SOLHomeObject(id object, NSString *name) {
    if (!object) return nil; SEL selector=NSSelectorFromString(name);
    Class cls=object_isClass(object) ? object_getClass(object):[object class];
    if (!SOLMethodMatchesEncoding(cls,selector,"@@:")) return nil;
    return ((id (*)(id,SEL))objc_msgSend)(object,selector);
}
static UIView *SOLHomeFindView(UIView *view, NSString *name, NSUInteger depth) {
    if (!view || depth>12) return nil;
    Class cls=NSClassFromString(name); if (cls && [view isKindOfClass:cls]) return view;
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:SOLHomeSurface.class]) continue;
        UIView *found=SOLHomeFindView(child,name,depth+1); if (found) return found;
    }
    return nil;
}
static NSString *SOLHomeStatePath(void) {
    /* Separate versioned recovery state: never overwrite original widget model. */
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/Solo/HomeRecoveryState.plist"];
}
static NSArray<NSString *> *SOLHomePageKinds(void) {
    id raw=[SOLPreferences.shared objectForKey:@"carouselPages"];
    NSArray *known=@[@"widget",@"media",@"clock",@"calendar",@"shortcuts"];
    NSArray *defaults=@[@"widget",@"media",@"clock",@"calendar"];
    if (![raw isKindOfClass:NSArray.class] || ![raw count]) return defaults;
    NSMutableOrderedSet *result=[NSMutableOrderedSet orderedSet];
    for (id entry in raw) {
        NSString *kind=SOLHomeString(entry);
        if (kind && [known containsObject:kind]) [result addObject:kind];
    }
    return result.count ? result.array:defaults;
}
static void SOLHomeSetFrameIfChanged(UIView *view, CGRect frame) {
    if (view && isfinite(frame.origin.x) && isfinite(frame.origin.y) && isfinite(frame.size.width) && isfinite(frame.size.height) && !CGRectEqualToRect(view.frame,frame)) view.frame=frame;
}
static NSString *SOLMRKey(const char *symbol) {
    if (!SOLHomeMediaHandle) return nil;
    CFStringRef *value=dlsym(SOLHomeMediaHandle,symbol); return value && *value ? (__bridge NSString *)*value:nil;
}
static void SOLHomeLoadMedia(void) {
    static BOOL attempted=NO; if (attempted) return; attempted=YES;
    SOLHomeMediaHandle=dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_LAZY|RTLD_LOCAL);
    if (!SOLHomeMediaHandle) return;
    SOLMRInfo=dlsym(SOLHomeMediaHandle,"MRMediaRemoteGetNowPlayingInfo");
    SOLMRPlaying=dlsym(SOLHomeMediaHandle,"MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    SOLMRCommand=dlsym(SOLHomeMediaHandle,"MRMediaRemoteSendCommand");
    SOLMRSeek=dlsym(SOLHomeMediaHandle,"MRMediaRemoteSetElapsedTime");
    SOLMRPID=dlsym(SOLHomeMediaHandle,"MRMediaRemoteGetNowPlayingApplicationPID");
    SOLMRRegister=dlsym(SOLHomeMediaHandle,"MRMediaRemoteRegisterForNowPlayingNotifications");
    if (SOLMRRegister) SOLMRRegister(dispatch_get_main_queue());
}
static BOOL SOLHomeOpenURL(NSURL *url) {
    if (!url) return NO;
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil]; return YES;
}
static void SOLHomeExecuteShortcut(NSDictionary *action, UIView *source) {
    if (![action isKindOfClass:NSDictionary.class]) return;
    NSArray<NSDictionary *> *(*records)(NSString *)=dlsym(RTLD_DEFAULT,"SOLActionRecords");
    BOOL (*perform)(NSDictionary *)=dlsym(RTLD_DEFAULT,"SOLActionPerform");
    (void)records;
    if (perform) {
        NSMutableDictionary *record=[action mutableCopy];
        if (!record[@"type"]) {
            NSString *bundle=SOLHomeString(record[@"bundleID"]) ?: SOLHomeString(record[@"bundleIdentifier"]);
            NSString *url=SOLHomeString(record[@"url"]); NSString *shortcut=SOLHomeString(record[@"shortcut"]) ?: SOLHomeString(record[@"shortcutName"]);
            if (bundle) { record[@"type"]=@"app"; record[@"value"]=bundle; }
            else if (url) { record[@"type"]=@"url"; record[@"value"]=url; }
            else if (shortcut) { record[@"type"]=@"shortcut"; record[@"value"]=shortcut; }
            else { record[@"type"]=@"tool"; record[@"value"]=record[@"id"] ?: @""; }
        }
        perform(record); return;
    }
    NSString *url=SOLHomeString(action[@"url"]);
    if (url.length) { SOLHomeOpenURL([NSURL URLWithString:url]); return; }
    NSString *shortcut=SOLHomeString(action[@"shortcut"]) ?: SOLHomeString(action[@"shortcutName"]);
    if (shortcut.length) {
        NSURLComponents *components=[NSURLComponents componentsWithString:@"shortcuts://run-shortcut"];
        components.queryItems=@[[NSURLQueryItem queryItemWithName:@"name" value:shortcut]]; SOLHomeOpenURL(components.URL); return;
    }
    NSString *bundle=SOLHomeString(action[@"bundleID"]) ?: SOLHomeString(action[@"bundleIdentifier"]);
    if (!bundle.length) return;
    id workspace=SOLHomeObject(NSClassFromString(@"LSApplicationWorkspace"),@"defaultWorkspace");
    SEL selector=NSSelectorFromString(@"openApplicationWithBundleID:");
    if (SOLMethodMatchesEncoding([workspace class],selector,"B@:@")) ((BOOL (*)(id,SEL,id))objc_msgSend)(workspace,selector,bundle);
}
void SOLHomeRefresh(void) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{ SOLHomeRefresh(); }); return; }
    SOLHomeController *controller=SOLHomeSharedController();
    if (!controller.root || !controller.root.window) {
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            UIView *root=SOLHomeFindView(window,@"SBRootFolderView",0); if (root.window) { [controller observeRoot:root]; break; }
        }
    }
    [controller refresh];
}
void SOLHomeObserveRoot(UIView *root) { if (NSThread.isMainThread) [SOLHomeSharedController() observeRoot:root]; }
void SOLHomeObserveDock(UIView *dock) {
    if (!NSThread.isMainThread) return;
    Class cls=NSClassFromString(@"SBRootFolderView"); UIView *view=dock;
    while (view && cls && ![view isKindOfClass:cls]) view=view.superview;
    if (view) { SOLHomeSharedController().dock=dock; SOLHomeObserveRoot(view); }
}
CGRect SOLHomeAdjustedNativeFrame(UIView *view, CGRect requestedFrame) {
    SOLHomeController *s=SOLHomeSharedController();
    if (s.applyingLayout || !s.root || !view.superview || ![view isDescendantOfView:s.root]) return requestedFrame;
    [s.nativeFrames setObject:[NSValue valueWithCGRect:requestedFrame] forKey:view];
    if (s.surface.hidden || !SOLPreferences.shared.enabled || s.suppression.count) return requestedFrame;
    CGRect frame=[view.superview convertRect:requestedFrame toView:s.root];
    CGFloat bottom=CGRectGetMaxY(frame),top=MAX(CGRectGetMinY(frame),CGRectGetMaxY(s.surface.frame)+8);
    if (bottom-top<100) return requestedFrame;
    frame.origin.y=top; frame.size.height=bottom-top;
    return [s.root convertRect:frame toView:view.superview];
}
void SOLHomeSetSuppressed(NSString *reason, BOOL suppressed) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{ SOLHomeSetSuppressed(reason,suppressed); }); return; }
    SOLHomeController *s=SOLHomeSharedController();
    if (suppressed) [s.suppression addObject:reason]; else [s.suppression removeObject:reason];
    [s applyLayout];
}
void SOLHomeHandleAction(NSString *action,id sender) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{ SOLHomeHandleAction(action,sender); }); return; }
    [SOLHomeSharedController() action:action sender:sender];
}
void SOLHomeTick(void) { if (NSThread.isMainThread) { [SOLHomeSharedController() tick]; [SOLHomeSharedController() requestMedia]; } }
void SOLHomeApplyExpansion(CGFloat progress) { if (isfinite(progress)) [SOLHomeSharedController() setExpanded:progress>=.5 animated:NO]; }
BOOL SOLHomeShouldBeginPan(UIPanGestureRecognizer *pan) {
    CGPoint v=[pan velocityInView:pan.view]; return fabs(v.x)>fabs(v.y) && ![SOLHomeSharedController().selectedKind isEqualToString:@"media"];
}
BOOL SOLHomeGestureShouldReceiveTouch(UITouch *touch) {
    UIView *v=touch.view; while (v) { if ([v isKindOfClass:UIControl.class]) return NO; if ([v isKindOfClass:SOLHomeSurface.class]) break; v=v.superview; } return YES;
}
