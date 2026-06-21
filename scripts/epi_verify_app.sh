#!/bin/zsh
# Computer-use verifier (owner 2026-06-21: "I won't check manually"). Launches the latest built
# Epistemos.app, brings it front, screenshots to /tmp/epi_app_shot.png for the monitor to READ +
# visually verify. Launch-smoke (no crash) + visual check. Does NOT build (builds are coordinated
# with the loop separately to avoid concurrent xcodebuild). Usage: zsh scripts/epi_verify_app.sh
cd /Users/jojo/Downloads/Epistemos || exit 1
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/Epistemos-*/Build/Products/Debug/Epistemos.app 2>/dev/null | head -1)
[ -z "$APP" ] && { echo "no built app"; exit 2; }
open "$APP" 2>/dev/null; sleep 14
osascript -e 'tell application "Epistemos" to activate' 2>/dev/null
osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "Epistemos") to true' 2>/dev/null
sleep 3
crashed=$([ "$(pgrep -x Epistemos|wc -l|tr -d ' ')" -eq 0 ] && echo CRASHED-or-exited || echo running)
screencapture -x -t png /tmp/epi_app_shot.png 2>/dev/null
front=$(osascript -e 'tell application "System Events" to name of first process whose frontmost is true' 2>/dev/null)
echo "$(date '+%H:%M:%S') built=$(stat -f '%Sm' "$APP") proc=$crashed front=$front shot=/tmp/epi_app_shot.png" | tee -a /tmp/epi_verify.log
