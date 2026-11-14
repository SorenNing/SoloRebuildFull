#import "SOLActionsInternal.h"
#import "SOLPreferences.h"
#import "SOLHookRuntime.h"
#import <MediaPlayer/MediaPlayer.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <notify.h>

@interface SXLIconPipeline (SOLRecovered)
- (void)invalidate;
- (void)request:(NSString *)bundleID size:(CGFloat)size isCurrent:(BOOL (^)(void))isCurrent completion:(void (^)(UIImage *))completion;
@end

@implementation SXLAppInfo
@end

@implementation SXLAppCenter
+ (instancetype)sharedCenter { static id center; static dispatch_once_t once; dispatch_once(&once,^{center=[self new];}); return center; }
- (instancetype)init {
    if ((self=[super init])) {
        self.mutableApplications=[NSMutableArray array]; self.applicationMap=[NSMutableDictionary dictionary];
        self.iconCache=[NSCache new]; self.iconCache.countLimit=128; self.iconCache.totalCostLimit=8*1024*1024;
    }
    return self;
}
- (id)installedApplications { return [self.mutableApplications copy]; }
- (void)reloadInstalledApplications { [self reloadFromApplicationWorkspace]; }
- (void)reloadFromApplicationWorkspace {
    id workspace=SOLAShared(@"LSApplicationWorkspace");
    id applications=SOLAObject(workspace,@"allInstalledApplications") ?: SOLAObject(workspace,@"allApplications");
    if (![applications isKindOfClass:NSArray.class]) {
        self.applicationController=SOLAShared(@"SBApplicationController");
        applications=SOLAObject(self.applicationController,@"allApplications");
    }
    if (![applications isKindOfClass:NSArray.class]) { SOLLog(@"installed application inventory unavailable"); return; }
    NSMutableArray *records=[NSMutableArray array]; NSMutableDictionary *map=[NSMutableDictionary dictionary];
    for (id application in applications) {
        id bundle=SOLAObject(application,@"applicationIdentifier") ?: SOLAObject(application,@"bundleIdentifier");
        if (![bundle isKindOfClass:NSString.class] || ![bundle length] || map[bundle]) continue;
        id title=SOLAObject(application,@"localizedName") ?: SOLAObject(application,@"displayName");
        SXLAppInfo *info=[SXLAppInfo new]; info.bundleIdentifier=bundle;
        info.displayName=[title isKindOfClass:NSString.class] ? title : bundle;
        info.privateApplication=application; map[bundle]=info; [records addObject:info];
    }
    [records sortUsingComparator:^NSComparisonResult(SXLAppInfo *a,SXLAppInfo *b){return [a.displayName localizedStandardCompare:b.displayName];}];
    self.mutableApplications=records; self.applicationMap=map; self.workspaceMapLoaded=YES;
    [self.iconCache removeAllObjects]; [self invalidatePreparedIcons];
}
- (SXLAppInfo *)applicationForBundleID:(NSString *)bundleID { return self.applicationMap[bundleID]; }
- (SXLAppInfo *)ensureApplicationForBundleID:(NSString *)bundleID {
    SXLAppInfo *info=[self applicationForBundleID:bundleID]; if (info) return info;
    if (!self.workspaceMapLoaded) { [self reloadInstalledApplications]; info=[self applicationForBundleID:bundleID]; if (info) return info; }
    id app=SOLAInvoke(SOLAShared(@"SBApplicationController"),@"applicationWithBundleIdentifier:",@"object",@[@"object"],@[bundleID],NULL);
    if (!app) return nil;
    info=[SXLAppInfo new]; info.bundleIdentifier=bundleID; info.privateApplication=app;
    id title=SOLAObject(app,@"displayName"); info.displayName=[title isKindOfClass:NSString.class] ? title : bundleID;
    self.applicationMap[bundleID]=info; [self.mutableApplications addObject:info]; return info;
}
- (UIImage *)iconForPrivateApplication:(id)application bundleID:(NSString *)bundleID {
    id image=SOLAObject(application,@"icon") ?: SOLAObject(application,@"applicationIcon");
    return [image isKindOfClass:UIImage.class] ? image : nil;
}
- (UIImage *)iconForBundleID:(NSString *)bundleID {
    if (!bundleID.length) return nil;
    UIImage *image=[self.iconCache objectForKey:bundleID]; if (image) return image;
    id result=SOLAInvoke(UIImage.class,@"_applicationIconImageForBundleIdentifier:format:scale:",@"object",@[@"object",@"number",@"number"],@[bundleID,@0,@(UIScreen.mainScreen.scale)],NULL);
    if ([result isKindOfClass:UIImage.class]) image=result;
    if (!image) { SXLAppInfo *app=[self ensureApplicationForBundleID:bundleID]; image=[self iconForPrivateApplication:app.privateApplication bundleID:bundleID]; }
    if (image) [self.iconCache setObject:image forKey:bundleID cost:(NSUInteger)(image.size.width*image.size.height*image.scale*image.scale*4)];
    return image;
}
- (void)invalidatePreparedIcons { SXLIconPipeline *pipeline=objc_getAssociatedObject(self,@selector(ql_iconPipeline)); [pipeline invalidate]; }
- (SXLIconPipeline *)ql_iconPipeline {
    SXLIconPipeline *pipeline=objc_getAssociatedObject(self,_cmd);
    if (!pipeline) { pipeline=[SXLIconPipeline new]; pipeline.source=self; objc_setAssociatedObject(self,_cmd,pipeline,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return pipeline;
}
- (void)requestIconForBundleID:(NSString *)bundleID size:(CGFloat)size completion:(void (^)(UIImage *))completion {
    [self requestIconForBundleID:bundleID size:size isCurrent:^{return YES;} completion:completion];
}
- (void)requestIconForBundleID:(NSString *)bundleID size:(CGFloat)size isCurrent:(BOOL (^)(void))isCurrent completion:(void (^)(UIImage *))completion {
    [[self ql_iconPipeline] request:bundleID size:size isCurrent:isCurrent completion:completion];
}
- (BOOL)launchBundleID:(NSString *)bundleID error:(NSError **)error {
    if (!bundleID.length) { if (error) *error=SOLAError(50,@"未配置应用标识"); return NO; }
    if (!SOLAIsUnlocked(error)) return NO;
    BOOL accepted=NO;
    NSNumber *result=SOLAInvoke(UIApplication.sharedApplication,@"launchApplicationWithIdentifier:suspended:",@"bool",@[@"object",@"bool"],@[bundleID,@NO],&accepted);
    if (accepted && result.boolValue) return YES;
    /* Original 0x2c994..0x2c9c0: int SBSLaunchApplicationWithIdentifier(CFStringRef, BOOL). */
    static void *services; static dispatch_once_t once;
    dispatch_once(&once,^{services=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_LAZY|RTLD_LOCAL);});
    int (*launch)(CFStringRef,BOOL)=services ? (int (*)(CFStringRef,BOOL))dlsym(services,"SBSLaunchApplicationWithIdentifier") : NULL;
    if (launch && launch((__bridge CFStringRef)bundleID,NO)==0) return YES;
    if (error) *error=SOLAError(51,@"系统未接受应用启动请求或该应用不可用"); return NO;
}
/* Third-party launch modes are intentionally rejected until adapter ABI is verified. */
- (BOOL)openBundleIDInScreenCoreDuo:(NSString *)b sourceRect:(CGRect)r error:(NSError **)e { if(e)*e=SOLAError(52,@"ScreenCore Duo 适配未核验"); return NO; }
- (BOOL)openBundleIDInScreenCore:(NSString *)b sourceRect:(CGRect)r error:(NSError **)e { if(e)*e=SOLAError(52,@"ScreenCore 适配未核验"); return NO; }
- (BOOL)openBundleIDInIya:(NSString *)b mode:(NSString *)m error:(NSError **)e { if(e)*e=SOLAError(52,@"一芽适配未核验"); return NO; }
- (BOOL)openBundleIDInMyrtle:(NSString *)b error:(NSError **)e { if(e)*e=SOLAError(52,@"Myrtle 适配未核验"); return NO; }
- (BOOL)openBundleIDInSVP:(NSString *)b error:(NSError **)e { if(e)*e=SOLAError(52,@"SVP 适配未核验"); return NO; }
- (BOOL)openBundleIDInFV:(NSString *)b error:(NSError **)e { if(e)*e=SOLAError(52,@"FV 适配未核验"); return NO; }
- (BOOL)openBundleIDInOpenSplit:(NSString *)b error:(NSError **)e { if(e)*e=SOLAError(52,@"Open 适配未核验"); return NO; }
- (BOOL)openBundleIDInPullOverCard:(NSString *)b error:(NSError **)e { if(e)*e=SOLAError(52,@"PullOver 适配未核验"); return NO; }
@end

@implementation SXLIconConsumer
@end
@implementation SXLIconRequest
@end
@implementation SXLIconPipeline
- (instancetype)init { if ((self=[super init])) { self.cache=[NSCache new]; self.cache.countLimit=160; self.revision=1; } return self; }
- (void)invalidate { self.revision++; [self.cache removeAllObjects]; }
- (void)memoryWarning:(NSNotification *)notification { [self invalidate]; }
- (void)request:(NSString *)bundleID size:(CGFloat)size isCurrent:(BOOL (^)(void))isCurrent completion:(void (^)(UIImage *))completion {
    if (!completion || !bundleID.length) return;
    size=MIN(128,MAX(16,size));
    NSString *key=[NSString stringWithFormat:@"%@/%.0f",bundleID,size];
    UIImage *cached=[self.cache objectForKey:key];
    if (cached) { if (!isCurrent || isCurrent()) completion(cached); return; }
    NSUInteger revision=self.revision;
    dispatch_async(dispatch_get_main_queue(),^{
        if (revision!=self.revision || (isCurrent && !isCurrent())) return;
        UIImage *original=[self.source iconForBundleID:bundleID]; UIImage *image=original;
        if (original) {
            UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size,size)];
            image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){[original drawInRect:CGRectMake(0,0,size,size)];}];
            [self.cache setObject:image forKey:key];
        }
        if (!isCurrent || isCurrent()) completion(image);
    });
}
@end

