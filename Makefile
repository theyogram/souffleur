DERIVED ?= build/DerivedData
.PHONY: gen build test install sign dmg
gen:
	xcodegen generate --quiet
build: gen
	xcodebuild -project Souffleur.xcodeproj -scheme Souffleur -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath $(DERIVED) build -quiet
test: gen
	xcodebuild -project Souffleur.xcodeproj -scheme Souffleur -destination 'platform=macOS,arch=arm64' -derivedDataPath $(DERIVED) test -quiet
install: gen
	xcodebuild -project Souffleur.xcodeproj -scheme Souffleur -configuration Release -derivedDataPath build/Release build -quiet
	rm -rf /Applications/Souffleur.app && cp -R build/Release/Build/Products/Release/Souffleur.app /Applications/
	@$(MAKE) --no-print-directory sign

# Signature stable (certificat local auto-signé) : macOS conserve ainsi les autorisations
# micro et reconnaissance vocale d'une compilation à l'autre. Sans trousseau, on reste en ad hoc.
SIGN_KEYCHAIN := $(CURDIR)/signing/souffleur-signing.keychain-db
sign:
	@if [ -f "$(SIGN_KEYCHAIN)" ]; then \
		security unlock-keychain -p "$$(cat signing/keychain-password)" "$(SIGN_KEYCHAIN)" && \
		codesign --force --deep --sign "Souffleur Local Signing" --keychain "$(SIGN_KEYCHAIN)" /Applications/Souffleur.app && \
		echo "Signé avec le certificat local."; \
	else echo "Pas de trousseau de signature : signature ad hoc conservée."; fi

# DMG distribuable : build/dist/Souffleur-<version>.dmg (app + raccourci Applications).
dmg: gen
	xcodebuild -project Souffleur.xcodeproj -scheme Souffleur -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath build/Release build -quiet
	rm -rf build/dist && mkdir -p build/dist/stage
	cp -R build/Release/Build/Products/Release/Souffleur.app build/dist/stage/
	@if [ -f "$(SIGN_KEYCHAIN)" ]; then \
		security unlock-keychain -p "$$(cat signing/keychain-password)" "$(SIGN_KEYCHAIN)" && \
		codesign --force --deep --sign "Souffleur Local Signing" --keychain "$(SIGN_KEYCHAIN)" build/dist/stage/Souffleur.app; fi
	ln -s /Applications build/dist/stage/Applications
	V=$$(defaults read "$(CURDIR)/build/dist/stage/Souffleur.app/Contents/Info" CFBundleShortVersionString) && \
		hdiutil create -volname "Souffleur $$V" -srcfolder build/dist/stage -ov -format UDZO "build/dist/Souffleur-$$V.dmg" -quiet
	rm -rf build/dist/stage
	@ls -lh build/dist/*.dmg
