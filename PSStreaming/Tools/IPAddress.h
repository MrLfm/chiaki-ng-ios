//
//  IPAddress.h
//  PSStreamingDemo
//
//  Created by FM on 2025/3/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IPAddress : NSObject

+ (NSString *)getWiFiIPAddress;

+ (BOOL)checkIfConnectedWiFiWithIP:(NSString *)ip;

@end

NS_ASSUME_NONNULL_END
