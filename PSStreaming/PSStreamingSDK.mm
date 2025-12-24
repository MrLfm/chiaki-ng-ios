//
//  PSStreamingSDK.m
//  PSStreaming
//
//  Created by FM on 2025/3/13.
//

#import "PSStreamingSDK.h"
#import "VideoTool.h"
#import "IPAddress.h"

#import <chiaki/regist.h>
#import <chiaki/session.h>
#import <chiaki/streamconnection.h>
#import <chiaki/common.h>
#import <chiaki/discovery.h>
#import <chiaki/discoveryservice.h>
#import <chiaki/base64.h>
#import <chiaki/log.h>
#import <chiaki/takion.h>

// 视频
#import <chiaki/ffmpegdecoder.h>
extern "C" {
#include <ffmpeg/libswscale/swscale.h>
#include <ffmpeg/libavutil/avutil.h>
#include <ffmpeg/libavutil/imgutils.h>
#include <ffmpeg/libavutil/log.h>
#include <ffmpeg/libavutil/pixfmt.h>
}

// 音频
#import <chiaki/opusdecoder.h>
#import <chiaki/opusencoder.h>
#include <SDL2/SDL.h>
#include <stdio.h>
#include <_time.h>// 导入这个头文件，解决因导入#include <vector>而报错：In file included from /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.1.sdk/usr/include/c++/v1/vector:325: error: use of undeclared identifier 'nanosleep' 和 error: member access into incomplete type 'tm'
#include <vector>
#include <mutex>

#import <SystemConfiguration/SystemConfiguration.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#include <stdlib.h>
#include <stdio.h>

#include <openssl/opensslv.h>
#include <openssl/evp.h>
#include <openssl/objects.h>
//#include <openssl/provider.h>
#include <openssl/err.h>


#define NSLog(fmt, ...) { \
if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnableDebugLogs"]) {\
NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init]; \
[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"]; \
NSString *currentDateString = [dateFormatter stringFromDate:[NSDate date]]; \
NSLog((@"%s [%d行] PSStreaming- " fmt), [currentDateString UTF8String], __LINE__, ##__VA_ARGS__); \
}\
}\

NSInteger const PSControllerTouchpadWidth = 1920;
NSInteger const PSControllerTouchpadHeight = 940;

NSString * const PSRegistedHostKey_ip = @"ip";
NSString * const PSRegistedHostKey_target = @"target";
NSString * const PSRegistedHostKey_ap_ssid = @"ap_ssid";
NSString * const PSRegistedHostKey_ap_bssid = @"ap_bssid";
NSString * const PSRegistedHostKey_ap_key = @"ap_key";
NSString * const PSRegistedHostKey_ap_name = @"ap_name";
NSString * const PSRegistedHostKey_server_nickname = @"server_nickname";
NSString * const PSRegistedHostKey_rp_key_type = @"rp_key_type";
NSString * const PSRegistedHostKey_server_mac = @"server_mac";
NSString * const PSRegistedHostKey_rp_key = @"rp_key";
NSString * const PSRegistedHostKey_rp_regist_key = @"rp_regist_key";
NSString * const PSRegistedHostKey_console_pin = @"console_pin";

NSString * const PSFoundHostKey_ip = @"ip";
NSString * const PSFoundHostKey_target = @"target";// 主机类型
NSString * const PSFoundHostKey_server_nickname = @"server_nickname";
NSString * const PSFoundHostKey_state = @"state";// 状态
NSString * const PSFoundHostKey_protocol = @"protocol";// 协议
NSString * const PSFoundHostKey_hostID = @"hostID";// ID
NSString * const PSFoundHostKey_port = @"port";// 端口
NSString * const PSFoundHostKey_sys_version = @"sys_version";// 系统版本

#define SAMPLE_RATE 48000
#define CHANNELS 2
#define SAMPLE_FORMAT AUDIO_S16SYS  // 16-bit PCM

typedef void(^PingCallback)(BOOL isOnline);
// 唤醒主机的回调
typedef void (^PSWakeupCallback)(BOOL isAwakened);

@interface PSStreamingSDK ()
@property (nonatomic, copy) PSScanHostResultCallback scanCallback;
@property (nonatomic, copy) PingCallback pingCallback;
@property (nonatomic, copy) PSRegistCallback registCallback;
@property (nonatomic, copy) PSConnectResultCallback connectResultCallback;
@property (nonatomic, copy) PSVideoCallback videoCallback;
@property (nonatomic, copy) PSAudioCallback audioCallback;
@property (nonatomic, copy) PSHapticsCallback hapticsCallback;
@property (nonatomic, assign) ChiakiControllerState controllerState;

@property (nonatomic, assign) BOOL isExchangedABXYLayout;
@end

@implementation PSStreamingSDK

- (NSString *)version {
    return @"0.0.1";
}

+ (instancetype)sharedInstance {
    static PSStreamingSDK *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PSStreamingSDK.alloc init];
        printf("OpenSSL version: %s\n", OPENSSL_VERSION_TEXT);
//        print_all_ciphers();
        
//        OSSL_PROVIDER *provider = OSSL_PROVIDER_load(NULL, "default");
//        if (!provider)
//        {
//            fprintf(stderr, "加载 default provider 失败\n");
//            ERR_print_errors_fp(stderr);  // 这时 ERR_get_error() 是有意义的
//        }
    });
    return instance;
}

//void print_all_ciphers()
//{
//    EVP_CIPHER *cipher = NULL;
//    int i = 0;
//    while ((cipher = (EVP_CIPHER *)EVP_get_cipherbynid(i++)))
//    {
//        const char *name = EVP_CIPHER_name(cipher);
//        if (name)
//            printf("cipher: %s\n", name);
//    }
//}

- (void)enbaleDebugLog:(BOOL)enabled {
    CHIAKI_LOG_ENABLED = enabled;
    
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:@"EnableDebugLogs"];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        kPSStreamingSDK = self; // 将当前实例保存到全局变量
        chiaki_controller_state_set_idle(&_controllerState); // 初始化为空闲状态
    }
    return self;
}


