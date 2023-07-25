/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2018-2023 WireGuard LLC. All Rights Reserved.
 */

#ifndef SPACENET_API_H
#define SPACENET_API_H

#include <sys/types.h>
#include <stdint.h>
#include <stdbool.h>

#include "./ui.h"

typedef unsigned char SN_CFG_STATUS;
const SN_CFG_STATUS SN_CFG_STATUS_ERROR = 0;
const SN_CFG_STATUS SN_CFG_STATUS_NEEDS_INIT = 1;
const SN_CFG_STATUS SN_CFG_STATUS_NEEDS_LOGIN = 2;
const SN_CFG_STATUS SN_CFG_STATUS_LOGGED_IN = 3;
const SN_CFG_STATUS SN_CFG_STATUS_LOGGED_OUT = 4;
const SN_CFG_STATUS SN_CFG_STATUS_LOCKED = 5;

typedef void (*set_cfg_status)(void *context, const SN_CFG_STATUS status);
extern void snRegisterStatusChangeHandler(void *context, set_cfg_status handler);

extern void snInitializeContext(const char *passphrase);

#endif