@implementation SXLLockStateMonitor
- (instancetype)init { if ((self=[super init])) self.token=-1; return self; }
- (void)start {
    if (self.running) return;
    self.running=YES; __weak typeof(self) weakSelf=self; int token=-1;
    if (notify_register_dispatch("com.apple.springboard.lockstate",&token,dispatch_get_main_queue(),^(int t){[weakSelf refresh];})==NOTIFY_STATUS_OK) self.token=token;
    [self refresh];
}
- (void)systemStateChanged:(NSNotification *)notification { [self refresh]; }
- (void)refresh {
    if (!self.running) return;
    uint64_t state=1; BOOL known=self.token>=0 && notify_get_state((int)self.token,&state)==NOTIFY_STATUS_OK;
    NSNumber *locked=SOLANumber(SOLAShared(@"SBLockScreenManager"),@"isUILocked");
    BOOL next=locked ? locked.boolValue : (known ? state!=0 : YES);
    BOOL changed=self.locked!=next; self.locked=next;
    if (changed && self.stateChanged) ((void (^)(BOOL))self.stateChanged)(next);
}
- (void)stop { self.running=NO; if (self.token>=0) notify_cancel((int)self.token); self.token=-1; [self.timer invalidate]; self.timer=nil; }
- (void)dealloc { [self stop]; }
@end

