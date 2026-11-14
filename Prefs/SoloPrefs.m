#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <math.h>
#if __has_include(<Preferences/Preferences.h>)
#import <Preferences/Preferences.h>
#else
// Match the runtime inheritance; PSListController is NOT a UIViewController subclass directly.
@interface PSViewController : UIViewController
- (void)setSpecifier:(id)specifier;
- (id)specifier;
- (void)setRootController:(id)controller;
- (id)rootController;
- (void)setParentController:(id)controller;
@end
@interface PSListController : PSViewController {
@protected
    NSArray *_specifiers;
}
- (void)reloadSpecifiers;
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
- (UITableView *)table;
@end
@interface PSSpecifier : NSObject
@property(nonatomic) SEL buttonAction;
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(NSInteger)cell edit:(Class)edit;
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)value forKey:(NSString *)key;
@end
#endif

static NSString * const kDomain = @"com.oakstheawesome.solo";
static NSString * const kReload = @"com.oakstheawesome.solo/ReloadPrefs";
static NSString * const kPublished = @"com.oakstheawesome.solo/CalendarsPublished";
static id SOLRead(NSString *key);
static BOOL SOLWrite(NSDictionary *values, NSArray *remove);
static void SOLPost(void);
static void SOLAlert(UIViewController *vc, NSString *title, NSString *message);
static NSDictionary *SOLConfig(Class cls, NSString *page);
static NSArray *SOLPages(void);
static NSArray *SOLShortcutCatalog(void);
static NSArray *SOLStringList(id value, NSArray *allowed, NSArray *fallback, NSUInteger limit);
static PSSpecifier *SOLSpecifier(NSDictionary *item, id target);
static void SOLCalendarPublished(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info);

// Public C interfaces for local settings consumers. No write happens during page loading.
id SOLPrefsReadValue(NSString *key) { return SOLRead(key); }
BOOL SOLPrefsWriteValues(NSDictionary *values, NSArray *removedKeys) { return SOLWrite(values, removedKeys); }
static id SOLRead(NSString *key) {
    return key.length ? CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)kDomain)) : nil;
}
static void SOLPost(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)kReload, NULL, NULL, true);
    [[NSNotificationCenter defaultCenter] postNotificationName:kReload object:nil];
}
static BOOL SOLWrite(NSDictionary *values, NSArray *remove) {
    for (NSString *key in remove) CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, (__bridge CFStringRef)kDomain);
    for (NSString *key in values) CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)values[key], (__bridge CFStringRef)kDomain);
    BOOL ok = CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    if (ok) SOLPost();
    return ok;
}
static void SOLAlert(UIViewController *vc, NSString *title, NSString *message) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}
static NSDictionary *SOLConfig(Class cls, NSString *page) {
    NSBundle *bundle = [NSBundle bundleForClass:cls];
    NSString *path = [bundle pathForResource:page ofType:@"plist"];
    NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
    id config = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil] : nil;
    return [config isKindOfClass:NSDictionary.class] && [config[@"items"] isKindOfClass:NSArray.class] ? config : nil;
}
static NSArray *SOLStringList(id value, NSArray *allowed, NSArray *fallback, NSUInteger limit) {
    NSArray *input = [value isKindOfClass:NSArray.class] ? value : fallback;
    NSMutableArray *out = [NSMutableArray array];
    for (id key in input) if ([key isKindOfClass:NSString.class] && [allowed containsObject:key] && ![out containsObject:key] && out.count < limit) [out addObject:key];
    return out;
}
static PSSpecifier *SOLSpecifier(NSDictionary *item, id target) {
    NSDictionary *types = @{@"PSGroupCell":@0, @"PSLinkCell":@1, @"PSLinkListCell":@2, @"PSSwitchCell":@6, @"PSButtonCell":@13, @"PSSegmentCell":@9};
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:item[@"label"] ?: @"" target:target set:item[@"key"] ? @selector(setPreferenceValue:specifier:) : NULL get:item[@"key"] ? @selector(readPreferenceValue:) : NULL detail:NSClassFromString(item[@"detail"] ?: @"") cell:[types[item[@"cell"]] integerValue] edit:Nil];
    for (NSString *key in item) [s setProperty:item[key] forKey:key];
    if (item[@"action"]) s.buttonAction = NSSelectorFromString(item[@"action"]);
    return s;
}

