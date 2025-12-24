#import <AVFoundation/AVFoundation.h>

#define SAMPLE_RATE 48000
#define CHANNELS 2
#define BUFFER_SIZE 480

@interface AudioProcessor : NSObject
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioPlayerNode *playerNode;
@property (nonatomic, strong) AVAudioConverter *audioConverter;
@property (nonatomic, strong) AVAudioFormat *aacFormat;
@property (nonatomic, strong) AVAudioFormat *pcmFormat;
@property (nonatomic, strong) NSMutableData *audioData;
@property (nonatomic, strong) NSMutableArray<AVAudioPCMBuffer *> *bufferQueue;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) NSInteger msCount;// 毫秒数
@end

@implementation AudioProcessor

- (instancetype)init {
    if (self = [super init]) {
        _audioData = [[NSMutableData alloc] init];
        _audioEngine = [[AVAudioEngine alloc] init];
        _playerNode = [[AVAudioPlayerNode alloc] init];
        
        _pcmFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:SAMPLE_RATE channels:CHANNELS interleaved:YES];
        _aacFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:SAMPLE_RATE channels:CHANNELS interleaved:NO];
        _audioConverter = [[AVAudioConverter alloc] initFromFormat:_pcmFormat toFormat:_aacFormat];
        
        [_audioEngine attachNode:_playerNode];
        [_audioEngine connect:_playerNode to:_audioEngine.mainMixerNode format:_aacFormat];
        
        _bufferQueue = [[NSMutableArray alloc] init];
        _isPlaying = NO;
        
        NSError *error = nil;
        if (![_audioEngine startAndReturnError:&error]) {
            NSLog(@"Audio Engine start error: %@", error);
        }
        
        [_playerNode play];
        
        self.msCount = 20;
    }
    return self;
}

- (void)receiveAudioData:(NSData *)data {
    if (!_audioData) {
        _audioData = [[NSMutableData alloc] init];
    }
    [_audioData appendData:data];
    
    NSInteger maxCount = 192*self.msCount;// 192 bytes = 1ms
    if (_audioData.length >= maxCount) {
        NSData *bufferedPCMData = [_audioData subdataWithRange:NSMakeRange(0, maxCount)];
        [_audioData replaceBytesInRange:NSMakeRange(0, maxCount) withBytes:NULL length:0];
        
        [self playBufferedPCMData:bufferedPCMData];
    }
}

- (void)playBufferedPCMData:(NSData *)data {
    AVAudioFrameCount frameCount = (AVAudioFrameCount)(data.length / (CHANNELS * 2));// 帧数
    
    // 使用convertToBuffer转换
    AVAudioPCMBuffer *pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_pcmFormat frameCapacity:frameCount];
    pcmBuffer.frameLength = frameCount;
    int16_t *sourcePCM = (int16_t *)data.bytes;
    int16_t *leftChannel = pcmBuffer.int16ChannelData[0];
    int16_t *rightChannel = pcmBuffer.int16ChannelData[1];
    for (int i = 0; i < frameCount; i++) {
        leftChannel[i] = sourcePCM[i * 2];
        rightChannel[i] = sourcePCM[i * 2 + 1];
    }
    AVAudioPCMBuffer *aacBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_aacFormat frameCapacity:frameCount];
    aacBuffer.frameLength = frameCount;
    NSError *error = nil;
    [_audioConverter convertToBuffer:aacBuffer fromBuffer:pcmBuffer error:&error];
    if (error) {
        NSLog(@"AAC Conversion Error: %@", error);
        return;
    }
    
    @synchronized (self.bufferQueue) {
        [self.bufferQueue addObject:aacBuffer];
    }
    
    [self tryPlayAudio];
}

- (void)tryPlayAudio {
    if (_isPlaying) return;
    
    @synchronized (self.bufferQueue) {
        if (self.bufferQueue.count < 3) return; // 缓冲 3 个 buffer 后再播放，减少卡顿
        _isPlaying = YES;
    }
    
    [self playNextBuffer];
}

- (void)playNextBuffer {
    AVAudioPCMBuffer *nextBuffer = nil;
    @synchronized (self.bufferQueue) {
        if (self.bufferQueue.count > 0) {
            nextBuffer = [self.bufferQueue firstObject];
            [self.bufferQueue removeObjectAtIndex:0];
        } else {
            _isPlaying = NO;
            return;
        }
    }
    
    [_playerNode scheduleBuffer:nextBuffer completionHandler:^{
        [self playNextBuffer];
    }];
}

@end
