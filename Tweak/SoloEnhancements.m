#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "SOLActionsInternal.h"
#import "SOLPreferences.h"
#import "SOLHookRuntime.h"

/* Reconstructed enhancement layer: vertical action rail, material backdrop,
 * app/action data pipeline and optional SpringBoard integration. */

@implementation SXShortcutBackdropView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.layer.cornerRadius = 22.0;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.clipsToBounds = YES;
        [self updateAppearance];
    }
    return self;
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    [self updateAppearance];
}
- (void)setStyleIdentifier:(NSString *)styleIdentifier {
    _styleIdentifier = [styleIdentifier copy];
    [self updateAppearance];
}
- (void)updateAppearance {
    if (!self.material) {
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
        self.material = [[UIVisualEffectView alloc] initWithEffect:effect];
        self.material.userInteractionEnabled = NO;
        [self addSubview:self.material];
    }
    self.material.frame = self.bounds;
    self.material.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (!self.wash) self.wash = [CAGradientLayer layer];
    self.wash.frame = self.bounds;
    self.wash.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.12].CGColor,
                         (id)[UIColor colorWithWhite:0 alpha:0.08].CGColor];
    self.wash.startPoint = CGPointMake(0.5, 0); self.wash.endPoint = CGPointMake(0.5, 1);
    if (!self.wash.superlayer) [self.layer addSublayer:self.wash];
}
- (void)layoutSubviews { [super layoutSubviews]; [self updateAppearance]; }
@end

@implementation SXGridLayout
- (CGSize)collectionViewContentSize {
    NSInteger count = [self.collectionView numberOfItemsInSection:0];
    CGFloat w = MAX(self.collectionView.bounds.size.width, 1);
    CGFloat row = self.rowHeight > 1 ? self.rowHeight : 82.0;
    NSInteger columns = MAX((NSInteger)floor(w / 84.0), 1);
    NSInteger rows = (count + columns - 1) / columns;
    return self.vertical ? CGSizeMake(w, rows * row) : CGSizeMake(MAX(columns, count) * 84.0, row);
}
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewLayoutAttributes *a = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    CGFloat w = MAX(self.collectionView.bounds.size.width, 1);
    CGFloat row = self.rowHeight > 1 ? self.rowHeight : 82.0;
    NSInteger columns = MAX((NSInteger)floor(w / 84.0), 1);
    NSInteger i = indexPath.item;
    if (self.vertical) {
        CGFloat cellW = w / columns;
        a.frame = CGRectMake((i % columns) * cellW + 3, (i / columns) * row + 3, cellW - 6, row - 6);
    } else {
        a.frame = CGRectMake(i * 84.0 + 3, 3, 78, row - 6);
    }
    return a;
}
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSInteger n = [self.collectionView numberOfItemsInSection:0];
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:n];
    for (NSInteger i = 0; i < n; i++) {
        NSIndexPath *p = [NSIndexPath indexPathForItem:i inSection:0];
        UICollectionViewLayoutAttributes *a = [self layoutAttributesForItemAtIndexPath:p];
        if (CGRectIntersectsRect(rect, a.frame)) [out addObject:a];
    }
    return out;
}
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds { return YES; }
@end

@implementation SXAxisCollection
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (![gesture isKindOfClass:[UIPanGestureRecognizer class]]) return YES;
    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
    CGPoint v = [pan velocityInView:self];
    return self.vertical ? fabs(v.y) >= fabs(v.x) : fabs(v.x) >= fabs(v.y);
}
@end