// Own the single UIKit table directly. PSListController assumes its own
// PSSpecifier/group arrays and must not drive these custom section delegates.
@interface SOLTableController : PSViewController <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic,strong) UITableView *solTable;
- (void)reloadSettings;
- (void)pushController:(PSViewController *)controller item:(NSDictionary *)item;
@end
@interface SOLPreferenceController : PSListController
@property(nonatomic,copy) NSString *pageName;
@property(nonatomic,strong) NSDictionary *configuration;
- (void)reloadSettings;
- (NSString *)settingsPage;
- (NSArray *)specifiers;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
@end
@interface SOLRootListController : SOLPreferenceController @end
@interface SOLSectionListController : SOLPreferenceController @end
@interface SOLCarouselController : SOLTableController
@property(nonatomic,strong) NSMutableArray *active;
@property(nonatomic,strong) NSMutableArray *inactive;
- (void)loadPages;
- (void)savePages;
@end
@interface SOLShortcutsController : SOLTableController
@property(nonatomic,strong) NSMutableArray *chosen;
@property(nonatomic,strong) NSMutableArray *available;
- (void)save;
@end
@interface SOLCalendarsController : SOLTableController
@property(nonatomic,strong) NSArray *accounts;
@property(nonatomic,strong) NSDictionary *calendarsByAccount;
@property(nonatomic,strong) NSMutableSet *hidden;
@property(nonatomic) BOOL waited;
- (void)reloadCalendars;
@end
@interface SXClockPreferences : SOLTableController <PHPickerViewControllerDelegate, UIDocumentPickerDelegate>
@property(nonatomic,strong) UIImage *backgroundImage;
@property(nonatomic) NSUInteger importGeneration;
- (void)importData:(NSData *)data generation:(NSUInteger)generation;
@end

@implementation SOLTableController
- (NSArray *)specifiers { return @[]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.solTable = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.solTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.solTable.dataSource = self; self.solTable.delegate = self;
    self.solTable.rowHeight = UITableViewAutomaticDimension; self.solTable.estimatedRowHeight = 56;
    [self.view addSubview:self.solTable];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSettings) name:kReload object:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain); [self reloadSettings]; }
- (void)reloadSettings { [self.solTable reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 0; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 0; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath { return [UITableViewCell new]; }
- (void)pushController:(PSViewController *)controller item:(NSDictionary *)item {
    [controller setSpecifier:SOLSpecifier(item, self)];
    [controller setRootController:[self rootController] ?: self]; [controller setParentController:self];
    controller.title = item[@"label"];
    [self.navigationController pushViewController:controller animated:YES];
}
@end

@implementation SOLPreferenceController
- (NSString *)settingsPage { return self.pageName ?: [[self specifier] propertyForKey:@"plist"] ?: @"HomeScreen"; }
- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSettings) name:kReload object:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    [self reloadSettings];
}
- (BOOL)itemWanted:(NSDictionary *)item {
    NSString *version = UIDevice.currentDevice.systemVersion;
    if (item[@"minimumiOS"] && [version compare:item[@"minimumiOS"] options:NSNumericSearch] == NSOrderedAscending) return NO;
    if (item[@"maximumiOS"] && [version compare:item[@"maximumiOS"] options:NSNumericSearch] != NSOrderedAscending) return NO;
    NSString *key = item[@"showWhenKey"];
    if (!key) return YES;
    id value = SOLRead(key);
    if (!value) for (NSDictionary *candidate in self.configuration[@"items"]) if ([candidate[@"key"] isEqual:key]) { value = candidate[@"default"]; break; }
    return item[@"showWhenValue"] ? fabs([value doubleValue] - [item[@"showWhenValue"] doubleValue]) < 0.000001 : [value boolValue];
}
// The original Root/Section controllers populate PSListController._specifiers
// (Root 0x41c0, Section 0x8164). Let the native controller own group indexing,
// cell creation, selection and child navigation; do not add a second table.
- (NSArray *)specifiers {
    if (!_specifiers) {
        self.configuration = SOLConfig(SOLRootListController.class, [self settingsPage]);
        self.title = self.configuration[@"title"] ?: self.title ?: @"Solo";
        NSArray *loaded = [self loadSpecifiersFromPlistName:[self settingsPage] target:self];
        NSMutableArray *specs = [NSMutableArray array];
        for (PSSpecifier *specifier in loaded) {
            NSMutableDictionary *conditions = [NSMutableDictionary dictionary];
            for (NSString *key in @[@"minimumiOS", @"maximumiOS", @"showWhenKey", @"showWhenValue"]) {
                id value = [specifier propertyForKey:key];
                if (value) conditions[key] = value;
            }
            if ([self itemWanted:conditions]) [specs addObject:specifier];
        }
        _specifiers = [specs copy];
    }
    return _specifiers;
}
- (void)reloadSettings {
    _specifiers = nil;
    [self reloadSpecifiers];
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    return SOLRead([specifier propertyForKey:@"key"]) ?: [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key.length) return;
    if (!SOLWrite(value ? @{key:value} : @{}, value ? @[] : @[key]))
        SOLAlert(self, @"保存失败", @"偏好未能同步到磁盘，请重试。");
}
@end
@implementation SOLSectionListController @end