@implementation SXSystemControlController
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=UIColor.systemBackgroundColor;
    UILabel *label=[UILabel new]; label.text=[self.kind isEqual:@"brightness"] ? @"亮度" : @"音量";
    label.textAlignment=NSTextAlignmentCenter; label.frame=CGRectMake(20,20,260,36); label.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:label];
    if ([self.kind isEqual:@"brightness"]) {
        self.brightness=[[UISlider alloc] initWithFrame:CGRectMake(24,70,252,44)];
        self.brightness.minimumValue=0; self.brightness.maximumValue=1; self.brightness.value=UIScreen.mainScreen.brightness;
        self.brightness.minimumValueImage=[UIImage systemImageNamed:@"sun.min.fill"]; self.brightness.maximumValueImage=[UIImage systemImageNamed:@"sun.max.fill"];
        self.brightness.autoresizingMask=UIViewAutoresizingFlexibleWidth;
        [self.brightness addTarget:self action:@selector(brightnessChanged:) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:self.brightness];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshBrightness:) name:UIScreenBrightnessDidChangeNotification object:nil];
    } else {
        MPVolumeView *volume=[[MPVolumeView alloc] initWithFrame:CGRectMake(24,70,252,44)]; volume.showsRouteButton=NO;
        volume.autoresizingMask=UIViewAutoresizingFlexibleWidth; [self.view addSubview:volume];
    }
    self.preferredContentSize=CGSizeMake(300,140);
}
- (void)brightnessChanged:(UISlider *)sender { NSError *error=nil; if (SOLAIsUnlocked(&error)) UIScreen.mainScreen.brightness=sender.value; else SOLActionShowMessage(error.localizedDescription); }
- (void)refreshBrightness:(NSNotification *)notification { if (!self.brightness.tracking) self.brightness.value=UIScreen.mainScreen.brightness; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end

@implementation SXLOverlayController
- (void)loadView { self.view=[[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds]; self.view.backgroundColor=UIColor.clearColor; }
- (void)setContentView:(UIView *)contentView { if (_contentView!=contentView) { [_contentView removeFromSuperview]; _contentView=contentView; if(contentView)[self.view addSubview:contentView]; } }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; [self refreshGeometry]; }
- (void)startMonitoring { [self refreshGeometry]; }
- (void)stopMonitoring { [self.geometryTimer invalidate]; self.geometryTimer=nil; }
- (void)refreshGeometry {
    if (self.updatingGeometry) return; self.updatingGeometry=YES;
    self.contentView.frame=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);
    self.hasGeometry=YES; self.updatingGeometry=NO;
    if (self.layoutChanged) ((void (^)(void))self.layoutChanged)();
}
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
- (void)dealloc { [self stopMonitoring]; }
@end
@implementation SXModuleController
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=UIColor.systemBackgroundColor;
    if (self.moduleController) { [self addChildViewController:self.moduleController]; self.contentView=self.moduleController.view; [self.moduleController didMoveToParentViewController:self]; }
    self.closeButton=[UIButton buttonWithType:UIButtonTypeSystem]; [self.closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    self.closeButton.frame=CGRectMake(12,12,40,40); [self.closeButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.closeButton];
    self.lockMonitor=[SXLLockStateMonitor new]; __weak typeof(self) weakSelf=self;
    self.lockMonitor.stateChanged=^(BOOL locked){if(locked)[weakSelf close];}; [self.lockMonitor start];
}
- (void)close { [self.lockMonitor stop]; [self dismissViewControllerAnimated:YES completion:nil]; if(self.geometryWindow){self.geometryWindow.hidden=YES;self.geometryWindow.rootViewController=nil;} }
@end

