# Epistemos Agent System — Post-Implementation Audit
## For Claude Code (NOT Codex) — Verify, Never Implement

---

## YOUR ROLE

You are an architectural auditor reviewing work done by Codex on the Epistemos agent system. You have deep knowledge of the system's architecture: Swift 6 + Rust (tokio/UniFFI) + Metal, a living agentic loop in Rust, grammar-constrained local inference via MLX-Swift, and a five-layer anti-drift defense system.

**You do NOT write code. You do NOT fix anything. You only read, grep, trace, and report.**

If you find something broken, you describe exactly what's wrong, where it is, what it should be, and why — so the next implementation session can fix it with zero ambiguity. Your output is a structured audit report that becomes the input for the next Codex sprint.

---

## STEP 0: ORIENT (run first, every time)

```bash
echo "=== ORIENTATION ==="
echo ""

echo "--- Project structure ---"
ls -la CLAUDE.md .claude/settings.json .claude/context-essentials.txt 2>/dev/null
echo ""

echo "--- Progress state ---"
cat docs/PROGRESS.md 2>/dev/null || echo "NO PROGRESS.md FOUND"
echo ""

echo "--- Agent core exists? ---"
ls agent_core/src/ 2>/dev/null || echo "agent_core/src/ DOES NOT EXIST"
echo ""

echo "--- File counts ---"
echo "Rust files in agent_core: $(find agent_core -name '*.rs' 2>/dev/null | wc -l)"
echo "Swift bridge files: $(find Epistemos/Bridge Epistemos/ViewModels Epistemos/Views Epistemos/LocalAgent -name '*.swift' 2>/dev/null | wc -l)"
echo "Total Swift files: $(find . -name '*.swift' -not -path '*/.*' | wc -l)"
echo "Total Rust files: $(find . -name '*.rs' -not -path '*/.*' | wc -l)"
echo "Test files: $(find . -name '*Test*' -o -name '*test*' | grep -E '\.(swift|rs)$' | wc -l)"
echo ""

echo "--- Anti-drift system intact? ---"
[ -f "CLAUDE.md" ] && echo "✅ CLAUDE.md" || echo "❌ CLAUDE.md MISSING"
[ -f ".claude/settings.json" ] && echo "✅ .claude/settings.json" || echo "❌ settings.json MISSING"
[ -f ".claude/context-essentials.txt" ] && echo "✅ context-essentials.txt" || echo "❌ context-essentials.txt MISSING"
[ -f "docs/agent-system/AGENT_ARCHITECTURE.md" ] && echo "✅ AGENT_ARCHITECTURE.md" || echo "❌ AGENT_ARCHITECTURE.md MISSING"
[ -f "docs/agent-system/GAP_ANALYSIS.md" ] && echo "✅ GAP_ANALYSIS.md" || echo "❌ GAP_ANALYSIS.md MISSING"
echo ""

echo "--- What sprints are marked done? ---"
grep -E "^\- \[x\]|^\- \[X\]" docs/PROGRESS.md 2>/dev/null | head -30 || echo "No completed items found"
echo ""

echo "--- What sprints are still pending? ---"
grep -E "^\- \[ \]" docs/PROGRESS.md 2>/dev/null | head -30 || echo "No pending items found"
```

After running orientation, state: "Audit starting. Codex completed: [what's checked off]. Auditing: [what you'll verify]. Scope: [per-sprint / full]."

---

## STEP 1: CONSTRAINT VIOLATIONS (check these FIRST — any violation is a blocker)

These are the non-negotiable rules. A single violation means the sprint is NOT complete regardless of what PROGRESS.md says.

