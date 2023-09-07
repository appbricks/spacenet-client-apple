/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2023 AppBricks, Inc. All Rights Reserved.
 */

package main

// #include <stdlib.h>
// #include <stdio.h>
// #include <sys/types.h>
//
// typedef unsigned char BOOL;
//
// typedef unsigned char SN_CFG_STATUS;
// const SN_CFG_STATUS SN_CFG_STATUS_ERROR = 0;
// const SN_CFG_STATUS SN_CFG_STATUS_NEEDS_INIT = 1;
// const SN_CFG_STATUS SN_CFG_STATUS_NEEDS_LOGIN = 2;
// const SN_CFG_STATUS SN_CFG_STATUS_LOGGED_IN = 3;
// const SN_CFG_STATUS SN_CFG_STATUS_LOGGED_OUT = 4;
// const SN_CFG_STATUS SN_CFG_STATUS_LOCKED = 5;
//
// static void postStatusChange(void *func, void *ctx, const SN_CFG_STATUS status)
// {
//   ((void(*)(void *, const unsigned char))func)(ctx, status);
// }
// static void onDone(void *func, void *ctx, const BOOL ok)
// {
//	 ((void(*)(void *, const BOOL))func)(ctx, ok);
// }
// static void onSettingsInit(void *func, void *ctx, const BOOL ok, const BOOL isInitialized, const char *deviceUser, const char *deviceName, const char *deviceLockPassphrase, const int unlockedTimeout)
// {
//	 ((void(*)(void *, const BOOL, const BOOL, const char *, const char *, const char *, const int))func)(ctx, ok, isInitialized, deviceUser, deviceName, deviceLockPassphrase, unlockedTimeout);
// }
// static void onSettingsDeviceOwnerLoggedIn(void *func, void *ctx, const char *username, const char *deviceName, const BOOL needsKey)
// {
//	 ((void(*)(void *, const char *, const char *, const BOOL))func)(ctx, username, deviceName, needsKey);
// }
// static void onSettingsOwnerKeyLoaded(void *func, void *ctx, const BOOL ok, const char *keyFile)
// {
//	 ((void(*)(void *, const BOOL, const char *))func)(ctx, ok, keyFile);
// }
import "C"

import (
	"context"
	"path/filepath"
	"unsafe"

	"github.com/appbricks/cloud-builder/config"
	"github.com/appbricks/mycloudspace-client/api"
	"github.com/appbricks/mycloudspace-client/auth"
	mycsconfig "github.com/appbricks/mycloudspace-client/config"

	// "github.com/appbricks/mycloudspace-client/mycscloud"
	// "github.com/appbricks/mycloudspace-common/monitors"

	"github.com/mevansam/goutils/logger"
)

var (
	cfgStatusHandlers = [][2]uintptr{}

	// Global configuration
	appConfig config.Config

	// // Monitor Service
	// monitorService *monitors.MonitorService

	// // Space Targets
	// spaceNodes *mycscloud.SpaceNodes
)

const (
	SN_CFG_STATUS_ERROR       = 0
	SN_CFG_STATUS_NEEDS_INIT  = 1
	SN_CFG_STATUS_NEEDS_LOGIN = 2
	SN_CFG_STATUS_LOGGED_IN   = 3
	SN_CFG_STATUS_LOGGED_OUT  = 4
	SN_CFG_STATUS_LOCKED      = 5
)

var configInitializer *mycsconfig.ConfigInitializer

//export snRegisterStatusChangeHandler
func snRegisterStatusChangeHandler(context, handler uintptr) {
	cfgStatusHandlers = append(cfgStatusHandlers, [2]uintptr{handler, context})
}
func postStatusChange(status C.uchar) {
	logger.DebugMessage("Posting config status change: %d", status)
	for _, h := range cfgStatusHandlers {
		if h[0] != 0 {
			fn  := unsafe.Pointer(h[0])
			ctx := unsafe.Pointer(h[1])
			C.postStatusChange(fn, ctx, status)
		}
	}
}

