#import "SOLActionsInternal.h"
#import "SOLPreferences.h"
#import "SOLHookRuntime.h"

/* Original enhancements hooked SBDockIconListView.layoutSubviews and
 * didMoveToWindow at 0x1dfb4 / 0x1dffc. We attach a source-level rail to its
 * home root without reading old dylib globals or suppressing native icons. */
@interface SOLActionRail : UIView
@property(nonatomic,strong) UIButton *handle;
@property(nonatomic,strong) SXActionView *actions;
@property(nonatomic,strong) UIVisualEffectView *backdrop;
@property(nonatomic,assign) BOOL expanded;
- (void)refresh;
@end
static NSHashTable<SOLActionRail *> *SOLARails;
static void SOLARailObserveDock(UIView *dock);
static void SOLARailInstallHooks(void);
static void (*SOLAOriginalDockMove)(id,SEL);
static void (*SOLAOriginalDockLayout)(id,SEL);
static char SOLARailKey;

@implementation SOLActionRail
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.handle=[UIButton buttonWithType:UIButtonTypeSystem];
        [self.handle setImage:[UIImage systemImageNamed:@"sidebar.left"] forState:UIControlStateNormal];
        self.handle.backgroundColor=[UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.94];
        self.handle.layer.cornerRadius=18; self.handle.accessibilityLabel=@"Solo 快捷侧栏";
        self.handle.accessibilityHint=@"轻点展开快捷动作，长按编辑";
        [self.handle addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.handle];
        UILongPressGestureRecognizer *edit=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(edit:)];
        [self.handle addGestureRecognizer:edit];
        self.backdrop=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
        self.backdrop.layer.cornerRadius=20; self.backdrop.clipsToBounds=YES; [self addSubview:self.backdrop];
        self.actions=(SXActionView *)SOLCreateActionView(YES,@"sxShortcutActions");
        [self.backdrop.contentView addSubview:self.actions];
        [self refresh];
    }
    return self;
}
- (void)toggle { self.expanded=!self.expanded; [self refresh]; }
- (void)edit:(UILongPressGestureRecognizer *)gesture { if(gesture.state==UIGestureRecognizerStateBegan) SOLPresentActionEditor(@"sxShortcutActions",nil); }
- (void)refresh {
    SOLPreferences *p=SOLPreferences.shared;
    self.hidden=!p.enabled || !p.enhancementsEnabled || [p boolForKey:@"sxHideSidebar" defaultValue:NO];
    self.backdrop.hidden=!self.expanded;
    if(!self.superview)return;
    CGRect bounds=self.superview.bounds;
    CGFloat height=MIN(390,MAX(120,bounds.size.height-self.superview.safeAreaInsets.top-self.superview.safeAreaInsets.bottom-170));
    CGFloat left=MAX(2,self.superview.safeAreaInsets.left+2);
    self.frame=CGRectMake(left,MAX(self.superview.safeAreaInsets.top+48,(bounds.size.height-height)*0.5),self.expanded?124:36,height);
    self.handle.frame=CGRectMake(0,(height-52)*0.5,32,52);
    self.backdrop.frame=CGRectMake(36,0,88,height);
    self.actions.frame=self.backdrop.bounds;
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if(self.hidden || !self.userInteractionEnabled)return nil;
    UIView *hit=[super hitTest:point withEvent:event];
    return hit==self ? nil : hit;
}
@end

void SOLAttachActionRail(UIView *host) {
    if(!SOLAIsSpringBoard() || ![host isKindOfClass:UIView.class])return;
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{SOLAttachActionRail(host);});return;}
    SOLActionRail *rail=objc_getAssociatedObject(host,&SOLARailKey);
    if(!rail) {
        rail=[[SOLActionRail alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(host,&SOLARailKey,rail,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [host addSubview:rail];
        if(!SOLARails)SOLARails=[NSHashTable weakObjectsHashTable]; [SOLARails addObject:rail];
    }
    [rail refresh];
}
static void SOLARailObserveDock(UIView *dock) {
    if(![dock isKindOfClass:UIView.class])return;
    Class rootClass=NSClassFromString(@"SBRootFolderView");
    UIView *root=dock; while(root && ![root isKindOfClass:rootClass])root=root.superview;
    if(root) SOLAttachActionRail(root);
}
static void SOLARailMove(id self,SEL cmd) { if(SOLAOriginalDockMove)SOLAOriginalDockMove(self,cmd); SOLARailObserveDock(self); }
static void SOLARailLayout(id self,SEL cmd) { if(SOLAOriginalDockLayout)SOLAOriginalDockLayout(self,cmd); SOLARailObserveDock(self); }
static void SOLARailFindRoots(UIView *view,NSUInteger depth) {
    if(depth>12 || !view)return;
    Class root=NSClassFromString(@"SBRootFolderView");
    if(root && [view isKindOfClass:root]) {SOLAttachActionRail(view);return;}
    for(UIView *child in view.subviews)SOLARailFindRoots(child,depth+1);
}
static void SOLARailInstallHooks(void) {
    Class dock=NSClassFromString(@"SBDockIconListView");
    SOLInstallTypedMessageHookOnce(@"Solo.Actions.Dock.move",dock,@selector(didMoveToWindow),"v@:",(IMP)SOLARailMove,(IMP *)&SOLAOriginalDockMove);
    SOLInstallTypedMessageHookOnce(@"Solo.Actions.Dock.layout",dock,@selector(layoutSubviews),"v@:",(IMP)SOLARailLayout,(IMP *)&SOLAOriginalDockLayout);
}
__attribute__((constructor)) static void SOLARailStart(void) {
    dispatch_async(dispatch_get_main_queue(),^{
        if(!SOLAIsSpringBoard())return;
        SOLARailInstallHooks();
        for(UIWindow *window in UIApplication.sharedApplication.windows) SOLARailFindRoots(window,0);
        SOLObserveReload(^{
            SOLARailInstallHooks();
            for(SOLActionRail *rail in SOLARails) [rail refresh];
        });
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
            SOLARailInstallHooks(); for(UIWindow *window in UIApplication.sharedApplication.windows)SOLARailFindRoots(window,0);
        }];
    });
}
