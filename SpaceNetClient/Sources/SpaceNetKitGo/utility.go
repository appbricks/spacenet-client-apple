/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2018-2023 WireGuard LLC. All Rights Reserved.
 */

package main

import (
	"fmt"
	"os"
	"runtime/debug"
	"strings"

	"github.com/gookit/color"
	"github.com/sirupsen/logrus"

	"github.com/mevansam/goutils/utils"
)

func showErrorAndExit(message string) {
	
	var (
		stack strings.Builder
	)

	showErrorMessage(message)
	
	logLevel := logrus.GetLevel()	
	if logLevel == logrus.TraceLevel || logLevel == logrus.DebugLevel {
		stack.Write(debug.Stack())
		fmt.Println(
			color.Red.Render("\n" + stack.String()),
		)
	}

	os.Exit(1)
}

func showErrorMessage(message string) {

	var (
		format string
	)

	if message[len(message)-1] == '.' {
		format = "\nError! %s\n"
	} else {
		format = "\nError! %s.\n"
	}

	fmt.Println(
		color.Red.Render(
			utils.FormatMessage(7, 80, false, true, format, message),
		),
	)
}

func showWarningMessage(message string, args ...interface{}) {
	fmt.Println(
		color.Warn.Render(
			utils.FormatMessage(
				0, 80, false, false, 
				message, 
				args...,
			),
		),
	)
}