```bash
echo "════════════════════════════════════════════════════════════"
echo "  CONSTRAINT VIOLATION SCAN"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── C1: No sidecar processes ──────────────────────────────────────────
echo "C1: SIDECAR PATTERNS (must be 0)"
SIDECAR=$(grep -rn "Process()\|NSTask()\|posix_spawn\|localhost.*inference\|127\.0\.0\.1.*infer" \
    --include="*.swift" --include="*.rs" \
    | grep -v "//\|test\|Test\|mock\|Mock\|BLOCKED\|WARNING\|oMLX" \
    | wc -l | tr -d ' ')
echo "  Found: $SIDECAR"
if [ "$SIDECAR" -gt 0 ]; then
    echo "  ❌ BLOCKER — sidecar patterns detected:"
    grep -rn "Process()\|NSTask()\|posix_spawn\|localhost.*inference" \
        --include="*.swift" --include="*.rs" \
        | grep -v "//\|test\|Test\|mock\|Mock\|BLOCKED\|WARNING\|oMLX"
fi
echo ""

# ── C2: No fake SDKs ─────────────────────────────────────────────────
echo "C2: FAKE SDK IMPORTS (must be 0)"
FAKESDK=$(grep -rn "^import Anthropic$\|^import OpenAI$" --include="*.swift" | wc -l | tr -d ' ')
echo "  Found: $FAKESDK"
if [ "$FAKESDK" -gt 0 ]; then
    echo "  ❌ BLOCKER — nonexistent SDK imports:"
    grep -rn "^import Anthropic$\|^import OpenAI$" --include="*.swift"
fi
echo ""

# ── C3: API keys not in UserDefaults ──────────────────────────────────
echo "C3: CREDENTIALS IN USERDEFAULTS (must be 0)"
UDKEYS=$(grep -rn "UserDefaults.*[Aa]pi[Kk]ey\|UserDefaults.*token\|UserDefaults.*secret\|UserDefaults.*password" \
    --include="*.swift" | grep -v "//\|test\|Test" | wc -l | tr -d ' ')
echo "  Found: $UDKEYS"
if [ "$UDKEYS" -gt 0 ]; then
    echo "  ❌ BLOCKER — credentials stored in UserDefaults:"
    grep -rn "UserDefaults.*[Aa]pi[Kk]ey\|UserDefaults.*token\|UserDefaults.*secret" \
        --include="*.swift" | grep -v "//\|test\|Test"
fi
echo ""

# ── C4: Force unwraps in production ───────────────────────────────────
echo "C4: FORCE UNWRAPS IN PRODUCTION (should be 0, report count)"
FORCE=$(grep -rn '![^=]' --include="*.swift" \
    agent_core/ Epistemos/Bridge/ Epistemos/ViewModels/ Epistemos/Views/ Epistemos/LocalAgent/ 2>/dev/null \
    | grep -v "//\|test\|Test\|mock\|Mock\|IBOutlet\|IBAction\|!=\|guard.*!\|#expect\|#require" \
    | grep '\.unwrap()\|as!.\|try!' \
    | wc -l | tr -d ' ')
echo "  Found: $FORCE"
[ "$FORCE" -gt 0 ] && echo "  ⚠️  Force unwraps detected — review each one"
echo ""

# ── C5: Unsafe blocks without SAFETY comments ────────────────────────
echo "C5: UNSAFE WITHOUT SAFETY COMMENT (must be 0)"
if [ -d "agent_core" ]; then
    UNSAFETY=$(grep -rn "unsafe" --include="*.rs" agent_core/ | grep -v "SAFETY\|//\|test" | wc -l | tr -d ' ')
    echo "  Found: $UNSAFETY"
    if [ "$UNSAFETY" -gt 0 ]; then
        echo "  ❌ BLOCKER — unsafe blocks without // SAFETY: comment:"
        grep -B1 -A1 "unsafe" --include="*.rs" -rn agent_core/ | grep -v "SAFETY"
    fi
else
    echo "  ℹ️  agent_core/ not found — skipping"
fi
echo ""

# ── C6: print() in production paths ───────────────────────────────────
echo "C6: PRINT() IN PRODUCTION (should be 0)"
PRINTS=$(grep -rn "print(" --include="*.swift" \
    Epistemos/Bridge/ Epistemos/ViewModels/ Epistemos/Views/ Epistemos/LocalAgent/ 2>/dev/null \
    | grep -v "//\|test\|Test\|mock\|Mock\|Log\.\|os_log\|logger" \
    | wc -l | tr -d ' ')
echo "  Found: $PRINTS"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  CONSTRAINT SCAN COMPLETE"
echo "════════════════════════════════════════════════════════════"
```

---

## STEP 2: AGENT ARCHITECTURE AUDIT (Sprint Agent-1)

Only run this section if Sprint Agent-1 is marked complete in PROGRESS.md.

