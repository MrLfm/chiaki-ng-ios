//
//  AudioReceiver.h
//  PSStreamingDemo
//
//  Created by FM on 2025/3/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioProcessor : NSObject

- (void)receiveAudioData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
