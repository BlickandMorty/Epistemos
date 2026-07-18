#!/bin/bash
# Stages the vendored June web bundle for the MAS agent surface (Plan 1-MAS §1).
#
# Builds the pinned June fork (production Vite, relative base) and stages it
# into a reviewable generated tree that Xcode copies into the app bundle with
# directory structure preserved (Contents/Resources/JuneWeb/...), where
# JuneWebAssets.resolve() finds it. The generated tree is kept in source control
# so clean CI/release checkouts do not depend on a developer-only sibling clone.
#
# Gates:
# - refuses a dist containing a service worker (perf doctrine §2.7)
# - excludes June's commercial fonts (Plan 1-MAS R6) — Berkeley Mono,
#   ABC Diatype, Martina Plantijn are licensed to June upstream, not Epistemos.
#   The scheme handler additionally 404s them (belt + braces).
set -euo pipefail

FORK="${EPISTEMOS_JUNE_FORK:-$HOME/dev/june-epistemos}"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
MAS_PATCH="$REPO_ROOT/june-mas-cloud-only.patch"
MAS_TSCONFIG="$REPO_ROOT/june-mas-tsconfig.json"
# NOT under Epistemos/Resources: the resources glob flattens files into the
# Resources root ("Multiple commands produce index.html"). The postBuild
# script bundle-app-runtime-assets.sh copies this stage into the base app
# at Contents/Resources/JuneWeb (the Free App Store target excludes it).
STAGE="$REPO_ROOT/.june-web-stage"
BUILD_ROOT=""
WORKTREE_PARENT=""
WORKTREE=""