// 声明一个全局变量来保存 Objective-C 对象
static PSStreamingSDK *kPSStreamingSDK = nil;

#pragma mark - 注册

ChiakiRegist regist;
NSString *kIp = @"";
- (void)registHostWithPSType:(PSHostType)type
                   ipAddress:(NSString *)ip
                   accountID:(NSString *)accountID
                     pinCode:(NSInteger)pin
                    callback:(PSRegistCallback)callback {
    if (!ip
        || [ip isEqualToString:@""]) {
        NSLog(@"注册失败！原因：IP地址为空");
        return;
    }
    
    if (!accountID
        || [accountID isEqualToString:@""]) {
        NSLog(@"注册失败！原因：账号ID为空");
        return;
    }
    
    //    NSLog(@"注册传入参数：type：%@，ip：%@，accountID：%@，pin：%@", @(type), ip, accountID, @(pin));
    
    self.registCallback = callback;
    
    ChiakiRegistInfo info;
    info.pin = (uint32_t)pin;
    info.psn_online_id = NULL;
    info.holepunch_info = NULL;
    info.broadcast = false;
    info.target = (ChiakiTarget)type;
    info.host = ip.UTF8String;
    kIp = ip;
    const char *account_str = accountID.UTF8String;// 该数据经过base64编码
    //    base64_decode(account_str, info.psn_account_id, sizeof(info.psn_account_id));// base64解码
    
    size_t decoded_size = CHIAKI_PSN_ACCOUNT_ID_SIZE;
    uint8_t decoded_output[decoded_size];
    chiaki_base64_decode(account_str, strlen(account_str), decoded_output, &decoded_size);
    memcpy(info.psn_account_id, decoded_output, decoded_size);
    
    
//    ChiakiLog log;
    // 调用chiaki_regist_start进行设备注册
    ChiakiErrorCode err = chiaki_regist_start(&regist, NULL, &info, regist_callback, NULL);
    if (err != CHIAKI_ERR_SUCCESS) {
        NSLog(@"chiaki_regist_start 失败！原因：%@", @(err));
    }
}

/// 注册回调
/**
 typedef struct chiaki_registered_host_t
 {
 ChiakiTarget target;
 char ap_ssid[0x30];
 char ap_bssid[0x20];
 char ap_key[0x50];
 char ap_name[0x20];
 uint8_t server_mac[6];// mac地址？
 char server_nickname[0x20];
 char rp_regist_key[CHIAKI_SESSION_AUTH_SIZE]; // must be completely filled (pad with \0) // 对应ChiakiConnectInfo的char regist_key[CHIAKI_SESSION_AUTH_SIZE]
 uint32_t rp_key_type;
 uint8_t rp_key[0x10];// 对应ChiakiConnectInfo的uint8_t morning[0x10]
 uint32_t console_pin;
 } ChiakiRegisteredHost;
 */
ChiakiRegisteredHost *registeredHost;
void regist_callback(ChiakiRegistEvent *event, void *user) {
    PSHostType type = PSHostTypePS4_UNKNOWN;
    NSData *rpKeyData = nil;
    NSData *rpRegistKeyData = nil;
    
    // 处理注册事件
    if (event->type == CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS) {
        NSLog(@"注册成功");
        /** 已注册主机信息
         typedef struct chiaki_registered_host_t
         {
         ChiakiTarget target;
         char ap_ssid[0x30];
         char ap_bssid[0x20];
         char ap_key[0x50];
         char ap_name[0x20];
         uint8_t server_mac[6];
         char server_nickname[0x20];
         char rp_regist_key[CHIAKI_SESSION_AUTH_SIZE]; // must be completely filled (pad with \0) // 对应ChiakiConnectInfo的char regist_key[CHIAKI_SESSION_AUTH_SIZE]
         uint32_t rp_key_type;
         uint8_t rp_key[0x10];// 对应ChiakiConnectInfo的uint8_t morning[0x10]
         uint32_t console_pin;
         } ChiakiRegisteredHost;
         */
        registeredHost = event->registered_host;
        chiaki_regist_fini(&regist);
        
        type = (PSHostType)registeredHost->target;
        rpKeyData = [NSData dataWithBytes:registeredHost->rp_key length:sizeof(registeredHost->rp_key)];
        rpRegistKeyData = [NSData dataWithBytes:registeredHost->rp_regist_key length:sizeof(registeredHost->rp_regist_key)];
        
        if (kPSStreamingSDK.registCallback) {
            NSMutableDictionary *info = @{}.mutableCopy;
            /**
             target字段的说明：
             注册后返回的target值是整数，但是安卓端通过转换方法转为字符串，并保存为导出是json数据。
             我们只能跟安卓做成一样的数据类型，把整数映射成对应的字符串。
             安卓端的转换方法：
             CHIAKI_TARGET_PS4_UNKNOWN -> "PS4_UNKNOWN"
             CHIAKI_TARGET_PS4_8 -> "PS4_8"
             CHIAKI_TARGET_PS4_9 -> "PS4_9"
             CHIAKI_TARGET_PS4_10 -> "PS4_10"
             CHIAKI_TARGET_PS5_UNKNOWN -> "PS5_UNKNOWN"
             CHIAKI_TARGET_PS5_1 -> "PS5_1"
             */
            info[PSRegistedHostKey_target] = [kPSStreamingSDK getPSHostNameWithType:(PSHostType)registeredHost->target];
            info[PSRegistedHostKey_ap_ssid] = [NSString stringWithUTF8String:registeredHost->ap_ssid];
            info[PSRegistedHostKey_ap_bssid] = [NSString stringWithUTF8String:registeredHost->ap_bssid];
            info[PSRegistedHostKey_ap_key] = [NSString stringWithUTF8String:registeredHost->ap_key];
            info[PSRegistedHostKey_ap_name] = [NSString stringWithUTF8String:registeredHost->ap_name];
            info[PSRegistedHostKey_server_nickname] = [NSString stringWithUTF8String:registeredHost->server_nickname];
            info[PSRegistedHostKey_rp_key_type] = @(registeredHost->rp_key_type);
            
            NSString *server_mac = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                                    registeredHost->server_mac[0], registeredHost->server_mac[1], registeredHost->server_mac[2],
                                    registeredHost->server_mac[3], registeredHost->server_mac[4], registeredHost->server_mac[5]];
            info[PSRegistedHostKey_server_mac] = server_mac;
            
            size_t encoded_size = ((sizeof(registeredHost->rp_key) + 2) / 3) * 4 + 1; // Base64 编码规则
            char encoded_output[encoded_size];
            ChiakiErrorCode err = chiaki_base64_encode(registeredHost->rp_key, sizeof(registeredHost->rp_key), encoded_output, sizeof(encoded_output));
            if (err == CHIAKI_ERR_SUCCESS) {
                NSString *encodedString = [NSString stringWithUTF8String:encoded_output];
                info[PSRegistedHostKey_rp_key] = encodedString;
            }
            else {
                info[PSRegistedHostKey_rp_key] = @"";
            }
            
            size_t encoded_size1 = ((sizeof(registeredHost->rp_regist_key) + 2) / 3) * 4 + 1; // Base64 编码规则
            char encoded_output1[encoded_size1];
            err = chiaki_base64_encode((uint8_t *)registeredHost->rp_regist_key, sizeof(registeredHost->rp_regist_key), encoded_output1, sizeof(encoded_output1));
            if (err == CHIAKI_ERR_SUCCESS) {
                NSString *encodedString = [NSString stringWithUTF8String:encoded_output1];
                info[PSRegistedHostKey_rp_regist_key] = encodedString;
            }
            else {
                info[PSRegistedHostKey_rp_regist_key] = @"";
            }
            
            info[PSRegistedHostKey_console_pin] = @(registeredHost->console_pin);
            info[PSRegistedHostKey_ip] = kIp;
            kPSStreamingSDK.registCallback((PSRegistResultType)event->type, info.copy);
        }
    } else if (event->type == CHIAKI_REGIST_EVENT_TYPE_FINISHED_FAILED) {
        NSLog(@"注册失败！");
        if (kPSStreamingSDK.registCallback) {
            kPSStreamingSDK.registCallback((PSRegistResultType)event->type, @{});
        }
    } else if (event->type == CHIAKI_REGIST_EVENT_TYPE_FINISHED_CANCELED) {
        NSLog(@"已取消注册");
        if (kPSStreamingSDK.registCallback) {
            kPSStreamingSDK.registCallback((PSRegistResultType)event->type, @{});
        }
    }
    
    // TODO: 将kPSStreamingSDK.registCallback设为nil？
}

