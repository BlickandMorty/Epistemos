#!/usr/bin/env bash
set -euo pipefail

APP="${1:?usage: scan_appstore_bundle.sh /path/to/Epistemos.app}"

if [ ! -d "$APP" ]; then
  echo "::error::App Store bundle scan path does not exist or is not a directory: $APP" >&2
  exit 2
fi

REPORT_DIR="${EPISTEMOS_APPSTORE_SCAN_REPORT_DIR:-build/appstore-audit}"
mkdir -p "$REPORT_DIR"

find "$APP" -type f -print > "$REPORT_DIR/files.txt"

# Required audit reference from the recursive release backlog:
# pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl
FORBIDDEN_STRING_PATTERN='(^|[^A-Za-z0-9_])(pty|osascript|cli_passthrough|bash_execute|Command::new|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl)([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_.])docker([^A-Za-z0-9_-]|$)'
FORBIDDEN_SYMBOL_PATTERN='(^|[^A-Za-z0-9_])(_?fork|_?vfork|_?posix_spawn|_?exec(l|le|lp|v|ve|vp|vpe)?)([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])(pty|osascript|cli_passthrough|bash_execute|Command::new|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl)([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_.])docker([^A-Za-z0-9_-]|$)'
FORBIDDEN_RESOURCE_PATTERN='MOHAWK|MoLoRA|raw Helios|research packets|Hermes|omega_ax|omega-mcp|pty'

findings=0

echo "[scan] executable/resource strings"
if find "$APP" -type f -print0 |
  xargs -0 strings 2>/dev/null |
  rg -n "$FORBIDDEN_STRING_PATTERN" > "$REPORT_DIR/forbidden-strings.txt"; then
  echo "::error::AppStore bundle contains prohibited/pro-only runtime strings"
  sed -n '1,80p' "$REPORT_DIR/forbidden-strings.txt"
  findings=$((findings + 1))
else
  : > "$REPORT_DIR/forbidden-strings.txt"
  echo "  no prohibited runtime strings detected"
fi

echo "[scan] possible executable files"
find "$APP" -type f -perm +111 -print | sort > "$REPORT_DIR/executables.txt" || true
cat "$REPORT_DIR/executables.txt"

echo "[scan] dylib/executable linkage"
: > "$REPORT_DIR/otool-L.txt"
: > "$REPORT_DIR/nm-gU.txt"
while IFS= read -r file; do
  if file "$file" | grep -q 'Mach-O'; then
    {
      echo "===== $file"
      otool -L "$file" 2>/dev/null || true
    } >> "$REPORT_DIR/otool-L.txt"
    {
      echo "===== $file"
      nm -gU "$file" 2>/dev/null || true
    } >> "$REPORT_DIR/nm-gU.txt"
  fi
done < "$REPORT_DIR/files.txt"

if rg -n "$FORBIDDEN_SYMBOL_PATTERN" "$REPORT_DIR/otool-L.txt" "$REPORT_DIR/nm-gU.txt" > "$REPORT_DIR/forbidden-symbols.txt"; then
  echo "::error::AppStore bundle contains prohibited/pro-only runtime symbols or linked names"
  sed -n '1,80p' "$REPORT_DIR/forbidden-symbols.txt"
  findings=$((findings + 1))
else
  : > "$REPORT_DIR/forbidden-symbols.txt"
  echo "  no prohibited runtime symbols detected"
fi

echo "[scan] resource names and packaged research/tool residue"
if find "$APP" -type f -print |
  rg -n "$FORBIDDEN_RESOURCE_PATTERN" > "$REPORT_DIR/forbidden-resources.txt"; then
  echo "::error::AppStore bundle contains prohibited/pro-only research/tool resources"
  sed -n '1,80p' "$REPORT_DIR/forbidden-resources.txt"
  findings=$((findings + 1))
else
  : > "$REPORT_DIR/forbidden-resources.txt"
  echo "  no prohibited research/tool resource residue detected"
fi

echo "[scan] reports written to $REPORT_DIR"
if [ "$findings" -gt 0 ]; then
  echo "::error::AppStore bundle artifact scan FAILED with $findings finding(s)"
  exit 1
fi

echo "[scan] complete"