@implementation SXPicker
- (void)viewDidLoad {
    [super viewDidLoad]; self.filtered=self.records ?: @[];
    self.search=[[UISearchController alloc] initWithSearchResultsController:nil]; self.search.searchResultsUpdater=(id)self; self.search.obscuresBackgroundDuringPresentation=NO;
    self.navigationItem.searchController=self.search; self.definesPresentationContext=YES;
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
}
- (void)done { if(self.navigationController.viewControllers.count>1)[self.navigationController popViewControllerAnimated:YES];else[self dismissViewControllerAnimated:YES completion:nil]; }
- (void)updateSearchResultsForSearchController:(UISearchController *)controller {
    NSString *q=controller.searchBar.text;
    self.filtered=q.length ? [self.records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *record,NSDictionary *bindings){return [record[@"title"] localizedCaseInsensitiveContainsString:q] || [record[@"value"] localizedCaseInsensitiveContainsString:q];}]] : self.records;
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.filtered.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"action"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"action"];
    NSDictionary *record=self.filtered[indexPath.row]; cell.textLabel.text=record[@"title"]; cell.detailTextLabel.text=SOLActionUnavailableReason(record) ?: record[@"value"];
    cell.imageView.image=SOLActionImage(record) ?: [UIImage systemImageNamed:@"app"];
    cell.accessoryType=UITableViewCellAccessoryNone; return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row>=self.filtered.count)return; NSDictionary *record=self.filtered[indexPath.row];
    if(self.choose)((void (^)(NSDictionary *))self.choose)(record);
    [self.navigationController popViewControllerAnimated:YES];
}
@end