- (PSHostType)getPSHostTypeWithName:(NSString *)name {
    if (!name
        || [name isEqualToString:@""]) {
        NSLog(@"主机名称为空，默认返回主机类型：PSHostTypePS4_UNKNOWN");
        return PSHostTypePS4_UNKNOWN;
    }
    
    if ([name isEqualToString:@"PS4_UNKNOWN"]) {
        return PSHostTypePS4_UNKNOWN;
    }
    else if ([name isEqualToString:@"PS4_8"]) {
        return PSHostTypePS4_8;
    }
    else if ([name isEqualToString:@"PS4_9"]) {
        return PSHostTypePS4_9;
    }
    else if ([name isEqualToString:@"PS4_10"]
             || [name isEqualToString:@"PS4"]) {
        return PSHostTypePS4_10;
    }
    else if ([name isEqualToString:@"PS5_UNKNOWN"]) {
        return PSHostTypePS5_UNKNOWN;
    }
    else if ([name isEqualToString:@"PS5_1"]
             || [name isEqualToString:@"PS5"]) {
        return PSHostTypePS5_1;
    }
    else {
        return PSHostTypePS4_UNKNOWN;
    }
}

- (NSString *)getPSHostNameWithType:(PSHostType)type {
    switch (type) {
        case PSHostTypePS4_UNKNOWN: {
            return @"PS4_UNKNOWN";
        }
        case PSHostTypePS4_8: {
            return @"PS4_8";
        }
        case PSHostTypePS4_9: {
            return @"PS4_9";
        }
        case PSHostTypePS4_10: {
            return @"PS4_10";
        }
        case PSHostTypePS5_UNKNOWN: {
            return @"PS5_UNKNOWN";
        }
        case PSHostTypePS5_1: {
            return @"PS5_1";
        }
        default: {
            NSLog(@"未知主机类型，默认返回主机名称：PS4_UNKNOWN");
            return @"PS4_UNKNOWN";
        }
    }
}

