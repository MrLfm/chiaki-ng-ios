//
//  ViewController.m
//  PSStreamingDemo
//
//  Created by FM on 2025/3/17.
//

#import "ViewController.h"
#import <PSStreaming/PSStreaming.h>
#import "AudioProcessor.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *pinCodeTextField;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *sampleBufferDisplayLayer;
@property (nonatomic, strong) AudioProcessor *audioProcessor;
@end

@implementation ViewController


static ViewController *kViewController = nil;
- (void)viewDidLoad {
    [super viewDidLoad];
    
    kViewController = self;
    [PSStreamingSDK.sharedInstance enbaleDebugLog:YES];// 开启日志
    [self setupVideoLayer];
}

- (IBAction)btnActionRegistPSHost:(id)sender {
    PSHostType type = PSHostTypePS5_1;// 主机类型
    NSString *ip = @"192.168.xx.xx";// PS主机的IP地址
    /**
     PS账号ID的64位编码
     获取方法：运行此脚本，根据提示操作获取 https://github.com/streetpea/chiaki-ng/blob/main/scripts/psn-account-id.py
     注：PS主机也要登录该账号才能完成注册。
     */
    NSString *accountID = @"xxxxxxxxxx=";
    NSInteger pinCode = [self.pinCodeTextField.text integerValue];
    [PSStreamingSDK.sharedInstance registHostWithPSType:type ipAddress:ip accountID:accountID pinCode:pinCode callback:^(PSRegistResultType result, NSDictionary * _Nonnull hostInfo) {
        NSString *resultText = @"注册失败";
        switch (result) {
            case PSRegistResultTypeSuccess:
                resultText = @"注册成功";
                break;
            case PSRegistResultTypeFailed:
                resultText = @"注册失败";
                break;
            case PSRegistResultTypeCanceled:
                resultText = @"注册已取消";
                break;
            default:
                break;
        }
        
        [NSUserDefaults.standardUserDefaults setObject:hostInfo forKey:@"RegisterHostInfo"];
    }];
}

- (IBAction)btnActionConnectPSHost:(id)sender {
    NSDictionary *info =  [NSUserDefaults.standardUserDefaults objectForKey:@"RegisterHostInfo"];
    NSString *target = info[PSRegistedHostKey_target];
    PSHostType type = [PSStreamingSDK.sharedInstance getPSHostTypeWithName:target];
    NSString *rpKeyData = info[PSRegistedHostKey_rp_key];
    NSString *rpRegistKeyData = info[PSRegistedHostKey_rp_regist_key];
    NSString *ip = info[PSRegistedHostKey_ip];
    PSResolutionType resolution = PSResolutionType1080P;
    PSFpsType fps = PSFpsType60;
    PSEncodeType code = PSEncodeTypeH265;
    [PSStreamingSDK.sharedInstance connectHostWithPSType:type ipAddress:ip rpKey:rpKeyData rpRegistKey:rpRegistKeyData resolution:resolution bitrate:0 fps:fps encode:code resultCallback:^(PSConnectResultType result) {
        NSLog(@"连接结果：%@", @(result));
    } videoCallback:^(CMSampleBufferRef  _Nonnull videoBufferRef) {
        [self renderSampleBuffer:videoBufferRef];
    } audioCallback:^(NSData * _Nonnull audioData) {
        NSLog(@"音频数据：%@", audioData);
        [self.audioProcessor receiveAudioData:audioData];
    } hapticsCallback:^(CGFloat strength) {
        NSLog(@"振感强度：%f", strength);
    }];
}

- (IBAction)btnActionScanHost:(id)sender {
    [PSStreamingSDK.sharedInstance scanLocalPSHostCallback:^(PSScanResultType result, NSArray * _Nonnull foundHosts) {
        NSLog(@"扫描结果：%@", @(result));
        NSLog(@"扫描到主机：%@", foundHosts);
    }];
}

- (IBAction)btnActionStopScanning:(id)sender {
    [PSStreamingSDK.sharedInstance stopScanningPSHost];
}

- (IBAction)btnActionWakeupHost:(id)sender {
    NSDictionary *info =  [NSUserDefaults.standardUserDefaults objectForKey:@"RegisterHostInfo"];
    NSString *target = info[PSRegistedHostKey_target];
    PSHostType type = [PSStreamingSDK.sharedInstance getPSHostTypeWithName:target];
    NSString *rpRegistKeyData = info[PSRegistedHostKey_rp_regist_key];
    NSString *ip = info[PSRegistedHostKey_ip];
    [PSStreamingSDK.sharedInstance wakeupHostWithPSType:type ipAddress:ip rpRegistKey:rpRegistKeyData];
}

- (void)setupVideoLayer {
    self.sampleBufferDisplayLayer = [AVSampleBufferDisplayLayer layer];
    CGFloat width = 1280/2.0;
    CGFloat height = 720/2.0;
    self.sampleBufferDisplayLayer.frame = CGRectMake(60, (CGRectGetHeight(self.view.frame)-height)/2.0, width, height);
    [self.view.layer addSublayer:self.sampleBufferDisplayLayer];
}

- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (self.sampleBufferDisplayLayer == nil) {
        [self setupVideoLayer];
    }
    
    if (sampleBuffer) {
        [self.sampleBufferDisplayLayer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    } else {
        NSLog(@"渲染错误，数据为空");
    }
}

- (IBAction)btnActionDisconnect:(id)sender {
    [PSStreamingSDK.sharedInstance disconnectHost:^(BOOL result) {
        if (result) {
            [self.sampleBufferDisplayLayer removeFromSuperlayer];
            self.sampleBufferDisplayLayer = nil;
        }
    }];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

@end
