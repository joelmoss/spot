APP_NAME := Spot
BUNDLE_DIR := build/$(APP_NAME).app
DMG_PATH := build/$(APP_NAME).dmg

.PHONY: build run release app dmg test clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

build: ## Build debug binary
	swift build

run: build ## Build and run (debug)
	swift run $(APP_NAME)

test: ## Run tests
	swift test

release: ## Build release binary
	swift build -c release

app: release ## Build release app bundle
	rm -rf build
	mkdir -p "$(BUNDLE_DIR)/Contents/MacOS"
	mkdir -p "$(BUNDLE_DIR)/Contents/Resources"
	cp .build/release/$(APP_NAME) "$(BUNDLE_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(BUNDLE_DIR)/Contents/Info.plist"
	@echo "App bundle: $(BUNDLE_DIR)"

dmg: app ## Build release DMG
	rm -f "$(DMG_PATH)"
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(BUNDLE_DIR)" \
		-ov -format UDZO \
		"$(DMG_PATH)" \
		-quiet
	@echo "DMG: $(DMG_PATH)"

clean: ## Remove build artifacts
	swift package clean
	rm -rf build
