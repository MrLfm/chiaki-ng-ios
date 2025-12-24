//
//  PSCommon.h
//  PSStreaming
//
//  Created by FM on 2025/3/17.
//

#ifndef PSCommon_h
#define PSCommon_h

// PS手柄触摸板的宽高
extern NSInteger const PSControllerTouchpadWidth;
extern NSInteger const PSControllerTouchpadHeight;

// 已注册主机的字段
extern NSString * const PSRegistedHostKey_ip;               // 主机IP地址
extern NSString * const PSRegistedHostKey_target;           // 主机类型
extern NSString * const PSRegistedHostKey_ap_ssid;
extern NSString * const PSRegistedHostKey_ap_bssid;
extern NSString * const PSRegistedHostKey_ap_key;
extern NSString * const PSRegistedHostKey_ap_name;
extern NSString * const PSRegistedHostKey_server_nickname;
extern NSString * const PSRegistedHostKey_rp_key_type;
extern NSString * const PSRegistedHostKey_server_mac;       // MAC地址
extern NSString * const PSRegistedHostKey_rp_key;
extern NSString * const PSRegistedHostKey_rp_regist_key;    // 注册码
extern NSString * const PSRegistedHostKey_console_pin;      // PIN码

// 已扫描到的主机的字段
extern NSString * const PSFoundHostKey_ip;              // 主机IP地址
extern NSString * const PSFoundHostKey_target;          // 主机类型
extern NSString * const PSFoundHostKey_server_nickname; // 服务昵称
extern NSString * const PSFoundHostKey_state;           // 状态
extern NSString * const PSFoundHostKey_protocol;        // 协议
extern NSString * const PSFoundHostKey_hostID;          // 主机ID
extern NSString * const PSFoundHostKey_port;            // 端口
extern NSString * const PSFoundHostKey_sys_version;     // 系统版本

typedef enum
{
    PSErrorType_SUCCESS = 0,
    PSErrorType_UNKNOWN,
    PSErrorType_PARSE_ADDR,
    PSErrorType_THREAD,
    PSErrorType_MEMORY,
    PSErrorType_OVERFLOW,
    PSErrorType_NETWORK,
    PSErrorType_CONNECTION_REFUSED,
    PSErrorType_HOST_DOWN,
    PSErrorType_HOST_UNREACH,
    PSErrorType_DISCONNECTED,
    PSErrorType_INVALID_DATA,
    PSErrorType_BUF_TOO_SMALL,
    PSErrorType_MUTEX_LOCKED,
    PSErrorType_CANCELED,
    PSErrorType_TIMEOUT,
    PSErrorType_INVALID_RESPONSE,
    PSErrorType_INVALID_MAC,
    PSErrorType_UNINITIALIZED,
    PSErrorType_FEC_FAILED,
    PSErrorType_VERSION_MISMATCH,
    PSErrorType_HTTP_NONOK
} PSErrorType;

typedef enum : NSUInteger {
    PSScanResultTypeFailed_UNKNOW,                  // 未知
    PSScanResultTypeFailed_NOT_CONNECTED_TO_WIFI,   // 未连接Wi-Fi
    PSScanResultTypeSuccess                         // 扫描成功
} PSScanResultType;// 扫描结果

typedef enum : NSUInteger {
    PSControllerButton_A            = (1 << 0),
    PSControllerButton_B            = (1 << 1),
    PSControllerButton_X            = (1 << 2),
    PSControllerButton_Y            = (1 << 3),
    PSControllerButton_DPAD_LEFT    = (1 << 4),
    PSControllerButton_DPAD_RIGHT   = (1 << 5),
    PSControllerButton_DPAD_UP      = (1 << 6),
    PSControllerButton_DPAD_DOWN    = (1 << 7),
    PSControllerButton_L1           = (1 << 8),
    PSControllerButton_R1           = (1 << 9),
    PSControllerButton_L3           = (1 << 10),
    PSControllerButton_R3           = (1 << 11),
    PSControllerButton_START        = (1 << 12),
    PSControllerButton_SELECT       = (1 << 13),
    PSControllerButton_TOUCHPAD     = (1 << 14),//  触摸板
    PSControllerButton_HOME         = (1 << 15)
} PSControllerButton;// 手柄按键

typedef enum : NSUInteger {
    PSHostTypePS4_UNKNOWN =       0,    // 未知
    PSHostTypePS4_8 =           800,    // 版本号是8的PS4主机
    PSHostTypePS4_9 =           900,    // 版本号是9的PS4主机
    PSHostTypePS4_10 =         1000,    // 版本号是10的PS4主机
    PSHostTypePS5_UNKNOWN = 1000000,    // 版本号不明的PS5主机
    PSHostTypePS5_1 =       1000100     // PS5主机
} PSHostType;// 主机类型

typedef enum : NSUInteger {
    PSRegistResultTypeCanceled,
    PSRegistResultTypeFailed,
    PSRegistResultTypeSuccess
} PSRegistResultType;// 注册结果

typedef enum : NSUInteger {
    PSConnectResultTypeFailed_UNNKOWN,  // 未知
    PSConnectResultTypeFailed_STANDBY,  // 主机处于待机状态 或者 无法连接主机
    PSConnectResultTypeFailed_IN_USE,   // 主机已被连接
    PSConnectResultTypeFailed_SHUTDOWN, // 主机正在关机
    PSConnectResultTypeSuccess          // 连接成功
} PSConnectResultType;// 连接结果

typedef enum : NSUInteger {
    PSHostStateType_UNKNOWN,// 未知
    PSHostStateType_READY,  // 可连接
    PSHostStateType_STANDBY,// 待机
} PSHostStateType;// 主机状态

typedef enum : NSUInteger {
    PSResolutionType360P = 1,
    PSResolutionType540P = 2,
    PSResolutionType720P = 3,
    PSResolutionType1080P = 4
} PSResolutionType;// 视频分辨率

typedef enum : NSUInteger {
    PSFpsType30 = 30,
    PSFpsType60 = 60,
} PSFpsType;// 视频帧率

typedef enum : NSUInteger {
    PSEncodeTypeH264,
    PSEncodeTypeH265,// 仅PS5支持
    PSEncodeTypeH265_HDR,// 仅PS5支持
} PSEncodeType;// 视频数据的编码方式

#endif /* PSCommon_h */
