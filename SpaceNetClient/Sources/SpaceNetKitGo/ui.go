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
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_FILE_OPEN = 6;
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_SPINNER = 7;
// const SN_DIALOG_ACCESSORY_TYPE SN_DIALOG_ACCESSORY_PROGRESS_BAR = 8;
//
// static void *showDialog(void *func, void *ctx, const unsigned char dialogType, const char *title, const char *msg, const unsigned char accessoryType, const char *accessoryText, const unsigned char dispathToMain, unsigned long inputContext) {
//   return ((void *(*)(void *, const unsigned char, const char *, const char *, const unsigned char, const char *, const unsigned char, unsigned long))func)(ctx, dialogType, title, msg, accessoryType, accessoryText, dispathToMain, inputContext);
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
	"github.com/mevansam/goutils/logger"
)

var (
	showDialogFuncs = make(map[uintptr]*dialogContext)

	dialogHandleLookup = make(map[uintptr]uintptr)
)

const (
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
	SN_DIALOG_ACCESSORY_FILE_OPEN = 6
	SN_DIALOG_ACCESSORY_SPINNER = 7
	SN_DIALOG_ACCESSORY_PROGRESS_BAR = 8

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
	delete(dialogHandleLookup, inputContext)
}

//export snAssociateDialogInputToHandle
func snAssociateDialogInputToHandle(inputContext, handle uintptr) {
	dialogHandleLookup[inputContext] = handle
}

func showDialog(
	dlgContext uintptr, 
	dialogType int, 
	title, msg string, 
	accessoryType int, 
	accessoryText string, 
	dispathToMain bool,
	inputHandle *dialogInputHandle,
) *dialogHandle {
	if dc, ok := showDialogFuncs[dlgContext]; ok {

		context := unsafe.Pointer(dlgContext)
		showFunc := unsafe.Pointer(dc.showFunc)

		dispatch := C.uchar(0)
		if dispathToMain {
			dispatch = C.uchar(1)
		}

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
					dispatch,
					C.ulong(uintptr(unsafe.Pointer(inputHandle))),
				)),
			}		
		}	
	} else {
		logger.ErrorMessage("No show dialog function registered for context %x", dlgContext)
	}
	return nil
}

func dismissDialog(handle *dialogHandle) {
	if dc, ok := showDialogFuncs[handle.dlgContext]; ok {
		if handle.dlgHandle == 0 {
			handle.dlgHandle = dialogHandleLookup[uintptr(unsafe.Pointer(handle.dlgInputHandle))]
		}

		if handle.dlgHandle != 0 {
			context := unsafe.Pointer(handle.dlgContext)
			handle := unsafe.Pointer(handle.dlgHandle)
			dismissFunc := unsafe.Pointer(dc.dismissHandler)
			if uintptr(dismissFunc) != 0 {
				C.dismissDialog(dismissFunc, context, handle)
			}

		} else {
			logger.ErrorMessage("Dismiss dialog handle was nil")
		}

	} else {
		logger.ErrorMessage("No dismiss dialog function registered for context %x", handle.dlgContext)
	}
}

func getInput(
	context, getInputFn uintptr, 
	dialogType int, 
	title, msg, defaultInput string, 
	inputHandle *dialogInputHandle,
) {
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
	dlgContext uintptr

	dispatchToMain bool
}