//export snInitializeContext
func snInitializeContext(passphrase *C.char) C.uchar {	

	var (
		ppProvided bool
		ppValue    string
	)

	if passphrase != nil {
		ppValue = C.GoString(passphrase)
		ppProvided = true
	}

	var (
		err error

		isAuthenticated bool
	)
	ok := C.uchar(1)

	// initialize / load config file
	configFile := filepath.Join(homeDir, ".cb", "config.yml")
	logger.DebugMessage("Loading config: %s", configFile)

	needsPassphrase := false
	getPassphrase := func() string {
		if !ppProvided {
			logger.DebugMessage("Device unlock passphrase required but not provided")
			needsPassphrase = true
			return ""
		}
		logger.DebugMessage("Device unlock passphrase required and provided")
		return ppValue
	}

	if appConfig, err = config.InitFileConfig(
		configFile, nil, 
		getPassphrase, nil,
	); err != nil {
		logger.ErrorMessage("Failed to initialize the config file instance: %s", err.Error())
		ok = C.uchar(0)
	}
	if needsPassphrase {
		postStatusChange(SN_CFG_STATUS_LOCKED)

	} else {
		if err = appConfig.Load(); err != nil {
			logger.ErrorMessage("Failed to load the configuration data: %s", err.Error())
			postStatusChange(SN_CFG_STATUS_LOCKED)
			ok = C.uchar(0)

		} else if appConfig.Initialized() {
			if isAuthenticated, err = auth.ValidateAuthenticatedToken(getServiceConfig(), appConfig); err != nil {
				logger.ErrorMessage("Error loading the configuration data: %s", err.Error())
				postStatusChange(SN_CFG_STATUS_NEEDS_LOGIN)
			} else if isAuthenticated {
				postStatusChange(SN_CFG_STATUS_LOGGED_IN)
			} else {
				postStatusChange(SN_CFG_STATUS_NEEDS_LOGIN)
			}
		} else {
			postStatusChange(SN_CFG_STATUS_NEEDS_INIT)
		}	
	}	

	return ok
}

//export snLogin
func snLogin(dlgContext uintptr, handler uintptr) {

	context := unsafe.Pointer(dlgContext)
	handlerFunc := unsafe.Pointer(handler)

	appUI := NewAppUI(dlgContext)

	auth.Login(
		getServiceConfig(),
		appConfig,
		appUI,
		func(err error) {

			defer func() {
				if err = appConfig.Save(); err != nil {
					logger.ErrorMessage("Failed to save configuration after login: %s", err.Error())

					_ = appConfig.AuthContext().Reset()
					postStatusChange(SN_CFG_STATUS_LOGGED_OUT)				
				}
			}()
			
			if err != nil {
				logger.ErrorMessage("Failed to login: %s", err.Error())
				postStatusChange(SN_CFG_STATUS_LOGGED_OUT)

			} else if appConfig.AuthContext().IsLoggedIn() {
				postStatusChange(SN_CFG_STATUS_LOGGED_IN)

			} else {
				postStatusChange(SN_CFG_STATUS_LOGGED_OUT)
			}

			if uintptr(handlerFunc) != 0 {
				ok := C.uchar(1)
				if err != nil {
					ok = C.uchar(0)
				}
				C.onDone(
					handlerFunc, 
					context, 
					ok,
				)
			}
		},
	)
}

//export snLogout
func snLogout() C.uchar {

	var (
		err error
	)

	if err = auth.Logout(getServiceConfig(), appConfig); err != nil {
		logger.ErrorMessage("Failed to logout: %s", err.Error())

	} else {
		if err = appConfig.Save(); err != nil {
			logger.ErrorMessage("Failed to save configuration after logout: %s", err.Error())
		
		} else {
			postStatusChange(SN_CFG_STATUS_LOGGED_OUT)
		}
	}

	ok := C.uchar(1)
	if err != nil {
		ok = C.uchar(0)
	}
	return ok
}

//export snLoggedInUser
func snLoggedInUser() *C.char {

	var (
		err error

		awsAuth *auth.AWSCognitoJWT
	)

	if appConfig != nil {
		if awsAuth, err = auth.NewAWSCognitoJWT(
			getServiceConfig(),
			appConfig.AuthContext(),
		); err != nil {
			logger.ErrorMessage("Failed to extract auth token: %s", err.Error())	
		} else {
			return C.CString(awsAuth.Username())
		}
	}
	return nil
}

//export snIsLoggedInUserOwner
func snIsLoggedInUserOwner() C.uchar {
	if appConfig != nil {
		deviceContext := appConfig.DeviceContext()
		if ownerName, ok := deviceContext.GetOwnerUserName(); 
			ok && ownerName == deviceContext.GetLoggedInUserName() {
			return C.uchar(1)
		}
	}
	return C.uchar(0)
}

//export snEULAAccepted
func snEULAAccepted() C.uchar {	
	if appConfig != nil && appConfig.EULAAccepted() {
		return C.uchar(1)
	}
	return C.uchar(0)
}