#pragma mark - 连接
bool session_started;
ChiakiSession session;// 必须全局持有。如果中途被销毁，将导致连接主机失败
AVBufferRef *bufferRef = nullptr;
ChiakiFfmpegDecoder *ffmpegDecoder;// 视频解码
ChiakiOpusDecoder opus_decoder;// 音频解码
//ChiakiOpusEncoder opus_encoder;// 音频编码（麦克风输入音频时使用）
ChiakiAudioSink audio_sink;// 音频原数据回调
ChiakiAudioSink haptics_sink;// 体感原数据回调
- (void)connectHostWithPSType:(PSHostType)type
                    ipAddress:(NSString *)ip
                        rpKey:(NSString *)rpKey
                  rpRegistKey:(NSString *)rpRegistKey
                   resolution:(PSResolutionType)resolution
                      bitrate:(NSInteger)bitrate
                          fps:(PSFpsType)fps
                       encode:(PSEncodeType)encode
               resultCallback:(PSConnectResultCallback _Nullable)resultCallback
                videoCallback:(PSVideoCallback _Nullable)videoCallback
                audioCallback:(PSAudioCallback _Nullable)audioCallback
              hapticsCallback:(PSHapticsCallback _Nullable)hapticsCallback {
    if (session_started) {
        NSLog(@"已建立连接，请先断开连接");
        return;
    }
    
    if (!ip
        || [ip isEqualToString:@""]) {
        NSLog(@"连接失败！原因：IP地址为空");
        return;
    }
    
    if (!rpKey
        || [rpKey isEqualToString:@""]) {
        NSLog(@"连接失败！原因：rpKey为空");
        return;
    }
    
    if (!rpRegistKey
        || [rpRegistKey isEqualToString:@""]) {
        NSLog(@"连接失败！原因：rpRegistKey为空");
        return;
    }
    
    session_started = false;
    
    self.connectResultCallback = resultCallback;
    self.videoCallback = videoCallback;
    self.audioCallback = audioCallback;
    self.hapticsCallback = hapticsCallback;
    
    ChiakiVideoResolutionPreset resolutionPreset = (ChiakiVideoResolutionPreset)resolution;
    ChiakiVideoFPSPreset fpsPreset = (ChiakiVideoFPSPreset)fps;
    ChiakiConnectVideoProfile videoProfile;
    chiaki_connect_video_profile_preset(&videoProfile, resolutionPreset, fpsPreset);// 根据分辨率设置码率
    if (bitrate != 0) {
        if (bitrate < 2000) {
            bitrate = 2000;
        }
        if (bitrate > 15000) {
            bitrate = 15000;
        }
        videoProfile.bitrate = (int)bitrate;
    }
    //    NSLog(@"分辨率：%@*%@，码率：%@", @(videoProfile.width), @(videoProfile.height), @(videoProfile.bitrate));
    videoProfile.codec = (ChiakiCodec)encode;
    [VideoTool.sharedInstance setFPS:fpsPreset];
    
    ChiakiConnectInfo connectInfo;
    connectInfo.video_profile = videoProfile;
    connectInfo.holepunch_session = NULL;// 非局域网使用
    connectInfo.auto_regist = false;
    connectInfo.host = ip.UTF8String;
    connectInfo.enable_dualsense = true;// 支持振动反馈，开启后才会收到体感数据
    connectInfo.ps5 = (ChiakiTarget)type == CHIAKI_TARGET_PS5_1;
    if (rpKey) {
        const char *encoded_rp_key = rpKey.UTF8String;
        size_t decoded_size = 0x10;
        uint8_t decoded_output[decoded_size];
        chiaki_base64_decode(encoded_rp_key, strlen(encoded_rp_key), decoded_output, &decoded_size);// 解码
        memcpy(connectInfo.morning, decoded_output, decoded_size);
    }
    
    if (rpRegistKey) {
        const char *encoded_rp_regist_key = rpRegistKey.UTF8String;
        size_t decoded_size = CHIAKI_SESSION_AUTH_SIZE;
        uint8_t decoded_output[decoded_size];
        chiaki_base64_decode(encoded_rp_regist_key, strlen(encoded_rp_regist_key), decoded_output, &decoded_size);// 解码
        memcpy(connectInfo.regist_key, decoded_output, decoded_size);
    }
    
    ChiakiErrorCode code;
    // 初始化
    code = chiaki_session_init(&session, &connectInfo, NULL);
    if (code != CHIAKI_ERR_SUCCESS) {
        NSLog(@"chiaki_session_init 失败！");
        return;
    }
    
    // 回调设置
    {
        // session事件回调
        chiaki_session_set_event_cb(&session, chiakiEventCallback, NULL);// 注意！这个回调不能太晚设置，否则（如果主机处于连接状态）可能接收不到第一个event回调。
        
        // 视频
        if (bufferRef) {
            av_buffer_unref(&bufferRef);
            bufferRef = nullptr;
        }
        ffmpegDecoder = new ChiakiFfmpegDecoder;
        code = chiaki_ffmpeg_decoder_init(ffmpegDecoder, NULL, connectInfo.video_profile.codec, NULL, bufferRef, videoFrameCallback, NULL);// 设置ffmpeg解码器
        if(code != CHIAKI_ERR_SUCCESS) {
            NSLog(@"chiaki_ffmpeg_decoder_init 失败！");
        }
        chiaki_session_set_video_sample_cb(&session, videoSampleCallback, ffmpegDecoder);// 视频解码回调
        
        // 音频
        chiaki_opus_decoder_init(&opus_decoder, NULL);
        chiaki_opus_decoder_set_cb(&opus_decoder, audioSettingsCallback, audioFrameCallback, NULL);// 音频解码回调
        chiaki_opus_decoder_get_sink(&opus_decoder, &audio_sink);
        chiaki_session_set_audio_sink(&session, &audio_sink);
        
        [self initAudioPlayer];
        
        // 麦克风音频编码
        //    ChiakiAudioHeader audio_header;
        //    chiaki_audio_header_set(&audio_header, 2, 16, 480 * 100, 480);
        //    chiaki_opus_encoder_header(&audio_header, &opus_encoder, &session);
        
        // 体感（包括振动）
        haptics_sink.user = NULL;
        haptics_sink.frame_cb = chiakiHapticsCallback;
        chiaki_session_set_haptics_sink(&session, &haptics_sink);
    }
    
    // 开始连接
    code = chiaki_session_start(&session);
    if (code != CHIAKI_ERR_SUCCESS) {
        NSLog(@"chiaki_session_start 失败！");
        return;
    }
    
    session_started = true;
}

// 连接事件回调

void chiakiEventCallback(ChiakiEvent *event, void *user) {
    [kPSStreamingSDK handleConnectEvent:event];
}

