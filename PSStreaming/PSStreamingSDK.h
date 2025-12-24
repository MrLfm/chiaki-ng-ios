//
//  PSStreamingSDK.h
//  PSStreaming
//
//  Created by FM on 2025/3/13.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <PSStreaming/PSCommon.h>

NS_ASSUME_NONNULL_BEGIN

// 扫描结果回调
typedef void (^PSScanHostResultCallback)(PSScanResultType result, NSArray *foundHosts);
// 注册结果回调
typedef void(^PSRegistCallback)(PSRegistResultType result, NSDictionary *hostInfo);
// 连接结果回调
typedef void (^PSConnectResultCallback)(PSConnectResultType result);
// 断开连接回调
typedef void (^PSDisconnectCallback)(BOOL result);
// 视频回调
typedef void (^PSVideoCallback)(CMSampleBufferRef videoBufferRef);
// 音频回调
typedef void (^PSAudioCallback)(NSData *audioData);
// 体感（振动）回调
typedef void (^PSHapticsCallback)(CGFloat strength);
// 主机状态回调
typedef void (^PSStateCallback)(PSHostStateType state);

/// PS串流SDK
@interface PSStreamingSDK : NSObject

/// 实例
+ (instancetype)sharedInstance;

/// SDK的版本号
- (NSString *)version;

/**
 输出日志，默认关闭
 enabled：YES开启，NO关闭
 */
- (void)enbaleDebugLog:(BOOL)enabled;

/**
 扫描局域网内的主机
 callback：扫描回调
 return：扫描服务的开启结果
 */
- (void)scanLocalPSHostCallback:(PSScanHostResultCallback)callback;

/**
 停止扫描主机
 return：停止扫描的结果
 */
- (void)stopScanningPSHost;

/**
 注册主机
 
 type：主机类型
 ip：主机的ip地址
 accountID：账号id
 pin：配对码（8位）
 callback：注册回调
 */
- (void)registHostWithPSType:(PSHostType)type
                   ipAddress:(NSString *)ip
                   accountID:(NSString *)accountID
                     pinCode:(NSInteger)pin
                    callback:(PSRegistCallback)callback;

/**
 连接主机
 
 type：主机类型
 ip：主机的ip地址
 rpKey：注册主机后返回的数据
 rpRegistKey：注册主机后返回的数据
 resolution：视频的分辨率
 bitrate：码率，传入0使用默认码率，或者传入2000-15000
 fps：视频的帧率
 encode：视频的编码方式
 resultCallback：连接结果回调
 videoCallback：视频数据回调
 audioCallback：音频数据回调
 hapticsCallback：体感（振动）回调
 */
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
              hapticsCallback:(PSHapticsCallback _Nullable)hapticsCallback;

/**
 断开主机的连接
 callback：结果回调
 */
- (void)disconnectHost:(PSDisconnectCallback)callback;

#pragma mark - 参数和设置

/**
 获取分辨率的默认码率
 resolution：分辨率
 return：默认码率，范围：2000-15000
 */
- (NSInteger)defaultBitrateWithResolution:(PSResolutionType)resolution;

/**
 设置ABXY按键布局
 exchanged：切换。切换后：A->B，B->A，X->Y，Y->X
 */
- (void)setABXYLayoutExchanged:(BOOL)exchanged;

/// 静音
- (void)mute;

/// 取消静音
- (void)unmute;

/**
 获取主机类型
 name：主机名称
 return：主机类型
 */
- (PSHostType)getPSHostTypeWithName:(NSString *)name;

/**
 获取主机名称
 type：主机类型
 return：主机名称
 */
- (NSString *)getPSHostNameWithType:(PSHostType)type;

/**
 唤醒主机
 type：主机类型
 ip：主机的ip地址
 rpRegistKey：注册主机后返回的数据
 return: 唤醒结果
 */
- (PSErrorType)wakeupHostWithPSType:(PSHostType)type
                          ipAddress:(NSString *)ip
                        rpRegistKey:(NSString *)rpRegistKey;


#pragma mark - 手柄操控

/**
 更新按键
 button：按键类型
 pressed：按下状态。YES：按下，NO：松开
 */
- (void)updateButton:(PSControllerButton)button pressed:(BOOL)pressed;

/**
 更新L2键
 value：按压值。取值范围：0.0~1.0
 */
- (void)updateL2:(CGFloat)value;

/**
 更新R2键
 value：按压值。取值范围：0.0~1.0
 */
- (void)updateR2:(CGFloat)value;

/**
 更新左摇杆数据
 x：X轴。取值范围：-1.0~1.0
 y：Y轴。取值范围：-1.0~1.0
 */
- (void)updateLeftJoystickX:(CGFloat)x Y:(CGFloat)y;

/**
 更新右摇杆数据
 x：X轴。取值范围：-1.0~1.0
 y：Y轴。取值范围：-1.0~1.0
 */
- (void)updateRightJoystickX:(CGFloat)x Y:(CGFloat)y;

/**
 （触摸板）开始触摸
 point：触摸点位置，x的取值范围：0~1920，y的取值范围：0~940
 return：触摸ID。如果返回-1，表示创建触摸点失败，因为最多同时创建2个触摸点。
 */
- (NSInteger)touchpadStartTouchWithPoint:(CGPoint)point;

/**
 （触摸板）更新触摸点
 touchID：触摸ID
 point：触摸点位置，x的取值范围：0~1920，y的取值范围：0~940
 */
- (void)touchpadUpdateTouch:(NSInteger)touchID withPoint:(CGPoint)point;

/**
 （触摸板）停止触摸
 touchID：触摸ID
 */
- (void)touchpadStopTouch:(NSInteger)touchID;

/**
 更新陀螺仪数据
 */
- (void)updateGyroWithX:(CGFloat)gyroX
                      y:(CGFloat)gyroY
                      z:(CGFloat)gyroZ
                 accelX:(CGFloat)accelX
                 accelY:(CGFloat)accelY
                 accelZ:(CGFloat)accelZ
                orientX:(CGFloat)orientX
                orientY:(CGFloat)orientY
                orientZ:(CGFloat)orientZ
                orientW:(CGFloat)orientW;

@end

NS_ASSUME_NONNULL_END
