/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2023 AppBricks, Inc. All Rights Reserved.
 */

package main

// #include <stdlib.h>
// #include <stdio.h>
// #include <sys/types.h>
//
// typedef unsigned char SN_CFG_STATUS;
// const SN_CFG_STATUS SN_CFG_STATUS_ERROR = 0;
// const SN_CFG_STATUS SN_CFG_STATUS_NEEDS_INIT = 1;
// const SN_CFG_STATUS SN_CFG_STATUS_NEEDS_LOGIN = 2;
// const SN_CFG_STATUS SN_CFG_STATUS_LOGGED_IN = 3;
// const SN_CFG_STATUS SN_CFG_STATUS_LOGGED_OUT = 4;
// const SN_CFG_STATUS SN_CFG_STATUS_LOCKED = 5;
//
// static void postStatusChange(void *func, void *ctx, const unsigned char status)
// {
//   ((void(*)(void *, const unsigned char))func)(ctx, status);
// }
import "C"

import (
	"path/filepath"
	"unsafe"

	"github.com/appbricks/cloud-builder/config"
	// "github.com/appbricks/mycloudspace-client/mycscloud"
	// "github.com/appbricks/mycloudspace-common/monitors"
	"github.com/mevansam/goutils/logger"
)

var (
	cfgStatusHandlers = [][2]uintptr{}

	// Global configuration
	snConfig config.Config

	// // Monitor Service
	// monitorService *monitors.MonitorService

	// // Space Targets
	// spaceNodes *mycscloud.SpaceNodes
)

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