- (void)handleConnectEvent:(ChiakiEvent *)event {
    NSLog(@"ChiakiEvent类型：%@", @(event->type));
    
    if (event->type == CHIAKI_EVENT_CONNECTED) {
        NSLog(@"连接成功");
        if (self.connectResultCallback) {
            self.connectResultCallback(PSConnectResultTypeSuccess);
        }
    }
    else if (event->type == CHIAKI_EVENT_QUIT) {
        session_started = false;
        
        /** event->quit.reason，退出原因（包括主动退出和被动退出）：
         CHIAKI_QUIT_REASON_NONE,
         CHIAKI_QUIT_REASON_STOPPED,
         CHIAKI_QUIT_REASON_SESSION_REQUEST_UNKNOWN,// 主机处于待机时返回
         CHIAKI_QUIT_REASON_SESSION_REQUEST_CONNECTION_REFUSED,
         CHIAKI_QUIT_REASON_SESSION_REQUEST_RP_IN_USE,// 主机已被连接
         CHIAKI_QUIT_REASON_SESSION_REQUEST_RP_CRASH,
         CHIAKI_QUIT_REASON_SESSION_REQUEST_RP_VERSION_MISMATCH,
         CHIAKI_QUIT_REASON_CTRL_UNKNOWN,
         CHIAKI_QUIT_REASON_CTRL_CONNECT_FAILED,
         CHIAKI_QUIT_REASON_CTRL_CONNECTION_REFUSED,
         CHIAKI_QUIT_REASON_STREAM_CONNECTION_UNKNOWN,
         CHIAKI_QUIT_REASON_STREAM_CONNECTION_REMOTE_DISCONNECTED,
         CHIAKI_QUIT_REASON_STREAM_CONNECTION_REMOTE_SHUTDOWN, // like REMOTE_DISCONNECTED, but because the server shut down
         CHIAKI_QUIT_REASON_PSN_REGIST_FAILED,
         */
        NSLog(@"session已退出！状态：%d，原因：%s", event->quit.reason, event->quit.reason_str);
        PSConnectResultType result = PSConnectResultTypeFailed_UNNKOWN;
        switch (event->quit.reason) {
            case CHIAKI_QUIT_REASON_SESSION_REQUEST_RP_IN_USE: {
                NSLog(@"主机已被连接");
                result = PSConnectResultTypeFailed_IN_USE;
                if (self.connectResultCallback) {
                    self.connectResultCallback(result);
                }
                [self clearDataFromConnect];
            }
                break;
            case CHIAKI_QUIT_REASON_SESSION_REQUEST_UNKNOWN:
            case CHIAKI_QUIT_REASON_STREAM_CONNECTION_UNKNOWN: {
                NSLog(@"连接异常！主机处于待机状态 或者 无法连接主机");
                result = PSConnectResultTypeFailed_STANDBY;
                if (self.connectResultCallback) {
                    self.connectResultCallback(result);
                }
                [self clearDataFromConnect];
            }
                break;
            case CHIAKI_QUIT_REASON_STREAM_CONNECTION_REMOTE_SHUTDOWN: {
                NSLog(@"主机正在关机...");
                result = PSConnectResultTypeFailed_SHUTDOWN;
                if (self.connectResultCallback) {
                    self.connectResultCallback(result);
                }
                [self clearDataFromConnect];
            }
                break;
            default:
                break;
        }
    }
}

// 音频回调

void audioSettingsCallback(uint32_t channels, uint32_t rate, void *user) {
    NSLog(@"音频数据 - 声道数量：%u，采样率：%u", channels, rate);
}

void audioFrameCallback(int16_t *buf, size_t samples_count, void *user) {
    std::lock_guard<std::mutex> lock(buffer_mutex);
    audio_buffer.insert(audio_buffer.end(), buf, buf + samples_count * CHANNELS);
}

- (void)initAudioPlayer {
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_AUDIO) < 0) {
        NSLog(@"SDL_Init failed: %s", SDL_GetError());
        return;
    }
    
    SDL_AudioSpec spec;
    spec.freq = SAMPLE_RATE;
    spec.format = SAMPLE_FORMAT;
    spec.channels = CHANNELS;
    spec.samples = 1024;
    spec.callback = sdl_audio_callback;
    
    if (SDL_OpenAudio(&spec, NULL) < 0) {
        NSLog(@"SDL_OpenAudio failed: %s", SDL_GetError());
        return;
    }
    
    SDL_PauseAudio(0);  // 启动播放
}

- (void)deinitAudioPlayer {
//    if (SDL_WasInit(SDL_INIT_AUDIO)) {
        SDL_CloseAudio();
//    }

//    if (SDL_WasInit(0)) {
        SDL_Quit();
//    }
}

// 音频缓冲区
std::vector<int16_t> audio_buffer;
std::mutex buffer_mutex;

// 音频回调函数
void sdl_audio_callback(void *userdata, Uint8 *stream, int len) {
    std::lock_guard<std::mutex> lock(buffer_mutex);
    
    if (audio_buffer.empty()) {
        SDL_memset(stream, 0, len);
        return;
    }
    
    int copy_size = len / 2;  // 转换为 16-bit 采样点数
    int available_size = audio_buffer.size();
    
    if (copy_size > available_size) {
        copy_size = available_size;
    }
    
    SDL_memcpy(stream, audio_buffer.data(), copy_size * 2);
    audio_buffer.erase(audio_buffer.begin(), audio_buffer.begin() + copy_size);
}

- (void)mute {
    SDL_PauseAudio(1);  // 暂停音频播放（静音）
}

- (void)unmute {
    SDL_PauseAudio(0);  // 暂停音频播放（静音）
}

// 体感回调

void chiakiHapticsCallback(uint8_t *buf, size_t buf_size, void *user) {
    [kPSStreamingSDK callbackHapticsData:buf bufSize:buf_size];
}

- (void)callbackHapticsData:(uint8_t *)buf bufSize:(size_t)bufSize {
    if (self.hapticsCallback) {
        if (bufSize < 2 * sizeof(int16_t)) return;
        
        int16_t amplitudeL = 0, amplitudeR = 0;
        uint32_t sumL = 0, sumR = 0;
        size_t sampleSize = 2 * sizeof(int16_t);
        size_t bufCount = bufSize / sampleSize;
        
        for (size_t i = 0; i < bufCount; i++) {
            size_t cur = i * sampleSize;
            memcpy(&amplitudeL, buf + cur, sizeof(int16_t));
            memcpy(&amplitudeR, buf + cur + sizeof(int16_t), sizeof(int16_t));
            sumL += abs(amplitudeL) * 2;
            sumR += abs(amplitudeR) * 2;
        }
        
        uint32_t tempLeft = sumL / bufCount;
        uint32_t tempRight = sumR / bufCount;
        uint16_t strength = (tempLeft > tempRight) ? tempLeft : tempRight;
        
        // **归一化到 0.0 - 1.0**
        float normalizedStrength = fminf((float)strength / UINT16_MAX, 1.0);
        
        // 由于算出来的强度很低，暂定*10倍，待后面优化
        normalizedStrength = normalizedStrength * 10;
        if (normalizedStrength >= 1.0) {
            normalizedStrength = 1.0;
        }
        //        NSLog(@"振动强度：%f", normalizedStrength);
        
        self.hapticsCallback(normalizedStrength);
    }
}

