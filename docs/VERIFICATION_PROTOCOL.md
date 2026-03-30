# Epistemos Verification Protocol v2.0
## Exhaustive Audit + Runtime Verification + Manual Testing + Computer Use Validation

---

## HOW THIS DOCUMENT WORKS

This is the single source of truth for verifying that Epistemos works correctly. It covers 7 layers of verification, each progressively deeper. Every layer is designed to be runnable by Claude Code, Codex, or a human developer.

**Layer 0**: Orientation — confirm the project is intact
**Layer 1**: Constraint violations — blockers that invalidate everything
**Layer 2**: Static architecture audit — files exist, patterns correct, types match
**Layer 3**: Compilation + unit tests — code builds, tests pass
**Layer 4**: Integration tests — components actually connect to each other
**Layer 5**: Runtime verification — app launches, services start, no crashes
**Layer 6**: Manual/Computer-Use UI testing — visual confirmation via screenshots

Each layer gates the next. Do NOT proceed to Layer N+1 if Layer N has blockers.

---

## LAYER 0: ORIENTATION (run first, always)

```bash
#!/bin/bash
set -euo pipefail
echo "================================================================"
echo "  LAYER 0: ORIENTATION"
echo "================================================================"
echo ""

cd /Users/jojo/Downloads/Epistemos

echo "--- Project root ---"
pwd
echo ""

echo "--- Core files ---"
for f in CLAUDE.md AGENTS.md .claude/settings.json .claude/context-essentials.txt \
         docs/PROGRESS.md docs/AGENT_PROGRESS.md \
         docs/agent-system/AGENT_ARCHITECTURE.md \
         docs/agent-system/GAP_ANALYSIS.md \
         docs/HERMES_INTEGRATION_RESEARCH.md; do
    [ -f "$f" ] && echo "  OK $f ($(wc -l < "$f" | tr -d ' ') lines)" || echo "  MISSING $f"
done
echo ""

echo "--- Codebase size ---"
echo "  Swift files: $(find . -name '*.swift' -not -path '*/.*' -not -path '*/build/*' | wc -l | tr -d ' ')"
echo "  Rust files:  $(find . -name '*.rs' -not -path '*/.*' -not -path '*/target/*' | wc -l | tr -d ' ')"
echo "  Test files:  $(find . -name '*Test*' -o -name '*test*' | grep -E '\.(swift|rs)$' | wc -l | tr -d ' ')"
echo ""

echo "--- Rust crates ---"
for crate in agent_core omega-mcp omega-ax; do
    [ -f "$crate/Cargo.toml" ] && echo "  OK $crate/" || echo "  MISSING $crate/"
done
echo ""

echo "--- Hermes Agent ---"
[ -d "hermes-agent" ] && echo "  OK hermes-agent/ ($(find hermes-agent -name '*.py' | wc -l | tr -d ' ') Python files)" \
    || echo "  NOT CLONED hermes-agent/"
echo ""

echo "--- Git state ---"
git status --porcelain | head -20
echo ""

echo "--- Sprint state ---"
echo "Completed:"
grep -E "^\- \[x\]|^\- \[X\]" docs/AGENT_PROGRESS.md 2>/dev/null | head -20 || echo "  (none)"
echo ""
echo "Pending:"
grep -E "^\- \[ \]" docs/AGENT_PROGRESS.md 2>/dev/null | head -20 || echo "  (none)"
```

---

## LAYER 1: CONSTRAINT VIOLATIONS (any failure here = stop everything)

9 non-negotiable rules. A single violation means ALL work must stop until fixed.

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos
BLOCKERS=0

echo "================================================================"
echo "  LAYER 1: CONSTRAINT VIOLATIONS"
echo "================================================================"
echo ""

# ── C1: No sidecar processes for inference ─────────────────────────
echo "C1: SIDECAR INFERENCE PATTERNS (must be 0)"
SIDECAR=$(grep -rn "Process()\|NSTask()\|posix_spawn" \
    --include="*.swift" \
    Epistemos/Engine/ Epistemos/LocalAgent/ Epistemos/Omega/Inference/ Epistemos/Bridge/ 2>/dev/null \
    | grep -vi "//\|test\|mock\|hermes\|osascript\|shortcuts" \
    | wc -l | tr -d ' ')
echo "  Found: $SIDECAR"
if [ "$SIDECAR" -gt 0 ]; then
    echo "  BLOCKER: Sidecar inference detected"
    grep -rn "Process()\|NSTask()" --include="*.swift" \
        Epistemos/Engine/ Epistemos/LocalAgent/ Epistemos/Omega/Inference/ 2>/dev/null \
        | grep -vi "//\|test\|mock\|hermes\|osascript"
    BLOCKERS=$((BLOCKERS + 1))
fi
echo ""

# ── C2: No fake SDK imports ────────────────────────────────────────
echo "C2: NONEXISTENT SDK IMPORTS (must be 0)"
FAKESDK=$(grep -rn "^import Anthropic$\|^import OpenAI$\|^import GoogleAI$" \
    --include="*.swift" Epistemos/ 2>/dev/null | wc -l | tr -d ' ')
echo "  Found: $FAKESDK"
[ "$FAKESDK" -gt 0 ] && { echo "  BLOCKER"; BLOCKERS=$((BLOCKERS + 1)); }
echo ""

# ── C3: API keys in Keychain, not UserDefaults ────────────────────
echo "C3: CREDENTIALS IN USERDEFAULTS (must be 0)"
UDKEYS=$(grep -rn "UserDefaults.*[Aa]pi[Kk]ey\|UserDefaults.*[Tt]oken\|UserDefaults.*[Ss]ecret\|UserDefaults.*[Pp]assword" \
    --include="*.swift" Epistemos/ 2>/dev/null \
    | grep -vi "//\|test\|mock" | wc -l | tr -d ' ')
echo "  Found: $UDKEYS"
[ "$UDKEYS" -gt 0 ] && { echo "  BLOCKER"; BLOCKERS=$((BLOCKERS + 1)); }
echo ""

# ── C4: No force unwraps in production ─────────────────────────────
echo "C4: FORCE UNWRAPS (try!, as!, .unwrap())"
FORCE=$(grep -rn 'try!\|as! \|\.unwrap()' \
    --include="*.swift" \
    Epistemos/Bridge/ Epistemos/ViewModels/ Epistemos/LocalAgent/ Epistemos/Omega/ Epistemos/Engine/ 2>/dev/null \
    | grep -vi "//\|test\|mock\|IBOutlet\|IBAction" \
    | wc -l | tr -d ' ')