@implementation SXActionCell
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.clearColor;
        self.icon = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.icon.contentMode = UIViewContentModeScaleAspectFit;
        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.nameLabel.textAlignment = NSTextAlignmentCenter;
        self.nameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
        self.nameLabel.numberOfLines = 2;
        [self.contentView addSubview:self.icon]; [self.contentView addSubview:self.nameLabel];
    }
    return self;
}
- (void)setAction:(NSDictionary *)action {
    _action = [action copy];
    self.representedID = action[@"id"] ?: action[@"identifier"];
    self.nameLabel.text = action[@"title"] ?: action[@"name"] ?: self.representedID;
    UIImage *image = SOLActionImage(action);
    self.icon.image = image ?: [UIImage systemImageNamed:@"app"];
    self.icon.tintColor = UIColor.labelColor;
    self.nameLabel.textColor = UIColor.labelColor;
    NSString *reason = SOLActionUnavailableReason(action);
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = self.nameLabel.text;
    self.accessibilityHint = reason ?: @"轻点执行；长按组件编辑";
    self.contentView.alpha = reason ? 0.5 : 1.0;
    [self applyState:SOLActionState(action)];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat iconH = MIN(self.bounds.size.width, self.iconSize > 1 ? self.iconSize : 42.0);
    self.icon.frame = CGRectMake((self.bounds.size.width-iconH)/2, 5, iconH, iconH);
    self.nameLabel.frame = CGRectMake(3, iconH+8, self.bounds.size.width-6, self.bounds.size.height-iconH-10);
}
- (void)prepareForReuse { [super prepareForReuse]; self.action = nil; self.icon.image = nil; self.nameLabel.text = nil; }
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; self.alpha = highlighted ? 0.55 : 1.0; }
- (void)applyState:(NSNumber *)state {
    self.displayedState = state;
    self.contentView.backgroundColor = state.boolValue ? [UIColor.systemBlueColor colorWithAlphaComponent:0.22] : UIColor.clearColor;
    self.contentView.layer.cornerRadius = 14;
    self.accessibilityValue = state ? (state.boolValue ? @"开启" : @"关闭") : nil;
}
@end

