/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2023 AppBricks, Inc. All Rights Reserved.
 */

 package main

// #include <stdlib.h>
// #include <stdio.h>
// #include <sys/types.h>
//
// static void showDialog(void *func, void* ctx, const unsigned char type, const char *title, const char* msg, const char withTextInput, void* cbContext) {
//   ((void(*)(void *, const unsigned char, const char *, const char *, const char, void *))func)(ctx, type, title, msg, withTextInput, cbContext);
// }
// static void dismissDialog(void *func, void* ctx) {
//   ((void(*)(void *))func)(ctx);
// }
// typedef void (*getInput_result_fn_t)(unsigned long, unsigned char, char *);
// static void getInput(void *func, void *ctx, const unsigned char type, const char *title, const char *msg, unsigned long inputContext, getInput_result_fn_t inputHandler)
// {
//   ((void(*)(void *, const unsigned char, const char *, const char *, unsigned long, getInput_result_fn_t))func)(ctx, type, title, msg, inputContext, inputHandler);
// }
// extern void snHandleDialogResult(unsigned long inputContext, unsigned char ok, char* result);
// static getInput_result_fn_t snHandleDialogResultFn() {
//   return snHandleDialogResult;
// }
import "C"

import (
	"fmt"
	"unsafe"
)

var (
	showDialogFuncs [3]uintptr
)

const (
	SN_CFG_STATUS_ERROR       = 0
	SN_CFG_STATUS_NEEDS_INIT  = 1
	SN_CFG_STATUS_NEEDS_LOGIN = 2
	SN_CFG_STATUS_LOGGED_IN   = 3
	SN_CFG_STATUS_LOGGED_OUT  = 4
	SN_CFG_STATUS_LOCKED      = 5

	SN_DIALOG_APP = 0
	SN_DIALOG_NOTIFY = 1
	SN_DIALOG_ALERT = 2
	SN_DIALOG_ERROR = 3

	C_FALSE = 0
	C_TRUE  = 1
)

type dialogInputHandle struct {
	input chan *string
}

//export snRegisterShowDialogFunc
func snRegisterShowDialogFunc(dlgContext, handler uintptr) {
	showDialogFuncs = [3]uintptr{handler, dlgContext, 0x0}
}

//export snSetDialogDismissHandler
func snSetDialogDismissHandler(dlgContext, cbContext, handler uintptr) {
	if showDialogFuncs[0] != 0 && showDialogFuncs[1] == dlgContext {
		showDialogFuncs[2] = handler
	}	
}

//export snHandleDialogResult
func snHandleDialogResult(inputContext uintptr, ok uint8, result *C.char) {	
	inputHandle := (*dialogInputHandle)(unsafe.Pointer(inputContext))
	if ok != 0 {
		result := C.GoString(result)
		inputHandle.input <- &result
	} else {
		inputHandle.input <- nil
	}
}
func getInput(context, getInputFn uintptr, dialogType int, title, msg string, inputHandle *dialogInputHandle) {
	appCtx       := unsafe.Pointer(context)
	getInputFunc := unsafe.Pointer(getInputFn)
	if uintptr(getInputFunc) != 0 {
		C.getInput(getInputFunc, appCtx, 
			SN_DIALOG_NOTIFY,
			C.CString(title), 
			C.CString(msg),
			C.ulong(uintptr(unsafe.Pointer(inputHandle))),
			C.snHandleDialogResultFn(),
		)
	}
}

//export snUnregisterShowDialogFunc
func snUnregisterShowDialogFunc() {
	showDialogFuncs = [3]uintptr{0x0, 0x0, 0x0}
}

// Begin: Swift / Golang UX Interop TESTS

//export snTESTdialogInput
func snTESTdialogInput(context, getInputFn uintptr) {	

	inputHandle := &dialogInputHandle{
		input: make(chan *string),
	}

	getInput(context, getInputFn,
		SN_DIALOG_NOTIFY,
		`Test Input`, 
		`Please enter some test text input.`,
		inputHandle,
	)

	go func() {
		inputText := <-inputHandle.input
		if inputText != nil {
			fmt.Println("Test Input:", *inputText)
		} else {
			fmt.Println("Input Canceled")
		}	
	}()
}

//export snTESTHello
func snTESTHello(name *C.char) *C.char {
	return C.CString(fmt.Sprintf("(%s) Hello %s", homeDir, C.GoString(name)))
}

// End: Swift / Golang UX Interop TESTS
