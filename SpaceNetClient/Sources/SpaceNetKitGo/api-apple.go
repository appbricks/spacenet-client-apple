/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2023 AppBricks, Inc. All Rights Reserved.
 */

package main

// #include <stdlib.h>
// #include <stdio.h>
// #include <sys/types.h>
//
// static void postStatusChange(void *func, void *ctx, const unsigned char status)
// {
//   ((void(*)(void *, const unsigned char))func)(ctx, status);
// }
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
	"os"
	"path/filepath"
	"unsafe"

	homedir "github.com/mitchellh/go-homedir"

	"github.com/appbricks/cloud-builder/config"
	// "github.com/appbricks/mycloudspace-client/mycscloud"
	// "github.com/appbricks/mycloudspace-common/monitors"
	"github.com/mevansam/goutils/logger"
)

var (
	homeDir string

	cfgStatusHandlers = [][2]uintptr{}

	showDialogFuncs [3]uintptr

	passphraseInput chan *string

	// Global configuration
	snConfig config.Config

	// // Monitor Service
	// monitorService *monitors.MonitorService

	// // Space Targets
	// spaceNodes *mycscloud.SpaceNodes
)

var isProd = "no"

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

//export snRegisterStatusChangeHandler
func snRegisterStatusChangeHandler(context, handler uintptr) {
	cfgStatusHandlers = append(cfgStatusHandlers, [2]uintptr{handler, context})
}
func postStatusChange(status C.uchar) {
	for _, h := range cfgStatusHandlers {
		if h[0] != 0 {
			fn  := unsafe.Pointer(h[0])
			ctx := unsafe.Pointer(h[1])
			C.postStatusChange(fn, ctx, status)
		}
	}
}

//export snInitializeContext
func snInitializeContext(passphrase *C.char) {	

	go func() {

		var (
			err error
		)

		needsPassphrase := false
		getPassphrase := func() string {
			if passphrase == nil {
				needsPassphrase = true
				return ""
			}
			return C.GoString(passphrase)
		}

		// initialize / load config file
		cfgFile := filepath.Join(homeDir, ".cb", "config.yml")
		logger.DebugMessage("Loading config: %s", cfgFile)

		if snConfig, err = config.InitFileConfig(
			cfgFile, nil, 
			getPassphrase, nil,
		); err != nil {
			logger.DebugMessage("Error initializing the config file instance: %s", err.Error())
			showErrorAndExit(err.Error())
		}
		if needsPassphrase {
			postStatusChange(SN_CFG_STATUS_LOCKED)

		} else {
			if err = snConfig.Load(); err != nil {
				logger.DebugMessage("Error loading the configuration data: %s", err.Error())
				showErrorAndExit(err.Error())
			}

			if snConfig.Initialized() {
				postStatusChange(SN_CFG_STATUS_NEEDS_LOGIN)
			} else {
				postStatusChange(SN_CFG_STATUS_NEEDS_INIT)
			}			
		}		
	}()	
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

func init() {

	var (
		err error
	)

	if isProd == "yes" {
		logLevel := os.Getenv("CBS_LOGLEVEL")
		if len(logLevel) == 0 {
			// default is error but for prod builds we do 
			// not want to show errors unless requested
			os.Setenv("CBS_LOGLEVEL", "fatal")

		} else if logLevel == "trace" {
			// reset trace log level if set for prod builds
			showWarningMessage(
				"Trace log-level is not supported in prod build. Resetting level to 'debug'.\n",
			)
			os.Setenv("CBS_LOGLEVEL", "debug")
		}
	}
	logger.Initialize()

	// find users home directory.
	homeDir, err = homedir.Dir()
	if err != nil {
		showErrorAndExit(err.Error())
	}

	// initialize data input channels
	passphraseInput = make(chan *string)
}

func main() {
}
