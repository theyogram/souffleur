DERIVED ?= build/DerivedData
.PHONY: gen build test install sign
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