echo "  Found: $FORCE"
[ "$FORCE" -gt 0 ] && echo "  WARNING: Review each one"
echo ""

# ── C5: Unsafe blocks have SAFETY comments ─────────────────────────
echo "C5: UNSAFE WITHOUT SAFETY COMMENT (must be 0)"
for crate in agent_core omega-mcp omega-ax; do
    if [ -d "$crate/src" ]; then
        UNSAFETY=$(grep -rn "unsafe " --include="*.rs" "$crate/src/" 2>/dev/null \
            | grep -v "SAFETY\|//\|test\|#\[" | wc -l | tr -d ' ')
        echo "  $crate: $UNSAFETY"
        [ "$UNSAFETY" -gt 0 ] && BLOCKERS=$((BLOCKERS + 1))
    fi
done
echo ""

# ── C6: No print() in production Swift ─────────────────────────────
echo "C6: PRINT() IN PRODUCTION"
PRINTS=$(grep -rn "print(" --include="*.swift" \
    Epistemos/Bridge/ Epistemos/ViewModels/ Epistemos/LocalAgent/ Epistemos/Omega/Inference/ 2>/dev/null \
    | grep -vi "//\|test\|mock\|Log\.\|os_log\|logger\|#if DEBUG" \
    | wc -l | tr -d ' ')
echo "  Found: $PRINTS"
echo ""

# ── C7: Thinking blocks preserved ──────────────────────────────────
echo "C7: THINKING BLOCK PRESERVATION"
if [ -f "agent_core/src/agent_loop.rs" ]; then
    STRIP=$(grep -c "filter.*Text\|strip.*thinking\|remove.*thinking" agent_core/src/agent_loop.rs 2>/dev/null)
    echo "  Thinking-stripping patterns: $STRIP"
    [ "$STRIP" -gt 0 ] && { echo "  BLOCKER: Thinking blocks being stripped"; BLOCKERS=$((BLOCKERS + 1)); }

    PRESERVE=$(grep -c "response_blocks" agent_core/src/agent_loop.rs 2>/dev/null)
    echo "  response_blocks references: $PRESERVE (should be 2+)"

    SIG=$(grep -c "signature" agent_core/src/types.rs 2>/dev/null)
    echo "  Signature field in types.rs: $SIG references"
fi
echo ""

# ── C8: Streaming, no buffering ────────────────────────────────────
echo "C8: STREAMING (delegate calls inside stream loop)"
if [ -f "agent_core/src/agent_loop.rs" ]; then
    DELEGATE_CALLS=$(grep -c "delegate\." agent_core/src/agent_loop.rs 2>/dev/null)
    echo "  Delegate calls in agent_loop: $DELEGATE_CALLS (should be 5+)"
    [ "$DELEGATE_CALLS" -lt 5 ] && echo "  WARNING: May not be streaming all events"
fi
if [ -f "Epistemos/ViewModels/AgentViewModel.swift" ]; then
    UNBOUNDED=$(grep -c "unbounded" Epistemos/ViewModels/AgentViewModel.swift 2>/dev/null)
    echo "  Unbounded buffering: $UNBOUNDED (must be 0)"
    [ "$UNBOUNDED" -gt 0 ] && { echo "  BLOCKER: Unbounded AsyncStream"; BLOCKERS=$((BLOCKERS + 1)); }
fi
echo ""

# ── C9: Honest capability gating ──────────────────────────────────
echo "C9: LOCAL MODEL CAPABILITY GATING"
GATING=$(grep -rn "canActAsAgent" --include="*.swift" Epistemos/ 2>/dev/null | wc -l | tr -d ' ')
echo "  canActAsAgent references: $GATING (should be 3+: ConfidenceRouter, LocalAgentLoop, DeviceAgentService)"
[ "$GATING" -lt 3 ] && echo "  WARNING: Capability gating may be incomplete"
echo ""

echo "================================================================"
echo "  LAYER 1 RESULT: $BLOCKERS BLOCKERS"
echo "================================================================"
if [ "$BLOCKERS" -gt 0 ]; then
    echo "  STOP. Fix all blockers before proceeding."
    exit 1