static char SOLAViewPreferenceKey;
@interface SXActionView ()
- (void)actionStateChanged:(NSNotification *)notification;
- (void)sol_preferencesReloaded:(NSNotification *)notification;
- (void)sol_edit:(UILongPressGestureRecognizer *)gesture;
- (void)changePage;
@end
@implementation SXActionView
- (instancetype)initVertical:(BOOL)vertical {
    if ((self = [super initWithFrame:CGRectZero])) {
        _vertical = vertical; _iconSize = 42.0;
        self.backgroundColor = UIColor.clearColor; self.clipsToBounds=YES;
        self.grid=[SXGridLayout new]; self.grid.vertical=vertical; self.grid.rowHeight=82;
        self.collection=[[SXAxisCollection alloc] initWithFrame:CGRectZero collectionViewLayout:self.grid];
        self.collection.vertical=vertical; self.collection.backgroundColor=UIColor.clearColor;
        self.collection.dataSource=(id)self; self.collection.delegate=(id)self;
        self.collection.alwaysBounceVertical=vertical; self.collection.directionalLockEnabled=YES;
        self.collection.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;
        self.collection.showsHorizontalScrollIndicator=NO;
        [self.collection registerClass:SXActionCell.class forCellWithReuseIdentifier:@"SXActionCell"];
        [self addSubview:self.collection];
        self.pages=[UIPageControl new]; self.pages.hidesForSinglePage=YES;
        [self.pages addTarget:self action:@selector(changePage) forControlEvents:UIControlEventValueChanged]; [self addSubview:self.pages];
        self.emptyLabel=[UILabel new]; self.emptyLabel.text=@"暂无快捷项目\n长按添加"; self.emptyLabel.numberOfLines=2;
        self.emptyLabel.textAlignment=NSTextAlignmentCenter; self.emptyLabel.textColor=UIColor.secondaryLabelColor;
        self.emptyLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleCaption1]; [self addSubview:self.emptyLabel];
        UILongPressGestureRecognizer *edit=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sol_edit:)];
        edit.minimumPressDuration=0.6; [self addGestureRecognizer:edit];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(sol_preferencesReloaded:) name:@"com.oakstheawesome.solo/preferencesDidReload" object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(actionStateChanged:) name:SOLActionsChangedNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(actionStateChanged:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [self sol_setPreferenceKey:@"sxShortcutActions"];
    }
    return self;
}
- (void)sol_setPreferenceKey:(NSString *)key { objc_setAssociatedObject(self,&SOLAViewPreferenceKey,key,OBJC_ASSOCIATION_COPY_NONATOMIC); [self reloadActions:nil]; }
- (void)sol_preferencesReloaded:(NSNotification *)notification { [self reloadActions:nil]; }
- (void)didMoveToWindow { [super didMoveToWindow]; if(self.window){[self reloadActions:nil];[self refreshToolStates];} }
- (void)dealloc { [self.stateTimer invalidate]; [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    self.collection.frame=self.bounds;
    self.pages.frame=CGRectMake(0,MAX(0,self.bounds.size.height-20),self.bounds.size.width,20);
    self.pages.hidden=self.vertical || self.collection.contentSize.width<=self.bounds.size.width;
    self.emptyLabel.frame=self.bounds; self.emptyLabel.hidden=self.actions.count>0;
    self.pages.numberOfPages=MAX(1,(NSInteger)ceil(self.collection.contentSize.width/MAX(1,self.bounds.size.width)));
}
- (void)reloadActions:(NSArray *)actions {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{[self reloadActions:actions];}); return; }
    NSString *key=objc_getAssociatedObject(self,&SOLAViewPreferenceKey) ?: @"sxShortcutActions";
    NSArray *records=actions ?: SOLActionRecords(key);
    NSMutableArray *enabled=[NSMutableArray array];
    for(id record in records) { NSDictionary *r=SOLANormalizeRecord(record); if(r && [r[@"enabled"] boolValue])[enabled addObject:r]; }
    self.actions=enabled;
    self.iconSize=MIN(72,MAX(24,[[SOLPreferences shared] doubleForKey:self.vertical ? @"sxDockIconSize" : @"sxShortcutIconSize" defaultValue:42]));
    self.grid.rowHeight=self.iconSize+40;
    [self.collection reloadData]; [self.grid invalidateLayout]; [self setNeedsLayout];
}
- (void)actionStateChanged:(NSNotification *)notification { [self refreshToolStates]; }
- (void)refreshToolStates {
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self refreshToolStates];});return;}
    for(SXActionCell *cell in self.collection.visibleCells) [cell applyState:SOLActionState(cell.action)];
}
- (void)sol_edit:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state==UIGestureRecognizerStateBegan) SOLPresentActionEditor(objc_getAssociatedObject(self,&SOLAViewPreferenceKey) ?: @"sxShortcutActions",nil);
}
- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section { return self.actions.count; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)path {
    SXActionCell *cell=[cv dequeueReusableCellWithReuseIdentifier:@"SXActionCell" forIndexPath:path];
    if(path.item<self.actions.count){cell.iconSize=self.iconSize;cell.action=self.actions[path.item];}return cell;
}
- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)path {
    [cv deselectItemAtIndexPath:path animated:YES]; if(path.item>=self.actions.count)return;
    SOLActionPerform(self.actions[path.item]); [self refreshToolStates];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { self.pages.currentPage=(NSInteger)round(scrollView.contentOffset.x/MAX(1,scrollView.bounds.size.width)); }
- (void)changePage { [self.collection setContentOffset:CGPointMake(self.pages.currentPage*self.collection.bounds.size.width,0) animated:YES]; }
@end

@implementation SXVerticalPanProxy
- (CGPoint)translationInView:(UIView *)view { return [self.real translationInView:view]; }
- (CGPoint)velocityInView:(UIView *)view { return [self.real velocityInView:view]; }
@end

static void SXInstallEnhancementHooks(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSNotificationCenter.defaultCenter addObserverForName:@"com.oakstheawesome.solo/HomeActionRequested" object:nil queue:nil usingBlock:^(NSNotification *notification) {
            if (![notification.object isKindOfClass:NSMutableDictionary.class]) return;
            NSMutableDictionary *request=notification.object;
            if ([request[@"handled"] boolValue] || ![request[@"action"] isKindOfClass:NSDictionary.class]) return;
            /* handled means consumed, not succeeded. Avoid duplicate fallback execution. */
            request[@"handled"]=@YES;
            NSError *error=nil;
            BOOL success=SOLActionPerformWithError(request[@"action"],&error);
            request[@"success"]=@(success);
            if(error){request[@"error"]=error.localizedDescription;SOLActionShowMessage(error.localizedDescription);}
        }];
    });
}

__attribute__((constructor)) static void SoloEnhancementsConstructor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *bundle = [NSBundle mainBundle].bundleIdentifier;
        if ([bundle isEqualToString:@"com.apple.springboard"] || [bundle isEqualToString:@"com.apple.Preferences"]) {
            SXInstallEnhancementHooks();
        }
    });
}
