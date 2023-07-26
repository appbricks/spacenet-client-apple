/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2023 AppBricks, Inc. All Rights Reserved.
 */

package main

// #include <stdlib.h>
// #include <stdio.h>
// #include <sys/types.h>
//
// typedef unsigned char SN_DIALOG_TYPE;
// const SN_DIALOG_TYPE SN_DIALOG_APP = 0;
// const SN_DIALOG_TYPE SN_DIALOG_NOTIFY = 1;
// const SN_DIALOG_TYPE SN_DIALOG_ALERT = 2;
// const SN_DIALOG_TYPE SN_DIALOG_ERROR = 3;
// const SN_DIALOG_TYPE SN_DIALOG_WAIT_MSG = 10;
// const SN_DIALOG_TYPE SN_DIALOG_WAIT_LOGIN = 11;
//
// static void *showDialog(void *func, void *ctx, const unsigned char dialogType, const char *title, const char *msg, const unsigned char withTextInput, unsigned long inputContext) {
//   return ((void *(*)(void *, const unsigned char, const char *, const char *, const unsigned char, unsigned long))func)(ctx, dialogType, title, msg, withTextInput, inputContext);
// }
// static void dismissDialog(void *func, void *ctx, void* handle) {
//   ((void(*)(void *, void *))func)(ctx, handle);
// }
// typedef void (*getInput_result_fn_t)(unsigned long, unsigned char, char *);
// static void getInput(void *func, void *ctx, const unsigned char dialogType, const char *title, const char *msg, unsigned long inputContext, getInput_result_fn_t inputHandler)
// {
//   ((void(*)(void *, const unsigned char, const char *, const char *, unsigned long, getInput_result_fn_t))func)(ctx, dialogType, title, msg, inputContext, inputHandler);
// }
// extern void snHandleDialogInput(unsigned long inputContext, unsigned char ok, char* result);
// static getInput_result_fn_t snHandleDialogInputFn() {
//   return snHandleDialogInput;
// }
import "C"

import (
	"fmt"
	"time"
	"unsafe"
)

var (
	showDialogFuncs = make(map[uintptr]*dialogContext)
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

type dialogContext struct {
	showFunc,
	dismissHandler uintptr
}

type dialogHandle struct {
	dlgContext,
	dlgHandle uintptr
}

type dialogInputHandle struct {
	input chan *string
}

//export snRegisterShowDialogFunc
func snRegisterShowDialogFunc(dlgContext, showFunc uintptr) {
	if dlgContext != 0 && showFunc != 0 {
		showDialogFuncs[dlgContext] = &dialogContext{
			showFunc: showFunc,
		}	
	}
}

//export snSetDialogDismissHandler
func snSetDialogDismissHandler(dlgContext, handler uintptr) {
	if dc, ok := showDialogFuncs[dlgContext]; ok {
		dc.dismissHandler = handler
	}
}

//export snUnregisterShowDialogFunc
func snUnregisterShowDialogFunc(dlgContext uintptr) {
	delete(showDialogFuncs, dlgContext)
}

//export snHandleDialogInput
func snHandleDialogInput(inputContext uintptr, ok uint8, result *C.char) {	
	inputHandle := (*dialogInputHandle)(unsafe.Pointer(inputContext))
	if ok != 0 {
		result := C.GoString(result)
		inputHandle.input <- &result
	} else {
		inputHandle.input <- nil
	}
}

func showDialog(dlgContext uintptr, dialogType int, title, msg string, withTextInput int, inputHandle *dialogInputHandle) *dialogHandle {
	if dc, ok := showDialogFuncs[dlgContext]; ok {
		context := unsafe.Pointer(dlgContext)
		showFunc := unsafe.Pointer(dc.showFunc)
		if uintptr(showFunc) != 0 {
			return &dialogHandle{
				dlgContext: dlgContext,
				dlgHandle: uintptr(C.showDialog(showFunc, context, 
					C.uchar(dialogType),
					C.CString(title), 
					C.CString(msg),
					C.uchar(withTextInput),
					C.ulong(uintptr(unsafe.Pointer(inputHandle))),
				)),
			}		
		}	
	}
	return nil
}

func dismissDialog(handle *dialogHandle) {
	if dc, ok := showDialogFuncs[handle.dlgContext]; ok && handle.dlgHandle != 0 {
		context := unsafe.Pointer(handle.dlgContext)
		handle := unsafe.Pointer(handle.dlgHandle)
		dismissFunc := unsafe.Pointer(dc.dismissHandler)
		if uintptr(dismissFunc) != 0 {
			C.dismissDialog(dismissFunc, context, handle)
		}	
	}
}

func getInput(context, getInputFn uintptr, dialogType int, title, msg string, inputHandle *dialogInputHandle) {
	dlgContext := unsafe.Pointer(context)
	getInputFunc := unsafe.Pointer(getInputFn)
	if uintptr(getInputFunc) != 0 {
		C.getInput(getInputFunc, dlgContext, 
			C.uchar(dialogType),
			C.CString(title), 
			C.CString(msg),
			C.ulong(uintptr(unsafe.Pointer(inputHandle))),
			C.snHandleDialogInputFn(),
		)
	}
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

//export snTESTdialogNotifyAndInput
func snTESTdialogNotifyAndInput(dlgContext uintptr) {

	inputHandle := &dialogInputHandle{
		input: make(chan *string),
	}

	dlgHandle := showDialog(
		dlgContext,
		SN_DIALOG_ALERT, 
		"This is an Alert", 
		"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat",
		C_FALSE,
		inputHandle,
	)
	
	go func() {
		select {
		case <-inputHandle.input:
			fmt.Println("Alert Dismissed")
		case <- time.After(time.Second * 10):
			fmt.Println("Dismissing Alert")
			dismissDialog(dlgHandle)
			fmt.Println("Done")
			return
		}
	}()
}

//export snTESTHello
func snTESTHello(name *C.char) *C.char {
	return C.CString(fmt.Sprintf("(%s) Hello %s", homeDir, C.GoString(name)))
}

// End: Swift / Golang UX Interop TESTS
