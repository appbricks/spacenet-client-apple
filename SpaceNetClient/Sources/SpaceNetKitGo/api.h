/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2023 AppBricks, Inc. All Rights Reserved.
 */

#ifndef SPACENET_API_H
#define SPACENET_API_H

#include <sys/types.h>
#include <stdint.h>
#include <stdbool.h>

#include "./ui.h"

typedef unsigned char SN_CFG_STATUS;
extern const SN_CFG_STATUS SN_CFG_STATUS_ERROR;
extern const SN_CFG_STATUS SN_CFG_STATUS_NEEDS_INIT;
extern const SN_CFG_STATUS SN_CFG_STATUS_NEEDS_LOGIN;
extern const SN_CFG_STATUS SN_CFG_STATUS_LOGGED_IN;
extern const SN_CFG_STATUS SN_CFG_STATUS_LOGGED_OUT;
extern const SN_CFG_STATUS SN_CFG_STATUS_LOCKED;

typedef void (*set_cfg_status)(void *context, const SN_CFG_STATUS status);
extern void snRegisterStatusChangeHandler(void *context, set_cfg_status handler);

extern void snInitializeContext(const char *passphrase);

#endif