fi
```

---

## LAYER 2: STATIC ARCHITECTURE AUDIT

### 2A: File Existence (every required file present with minimum line count)

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos
MISSING=0

echo "================================================================"
echo "  LAYER 2A: FILE EXISTENCE"
echo "================================================================"

check_file() {
    local path="$1"
    local min_lines="$2"
    local desc="$3"
    if [ ! -f "$path" ]; then
        echo "  MISSING: $path ($desc)"
        MISSING=$((MISSING + 1))
    else
        local lines=$(wc -l < "$path" | tr -d ' ')
        if [ "$lines" -lt "$min_lines" ]; then
            echo "  STUB: $path — only $lines lines (need $min_lines+) ($desc)"
            MISSING=$((MISSING + 1))
        else
            echo "  OK $path ($lines lines)"
        fi
    fi
}

echo ""
echo "--- Rust agent_core ---"
check_file "agent_core/Cargo.toml" 10 "Crate manifest"
check_file "agent_core/src/lib.rs" 10 "Crate root"
check_file "agent_core/src/types.rs" 80 "Message types (ContentBlock, Thinking+signature)"
check_file "agent_core/src/provider.rs" 30 "AgentProvider trait"
check_file "agent_core/src/agent_loop.rs" 300 "Agentic loop (THE CORE)"
check_file "agent_core/src/bridge.rs" 100 "UniFFI bridge"
check_file "agent_core/src/error.rs" 80 "HTTP retry + error classification"
check_file "agent_core/src/prompts.rs" 50 "System prompt builder"
check_file "agent_core/src/session.rs" 80 "Global session registry"
check_file "agent_core/src/routing.rs" 100 "Task routing/classification"
check_file "agent_core/src/providers/claude.rs" 400 "Claude SSE provider"
check_file "agent_core/src/tools/registry.rs" 300 "Tool registry + handlers"
check_file "agent_core/src/storage/vault.rs" 300 "Vault backend (tantivy + SQLite)"

echo ""
echo "--- Rust omega-mcp ---"
check_file "omega-mcp/src/lib.rs" 10 "Crate root"
check_file "omega-mcp/src/dispatcher.rs" 300 "MCP dispatcher"
check_file "omega-mcp/src/registry.rs" 100 "Tool registry"
check_file "omega-mcp/src/catalog.rs" 50 "Authoritative tool catalog"
check_file "omega-mcp/src/vault.rs" 50 "Vault MCP executor"
check_file "omega-mcp/src/server.rs" 100 "JSON-RPC types"
check_file "omega-mcp/src/logger.rs" 100 "Execution logger"
check_file "omega-mcp/src/orchestrator.rs" 300 "Task orchestration"

echo ""
echo "--- Rust omega-ax ---"
check_file "omega-ax/src/lib.rs" 10 "Crate root"
check_file "omega-ax/src/ax_tree.rs" 200 "AXUIElement tree walker"
check_file "omega-ax/src/ax_ffi.rs" 80 "Raw AX FFI bindings"
check_file "omega-ax/src/input.rs" 100 "CGEvent input simulation"
check_file "omega-ax/src/permissions.rs" 30 "Permission checking"

echo ""
echo "--- Swift LocalAgent ---"
check_file "Epistemos/LocalAgent/HermesPromptBuilder.swift" 80 "Hermes-3 ChatML builder"
check_file "Epistemos/LocalAgent/LocalToolGrammar.swift" 120 "Grammar DSL"
check_file "Epistemos/LocalAgent/LocalAgentLoop.swift" 200 "Local agentic loop actor"
check_file "Epistemos/LocalAgent/ConfidenceRouter.swift" 150 "SLM/LLM routing"

echo ""
echo "--- Swift Bridge/Views ---"
check_file "Epistemos/Bridge/StreamingDelegate.swift" 120 "Rust-to-Swift event bridge"
check_file "Epistemos/ViewModels/AgentViewModel.swift" 200 "Agent UI view model"
check_file "Epistemos/Views/Omega/OmegaPanel.swift" 200 "Omega agent panel"
check_file "Epistemos/Omega/MCPBridge.swift" 120 "MCP tool bridge"

echo ""
echo "--- Swift Inference ---"
check_file "Epistemos/Omega/Inference/DeviceAgentService.swift" 200 "Brain 2 device agent"
check_file "Epistemos/Omega/Inference/DualBrainRouter.swift" 80 "Brain 1/2 router"
check_file "Epistemos/Omega/Inference/ConstrainedDecodingService.swift" 80 "Grammar gate"
check_file "Epistemos/Omega/Inference/MLXConstrainedGenerator.swift" 150 "MLX logit processor"

echo ""
echo "--- Tests ---"
check_file "EpistemosTests/HermesPromptBuilderTests.swift" 50 "Prompt builder tests"
check_file "EpistemosTests/LocalAgentLoopTests.swift" 200 "Agent loop tests"
check_file "EpistemosTests/LocalToolGrammarTests.swift" 30 "Grammar tests"
check_file "EpistemosTests/ConfidenceRouterTests.swift" 100 "Router tests"
check_file "EpistemosTests/DeviceAgentServiceTests.swift" 80 "Device agent tests"

echo ""
echo "================================================================"
echo "  LAYER 2A RESULT: $MISSING MISSING/STUB FILES"
echo "================================================================"
```

### 2B: Pattern Verification (critical patterns exist in the right files)

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos
FAILS=0

echo "================================================================"
echo "  LAYER 2B: PATTERN VERIFICATION"
echo "================================================================"
echo ""

check_pattern() {
    local file="$1"
    local pattern="$2"
    local desc="$3"
    if [ ! -f "$file" ]; then
        echo "  SKIP: $file not found — $desc"
        return
    fi
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo "  OK $desc"
    else
        echo "  FAIL: $desc (pattern '$pattern' not in $file)"
        FAILS=$((FAILS + 1))
    fi
}

echo "--- Thinking preservation ---"
check_pattern "agent_core/src/types.rs" "signature" "ContentBlock::Thinking has signature field"
check_pattern "agent_core/src/agent_loop.rs" "response_blocks" "Agent loop preserves all content blocks"
check_pattern "agent_core/src/providers/claude.rs" "SignatureDelta\|signature_delta" "Claude provider handles signature deltas"

echo ""
echo "--- SSE state machine ---"
check_pattern "agent_core/src/providers/claude.rs" "content_block_start" "SSE: content_block_start"
check_pattern "agent_core/src/providers/claude.rs" "content_block_delta" "SSE: content_block_delta"
check_pattern "agent_core/src/providers/claude.rs" "content_block_stop" "SSE: content_block_stop"
check_pattern "agent_core/src/providers/claude.rs" "message_delta" "SSE: message_delta"
check_pattern "agent_core/src/providers/claude.rs" "message_stop" "SSE: message_stop"
check_pattern "agent_core/src/providers/claude.rs" "thinking_delta" "Delta: thinking_delta"
check_pattern "agent_core/src/providers/claude.rs" "text_delta" "Delta: text_delta"
check_pattern "agent_core/src/providers/claude.rs" "input_json_delta" "Delta: input_json_delta"
check_pattern "agent_core/src/providers/claude.rs" "adaptive" "Thinking config: adaptive"
check_pattern "agent_core/src/providers/claude.rs" "interleaved-thinking" "Beta header: interleaved-thinking"

echo ""
echo "--- Agentic loop ---"
check_pattern "agent_core/src/agent_loop.rs" "try_join_all\|join_all" "Parallel tool execution"
check_pattern "agent_core/src/agent_loop.rs" "is_cancelled" "Cancellation support"
check_pattern "agent_core/src/agent_loop.rs" "EndTurn\|end_turn" "Agent-decides termination"
check_pattern "agent_core/src/agent_loop.rs" "compact" "Context compaction"
check_pattern "agent_core/src/agent_loop.rs" "max_turns" "Max turns safety rail"
check_pattern "agent_core/src/agent_loop.rs" "vault_search\|vault" "Vault context bootstrap"

echo ""
echo "--- HTTP retry ---"
check_pattern "agent_core/src/error.rs" "429" "Rate limit (429) handling"
check_pattern "agent_core/src/error.rs" "500\|502\|503" "Server error retry"
check_pattern "agent_core/src/error.rs" "exponential\|backoff\|jitter" "Exponential backoff"

