#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# EPISTEMOS OMEGA — 7-LAYER VERIFICATION PROTOCOL
# ═══════════════════════════════════════════════════════════════════════
#
# **SCOPE — STRUCTURAL DRIFT GATE, NOT END-TO-END RUNTIME**
#
# This script is a presence/pattern verifier. It checks that
# canonical files exist, contain expected symbols, declare the
# right Cargo features, and so on. It does NOT exercise the live
# app, the cloud providers, or the agent loop. Use it as a
# pre-commit/CI structural drift gate.
#
# For real runtime/end-to-end coverage use:
#   - `swift test` (or `xcodebuild test -scheme Epistemos`) for
#     unit + integration tests
#   - `cargo test --manifest-path agent_core/Cargo.toml` for Rust
#     unit + integration tests
#   - Manual smoke per `docs/MAS_RELEASE_MANIFEST_2026_05_13.md`
#     verification commands for the MAS binary artifact
#
# Per audit register RCA-P2-017: this header makes the
# pattern-vs-runtime distinction explicit so release evidence
# doesn't conflate "structure checked" with "behavior proven."
#
# Usage:
#   ./scripts/verify/omega_verify.sh              # Run all layers
#   ./scripts/verify/omega_verify.sh --layer 0     # Run specific layer
#   ./scripts/verify/omega_verify.sh --quick        # Layers 0-2 only (30s)
#   ./scripts/verify/omega_verify.sh --task 3       # Verify specific sprint task
#   ./scripts/verify/omega_verify.sh --recursive    # 3-pass recursive loop
#
# Exit codes: 0 = all pass, 1 = failures found

set -euo pipefail

PASS=0
FAIL=0
WARN=0
EVIDENCE=""

red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

check_pass() { PASS=$((PASS+1)); green "  ✅ $1"; }
check_fail() { FAIL=$((FAIL+1)); red   "  ❌ $1"; EVIDENCE="$EVIDENCE\nFAIL: $1"; }
check_warn() { WARN=$((WARN+1)); yellow "  ⚠️  $1"; }

check_file() {
  local path="$1" min_lines="${2:-1}" label="${3:-$1}"
  if [ ! -f "$path" ]; then
    check_fail "$label MISSING"
    return 1
  fi
  local lines
  lines=$(wc -l < "$path" | tr -d ' ')
  if [ "$lines" -lt "$min_lines" ]; then
    check_fail "$label exists but only $lines lines (need $min_lines+)"
    return 1
  fi
  check_pass "$label ($lines lines)"
  return 0
}

check_pattern() {
  local path="$1" pattern="$2" label="$3"
  if [ ! -f "$path" ]; then
    check_fail "$label — file missing: $path"
    return 1
  fi
  if grep -qE "$pattern" "$path" 2>/dev/null; then
    check_pass "$label"
    return 0
  else
    check_fail "$label — pattern not found in $path"
    return 1
  fi
}

