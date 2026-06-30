#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: package-browser-use-pro.sh [--repo-root PATH] [--build-root PATH] [--output-root PATH]
                                  [--sign-identity IDENTITY] [--skip-build]

Creates a signed BrowserUsePro.bundle for the direct-distribution Pro build.
The bundle contains:
  - vendored browser-use 0.13.2, web-ui, and cdp-use source
  - staged wheelhouse, requirements.lock, BUILD_MANIFEST.json, and Playwright Chromium
  - the Python 3.11 venv plus an embedded relocatable Python runtime
  - SIGNATURE_MANIFEST.json package evidence

By default the script uses ad-hoc signing ("-") so local proof is possible.
Set --sign-identity "Developer ID Application: ..." for release packaging.
USAGE
}

repo_root=""
build_root=""
output_root=""
sign_identity="${EPISTEMOS_BROWSER_USE_PRO_SIGN_IDENTITY:--}"
skip_build=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="${2:?missing --repo-root value}"
      shift 2
      ;;
    --build-root)
      build_root="${2:?missing --build-root value}"
      shift 2
      ;;
    --output-root)
      output_root="${2:?missing --output-root value}"
      shift 2
      ;;
    --sign-identity)
      sign_identity="${2:?missing --sign-identity value}"
      shift 2
      ;;
    --skip-build)
      skip_build=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$repo_root" ]]; then
  repo_root="$(cd -- "$script_dir/.." && pwd)"
else
  repo_root="$(cd -- "$repo_root" && pwd)"
fi

if [[ -z "$build_root" ]]; then
  build_root="$repo_root/build/browser-use-pro"
else
  mkdir -p "$build_root"
  build_root="$(cd -- "$build_root" && pwd)"
fi

if [[ -z "$output_root" ]]; then
  output_root="$build_root"
else
  mkdir -p "$output_root"
  output_root="$(cd -- "$output_root" && pwd)"
fi

vendor_root="$repo_root/agent_core/vendor/browser-use"
venv_dir="$build_root/.venv"
venv_python="$venv_dir/bin/python"
bundle_dir="$output_root/BrowserUsePro.bundle"
payload_root="$bundle_dir/Contents/Resources/BrowserUsePro"
info_plist="$bundle_dir/Contents/Info.plist"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool not found: $1" >&2
    exit 69
  fi
}

require_tool rsync
require_tool python3
require_tool codesign
require_tool file

remove_python_bytecode() {
  find "$payload_root" -type d -name '__pycache__' -prune -exec rm -rf {} +
  find "$payload_root" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
}

if [[ "$skip_build" -eq 0 && ! -x "$venv_python" ]]; then
  "$vendor_root/build-pro-payload.sh" --repo-root "$repo_root" --build-root "$build_root"
fi

for required in \
  "$vendor_root/VENDOR_MANIFEST.json" \
  "$vendor_root/BUILD_MANIFEST.json" \
  "$vendor_root/requirements.lock" \
  "$vendor_root/web-ui/webui.py" \
  "$vendor_root/wheels" \
  "$vendor_root/playwright" \
  "$venv_python"; do
  if [[ ! -e "$required" ]]; then
    echo "Missing browser-use Pro packaging input: $required" >&2
    exit 66
  fi
done

real_python="$(python3 - <<'PY' "$venv_python"
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
)"
python_root="$(cd -- "$(dirname -- "$real_python")/.." && pwd)"
if [[ ! -x "$python_root/bin/python3.11" ]]; then
  echo "Could not resolve embedded Python root from $venv_python" >&2
  exit 66
fi

rm -rf "$bundle_dir"
mkdir -p "$payload_root" "$bundle_dir/Contents/Resources"

rsync -a --delete \
  --exclude='.git/' \
  --exclude='__pycache__/' \
  "$vendor_root/" "$payload_root/"

for adapter_file in \
  "$payload_root/epistemos_agent_browser.py" \
  "$payload_root/epistemos_browser_env.py" \
  "$payload_root/epistemos_browser_task.py"; do
  if [[ ! -f "$adapter_file" ]]; then
    echo "Missing browser-use Pro adapter file: $adapter_file" >&2
    exit 66
  fi
done
chmod 755 "$payload_root/epistemos_agent_browser.py"
chmod 644 "$payload_root/epistemos_browser_env.py" "$payload_root/epistemos_browser_task.py"

