// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#ifndef CHIAKI_TIME_H
#define CHIAKI_TIME_H

//#include <chiaki/common.h>// 导致多次导入common.h，因此注释，

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

//CHIAKI_EXPORT uint64_t chiaki_time_now_monotonic_us(void);// 因注释掉#include <chiaki/common.h>，改为下句👇🏻
uint64_t chiaki_time_now_monotonic_us(void);

static inline uint64_t chiaki_time_now_monotonic_ms(void) { return chiaki_time_now_monotonic_us() / 1000; }

#ifdef __cplusplus
}
#endif

#endif // CHIAKI_TIME_H
