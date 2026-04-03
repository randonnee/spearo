#!/bin/bash
set -e

APP_NAME="Spearo"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

echo "Building $APP_NAME in release mode..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "Sources/Spearo/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

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
