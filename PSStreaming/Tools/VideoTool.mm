//
//  RenderTool.m
//  PSStreaming
//
//  Created by FM on 2025/3/11.
//

#import "VideoTool.h"
#import "libyuv/libyuv.h"

#define CLAMP(x, min, max) ((x) < (min) ? (min) : ((x) > (max) ? (max) : (x)))

@interface VideoTool ()
@property (nonatomic, assign) int64_t presentationTimestamp;// AVSampleBufferDisplayLayer 是用于显示视频帧的，需要正确的时间戳来确保帧能按顺序渲染。如果每一帧的时间戳都相同，可能会导致渲染层只显示第一帧。因此，需要确保每一帧的时间戳递增。
@property (nonatomic, assign) CVPixelBufferPoolRef pixelBufferPool;
@property (nonatomic, assign) NSInteger frameFPS;
@property (nonatomic, assign) NSInteger frameWidth;
@property (nonatomic, assign) NSInteger frameHeight;
@end

@implementation VideoTool

+ (instancetype)sharedInstance {
    static VideoTool *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [VideoTool.alloc init];
        instance.frameFPS = 30;// 默认30帧
    });
    return instance;
}

- (CMSampleBufferRef)getRenderDataWithFrame:(AVFrame *)avFrame {
    // 创建 CVPixelBuffer
    CVPixelBufferRef pixelBuffer = [self getPixelBufferFromFrame:avFrame];
    if (!pixelBuffer) {
//        NSLog(@"创建 CVPixelBuffer 失败！");
        return nil;
    }
    
    // 创建 CMSampleBuffer
    CMSampleBufferRef sampleBuffer = [self getSampleBufferFromPixelBuffer:pixelBuffer];
    if (!sampleBuffer) {
//        NSLog(@"创建 CMSampleBuffer 失败！");
        CVPixelBufferRelease(pixelBuffer);
        return nil;
    }
    
    CVPixelBufferRelease(pixelBuffer);// 释放 CVPixelBuffer
    return sampleBuffer;
}

- (CVPixelBufferRef)getPixelBufferFromFrame:(AVFrame *)avFrame {
    if (_pixelBufferPool == nil
        || avFrame->width != self.frameWidth
        || avFrame->height != self.frameHeight) {// 当修改分辨率后，必须重新创建pixelBufferPool，否则I420ToARGB转换会崩溃（从小分辨率切换成大分辨率），或者画面大小显示不正确（从大分辨率切换成小分辨率）
        self.frameWidth = avFrame->width;
        self.frameHeight = avFrame->height;
        [self setupPixelBufferPoolWithWidth:avFrame->width height:avFrame->height];
    }
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferPoolCreatePixelBuffer(NULL, _pixelBufferPool, &pixelBuffer);
    if (!pixelBuffer) return NULL;
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    uint8_t *pixelData = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
    // yuv420p 格式转ARGB格式
    libyuv::I420ToARGB(avFrame->data[0],
                       avFrame->linesize[0],
                       avFrame->data[1],
                       avFrame->linesize[1],
                       avFrame->data[2],
                       avFrame->linesize[2],
                       pixelData,
                       avFrame->width * 4,
                       avFrame->width,
                       avFrame->height);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

- (void)setupPixelBufferPoolWithWidth:(int)width height:(int)height {
    NSLog(@"设置PixelBufferPool：宽%@ 高%@", @(width), @(height));
    NSDictionary *attributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey: @(width),
        (id)kCVPixelBufferHeightKey: @(height),
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };
    
    CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)attributes, &_pixelBufferPool);
}

// 将 CVPixelBuffer 转换为 CMSampleBuffer
- (CMSampleBufferRef)getSampleBufferFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CMSampleBufferRef sampleBuffer = NULL;
    
    // 创建 CMVideoFormatDescription
    CMFormatDescriptionRef formatDescription = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDescription);
    
    if (formatDescription) {
        // 设置帧的时间戳和持续时间
        CMTime presentationTimeStamp = CMTimeMake(self.presentationTimestamp, (int32_t)_frameFPS);
        CMTime duration = CMTimeMake(1, (int32_t)_frameFPS); // 帧的持续时间
        
        // 设置样本的时间信息
        CMSampleTimingInfo sampleTiming = {
            .presentationTimeStamp = presentationTimeStamp,
            .duration = duration,
            .decodeTimeStamp = kCMTimeInvalid // 如果没有解码时间，可以设置为无效
        };
        
        // 创建 CMSampleBuffer
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, formatDescription, &sampleTiming, &sampleBuffer);
        
        // 释放格式描述
        CFRelease(formatDescription);
        
        // 更新时间戳
        self.presentationTimestamp += 1; // 每次增加时间戳，或根据帧率调整
    }
    
    return sampleBuffer;
}

- (void)clear {
    if (_pixelBufferPool) {
        CVPixelBufferPoolRelease(_pixelBufferPool);
    }
    _pixelBufferPool = nil;
}

- (void)setFPS:(NSInteger)fps {
    if (fps != 30
        && fps != 60) {
        return;
    }
    _frameFPS = fps;
}

@end