```bash
echo "════════════════════════════════════════════════════════════"
echo "  SPRINT AGENT-1: LIVING LOOP AUDIT"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── 2.1: File existence ───────────────────────────────────────────────
echo "--- 2.1: Required files ---"
for f in \
    agent_core/Cargo.toml \
    agent_core/src/lib.rs \
    agent_core/src/types.rs \
    agent_core/src/provider.rs \
    agent_core/src/agent_loop.rs \
    agent_core/src/bridge.rs \
    agent_core/src/error.rs \
    agent_core/src/prompts.rs \
    agent_core/src/session.rs \
    agent_core/src/routing.rs \
    agent_core/src/providers/claude.rs \
    agent_core/src/tools/registry.rs \
    agent_core/src/storage/vault.rs \
    Epistemos/Bridge/StreamingDelegate.swift \
    Epistemos/ViewModels/AgentViewModel.swift \
    Epistemos/Views/OmegaPanel.swift; do
    [ -f "$f" ] && echo "  ✅ $f ($(wc -l < "$f" | tr -d ' ') lines)" || echo "  ❌ MISSING: $f"
done
echo ""

# ── 2.2: Thinking block preservation ─────────────────────────────────
echo "--- 2.2: Thinking block preservation (THE #1 FIX) ---"
echo "Looking for: assistant message push that includes ALL content blocks"
echo ""
if [ -f "agent_core/src/agent_loop.rs" ]; then
    # Must find a line that pushes response_blocks (not filtered) into messages
    PRESERVE=$(grep -n "response_blocks" agent_core/src/agent_loop.rs)
    echo "$PRESERVE"
    echo ""
    
    # Check for the WRONG pattern: filtering to text-only
    WRONG=$(grep -n "filter.*Text\|text_only\|strip.*thinking\|remove.*thinking" agent_core/src/agent_loop.rs)
    if [ -n "$WRONG" ]; then
        echo "  ❌ BLOCKER: Found thinking-stripping pattern:"
        echo "$WRONG"
    else
        echo "  ✅ No thinking-stripping patterns found"
    fi
    echo ""
    
    # Check ContentBlock enum has signature field
    echo "Checking ContentBlock::Thinking has signature field:"
    grep -A3 "Thinking" agent_core/src/types.rs 2>/dev/null | head -6
else
    echo "  ❌ agent_loop.rs does not exist"
fi
echo ""

# ── 2.3: SSE state machine completeness ──────────────────────────────
echo "--- 2.3: ClaudeProvider SSE state machine ---"
if [ -f "agent_core/src/providers/claude.rs" ]; then
    echo "Event types handled:"
    for event in "content_block_start" "content_block_delta" "content_block_stop" \
                 "message_delta" "message_stop" "ping" "error"; do
        COUNT=$(grep -c "$event" agent_core/src/providers/claude.rs 2>/dev/null)
        [ "$COUNT" -gt 0 ] && echo "  ✅ $event ($COUNT references)" || echo "  ❌ MISSING: $event"
    done
    echo ""
    
    echo "Delta types handled:"
    for delta in "thinking_delta" "text_delta" "input_json_delta" "signature_delta"; do
        COUNT=$(grep -c "$delta" agent_core/src/providers/claude.rs 2>/dev/null)
        [ "$COUNT" -gt 0 ] && echo "  ✅ $delta ($COUNT references)" || echo "  ❌ MISSING: $delta"
    done
    echo ""
    
    echo "API configuration:"
    grep -n "adaptive\|interleaved-thinking\|anthropic-version\|2023-06-01\|anthropic-beta" \
        agent_core/src/providers/claude.rs 2>/dev/null
    echo ""
    
    echo "Server tools:"
    for tool in "web_search_20250305" "web_fetch_20250305" "code_execution_20250825"; do
        grep -q "$tool" agent_core/src/providers/claude.rs 2>/dev/null \
            && echo "  ✅ $tool" || echo "  ⚠️  $tool not found (optional but expected)"
    done
else
    echo "  ❌ claude.rs does not exist"
fi
echo ""

# ── 2.4: Agentic loop correctness ────────────────────────────────────
echo "--- 2.4: Agentic loop patterns ---"
if [ -f "agent_core/src/agent_loop.rs" ]; then
    echo "Parallel tool execution:"
    grep -n "try_join_all\|join_all" agent_core/src/agent_loop.rs && echo "  ✅" || echo "  ❌ MISSING"
    echo ""
    
    echo "Cancellation support:"
    grep -n "is_cancelled\|CancellationToken\|cancel" agent_core/src/agent_loop.rs | head -5
    CANCEL_COUNT=$(grep -c "is_cancelled" agent_core/src/agent_loop.rs 2>/dev/null)
    [ "$CANCEL_COUNT" -ge 2 ] && echo "  ✅ Checked $CANCEL_COUNT times (should be ≥2: once per turn + once during stream)" \
        || echo "  ⚠️  Only $CANCEL_COUNT cancellation checks (need ≥2)"
    echo ""
    
    echo "Agent-decides termination:"
    grep -n "EndTurn\|end_turn" agent_core/src/agent_loop.rs | head -3
    echo ""
    
    echo "Context compaction:"
    grep -n "compact\|context_threshold\|estimate_tokens" agent_core/src/agent_loop.rs | head -5
    echo ""
    
    echo "Streaming (not buffering) — delegate calls inside stream loop:"
    grep -n "delegate.*on_text_delta\|delegate.*on_thinking_delta" agent_core/src/agent_loop.rs | head -5
    STREAM_COUNT=$(grep -c "delegate\." agent_core/src/agent_loop.rs 2>/dev/null)
    echo "  Total delegate calls: $STREAM_COUNT (should be 5+)"
    echo ""
    
    echo "Max turns safety rail:"
    grep -n "max_turns\|MaxTurnsExceeded" agent_core/src/agent_loop.rs | head -3
else
    echo "  ❌ agent_loop.rs does not exist"
fi
echo ""

# ── 2.5: UniFFI bridge correctness ───────────────────────────────────
echo "--- 2.5: UniFFI bridge ---"
if [ -f "agent_core/src/bridge.rs" ]; then
    echo "AgentConfig::from_ffi():"
    grep -n "from_ffi\|from_ffi" agent_core/src/bridge.rs && echo "  ✅" || echo "  ❌ MISSING (was a gap in original spec)"
    echo ""
    
    echo "Session management integration:"
    grep -n "GlobalSessions\|register\|cancel" agent_core/src/bridge.rs | head -5
    echo ""
    
    echo "UniFFI exports:"
    grep -n "uniffi::export" agent_core/src/bridge.rs
else
    echo "  ❌ bridge.rs does not exist"
fi
echo ""

# ── 2.6: HTTP retry logic ────────────────────────────────────────────
echo "--- 2.6: HTTP retry logic ---"
if [ -f "agent_core/src/error.rs" ]; then
    echo "Retry classification:"
    for status in "429" "500" "502" "503" "400" "401" "403"; do
        grep -q "$status" agent_core/src/error.rs && echo "  ✅ $status handled" || echo "  ❌ $status not handled"
    done
    echo ""
    
    echo "Backoff strategy:"
    grep -n "exponential\|backoff\|jitter\|Retry" agent_core/src/error.rs | head -5
else
    echo "  ❌ error.rs does not exist — NO RETRY LOGIC"
fi
echo ""

# ── 2.7: Swift bridge correctness ────────────────────────────────────
echo "--- 2.7: Swift bridge layer ---"

if [ -f "Epistemos/Bridge/StreamingDelegate.swift" ]; then
    echo "Permission timeout (must exist — prevents tokio thread starvation):"
    grep -n "timeout\|120\|permissionTimeout" Epistemos/Bridge/StreamingDelegate.swift
    HAS_TIMEOUT=$(grep -c "timeout\|120" Epistemos/Bridge/StreamingDelegate.swift 2>/dev/null)
    [ "$HAS_TIMEOUT" -gt 0 ] && echo "  ✅ Timeout present" || echo "  ❌ BLOCKER: No permission timeout — will starve tokio threads"
    echo ""
    
    echo "DispatchSemaphore (NOT async/await for permission gate):"
    grep -n "DispatchSemaphore\|semaphore" Epistemos/Bridge/StreamingDelegate.swift | head -3
    grep -q "DispatchSemaphore" Epistemos/Bridge/StreamingDelegate.swift \
        && echo "  ✅ Uses DispatchSemaphore" || echo "  ❌ BLOCKER: Must use DispatchSemaphore, not async/await"
fi
echo ""

if [ -f "Epistemos/ViewModels/AgentViewModel.swift" ]; then
    echo "Bounded buffering (NOT .unbounded):"
    grep -n "bufferingNewest\|bufferingOldest\|unbounded" Epistemos/ViewModels/AgentViewModel.swift
    grep -q "unbounded" Epistemos/ViewModels/AgentViewModel.swift \
        && echo "  ❌ Uses unbounded buffering — OOM risk on long sessions" \
        || echo "  ✅ Not using unbounded"
    echo ""
    
    echo "Task.detached (avoids @MainActor deadlock on Rust call):"
    grep -n "Task.detached" Epistemos/ViewModels/AgentViewModel.swift
    grep -q "Task.detached" Epistemos/ViewModels/AgentViewModel.swift \
        && echo "  ✅" || echo "  ⚠️  Should use Task.detached for Rust bridge call"
    echo ""
    
    echo "Session ID tracking (for proper cancellation):"
    grep -n "sessionId\|activeSessionId\|session_id" Epistemos/ViewModels/AgentViewModel.swift | head -3
fi
echo ""

# ── 2.8: Compilation ─────────────────────────────────────────────────
echo "--- 2.8: Compilation check ---"
if [ -f "agent_core/Cargo.toml" ]; then
    echo "Rust:"
    cd agent_core && cargo check 2>&1 | tail -10 && cd ..
else
    echo "  ⚠️  No Cargo.toml — Rust crate not set up"
fi
echo ""

echo "Swift (build check):"
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  SPRINT AGENT-1 AUDIT COMPLETE"
echo "════════════════════════════════════════════════════════════"
```