@interface SXActionEditor ()
- (void)toggleEditing;
- (void)sol_close;
- (void)sol_addText:(NSString *)type record:(nullable NSDictionary *)record;
- (void)addRecord:(NSDictionary *)record;
- (void)pickRecords:(NSArray *)records title:(NSString *)title;
- (void)enabledChanged:(UISwitch *)sender;
@end
@implementation SXActionEditor
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; if (!self.preferenceKey.length) self.preferenceKey=@"sxShortcutActions";
    self.title=@"快捷操作"; self.records=[SOLActionRecords(self.preferenceKey) mutableCopy];
    [self configureNavigation:self]; self.tableView.rowHeight=62;
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(sol_close)];
}
- (void)configureNavigation:(UIViewController *)controller {
    self.navigationOwner=controller;
    controller.navigationItem.rightBarButtonItems=@[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add)],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:self.editing ? UIBarButtonSystemItemDone : UIBarButtonSystemItemEdit target:self action:@selector(toggleEditing)]];
}
- (void)toggleEditing { [self setEditing:!self.editing animated:YES]; [self configureNavigation:self.navigationOwner ?: self]; }
- (void)sol_close { [self save]; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)save {
    NSError *error=nil;
    if (!SOLActionSaveRecords(self.preferenceKey,self.records,&error)) SOLActionShowMessage(error.localizedDescription);
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.records.count; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return @"点击项目修改；编辑可拖动排序和删除。修改即时保存，返回桌面即可使用。长按快捷组件也可打开此页。"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"record"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"record"];
    NSDictionary *r=self.records[path.row]; cell.textLabel.text=r[@"title"];
    cell.detailTextLabel.text=SOLActionUnavailableReason(r) ?: r[@"value"];
    cell.imageView.image=SOLActionImage(r) ?: [UIImage systemImageNamed:@"app"];
    UISwitch *enabled=[UISwitch new]; enabled.on=[r[@"enabled"] boolValue]; enabled.tag=path.row;
    [enabled addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=enabled;
    return cell;
}
- (void)enabledChanged:(UISwitch *)sender {
    if(sender.tag<0 || sender.tag>=self.records.count)return;
    NSMutableDictionary *r=[self.records[sender.tag] mutableCopy]; r[@"enabled"]=@(sender.on); self.records[sender.tag]=r; [self save];
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)path { return YES; }
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path { return YES; }
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    if(from.row>=self.records.count || to.row>=self.records.count)return;
    id record=self.records[from.row]; [self.records removeObjectAtIndex:from.row]; [self.records insertObject:record atIndex:to.row]; [self save]; [tableView reloadData];
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if(style!=UITableViewCellEditingStyleDelete || path.row>=self.records.count)return;
    [self.records removeObjectAtIndex:path.row]; [self save]; [tableView deleteRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
}
- (void)addRecord:(NSDictionary *)record {
    NSMutableDictionary *r=[SOLANormalizeRecord(record) mutableCopy]; if(!r)return;
    r[@"id"]=NSUUID.UUID.UUIDString; [self.records addObject:r]; [self save]; [self.tableView reloadData];
}
- (void)pickRecords:(NSArray *)records title:(NSString *)title {
    SXPicker *picker=[SXPicker new]; picker.title=title; picker.records=records;
    __weak typeof(self) weakSelf=self; picker.choose=^(NSDictionary *r){[weakSelf addRecord:r];};
    [self.navigationController pushViewController:picker animated:YES];
}
- (void)sol_addText:(NSString *)type record:(NSDictionary *)record {
    BOOL url=[type isEqual:@"url"];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:url ? @"网址 / URL Scheme" : @"快捷指令" message:url ? @"输入完整 URL（如 https://example.com）" : @"输入快捷指令 App 中的准确名称。通过系统 URL 提交运行请求。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"名称";field.text=record[@"title"];}];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=url ? @"https://" : @"快捷指令名称";field.text=record[@"value"];field.autocapitalizationType=UITextAutocapitalizationTypeNone;}];
    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSDictionary *r=@{@"type":type,@"title":alert.textFields[0].text ?: @"",@"value":alert.textFields[1].text ?: @"",@"id":record[@"id"] ?: NSUUID.UUID.UUIDString,@"enabled":record[@"enabled"] ?: @YES};
        NSDictionary *clean=SOLANormalizeRecord(r); if(!clean){SOLActionShowMessage(@"内容无效，请输入有效 URL 或快捷指令名称");return;}
        SXActionEditor *owner=weakSelf; if(!owner)return;
        NSUInteger index=record ? [owner.records indexOfObject:record] : NSNotFound;
        if(index==NSNotFound)[owner.records addObject:clean];else owner.records[index]=clean;
        [owner save]; [owner.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)add {
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"添加快捷操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"系统工具" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[weakSelf pickRecords:SOLActionCatalog() title:@"系统工具"];}]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"应用" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        [[SXLAppCenter sharedCenter] reloadInstalledApplications]; NSArray *apps=SOLInstalledApplicationRecords();
        if(!apps.count){SOLActionShowMessage(@"当前进程无法读取已安装应用列表");return;}[weakSelf pickRecords:apps title:@"应用"];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"URL" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[weakSelf sol_addText:@"url" record:nil];}]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"快捷指令" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[weakSelf sol_addText:@"shortcut" record:nil];}]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItems.firstObject;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES]; if(path.row>=self.records.count)return;
    NSDictionary *record=self.records[path.row]; NSString *type=record[@"type"];
    if([type isEqual:@"url"] || [type isEqual:@"shortcut"]) {[self sol_addText:type record:record];return;}
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:record[@"title"] message:SOLActionUnavailableReason(record) ?: record[@"value"] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"修改名称" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        UIAlertController *rename=[UIAlertController alertControllerWithTitle:@"显示名称" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [rename addTextFieldWithConfigurationHandler:^(UITextField *field){field.text=record[@"title"];}];
        [rename addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *b){
            NSMutableDictionary *r=[record mutableCopy]; r[@"title"]=rename.textFields.firstObject.text ?: record[@"title"]; self.records[path.row]=r; [self save]; [self.tableView reloadData];
        }]];[rename addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:rename animated:YES completion:nil];
    }]];
    if([type isEqual:@"app"]) [alert addAction:[UIAlertAction actionWithTitle:@"使用全屏打开" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){NSMutableDictionary *r=[record mutableCopy];r[@"mode"]=@"fullscreen";self.records[path.row]=r;[self save];[self.tableView reloadData];}]];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
