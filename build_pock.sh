#!/bin/bash
#
# build_pock.sh
# Builds Pock for Release, embeds frameworks, signs and zips for distribution
#

WORKSPACE="Pock.xcworkspace"
SCHEME="Pock"
CONFIGURATION="Release"

# Find the build output directory
BUILD_DIR=$(find ~/Library/Developer/Xcode/DerivedData/Pock-*/Build/Products/Release -maxdepth 0 2>/dev/null | head -1)

# Clean existing frameworks before build to avoid sandbox rsync conflicts
if [ -n "$BUILD_DIR" ] && [ -d "$BUILD_DIR/Pock.app/Contents/Frameworks" ]; then
    echo "🧹 Cleaning existing frameworks..."
    rm -rf "$BUILD_DIR/Pock.app/Contents/Frameworks"
fi

echo "🔨 Building Pock..."
xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"

# Re-find build dir after build
BUILD_DIR=$(find ~/Library/Developer/Xcode/DerivedData/Pock-*/Build/Products/Release -maxdepth 0 2>/dev/null | head -1)

if [ -z "$BUILD_DIR" ]; then
    echo "❌ Could not find build output directory"
    exit 1
fi

if [ ! -d "$BUILD_DIR/Pock.app" ]; then
    echo "❌ Build failed — Pock.app not found"
    exit 1
fi

APP="$BUILD_DIR/Pock.app"
FRAMEWORKS_DIR="$APP/Contents/Frameworks"
RESOURCES_DIR="$APP/Contents/Resources"

echo "📦 Embedding frameworks into $APP..."
mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Pods_Pock.framework
cp -Rf "$BUILD_DIR/Pods_Pock.framework" "$FRAMEWORKS_DIR/"

# Copy nested .framework bundles
for name in Magnet PockKit Sauce TinyConstraints Zip; do
    SRC="$BUILD_DIR/$name"
    if [ -d "$SRC" ]; then
        FRAMEWORK=$(find "$SRC" -name "*.framework" -maxdepth 1 | head -1)
        if [ -n "$FRAMEWORK" ]; then
            cp -Rf "$FRAMEWORK" "$FRAMEWORKS_DIR/"
            echo "  ✓ $name"
        else
            echo "  ⚠️  No .framework found in $SRC"
        fi
    fi
done

# Copy AppCenter resource bundles into app Resources
if [ -d "$BUILD_DIR/AppCenter" ]; then
    for bundle in "$BUILD_DIR/AppCenter/"*.bundle; do
        cp -Rf "$bundle" "$RESOURCES_DIR/"
        echo "  ✓ $(basename $bundle)"
    done
fi

echo "🔏 Signing app..."
codesign --force --deep --sign - "$APP"

echo "🗜  Zipping..."
OUTPUT="$HOME/Desktop/Pock.zip"
rm -f "$OUTPUT"
cd "$BUILD_DIR"
ditto -c -k --sequesterRsrc --keepParent Pock.app "$OUTPUT"

echo "✅ Done! Output: $OUTPUT"
