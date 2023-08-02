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
// static void onLoggedIn(void *func, void *ctx, const char *username)
// {
//	 ((void(*)(void *, const char *))func)(ctx, username);
// }
import "C"

import (
	"context"
	"path/filepath"
	"unsafe"

	"github.com/appbricks/cloud-builder/config"
	"github.com/appbricks/mycloudspace-client/api"
	"github.com/appbricks/mycloudspace-client/auth"

	// "github.com/appbricks/mycloudspace-client/mycscloud"
	// "github.com/appbricks/mycloudspace-common/monitors"
	"github.com/mevansam/goutils/logger"
)

var (
	cfgStatusHandlers = [][2]uintptr{}

	// Global configuration
	appConfig config.Config

	// Authenticated user
	authContext	config.AuthContext

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

		if appConfig, err = config.InitFileConfig(
			cfgFile, nil, 
			getPassphrase, nil,
		); err != nil {
			logger.DebugMessage("Error initializing the config file instance: %s", err.Error())
			showErrorAndExit(err.Error())
		}
		if needsPassphrase {
			postStatusChange(SN_CFG_STATUS_LOCKED)

		} else {
			if err = appConfig.Load(); err != nil {
				logger.DebugMessage("Error loading the configuration data: %s", err.Error())
				showErrorAndExit(err.Error())
			}

			if appConfig.Initialized() {
				postStatusChange(SN_CFG_STATUS_NEEDS_LOGIN)
			} else {
				postStatusChange(SN_CFG_STATUS_NEEDS_INIT)
			}			
		}		
	}()	
}

//export snEULAAccepted
func snEULAAccepted() C.uchar {	
	if appConfig != nil && appConfig.Initialized() && appConfig.EULAAccepted() {
		return C.uchar(1)
	}
	return C.uchar(0)
}

//export snSetEULAAccepted
func snSetEULAAccepted() {
	appConfig.SetEULAAccepted()
}

//export snAuthenticate
func snAuthenticate(dlgContext, handler uintptr) {	

	var (
		err error

		awsAuth *auth.AWSCognitoJWT
	)

	serviceConfig := getServiceConfig()

	ctx, cancel := context.WithCancel(context.Background())
	appUI := NewAppUI(cancel, dlgContext)
	authContext := config.NewAuthContext()
	authRet := auth.Authenticate(ctx, serviceConfig, authContext, appUI)

	go func() {
		if err := (<-authRet).Error; err != nil {				
			logger.ErrorMessage("Authentication failed: %s", err.Error())	
			return
		}
		if awsAuth, err = auth.NewAWSCognitoJWT(serviceConfig, authContext); err != nil {
			logger.ErrorMessage("Failed to extract auth token: %s", err.Error())	
			return
		}

		dlgContext := unsafe.Pointer(dlgContext)
		handlerFunc := unsafe.Pointer(handler)
		if uintptr(handlerFunc) != 0 {
			C.onLoggedIn(handlerFunc, dlgContext, C.CString(awsAuth.Username()))
		}
	}()
}

func getServiceConfig() api.ServiceConfig {
	return api.ServiceConfig{			
		// AWS Region
		Region: AWS_COGNITO_REGION,
		// Cognito user pool ID
		UserPoolID: AWS_COGNITO_USER_POOL_ID,
		// User pool resource app 
		// client ID and secret
		CliendID: CLIENT_ID,
		ClientSecret: CLIENT_SECRET,
		// Endpoint URLs
		AuthURL: AUTH_URL,
		TokenURL: TOKEN_URL,
		ApiURL: AWS_USERSPACE_API_URL,
	}
}
