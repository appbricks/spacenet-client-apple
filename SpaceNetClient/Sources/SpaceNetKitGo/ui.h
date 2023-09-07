/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2023 AppBricks, Inc. All Rights Reserved.
 */

#ifndef SPACENET_UI_H
#define SPACENET_UI_H

#include <sys/types.h>
#include <stdint.h>
#include <stdbool.h>

#include "./common.h"

typedef unsigned char SN_DIALOG_TYPE;
extern const SN_DIALOG_TYPE SN_DIALOG_APP;
extern const SN_DIALOG_TYPE SN_DIALOG_NOTIFY;
extern const SN_DIALOG_TYPE SN_DIALOG_ALERT;
extern const SN_DIALOG_TYPE SN_DIALOG_ERROR;
extern const SN_DIALOG_TYPE SN_DIALOG_WAIT_MSG;
extern const SN_DIALOG_TYPE SN_DIALOG_WAIT_LOGIN;

typedef unsigned char SN_DIALOG_ACCESSORY_TYPE;
extern const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_NONE;
extern const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_YES_NO;
extern const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_OK_CANCEL;
extern const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_TEXT_INPUT;
extern const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_PASSWORD_INPUT;
extern const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_PASSWORD_INPUT_WITH_VERIFY;
extern const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_FILE_OPEN;
extern const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_SPINNER;
extern const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_PROGRESS_BAR;

typedef void *(*showDialog_fn_t)(
  void *dlgContext,
  SN_DIALOG_TYPE dialogType,
  const char *title,
  const char *msg,
  const unsigned char accessoryType,
  const char *accessoryText,
  const BOOL dispathToMain,
  unsigned long inputContext);
typedef void (*dismissDialog_fn_t)(
  void *dlgContext,
  void *dlgHandle);
extern void snRegisterShowDialogFunc(void *dlgContext, showDialog_fn_t);
extern void snSetDialogDismissHandler(void* dlgContext, dismissDialog_fn_t dismissHandler);
extern void snUnregisterShowDialogFunc(void *dlgContext);
extern void snHandleDialogInput(unsigned long inputContext, BOOL ok, const char *result);
extern void snAssociateDialogInputToHandle(unsigned long inputContext, void *dlgHandle);

typedef void (*getInput_result_fn_t)(
  unsigned long inputContext, 
  BOOL ok, 
  const char *result);
typedef void (*getInput_fn_t)(
  void *dlgContext, 
  SN_DIALOG_TYPE type,
  const char *title, 
  const char *msg, 
  const char *defaultInput,
  unsigned long inputContext,
  getInput_result_fn_t inputHandler);

// Swift / Golang UX Interop TESTS

extern void *snTESTdialogInput(void *context, getInput_fn_t getInputFn);
extern void *snTESTdialogNotifyAndInput(void *context);
extern const char *snTESTHello(const char *name);

#endif