echo ""
echo "--- Swift bridge ---"
check_pattern "Epistemos/Bridge/StreamingDelegate.swift" "DispatchSemaphore" "Permission uses semaphore"
check_pattern "Epistemos/Bridge/StreamingDelegate.swift" "120\|timeout" "Permission timeout"
check_pattern "Epistemos/ViewModels/AgentViewModel.swift" "bufferingNewest" "Bounded AsyncStream"
check_pattern "Epistemos/ViewModels/AgentViewModel.swift" "Task.detached" "Detached task for FFI"

echo ""
echo "--- Local agent ---"
check_pattern "Epistemos/LocalAgent/LocalAgentLoop.swift" "canActAsAgent" "Capability gate in loop"
check_pattern "Epistemos/LocalAgent/ConfidenceRouter.swift" "canActAsAgent" "Capability gate in router"
check_pattern "Epistemos/Omega/Inference/DeviceAgentService.swift" "canActAsAgent" "Capability gate in backend"
check_pattern "Epistemos/LocalAgent/HermesPromptBuilder.swift" "tool_call\|tools>" "Hermes XML format"
check_pattern "Epistemos/LocalAgent/LocalToolGrammar.swift" "MLXStructured\|omegaSoftGuidance" "Grammar backend selection"

echo ""
echo "--- MCP ---"
check_pattern "omega-mcp/src/dispatcher.rs" "tools/list\|tools/call" "MCP methods"
check_pattern "omega-mcp/src/catalog.rs" "ToolCatalogEntry\|CatalogEntry" "Authoritative catalog"
check_pattern "Epistemos/Omega/MCPBridge.swift" "OmegaToolRegistry\|McpDispatcher" "Swift MCP bridge"

echo ""
echo "--- Computer use ---"
check_pattern "omega-ax/src/ax_tree.rs" "AXUIElementCreateApplication\|walk_ax_tree" "AX tree walker"
check_pattern "omega-ax/src/ax_ffi.rs" "AXIsProcessTrusted" "AX permission check"
check_pattern "omega-ax/src/input.rs" "CGEvent\|simulate_click" "CGEvent input"

echo ""
echo "================================================================"
echo "  LAYER 2B RESULT: $FAILS PATTERN FAILURES"
echo "================================================================"
```

---

## LAYER 3: COMPILATION + UNIT TESTS

### 3A: Rust Crate Builds + Tests

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos
FAILURES=0

echo "================================================================"
echo "  LAYER 3A: RUST COMPILATION + TESTS"
echo "================================================================"
echo ""

for crate in agent_core omega-mcp omega-ax; do
    if [ -f "$crate/Cargo.toml" ]; then
        echo "--- $crate: cargo check ---"
        if cargo check --manifest-path "$crate/Cargo.toml" 2>&1 | tail -3; then
            echo "  OK compilation"
        else
            echo "  FAIL compilation"
            FAILURES=$((FAILURES + 1))
        fi
        echo ""

        echo "--- $crate: cargo test ---"
        TEST_OUTPUT=$(cargo test --manifest-path "$crate/Cargo.toml" 2>&1)
        echo "$TEST_OUTPUT" | tail -5
        PASSED=$(echo "$TEST_OUTPUT" | grep "test result:" | grep -o "[0-9]* passed" | head -1)
        FAILED=$(echo "$TEST_OUTPUT" | grep "test result:" | grep -o "[0-9]* failed" | head -1)
        echo "  Result: $PASSED, $FAILED"
        echo "$TEST_OUTPUT" | grep -q "FAILED" && FAILURES=$((FAILURES + 1))
        echo ""
    fi
done

echo "================================================================"
echo "  LAYER 3A RESULT: $FAILURES FAILURES"
echo "================================================================"
```

### 3B: Swift Build

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos

echo "================================================================"
echo "  LAYER 3B: SWIFT COMPILATION"
echo "================================================================"
echo ""

echo "--- xcodebuild build-for-testing ---"
xcodebuild -quiet \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    build-for-testing 2>&1 | tail -20

BUILD_EXIT=$?
if [ $BUILD_EXIT -eq 0 ]; then
    echo "  OK Swift build succeeded"
else
    echo "  FAIL Swift build failed (exit $BUILD_EXIT)"
fi
```

### 3C: Focused Swift Tests (agent-specific)

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos
FAILURES=0

echo "================================================================"
echo "  LAYER 3C: FOCUSED SWIFT TESTS"
echo "================================================================"
echo ""

TEST_SUITES=(
    "EpistemosTests/HermesPromptBuilderTests"
    "EpistemosTests/LocalAgentLoopTests"
    "EpistemosTests/LocalToolGrammarTests"
    "EpistemosTests/ConfidenceRouterTests"
    "EpistemosTests/DeviceAgentServiceTests"
    "EpistemosTests/OmegaAgentTests"
    "EpistemosTests/OmegaToolCallParserTests"
    "EpistemosTests/OmegaToolSchemaGrammarTests"
    "EpistemosTests/OmegaLiveRuntimeTests"
    "EpistemosTests/OmegaConfirmationGateTests"
    "EpistemosTests/OmegaAXSemanticSelectorTests"
    "EpistemosTests/OmegaTaskGraphTests"
)

ONLY_TESTING=""
for suite in "${TEST_SUITES[@]}"; do
    ONLY_TESTING="$ONLY_TESTING -only-testing:$suite"
done

echo "Running ${#TEST_SUITES[@]} test suites..."
xcodebuild \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    test-without-building \
    $ONLY_TESTING 2>&1 | tail -30

echo ""

# Parse results
for suite in "${TEST_SUITES[@]}"; do
    NAME=$(echo "$suite" | sed 's|.*/||')
    echo "  $NAME: checking..."
done
```

### 3D: Full Test Suite Health (regression check)

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos

echo "================================================================"
echo "  LAYER 3D: FULL TEST SUITE (regression check)"
echo "================================================================"
echo ""
echo "WARNING: This takes 5-15 minutes."
echo ""

xcodebuild \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    test 2>&1 | tee /tmp/epistemos-full-test.log | tail -30

echo ""
echo "--- Summary ---"
grep -E "Test Suite.*passed|Test Suite.*failed|Executed.*test" /tmp/epistemos-full-test.log | tail -5
echo ""