@implementation SOLRootListController
- (NSString *)settingsPage { return @"Root"; }
- (void)resetPreferences {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"重置设置" message:@"恢复 Solo 默认设置，包括轮播顺序、快捷选择与时钟背景。不会自动注销。" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"重置" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSArray *keys = CFBridgingRelease(CFPreferencesCopyKeyList((__bridge CFStringRef)kDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
        // knownCalendars is published backend data, not a user setting.
        NSMutableArray *remove = [keys mutableCopy] ?: [NSMutableArray array]; [remove removeObject:@"knownCalendars"];
        if (!SOLWrite(@{}, remove)) SOLAlert(self, @"重置失败", @"偏好同步失败，请重试。");
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)showWelcomeAgain {
    if (SOLWrite(@{}, @[@"welcomeShown"])) SOLAlert(self, @"欢迎页", @"下次进入主屏幕时会再次显示欢迎页。");
    else SOLAlert(self, @"保存失败", @"偏好同步失败，请重试。");
}
- (void)shareDebugReport {
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    NSArray *keys = CFBridgingRelease(CFPreferencesCopyKeyList((__bridge CFStringRef)kDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
    for (NSString *key in keys) {
        id value = SOLRead(key);
        if ([key isEqual:@"knownCalendars"] || [key isEqual:@"hiddenCalendars"]) values[key] = @([value count]);
        else if ([value isKindOfClass:NSData.class]) values[key] = [NSString stringWithFormat:@"<%lu bytes>", (unsigned long)[value length]];
        else if ([key isEqual:@"sxShortcutActions"] || [key isEqual:@"sxSidebarActions"]) values[key] = @([value count]);
        else if (value) values[key] = value;
    }
    NSString *report = [NSString stringWithFormat:@"Solo diagnostics\niOS %@\nPreferences bundle %@\n%@\n", UIDevice.currentDevice.systemVersion, [NSBundle bundleForClass:self.class].bundlePath, values];
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[report] applicationActivities:nil];
    share.popoverPresentationController.sourceView = self.view; share.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, 80, 1, 1);
    [self presentViewController:share animated:YES completion:nil];
}
- (void)openLink:(NSString *)link { [UIApplication.sharedApplication openURL:[NSURL URLWithString:link] options:@{} completionHandler:nil]; }
- (void)discordLink { [self openLink:@"https://discord.com/users/384917479752990731"]; }
- (void)twitterLink { [self openLink:@"https://x.com/oakstheawesome"]; }
- (void)youTubeLink { [self openLink:@"https://youtube.com/@oakstheawesome"]; }
- (void)gitHubLink { [self openLink:@"https://github.com/OaksTheAwesome"]; }
- (void)respring {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"注销" message:@"确定要重启 SpringBoard 吗？" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"稍后" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"注销" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        // A request only: backend must opt in. Never posted while loading/saving/resetting.
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.oakstheawesome.solo/RequestRespring"), NULL, NULL, true);
        SOLAlert(self, @"已请求注销", @"仅向 Solo 后端发送手动注销请求；若当前后端不支持，请使用越狱管理器注销。");
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

static NSArray *SOLPages(void) {
    return @[@{@"id":@"widget",@"title":@"组件",@"subtitle":@"你选择的小组件或智能叠放",@"symbol":@"square.stack.fill"},
             @{@"id":@"media",@"title":@"媒体",@"subtitle":@"正在播放、进度与歌词",@"symbol":@"music.note",@"plist":@"Media"},
             @{@"id":@"clock",@"title":@"时钟",@"subtitle":@"三种布局、天气与计时",@"symbol":@"clock.fill",@"plist":@"Clock"},
             @{@"id":@"calendar",@"title":@"日历",@"subtitle":@"接下来的日程",@"symbol":@"calendar",@"plist":@"Calendar"},
             @{@"id":@"shortcuts",@"title":@"快捷",@"subtitle":@"最多六个开关与操作",@"symbol":@"circle.grid.3x3.fill"}];
}
@implementation SOLCarouselController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"轮播";
    [self.solTable setEditing:YES animated:NO]; self.solTable.allowsSelectionDuringEditing = YES;
}
- (void)reloadSettings { [self loadPages]; [super reloadSettings]; }
- (void)loadPages {
    NSArray *ids = [SOLPages() valueForKey:@"id"];
    self.active = [SOLStringList(SOLRead(@"carouselPages"), ids, @[@"widget",@"media",@"clock",@"calendar"], 5) mutableCopy];
    if (!self.active.count) [self.active addObject:@"widget"];
    self.inactive = [ids mutableCopy]; [self.inactive removeObjectsInArray:self.active];
}
- (void)savePages { if (!SOLWrite(@{@"carouselPages":[self.active copy]}, @[])) SOLAlert(self, @"保存失败", @"轮播顺序未能同步，请重试。"); [self reloadSettings]; }
- (NSMutableArray *)listForSection:(NSInteger)section { return section == 1 ? self.active : self.inactive; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 3 : [[self listForSection:section] count]; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @[@"轮播",@"启用",@"可用"][section]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return section == 0 ? @"关闭后图标上移占据轮播区域。回到起始页在每次解锁时回到第一页；智能轮换在解锁时跳到最相关页面。" : section == 1 ? @"拖动排序，或拖至“可用”停用。点按媒体、时钟、日历、快捷可打开设置。至少保留一页。" : @"点按或拖至“启用”添加。"; }
- (void)behaviorToggled:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (!SOLWrite(@{key:@(sender.on)}, @[])) SOLAlert(self, @"保存失败", @"偏好同步失败，请重试。");
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    if (path.section == 0) {
        NSArray *keys = @[@"carouselEnabled",@"returnToStart",@"smartRotate"];
        cell.textLabel.text = @[@"显示轮播",@"回到起始页",@"智能轮换"][path.row];
        UISwitch *toggle = [UISwitch new]; toggle.accessibilityIdentifier = keys[path.row]; toggle.on = [SOLRead(keys[path.row]) ?: @(path.row == 0) boolValue];
        [toggle addTarget:self action:@selector(behaviorToggled:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = toggle; cell.editingAccessoryView = toggle;
    } else {
        NSString *key = [self listForSection:path.section][path.row]; NSDictionary *page = SOLPages()[[[SOLPages() valueForKey:@"id"] indexOfObject:key]];
        cell.textLabel.text = page[@"title"]; cell.detailTextLabel.text = page[@"subtitle"]; cell.detailTextLabel.numberOfLines = 0;
        cell.imageView.image = [UIImage systemImageNamed:page[@"symbol"]]; cell.showsReorderControl = YES;
        cell.editingAccessoryType = [key isEqual:@"widget"] ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)path { return UITableViewCellEditingStyleNone; }
- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)path { return NO; }
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path { return path.section > 0; }
- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source toProposedIndexPath:(NSIndexPath *)target {
    if (target.section == 0) return [NSIndexPath indexPathForRow:0 inSection:1];
    if (source.section == 1 && target.section == 2 && self.active.count <= 1) return source;
    return target;
}
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)target {
    if (source.section == 1 && target.section == 2 && self.active.count <= 1) { SOLAlert(self,@"至少保留一页",@"请先添加另一页。"); [tableView reloadData]; return; }
    NSMutableArray *from = [self listForSection:source.section], *to = [self listForSection:target.section]; NSString *key = from[source.row]; [from removeObjectAtIndex:source.row]; [to insertObject:key atIndex:MIN((NSUInteger)target.row,to.count)]; [self savePages];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES]; if (!path.section) return;
    NSString *key = [self listForSection:path.section][path.row];
    if (path.section == 2) { [self.inactive removeObject:key]; [self.active addObject:key]; [self savePages]; return; }
    if ([key isEqual:@"widget"]) return;
    NSDictionary *page = SOLPages()[[[SOLPages() valueForKey:@"id"] indexOfObject:key]];
    [self pushController:[key isEqual:@"shortcuts"] ? [SOLShortcutsController new] : [SOLSectionListController new] item:@{@"label":page[@"title"],@"plist":page[@"plist"] ?: @"",@"pageID":key,@"detail":[key isEqual:@"shortcuts"] ? @"SOLShortcutsController" : @"SOLSectionListController",@"cell":@"PSLinkCell",@"isController":@YES}];
}
@end

static NSArray *SOLShortcutCatalog(void) {
    // Original sub_1ab80 + sub_d2d0: built-ins; external power tools require executables.
    NSMutableArray *rows = [@[@{@"id":@"wifi",@"title":@"Wi-Fi"},@{@"id":@"bluetooth",@"title":@"蓝牙"},@{@"id":@"airplane",@"title":@"飞行"},@{@"id":@"location",@"title":@"定位"},@{@"id":@"nightShift",@"title":@"夜览"},@{@"id":@"lowPower",@"title":@"低电量"},@{@"id":@"rotationLock",@"title":@"旋转锁定"},@{@"id":@"darkMode",@"title":@"深色"},@{@"id":@"flashlight",@"title":@"手电筒"},@{@"id":@"respring",@"title":@"注销"}] mutableCopy];
    NSArray *extra = @[@{@"id":@"psReboot",@"title":@"重启",@"path":@"psreboot"},@{@"id":@"psUserspace",@"title":@"软重启",@"path":@"psusreboot"},@{@"id":@"psLDRestart",@"title":@"LDRestart",@"path":@"ldrunps"},@{@"id":@"psSafeMode",@"title":@"安全",@"path":@"killall"},@{@"id":@"psUICache",@"title":@"缓存",@"path":@"uicache"},@{@"id":@"psSBReload",@"title":@"SB重载",@"path":@"sbreload"},@{@"id":@"psPowerOff",@"title":@"关机",@"path":@"pspoweroff"}];
    for (NSDictionary *row in extra) for (NSString *prefix in @[@"/var/jb/usr/bin",@"/usr/bin"]) if ([NSFileManager.defaultManager isExecutableFileAtPath:[prefix stringByAppendingPathComponent:row[@"path"]]]) { [rows addObject:row]; break; }
    return rows;
}
@implementation SOLShortcutsController
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"快捷"; [self.solTable setEditing:YES animated:NO]; self.solTable.allowsSelectionDuringEditing = YES; }
- (void)reloadSettings {
    NSArray *ids = [SOLShortcutCatalog() valueForKey:@"id"];
    self.chosen = [SOLStringList(SOLRead(@"shortcuts"), ids, @[@"wifi",@"bluetooth",@"airplane",@"lowPower",@"rotationLock",@"darkMode"], 6) mutableCopy];
    self.available = [ids mutableCopy]; [self.available removeObjectsInArray:self.chosen]; [super reloadSettings];
}
- (NSMutableArray *)listForSection:(NSInteger)section { return section == 0 ? self.chosen : self.available; }
- (void)save {
    // Deliberate legacy edit supersedes a prior enhanced action list; the backend migrates it.
    if (!SOLWrite(@{@"shortcuts":[self.chosen copy]}, @[@"sxShortcutActions"])) SOLAlert(self,@"保存失败",@"快捷选择未能同步，请重试。");
    [self reloadSettings];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [[self listForSection:section] count]; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return section == 0 ? [NSString stringWithFormat:@"启用 %lu/6",(unsigned long)self.chosen.count] : @"可用"; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return section == 0 ? @"拖动排序。点按移除；快捷动作在主屏幕执行。" : @"点按添加，最多六个。也可拖动到启用分区。"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSString *key = [self listForSection:path.section][path.row]; UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    for (NSDictionary *row in SOLShortcutCatalog()) if ([row[@"id"] isEqual:key]) { cell.textLabel.text = row[@"title"]; break; }
    cell.showsReorderControl = YES; return cell;
}
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)path { return UITableViewCellEditingStyleNone; }
- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)path { return NO; }
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path { return YES; }
- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source toProposedIndexPath:(NSIndexPath *)target { return source.section == 1 && target.section == 0 && self.chosen.count >= 6 ? source : target; }
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)target {
    if (source.section == 1 && target.section == 0 && self.chosen.count >= 6) { [tableView reloadData]; return; }
    NSMutableArray *from = [self listForSection:source.section], *to = [self listForSection:target.section]; NSString *key = from[source.row]; [from removeObjectAtIndex:source.row]; [to insertObject:key atIndex:MIN((NSUInteger)target.row,to.count)]; [self save];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section == 1 && self.chosen.count >= 6) { SOLAlert(self,@"最多六个快捷",@"请先移除一个已启用快捷。"); return; }
    NSMutableArray *from = [self listForSection:path.section], *to = [self listForSection:1-path.section]; NSString *key = from[path.row]; [from removeObjectAtIndex:path.row]; [to addObject:key]; [self save];
}
@end