type appMessage struct {
	appUI  *appUI
	cancel context.CancelFunc

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

func NewAppUI(dlgContext uintptr) ui.UI {
	return &appUI{
		dlgContext:     dlgContext,
		dispatchToMain: false,
	}
}

func NewAppUIBackground(dlgContext uintptr) ui.UI {
	return &appUI{
		dlgContext:     dlgContext,
		dispatchToMain: true,
	}
}

func (ui *appUI) NewUIMessage(title string) ui.Message {
	return &appMessage{
		appUI: ui,

		title:      title,
		dialogType: SN_DIALOG_APP,
	}
}

func (ui *appUI) NewUIMessageWithCancel(title string, cancel context.CancelFunc) ui.Message {
	return &appMessage{
		appUI:  ui,
		cancel: cancel,

		title:      title,
		dialogType: SN_DIALOG_APP,
	}
}

func (ui *appUI) ShowErrorMessage(message string) {
	uh := ui.NewUIMessage("Error").(*appMessage)
	uh.WriteErrorMessage(message)
	uh.showMessage(true)
}

func (ui *appUI) ShowInfoMessage(title, message string) {
	uh := ui.NewUIMessage(title).(*appMessage)
	uh.WriteInfoMessage(message)
	uh.showMessage(true)
}

func (ui *appUI) ShowNoteMessage(title, message string) {
	uh := ui.NewUIMessage(title).(*appMessage)
	uh.WriteNoteMessage(message)
	uh.showMessage(true)
}

func (ui *appUI) ShowNoticeMessage(title, message string) {
	uh := ui.NewUIMessage(title).(*appMessage)
	uh.WriteNoticeMessage(message)
	uh.showMessage(true)
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

func (msg *appMessage) showMessage(dispatchToMain bool) {

	msg.inputHandle = &dialogInputHandle{
		input: make(chan *string, 1),
	}

	msg.dlgHandle = showDialog(
		msg.appUI.dlgContext,
		msg.dialogType, 
		msg.title, 
		msg.msgBuffer.String(),
		SN_DIALOG_ACCESSORY_NONE,
		EMPTY_STRING,
		dispatchToMain,
		msg.inputHandle,
	)

	go func() {
		<-msg.inputHandle.input		
		// clear dialog handle as it would have already been dismissed
		msg.dlgHandle = nil
	}()
}

func (msg *appMessage) ShowMessageWithInput(defaultInput string, handleInput func(*string)) {
	msg.showMessageWithInput(SN_DIALOG_ACCESSORY_TEXT_INPUT, defaultInput, true, handleInput)	
}

func (msg *appMessage) ShowMessageWithSecureInput(handleInput func(*string)) {
	msg.showMessageWithInput(SN_DIALOG_ACCESSORY_PASSWORD_INPUT, EMPTY_STRING, true, handleInput)	
}

func (msg *appMessage) ShowMessageWithSecureVerifiedInput(handleInput func(*string)) {
	msg.showMessageWithInput(SN_DIALOG_ACCESSORY_PASSWORD_INPUT_WITH_VERIFY, EMPTY_STRING, true, handleInput)	
}

func (msg *appMessage) ShowMessageWithYesNoInput(handleInput func(bool)) {
	msg.showMessageWithInput(SN_DIALOG_ACCESSORY_YES_NO, "", true, 
		func(input *string) {
			handleInput(input != nil)
		},
	)
}

func (msg *appMessage) ShowMessageWithFileInput(handleInput func(*string)) {
	msg.showMessageWithInput(SN_DIALOG_ACCESSORY_FILE_OPEN, "", true, handleInput)	
}

func (msg *appMessage) showMessageWithInput(accType int, accessoryText string, dispatchToMain bool, handleInput func(*string)) {

	msg.inputHandle = &dialogInputHandle{
		input: make(chan *string, 1),
	}

	msg.dlgHandle = showDialog(
		msg.appUI.dlgContext,
		msg.dialogType, 
		msg.title, 
		msg.msgBuffer.String(),
		accType,
		accessoryText,
		dispatchToMain,
		msg.inputHandle,
	)

	go func() {
		input := <-msg.inputHandle.input
		if msg.cancel != nil {
			msg.cancel()
		}
		handleInput(input)

		// clear dialog handle as it would have already been dismissed
		msg.dlgHandle = nil
	}()
}

func (msg *appMessage) DismissMessage() {
	if msg.cancel != nil {
		msg.cancel()
	}
	if msg.dlgHandle != nil {
		dismissDialog(msg.dlgHandle)
	}
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
		msg.appUI.dispatchToMain,
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
		if pi.msg.cancel != nil {
			pi.msg.cancel()
		}
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
		"## Lorem ipsum dolor sit amet, consectetur adipiscing elit.\nSed do eiusmod tempor **incididunt** ut labore et dolore [magna aliqua](https://www.google.com). Ut enim ad minim veniam, *quis nostrud exercitation ullamco laboris* nisi ut aliquip ex ea commodo consequat",
		false,
		inputHandle,
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
