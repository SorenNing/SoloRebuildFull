#pragma once
#import <objc/message.h>
#import <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*SOLIMP)(void);
void MSHookMessageEx(Class cls, SEL sel, IMP replacement, IMP *result);
void MSHookFunction(void *symbol, void *replace, void **result);

#ifdef __cplusplus
}
#endif