rsync -a --delete \
  --exclude='__pycache__/' \
  "$venv_dir/" "$payload_root/.venv/"

rsync -a --delete "$python_root/" "$payload_root/.python/"

rm -f "$payload_root/.venv/bin/python" "$payload_root/.venv/bin/python3" "$payload_root/.venv/bin/python3.11"
ln -s "../../.python/bin/python3.11" "$payload_root/.venv/bin/python"
ln -s "python" "$payload_root/.venv/bin/python3"
ln -s "python" "$payload_root/.venv/bin/python3.11"

python3 - <<'PY' "$payload_root/.venv/pyvenv.cfg"
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
rewritten = []
did_home = False
for line in lines:
    if line.startswith("home = "):
        rewritten.append("home = ../../.python/bin")
        did_home = True
    else:
        rewritten.append(line)
if not did_home:
    rewritten.insert(0, "home = ../../.python/bin")
path.write_text("\n".join(rewritten) + "\n", encoding="utf-8")
PY

remove_python_bytecode

cat > "$info_plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string></string>
  <key>CFBundleIdentifier</key>
  <string>com.epistemos.browserusepro</string>
  <key>CFBundleName</key>
  <string>BrowserUsePro</string>
  <key>CFBundlePackageType</key>
  <string>BNDL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.13.2</string>
  <key>CFBundleVersion</key>
  <string>1</string>
</dict>
</plist>
PLIST

signature_type="apple-development"
case "$sign_identity" in
  "-") signature_type="ad-hoc" ;;
  *"Developer ID Application"*) signature_type="developer-id" ;;
esac

codesign_args=(--force --sign "$sign_identity")
case "$signature_type" in
  "developer-id")
    codesign_args+=(--timestamp --options runtime)
    ;;
  "apple-development")
    codesign_args+=(--timestamp=none --options runtime)
    ;;
  *)
    codesign_args+=(--timestamp=none)
    ;;
esac

while IFS= read -r -d '' candidate; do
  if file "$candidate" | grep -q 'Mach-O'; then
    codesign "${codesign_args[@]}" "$candidate"
  fi
done < <(find "$payload_root" -type f -print0)

file_count="$(find "$payload_root" -type f ! -path "$payload_root/SIGNATURE_MANIFEST.json" | wc -l | tr -d ' ')"
python_version="$("$payload_root/.venv/bin/python" --version 2>&1)"

SIGNATURE_MANIFEST="$payload_root/SIGNATURE_MANIFEST.json" \
SIGNATURE_TYPE="$signature_type" \
SIGNING_IDENTITY="$sign_identity" \
FILE_COUNT="$file_count" \
PYTHON_VERSION="$python_version" \
python3 - <<'PY'
import json
import os
from pathlib import Path
from datetime import datetime, timezone

payload = {
    "schema_version": 1,
    "package_name": "BrowserUsePro",
    "runtime_lane": "pro-developer-id-only",
    "signature_type": os.environ["SIGNATURE_TYPE"],
    "signing_identity": os.environ["SIGNING_IDENTITY"],
    "payload_root": "Contents/Resources/BrowserUsePro",
    "file_count": int(os.environ["FILE_COUNT"]),
    "python": os.environ["PYTHON_VERSION"],
    "browser_use_version": "0.13.2",
    "created_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "codesign_contract": "BrowserUsePro.bundle must pass codesign --verify --deep --strict before bundling and strict Security.framework validation at runtime.",
}

Path(os.environ["SIGNATURE_MANIFEST"]).write_text(
    json.dumps(payload, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

codesign "${codesign_args[@]}" "$bundle_dir"
codesign --verify --strict --verbose=2 "$bundle_dir"
codesign --verify --deep --strict --verbose=2 "$bundle_dir"

PYTHONPATH="$payload_root:$payload_root/browser-use:$payload_root/cdp-use" \
PYTHONDONTWRITEBYTECODE=1 \
"$payload_root/.venv/bin/python" - <<'PY'
import epistemos_agent_browser
import epistemos_browser_env
import epistemos_browser_task
import gradio
import browser_use
import cdp_use
print(f"browser-use Pro package import smoke OK: gradio={gradio.__version__}")
PY

codesign --verify --strict --verbose=2 "$bundle_dir"
codesign --verify --deep --strict --verbose=2 "$bundle_dir"

echo "browser-use Pro signed bundle ready: $bundle_dir"
