#!/bin/bash
# rebuild-and-relaunch.sh
#
# Single command that picks up Rust + Swift code changes in the running app.
# Solves the recurring "I made changes but nothing landed visually" problem:
# (a) the app mmap's its dylib at launch, so editing source + xcodebuild does
# NOT update an already-running process; (b) Spotlight / Dock / Launchpad
# typically resolve "Epistemos" to /Applications/Epistemos.app, NOT to the
# Xcode DerivedData build. If /Applications/Epistemos.app is stale (a manual
# `xcodebuild install` or an old copy from weeks ago), every Cmd-Space-Epistemos
# you do launches the stale app while the fresh build sits unused in
# DerivedData. This script forces the chain:
#
#   1. Rebuild static Rust libs (build-rust.sh)
#   2. xcodebuild build (relinks Epistemos.debug.dylib)
#   3. Kill any running Epistemos.app instance (mmap'd bytes are stale)
#   4. Sync the fresh DerivedData build over /Applications/Epistemos.app so
#      future Spotlight / Dock launches resolve to the new code.
#   5. Launch the freshly-built app
#
# Usage:
#   bash rebuild-and-relaunch.sh                # full Debug rebuild + relaunch
#   bash rebuild-and-relaunch.sh --no-launch    # rebuild + kill, no relaunch
#   bash rebuild-and-relaunch.sh --no-rust      # skip Rust step (Swift-only edits)
#   bash rebuild-and-relaunch.sh --no-sync      # skip /Applications sync
#   CONFIGURATION=Release bash rebuild-and-relaunch.sh

set -euo pipefail

cd "$(dirname "$0")"

CONFIGURATION="${CONFIGURATION:-Debug}"
SKIP_RUST=0
NO_LAUNCH=0
NO_SYNC=0
for arg in "$@"; do
    case "$arg" in
        --no-rust)   SKIP_RUST=1 ;;
        --no-launch) NO_LAUNCH=1 ;;
        --no-sync)   NO_SYNC=1 ;;
        --help|-h)
            sed -n '2,28p' "$0"
            exit 0
            ;;
        *)
            echo "[rebuild-and-relaunch] unknown arg: $arg" >&2
            exit 2
            ;;
    esac
done

DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl"
APP_BIN="$DERIVED_DATA/Build/Products/$CONFIGURATION/Epistemos.app/Contents/MacOS/Epistemos"
APP_DYLIB="$DERIVED_DATA/Build/Products/$CONFIGURATION/Epistemos.app/Contents/MacOS/Epistemos.debug.dylib"

echo "[rebuild-and-relaunch] configuration: $CONFIGURATION"

if [ "$SKIP_RUST" -eq 0 ]; then
    echo "[rebuild-and-relaunch] step 1/4: bash build-rust.sh"
    CONFIGURATION="$CONFIGURATION" bash ./build-rust.sh
else
    echo "[rebuild-and-relaunch] step 1/4: skipped (--no-rust)"
fi

echo "[rebuild-and-relaunch] step 2/4: xcodebuild build"
xcodebuild \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -configuration "$CONFIGURATION" \
    build \
    CODE_SIGNING_ALLOWED=NO \
    >/tmp/epistemos-rebuild.log 2>&1 || {
        echo "[rebuild-and-relaunch] xcodebuild failed — see /tmp/epistemos-rebuild.log:" >&2
        tail -40 /tmp/epistemos-rebuild.log >&2
        exit 1
    }
tail -3 /tmp/epistemos-rebuild.log | sed 's/^/[xcodebuild] /'

if [ ! -f "$APP_BIN" ]; then
    echo "[rebuild-and-relaunch] expected app binary not found at $APP_BIN" >&2
    exit 1
fi

echo "[rebuild-and-relaunch] step 3/5: kill running Epistemos instances"
# Match BOTH the DerivedData binary and the /Applications binary so we
# don't leave a stale-bytes process running on either path.
RUNNING_PIDS="$(pgrep -f '/Epistemos.app/Contents/MacOS/Epistemos' || true)"
RUNNING_PIDS="$(echo $RUNNING_PIDS | tr ' ' '\n' | sort -u | grep -v '^$' || true)"
if [ -n "$RUNNING_PIDS" ]; then
    for pid in $RUNNING_PIDS; do
        echo "[rebuild-and-relaunch]   sending SIGTERM to PID $pid"
        kill "$pid" 2>/dev/null || true
    done
    sleep 1
    for pid in $RUNNING_PIDS; do
        if kill -0 "$pid" 2>/dev/null; then
            echo "[rebuild-and-relaunch]   PID $pid still alive — sending SIGKILL"
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
else
    echo "[rebuild-and-relaunch]   no running Epistemos instance"