// 视频回调

// 视频数据回调
bool videoSampleCallback(uint8_t *buf, size_t buf_size, int32_t frames_lost, bool frame_recovered, void *user) {
    return chiaki_ffmpeg_decoder_video_sample_cb(buf, buf_size, frames_lost, frame_recovered, user);// 解码
}

// 解码视频后的回调
void videoFrameCallback(ChiakiFfmpegDecoder *decoder, void *user) {
    AVFrame *frame = av_frame_alloc();
    //    NSLog(@"解码后的宽高：%@*%@", @(decoder->codec_context->width), @(decoder->codec_context->height));
    int ret = avcodec_receive_frame(decoder->codec_context, frame);
    if (ret != 0) {
        //        NSLog(@"解码失败！");
        av_frame_free(&frame);
        return;
    }
    
    [kPSStreamingSDK convertAVFrame:frame];
    av_frame_free(&frame);
}

- (void)convertAVFrame:(AVFrame*)frame {
    CMSampleBufferRef sampleBuffer = [VideoTool.sharedInstance getRenderDataWithFrame:frame];
    
    if (!sampleBuffer) {
        NSLog(@"创建 sampleBuffer 失败");
        return;
    }
    
    if (self.videoCallback) {
        self.videoCallback(sampleBuffer);
    }
    else {
        NSLog(@"没有设置视频回调");
        CFRelease(sampleBuffer);
    }
}

#pragma mark - 断开

BOOL isDisconnecting = NO;
- (void)disconnectHost:(PSDisconnectCallback)callback {
    if (!session_started
        || isDisconnecting) {
        NSLog(@"未建立连接或者正在断开，无需断开");
        if (callback) {
            callback(YES);
        }
        return;
    }
    
    isDisconnecting = YES;
    
    // 确保 session 中的线程完全停止
    NSLog(@"等待 session 线程结束");
    // 设置停止标志
    session.should_stop = true;
    // 调用 chiaki_session_stop 来停止 session
    ChiakiErrorCode stopResult = chiaki_session_stop(&session);
    if (stopResult != CHIAKI_ERR_SUCCESS) {
        NSLog(@"停止 session 时发生错误: %d", stopResult);
        
        if (callback) {
            callback(NO);
        }
        return;
    }
    // 确保线程已完全结束
    chiaki_session_join(&session); // 等待线程退出
    NSLog(@"session 线程已结束");
    
    //    chiaki_takion_close(&session.stream_connection.takion);
    chiaki_session_fini(&session);// 需先chiaki_session_join()，否则崩溃
    chiaki_opus_decoder_fini(&opus_decoder);
    
    if (ffmpegDecoder) {
        chiaki_ffmpeg_decoder_fini(ffmpegDecoder);
        delete ffmpegDecoder;
        ffmpegDecoder = nullptr;
    }
    session_started = false;
    isDisconnecting = NO;
    
    [self deinitAudioPlayer];
    [VideoTool.sharedInstance clear];
    
    [self clearDataFromConnect];
    
    if (callback) {
        callback(YES);
    }
}

- (void)clearDataFromConnect {
    self.videoCallback = nil;
    self.audioCallback = nil;
    self.hapticsCallback = nil;
    self.connectResultCallback = nil;
}

- (NSInteger)defaultBitrateWithResolution:(PSResolutionType)resolution {
    if (resolution == 0) {
        NSLog(@"获取默认码率失败！传入分辨率为0");
        return 0;
    }
    
    ChiakiConnectVideoProfile profile;
    ChiakiVideoResolutionPreset resolutionPreset = (ChiakiVideoResolutionPreset)resolution;
    chiaki_connect_video_profile_preset(&profile, resolutionPreset, CHIAKI_VIDEO_FPS_PRESET_30);
    return profile.bitrate;
}

- (void)setABXYLayoutExchanged:(BOOL)exchanged {
    self.isExchangedABXYLayout = exchanged;
}

#pragma mark - 扫描

#define PING_MS      500
#define HOSTS_MAX    16
#define DROP_PINGS   3

ChiakiDiscoveryService discoveryDervice;
BOOL isStartingScanning = NO;
- (void)scanLocalPSHostCallback:(PSScanHostResultCallback)callback {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([self isDiscoveryThreadRunning]
            || isStartingScanning) {
            NSLog(@"开启扫描服务失败！原因：扫描线程正在运行... 或 正在开启扫描服务...");
            return;
        }
        
        ChiakiDiscoveryServiceOptions options = {};
        options.ping_ms = PING_MS;
        options.hosts_max = HOSTS_MAX;
        options.host_drop_pings = DROP_PINGS;
        options.cb = chiakiDiscoveryServiceCb;
        struct sockaddr_in in_addr = {};
        in_addr.sin_family = AF_INET;
        //        in_addr.sin_addr.s_addr = 0xffffffff;  //255.255.255.255，这个IP无法广播
        NSString *localIP = [IPAddress getWiFiIPAddress];
        if (![IPAddress checkIfConnectedWiFiWithIP:localIP]) {
            if (self.scanCallback) {
                self.scanCallback(PSScanResultTypeFailed_NOT_CONNECTED_TO_WIFI, @[]);
            }
            NSLog(@"开启扫描服务失败！原因：未连接WiFi");
            return;
        }
        
        // 192.168.31.x -> 192.168.31.255，通过255这个IP进行广播
        NSMutableString *mutableIpString = [localIP mutableCopy];
        NSRange lastDotRange = [mutableIpString rangeOfString:@"." options:NSBackwardsSearch];
        if (lastDotRange.location != NSNotFound) {
            [mutableIpString replaceCharactersInRange:NSMakeRange(lastDotRange.location + 1, mutableIpString.length - (lastDotRange.location + 1))
                                           withString:@"255"];
        }
        
        const char *modifiedIp = [mutableIpString UTF8String];
        if (inet_pton(AF_INET, modifiedIp, &in_addr.sin_addr) != 1) {
            if (self.scanCallback) {
                self.scanCallback(PSScanResultTypeFailed_NOT_CONNECTED_TO_WIFI, @[]);
            }
            NSLog(@"开启扫描服务失败！原因：IP地址（%@）有问题", mutableIpString);
            return;
        }
        
        isStartingScanning = YES;
        self.scanCallback = callback;// 一切正常后，再保存回调
        
        struct sockaddr_storage addr;
        memcpy(&addr, &in_addr, sizeof(in_addr));
        options.send_addr = &addr;
        options.send_addr_size = sizeof(struct sockaddr_in);
        options.send_host = nullptr;
        options.broadcast_addrs = nullptr;
        options.broadcast_num = 0;
        
        NSLog(@"正在开启扫描服务...");
        ChiakiErrorCode error = chiaki_discovery_service_init(&discoveryDervice, &options, NULL);
        if (error != CHIAKI_ERR_SUCCESS) {
            NSLog(@"chiaki_discovery_service_init 失败！");
        }
        isStartingScanning = NO;
    });
}

