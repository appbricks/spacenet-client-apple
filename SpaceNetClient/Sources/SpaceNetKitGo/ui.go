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
// typedef unsigned char SN_DIALOG_ACCESSORY_TYPE;
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_NONE = 0;
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_YES_NO = 1;
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_OK_CANCEL = 2;
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_TEXT_INPUT = 3;
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_PASSWORD_INPUT = 4;
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_PASSWORD_INPUT_WITH_VERIFY = 5;
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_SPINNER = 6;
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_PROGRESS_BAR = 7;
//
// static void *showDialog(void *func, void *ctx, const unsigned char dialogType, const char *title, const char *msg, const unsigned char accessoryType, const char *accessoryText, unsigned long inputContext) {
//   return ((void *(*)(void *, const unsigned char, const char *, const char *, const unsigned char, const char *, unsigned long))func)(ctx, dialogType, title, msg, accessoryType, accessoryText, inputContext);
// }
// static void dismissDialog(void *func, void *ctx, void* handle) {
//   ((void(*)(void *, void *))func)(ctx, handle);
// }
// typedef void (*getInput_result_fn_t)(unsigned long, unsigned char, char *);
// static void getInput(void *func, void *ctx, const unsigned char dialogType, const char *title, const char *msg, const char *defaultInput, unsigned long inputContext, getInput_result_fn_t inputHandler)
// {
//   ((void(*)(void *, const unsigned char, const char *, const char *, const char *, unsigned long, getInput_result_fn_t))func)(ctx, dialogType, title, msg, defaultInput, inputContext, inputHandler);
// }
// extern void snHandleDialogInput(unsigned long inputContext, unsigned char ok, char* result);
// static getInput_result_fn_t snHandleDialogInputFn() {
//   return snHandleDialogInput;
// }
import "C"

import (
	"context"
	"fmt"
	"strings"
	"time"
	"unsafe"

	"github.com/appbricks/mycloudspace-client/ui"
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

	SN_DIALOG_ACCESSORY_NONE = 0
	SN_DIALOG_ACCESSORY_YES_NO = 1
	SN_DIALOG_ACCESSORY_OK_CANCEL = 2
	SN_DIALOG_ACCESSORY_TEXT_INPUT = 3
	SN_DIALOG_ACCESSORY_PASSWORD_INPUT = 4
	SN_DIALOG_ACCESSORY_PASSWORD_INPUT_WITH_VERIFY = 5
	SN_DIALOG_ACCESSORY_SPINNER = 6
	SN_DIALOG_ACCESSORY_PROGRESS_BAR = 7

	EMPTY_STRING = ""
)

type dialogContext struct {
	showFunc,
	dismissHandler uintptr
}

