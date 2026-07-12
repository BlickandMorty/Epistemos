#!/bin/zsh

set -u
set -o pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
expected_branch=feat/goose-surface
canon_dir="$HOME/Downloads/epistemos_mas_master_canon_2026_07_08"
prep_dir="$HOME/Downloads/epistemos_mas_low_ram_preparation_2026_07_11"
flash_root=${EPISTEMOS_RECOVERY_DRIVE:-/Volumes/treasure}
flash_assets="$flash_root/Epistemos-External-Plan-Assets-2026-07-12"
flash_canon="$flash_assets/epistemos_mas_master_canon_2026_07_08"
flash_prep="$flash_assets/epistemos_mas_low_ram_preparation_2026_07_11"
prompt_pack="$canon_dir/03_MINIMAL_PROMPT_PACK.md"
evidence_doc="$repo_root/docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md"
handoff="$repo_root/docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md"
expected_key=EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08
expected_june_head=7105c43c8622cc546075f7ff1e20680e2009f8bb
expected_june_main_sha=9d38c92dea2a70bf15e88741c47ea9833da3fee8ecfc053fd593f4befc8a1144
expected_june_index_sha=30790bb4f65afaf93dd9db5bd4fc9ec396708d4f22f7cb881a24c0cbeec2c00e
expected_june_shim_sha=7440986d70a044689fea50f8a181441dfc05c5b8736421691db8b2980979e77a
fatal_count=0
prerequisite_count=0

pass() {
  print "PASS  $1"
}

fail() {
  print -u2 "FAIL  $1"
  fatal_count=$((fatal_count + 1))
}

blocked() {
  print "BLOCK $1"
  prerequisite_count=$((prerequisite_count + 1))
}

restore_directory_if_needed() {
  local target=$1
  local source=$2
  local label=$3

  if [[ -d "$target" ]]; then
    pass "$label exists at $target"
    return
  fi
  if [[ ! -d "$source" ]]; then
    fail "$label is absent and its flash-drive recovery source is unavailable"
    return
  fi
  mkdir -p "$target"
  if rsync -a --exclude='._*' "$source/" "$target/"; then
    pass "$label restored from the verified flash-drive copy"
  else
    fail "$label restore failed"
  fi
}

print "== Canon-first Epistemos reset/resume check =="
restore_directory_if_needed "$canon_dir" "$flash_canon" "Full July 8 MAS master canon"
restore_directory_if_needed "$prep_dir" "$flash_prep" "Corrected low-RAM preparation packet"

if [[ -d "$flash_canon" && -d "$canon_dir" ]]; then
  if diff -qr --exclude='._*' "$flash_canon" "$canon_dir" >/dev/null; then
    pass "External master canon matches the complete flash-drive copy"
  else
    fail "External master canon differs from the complete flash-drive copy"
  fi
fi
if [[ -d "$flash_prep" && -d "$prep_dir" ]]; then
  if diff -qr --exclude='._*' "$flash_prep" "$prep_dir" >/dev/null; then
    pass "Corrected preparation packet matches the flash-drive copy"
  else
    fail "Corrected preparation packet differs from the flash-drive copy"
  fi
fi

if [[ -f "$prompt_pack" ]] && grep -Fq "## Prompt 2 - KEELSTONE Storage and MAS Release Gate" "$prompt_pack" && grep -Fq "ID: $expected_key" "$prompt_pack"; then
  pass "Canonical numbered prompt pack contains exact Prompt 2 and execution key"
else
  fail "Canonical Prompt 2 identity is missing or changed"
fi
if [[ -f "$prep_dir/PREPARATION_PACKET_CORRECTION_LOG.md" ]] && grep -Fq 'PREPARATION ONLY' "$prep_dir/PREPARATION_PACKET_CORRECTION_LOG.md"; then
  pass "Preparation correction remains explicitly subordinate"
else
  fail "Preparation correction log is missing or no longer marked preparation-only"
fi

print "\n== GitHub identity =="
cd "$repo_root" || exit 1
branch=$(git branch --show-current 2>/dev/null || true)
[[ "$branch" == "$expected_branch" ]] && pass "Branch is $expected_branch" || fail "Expected branch $expected_branch, found ${branch:-none}"

if git fetch origin "$expected_branch" >/dev/null 2>&1; then
  pass "Fetched origin/$expected_branch"
else
  fail "Could not fetch origin/$expected_branch"
fi

head_sha=$(git rev-parse HEAD 2>/dev/null || true)
remote_sha=$(git rev-parse "origin/$expected_branch" 2>/dev/null || true)
handoff_sha=$(git log -1 --format=%H -- "$handoff" 2>/dev/null || true)
live_sha=$(git ls-remote origin "refs/heads/$expected_branch" 2>/dev/null | awk 'NR == 1 {print $1}')
if [[ -n "$head_sha" && "$head_sha" == "$remote_sha" && "$head_sha" == "$handoff_sha" && "$head_sha" == "$live_sha" ]]; then
  pass "HEAD, origin, live GitHub, and handoff publication commit agree: $head_sha"
else
  fail "Git identity mismatch (HEAD=${head_sha:-missing}, origin=${remote_sha:-missing}, handoff=${handoff_sha:-missing}, live=${live_sha:-missing})"
fi

dirty_count=$(git status --porcelain=v1 -uall | wc -l | tr -d ' ')
if [[ "$dirty_count" == 0 ]]; then
  pass "Worktree is clean"
else
  fail "Worktree has $dirty_count entries; inspect them without resetting or overwriting"
fi