static void SOLCalendarPublished(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{ [[NSNotificationCenter defaultCenter] postNotificationName:kPublished object:nil]; });
}
@implementation SOLCalendarsController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"显示的日历";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadCalendars) name:kPublished object:nil];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, SOLCalendarPublished, (__bridge CFStringRef)kPublished, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(requestCalendars)];
    [self requestCalendars];
}
- (void)dealloc { CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, (__bridge CFStringRef)kPublished, NULL); }
- (void)requestCalendars {
    self.waited = NO; [self reloadCalendars];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.oakstheawesome.solo/RequestCalendars"), NULL, NULL, true);
    __weak SOLCalendarsController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ weakSelf.waited = YES; [weakSelf reloadCalendars]; });
}
- (void)reloadSettings { [self reloadCalendars]; }
- (void)reloadCalendars {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    id hidden = SOLRead(@"hiddenCalendars"); self.hidden = [NSMutableSet setWithArray:[hidden isKindOfClass:NSArray.class] ? hidden : @[]];
    NSMutableDictionary *groups = [NSMutableDictionary dictionary]; NSMutableArray *accounts = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
    id records = SOLRead(@"knownCalendars");
    if ([records isKindOfClass:NSArray.class]) for (id record in records) {
        if (![record isKindOfClass:NSDictionary.class] || ![record[@"id"] isKindOfClass:NSString.class] || ![record[@"title"] isKindOfClass:NSString.class] || [seen containsObject:record[@"id"]]) continue;
        [seen addObject:record[@"id"]];
        NSString *account = [record[@"account"] isKindOfClass:NSString.class] && [record[@"account"] length] ? record[@"account"] : @"其他";
        if (!groups[account]) { groups[account] = [NSMutableArray array]; [accounts addObject:account]; }
        [groups[account] addObject:record];
    }
    self.accounts = accounts; self.calendarsByAccount = groups; [super reloadSettings];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return MAX((NSUInteger)1,self.accounts.count); }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.accounts.count ? [self.calendarsByAccount[self.accounts[section]] count] : 0; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return self.accounts.count ? self.accounts[section] : @"日历"; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.accounts.count ? @"未勾选的日历不会出现在日历页，智能轮换也会忽略其日程。" : self.waited ? @"Solo 还未发布可读日历。请在桌面打开一次日历页并授予日历权限，再点右上角刷新。" : @"正在请求主屏幕发布日历…";
}
- (NSDictionary *)calendarAt:(NSIndexPath *)path { return self.calendarsByAccount[self.accounts[path.section]][path.row]; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *record = [self calendarAt:path]; UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = record[@"title"]; cell.accessoryType = [self.hidden containsObject:record[@"id"]] ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES]; NSString *key = [self calendarAt:path][@"id"];
    if ([self.hidden containsObject:key]) [self.hidden removeObject:key]; else [self.hidden addObject:key];
    if (!SOLWrite(@{@"hiddenCalendars":[self.hidden.allObjects sortedArrayUsingSelector:@selector(compare:)]}, @[])) SOLAlert(self,@"保存失败",@"日历选择未能同步，请重试。");
    [self reloadCalendars];
}
@end