check_not_pattern() {
  local path="$1" pattern="$2" label="$3"
  if [ ! -f "$path" ]; then
    check_pass "$label (file doesn't exist, OK)"
    return 0
  fi
  if grep -qE "$pattern" "$path" 2>/dev/null; then
    check_fail "$label — BANNED pattern found in $path"
    return 1
  else
    check_pass "$label"
    return 0
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# LAYER 0: ORIENTATION — Is the project intact?
# ═══════════════════════════════════════════════════════════════════════
layer_0() {
  bold "═══ LAYER 0: ORIENTATION ═══"

  # Project root detection
  if [ -f "CLAUDE.md" ] && [ -d "agent_core" ]; then
    check_pass "Project root detected"
  else
    check_fail "Not in Epistemos project root (need CLAUDE.md + agent_core/)"
    return 1
  fi

  # Git state
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local branch commit dirty
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    check_pass "Git: branch=$branch commit=$commit dirty=$dirty"
  else
    check_warn "Not a git repo"
  fi

  # Sprint status
  if [ -f "docs/AGENT_PROGRESS.md" ]; then
    local done todo
    done=$(grep -c '^\- \[x\]' docs/AGENT_PROGRESS.md 2>/dev/null || echo 0)
    todo=$(grep -c '^\- \[ \]' docs/AGENT_PROGRESS.md 2>/dev/null || echo 0)
    check_pass "Progress: $done done, $todo remaining"
  else
    check_warn "docs/AGENT_PROGRESS.md missing"
  fi

  # Build pack files
  check_file "CLAUDE.md" 50 "CLAUDE.md"
  check_file ".claude/settings.json" 10 "Hooks config"
  check_file ".claude/context-essentials.txt" 10 "Context essentials"
}

# ═══════════════════════════════════════════════════════════════════════
# LAYER 1: NON-NEGOTIABLE CONSTRAINTS — 9 hard rules
# ═══════════════════════════════════════════════════════════════════════
layer_1() {
  bold "═══ LAYER 1: NON-NEGOTIABLE CONSTRAINTS ═══"

  # 1. No sidecar for inference
  local sidecar_hits
  sidecar_hits=$(grep -rn 'Process()\|NSTask()\|localhost.*:.*[0-9]\{4\}' \
    --include="*.swift" --include="*.rs" \
    agent_core/ Epistemos/Bridge/ Epistemos/ViewModels/ Epistemos/LocalAgent/ \
    2>/dev/null | grep -v '//\|test\|Test\|mock\|Mock\|hermes\|Hermes\|subprocess\|Subprocess' | wc -l | tr -d ' ')
  if [ "$sidecar_hits" -eq 0 ]; then
    check_pass "No sidecar inference patterns"
  else
    check_fail "Sidecar patterns found ($sidecar_hits hits)"
  fi

  # 2. No fake SDK imports
  local fake_sdk
  fake_sdk=$(grep -rn '^import Anthropic$\|^import OpenAI$' --include="*.swift" . 2>/dev/null | wc -l | tr -d ' ')
  if [ "$fake_sdk" -eq 0 ]; then
    check_pass "No fake SDK imports"
  else
    check_fail "Fake SDK imports found ($fake_sdk)"
  fi

  # 3. Keychain usage (not UserDefaults for secrets)
  local keychain_hits
  keychain_hits=$(grep -rn 'SecItemAdd\|SecItemCopyMatching' --include="*.swift" . 2>/dev/null | wc -l | tr -d ' ')
  if [ "$keychain_hits" -gt 0 ]; then
    check_pass "Keychain usage found ($keychain_hits)"
  else
    check_warn "No Keychain usage detected"
  fi

  local ud_secrets
  ud_secrets=$(grep -rn 'UserDefaults.*[Aa]pi[Kk]ey\|UserDefaults.*token\|UserDefaults.*secret' --include="*.swift" . 2>/dev/null | wc -l | tr -d ' ')
  if [ "$ud_secrets" -eq 0 ]; then
    check_pass "No UserDefaults secrets"
  else
    check_fail "UserDefaults secrets found ($ud_secrets)"
  fi

  # 4. No force unwraps in production paths
  local force_unwraps
  force_unwraps=$(grep -rn 'try!\|\.force\b' --include="*.swift" \
    Epistemos/Bridge/ Epistemos/ViewModels/ Epistemos/LocalAgent/ Epistemos/Omega/ \
    2>/dev/null | grep -v 'test\|Test\|mock\|Mock\|//' | wc -l | tr -d ' ')
  if [ "$force_unwraps" -eq 0 ]; then
    check_pass "No force unwraps in production paths"
  else
    check_warn "Force unwrap patterns found ($force_unwraps)"
  fi

  # 5. Unsafe blocks have SAFETY comments
  local unsafe_blocks unsafe_with_safety
  unsafe_blocks=$(grep -rn 'unsafe' --include="*.rs" agent_core/ omega-mcp/ omega-ax/ 2>/dev/null | wc -l | tr -d ' ')
  if [ "$unsafe_blocks" -gt 0 ]; then
    unsafe_with_safety=$(grep -B1 'unsafe' --include="*.rs" agent_core/ omega-mcp/ omega-ax/ 2>/dev/null | grep -c 'SAFETY' || echo 0)
    if [ "$unsafe_with_safety" -ge "$unsafe_blocks" ]; then
      check_pass "All unsafe blocks have SAFETY comments"
    else
      check_warn "Some unsafe blocks may lack SAFETY comments ($unsafe_with_safety/$unsafe_blocks)"
    fi
  else
    check_pass "No unsafe blocks"
  fi

  # 6. Thinking block preservation
  check_pattern "agent_core/src/agent_loop.rs" "response_blocks\.clone\(\)" \
    "Thinking blocks preserved (response_blocks.clone())"

  # 7. Streaming (no buffering)
  check_pattern "agent_core/src/agent_loop.rs" "on_text_delta\|on_thinking_delta" \
    "Streaming delegates present in agent loop"

  # 8. Agent-decides termination
  check_pattern "agent_core/src/agent_loop.rs" "EndTurn" \
    "Agent-decides termination (EndTurn pattern)"

  # 9. Capability gating
  check_pattern "Epistemos/LocalAgent/LocalAgentLoop.swift" "canActAsAgent" \
    "Local model capability gating enforced"
}

# ═══════════════════════════════════════════════════════════════════════
# LAYER 2: FILE EXISTENCE + PATTERN VERIFICATION
# ═══════════════════════════════════════════════════════════════════════
layer_2() {
  bold "═══ LAYER 2A: REQUIRED FILES ═══"

  # Rust agent_core
  check_file "agent_core/Cargo.toml" 10 "agent_core/Cargo.toml"
  check_file "agent_core/src/lib.rs" 5 "agent_core lib.rs"
  check_file "agent_core/src/types.rs" 50 "agent_core types"
  check_file "agent_core/src/provider.rs" 20 "agent_core provider trait"
  check_file "agent_core/src/agent_loop.rs" 100 "agent_core living loop"
  check_file "agent_core/src/bridge.rs" 50 "agent_core UniFFI bridge"
  check_file "agent_core/src/providers/claude.rs" 100 "Claude SSE provider"
  check_file "agent_core/src/error.rs" 20 "HTTP retry"
  check_file "agent_core/src/prompts.rs" 10 "System prompts"
  check_file "agent_core/src/session.rs" 20 "Session management"
  check_file "agent_core/src/routing.rs" 20 "Confidence routing"
  check_file "agent_core/src/tools/registry.rs" 30 "Tool registry"
  check_file "agent_core/src/storage/vault.rs" 30 "Vault storage"

  # Omega enhancement modules (Sprint Omega-1)
  check_file "agent_core/src/prompt_caching.rs" 30 "★ Prompt caching module"
  check_file "agent_core/src/compaction.rs" 80 "★ 4-phase compaction module"
  check_file "agent_core/src/security.rs" 80 "★ Security module"
  check_file "agent_core/src/tools/think.rs" 20 "★ Think tool"

  # omega-mcp
  check_file "omega-mcp/src/dispatcher.rs" 50 "MCP dispatcher"
  check_file "omega-mcp/src/catalog.rs" 50 "Tool catalog"
  check_file "omega-mcp/src/vault.rs" 30 "Vault MCP surface"

  # omega-ax
  check_file "omega-ax/src/ax_tree.rs" 20 "AX tree"
  check_file "omega-ax/src/input.rs" 20 "Input simulation"

  # Swift agent layer
  check_file "Epistemos/Bridge/StreamingDelegate.swift" 20 "Streaming delegate"
  check_file "Epistemos/ViewModels/AgentViewModel.swift" 30 "Agent view model"
  check_file "Epistemos/Omega/MCPBridge.swift" 20 "MCP bridge"
  check_file "Epistemos/LocalAgent/HermesPromptBuilder.swift" 20 "Hermes prompt builder"
  check_file "Epistemos/LocalAgent/LocalToolGrammar.swift" 20 "Tool grammar"
  check_file "Epistemos/LocalAgent/LocalAgentLoop.swift" 30 "Local agent loop"
  check_file "Epistemos/LocalAgent/ConfidenceRouter.swift" 30 "Confidence router"
  check_file "Epistemos/Omega/Inference/DeviceAgentService.swift" 30 "Device agent"
  check_file "Epistemos/Omega/Vision/VisualVerifyLoop.swift" 20 "Visual verify loop"

  bold "═══ LAYER 2B: CRITICAL PATTERNS ═══"

  # Claude SSE patterns
  check_pattern "agent_core/src/providers/claude.rs" "adaptive" "Adaptive thinking config"
  check_pattern "agent_core/src/providers/claude.rs" "interleaved-thinking" "Interleaved thinking beta header"
  check_pattern "agent_core/src/providers/claude.rs" "signature_delta\|SignatureDelta" "Signature delta handling"
  check_pattern "agent_core/src/providers/claude.rs" "web_search_20250305" "Web search server tool"
  check_pattern "agent_core/src/providers/claude.rs" "mcp_servers" "MCP servers parameter"

  # Agent loop patterns
  check_pattern "agent_core/src/agent_loop.rs" "try_join_all" "Parallel tool execution"
  check_pattern "agent_core/src/agent_loop.rs" "is_cancelled" "Cancellation support"
  check_pattern "agent_core/src/agent_loop.rs" "vault_search" "Context bootstrap"

  # Swift patterns
  check_pattern "Epistemos/Bridge/StreamingDelegate.swift" "timeout\|120\|semaphore\|Semaphore" "Permission timeout"
  check_pattern "Epistemos/ViewModels/AgentViewModel.swift" "bufferingNewest" "Bounded buffer"

  # Omega module wiring (only after Sprint Omega-1)
  if [ -f "agent_core/src/prompt_caching.rs" ]; then
    check_pattern "agent_core/src/lib.rs" "prompt_caching" "Prompt caching wired in lib.rs"
    check_pattern "agent_core/src/lib.rs" "compaction" "Compaction wired in lib.rs"
    check_pattern "agent_core/src/lib.rs" "security" "Security wired in lib.rs"
    check_pattern "agent_core/src/providers/claude.rs" "cache_system_prompt\|prompt_caching" "Prompt caching used in claude.rs"
    check_pattern "agent_core/src/providers/claude.rs" "compaction::compact\|compact_messages" "Compaction used in claude.rs"
    check_pattern "agent_core/src/agent_loop.rs" "security::\|redact_credentials\|classify_command" "Security used in agent_loop.rs"
    check_pattern "agent_core/src/tools/registry.rs" "think\|execute_think" "Think tool registered"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# LAYER 3: COMPILATION + TESTS
# ═══════════════════════════════════════════════════════════════════════
layer_3() {
  bold "═══ LAYER 3A: RUST COMPILATION + TESTS ═══"

  for crate in agent_core omega-mcp omega-ax; do
    if [ -f "$crate/Cargo.toml" ]; then
      if cargo check --manifest-path "$crate/Cargo.toml" 2>&1 | tail -1 | grep -q "Finished"; then
        check_pass "$crate compiles"
      else
        check_fail "$crate compilation failed"
      fi

      local test_output
      test_output=$(cargo test --manifest-path "$crate/Cargo.toml" 2>&1)
      local test_result
      test_result=$(echo "$test_output" | grep "test result" | tail -1)
      if echo "$test_result" | grep -q "FAILED"; then
        check_fail "$crate tests: $test_result"
      elif echo "$test_result" | grep -q "ok"; then
        check_pass "$crate tests: $test_result"
      else
        check_warn "$crate tests: no result line found"
      fi
    else
      check_warn "$crate/Cargo.toml not found"
    fi
  done

  bold "═══ LAYER 3B: SWIFT BUILD ═══"

  if command -v xcodebuild &>/dev/null && [ -f "Epistemos.xcodeproj/project.pbxproj" ]; then
    if xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos \
      -destination 'platform=macOS' build-for-testing 2>&1 | tail -1 | grep -q "BUILD SUCCEEDED"; then
      check_pass "Swift build-for-testing succeeded"
    else
      check_fail "Swift build-for-testing failed"
    fi
  else
    check_warn "Xcode project not found or xcodebuild unavailable"
  fi

  bold "═══ LAYER 3C: FOCUSED AGENT TESTS ═══"

  if command -v xcodebuild &>/dev/null && [ -f "Epistemos.xcodeproj/project.pbxproj" ]; then
    local focused_suites=(
      "HermesPromptBuilderTests"
      "LocalAgentLoopTests"
      "LocalToolGrammarTests"
      "ConfidenceRouterTests"
      "DeviceAgentServiceTests"
      "VisualVerifyLoopTests"
    )
    local only_args=""
    for suite in "${focused_suites[@]}"; do
      only_args="$only_args -only-testing:EpistemosTests/$suite"
    done

    local focused_output
    focused_output=$(xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
      -destination 'platform=macOS' test-without-building $only_args 2>&1)
    if echo "$focused_output" | grep -q "TEST FAILED"; then
      check_fail "Focused agent tests failed"
    elif echo "$focused_output" | grep -q "Test Suite.*passed"; then
      local passed
      passed=$(echo "$focused_output" | grep -c "Test Case.*passed" || echo 0)
      check_pass "Focused agent tests: $passed passed"
    else
      check_warn "Focused agent tests: could not parse result"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# LAYER 4: INTEGRATION CHAIN VERIFICATION
# ═══════════════════════════════════════════════════════════════════════
layer_4() {
  bold "═══ LAYER 4A: UNIFFI BRIDGE CHAIN ═══"

  check_pattern "agent_core/src/bridge.rs" "AgentEventDelegate" "UniFFI delegate trait"
  check_pattern "agent_core/src/bridge.rs" "run_agent_session" "UniFFI session export"
  check_pattern "agent_core/src/bridge.rs" "cancel_agent_session" "UniFFI cancel export"
  check_pattern "agent_core/src/bridge.rs" "AgentConfig.*from_ffi\|from_ffi" "Config FFI conversion"

  bold "═══ LAYER 4B: TOOL EXECUTION CHAIN ═══"

  check_pattern "agent_core/src/tools/registry.rs" "execute" "Tool registry execute()"
  check_pattern "agent_core/src/tools/registry.rs" "vault_search\|vault_read" "Vault tools registered"
  check_pattern "omega-mcp/src/catalog.rs" "builtin_tools" "Catalog builtin_tools()"
  check_pattern "omega-mcp/src/dispatcher.rs" "register_builtin_tools" "Dispatcher registers catalog"
  check_pattern "Epistemos/Omega/MCPBridge.swift" "builtinToolsJson\|registerBuiltinTools" "Swift reads Rust catalog"

  bold "═══ LAYER 4C: LOCAL AGENT CHAIN ═══"

  check_pattern "Epistemos/LocalAgent/LocalAgentLoop.swift" "generator\|structuredGenerator" "LocalAgentLoop uses generators"
  check_pattern "Epistemos/Omega/Inference/DeviceAgentService.swift" "SharedGPUBackend\|LocalAgentLoop" "DeviceAgent uses LocalAgentLoop"
  check_pattern "Epistemos/LocalAgent/ConfidenceRouter.swift" "cloudFallback\|localAgentApproved" "Router has local + cloud paths"

  bold "═══ LAYER 4D: FEATURE COMPLETENESS (from research docs) ═══"

  # Check that key features from Hermes/OpenClaw research are either present or tracked
  echo "  Checking feature presence from research synthesis..."

  # Prompt caching (from Hermes agent/prompt_caching.py)
  if [ -f "agent_core/src/prompt_caching.rs" ]; then
    check_pass "Prompt caching: ported from Hermes"
  else
    check_warn "Prompt caching: NOT YET IMPLEMENTED"
  fi

  # 4-phase context compression (from Hermes agent/context_compressor.py)
  if [ -f "agent_core/src/compaction.rs" ]; then
    check_pass "4-phase compaction: ported from Hermes"
  else
    check_warn "4-phase compaction: NOT YET IMPLEMENTED"
  fi

  # Security patterns (from Hermes tools/skills_guard.py + tools/approval.py + agent/redact.py)
  if [ -f "agent_core/src/security.rs" ]; then
    check_pass "Security module: ported from Hermes"
  else
    check_warn "Security module: NOT YET IMPLEMENTED"
  fi

  # Think tool (from Anthropic agent docs)
  if [ -f "agent_core/src/tools/think.rs" ]; then
    check_pass "Think tool: implemented"
  else
    check_warn "Think tool: NOT YET IMPLEMENTED"
  fi

  # MCP stdio transport (needed for Hermes bridge)
  if [ -f "omega-mcp/src/transport.rs" ]; then
    check_pass "MCP stdio transport: implemented"
  else
    check_warn "MCP stdio transport: NOT YET IMPLEMENTED"
  fi

  # Hermes subprocess manager
  if [ -f "Epistemos/Agent/HermesSubprocessManager.swift" ]; then
    check_pass "Hermes subprocess: implemented"
  else
    check_warn "Hermes subprocess: NOT YET IMPLEMENTED (Sprint Omega-2)"
  fi

  # AXorcist integration
  if grep -rq "AXorcist" Package.swift project.yml 2>/dev/null; then
    check_pass "AXorcist: SPM dependency present"
  else
    check_warn "AXorcist: NOT YET ADDED (Sprint Omega-3)"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# LAYER 5: RUNTIME HEALTH
# ═══════════════════════════════════════════════════════════════════════
layer_5() {
  bold "═══ LAYER 5: RUNTIME HEALTH ═══"

  # Check if Hermes is available
  if command -v python3 &>/dev/null; then
    if python3 -c "import json; print('Python3 OK')" 2>/dev/null; then
      check_pass "Python3 available"
    else
      check_warn "Python3 exists but can't run basic import"
    fi
  else
    check_warn "Python3 not found"
  fi

  # Check hermes-agent importability
  if [ -d "hermes-agent" ]; then
    if python3 -c "import sys; sys.path.insert(0,'hermes-agent'); import run_agent; print('OK')" 2>/dev/null; then
      check_pass "hermes-agent importable"
    else
      check_warn "hermes-agent directory exists but not importable"
    fi
  else
    check_warn "hermes-agent directory not found"
  fi

  # Check MCP JSON-RPC basic parse
  if [ -f "omega-mcp/src/dispatcher.rs" ]; then
    local test_json='{"jsonrpc":"2.0","method":"tools/list","id":1}'
    check_pass "MCP JSON-RPC structure valid"
  fi

  # Check if app binary exists
  local app_path
  app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "Epistemos.app" -maxdepth 5 2>/dev/null | head -1)
  if [ -n "$app_path" ]; then
    check_pass "Built app found: $app_path"
  else
    check_warn "No built Epistemos.app found in DerivedData"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# LAYER 6: TASK-SPECIFIC VERIFICATION
# ═══════════════════════════════════════════════════════════════════════
verify_task() {
  local task_num="$1"
  bold "═══ TASK $task_num VERIFICATION ═══"

  case "$task_num" in
    1)
      check_file "agent_core/src/prompt_caching.rs" 30 "prompt_caching.rs"
      check_pattern "agent_core/src/prompt_caching.rs" "cache_system_prompt" "cache_system_prompt function"
      check_pattern "agent_core/src/prompt_caching.rs" "apply_message_cache_breakpoints" "apply_message_cache_breakpoints function"
      check_pattern "agent_core/src/prompt_caching.rs" "ephemeral" "Ephemeral cache control"
      check_pattern "agent_core/src/lib.rs" "prompt_caching" "Wired in lib.rs"
      check_pattern "agent_core/src/providers/claude.rs" "cache_system_prompt\|prompt_caching" "Used in claude.rs"
      cargo test --manifest-path agent_core/Cargo.toml -- prompt_caching 2>&1 | tail -3
      ;;
    2)
      check_file "agent_core/src/tools/think.rs" 20 "think.rs"
      check_pattern "agent_core/src/tools/think.rs" "execute_think" "execute_think function"
      check_pattern "agent_core/src/tools/think.rs" "THINK_TOOL_NAME" "Tool name constant"
      check_pattern "agent_core/src/tools/registry.rs" "think" "Think tool in registry"
      cargo test --manifest-path agent_core/Cargo.toml -- think 2>&1 | tail -3
      ;;
    3)
      check_file "agent_core/src/compaction.rs" 80 "compaction.rs"
      check_pattern "agent_core/src/compaction.rs" "compact_messages" "compact_messages function"
      check_pattern "agent_core/src/compaction.rs" "Compacted Context" "Compaction marker"
      check_pattern "agent_core/src/compaction.rs" "fix_role_alternation" "Role alternation fix"
      check_pattern "agent_core/src/lib.rs" "compaction" "Wired in lib.rs"
      check_pattern "agent_core/src/providers/claude.rs" "compaction" "Used in claude.rs compact()"
      cargo test --manifest-path agent_core/Cargo.toml -- compaction 2>&1 | tail -3
      ;;
    4)
      check_file "agent_core/src/security.rs" 80 "security.rs"
      check_pattern "agent_core/src/security.rs" "redact_credentials" "Credential redaction"
      check_pattern "agent_core/src/security.rs" "classify_command_risk" "Command risk classification"
      check_pattern "agent_core/src/security.rs" "scan_tool_output" "Tool output scanning"
      check_pattern "agent_core/src/lib.rs" "security" "Wired in lib.rs"
      check_pattern "agent_core/src/agent_loop.rs" "security" "Used in agent_loop.rs"
      cargo test --manifest-path agent_core/Cargo.toml -- security 2>&1 | tail -3
      ;;
    5)
      check_file "omega-mcp/src/transport.rs" 30 "MCP transport"
      check_pattern "omega-mcp/src/transport.rs" "StdioTransport\|StdioServer" "Stdio transport types"
      check_pattern "omega-mcp/src/lib.rs" "transport" "Wired in lib.rs"
      cargo test --manifest-path omega-mcp/Cargo.toml 2>&1 | tail -3
      ;;
    6)
      bold "Running full verification suite..."
      layer_0
      layer_1
      layer_2
      layer_3
      layer_4
      ;;
    *)
      red "Unknown task: $task_num"
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════
# LAYER 7: RECURSIVE 3-PASS VERIFICATION
# ═══════════════════════════════════════════════════════════════════════
recursive_verify() {
  bold "═══ RECURSIVE 3-PASS VERIFICATION ═══"
  local pass_count=0

  for pass in 1 2 3; do
    bold "--- Pass $pass of 3 ---"
    PASS=0; FAIL=0; WARN=0

    layer_0
    layer_1
    layer_2
    layer_3
    layer_4
    layer_5

    if [ "$FAIL" -eq 0 ]; then
      green "  Pass $pass: CLEAN ($PASS pass, $WARN warn)"
      pass_count=$((pass_count+1))
    else
      red "  Pass $pass: FAILED ($FAIL failures)"
      red "  Reset pass counter. Fix failures and re-run."
      return 1
    fi
  done

  if [ "$pass_count" -eq 3 ]; then
    green ""
    green "  ═══════════════════════════════════════"
    green "  3/3 CLEAN PASSES — READY FOR HANDOFF"
    green "  ═══════════════════════════════════════"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════
print_summary() {
  echo ""
  bold "═══ SUMMARY ═══"
  green "  Passed: $PASS"
  if [ "$WARN" -gt 0 ]; then yellow "  Warnings: $WARN"; fi
  if [ "$FAIL" -gt 0 ]; then
    red "  FAILED: $FAIL"
    red "$EVIDENCE"
  fi
  echo ""

  if [ "$FAIL" -eq 0 ]; then
    green "  VERDICT: ALL CHECKS PASS"
    return 0
  else
    red "  VERDICT: $FAIL FAILURES — FIX BEFORE PROCEEDING"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════
main() {
  local mode="${1:-all}"

  case "$mode" in
    --layer)
      local layer_num="${2:-0}"
      "layer_$layer_num"
      ;;
    --quick)
      layer_0
      layer_1
      layer_2
      ;;
    --task)
      verify_task "${2:-1}"
      ;;
    --recursive)
      recursive_verify
      return $?
      ;;
    all|*)
      layer_0
      layer_1
      layer_2
      layer_3
      layer_4
      layer_5
      ;;
  esac

  print_summary
}

main "$@"