---

## STEP 3: LOCAL AGENT AUDIT (Sprint Agent-2)

Only run if Sprint Agent-2 is marked complete.

```bash
echo "════════════════════════════════════════════════════════════"
echo "  SPRINT AGENT-2: LOCAL AGENT AUDIT"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "--- Required files ---"
for f in \
    Epistemos/LocalAgent/HermesPromptBuilder.swift \
    Epistemos/LocalAgent/LocalToolGrammar.swift \
    Epistemos/LocalAgent/LocalAgentLoop.swift \
    Epistemos/LocalAgent/ConfidenceRouter.swift; do
    [ -f "$f" ] && echo "  ✅ $f" || echo "  ❌ MISSING: $f"
done
echo ""

echo "--- Grammar-constrained decoding ---"
grep -rn "MLXStructured\|SequenceFormat\|TriggeredTagsFormat\|JSONSchemaFormat\|Grammar" \
    Epistemos/LocalAgent/ --include="*.swift" 2>/dev/null | head -10
echo ""

echo "--- Hermes-3 prompt format ---"
grep -rn "tool_call\|scratch_pad\|im_start\|im_end\|tools>" \
    Epistemos/LocalAgent/ --include="*.swift" 2>/dev/null | head -10
echo ""

echo "--- Honest capability gating (CRITICAL) ---"
echo "Local models must NOT get agent capability:"
grep -rn "canActAsAgent\|agent.*disabled\|agent.*local\|requiresCloudModel" \
    --include="*.swift" 2>/dev/null | head -10
echo ""

echo "--- Confidence router ---"
grep -rn "confidence\|threshold\|escalat\|fallback\|SLM.*LLM\|local.*cloud" \
    Epistemos/LocalAgent/ConfidenceRouter.swift 2>/dev/null | head -10
echo ""

echo "--- History trimming (prevents context overflow) ---"
grep -rn "history.*count\|suffix\|trimm\|truncat" \
    Epistemos/LocalAgent/LocalAgentLoop.swift 2>/dev/null | head -5
```

