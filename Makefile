APP_NAME := AnalysisLens
EXECUTABLE := AnalysisLens

BUILD_DIR := build
DIST_DIR := dist
CACHE_DIR := .build-cache

BUILD_APP := $(BUILD_DIR)/$(APP_NAME).app
DIST_APP := $(DIST_DIR)/$(APP_NAME).app

SWIFTC := swiftc

SDKROOT_IN := $(SDKROOT)
FALLBACK_SDKROOT := /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
PREFERRED_SDKROOT := /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
SDKROOT := $(if $(wildcard $(SDKROOT_IN)),$(SDKROOT_IN),$(if $(wildcard $(PREFERRED_SDKROOT)),$(PREFERRED_SDKROOT),$(FALLBACK_SDKROOT)))

ARCH := arm64
MACOSX_DEPLOYMENT_TARGET ?= 12.0
SWIFT_TARGET := $(ARCH)-apple-macosx$(MACOSX_DEPLOYMENT_TARGET)
SWIFT_MODULE_CACHE_DIR := $(CACHE_DIR)/module-cache
CONFIG ?= debug
SWIFT_OPTIMIZATION := $(if $(filter release,$(CONFIG)),-O,-Onone)
SWIFTFLAGS := -target $(SWIFT_TARGET) -sdk "$(SDKROOT)" -module-cache-path "$(SWIFT_MODULE_CACHE_DIR)" -enable-incremental-imports -enable-incremental-file-hashing $(SWIFT_OPTIMIZATION)

SWIFT_SOURCES := swift/src/LensAnalyzer.swift swift/src/AnalysisLensApp.swift

.PHONY: all app swift dist clean clean-cache run

all: app

app: swift

swift: $(BUILD_APP)/Contents/MacOS/$(EXECUTABLE)

dist: CONFIG = release
dist: app
	@rm -rf "$(DIST_DIR)"
	@mkdir -p "$(DIST_DIR)"
	@ditto "$(BUILD_APP)" "$(DIST_APP)"

$(BUILD_APP)/Contents/MacOS/$(EXECUTABLE): $(SWIFT_SOURCES) swift/resources/Info.plist
	@mkdir -p "$(BUILD_APP)/Contents/MacOS" "$(BUILD_APP)/Contents/Resources"
	$(SWIFTC) $(SWIFTFLAGS) $(SWIFT_SOURCES) -o "$@"
	@cp swift/resources/Info.plist "$(BUILD_APP)/Contents/Info.plist"

run: swift
	open "$(BUILD_APP)"

clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"

clean-cache:
	rm -rf "$(CACHE_DIR)"
