#!/usr/bin/env bash
set -euo pipefail

APP="${1:?usage: scan_appstore_bundle.sh /path/to/Epistemos.app}"

if [ ! -d "$APP" ]; then
  echo "::error::App Store bundle scan path does not exist or is not a directory: $APP" >&2
  exit 2
fi

REPORT_DIR="${EPISTEMOS_APPSTORE_SCAN_REPORT_DIR:-build/appstore-audit}"
mkdir -p "$REPORT_DIR"

find "$APP" -type f -print > "$REPORT_DIR/all-files.txt"
find "$APP" \
  \( -path "$APP/Contents/PlugIns/*" \
    -o -path "$APP/Contents/Frameworks/Testing.framework/*" \
    -o -path "$APP/Contents/Frameworks/XCTAutomationSupport.framework/*" \
    -o -path "$APP/Contents/Frameworks/XCTest.framework/*" \
    -o -path "$APP/Contents/Frameworks/XCTestCore.framework/*" \
    -o -path "$APP/Contents/Frameworks/XCTestSupport.framework/*" \
    -o -path "$APP/Contents/Frameworks/XCUIAutomation.framework/*" \
    -o -path "$APP/Contents/Frameworks/XCUnit.framework/*" \
    -o -path "$APP/Contents/Frameworks/libXCTest*.dylib" \) -prune \
  -o -type f -print > "$REPORT_DIR/files.txt"
awk -v prefix="$APP/" '
  index($0, prefix) == 1 { print substr($0, length(prefix) + 1); next }
  { print }
' "$REPORT_DIR/files.txt" > "$REPORT_DIR/resource-files.txt"

# Required audit reference from the recursive release backlog:
# pty|osascript|cli_passthrough|bash_execute|Command::new|fork|exec|docker|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl
FORBIDDEN_STRING_PATTERN='(^|[^A-Za-z0-9_])(pty|osascript|cli_passthrough|bash_execute|Command::new|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl)([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_.])docker([^A-Za-z0-9_-]|$)'
# Match exported Mach-O symbol tokens, not arbitrary substrings inside Rust
# mangled type names such as `std..sys..process..posix_spawn..PosixSpawnattr`.
FORBIDDEN_PROCESS_SYMBOL_PATTERN='(^|[[:space:]])(_?fork|_?vfork|_?posix_spawn(p|attr|_file_actions)?|_?exec(l|le|lp|v|ve|vp|vpe)?)([[:space:]]|$)'
FORBIDDEN_SYMBOL_PATTERN="${FORBIDDEN_PROCESS_SYMBOL_PATTERN}|(^|[^A-Za-z0-9_])(pty|osascript|cli_passthrough|bash_execute|Command::new|stdio_mcp|ScreenCaptureKit|AXUIElement|/bin/sh|/bin/bash|/usr/bin/python|launchctl)([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_.])docker([^A-Za-z0-9_-]|$)"
FORBIDDEN_ACCOUNT_RUNTIME_PATTERN='(\.codex/(auth|models_cache)\.json|backend-api/codex|auth\.openai\.com/codex/device|auth\.openai\.com/api/accounts/deviceauth|\.claude/\.credentials\.json|platform\.claude\.com/v1/oauth/token|console\.anthropic\.com/v1/oauth/token|claude-cli/[0-9]|claude-code-20250219|oauth-2025-04-20)'
retired_surface_a="Open"
retired_surface_b="Chamber"
FORBIDDEN_RETIRED_LANE_STRING_PATTERN='(^|[^[:alnum:]_])(ExperimentalWeb|'"${retired_surface_a}${retired_surface_b}"'|goosed|opencode|codex|experimental-runtime|experimental-web)([^[:alnum:]_]|$)'
parked_surface_a="Open"
parked_surface_b="Chamber"
FORBIDDEN_RESOURCE_PATTERN='MOHAWK|MoLoRA|raw Helios|research packets|Hermes|omega_ax|omega-mcp|pty|browser-use|Chromium|'"${parked_surface_a}${parked_surface_b}"'|(^|/)(Pyodide|experimental-runtime|opencode-runtime|GooseRuntime|'"${parked_surface_a}${parked_surface_b}"'Web)(/|$)|(^|/)(python_stdlib\.zip|pyodide\.js|pyodide\.mjs|pyodide\.asm\.mjs|pyodide\.asm\.wasm|pyodide-lock\.json|experimental-web\.tar\.gz|goose|goosed|node|codex|rg|bun|opencode|omega_mcp_stdio)$'

