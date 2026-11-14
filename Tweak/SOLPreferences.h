#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const SOLPreferenceDomain;
FOUNDATION_EXPORT NSString * const SOLReloadNotification;
FOUNDATION_EXPORT NSString * const SOLPreferencesDidReloadNotification;

@interface SOLPreferences : NSObject
+ (instancetype)shared;
- (void)reload;
- (BOOL)enabled;
- (BOOL)enhancementsEnabled;
- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)value;
- (double)doubleForKey:(NSString *)key defaultValue:(double)value;
- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)value;
- (nullable id)objectForKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