type dialogHandle struct {
	dlgContext,
	dlgHandle uintptr
	dlgInputHandle *dialogInputHandle
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

func showDialog(dlgContext uintptr, dialogType int, title, msg string, accessoryType int, accessoryText string, inputHandle *dialogInputHandle) *dialogHandle {
	if dc, ok := showDialogFuncs[dlgContext]; ok {
		context := unsafe.Pointer(dlgContext)
		showFunc := unsafe.Pointer(dc.showFunc)
		if uintptr(showFunc) != 0 {
			return &dialogHandle{
				dlgContext: dlgContext,
				dlgInputHandle: inputHandle,
				dlgHandle: uintptr(C.showDialog(showFunc, context, 
					C.uchar(dialogType),
					C.CString(title), 
					C.CString(msg),
					C.uchar(accessoryType),
					C.CString(accessoryText),
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

func getInput(context, getInputFn uintptr, dialogType int, title, msg, defaultInput string, inputHandle *dialogInputHandle) {
	dlgContext := unsafe.Pointer(context)
	getInputFunc := unsafe.Pointer(getInputFn)
	if uintptr(getInputFunc) != 0 {
		C.getInput(getInputFunc, dlgContext, 
			C.uchar(dialogType),
			C.CString(title), 
			C.CString(msg),
			C.CString(defaultInput),
			C.ulong(uintptr(unsafe.Pointer(inputHandle))),
			C.snHandleDialogInputFn(),
		)
	}
}

// Implements UI interface
type appUI struct {
	cancel context.CancelFunc

	dlgContext uintptr
}

type appMessage struct {
	appUI *appUI

	dialogType int
	title      string

	msgBuffer strings.Builder

	dlgHandle *dialogHandle
	inputHandle *dialogInputHandle
}

type appProgressIndicator struct {
	msg *appMessage

	startMsg,
	progressMsg,
	endMsg string
}

func NewAppUI(cancel context.CancelFunc, dlgContext uintptr) ui.UI {
	return &appUI{
		cancel: cancel,

		dlgContext: dlgContext,
	}
}

func (ui *appUI) NewUIMessage(title string) ui.Message {
	return &appMessage{
		appUI: ui,

		title:      title,
		dialogType: SN_DIALOG_APP,
	}
}

func (msg *appMessage) WriteMessage(message string) {
	msg.dialogType = SN_DIALOG_APP
	msg.WriteText(message)
}

func (msg *appMessage) WriteCommentMessage(message string) {
	msg.dialogType = SN_DIALOG_APP
	msg.WriteText(message)
}

func (msg *appMessage) WriteInfoMessage(message string) {
	msg.dialogType = SN_DIALOG_APP
	msg.WriteText(message)
}

func (msg *appMessage) WriteNoteMessage(message string) {
	msg.dialogType = SN_DIALOG_NOTIFY
	msg.WriteText(message)
}

func (msg *appMessage) WriteNoticeMessage(message string) {
	msg.dialogType = SN_DIALOG_NOTIFY
	msg.WriteText(message)
}

func (msg *appMessage) WriteErrorMessage(message string) {
	msg.dialogType = SN_DIALOG_ERROR
	msg.WriteText(message)
}

func (msg *appMessage) WriteDangerMessage(message string) {
	msg.dialogType = SN_DIALOG_ERROR
	msg.WriteText(message)
}

func (msg *appMessage) WriteFatalMessage(message string) {
	msg.dialogType = SN_DIALOG_ERROR
	msg.WriteText(message)
}

func (msg *appMessage) WriteText(text string) {
	if msg.msgBuffer.Len() > 0 {
		msg.msgBuffer.WriteString("\n\n")
	}
	msg.msgBuffer.WriteString(text)
}

func (msg *appMessage) ShowMessage() {

}

func (msg *appMessage) DismissMessage() {

}

func (msg *appMessage) ShowMessageWithProgressIndicator(startMsg, progressMsg, endMsg string, doneAt int) ui.ProgressMessage {

	msg.inputHandle = &dialogInputHandle{
		input: make(chan *string, 1),
	}	

	accType := SN_DIALOG_ACCESSORY_SPINNER
	if doneAt > 0 {
		accType = SN_DIALOG_ACCESSORY_PROGRESS_BAR
	}

	msg.dlgHandle = showDialog(
		msg.appUI.dlgContext,
		msg.dialogType, 
		msg.title, 
		msg.msgBuffer.String(),
		accType,
		startMsg,
		msg.inputHandle,
	)

	return &appProgressIndicator{
		msg: msg,

		startMsg:    startMsg,
		progressMsg: progressMsg,
		endMsg:      endMsg,
	}
}

func (pi *appProgressIndicator) Start() {

	go func() {
		<-pi.msg.inputHandle.input
		pi.msg.appUI.cancel()
		// clear dialog handle as it would have already been dismissed
		pi.msg.dlgHandle = nil
	}()
}

func (pi *appProgressIndicator) Update(updateMsg string, progressAt int) {
}

func (pi *appProgressIndicator) Done() {
	if pi.msg.dlgHandle != nil {
		dismissDialog(pi.msg.dlgHandle)
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
		"Test Input", 
		"Please enter some test text input.",
		"default input",
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
		input: make(chan *string, 1),
	}

	dlgHandle := showDialog(
		dlgContext,
		SN_DIALOG_ALERT, 
		"This is an Alert", 
		"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt.",
		SN_DIALOG_ACCESSORY_OK_CANCEL,
		"## Lorem ipsum dolor sit amet, consectetur adipiscing elit.\nSed do eiusmod tempor **incididunt** ut labore et dolore [magna aliqua](https://www.google.com). Ut enim ad minim veniam, *quis nostrud exercitation ullamco laboris* nisi ut aliquip ex ea commodo consequat",inputHandle,
	)
	
	go func() {
		select {
		case res := <-inputHandle.input:
			if res != nil {
				fmt.Println("Alert Dismissed with OK")
			} else {
				fmt.Println("Alert Dismissed with Cancel")
			}
		case <-time.After(time.Second * 10):
			fmt.Println("Dismissing Alert")
			dismissDialog(dlgHandle)
			fmt.Println("Done")
		}
	}()
}

//export snTESTHello
func snTESTHello(name *C.char) *C.char {
	return C.CString(fmt.Sprintf("(%s) Hello %s", homeDir, C.GoString(name)))
}

// End: Swift / Golang UX Interop TESTS
