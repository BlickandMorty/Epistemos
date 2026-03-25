#!/bin/bash
# Capture Epistemos logs to .claude/logs/ for debugging.
# Usage: bash .claude/capture-logs.sh
# Runs in background, writes to timestamped file.

LOGDIR="$(dirname "$0")/logs"
mkdir -p "$LOGDIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOGFILE="$LOGDIR/epistemos-$TIMESTAMP.log"

echo "Capturing Epistemos logs to: $LOGFILE"
echo "Press Ctrl+C to stop."

log stream \
    --predicate 'process == "Epistemos"' \
    --level debug \
    --style compact \
    > "$LOGFILE" 2>&1
