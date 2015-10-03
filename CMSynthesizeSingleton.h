//
//  SingletonGCD.h
// From Github From 2010 WWDC video

#import <Foundation/Foundation.h>

#ifndef SYNTHESIZE_SINGLETON_FOR_CLASS
#define SYNTHESIZE_SINGLETON_FOR_CLASS(classname, predicatename)        \
\
__strong static classname * predicatename = nil;    \
+ (classname *)predicatename {                      \
\
static dispatch_once_t pred;                            \
dispatch_once( &pred, ^{                                \
predicatename = [[self alloc] init]; });            \
return predicatename;                               \
}
#endif
