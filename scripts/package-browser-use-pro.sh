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
  - PACKAGE_RESULT.json non-secret checkpoint evidence beside the bundle

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
package_result="$output_root/PACKAGE_RESULT.json"

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

if [[ "$skip_build" -eq 0 ]]; then
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
import os
import stat
from pathlib import Path
import sys

MAX_PYVENV_CFG_BYTES = 64 * 1024


def read_text_no_follow(path, label, max_bytes):
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode):
            raise SystemExit(f"{label} is not a regular file")
        if metadata.st_size < 0 or metadata.st_size > max_bytes:
            raise SystemExit(f"{label} is too large")
        with os.fdopen(fd, "rb") as handle:
            fd = -1
            data = handle.read(max_bytes + 1)
    finally:
        if fd >= 0:
            os.close(fd)
    if len(data) > max_bytes:
        raise SystemExit(f"{label} is too large")
    return data.decode("utf-8")


def write_text_no_follow(path, text, label):
    flags = os.O_WRONLY | os.O_TRUNC | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode):
            raise SystemExit(f"{label} is not a regular file")
        with os.fdopen(fd, "wb") as handle:
            fd = -1
            handle.write(text.encode("utf-8"))
    finally:
        if fd >= 0:
            os.close(fd)


path = Path(sys.argv[1])
lines = read_text_no_follow(path, "pyvenv.cfg", MAX_PYVENV_CFG_BYTES).splitlines()
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
write_text_no_follow(path, "\n".join(rewritten) + "\n", "pyvenv.cfg")
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
VENDOR_MANIFEST="$payload_root/VENDOR_MANIFEST.json" \
BUILD_MANIFEST="$payload_root/BUILD_MANIFEST.json" \
SIGNATURE_TYPE="$signature_type" \
SIGNING_IDENTITY="$sign_identity" \
FILE_COUNT="$file_count" \
PYTHON_VERSION="$python_version" \
python3 - <<'PY'
import json
import os
import stat
from pathlib import Path
from datetime import datetime, timezone

MAX_PACKAGE_MANIFEST_BYTES = 1024 * 1024

expected_components = {
    "browser-use": {
        "repo": "https://github.com/browser-use/browser-use.git",
        "commit": "2454d3e2551705232333c906ded8fc31ab0fc9f2",
        "package_version": "0.13.2",
    },
    "web-ui": {
        "repo": "https://github.com/browser-use/web-ui.git",
        "commit": "61962296c38a0d064e0ba02c827192b7a81d1819",
        "package_version": None,
    },
    "cdp-use": {
        "repo": "https://github.com/browser-use/cdp-use.git",
        "commit": "a318684daab5ab3a9a516fcab447ed4bdfb92be9",
        "package_version": "1.4.5",
    },
}


def read_text_no_follow(path, label, max_bytes=MAX_PACKAGE_MANIFEST_BYTES):
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode):
            raise SystemExit(f"{label} is not a regular file")
        if metadata.st_size <= 0 or metadata.st_size > max_bytes:
            raise SystemExit(f"{label} is empty or too large")
        with os.fdopen(fd, "rb") as handle:
            fd = -1
            data = handle.read(max_bytes + 1)
    finally:
        if fd >= 0:
            os.close(fd)
    if len(data) > max_bytes:
        raise SystemExit(f"{label} is too large")
    return data.decode("utf-8")


def write_text_no_follow(path, text, label):
    flags = (
        os.O_WRONLY
        | os.O_CREAT
        | os.O_TRUNC
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_NOFOLLOW", 0)
    )
    fd = os.open(path, flags, 0o644)
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode):
            raise SystemExit(f"{label} is not a regular file")
        with os.fdopen(fd, "wb") as handle:
            fd = -1
            handle.write(text.encode("utf-8"))
    finally:
        if fd >= 0:
            os.close(fd)


def required_string(component, key):
    value = component.get(key)
    if not isinstance(value, str):
        raise SystemExit("VENDOR_MANIFEST.json has non-string component pin evidence")
    value = value.strip()
    if not value:
        raise SystemExit("VENDOR_MANIFEST.json has malformed component pin evidence")
    return value


def optional_version(component):
    value = component.get("package_version")
    if value is None:
        return None
    if not isinstance(value, str):
        raise SystemExit("VENDOR_MANIFEST.json has malformed component version evidence")
    return value.strip()


def component_evidence(vendor_manifest):
    repos = {}
    commits = {}
    versions = {}
    for component in vendor_manifest.get("components", []):
        if not isinstance(component, dict):
            raise SystemExit("VENDOR_MANIFEST.json has malformed component entry")
        name = required_string(component, "name")
        if name in commits:
            raise SystemExit(f"VENDOR_MANIFEST.json has duplicate component pin evidence for {name}")
        repos[name] = required_string(component, "repo")
        commits[name] = required_string(component, "commit")
        versions[name] = optional_version(component)
    if not commits:
        raise SystemExit("VENDOR_MANIFEST.json has no component pins to record")
    return repos, commits, versions


