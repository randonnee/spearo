#!/bin/bash
set -e

APP_NAME="Spearo"
APP_BUNDLE="$APP_NAME.app"
RESOURCE_BUNDLE="${APP_NAME}_${APP_NAME}.bundle"

echo "Building $APP_NAME in release mode..."
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "Sources/Spearo/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy app icon
cp "Sources/Spearo/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Bundle.module requires the SwiftPM resource bundle at runtime.
cp -R "$BUILD_DIR/$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE"

echo "Signing app bundle for local use..."
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "Build complete: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "IMPORTANT: Grant Accessibility permissions in:"
echo "  System Settings > Privacy & Security > Accessibility"
