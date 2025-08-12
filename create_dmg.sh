#!/bin/bash

# Combined build and package script for KaTrain macOS app
# This script builds the app with PyInstaller and creates a DMG for distribution

set -e  # Exit on any error

echo "🚀 Building and Packaging KaTrain for macOS"

# ============================================================================
# STEP 1: BUILD APP WITH PYINSTALLER
# ============================================================================

echo ""
echo "📱 STEP 1: Building KaTrain App"
echo "================================"

# Get version from constants.py
VERSION=$(python3 -c "import sys; sys.path.append('katrain/core'); from constants import VERSION; print(VERSION)")
echo "📋 Detected version: $VERSION"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf dist build
find . -name "*.pyc" -delete
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Build with PyInstaller using the correct version
echo "🔨 Building app with PyInstaller..."
KATRAIN_VERSION="$VERSION" .venv/bin/pyinstaller spec/KaTrain.spec --clean --noconfirm --log-level WARN 2>/dev/null

# Verify the build
if [ -d "./dist/KaTrain.app" ]; then
    BUILT_VERSION=$(plutil -p ./dist/KaTrain.app/Contents/Info.plist | grep CFBundleShortVersionString | cut -d'"' -f4)
    echo "✅ App built successfully with version: $BUILT_VERSION"
    
    if [ "$BUILT_VERSION" = "$VERSION" ]; then
        echo "✅ Version matches source code"
    else
        echo "❌ Version mismatch! Source: $VERSION, Built: $BUILT_VERSION"
        exit 1
    fi
else
    echo "❌ Build failed - app not found"
    exit 1
fi

echo "🎉 App build completed successfully!"

# ============================================================================
# STEP 2: CREATE DMG PACKAGE
# ============================================================================

echo ""
echo "💿 STEP 2: Creating DMG Package"
echo "==============================="

# Configuration
APP_NAME="KaTrain"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="./dist"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_DIR="./dmg_temp"

echo "📦 Creating DMG for ${APP_NAME} v${VERSION}"

# Clean up any previous DMG files and temp directories
echo "🧹 Cleaning up previous DMG builds..."
rm -rf "${DMG_DIR}"
rm -f "${DMG_NAME}.dmg"

# Create temporary DMG directory
echo "📁 Creating temporary DMG directory..."
mkdir -p "${DMG_DIR}"

# Copy the app bundle to DMG directory
echo "📋 Copying ${APP_NAME}.app to DMG directory..."
cp -R "${APP_PATH}" "${DMG_DIR}/"

# Create symbolic link to Applications folder
echo "🔗 Creating link to Applications folder..."
ln -s /Applications "${DMG_DIR}/Applications"

# Create the DMG
echo "💿 Creating DMG file..."
if command -v create-dmg >/dev/null 2>&1; then
    # Use create-dmg if available (install with: brew install create-dmg)
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "./katrain/img/icon.icns" \
        --window-pos 200 120 \
        --window-size 800 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 200 190 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 600 185 \
        "${DMG_NAME}.dmg" \
        "${DMG_DIR}" 2>/dev/null || true
else
    # Fallback to hdiutil (built into macOS)
    echo "📦 Using hdiutil to create DMG..."
    hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_DIR}" -ov -format UDZO "${DMG_NAME}.dmg"
fi

# Clean up temp directory
echo "🧹 Cleaning up temporary files..."
rm -rf "${DMG_DIR}"

# ============================================================================
# FINAL VERIFICATION
# ============================================================================

echo ""
echo "🎯 FINAL VERIFICATION"
echo "===================="

# Verify DMG was created
if [ -f "${DMG_NAME}.dmg" ]; then
    FILE_SIZE=$(du -h "${DMG_NAME}.dmg" | cut -f1)
    echo "✅ DMG created successfully: ${DMG_NAME}.dmg (${FILE_SIZE})"
else
    echo "❌ Error: DMG creation failed"
    exit 1
fi

# Verify app version in DMG
echo "🔍 Verifying packaged app version..."
FINAL_VERSION=$(plutil -p "./dist/KaTrain.app/Contents/Info.plist" | grep CFBundleShortVersionString | cut -d'"' -f4)
echo "📋 Final packaged version: $FINAL_VERSION"

echo ""
echo "🎉 BUILD AND PACKAGE COMPLETED SUCCESSFULLY!"
echo "============================================="
echo "📱 App: ./dist/KaTrain.app"
echo "💿 DMG: ./${DMG_NAME}.dmg"
echo "🚀 Ready for distribution!"