BOOL isStoppingScanning = NO;
- (void)stopScanningPSHost {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([self isDiscoveryThreadRunning] == NO
            || isStoppingScanning) {
            NSLog(@"停止扫描失败！原因：扫描线程未在运行 或 正在停止扫描...");
            return;
        }
        
        NSLog(@"正在停止扫描...");
        isStoppingScanning = YES;
        chiaki_discovery_service_fini(&discoveryDervice);
        memset(&discoveryDervice, 0, sizeof(discoveryDervice));
        self.scanCallback = nil;
        isStoppingScanning = NO;
        NSLog(@"已停止扫描...");
    });
}

- (BOOL)isDiscoveryThreadRunning {
    int ret = pthread_kill(discoveryDervice.thread.thread, 0);
    if (ret == 0) {
        NSLog(@"扫描线程正在运行...");
    }
    else {
        NSLog(@"扫描线程未在运行");
    }
    return (ret == 0); // 线程还活着
}

void chiakiDiscoveryServiceCb(ChiakiDiscoveryHost *hosts, size_t hosts_count, void *user) {
    // 用来保存所有主机信息的数组
    NSMutableArray *hostsInfoArray = [NSMutableArray array];
    
    // 遍历所有发现的主机
    for (size_t i = 0; i < hosts_count; i++) {
        ChiakiDiscoveryHost *host = &hosts[i];
        const char *ip = host->host_addr;// IP地址：192.168.31.211
        const char *type = host->host_type;// 主机类型：PS5
        const char *protocol = host->device_discovery_protocol_version;// 协议：00030010
        const char *name = host->host_name;// 主机名称
        const char *hostID = host->host_id;// 主机ID
        uint16_t port = host->host_request_port;// 端口
        ChiakiDiscoveryHostState state = host->state;// 主机状态
        const char *sys_version = host->system_version;// 系统版本
        
        NSMutableDictionary *aHostInfo = @{}.mutableCopy;
        if (ip) {
            [aHostInfo setObject:[NSString stringWithUTF8String:ip] forKey:PSFoundHostKey_ip];
        }
        if (type) {
            [aHostInfo setObject:[NSString stringWithUTF8String:type] forKey:PSFoundHostKey_target];
        }
        if (protocol) {
            [aHostInfo setObject:[NSString stringWithUTF8String:protocol] forKey:PSFoundHostKey_protocol];
        }
        if (name) {
            [aHostInfo setObject:[NSString stringWithUTF8String:name] forKey:PSFoundHostKey_server_nickname];
        }
        if (hostID) {
            [aHostInfo setObject:[NSString stringWithUTF8String:hostID] forKey:PSFoundHostKey_hostID];
        }
        if (sys_version) {
            [aHostInfo setObject:[NSString stringWithUTF8String:sys_version] forKey:PSFoundHostKey_sys_version];
        }
        [aHostInfo setObject:@(port) forKey:PSFoundHostKey_port];
        [aHostInfo setObject:@(state) forKey:PSFoundHostKey_state];  // 可以映射为字符串来表示状态值
        
        //        // 打印各个字段的信息
        //        NSLog(@"发现主机：");
        //        if (host->host_addr) {
        //            NSLog(@"IP 地址: %s", host->host_addr);
        //        }
        //        if (host->host_type) {
        //            NSLog(@"主机类型: %s", host->host_type);
        //        }
        //        if (host->device_discovery_protocol_version) {
        //            NSLog(@"协议版本: %s", host->device_discovery_protocol_version);
        //        }
        //        if (host->host_name) {
        //            NSLog(@"主机名称: %s", host->host_name);
        //        }
        //        if (host->host_id) {
        //            NSLog(@"主机ID: %s", host->host_id);
        //        }
        //        if (host->system_version) {
        //            NSLog(@"系统版本: %s", host->system_version);
        //        }
        //        NSLog(@"端口: %u", host->host_request_port);
        //        NSLog(@"主机状态: %d", host->state);
        
        // 将这个字典添加到 hostsInfoArray 中
        [hostsInfoArray addObject:aHostInfo];
    }
    
    if (kPSStreamingSDK.scanCallback) {
        kPSStreamingSDK.scanCallback(PSScanResultTypeSuccess, hostsInfoArray.copy);
    }
}

