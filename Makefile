DERIVED ?= build/DerivedData
.PHONY: gen build test install
gen:
	xcodegen generate --quiet
build: gen
	xcodebuild -project Souffleur.xcodeproj -scheme Souffleur -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath $(DERIVED) build -quiet
test: gen
	xcodebuild -project Souffleur.xcodeproj -scheme Souffleur -destination 'platform=macOS,arch=arm64' -derivedDataPath $(DERIVED) test -quiet
install: gen
	xcodebuild -project Souffleur.xcodeproj -scheme Souffleur -configuration Release -derivedDataPath build/Release build -quiet
	rm -rf /Applications/Souffleur.app && cp -R build/Release/Build/Products/Release/Souffleur.app /Applications/