//export snSetEULAAccepted
func snSetEULAAccepted() {
	appConfig.SetEULAAccepted()
	if err := appConfig.Save(); err != nil {
		panic(err.Error())
	}
}

//export snSettingsInit
func snSettingsInit(dlgContext uintptr, handler uintptr) {

	var (
		err error
	)

	dialogCtx := unsafe.Pointer(dlgContext)
	handlerFunc := unsafe.Pointer(handler)

	ok := C.uchar(1)
	if configInitializer, err = mycsconfig.NewConfigInitializer(
		appConfig,
		context.Background(),
		getServiceConfig(), 
		NewAppUIBackground(dlgContext),
	); err != nil {
		logger.ErrorMessage("Error initializing the config initializer: %s", err.Error())
		ok = C.uchar(0)
	}

	if uintptr(handlerFunc) != 0 {

		cDeviceUserName := C.CString(configInitializer.DeviceUsername())
		cDeviceName := C.CString(configInitializer.DeviceName())
		cDevicePassphrase := C.CString(configInitializer.DevicePassphrase())

		initialized := C.uchar(0)
		if configInitializer.Initialized() {
			initialized = C.uchar(1)
		}

		C.onSettingsInit(
			handlerFunc, 
			dialogCtx, 
			ok,
			initialized,
			cDeviceUserName,
			cDeviceName,
			cDevicePassphrase,
			C.int(configInitializer.UnlockedTimeout()),
		)

		C.free(unsafe.Pointer(cDeviceUserName))
		C.free(unsafe.Pointer(cDeviceName))
		C.free(unsafe.Pointer(cDevicePassphrase))
	}
}

//export snSettingsResetDeviceOwner
func snSettingsResetDeviceOwner(dlgContext, handler uintptr) {	

	context := unsafe.Pointer(dlgContext)
	handlerFunc := unsafe.Pointer(handler)

	configInitializer.ResetDeviceOwner(
		func(userName, deviceName string, userNeedsNewKey bool, err error) {

			if err != nil {
				logger.ErrorMessage("Authentication failed: %s", err.Error())	

			} else {
				needsKey := C.uchar(0)
				if userNeedsNewKey {
					needsKey = C.uchar(1)
				}

				if uintptr(handlerFunc) != 0 {

					cUserName := C.CString(userName)
					cDeviceName := C.CString(deviceName)

					C.onSettingsDeviceOwnerLoggedIn(
						handlerFunc, 
						context, 
						cUserName,
						cDeviceName,
						needsKey,
					)

					C.free(unsafe.Pointer(cUserName))
					C.free(unsafe.Pointer(cDeviceName))
				}
			}
		},
	)
}

//export snSettingsLoadUserKey
func snSettingsLoadUserKey(
	dlgContext uintptr, 
	keyFile *C.char, 
	createKey uint8, 
	handler uintptr,
) {	
	context := unsafe.Pointer(dlgContext)
	handlerFunc := unsafe.Pointer(handler)

	configInitializer.LoadDeviceOwnerKey(
		C.GoString(keyFile),
		createKey == 1,
		func(keyFileName string, err error) {
			if uintptr(handlerFunc) != 0 {

				ok := C.uchar(1)
				if err != nil {
					logger.ErrorMessage("Failed to load key file: %s", err.Error())	
					ok = C.uchar(0)
				}

				cKeyFileName := C.CString(keyFileName)

				C.onSettingsOwnerKeyLoaded(
					handlerFunc, 
					context, 
					ok,
					cKeyFileName,
				)

				C.free(unsafe.Pointer(cKeyFileName))
			}
		},
	)
}

//export snSettingsSave
func snSettingsSave(
	dlgContext uintptr, 
	deviceName *C.char, 
	deviceLockPassphrase *C.char, 
	unlockedTimeout int, 
	handler uintptr,
) {
	context := unsafe.Pointer(dlgContext)
	handlerFunc := unsafe.Pointer(handler)

	configInitializer.Save(
		C.GoString(deviceName),
		C.GoString(deviceLockPassphrase),
		ClientType,
		Version,
		unlockedTimeout,

		func(err error) {
			if uintptr(handlerFunc) != 0 {

				ok := C.uchar(1)
				if err != nil {
					ok = C.uchar(0)
				}

				C.onDone(
					handlerFunc, 
					context, 
					ok,
				)
			}
		},
	)
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