print "\n== Build prerequisites (reported, never auto-installed) =="
if command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1; then
  pass "Rust toolchain is installed"
else
  blocked "Rust toolchain is absent; focused Xcode tests and archive builds cannot start"
fi
if command -v bun >/dev/null 2>&1; then
  pass "Bun is installed"
else
  blocked "Bun is absent; JuneWeb cannot be rebuilt from donor source"
fi
if xcodebuild -version >/dev/null 2>&1; then
  pass "Xcode command-line build tools are available"
else
  blocked "Xcode command-line build tools are unavailable"
fi

stage="$repo_root/.june-web-stage"
stage_main=$(find "$stage/dist/assets" -maxdepth 1 -type f -name 'main-*.js' -print -quit 2>/dev/null || true)
if [[ -n "$stage_main" && -f "$stage/dist/index.html" && -f "$stage/tauri-internals-shim.js" ]]; then
  main_sha=$(shasum -a 256 "$stage_main" | awk '{print $1}')
  index_sha=$(shasum -a 256 "$stage/dist/index.html" | awk '{print $1}')
  shim_sha=$(shasum -a 256 "$stage/tauri-internals-shim.js" | awk '{print $1}')
  if [[ "$main_sha" == "$expected_june_main_sha" && "$index_sha" == "$expected_june_index_sha" && "$shim_sha" == "$expected_june_shim_sha" ]]; then
    pass "JuneWeb stage matches the last reviewed July 10 artifact hashes"
  else
    blocked "JuneWeb stage exists but differs from the reviewed July 10 hashes; review before use"
  fi
else
  blocked "Exact reviewed JuneWeb stage is absent"
fi

june_donor="$HOME/dev/june-epistemos"
if [[ -d "$june_donor/.git" ]]; then
  june_head=$(git -C "$june_donor" rev-parse HEAD 2>/dev/null || true)
  if [[ "$june_head" == "$expected_june_head" ]]; then
    blocked "June donor has the recorded base commit, but its 92-file reviewed dirty overlay still needs hash-oracle reconstruction"
  else
    blocked "June donor HEAD differs from recorded local base $expected_june_head"
  fi
else
  blocked "Owner-modified June donor is absent; its unpushed base/overlay must be reconstructed and validated against the recorded stage hashes"
fi

if security find-identity -v -p codesigning 2>/dev/null | grep -Eq 'Apple Development|Apple Distribution|3rd Party Mac Developer'; then
  pass "At least one Apple code-signing identity is available"
else
  blocked "Apple code-signing identity is absent"
fi

print "\n== Owner resource safety threshold =="
swap_line=$(sysctl -n vm.swapusage 2>/dev/null || true)
swap_mb=$(print -r -- "$swap_line" | awk '{for (i=1; i<=NF; i++) if ($i == "used") {v=$(i+2); sub(/M$/, "", v); print v; exit}}')
free_percent=$(memory_pressure -Q 2>/dev/null | awk -F': ' '/System-wide memory free percentage/ {gsub(/%/, "", $2); print $2; exit}')
pages_throttled=$(vm_stat 2>/dev/null | awk -F': ' '/Pages throttled/ {gsub(/\./, "", $2); gsub(/ /, "", $2); print $2; exit}')
competing=$(ps -axo pid=,command= | awk 'BEGIN {IGNORECASE=1} /xcodebuild|swift-frontend|(^|\/)swiftc( |$)|(^|\/)clang( |$)|llama-cli|llama-server|ollama|mlx_lm|Epistemos\.app\/Contents\/MacOS\/Epistemos/ && !/awk/ {print}')

if [[ -n "$swap_mb" ]] && awk -v value="$swap_mb" 'BEGIN {exit !(value < 4096)}'; then
  pass "Swap used is below 4 GB (${swap_mb} MB)"
else
  blocked "Swap threshold failed or could not be read (${swap_mb:-unknown} MB)"
fi
if [[ -n "$free_percent" && "$free_percent" -ge 25 ]]; then
  pass "Free-memory percentage is at least 25% (${free_percent}%)"
else
  blocked "Free-memory threshold failed or could not be read (${free_percent:-unknown}%)"
fi
if [[ "$pages_throttled" == 0 ]]; then
  pass "Pages throttled is zero"
else
  blocked "Pages throttled is ${pages_throttled:-unknown}"
fi
if [[ -z "$competing" ]]; then
  pass "No competing Xcode/compiler/model/Epistemos process is active"
else
  blocked "Competing process detected; do not start tests or archive work"
  print -r -- "$competing"
fi

print "\n== Canonical continuation boundary =="
print "Prompt authority: $prompt_pack"
print "Active prompt: Prompt 2 only"
print "Execution key: $expected_key"
print "Evidence ledger to update: $evidence_doc"
print "Next action after every prerequisite and safety check is green: run only the narrow serial compile/regression batch, then exactly one Release archive, every artifact gate, and the finite correlated runtime matrix. Do not begin Prompt 3."

if (( fatal_count > 0 )); then
  print -u2 "\nRESET/RESUME IDENTITY: FAILED ($fatal_count fatal finding(s)); stop without overwriting anything."
  exit 1
fi

print "\nRESET/RESUME IDENTITY: VERIFIED"
if (( prerequisite_count > 0 )); then
  print "KEELSTONE EXECUTION: BLOCKED BY $prerequisite_count REPORTED PREREQUISITE(S); restore them before tests/build/archive/runtime work."
else
  print "KEELSTONE EXECUTION: PREREQUISITES AND CURRENT RESOURCE THRESHOLDS PASS."
fi
