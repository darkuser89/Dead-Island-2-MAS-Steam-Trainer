#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---build-only}"
case "$MODE" in --build-only|--test-host|--verify|--validate-game|run) ;; *) echo 'Usage: build_and_run.sh [--build-only|--test-host|--verify|--validate-game|run]'; exit 2;; esac
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
    if pgrep -x Trainer >/dev/null || pgrep -x DeadIsland2 >/dev/null || pgrep -x TrainerTestHost >/dev/null; then
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
FLAGS=(-arch arm64 -mmacosx-version-min=14.0 -fobjc-arc -O1 -Wall -Wextra -Werror -I"$ROOT/Sources")
xcrun clang "${FLAGS[@]}" -dynamiclib -framework AppKit -framework QuartzCore \
    "$ROOT/Sources/Overlay.m" "$ROOT/Sources/Runtime.m" -o "$CANDIDATE/Contents/Resources/TrainerOverlay.dylib"
codesign --force --sign - --timestamp=none "$CANDIDATE/Contents/Resources/TrainerOverlay.dylib"
xcrun clang "${FLAGS[@]}" -framework AppKit -framework Security "$ROOT/Sources/Launcher.m" -o "$CANDIDATE/Contents/MacOS/Trainer"
cp "$ROOT/Resources/Info.plist" "$CANDIDATE/Contents/Info.plist"
cp "$ROOT/LICENSE" "$CANDIDATE/Contents/Resources/LICENSE"
codesign --force --sign - --options runtime --timestamp=none "$CANDIDATE"
codesign --verify --deep --strict "$CANDIDATE"
xcrun clang "${FLAGS[@]}" -framework AppKit -framework Metal -framework QuartzCore \
    "$ROOT/Tests/MetalHost.m" "$ROOT/Sources/Overlay.m" -o "$TEST/Contents/MacOS/TrainerTestHost"
python3 - "$TEST/Contents/Info.plist" <<'PY'
import plistlib,sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.deadisland2.trainer-test','CFBundleExecutable':'TrainerTestHost','CFBundleName':'Trainer Overlay Metal-Test','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.0','LSMinimumSystemVersion':'14.0','NSPrincipalClass':'NSApplication','NSHighResolutionCapable':True}))
PY
xcrun clang "${FLAGS[@]}" -DDI2_OVERLAY_TEST=1 -dynamiclib -framework AppKit -framework QuartzCore \
    "$ROOT/Sources/Overlay.m" "$ROOT/Sources/Runtime.m" -o "$STAGE/TestOverlay.dylib"
codesign --force --sign - --timestamp=none "$STAGE/TestOverlay.dylib"
codesign --force --sign - --timestamp=none "$TEST"
"$TEST/Contents/MacOS/TrainerTestHost" --unit-test
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
printf 'Build und Tests erfolgreich: %s\n' "$APP"
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
