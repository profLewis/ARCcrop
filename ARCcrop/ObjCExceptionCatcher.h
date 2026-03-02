#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Executes a block and catches any Objective-C exceptions.
/// Returns YES if the block completed without an exception, NO otherwise.
BOOL ObjCTryCatch(void (NS_NOESCAPE ^block)(void), NSError * _Nullable __autoreleasing * _Nullable error);

NS_ASSUME_NONNULL_END
