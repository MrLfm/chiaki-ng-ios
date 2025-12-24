//
//  IPAddress.m
//  PSStreamingDemo
//
//  Created by FM on 2025/3/27.
//

#import "IPAddress.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
 
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

@implementation IPAddress

#pragma mark - 获取设备当前网络IP地址
+ (NSString *)getWiFiIPAddress {
    /** addresses数据
     {
     // en开头是Wi-Fi接口
     // 连接WiFi时
        "en0/ipv4" = "192.168.31.141";
     // 使用流量时
        "en2/ipv4" = "169.254.69.108";// 169.254开头表明没有连接wifi
     // 可能出现2个接口的情况
        "en0/ipv4" = "192.168.31.141";
        "en2/ipv4" = "169.254.69.108";
     
     // utun开头是vpn接口：
        "utun13/ipv4" = "198.18.0.1";
     // IPsec虚拟私有网络（VPN）接口
         "ipsec2/ipv6" = "2408:8557:c70:1507:cb8:9822:9e77:46a5";
     // 本地链路（Link-local）接口
         "llw0/ipv6" = "fe80::3096:adff:fe11:c2d9";
     // 回环接口（Loopback interface）接口
         "lo0/ipv4" = "127.0.0.1";
     // 移动数据接口
         "pdp_ip0/ipv4" = "10.5.43.7";
     // Apple Wireless Direct Link (AWDL) 接口
         "awdl0/ipv6" = "fe80::3096:adff:fe11:c2d9";
     }
     */
    NSDictionary *addresses = [self getIPAddresses];
    NSLog(@"本地IP列表：%@", addresses);
    
    NSString *address = @"0.0.0.0";
    for (NSString *aKey in addresses.allKeys) {
        if ([aKey hasPrefix:@"en"]
            && [aKey hasSuffix:@"ipv4"]) {// en开头是WiFi接口，取ipv4，根据需要修改
            NSString *value = addresses[aKey];
            if ([self isValidatIP:value]) {
                address = value;
            }
            if (![self checkIfConnectedWiFiWithIP:address]) {// 拿到未连接WiFi的ip，继续往下查找
                continue;
            }
            else {// 拿到已连接WiFi的ip，停止查找
                break;
            }
        }
    }
    
    NSLog(@"本机IP地址：%@", address);
    return address;
}
 
+ (BOOL)isValidatIP:(NSString *)ipAddress {
    if (ipAddress.length == 0) {
        return NO;
    }
    
    NSString *urlRegEx = @"^([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])$";
    
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:urlRegEx options:0 error:&error];
    if (regex != nil) {
        NSTextCheckingResult *firstMatch = [regex firstMatchInString:ipAddress options:0 range:NSMakeRange(0, [ipAddress length])];
        if (firstMatch) {
            return YES;
        }
    }
    
    return NO;
}
 
+ (NSDictionary *)getIPAddresses {
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

+ (BOOL)checkIfConnectedWiFiWithIP:(NSString *)ip {
    /**
     常见局域网的IP段：
     •    10.0.0.0 到 10.255.255.255
     •    172.16.0.0 到 172.31.255.255
     •    192.168.0.0 到 192.168.255.255
     
     未连接网络的IP：
     如果设备没有获取到 DHCP 分配的 IP 地址，它可能会自动分配一个 APIPA 地址，通常以 169.254.x.x 开头，表示设备未能连接到有效的网络。
     */
    if ([ip hasPrefix:@"192.168."]
        || [ip hasPrefix:@"172."]
        || [ip hasPrefix:@"10."]) {
        return YES;
    }
    
    if ([ip hasPrefix:@"169.254"]) {
        return NO;
    }
    
    return YES;// TODO: 完善规则
}

@end
