// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// 将 ChiakiLaunchSpec 类型的数据格式化为一个 JSON 字符串，并将其存储到 buf 缓冲区中
#ifndef CHIAKI_LAUNCHSPEC_H
#define CHIAKI_LAUNCHSPEC_H

#include <chiaki/common.h>

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct chiaki_launch_spec_t
{
	ChiakiTarget target;
	unsigned int mtu;
	unsigned int rtt;
	uint8_t *handshake_key;
	unsigned int width;
	unsigned int height;
	unsigned int max_fps;
	ChiakiCodec codec;
	unsigned int bw_kbps_sent;
} ChiakiLaunchSpec;

CHIAKI_EXPORT int chiaki_launchspec_format(char *buf, size_t buf_size, ChiakiLaunchSpec *launch_spec);

#ifdef __cplusplus
}
#endif

#endif // CHIAKI_LAUNCHSPEC_H
