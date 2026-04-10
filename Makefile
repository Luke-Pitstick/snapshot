# Snapshot — build and bundle as a macOS .app
#
# Targets:
#   make             # debug build (swift build)
#   make release     # release build
#   make app         # bundle Snapshot.app into ./build/
#   make run         # bundle and launch from ./build/
#   make install     # replace /Applications/Snapshot.app in place
#   make reset-tcc   # clear the stale Screen Recording grant (use after signing-id changes)
#   make clean       # remove build artifacts
#
# Signing:
#   By default, `make app` ad-hoc signs with a stable --identifier (the
#   bundle id). That keeps the designated-requirement consistent across
#   rebuilds more reliably than plain `codesign --sign -`.
#
#   For a truly stable TCC grant across rebuilds, create a self-signed
#   "Code Signing" certificate in Keychain Access, then:
#     export SIGN_IDENTITY="My Snapshot Cert"
#     make app

APP_NAME      := Snapshot
BUNDLE_ID     := com.lukepitstick.snapshot
BUILD_DIR     := build
APP_BUNDLE    := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS      := $(APP_BUNDLE)/Contents
MACOS_DIR     := $(CONTENTS)/MacOS
RESOURCES_DIR := $(CONTENTS)/Resources
INFO_PLIST    := Sources/Snapshot/Resources/Info.plist
INSTALL_PATH  := /Applications/$(APP_NAME).app

# Override with: make app SIGN_IDENTITY="My Cert Name"
SIGN_IDENTITY ?= -

.PHONY: all debug release app run install reset-tcc clean

all: debug

debug:
	swift build

release:
	swift build -c release

app: release
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	@cp .build/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@cp $(INFO_PLIST) $(CONTENTS)/Info.plist
	@codesign --force --deep \
		--identifier $(BUNDLE_ID) \
		--sign "$(SIGN_IDENTITY)" \
		$(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)  (signed by: $(SIGN_IDENTITY))"

run: app
	open $(APP_BUNDLE)

install: app
	@echo "Quitting any running Snapshot…"
	@osascript -e 'tell application "$(APP_NAME)" to quit' 2>/dev/null || true
	@killall $(APP_NAME) 2>/dev/null || true
	@rm -rf $(INSTALL_PATH)
	@cp -R $(APP_BUNDLE) $(INSTALL_PATH)
	@echo "Installed to $(INSTALL_PATH)"
	@open $(INSTALL_PATH)

reset-tcc:
	@echo "Clearing Screen Recording grant for $(BUNDLE_ID)…"
	@tccutil reset ScreenCapture $(BUNDLE_ID) || true
	@echo "Done. Re-approve on next launch."

clean:
	swift package clean
	rm -rf .build $(BUILD_DIR)
