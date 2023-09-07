/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2023 AppBricks, Inc. All Rights Reserved.
 */

#ifndef SPACENET_API_H
#define SPACENET_API_H

#include <sys/types.h>
#include <stdint.h>
#include <stdbool.h>

#include "./common.h"
#include "./ui.h"

typedef unsigned char SN_CFG_STATUS;
extern const SN_CFG_STATUS SN_CFG_STATUS_ERROR;
extern const SN_CFG_STATUS SN_CFG_STATUS_NEEDS_INIT;
extern const SN_CFG_STATUS SN_CFG_STATUS_NEEDS_LOGIN;
extern const SN_CFG_STATUS SN_CFG_STATUS_LOGGED_IN;
extern const SN_CFG_STATUS SN_CFG_STATUS_LOGGED_OUT;
extern const SN_CFG_STATUS SN_CFG_STATUS_LOCKED;

// Callback function types

typedef void (*post_status_change)(void *context, const SN_CFG_STATUS status);
typedef void (*on_done)(void *context, const BOOL ok);

typedef void (*on_settings_init)(
  void *context, 
  const BOOL ok, 
  const BOOL isInitialized,
  const char *deviceUser, 
  const char *deviceName, 
  const char *deviceLockPassphrase, 
  const int unlockedTimeout);
typedef void (*on_settings_device_owner_logged_in)(
  void *context, 
  const char *username, 
  const char *deviceName, 
  const BOOL needsKey);
typedef void (*on_settings_owner_key_loaded)(
  void *context, 
  const BOOL ok,
  const char *keyFile);


// Application context apis

extern void snRegisterStatusChangeHandler(void *context, post_status_change handler);

extern const BOOL snInitializeContext(const char *passphrase);

extern void snLogin(void *context, on_done handler);
extern const BOOL snLogout();
extern const char *snLoggedInUser();
extern const BOOL snIsLoggedInUserOwner();

extern const BOOL snEULAAccepted();
extern void snSetEULAAccepted();

// AppConfig Settings Initialization and Update

extern void snSettingsInit(void *context, on_settings_init handler);

extern void snSettingsResetDeviceOwner(
  void *context, 
  on_settings_device_owner_logged_in handler);
extern void snSettingsLoadUserKey(
  void *context, 
  const char *keyFile, 
  const BOOL createKey, 
  on_settings_owner_key_loaded handler);
extern void snSettingsSave(
  void *context, 
  const char *deviceName, 
  const char *deviceLockPassphrase, 
  const int unlockedTimeout, 
  on_done handler);

#endif
