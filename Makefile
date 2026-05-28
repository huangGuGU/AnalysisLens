APP_NAME := AnalysisLens
EXECUTABLE := AnalysisLens

BUILD_DIR := build
DIST_DIR := dist
CACHE_DIR := .build-cache

BUILD_APP := $(BUILD_DIR)/$(APP_NAME).app
DIST_APP := $(DIST_DIR)/$(APP_NAME).app
DMG_ROOT := $(BUILD_DIR)/dmg-root
DMG_FILE := $(DIST_DIR)/$(APP_NAME).dmg

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
ICON_SOURCE := swift/resources/AppIcon.png
DARK_ICON_SOURCE := swift/resources/AppIconDark.png
ICON_FILE := $(BUILD_DIR)/AppIcon.icns
DARK_ICON_FILE := $(BUILD_DIR)/AppIconDark.icns

.PHONY: all app swift dist dmg icon-from-png clean clean-cache run

all: app

app: swift

swift: $(BUILD_APP)/Contents/MacOS/$(EXECUTABLE)

dist: CONFIG = release
dist: app
	@rm -rf "$(DIST_DIR)"
	@mkdir -p "$(DIST_DIR)"
	@ditto "$(BUILD_APP)" "$(DIST_APP)"
	@xattr -cr "$(DIST_APP)"

dmg: CONFIG = release
dmg: dist
	@rm -rf "$(DMG_ROOT)"
	@mkdir -p "$(DMG_ROOT)"
	@ditto "$(DIST_APP)" "$(DMG_ROOT)/$(APP_NAME).app"
	@ln -s /Applications "$(DMG_ROOT)/Applications"
	@xattr -cr "$(DMG_ROOT)"
	@rm -f "$(DMG_FILE)"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(CURDIR)/$(DMG_ROOT)" -ov -format UDZO "$(CURDIR)/$(DMG_FILE)"
	@rm -rf "$(DMG_ROOT)"

$(ICON_FILE): $(ICON_SOURCE)
	$(MAKE) icon-from-png ICON_INPUT="$(ICON_SOURCE)" ICON_OUTPUT="$@"

$(DARK_ICON_FILE): $(DARK_ICON_SOURCE)
	$(MAKE) icon-from-png ICON_INPUT="$(DARK_ICON_SOURCE)" ICON_OUTPUT="$@"

icon-from-png:
	@rm -rf "$(ICON_OUTPUT).iconset"
	@mkdir -p "$(ICON_OUTPUT).iconset"
	sips -z 16 16 "$(ICON_INPUT)" --out "$(ICON_OUTPUT).iconset/icon_16x16.png"
	sips -z 32 32 "$(ICON_INPUT)" --out "$(ICON_OUTPUT).iconset/icon_16x16@2x.png"
	sips -z 32 32 "$(ICON_INPUT)" --out "$(ICON_OUTPUT).iconset/icon_32x32.png"
	sips -z 64 64 "$(ICON_INPUT)" --out "$(ICON_OUTPUT).iconset/icon_32x32@2x.png"
	sips -z 128 128 "$(ICON_INPUT)" --out "$(ICON_OUTPUT).iconset/icon_128x128.png"
	sips -z 256 256 "$(ICON_INPUT)" --out "$(ICON_OUTPUT).iconset/icon_128x128@2x.png"
	sips -z 256 256 "$(ICON_INPUT)" --out "$(ICON_OUTPUT).iconset/icon_256x256.png"
	sips -z 512 512 "$(ICON_INPUT)" --out "$(ICON_OUTPUT).iconset/icon_256x256@2x.png"
	sips -z 512 512 "$(ICON_INPUT)" --out "$(ICON_OUTPUT).iconset/icon_512x512.png"
	sips -z 1024 1024 "$(ICON_INPUT)" --out "$(ICON_OUTPUT).iconset/icon_512x512@2x.png"
	xattr -cr "$(ICON_OUTPUT).iconset"
	iconutil -c icns "$(ICON_OUTPUT).iconset" -o "$(ICON_OUTPUT)"
	xattr -cr "$(ICON_OUTPUT)"
	@rm -rf "$(ICON_OUTPUT).iconset"

$(BUILD_APP)/Contents/MacOS/$(EXECUTABLE): $(SWIFT_SOURCES) swift/resources/Info.plist $(ICON_FILE) $(DARK_ICON_FILE)
	@mkdir -p "$(BUILD_APP)/Contents/MacOS" "$(BUILD_APP)/Contents/Resources"
	@rm -f "$(BUILD_APP)"/Icon*
	$(SWIFTC) $(SWIFTFLAGS) $(SWIFT_SOURCES) -o "$@"
	@cp swift/resources/Info.plist "$(BUILD_APP)/Contents/Info.plist"
	@cp "$(ICON_FILE)" "$(BUILD_APP)/Contents/Resources/AppIcon.icns"
	@cp "$(DARK_ICON_FILE)" "$(BUILD_APP)/Contents/Resources/AppIconDark.icns"
	@printf "APPL????" > "$(BUILD_APP)/Contents/PkgInfo"
	@xattr -cr "$(BUILD_APP)"

run: swift
	open "$(BUILD_APP)"

clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"

clean-cache:
	rm -rf "$(CACHE_DIR)"
