#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CC="$(xcrun --sdk iphoneos -f clang)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD" "$DIST"

COMMON=( -fobjc-arc -O2 -fblocks -isysroot "$SDK" -I"$ROOT/Tweak" -I"$ROOT/Vendor/Headers" \
  -F"$SDK/System/Library/PrivateFrameworks" \
  -Wno-deprecated-declarations -Wno-objc-property-implementation \
  -framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics -framework CoreFoundation \
  -framework EventKit -framework MediaPlayer -framework PhotosUI -framework Preferences \
  -Wl,-undefined,dynamic_lookup )
ENH_MACROS=( -DSOLPreferences=SOLEnhancementPreferences \
  -DSOLPreferenceDomain=SOLEnhancementPreferenceDomain \
  -DSOLReloadNotification=SOLEnhancementReloadNotification \
  -DSOLPreferencesDidReloadNotification=SOLEnhancementPreferencesDidReloadNotification )

build_arch() {
  local arch="$1"
  "$CC" "${COMMON[@]}" -target "${arch}-apple-ios15.0" -dynamiclib \
    -Wl,-install_name,@loader_path/Solo.dylib \
    "$ROOT/Tweak/SoloCore.m" "$ROOT/Tweak/SOLHome.m" "$ROOT/Tweak/SOLPreferences.m" "$ROOT/Tweak/SOLHookRuntime.m" "$ROOT/Tweak/SoloRecoveredClasses.m" \
    -o "$BUILD/Solo-${arch}.dylib"
  "$CC" "${COMMON[@]}" "${ENH_MACROS[@]}" -target "${arch}-apple-ios15.0" -dynamiclib \
    -Wl,-install_name,@loader_path/SoloEnhancements.dylib \
    "$ROOT/Tweak/SoloEnhancements.m" "$ROOT/Tweak/SOLActions.m" "$ROOT/Tweak/SOLActionsCatalog.m" "$ROOT/Tweak/SOLActionsRail.m" "$ROOT/Tweak/SOLPreferences.m" "$ROOT/Tweak/SOLHookRuntime.m" "$ROOT/Tweak/EnhancementsRecoveredClasses.m" \
    -o "$BUILD/SoloEnhancements-${arch}.dylib"
  "$CC" "${COMMON[@]}" -target "${arch}-apple-ios15.0" -bundle \
    "$ROOT/Prefs/SoloPrefs.m" -o "$BUILD/SoloPrefs-${arch}"
}

for arch in arm64 arm64e; do
  build_arch "$arch"
done

xcrun lipo -create -output "$BUILD/Solo.dylib" "$BUILD/Solo-arm64.dylib" "$BUILD/Solo-arm64e.dylib"
xcrun lipo -create -output "$BUILD/SoloEnhancements.dylib" "$BUILD/SoloEnhancements-arm64.dylib" "$BUILD/SoloEnhancements-arm64e.dylib"
xcrun lipo -create -output "$BUILD/SoloPrefs" "$BUILD/SoloPrefs-arm64" "$BUILD/SoloPrefs-arm64e"
for f in "$BUILD/Solo.dylib" "$BUILD/SoloEnhancements.dylib" "$BUILD/SoloPrefs"; do
  xcrun codesign --force --sign - --timestamp=none "$f"
done

python3 "$ROOT/tools/package.py" --root "$ROOT" --build "$BUILD" --output "$DIST/com.oakstheawesome.solo_1.0.1-14_iphoneos-arm64e.deb"
python3 "$ROOT/tools/verify_package.py" "$DIST/com.oakstheawesome.solo_1.0.1-14_iphoneos-arm64e.deb"
shasum -a 256 "$DIST/com.oakstheawesome.solo_1.0.1-14_iphoneos-arm64e.deb"
