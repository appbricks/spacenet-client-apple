/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2018-2023 WireGuard LLC. All Rights Reserved.
 */

#ifndef SPACENET_UI_H
#define SPACENET_UI_H

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

// Swift / Golang UX Interop TESTS

extern void *snTESTdialogInput(void *context, getInput_fn_t getInputFn);
extern const char *snTESTHello(const char *name);

#endif