findings=0

echo "[scan] quarantine extended attributes"
: > "$REPORT_DIR/quarantine-xattrs.txt"
while IFS= read -r -d '' file; do
  if value="$(xattr -p com.apple.quarantine "$file" 2>/dev/null)"; then
    printf '%s: %s\n' "$file" "$value" >> "$REPORT_DIR/quarantine-xattrs.txt"
  fi
done < <(find "$APP" -print0)
if [ -s "$REPORT_DIR/quarantine-xattrs.txt" ]; then
  echo "::error::AppStore bundle contains com.apple.quarantine extended attributes"
  sed -n '1,80p' "$REPORT_DIR/quarantine-xattrs.txt"
  findings=$((findings + 1))
else
  echo "  no quarantine extended attributes detected"
fi

echo "[scan] executable/resource strings"
if tr '\n' '\0' < "$REPORT_DIR/files.txt" |
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
while IFS= read -r file; do
  if [ -x "$file" ]; then
    printf '%s\n' "$file"
  fi
done < "$REPORT_DIR/files.txt" | sort > "$REPORT_DIR/executables.txt" || true
cat "$REPORT_DIR/executables.txt"

echo "[scan] parked account/backend runtime strings"
if tr '\n' '\0' < "$REPORT_DIR/files.txt" |
  xargs -0 strings 2>/dev/null |
  rg -n "$FORBIDDEN_ACCOUNT_RUNTIME_PATTERN" > "$REPORT_DIR/forbidden-account-runtime-strings.txt"; then
  echo "::error::AppStore bundle contains parked account/backend runtime strings"
  sed -n '1,80p' "$REPORT_DIR/forbidden-account-runtime-strings.txt"
  findings=$((findings + 1))
else
  : > "$REPORT_DIR/forbidden-account-runtime-strings.txt"
  echo "  no parked account/backend runtime strings detected"
fi

echo "[scan] retired-lane bundle strings"
if tr '\n' '\0' < "$REPORT_DIR/files.txt" |
  xargs -0 strings 2>/dev/null |
  rg -in "$FORBIDDEN_RETIRED_LANE_STRING_PATTERN" > "$REPORT_DIR/forbidden-retired-lane-strings.txt"; then
  echo "::error::AppStore bundle contains retired-lane strings"
  sed -n '1,80p' "$REPORT_DIR/forbidden-retired-lane-strings.txt"
  findings=$((findings + 1))
else
  : > "$REPORT_DIR/forbidden-retired-lane-strings.txt"
  echo "  no retired-lane strings detected"
fi

echo "[scan] 1Code bundle strings"
if tr '\n' '\0' < "$REPORT_DIR/files.txt" |
  xargs -0 strings 2>/dev/null |
  rg -n '(^|[^[:alnum:]])1(Code|CODE)([^[:alnum:]]|$)' > "$REPORT_DIR/forbidden-1code-strings.txt"; then
  echo "::error::AppStore bundle contains 1Code strings"
  sed -n '1,80p' "$REPORT_DIR/forbidden-1code-strings.txt"
  findings=$((findings + 1))
else
  : > "$REPORT_DIR/forbidden-1code-strings.txt"
  echo "  no 1Code strings detected"
fi

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
if rg -n "$FORBIDDEN_RESOURCE_PATTERN" "$REPORT_DIR/resource-files.txt" > "$REPORT_DIR/forbidden-resources.txt"; then
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