---

## STEP 4: CROSS-SYSTEM INTEGRATION AUDIT

Run this after multiple sprints are complete to verify the pieces actually connect.

```bash
echo "════════════════════════════════════════════════════════════"
echo "  CROSS-SYSTEM INTEGRATION AUDIT"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── Does the Rust bridge actually export functions Swift can call? ─────
echo "--- UniFFI exports (Rust side) ---"
grep -rn "uniffi::export" --include="*.rs" agent_core/ 2>/dev/null
echo ""

# ── Does Swift actually call those exports? ───────────────────────────
echo "--- Swift calls to Rust (bridge calls) ---"
grep -rn "runAgentSession\|cancelAgentSession\|RustAgentCore" \
    --include="*.swift" Epistemos/ 2>/dev/null | head -10
echo ""

# ── Tool registry ↔ vault storage connection ─────────────────────────
echo "--- Tool registry uses VaultBackend ---"
grep -rn "VaultBackend\|VaultStore\|vault" --include="*.rs" agent_core/src/tools/ 2>/dev/null | head -5
echo ""

# ── Provider ↔ loop connection ────────────────────────────────────────
echo "--- Agent loop uses AgentProvider ---"
grep -rn "AgentProvider\|provider\." --include="*.rs" agent_core/src/agent_loop.rs 2>/dev/null | head -5
echo ""

# ── Session ↔ bridge connection ───────────────────────────────────────
echo "--- Bridge uses GlobalSessions ---"
grep -rn "GlobalSessions" --include="*.rs" agent_core/src/bridge.rs 2>/dev/null | head -5
echo ""

# ── Anti-drift hooks still intact? ───────────────────────────────────
echo "--- Anti-drift hooks ---"
if [ -f ".claude/settings.json" ]; then
    echo "Hooks configured:"
    grep -o '"matcher"[^,]*' .claude/settings.json
    echo ""
    echo "Post-compact hook fires context-essentials:"
    grep "context-essentials" .claude/settings.json && echo "  ✅" || echo "  ❌ MISSING"
else
    echo "  ❌ .claude/settings.json not found — anti-drift disabled"
fi
echo ""

# ── Existing Omega system not broken ─────────────────────────────────
echo "--- Existing systems intact ---"
echo "OrchestratorState:"
grep -rn "OrchestratorState" --include="*.swift" | head -3
echo ""
echo "ResearchOrchestrator:"
grep -rn "ResearchOrchestrator" --include="*.swift" | head -3
echo ""
echo "MCPBridge:"
grep -rn "MCPBridge" --include="*.swift" | head -3
echo ""

# ── Test suite ────────────────────────────────────────────────────────
echo "--- Test suite ---"
echo "Running tests (this may take a while)..."
swift test 2>&1 | tail -15
```

