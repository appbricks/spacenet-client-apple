# SPDX-License-Identifier: MIT
#
# Copyright (C) 2018-2019 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.

# These are generally passed to us by xcode, but we set working defaults for standalone compilation too.
ARCHS ?= x86_64 arm64
PLATFORM_NAME ?= macosx
SDKROOT ?= $(shell xcrun --sdk $(PLATFORM_NAME) --show-sdk-path)
CONFIGURATION_BUILD_DIR ?= $(CURDIR)/out
CONFIGURATION_TEMP_DIR ?= $(CURDIR)/.tmp

export PATH := $(PATH):/usr/local/bin:/opt/homebrew/bin
export CC ?= clang
LIPO ?= lipo
DESTDIR ?= $(CONFIGURATION_BUILD_DIR)
BUILDDIR ?= $(CONFIGURATION_TEMP_DIR)/spacenet-go-bridge

CFLAGS_PREFIX := $(if $(DEPLOYMENT_TARGET_CLANG_FLAG_NAME),-$(DEPLOYMENT_TARGET_CLANG_FLAG_NAME)=$($(DEPLOYMENT_TARGET_CLANG_ENV_NAME)),) -isysroot $(SDKROOT) -arch
GOARCH_arm64 := arm64
GOARCH_x86_64 := amd64
GOOS_macosx := darwin
GOOS_iphoneos := ios

build: $(DESTDIR)/libsn-go.a
version-header: $(DESTDIR)/spacenet-go-version.h

REAL_GOROOT := $(shell go env GOROOT 2>/dev/null)
export GOROOT := $(BUILDDIR)/goroot
$(GOROOT)/.prepared:
	[ -n "$(REAL_GOROOT)" ]
	mkdir -p "$(GOROOT)"
	rsync -a --delete --exclude=pkg/obj/go-build "$(REAL_GOROOT)/" "$(GOROOT)/"
	cat goruntime-*.diff | patch -p1 -f -N -r- -d "$(GOROOT)"
	touch "$@"

define libsn-go-a
$(BUILDDIR)/libsn-go-$(1).a: export CGO_ENABLED := 1
$(BUILDDIR)/libsn-go-$(1).a: export CGO_CFLAGS := $(CFLAGS_PREFIX) $(ARCH)
$(BUILDDIR)/libsn-go-$(1).a: export CGO_LDFLAGS := $(CFLAGS_PREFIX) $(ARCH)
$(BUILDDIR)/libsn-go-$(1).a: export GOOS := $(GOOS_$(PLATFORM_NAME))
$(BUILDDIR)/libsn-go-$(1).a: export GOARCH := $(GOARCH_$(1))
$(BUILDDIR)/libsn-go-$(1).a: $(GOROOT)/.prepared go.mod
	go build -ldflags=-w -trimpath -v -o "$(BUILDDIR)/libsn-go-$(1).a" -buildmode c-archive
	rm -f "$(BUILDDIR)/libsn-go-$(1).h"
endef
$(foreach ARCH,$(ARCHS),$(eval $(call libsn-go-a,$(ARCH))))

$(DESTDIR)/spacenet-go-version.h: go.mod $(GOROOT)/.prepared
	 sed -E -n 's/.*golang\.zx2c4\.com\/wireguard +v[0-9.]+-[0-9]+-([0-9a-f]{8})[0-9a-f]{4}.*/#define SPACENET_GO_VERSION "\1"/p' "$<" > "$@"

$(DESTDIR)/libsn-go.a: $(foreach ARCH,$(ARCHS),$(BUILDDIR)/libsn-go-$(ARCH).a)
	@mkdir -vp "$(DESTDIR)"
	$(LIPO) -create -output "$@" $^

clean:
	rm -rf "$(BUILDDIR)" "$(DESTDIR)/libsn-go.a" "$(DESTDIR)/spacenet-go-version.h"

install: build

.PHONY: clean build version-header install
