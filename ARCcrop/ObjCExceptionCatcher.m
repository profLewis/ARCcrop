#import "ObjCExceptionCatcher.h"

BOOL ObjCTryCatch(void (NS_NOESCAPE ^block)(void), NSError * _Nullable __autoreleasing *error) {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"ObjCException"
                                         code:-1
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason ?: @"unknown"]
            }];
        }
        NSLog(@"Caught ObjC exception: %@ — %@\n%@", exception.name, exception.reason, exception.callStackSymbols);
        return NO;
    }
}