def component_pin_problems(repos, commits, versions):
    problems = []
    for name, expected in sorted(expected_components.items()):
        if name not in commits:
            problems.append(f"missing {name}")
            continue
        if repos.get(name) != expected["repo"]:
            problems.append(f"{name} repo mismatch")
        if commits.get(name) != expected["commit"]:
            problems.append(f"{name} commit mismatch")
        if versions.get(name) != expected["package_version"]:
            problems.append(f"{name} package version mismatch")
    for name in sorted(commits):
        if name not in expected_components:
            problems.append(f"unexpected {name}")
    return problems


def required_playwright_revision(build_manifest, key, expected):
    value = build_manifest.get(key)
    if not isinstance(value, str):
        raise SystemExit(f"BUILD_MANIFEST.json has malformed {key}")
    value = value.strip()
    if value != expected:
        raise SystemExit(f"BUILD_MANIFEST.json {key} mismatch")
    return value


vendor_manifest = json.loads(read_text_no_follow(Path(os.environ["VENDOR_MANIFEST"]), "VENDOR_MANIFEST.json"))
build_manifest = json.loads(read_text_no_follow(Path(os.environ["BUILD_MANIFEST"]), "BUILD_MANIFEST.json"))
component_repos, component_commits, component_versions = component_evidence(vendor_manifest)
pin_problems = component_pin_problems(component_repos, component_commits, component_versions)
if pin_problems:
    raise SystemExit("VENDOR_MANIFEST.json component pins mismatch: " + "; ".join(pin_problems))
playwright_revisions = {
    "chromium": required_playwright_revision(build_manifest, "chromium_revision", "1223"),
    "chromium_headless_shell": required_playwright_revision(build_manifest, "headless_shell_revision", "1223"),
    "ffmpeg": required_playwright_revision(build_manifest, "ffmpeg_revision", "1011"),
}
python_version = os.environ["PYTHON_VERSION"].strip()
if not python_version.startswith("Python 3.11."):
    raise SystemExit(f"BrowserUsePro requires Python 3.11, got {python_version}")

payload = {
    "schema_version": 1,
    "package_name": "BrowserUsePro",
    "runtime_lane": "pro-developer-id-only",
    "signature_type": os.environ["SIGNATURE_TYPE"],
    "signing_identity": os.environ["SIGNING_IDENTITY"],
    "payload_root": "Contents/Resources/BrowserUsePro",
    "file_count": int(os.environ["FILE_COUNT"]),
    "python": python_version,
    "browser_use_version": "0.13.2",
    "component_repos": component_repos,
    "component_commits": component_commits,
    "component_versions": component_versions,
    "playwright_revisions": playwright_revisions,
    "created_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "codesign_contract": "BrowserUsePro.bundle must pass codesign --verify --deep --strict before bundling and strict Security.framework validation at runtime.",
}

write_text_no_follow(
    Path(os.environ["SIGNATURE_MANIFEST"]),
    json.dumps(payload, indent=2, sort_keys=True) + "\n",
    "SIGNATURE_MANIFEST.json",
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

PACKAGE_RESULT="$package_result" \
SIGNATURE_TYPE="$signature_type" \
PYTHON_VERSION="$python_version" \
python3 - <<'PY'
import json
import os
import stat
from pathlib import Path
from datetime import datetime, timezone


def write_text_no_follow(path, text, label):
    flags = (
        os.O_WRONLY
        | os.O_CREAT
        | os.O_TRUNC
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_NOFOLLOW", 0)
    )
    fd = os.open(path, flags, 0o644)
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode):
            raise SystemExit(f"{label} is not a regular file")
        with os.fdopen(fd, "wb") as handle:
            fd = -1
            handle.write(text.encode("utf-8"))
    finally:
        if fd >= 0:
            os.close(fd)


payload = {
    "schema_version": 1,
    "package_name": "BrowserUsePro",
    "bundle": "BrowserUsePro.bundle",
    "signature_manifest": "BrowserUsePro.bundle/Contents/Resources/BrowserUsePro/SIGNATURE_MANIFEST.json",
    "signature_type": os.environ["SIGNATURE_TYPE"],
    "python": os.environ["PYTHON_VERSION"],
    "codesign_verified": True,
    "smoke_suite_entrypoint": "scripts/browser-use-pro-smoke-suite.sh",
    "smoke_suite_args": ["--signed-bundle", "BrowserUsePro.bundle"],
    "notarization": "not recorded; release notarization remains distribution ops",
    "secrets": "not recorded",
    "created_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}
write_text_no_follow(
    Path(os.environ["PACKAGE_RESULT"]),
    json.dumps(payload, indent=2, sort_keys=True) + "\n",
    "PACKAGE_RESULT.json",
)
PY

echo "browser-use Pro signed bundle ready: $bundle_dir"
echo "browser-use Pro package result: $package_result"