- (PSErrorType)wakeupHostWithPSType:(PSHostType)type
                          ipAddress:(NSString *)ip
                        rpRegistKey:(NSString *)rpRegistKey {// rpRegistKey是编码后数据，需解码
    
    if (!ip
        || [ip isEqualToString:@""]) {
        NSLog(@"唤醒主机失败！原因：IP地址为空");
        return PSErrorType_INVALID_DATA;
    }
    
    if (!rpRegistKey
        || [rpRegistKey isEqualToString:@""]) {
        NSLog(@"唤醒主机失败！原因：rpRegistKey为空");
        return PSErrorType_INVALID_DATA;
    }
    
    const char *encoded_rp_regist_key = rpRegistKey.UTF8String;
    size_t decoded_size = CHIAKI_SESSION_AUTH_SIZE;
    uint8_t decoded_output[decoded_size];
    chiaki_base64_decode(encoded_rp_regist_key, strlen(encoded_rp_regist_key), decoded_output, &decoded_size);// 解码
    
    unsigned long long userCredential = strtoull((const char *)decoded_output, NULL, 16); // "a85a9089" -> 2824507529
    ChiakiErrorCode error = chiaki_discovery_wakeup(NULL, NULL, ip.UTF8String, userCredential, type == PSHostTypePS5_1);
    if (error != CHIAKI_ERR_SUCCESS) {
        NSLog(@"chiaki_discovery_wakeup 失败！");
    }
    return (PSErrorType)error;
}

#pragma mark - 手柄操控

// 按键
- (void)updateButton:(PSControllerButton)button pressed:(BOOL)pressed {
    if (self.isExchangedABXYLayout) {
        switch (button) {
            case PSControllerButton_A:
                button = PSControllerButton_B;
                break;
            case PSControllerButton_B:
                button = PSControllerButton_A;
                break;
            case PSControllerButton_X:
                button = PSControllerButton_Y;
                break;
            case PSControllerButton_Y:
                button = PSControllerButton_X;
                break;
            default:
                break;
        }
    }
    
    [self clickControllerKey:(ChiakiControllerButton)button pressed:pressed];// PSControllerButton值和ChiakiControllerButton值必须一样
}

- (void)clickControllerKey:(ChiakiControllerButton)button pressed:(BOOL)pressed {
    if (pressed) {
        _controllerState.buttons |= button; // 按下按键
    } else {
        _controllerState.buttons &= ~button; // 释放按键
    }
    
    chiaki_session_set_controller_state(&session, &_controllerState); // 发送状态
}

- (void)updateL2:(CGFloat)value {
    _controllerState.l2_state = (uint8_t)(value * 255);
    chiaki_session_set_controller_state(&session, &_controllerState);
}

- (void)updateR2:(CGFloat)value {
    _controllerState.r2_state = (uint8_t)(value * 255);
    chiaki_session_set_controller_state(&session, &_controllerState);
}

// 摇杆

- (void)updateLeftJoystickX:(CGFloat)x Y:(CGFloat)y {
    _controllerState.left_x = (int16_t)(x * 32767); // 转换到手柄坐标
    _controllerState.left_y = (int16_t)(-y * 32767); // y轴方向可能要反转
    chiaki_session_set_controller_state(&session, &_controllerState);
}

- (void)updateRightJoystickX:(CGFloat)x Y:(CGFloat)y {
    _controllerState.right_x = (int16_t)(x * 32767);
    _controllerState.right_y = (int16_t)(-y * 32767);
    chiaki_session_set_controller_state(&session, &_controllerState);
}

// 触摸板

- (NSInteger)touchpadStartTouchWithPoint:(CGPoint)point {
    point = [self correctTouchPoint:point];
    NSInteger touchID = chiaki_controller_state_start_touch(&_controllerState, point.x, point.y);
    if (touchID < 0) {
        NSLog(@"创建触摸点失败！");
    }
    else {
        chiaki_session_set_controller_state(&session, &_controllerState);
    }
    
    return touchID;
}

- (void)touchpadUpdateTouch:(NSInteger)touchID withPoint:(CGPoint)point {
    if (touchID < 0) {
        NSLog(@"更新触摸点失败！触摸点ID必须大于0");
        return;
    }
    
    point = [self correctTouchPoint:point];
    chiaki_controller_state_set_touch_pos(&_controllerState, touchID, point.x, point.y);
    chiaki_session_set_controller_state(&session, &_controllerState);
}

- (void)touchpadStopTouch:(NSInteger)touchID {
    if (touchID < 0) {
        NSLog(@"停止触摸失败！触摸点ID必须大于0");
        return;
    }
    
    chiaki_controller_state_stop_touch(&_controllerState, touchID);
    chiaki_session_set_controller_state(&session, &_controllerState);
}

- (CGPoint)correctTouchPoint:(CGPoint)point {
    if (point.x < 0) {
        point.x = 0;
        NSLog(@"触摸点的x值小于0！已改为0");
    }
    if (point.x > PSControllerTouchpadWidth) {
        point.x = PSControllerTouchpadWidth;
        NSLog(@"触摸点的x值大于%@！已改为%@", @(PSControllerTouchpadWidth), @(PSControllerTouchpadWidth));
    }
    if (point.y < 0) {
        point.y = 0;
        NSLog(@"触摸点的y值小于0！已改为0");
    }
    if (point.y > PSControllerTouchpadHeight) {
        point.y = PSControllerTouchpadHeight;
        NSLog(@"触摸点的y值大于%@！已改为%@", @(PSControllerTouchpadHeight), @(PSControllerTouchpadHeight));
    }
    return point;
}

// 陀螺仪

- (void)updateGyroWithX:(CGFloat)gyroX
                      y:(CGFloat)gyroY
                      z:(CGFloat)gyroZ
                 accelX:(CGFloat)accelX
                 accelY:(CGFloat)accelY
                 accelZ:(CGFloat)accelZ
                orientX:(CGFloat)orientX
                orientY:(CGFloat)orientY
                orientZ:(CGFloat)orientZ
                orientW:(CGFloat)orientW {
    _controllerState.gyro_x = gyroX;
    _controllerState.gyro_y = gyroY;
    _controllerState.gyro_z = gyroZ;
    
    _controllerState.accel_x = accelX;
    _controllerState.accel_y = accelY;
    _controllerState.accel_z = accelZ;
    
    _controllerState.orient_x = orientX;
    _controllerState.orient_y = orientY;
    _controllerState.orient_z = orientZ;
    _controllerState.orient_w = orientW;
    
    chiaki_session_set_controller_state(&session, &_controllerState);
}

@end