@implementation SXClockPreferences
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"时钟背景"; }
- (void)reloadSettings {
    id data = SOLRead(@"sxClockBackgroundJPEG"); self.backgroundImage = [data isKindOfClass:NSData.class] ? [UIImage imageWithData:data] : nil; [super reloadSettings];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 5; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return @"背景与磨砂设置实时保存。取消选择不会改动当前背景。"; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path { return path.row == 0 ? 180 : 58; }
- (void)opacity:(UISlider *)slider {
    if (!SOLWrite(@{@"sxClockBackdropOpacity":@(slider.value)}, @[])) SOLAlert(self,@"保存失败",@"不透明度未能同步，请重试。");
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (path.row == 0) {
        if (self.backgroundImage) {
            UIImageView *view = [[UIImageView alloc] initWithImage:self.backgroundImage]; view.contentMode = UIViewContentModeScaleAspectFill; view.clipsToBounds = YES;
            view.frame = CGRectMake(0,0,tableView.bounds.size.width-40,180); view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [cell.contentView addSubview:view];
        } else { cell.textLabel.text = @"未设置自定义背景"; cell.textLabel.textAlignment = NSTextAlignmentCenter; }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (path.row == 1) {
        cell.textLabel.text = @"模块背景不透明度";
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0,0,MIN(180,tableView.bounds.size.width*0.4),36)]; slider.minimumValue = 0; slider.maximumValue = 1;
        slider.value = fmin(1,fmax(0,[SOLRead(@"sxClockBackdropOpacity") ?: @0.55 doubleValue])); slider.continuous = NO; slider.accessibilityLabel = cell.textLabel.text;
        [slider addTarget:self action:@selector(opacity:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView = slider; cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else { cell.textLabel.text = @[@"",@"",@"从照片选择",@"从文件导入",@"清除背景"][path.row]; cell.textLabel.textColor = path.row == 4 ? UIColor.systemRedColor : self.view.tintColor; }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.row == 2) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init]; config.selectionLimit = 1; config.filter = PHPickerFilter.imagesFilter;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config]; picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else if (path.row == 3) {
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image"] inMode:UIDocumentPickerModeImport]; picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else if (path.row == 4) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"清除背景" message:@"恢复默认时钟背景？" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"清除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            self.importGeneration++;
            if (!SOLWrite(@{},@[@"sxClockBackgroundJPEG"])) SOLAlert(self,@"保存失败",@"背景未能清除，请重试。"); [self reloadSettings];
        }]]; [self presentViewController:a animated:YES completion:nil];
    }
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!results.count) return;
    NSUInteger generation = ++self.importGeneration; __weak SXClockPreferences *weakSelf = self;
    NSItemProvider *provider = results.firstObject.itemProvider;
    [provider loadDataRepresentationForTypeIdentifier:@"public.image" completionHandler:^(NSData *data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ if (weakSelf.importGeneration == generation) { if (data) [weakSelf importData:data generation:generation]; else SOLAlert(weakSelf,@"导入失败",@"无法读取所选照片。"); } });
    }];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject; if (!url) return;
    BOOL scoped = [url startAccessingSecurityScopedResource]; NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil]; if (scoped) [url stopAccessingSecurityScopedResource];
    [self importData:data generation:++self.importGeneration];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller { /* no preference mutation */ }
- (void)importData:(NSData *)data generation:(NSUInteger)generation {
    if (generation != self.importGeneration) return;
    UIImage *image = data ? [UIImage imageWithData:data] : nil;
    if (!image || image.size.width <= 0 || image.size.height <= 0) { SOLAlert(self,@"导入失败",@"所选文件不是可读取的图片，当前背景未改变。"); return; }
    CGFloat ratio = MIN(1,1600.0/MAX(image.size.width,image.size.height)); CGSize size = CGSizeMake(image.size.width*ratio,image.size.height*ratio);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat]; format.scale = 1;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIImage *resized = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [image drawInRect:(CGRect){CGPointZero,size}]; }];
    NSData *jpeg = UIImageJPEGRepresentation(resized,0.85);
    if (!jpeg || !SOLWrite(@{@"sxClockBackgroundJPEG":jpeg},@[])) SOLAlert(self,@"保存失败",@"背景图片未能同步，请重试。");
    [self reloadSettings];
}
@end
