/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2018-2023 WireGuard LLC. All Rights Reserved.
 */

#ifndef SPACENET_H
#define SPACENET_H

#include <sys/types.h>
#include <stdint.h>
#include <stdbool.h>

typedef unsigned char SN_DIALOG_TYPE;
const SN_DIALOG_TYPE SN_DIALOG_APP = 0;
const SN_DIALOG_TYPE SN_DIALOG_NOTIFY = 1;
const SN_DIALOG_TYPE SN_DIALOG_ALERT = 2;
const SN_DIALOG_TYPE SN_DIALOG_ERROR = 3;

typedef void (*showDialog_fn_t)(
  void *dlgContext,
  SN_DIALOG_TYPE type,
  const char *title,
  const char *msg,
  unsigned long inputContext);
typedef void (*dismissDialog_fn_t)(
  void *dlgContext);
extern void snRegisterShowDialogFunc(void *dlgContext, showDialog_fn_t);
extern void snSetDialogDismissHandler(void* dlgContext, dismissDialog_fn_t dismissHandler);
extern void snHandleDialogResult(unsigned long inputContext, unsigned char ok, const char *result);
extern void snUnregisterShowDialogFunc();

typedef void (*getInput_result_fn_t)(
  unsigned long inputContext, 
  unsigned char ok, 
  const char *result);
typedef void (*getInput_fn_t)(
  void *dlgContext, 
  SN_DIALOG_TYPE type,
  const char *title, 
  const char *msg, 
  unsigned long inputContext,
  getInput_result_fn_t inputHandler);

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

// Swift / Golang UX Interop TESTS

extern void *snTESTdialogInput(void *context, getInput_fn_t getInputFn);
extern const char *snTESTHello(const char *name);

#endif
