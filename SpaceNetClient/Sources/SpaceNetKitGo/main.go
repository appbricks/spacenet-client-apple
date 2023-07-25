/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2023 AppBricks, Inc. All Rights Reserved.
 */

package main

import (
	"os"

	"github.com/mevansam/goutils/logger"
	homedir "github.com/mitchellh/go-homedir"
)

var (
	homeDir string

	isProd = "no"
)

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
}

func main() {
}