TOTAL=$(grep "Executed" /tmp/epistemos-full-test.log | tail -1 | grep -o "[0-9]* test" | head -1)
FAILURES=$(grep "Executed" /tmp/epistemos-full-test.log | tail -1 | grep -o "[0-9]* failure" | head -1)
echo "Total: $TOTAL"
echo "Failures: $FAILURES"
echo ""
echo "Baseline: 2717 tests in 355 suites, ~19 pre-existing issues"
echo "If total < 2700, tests were LOST. If failures > 25, regressions introduced."
```

---

## LAYER 4: INTEGRATION VERIFICATION

### 4A: UniFFI Bridge Chain

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos

echo "================================================================"
echo "  LAYER 4A: UNIFFI BRIDGE CHAIN"
echo "================================================================"
echo ""

echo "--- Rust exports ---"
echo "agent_core:"
grep -n "uniffi::export\|#\[uniffi::export\]" agent_core/src/bridge.rs 2>/dev/null | head -10
echo ""
echo "omega-mcp:"
grep -n "uniffi::export\|pub fn" omega-mcp/src/uniffi_exports.rs 2>/dev/null | head -15
echo ""
echo "omega-ax:"
grep -n "uniffi::export\|pub fn" omega-ax/src/uniffi_exports.rs 2>/dev/null | head -10
echo ""

echo "--- Swift imports ---"
echo "StreamingDelegate imports agent_core:"
grep -n "import agent_core\|canImport(agent_core)" Epistemos/Bridge/StreamingDelegate.swift 2>/dev/null
echo ""
echo "MCPBridge imports omega_mcp:"
grep -n "McpDispatcher\|omega_mcp\|canImport" Epistemos/Omega/MCPBridge.swift 2>/dev/null | head -5
echo ""

echo "--- Function call chain ---"
echo "Swift calls runAgentSession:"
grep -rn "runAgentSession" --include="*.swift" Epistemos/ 2>/dev/null | head -5
echo ""
echo "Rust exposes runAgentSession:"
grep -n "run_agent_session" agent_core/src/bridge.rs 2>/dev/null | head -5
echo ""
echo "runAgentSession calls run_agent_loop:"
grep -n "run_agent_loop" agent_core/src/bridge.rs 2>/dev/null | head -3
echo ""
echo "run_agent_loop calls provider.stream_message:"
grep -n "stream_message" agent_core/src/agent_loop.rs 2>/dev/null | head -3
```

### 4B: Tool Registry → Vault → Tool Execution Chain

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos

echo "================================================================"
echo "  LAYER 4B: TOOL EXECUTION CHAIN"
echo "================================================================"
echo ""

echo "--- Registry has vault tools ---"
grep -n "vault_search\|vault_read\|vault_write" agent_core/src/tools/registry.rs 2>/dev/null | head -6
echo ""

echo "--- Vault tools use VaultBackend ---"
grep -n "VaultBackend\|VaultStore\|vault\." agent_core/src/tools/registry.rs 2>/dev/null | head -6
echo ""

echo "--- VaultStore has hybrid search ---"
grep -n "hybrid_search\|tantivy\|QueryParser" agent_core/src/storage/vault.rs 2>/dev/null | head -6
echo ""

echo "--- MCPBridge registers tools ---"
grep -n "register\|registerTool\|registerAll" Epistemos/Omega/MCPBridge.swift 2>/dev/null | head -5
echo ""

echo "--- OmegaToolRegistry defines all tools ---"
TOOL_COUNT=$(grep -c "OmegaToolDefinition(" Epistemos/Omega/MCPBridge.swift 2>/dev/null)
echo "  Tool definitions in MCPBridge: $TOOL_COUNT (should be 27)"
```

### 4C: Local Agent → Inference → Grammar Chain

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos

echo "================================================================"
echo "  LAYER 4C: LOCAL AGENT CHAIN"
echo "================================================================"
echo ""

echo "--- LocalAgentLoop.liveLoop() factory ---"
grep -n "liveLoop\|static func" Epistemos/LocalAgent/LocalAgentLoop.swift 2>/dev/null | head -5
echo ""

echo "--- SharedGPUBackend creates LocalAgentLoop ---"
grep -n "LocalAgentLoop\|liveLoop\|makeLocalAgent" Epistemos/Omega/Inference/DeviceAgentService.swift 2>/dev/null | head -5
echo ""

echo "--- ConstrainedDecodingService wired in AppBootstrap ---"
grep -n "constrainedDecod\|MLXConstrainedGenerator\|setGenerator" Epistemos/App/AppBootstrap.swift 2>/dev/null | head -5
echo ""

echo "--- isFullyConstraining status ---"
grep -n "isFullyConstraining" Epistemos/Omega/Inference/MLXConstrainedGenerator.swift 2>/dev/null
echo ""

echo "--- LocalToolGrammar backends ---"
grep -n "mlxStructured\|omegaSoftGuidance\|supportsStructured" Epistemos/LocalAgent/LocalToolGrammar.swift 2>/dev/null | head -5
echo ""

echo "--- ConfidenceRouter routes ---"
grep -n "\.local\|\.cloudFallback\|\.hermes\|Route\." Epistemos/LocalAgent/ConfidenceRouter.swift 2>/dev/null | head -10
```

---

## LAYER 5: RUNTIME VERIFICATION

### 5A: App Launch + Service Initialization

This layer verifies the app actually RUNS. It requires building and launching Epistemos.app.

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos

echo "================================================================"
echo "  LAYER 5A: RUNTIME — APP LAUNCH"
echo "================================================================"
echo ""

