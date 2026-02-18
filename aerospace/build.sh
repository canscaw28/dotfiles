#!/bin/bash
# Build a patched AeroSpace from source and install it.
#
# Applies the focus-guard patch (prevents Chrome's makeKeyAndOrderFront from
# triggering unwanted workspace switches) and builds a signed .app bundle.
#
# Prerequisites: Xcode (with command-line tools)
#
# Usage:
#   build-aerospace.sh                  # build + install
#   build-aerospace.sh --build-only     # build without installing
#   build-aerospace.sh --version v0.20.0-Beta  # pin to a specific tag
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/focus-guard.patch"
BUILD_DIR="/tmp/aerospace-build"
AEROSPACE_REPO="https://github.com/nikitabobko/AeroSpace.git"
DEFAULT_VERSION="v0.20.2-Beta"

# Parse args
VERSION="$DEFAULT_VERSION"
INSTALL=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --build-only) INSTALL=0; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

echo "==> Building AeroSpace $VERSION with focus-guard patch"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Clone at the target version (shallow for speed)
echo "==> Cloning AeroSpace $VERSION..."
git clone --depth 1 --branch "$VERSION" "$AEROSPACE_REPO" "$BUILD_DIR/AeroSpace"
cd "$BUILD_DIR/AeroSpace"

# Apply patch
echo "==> Applying focus-guard patch..."
git apply "$PATCH_FILE"

# Generate build files (skip docs — not needed for .app)
echo "==> Running generate.sh..."
./generate.sh --ignore-cmd-help --codesign-identity -

# Build the .app bundle via xcodebuild
echo "==> Building AeroSpace.app (this may take a few minutes)..."
xcodebuild build \
    -scheme AeroSpace \
    -destination "generic/platform=macOS" \
    -configuration Release \
    -derivedDataPath .xcode-build \
    -quiet 2>&1 || {
        echo "ERROR: xcodebuild failed. Re-run without -quiet for details:" >&2
        echo "  cd $BUILD_DIR/AeroSpace && xcodebuild build -scheme AeroSpace -destination 'generic/platform=macOS' -configuration Release -derivedDataPath .xcode-build" >&2
        exit 1
    }

APP_PATH=".xcode-build/Build/Products/Release/AeroSpace.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: Build failed — $APP_PATH not found" >&2
    exit 1
fi

# Build the CLI binary
echo "==> Building aerospace CLI..."
swift build -c release --product aerospace 2>&1 | tail -5
CLI_PATH=".build/release/aerospace"

# Ad-hoc codesign (no certificate needed)
echo "==> Signing..."
codesign -f -s - "$APP_PATH"
codesign -f -s - "$CLI_PATH"

if [[ "$INSTALL" -eq 0 ]]; then
    echo "==> Build complete (not installing)"
    echo "    App: $BUILD_DIR/AeroSpace/$APP_PATH"
    echo "    CLI: $BUILD_DIR/AeroSpace/$CLI_PATH"
    exit 0
fi

# Stop running AeroSpace
echo "==> Stopping AeroSpace..."
pkill -x AeroSpace 2>/dev/null || true
sleep 1

# Install
echo "==> Installing to /Applications/AeroSpace.app..."
rm -rf /Applications/AeroSpace.app
cp -r "$APP_PATH" /Applications/AeroSpace.app

echo "==> Installing CLI to ~/.local/bin/aerospace..."
mkdir -p ~/.local/bin
cp "$CLI_PATH" ~/.local/bin/aerospace

# Restart
echo "==> Starting AeroSpace..."
open /Applications/AeroSpace.app

echo "==> Done! AeroSpace $VERSION (patched) installed."
