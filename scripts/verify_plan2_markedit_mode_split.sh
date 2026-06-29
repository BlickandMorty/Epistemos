#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_RESOURCES_DIR="${1:-${ROOT_DIR}/build/plan2-markedit-final/DerivedData/Build/Products/Debug/Epistemos.app/Contents/Resources}"

fail() {
  echo "verify_plan2_markedit_mode_split.sh: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [ -f "${path}" ] || fail "missing required file: ${path#${ROOT_DIR}/}"
}

require_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq "${needle}" "${path}" || fail "${path#${ROOT_DIR}/} does not contain: ${needle}"
}

require_not_contains() {
  local path="$1"
  local needle="$2"
  if grep -Fq "${needle}" "${path}"; then
    fail "${path#${ROOT_DIR}/} unexpectedly contains: ${needle}"
  fi
}

code_editor="${ROOT_DIR}/Epistemos/Views/Notes/CodeEditorView.swift"
adapter="${ROOT_DIR}/Epistemos/Views/Notes/WebKitCodeEditorView.swift"
codepack="${ROOT_DIR}/docs/research/MARKEDIT_EMBED_CODEPACK_2026_06_27.md"
canonical="${ROOT_DIR}/docs/research/EDITOR_CANONICAL_PLAN_2026_06_27.md"

require_file "${code_editor}"
require_file "${adapter}"
require_file "${codepack}"
require_file "${canonical}"

require_contains "${codepack}" "MODE-SPLIT CHROME over ONE shared CoreEditor engine"
require_contains "${codepack}" "THE PREVIEW BUTTON IS LOAD-BEARING"
require_contains "${canonical}" "MODE-SPLIT chrome over ONE CoreEditor engine"
require_contains "${canonical}" "Live-Preview / HTML preview button"

require_contains "${code_editor}" "private var isMarkdownDocument"
require_contains "${code_editor}" "if isMarkdownDocument"
require_contains "${code_editor}" "MarkEditMarkdownEditorRepresentable("
require_contains "${code_editor}" "codeEditorChromeContent"
require_contains "${code_editor}" "MarkEditCodeEditorRepresentable("
require_contains "${code_editor}" "HTMLWorkspacePreviewView("
require_contains "${code_editor}" "showLivePreview.toggle()"
require_not_contains "${code_editor}" "WebKitCodeEditorView("

require_contains "${adapter}" "struct MarkEditCodeEditorRepresentable"
require_contains "${adapter}" "struct MarkEditMarkdownEditorRepresentable"
require_contains "${adapter}" "MarkEditVerbatimMarkdownChromeRepresentable"
require_contains "${adapter}" "makeNSViewController(context: Context) -> EditorViewController"
require_contains "${adapter}" "MarkEditCoreEditorChunkLoader"
require_contains "${adapter}" "Bundle.main.url(forResource: filename, withExtension: nil)"
require_contains "${adapter}" "Bundle.main.url(forResource: \"index\", withExtension: \"html\")"

if [ -d "${APP_RESOURCES_DIR}" ]; then
  index_html="${APP_RESOURCES_DIR}/index.html"
  require_file "${index_html}"
  require_contains "${index_html}" 'window.config = "{{EDITOR_CONFIG}}";'

  chunk_count="$(
    grep -o '/chunk-loader/chunks/[^"'"'"') ]*' "${index_html}" |
      sed 's#^/chunk-loader/chunks/##' |
      sort -u |
      while IFS= read -r chunk; do
        [ -n "${chunk}" ] || continue
        [ -f "${APP_RESOURCES_DIR}/${chunk}" ] || fail "built app bundle is missing CoreEditor chunk: ${chunk}"
        echo "${chunk}"
      done |
      wc -l |
      tr -d ' '
  )"
  [ "${chunk_count}" -gt 0 ] || fail "built app index.html has no CoreEditor chunk references"
  echo "Plan 2 MarkEdit mode split OK; verified ${chunk_count} built CoreEditor resource references."
else
  echo "Plan 2 MarkEdit mode split OK; built app resources not present at ${APP_RESOURCES_DIR#${ROOT_DIR}/}, skipped bundle check."
fi

