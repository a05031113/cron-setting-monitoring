#!/bin/bash
set -e

APP_NAME="CronMonitor"
BUILD_DIR=".build/release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/"

echo "App bundle created at: ${APP_BUNDLE}"
echo ""
echo "To install: cp -r '${APP_BUNDLE}' /Applications/"
echo "To run:     open '${APP_BUNDLE}'"