fi

FRESH_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/Epistemos.app"
APPLICATIONS_APP="/Applications/Epistemos.app"

# Step 4 — sync to /Applications. Spotlight / Dock / Launchpad resolve
# "Epistemos" to /Applications/Epistemos.app, not the DerivedData build.
# If that copy is stale, the user keeps launching old code no matter how
# many times xcodebuild succeeds. We replace it with the fresh build so
# every launch path lands on the same dylib bytes.
if [ "$NO_SYNC" -eq 0 ]; then
    if [ -d "$APPLICATIONS_APP" ]; then
        OLD_DYLIB_TS="$(stat -f '%Sm' "$APPLICATIONS_APP/Contents/MacOS/Epistemos.debug.dylib" 2>/dev/null || echo 'unknown')"
        FRESH_DYLIB_TS="$(stat -f '%Sm' "$FRESH_APP/Contents/MacOS/Epistemos.debug.dylib" 2>/dev/null || echo 'unknown')"
        echo "[rebuild-and-relaunch] step 4/5: sync to /Applications/Epistemos.app"
        echo "[rebuild-and-relaunch]   stale  /Applications dylib: $OLD_DYLIB_TS"
        echo "[rebuild-and-relaunch]   fresh  DerivedData  dylib: $FRESH_DYLIB_TS"
        # Use rsync rather than rm+cp so xattrs / hardlinks are preserved.
        # --delete strips files that no longer exist in the source.
        rsync -a --delete "$FRESH_APP/" "$APPLICATIONS_APP/" || {
            echo "[rebuild-and-relaunch] /Applications sync failed (permissions?). Continuing without sync." >&2
        }
    else
        echo "[rebuild-and-relaunch] step 4/5: no /Applications/Epistemos.app present — skipping sync"
    fi
else
    echo "[rebuild-and-relaunch] step 4/5: skipped (--no-sync)"
fi

if [ "$NO_LAUNCH" -eq 1 ]; then
    echo "[rebuild-and-relaunch] step 5/5: skipped (--no-launch)"
    DYLIB_TS="$(stat -f '%Sm' "$APP_DYLIB" 2>/dev/null || echo 'unknown')"
    echo "[rebuild-and-relaunch] fresh dylib ready: $DYLIB_TS"
    echo "[rebuild-and-relaunch] launch manually with: open '$FRESH_APP'"
    exit 0
fi

echo "[rebuild-and-relaunch] step 5/5: launch fresh Epistemos.app"
# Launch from /Applications when synced (matches what the user gets from
# Spotlight) so dock/Launchpad point at the same running instance.
if [ "$NO_SYNC" -eq 0 ] && [ -d "$APPLICATIONS_APP" ]; then
    open "$APPLICATIONS_APP"
else
    open "$FRESH_APP"
fi

sleep 1
NEW_PID="$(pgrep -f '/Epistemos.app/Contents/MacOS/Epistemos' | head -1 || true)"
if [ -n "$NEW_PID" ]; then
    NEW_START="$(ps -o lstart= -p "$NEW_PID" 2>/dev/null | xargs)"
    NEW_PATH="$(ps -o command= -p "$NEW_PID" 2>/dev/null | awk '{print $1}')"
    NEW_DYLIB_PATH="$(dirname "$NEW_PATH")/Epistemos.debug.dylib"
    NEW_DYLIB_TS="$(stat -f '%Sm' "$NEW_DYLIB_PATH" 2>/dev/null || echo 'unknown')"
    echo "[rebuild-and-relaunch] launched PID $NEW_PID at $NEW_START"
    echo "[rebuild-and-relaunch] running app:    $NEW_PATH"
    echo "[rebuild-and-relaunch] running dylib:  $NEW_DYLIB_PATH"
    echo "[rebuild-and-relaunch] dylib mtime:    $NEW_DYLIB_TS"
    echo "[rebuild-and-relaunch] DONE — new code is live."
else
    echo "[rebuild-and-relaunch] warning: launch issued but no Epistemos PID detected yet" >&2
fi