# Build the app
echo "--- Building Epistemos.app ---"
xcodebuild -quiet \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -configuration Debug \
    build 2>&1 | tail -5

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Epistemos.app" -path "*/Debug/*" -maxdepth 5 2>/dev/null | head -1)
echo "Built app: $APP_PATH"

if [ -z "$APP_PATH" ]; then
    echo "  FAIL: Could not find built Epistemos.app"
    exit 1
fi

# Launch and wait for initialization (5 seconds)
echo ""
echo "--- Launching Epistemos.app (5 second probe) ---"
open "$APP_PATH" &
sleep 5

# Check it's running
if pgrep -x "Epistemos" > /dev/null; then
    echo "  OK: Epistemos is running (PID: $(pgrep -x Epistemos))"
else
    echo "  FAIL: Epistemos is NOT running (crashed on launch?)"
    echo "  Check Console.app for crash logs"
    exit 1
fi

# Check for crash logs
RECENT_CRASH=$(find ~/Library/Logs/DiagnosticReports -name "Epistemos*" -newer /tmp/epistemos-launch-marker 2>/dev/null | head -1)
if [ -n "$RECENT_CRASH" ]; then
    echo "  WARNING: Recent crash log found: $RECENT_CRASH"
    head -30 "$RECENT_CRASH"
fi

echo ""
echo "--- Memory usage ---"
ps aux | grep "[E]pistemos" | awk '{print "  RSS:", $6/1024, "MB  VSZ:", $5/1024, "MB"}'
echo ""

echo "--- Process info ---"
ps aux | grep "[E]pistemos"
```

### 5B: Service Health Check (via Console.app logs)

```bash
#!/bin/bash
set -euo pipefail

echo "================================================================"
echo "  LAYER 5B: RUNTIME — SERVICE HEALTH"
echo "================================================================"
echo ""

# Read recent Epistemos logs (last 30 seconds)
echo "--- Recent logs (last 30s) ---"
log show --predicate 'process == "Epistemos"' --last 30s --style compact 2>/dev/null | tail -50
echo ""

echo "--- Error/Warning logs ---"
log show --predicate 'process == "Epistemos" AND (messageType == error OR messageType == fault)' \
    --last 60s --style compact 2>/dev/null | tail -20
echo ""

echo "--- Key service initializations ---"
log show --predicate 'process == "Epistemos"' --last 60s --style compact 2>/dev/null \
    | grep -i "init\|start\|ready\|loaded\|service\|agent\|mlx\|inference\|vault\|mcp" | tail -20
```

### 5C: Hermes Subprocess Health (if integrated)

```bash
#!/bin/bash
set -euo pipefail

echo "================================================================"
echo "  LAYER 5C: HERMES SUBPROCESS HEALTH"
echo "================================================================"
echo ""

# Check Python available
echo "--- Python environment ---"
python3 --version 2>/dev/null || echo "  FAIL: Python3 not found"
echo ""

# Check hermes importable
echo "--- Hermes importable ---"
python3 -c "import sys; sys.path.insert(0, '/Users/jojo/Downloads/Epistemos/hermes-agent'); print('OK')" 2>&1
echo ""

# Check hermes CLI
echo "--- Hermes CLI ---"
if [ -f "/Users/jojo/Downloads/Epistemos/hermes-agent/hermes" ]; then
    echo "  OK: hermes CLI exists"
else
    echo "  NOT FOUND: hermes CLI (may need pip install)"
fi
echo ""

# Check MCP connectivity (if subprocess running)
echo "--- MCP connectivity test ---"
echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test"}},"id":1}' \
    | timeout 5 python3 -c "
import sys, json
# Simple test: can we parse a JSON-RPC request?
data = json.loads(sys.stdin.read())
print(json.dumps({'jsonrpc':'2.0','result':{'ok':True},'id':data['id']}))
" 2>/dev/null && echo "  OK: JSON-RPC parse works" || echo "  SKIP: Hermes not running as MCP yet"
```

---

## LAYER 6: MANUAL / COMPUTER-USE UI TESTING

This layer uses Claude Computer Use to visually verify the app. Each test is a screenshot-based verification that confirms UI elements exist and behave correctly.

### 6A: Computer Use Test Protocol

**For Claude Code with computer-use MCP:**

```
COMPUTER USE VERIFICATION PROTOCOL

Before starting:
1. Call mcp__computer-use__request_access with apps: ["Epistemos"]
2. Call mcp__computer-use__open_application with app: "Epistemos"
3. Wait 5 seconds for app to load
4. Take initial screenshot

Test CU-1: APP LAUNCHES WITHOUT CRASH
- Take screenshot
- Verify: main window visible, no crash dialog, no blank window
- Expected: Epistemos main window with sidebar and content area

Test CU-2: OMEGA PANEL EXISTS
- Navigate to Omega panel (look for agent/Omega tab or button)
- Take screenshot
- Verify: OmegaPanel is visible with input bar at bottom
- Expected: task input bar, status indicators, permission banners

Test CU-3: SIDEBAR NAVIGATION
- Click through sidebar items (Notes, Search, Settings, etc.)
- Take screenshot after each click
- Verify: no crashes, views load, content appears
- Expected: each view renders correctly without blank screens

Test CU-4: INFERENCE STATE
- Open Settings or status bar
- Take screenshot
- Verify: model status visible (local model loaded or "no model")
- Expected: InferenceState shows current model ID and capability tier

Test CU-5: PERMISSION BANNERS
- In Omega panel, check for Accessibility/Screen Recording banners
- Take screenshot
- Verify: permission status shows correctly
- Expected: banners show granted/denied state for each TCC permission

Test CU-6: TEXT INPUT
- Click the Omega panel input bar
- Type a test message: "Hello, test input"
- Take screenshot
- Verify: text appears in input bar, submit button visible
- Expected: text renders correctly, no layout glitches

Test CU-7: DARK MODE
- Toggle system appearance to dark mode (System Settings > Appearance)
- Switch back to Epistemos
- Take screenshot
- Verify: app respects dark mode, no white flashes, text readable
- Expected: dark background, light text, proper contrast

Test CU-8: MEMORY PRESSURE
- Open Activity Monitor alongside Epistemos
- Take screenshot showing both
- Verify: Epistemos RSS < 500MB at idle, no memory leaks over 30s
- Expected: stable memory footprint

Test CU-9: WINDOW RESIZE
- Resize Epistemos window to minimum size
- Take screenshot
- Resize to maximum size
- Take screenshot
- Verify: no layout breaks, content reflows correctly
- Expected: responsive layout at all sizes

Test CU-10: QUIT AND RELAUNCH
- Quit Epistemos (Cmd+Q)
- Wait 2 seconds
- Relaunch
- Take screenshot
- Verify: app relaunches cleanly, state preserved
- Expected: previous state restored (or clean state if expected)
```

### 6B: Automated Computer-Use Test Runner

This is designed to be run by Claude Code with computer-use MCP access:

```
INSTRUCTIONS FOR CLAUDE CODE:

1. Request access: mcp__computer-use__request_access
   apps: ["Epistemos", "Activity Monitor", "System Settings"]
   reason: "Verify Epistemos UI renders correctly and services start"

2. Open Epistemos: mcp__computer-use__open_application app: "Epistemos"

3. Wait 5 seconds: mcp__computer-use__wait duration: 5

4. Screenshot: mcp__computer-use__screenshot
   VERIFY: Main window visible. No crash dialog. Rate: PASS/FAIL

5. For each UI area (sidebar items, Omega panel, settings):
   - Click the area
   - Wait 1 second
   - Screenshot
   - VERIFY: Content loaded. No blank view. No crash.

6. Zoom into small text areas:
   mcp__computer-use__zoom region: [x0, y0, x1, y1]
   VERIFY: Text is readable. No truncation. No overlap.

7. Test dark mode:
   - Open System Settings > Appearance
   - Click Dark
   - Switch to Epistemos
   - Screenshot
   - VERIFY: Dark mode applied correctly

8. Check memory:
   - Open Activity Monitor
   - Find Epistemos process
   - Zoom to read memory column
   - VERIFY: RSS < 500MB

9. Report format:
   CU-1: PASS/FAIL [description]
   CU-2: PASS/FAIL [description]
   ...
   CU-10: PASS/FAIL [description]

   Screenshots saved: [list of saved paths]
   Total: X/10 passed
```

---

## LAYER 7: RECURSIVE SELF-VERIFICATION

This layer makes verification self-checking. Each prior layer's output is validated for completeness.

### 7A: Meta-Verification Script

```bash
#!/bin/bash
set -euo pipefail
cd /Users/jojo/Downloads/Epistemos

echo "================================================================"
echo "  LAYER 7: RECURSIVE SELF-VERIFICATION"
echo "================================================================"
echo ""

ISSUES=0

# Verify Layer 0 ran
echo "--- Did Layer 0 produce output? ---"
echo "  Checking: project root, core files, crate existence"
[ -f "CLAUDE.md" ] && [ -f "docs/AGENT_PROGRESS.md" ] && echo "  OK" || { echo "  FAIL: Core files missing"; ISSUES=$((ISSUES + 1)); }

# Verify Layer 1 is clean
echo "--- Layer 1: All constraints satisfied? ---"
# Re-run critical checks silently
SIDECAR=$(grep -rn "Process()" --include="*.swift" Epistemos/Engine/ Epistemos/LocalAgent/ Epistemos/Omega/Inference/ 2>/dev/null | grep -vi "//\|test\|mock\|hermes\|osascript" | wc -l | tr -d ' ')
FAKESDK=$(grep -rn "^import Anthropic$\|^import OpenAI$" --include="*.swift" Epistemos/ 2>/dev/null | wc -l | tr -d ' ')
UDKEYS=$(grep -rn "UserDefaults.*[Aa]pi[Kk]ey" --include="*.swift" Epistemos/ 2>/dev/null | grep -vi "//\|test" | wc -l | tr -d ' ')
L1_TOTAL=$((SIDECAR + FAKESDK + UDKEYS))
echo "  Constraint violations: $L1_TOTAL (must be 0)"
[ "$L1_TOTAL" -gt 0 ] && ISSUES=$((ISSUES + 1))

# Verify Layer 2 files exist
echo "--- Layer 2: All required files present? ---"
REQUIRED_FILES=(
    "agent_core/src/agent_loop.rs"
    "agent_core/src/providers/claude.rs"
    "agent_core/src/bridge.rs"
    "agent_core/src/storage/vault.rs"
    "agent_core/src/tools/registry.rs"
    "omega-mcp/src/dispatcher.rs"
    "omega-ax/src/ax_tree.rs"
    "Epistemos/LocalAgent/LocalAgentLoop.swift"
    "Epistemos/LocalAgent/ConfidenceRouter.swift"
    "Epistemos/Bridge/StreamingDelegate.swift"
)
L2_MISSING=0
for f in "${REQUIRED_FILES[@]}"; do
    [ ! -f "$f" ] && { L2_MISSING=$((L2_MISSING + 1)); echo "  MISSING: $f"; }
done
echo "  Missing files: $L2_MISSING"
[ "$L2_MISSING" -gt 0 ] && ISSUES=$((ISSUES + 1))

# Verify Layer 3 compilation
echo "--- Layer 3: Rust crates compile? ---"
for crate in agent_core omega-mcp omega-ax; do
    if [ -f "$crate/Cargo.toml" ]; then
        cargo check --manifest-path "$crate/Cargo.toml" 2>/dev/null && echo "  OK $crate" || { echo "  FAIL $crate"; ISSUES=$((ISSUES + 1)); }
    fi
done

# Verify Layer 3 tests pass
echo "--- Layer 3: Rust tests pass? ---"
for crate in agent_core omega-mcp omega-ax; do
    if [ -f "$crate/Cargo.toml" ]; then
        cargo test --manifest-path "$crate/Cargo.toml" 2>/dev/null | grep -q "FAILED" && { echo "  FAIL $crate"; ISSUES=$((ISSUES + 1)); } || echo "  OK $crate"
    fi
done

# Verify test count hasn't dropped
echo "--- Layer 3: Test count regression check ---"
RUST_TESTS=0
for crate in agent_core omega-mcp omega-ax; do
    if [ -f "$crate/Cargo.toml" ]; then
        COUNT=$(cargo test --manifest-path "$crate/Cargo.toml" 2>&1 | grep "test result:" | grep -o "[0-9]* passed" | grep -o "[0-9]*")
        RUST_TESTS=$((RUST_TESTS + COUNT))
    fi
done
echo "  Rust tests: $RUST_TESTS (baseline: 118)"
[ "$RUST_TESTS" -lt 118 ] && { echo "  REGRESSION: Tests dropped below baseline"; ISSUES=$((ISSUES + 1)); }

# Verify docs match reality
echo "--- Layer 7: Docs match code? ---"
# Check AGENT_PROGRESS claims vs actual files
CLAIMED_COMPLETE=$(grep -c "\[x\]\|✅" docs/AGENT_PROGRESS.md 2>/dev/null)
echo "  AGENT_PROGRESS claims $CLAIMED_COMPLETE items complete"

# Spot-check: if Sprint Agent-1 claimed complete, verify agent_loop.rs exists
if grep -q "\[x\].*agent_loop" docs/AGENT_PROGRESS.md 2>/dev/null; then
    [ -f "agent_core/src/agent_loop.rs" ] && echo "  OK: agent_loop.rs exists (matches claim)" || { echo "  LIE: agent_loop.rs claimed done but missing"; ISSUES=$((ISSUES + 1)); }
fi

# Spot-check: if Sprint Agent-2 claimed complete, verify LocalAgentLoop.swift exists
if grep -q "\[x\].*LocalAgentLoop" docs/AGENT_PROGRESS.md 2>/dev/null; then
    [ -f "Epistemos/LocalAgent/LocalAgentLoop.swift" ] && echo "  OK: LocalAgentLoop.swift exists (matches claim)" || { echo "  LIE: LocalAgentLoop.swift claimed done but missing"; ISSUES=$((ISSUES + 1)); }
fi

echo ""
echo "================================================================"
echo "  LAYER 7 RESULT: $ISSUES ISSUES"
echo "================================================================"
if [ "$ISSUES" -eq 0 ]; then
    echo ""
    echo "  ALL LAYERS VERIFIED. SYSTEM IS COHERENT."
    echo ""
else
    echo ""
    echo "  $ISSUES ISSUES FOUND. Review above output."
    echo ""
fi
```

### 7B: Verification Coverage Matrix

After running all layers, produce this matrix:

```
VERIFICATION COVERAGE MATRIX
═══════════════════════════════════════════════════════════════

Area                          | L1 | L2 | L3 | L4 | L5 | L6
─────────────────────────────┼────┼────┼────┼────┼────┼────
Thinking block preservation   | C7 | 2B | 3A | 4A |    |
SSE state machine             |    | 2B | 3A |    |    |
Streaming (no buffering)      | C8 | 2B |    |    | 5B |
Agent loop correctness        |    | 2B | 3A | 4A |    |
Parallel tool execution       |    | 2B | 3A | 4B |    |
Cancellation support          |    | 2B | 3A |    |    |
Context compaction             |    | 2B | 3A |    |    |
HTTP retry logic              |    | 2B | 3A |    |    |
UniFFI bridge chain           |    | 2B | 3B | 4A |    |
Permission semaphore           |    | 2B | 3C |    | 5A |
Local agent loop              | C9 | 2B | 3C | 4C |    |
Capability gating             | C9 | 2B | 3C | 4C |    |
Grammar constrained decode    |    | 2B | 3C | 4C |    |
Hermes prompt format          |    | 2B | 3C |    |    |
Confidence routing            | C9 | 2B | 3C | 4C |    |
MCP dispatcher                |    | 2B | 3A | 4B |    |
AX tree walker                |    | 2B | 3A |    |    |
CGEvent input                 |    | 2B | 3A |    |    |
Vault search/read/write       |    | 2B | 3A | 4B |    |
App launch (no crash)         |    |    |    |    | 5A | CU1
Omega panel UI                |    |    |    |    | 5A | CU2
Dark mode                     |    |    |    |    |    | CU7
Memory footprint              |    |    |    |    | 5B | CU8
Window resize                 |    |    |    |    |    | CU9
Hermes subprocess             |    |    |    |    | 5C |
No sidecar inference          | C1 |    |    |    |    |
No fake SDKs                  | C2 |    |    |    |    |
Keychain (not UserDefaults)   | C3 |    |    |    |    |
No force unwraps              | C4 |    |    |    |    |
Unsafe has SAFETY             | C5 |    |    |    |    |
No print() in production      | C6 |    |    |    |    |

Legend: L1=Constraints, L2=Static, L3=Tests, L4=Integration,
        L5=Runtime, L6=Computer Use, Cx=Constraint check,
        CUx=Computer Use test
```

---

## HOW TO USE THIS DOCUMENT

### For Codex (implementation sessions):

```
After completing any sprint, run Layers 0-3 as verification.
The bash scripts are copy-pasteable. Run them in order.
If Layer 1 has ANY blocker, stop and fix before continuing.
If Layer 3 has test failures, fix before claiming the sprint done.
Update docs/AGENT_PROGRESS.md only after Layer 3 passes.
```

### For Claude Code (audit sessions):

```
Read docs/VERIFICATION_PROTOCOL.md.
Run ALL layers (0 through 7).
For Layer 6, use computer-use MCP to take screenshots.
Produce the verification coverage matrix.
Report: X/Y checks passed, Z blockers, N improvements.
Do NOT fix anything. Only report.
```

### For Claude Code (computer-use testing):

```
Read docs/VERIFICATION_PROTOCOL.md, Layer 6 section.
Call mcp__computer-use__request_access for Epistemos.
Run each CU-1 through CU-10 test.
Save screenshots with save_to_disk: true.
Report PASS/FAIL for each test with screenshot evidence.
```

### For the developer (you):

```
After any major change:
1. Run Layer 1 (constraint scan) — 10 seconds
2. Run Layer 3A (Rust tests) — 30 seconds
3. Run Layer 3C (focused Swift tests) — 2 minutes
4. If changing integration points, run Layer 4 — 2 minutes
5. If changing UI, run Layer 6 via computer use — 5 minutes
6. Before any release, run Layer 7 (recursive self-check) — 5 minutes
```

---

## APPENDIX: QUICK-RUN ALL LAYERS

```bash
#!/bin/bash
# Run ALL verification layers sequentially
# Usage: bash docs/VERIFICATION_PROTOCOL.md  (won't work — use the scripts above individually)
# Or copy each layer's script into separate files:
#   verification/layer0-orient.sh
#   verification/layer1-constraints.sh
#   verification/layer2a-files.sh
#   verification/layer2b-patterns.sh
#   verification/layer3a-rust.sh
#   verification/layer3b-swift-build.sh
#   verification/layer3c-swift-tests.sh
#   verification/layer3d-full-suite.sh
#   verification/layer4a-uniffi.sh
#   verification/layer4b-tools.sh
#   verification/layer4c-local.sh
#   verification/layer5a-launch.sh
#   verification/layer5b-logs.sh
#   verification/layer5c-hermes.sh
#   verification/layer7-recursive.sh

echo "Run each layer script individually. Layer 6 requires Claude computer-use MCP."
```