cleanup() {
  if [ -n "$WORKTREE" ] && [ -d "$WORKTREE" ]; then
    git -C "$FORK" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
  fi
  if [ -n "$WORKTREE_PARENT" ] && [ -d "$WORKTREE_PARENT" ]; then
    rmdir "$WORKTREE_PARENT" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

UNLICENSED_FONTS=(
  "BerkeleyMono-Regular.woff2" "BerkeleyMono-Oblique.woff2"
  "ABCDiatype-Regular.woff2" "ABCDiatype-Medium.woff2"
  "martina-plantijn-light.woff2"
)

validate_staged_tree() {
  [ -f "$STAGE/dist/index.html" ] || return 1
  [ -f "$STAGE/tauri-internals-shim.js" ] || return 1

  local main_count
  main_count="$(find "$STAGE/dist/assets" -maxdepth 1 -type f -name 'main-*.js' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$main_count" = "1" ] || return 1
  grep -aFq 'June models' "$STAGE"/dist/assets/main-*.js || return 1
  grep -aFq 'June runs in Epistemos' "$STAGE"/dist/assets/main-*.js || return 1
  grep -aFq 'Models and tools are admitted by the Epistemos MAS host' "$STAGE"/dist/assets/main-*.js || return 1
  grep -aFq 'June text models' "$STAGE"/dist/assets/main-*.js || return 1
  if grep -aEq 'Workspace runs in Epistemos|Requests use your local June API|Configure Hermes capabilities and external messaging channels' \
    "$STAGE"/dist/assets/main-*.js; then
    return 1
  fi
  if grep -aEqi 'Ollama|GGUF|epistemos-local-chat|local language model|local model|browser-use|puppeteer|playwright|chromium|Drives a browser' \
    "$STAGE"/dist/assets/*.js; then
    return 1
  fi
  grep -Fq 'MAS uses June' "$STAGE/tauri-internals-shim.js" || return 1

  if find "$STAGE" -type f \( \
      -name 'sw.js' -o \
      -name 'service-worker*' -o \
      -name '*browser*' -o \
      -name '*.map' -o \
      -name 'BerkeleyMono-*' -o \
      -name 'ABCDiatype-*' -o \
      -name 'martina-plantijn-light.woff2' \
    \) | grep -q .; then
    return 1
  fi
}

if [ ! -f "$FORK/package.json" ]; then
  if validate_staged_tree; then
    echo "== June donor unavailable; using checked-in staged JuneWeb"
    exit 0
  fi
  echo "ERROR: June fork not found at $FORK and checked-in staged JuneWeb is incomplete (set EPISTEMOS_JUNE_FORK)" >&2
  exit 1
fi
[ -f "$MAS_PATCH" ] || { echo "ERROR: MAS cloud-only June patch is missing"; exit 1; }
[ -f "$MAS_TSCONFIG" ] || { echo "ERROR: MAS June TypeScript config is missing"; exit 1; }
if [ -n "$(git -C "$FORK" status --porcelain)" ]; then
  echo "ERROR: June donor has uncommitted files; refusing to ignore or overwrite them" >&2
  exit 1
fi
[ -d "$FORK/node_modules" ] || { echo "ERROR: June donor dependencies are missing"; exit 1; }

WORKTREE_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/epistemos-june-web.XXXXXX")"
WORKTREE="$WORKTREE_PARENT/worktree"
git -C "$FORK" worktree add --detach "$WORKTREE" HEAD >/dev/null
ln -s "$FORK/node_modules" "$WORKTREE/node_modules"
git -C "$WORKTREE" apply --check "$MAS_PATCH"
git -C "$WORKTREE" apply "$MAS_PATCH"
cp "$MAS_TSCONFIG" "$WORKTREE/tsconfig.epistemos.json"
BUILD_ROOT="$WORKTREE"

[ -f "$BUILD_ROOT/epistemos/tauri-internals-shim.js" ] || { echo "ERROR: overlay shim missing in fork"; exit 1; }
SETTINGS_SOURCE="$BUILD_ROOT/src/components/settings/AppSettings.tsx"
SIDEBAR_SOURCE="$BUILD_ROOT/src/components/sidebar/Sidebar.tsx"
AGENT_SOURCE="$BUILD_ROOT/src/components/agent/AgentWorkspace.tsx"
ACCOUNT_SOURCE="$BUILD_ROOT/src/components/account/AccountSettings.tsx"
[ -f "$SETTINGS_SOURCE" ] || { echo "ERROR: June Settings source missing in fork"; exit 1; }
[ -f "$SIDEBAR_SOURCE" ] || { echo "ERROR: June Settings sidebar source missing in fork"; exit 1; }
[ -f "$AGENT_SOURCE" ] || { echo "ERROR: June agent source missing in fork"; exit 1; }
[ -f "$ACCOUNT_SOURCE" ] || { echo "ERROR: June account source missing in fork"; exit 1; }
grep -Fq 'const imageGenerationAvailable = providerSettings.imageModel.trim().length > 0;' \
  "$SETTINGS_SOURCE" || {
    echo "ERROR: June Settings must hide image models when the MAS host exposes no image-generation model"
    exit 1
  }
grep -Fq 'MAS_HOST_HIDDEN_SETTINGS_TABS' "$SETTINGS_SOURCE" || {
  echo "ERROR: June Settings must hide disconnected account/skill tabs in the MAS host"
  exit 1
}
grep -Fq 'account.localDev ? "June text models" : "AI models"' \
  "$SETTINGS_SOURCE" || {
    echo "ERROR: June Settings must visibly identify the MAS text catalog"
    exit 1
  }
grep -Fq 'label: "June models"' "$SIDEBAR_SOURCE" || {
  echo "ERROR: June Settings sidebar must identify the MAS text catalog as June models"
    exit 1
}
HIDDEN_SETTINGS_BLOCK="$(sed -n '/^export const MAS_HOST_HIDDEN_SETTINGS_TABS/,/^]);/p' "$SETTINGS_SOURCE")"
for tab in \
  billing agent skills external-dirs skill-review mcp mcp-catalog \
  mcp-diagnostics mcp-security skills-hub taps toolsets bundles \
  profile-builder integrations-health import-export
do
  grep -Fq "\"$tab\"" <<<"$HIDDEN_SETTINGS_BLOCK" || {
    echo "ERROR: MAS June Settings must hide disconnected tab: $tab"
    exit 1
  }
done
grep -Fq 'if (!model) return "June runs in Epistemos.";' "$AGENT_SOURCE" || {
  echo "ERROR: MAS June model disclosure must keep the June identity"
  exit 1
}
if grep -Fq 'Workspace runs in Epistemos' "$AGENT_SOURCE"; then
  echo "ERROR: MAS June model disclosure must not rename June to Workspace"
  exit 1
fi
grep -Fq 'Models and tools are admitted by the Epistemos MAS host' "$ACCOUNT_SOURCE" || {
  echo "ERROR: MAS June local-host account copy must describe the native gateway"
  exit 1
}
grep -Fq 'June text models' "$SETTINGS_SOURCE" || {
  echo "ERROR: MAS June Settings must separate agent text models from dictation"
  exit 1
}
command -v bun >/dev/null || { echo "ERROR: bun is required"; exit 1; }

echo "== June fork: $FORK @ $(git -C "$FORK" rev-parse --short HEAD) ($(git -C "$FORK" log -1 --format=%cs))"
echo "== Applying Epistemos MAS cloud-only overlay in an isolated worktree"

echo "== Building (pinned dependencies + tsc + vite build --base=./)"
(cd "$BUILD_ROOT" && bunx tsc --project tsconfig.epistemos.json && bunx vite build --base=./ >/dev/null)

if find "$BUILD_ROOT/dist" -name "sw.js" -o -name "service-worker*" | grep -q .; then
  echo "ERROR: dist contains a service worker — refusing to stage"
  exit 1
fi

echo "== Staging -> $STAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE"
EXCLUDES=()
for font in "${UNLICENSED_FONTS[@]}"; do EXCLUDES+=(--exclude "$font"); done
# Never ship source maps: they leak June's original (commercial) source into the
# bundle and bloat it. The scheme handler would even serve them as JSON. Exclude
# defensively so a sourcemap-enabled Vite build can't leak through.
EXCLUDES+=(--exclude "*.map")
rsync -a "${EXCLUDES[@]}" "$BUILD_ROOT/dist/" "$STAGE/dist/"
cp "$BUILD_ROOT/epistemos/tauri-internals-shim.js" "$STAGE/tauri-internals-shim.js"

# Epistemos embeds only June's main agent surface. The donor's floating agent,
# dictation, and meeting HUD entrypoints are separate windows in upstream June;
# they are unreachable here and pull in React's browser-target HTML renderer.
rm -f \
  "$STAGE/dist/agent-hud.html" \
  "$STAGE/dist/hud.html" \
  "$STAGE/dist/meeting-hud.html" \
  "$STAGE"/dist/assets/agent-hud-*.js \
  "$STAGE"/dist/assets/agent-hud-*.css \
  "$STAGE"/dist/assets/hud-*.js \
  "$STAGE"/dist/assets/hud-*.css \
  "$STAGE"/dist/assets/meeting-hud-*.js \
  "$STAGE"/dist/assets/meeting-hud-*.css \
  "$STAGE"/dist/assets/server.browser-*.js

for font in "${UNLICENSED_FONTS[@]}"; do
  if [ -e "$STAGE/dist/$font" ]; then
    echo "ERROR: unlicensed font leaked into stage: $font"
    exit 1
  fi
done

if ! validate_staged_tree; then
  echo "ERROR: staged JuneWeb failed the clean-checkout artifact contract" >&2
  exit 1
fi

FILES=$(find "$STAGE/dist" -type f | wc -l | tr -d ' ')
MAIN_GZ=$(gzip -c "$STAGE"/dist/assets/main-*.js 2>/dev/null | wc -c | tr -d ' ')
echo "== Staged $FILES files; main chunk $((MAIN_GZ / 1024)) KB gz"
echo "== Done. Rebuild the Epistemos base scheme to bundle (bundle-app-runtime-assets.sh copies the stage)."
