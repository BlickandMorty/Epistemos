#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Catches Objective-C exceptions (NSException) and bridges them to Swift errors.
/// Needed because Swift's do/catch cannot intercept NSException — only Swift Error.
@interface ObjCExceptionCatcher : NSObject

/// Runs the block inside @try/@catch. If an NSException is thrown,
/// it is converted to an NSError and returned via the error pointer.
+ (BOOL)catchException:(void (NS_NOESCAPE ^)(void))block
                 error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
