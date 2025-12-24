//
//  VideoTool.h
//  PSStreaming
//
//  Created by FM on 2025/3/11.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

extern "C" {
#import <ffmpeg/libavcodec/avcodec.h>
#import <ffmpeg/libavutil/frame.h>
#import <ffmpeg/libavutil/imgutils.h>
}

NS_ASSUME_NONNULL_BEGIN

@interface VideoTool : NSObject

/// 实例
+ (instancetype)sharedInstance;

- (void)setFPS:(NSInteger)fps;

- (CMSampleBufferRef)getRenderDataWithFrame:(AVFrame *)avFrame;

- (void)clear;

@end

NS_ASSUME_NONNULL_END
