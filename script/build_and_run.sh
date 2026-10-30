#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---build-only}"
case "$MODE" in --build-only|--update-only|--test-host|--verify|--validate-game|run) ;; *) echo 'Usage: build_and_run.sh [--build-only|--update-only|--test-host|--verify|--validate-game|run]'; exit 2;; esac
BUILD="$(python3 - "$ROOT" "${DI2_TRAINER_BUILD_DIR:-$HOME/Library/Developer/DeadIsland2Trainer}" <<'PY'
from pathlib import Path
import sys
source,build=map(lambda p:Path(p).expanduser().resolve(),sys.argv[1:])
if source==build or source in build.parents: raise SystemExit('Build folder must be outside source.')
print(build)
PY
)"
APP="$BUILD/Dead Island 2 Trainer.app"
mkdir -p "$BUILD"
if [[ -d "$APP" ]]; then
    if [[ "$MODE" != --update-only ]] && { pgrep -x Trainer >/dev/null || pgrep -x DeadIsland2 >/dev/null || pgrep -x TrainerTestHost >/dev/null; }; then
        echo 'Bitte Trainer, Spiel und Testfenster vor einem Ersatzbuild regulär beenden.' >&2
        exit 1
    fi
    ID="$(plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist")"
    [[ "$ID" == local.deadisland2.trainer ]] || { echo 'Unerwartete App im Buildziel.' >&2; exit 1; }
fi
STAGE="$(mktemp -d "$BUILD/.stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
CANDIDATE="$STAGE/Dead Island 2 Trainer.app"
TEST="$STAGE/Trainer Test.app"
mkdir -p "$CANDIDATE/Contents/MacOS" "$CANDIDATE/Contents/Resources" "$TEST/Contents/MacOS"
FLAGS=(-arch arm64 -mmacosx-version-min=14.0 -fobjc-arc -O1 -Wall -Wextra -Werror "-ffile-prefix-map=$ROOT=." -I"$ROOT/Sources")
xcrun clang "${FLAGS[@]}" -dynamiclib -framework Carbon -framework AppKit -framework QuartzCore \
    "$ROOT/Sources/TrainerMaterial.m" "$ROOT/Sources/Overlay.m" "$ROOT/Sources/OverlaySettings.m" "$ROOT/Sources/OverlayShortcuts.m" "$ROOT/Sources/TrainerFeatures.m" "$ROOT/Sources/SelectionSettings.m" "$ROOT/Sources/GameBridge.m" "$ROOT/Sources/OverlayInput.m" "$ROOT/Sources/GameAccess.m" "$ROOT/Sources/GameEdition.m" "$ROOT/Sources/ExtraFeatures.m" "$ROOT/Sources/Runtime.m" -install_name @rpath/TrainerOverlay.dylib -o "$CANDIDATE/Contents/Resources/TrainerOverlay.dylib"
codesign --force --sign - --timestamp=none "$CANDIDATE/Contents/Resources/TrainerOverlay.dylib"
xcrun clang "${FLAGS[@]}" -framework Carbon -framework AppKit -framework Security -framework UniformTypeIdentifiers "$ROOT/Sources/Launcher.m" "$ROOT/Sources/LauncherView.m" "$ROOT/Sources/TrainerMaterial.m" "$ROOT/Sources/OverlayShortcuts.m" "$ROOT/Sources/TrainerFeatures.m" "$ROOT/Sources/SelectionSettings.m" "$ROOT/Sources/OverlaySettings.m" "$ROOT/Sources/GameEdition.m" -o "$CANDIDATE/Contents/MacOS/Trainer"
cp "$ROOT/Resources/Info.plist" "$CANDIDATE/Contents/Info.plist"
cp "$ROOT/LICENSE" "$CANDIDATE/Contents/Resources/LICENSE"
ICONSET="$STAGE/AppIcon.iconset"
mkdir -p "$ICONSET"
for spec in '16:icon_16x16' '32:icon_16x16@2x' '32:icon_32x32' '64:icon_32x32@2x' '128:icon_128x128' '256:icon_128x128@2x' '256:icon_256x256' '512:icon_256x256@2x' '512:icon_512x512' '1024:icon_512x512@2x'; do
    size="${spec%%:*}"
    sips --resampleHeightWidth "$size" "$size" -s format png "$ROOT/Resources/AppIcon.png" --out "$ICONSET/${spec#*:}.png" >/dev/null
done
iconutil --convert icns "$ICONSET" --output "$CANDIDATE/Contents/Resources/AppIcon.icns"
codesign --force --sign - --options runtime --timestamp=none "$CANDIDATE"
codesign --verify --deep --strict "$CANDIDATE"
xcrun clang "${FLAGS[@]}" -framework Carbon -framework AppKit -framework QuartzCore \
    "$ROOT/Tests/LauncherViewTests.m" "$ROOT/Sources/LauncherView.m" "$ROOT/Sources/TrainerMaterial.m" "$ROOT/Sources/OverlayShortcuts.m" "$ROOT/Sources/TrainerFeatures.m" "$ROOT/Sources/SelectionSettings.m" "$ROOT/Sources/GameEdition.m" -o "$STAGE/LauncherViewTests"
"$STAGE/LauncherViewTests" "$STAGE/LauncherPreview.png" "$CANDIDATE/Contents/Resources/AppIcon.icns"
xcrun clang "${FLAGS[@]}" -framework Carbon -framework AppKit \
    "$ROOT/Tests/HotkeyTests.m" "$ROOT/Sources/OverlayShortcuts.m" "$ROOT/Sources/TrainerFeatures.m" "$ROOT/Sources/SelectionSettings.m" -o "$STAGE/HotkeyTests"