---

## STEP 5: DEEP READ AUDIT (manual review — read the actual code)

After running the automated checks above, READ these specific files and verify the logic is correct. Don't just grep — actually trace the code flow.

**For agent_loop.rs, verify this exact flow:**
1. Context bootstrap: vault_search runs before first inference
2. The `loop` starts with turn counting
3. Cancellation checked before streaming
4. Stream is opened via `provider.stream_message()`
5. Inside the stream loop, EVERY event type forwards to the delegate IMMEDIATELY
6. After stream ends, stop_reason is checked: EndTurn → return, ToolUse → execute tools → continue, MaxTokens → compact → continue
7. Before tool execution, the FULL response_blocks (including thinking) are pushed to messages
8. Tools execute in parallel via try_join_all
9. Tool results are pushed as user message
10. Context size is estimated and compaction triggers if over threshold

**For claude.rs, verify:**
1. The SSE parser handles ALL event types (not just text_delta)
2. Signature deltas are accumulated and stored in ContentBlock::Thinking
3. The thinking config uses `"type": "adaptive"` not `"type": "enabled"`
4. The beta header is `interleaved-thinking-2025-05-14`

**For StreamingDelegate.swift, verify:**
1. waitForPermission uses DispatchSemaphore, NOT async/await
2. There IS a timeout (should be ~120 seconds)
3. The semaphore is registered BEFORE yielding the permission event (prevents race condition)
4. resolvePermission is callable from @MainActor without deadlock

Read each file. Report what you found. Do NOT fix anything.

---

## OUTPUT FORMAT

For every item you check, report exactly one of:

```
✅ VERIFIED: [item] — confirmed at [file:line], works correctly
❌ MISSING:  [item] — not found, expected at [location], spec says [what it should be]
⚠️ PARTIAL:  [item] — exists at [file:line] but incomplete: [what's wrong]
🔴 BLOCKER:  [item] — constraint violation, must be fixed before sprint is complete
💡 IMPROVE:  [item] — works but could be better: [suggestion]
```

At the end, produce a summary:

```
AUDIT SUMMARY
═══════════════
Sprints audited: [list]
Total checks: [N]
✅ Verified: [N]
❌ Missing: [N]
⚠️ Partial: [N]
🔴 Blockers: [N]
💡 Improvements: [N]

BLOCKERS (fix before continuing):
1. [description]
2. [description]

NEXT ACTIONS (for the next Codex session):
1. [specific task with file path]
2. [specific task with file path]
```

---

## HOW TO USE THIS AUDIT

**After a single sprint:**
```
I just finished Sprint Agent-1 with Codex. Audit it.
Read docs/audit-prompts/agent-audit.md and run Steps 0, 1, and 2.
Report findings. Do NOT write any code.
```

**After multiple sprints:**
```
Codex completed Sprints Agent-1 through Agent-3. Full audit.
Read docs/audit-prompts/agent-audit.md and run all steps.
Report findings. Do NOT write any code.
```

**After the entire implementation:**
```
The agent system implementation is complete. Run the full audit
including Step 4 (cross-system integration) and Step 5 (deep read).
Read docs/audit-prompts/agent-audit.md. Report everything.
Do NOT write any code.
```