"$STAGE/HotkeyTests"
xcrun clang "${FLAGS[@]}" -framework Carbon -framework AppKit -framework Metal -framework QuartzCore \
    "$ROOT/Tests/MetalHost.m" "$ROOT/Tests/PresentationTests.m" "$ROOT/Sources/TrainerMaterial.m" "$ROOT/Sources/Overlay.m" "$ROOT/Sources/OverlaySettings.m" "$ROOT/Sources/OverlayShortcuts.m" "$ROOT/Sources/TrainerFeatures.m" "$ROOT/Sources/SelectionSettings.m" "$ROOT/Sources/GameBridge.m" "$ROOT/Sources/OverlayInput.m" "$ROOT/Sources/GameAccess.m" "$ROOT/Sources/GameEdition.m" "$ROOT/Sources/ExtraFeatures.m" -o "$TEST/Contents/MacOS/TrainerTestHost"
python3 - "$TEST/Contents/Info.plist" "$ROOT/Resources/Info.plist" <<'PY'
import plistlib,sys
from pathlib import Path
version=plistlib.loads(Path(sys.argv[2]).read_bytes())['CFBundleShortVersionString']
Path(sys.argv[1]).write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.deadisland2.trainer-test','CFBundleExecutable':'TrainerTestHost','CFBundleName':'Trainer Overlay Metal-Test','CFBundlePackageType':'APPL','CFBundleShortVersionString':version,'LSMinimumSystemVersion':'14.0','NSPrincipalClass':'NSApplication','NSHighResolutionCapable':True}))
PY
xcrun clang "${FLAGS[@]}" -DDI2_OVERLAY_TEST=1 -dynamiclib -framework Carbon -framework AppKit -framework QuartzCore \
    "$ROOT/Sources/TrainerMaterial.m" "$ROOT/Sources/Overlay.m" "$ROOT/Sources/OverlaySettings.m" "$ROOT/Sources/OverlayShortcuts.m" "$ROOT/Sources/TrainerFeatures.m" "$ROOT/Sources/SelectionSettings.m" "$ROOT/Sources/GameBridge.m" "$ROOT/Sources/OverlayInput.m" "$ROOT/Sources/GameAccess.m" "$ROOT/Sources/GameEdition.m" "$ROOT/Sources/ExtraFeatures.m" "$ROOT/Sources/Runtime.m" -install_name @rpath/TestOverlay.dylib -o "$STAGE/TestOverlay.dylib"
codesign --force --sign - --timestamp=none "$STAGE/TestOverlay.dylib"
codesign --force --sign - --timestamp=none "$TEST"
"$TEST/Contents/MacOS/TrainerTestHost" --unit-test
xcrun clang "${FLAGS[@]}" -DDI2_TRAINER_TESTING=1 -framework Foundation \
    "$ROOT/Tests/GameBridgeTests.m" "$ROOT/Tests/SelectionSettingsTests.m" "$ROOT/Tests/ExtraFeaturesTests.m" "$ROOT/Tests/OverlayInputTests.m" "$ROOT/Sources/TrainerFeatures.m" "$ROOT/Sources/SelectionSettings.m" "$ROOT/Sources/GameBridge.m" "$ROOT/Sources/OverlayInput.m" "$ROOT/Sources/GameAccess.m" "$ROOT/Sources/GameEdition.m" "$ROOT/Sources/ExtraFeatures.m" -o "$STAGE/GameBridgeTests"
"$STAGE/GameBridgeTests"
xcrun clang "${FLAGS[@]}" -framework Foundation "$ROOT/Tests/GameEditionTests.m" "$ROOT/Sources/GameEdition.m" -o "$STAGE/GameEditionTests"
"$STAGE/GameEditionTests"
python3 "$ROOT/Tests/verify_game_abi.py" "$ROOT"
"$TEST/Contents/MacOS/TrainerTestHost" --preview "$STAGE/OverlayPreview.png"
if [[ "$MODE" == --validate-game ]]; then "$CANDIDATE/Contents/MacOS/Trainer" --validate-only; fi
python3 - "$CANDIDATE" "$APP" "$STAGE/previous.app" <<'PY'
from pathlib import Path
import os,sys,shutil
candidate,target,previous=map(Path,sys.argv[1:])
if target.exists(): os.rename(target,previous)
try: os.rename(candidate,target)
except BaseException:
 if previous.exists(): os.rename(previous,target)
 raise
if previous.exists(): shutil.rmtree(previous)
PY
mv "$STAGE/OverlayPreview.png" "$BUILD/OverlayPreview.png"
mv "$STAGE/LauncherPreview.png" "$BUILD/LauncherPreview.png"
printf 'Build und Tests erfolgreich: %s\n' "$APP"
if [[ "$MODE" == --update-only ]]; then
    echo 'Nur die externe App wurde atomar ersetzt. Laufende Prozesse behalten ihren bereits geladenen Code; die neue Version wirkt nach einem regulären Neustart.'
fi
if [[ "$MODE" == --test-host ]]; then
    mkdir -p "$BUILD/Tests"
    rm -rf "$BUILD/Tests/Trainer Test.app"
    mv "$TEST" "$BUILD/Tests/Trainer Test.app"
    mv "$STAGE/TestOverlay.dylib" "$BUILD/Tests/TestOverlay.dylib"
    open -n --env "DYLD_INSERT_LIBRARIES=$BUILD/Tests/TestOverlay.dylib" "$BUILD/Tests/Trainer Test.app"
elif [[ "$MODE" == --verify || "$MODE" == run ]]; then
    open -n "$APP"
    if [[ "$MODE" == --verify ]]; then sleep 2; pgrep -x Trainer >/dev/null; fi
fi
