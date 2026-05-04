# CODEX AGENT SYSTEM BOOTSTRAP

> **Index status**: CANONICAL-OPERATIONAL — One-prompt Codex bootstrap with self-install script + Phase 0-N implementation phases.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.


## The One Prompt That Builds Everything

**Give this entire file to Codex as your prompt. It self-installs, self-directs, and builds.**

---

## PHASE 0: SELF-INSTALL (run this FIRST, before any implementation)

Before writing ANY agent code, run the install script. It copies all architecture docs, sprint files, hooks, and pre-built source files from `~/Downloads/release/for codex/` into the correct project locations. After install, every subsequent session auto-reads the right docs and fires the right hooks.

```bash
# ── 0.1: Run the install script ──────────────────────────────────────────
# This creates all directories, copies all files from the release folder,
# backs up existing CLAUDE.md and settings.json, and verifies placement.
bash docs/agent-system/install.sh

# If the install script doesn't exist yet, bootstrap it:
# mkdir -p docs/agent-system
# cp "$HOME/Downloads/release/for codex/docs/agent-system/install.sh" docs/agent-system/install.sh
# bash docs/agent-system/install.sh
```

If the install script reports any ❌ MISSING items, copy them manually from `~/Downloads/release/for codex/` before proceeding. The key files and where they go:

```
~/Downloads/release/for codex/
├── CLAUDE.md                              → CLAUDE.md (project root)
├── .claude/
│   ├── settings.json                      → .claude/settings.json
│   └── context-essentials.txt             → .claude/context-essentials.txt
├── docs/
│   ├── CODEX_AGENT_BOOTSTRAP.md           → docs/CODEX_AGENT_BOOTSTRAP.md (this file)
│   ├── AGENT_PROGRESS.md                  → append to docs/PROGRESS.md
│   ├── agent-system/
│   │   └── install.sh                     → docs/agent-system/install.sh
│   └── sprint-sessions/
│       └── sprint-agent-1-living-loop.md  → docs/sprint-sessions/sprint-agent-1-living-loop.md
├── epistemos-agent-core/
│   ├── CLAUDE.md                          → docs/agent-system/AGENT_ARCHITECTURE.md
│   ├── EPISTEMOS_GAP_ANALYSIS.md          → docs/agent-system/GAP_ANALYSIS.md
│   └── src/
│       ├── *.rs                           → agent_core/src/*.rs (pre-built Rust files)
│       ├── storage/vault.rs               → agent_core/src/storage/vault.rs
│       └── swift/*.swift                  → Epistemos/Bridge/, ViewModels/, Views/
├── EPISTEMOS_FUSED_v3.md                  → docs/EPISTEMOS_FUSED_v3.md
├── epistemos-deep-analysis.md             → docs/epistemos-deep-analysis.md
├── ANTI_DRIFT_SYSTEM.md                   → docs/ANTI_DRIFT_SYSTEM.md
└── Agent_Architecture_and_Implementation_Details.pdf
                                           → docs/agent-system/
```

```bash
# ── 0.2: Verify everything landed ───────────────────────────────────────
echo "=== POST-INSTALL VERIFICATION ==="

for f in \
    CLAUDE.md \
    .claude/settings.json \
    .claude/context-essentials.txt \
    docs/agent-system/AGENT_ARCHITECTURE.md \
    docs/agent-system/GAP_ANALYSIS.md \
    docs/CODEX_AGENT_BOOTSTRAP.md \
    docs/sprint-sessions/sprint-agent-1-living-loop.md \
    docs/PROGRESS.md; do
    [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

echo ""
echo "=== PRE-FLIGHT: Verifying existing codebase ==="

echo "1. Existing model enum:"
grep -r "LocalTextModelID" --include="*.swift" | head -5

echo "2. Existing Omega agent system:"
grep -r "OrchestratorState\|ResearchOrchestrator\|MCPBridge" --include="*.swift" | head -5

echo "3. Existing test count:"
find . -name "*Test*.swift" -o -name "*test*.rs" | wc -l

echo "4. Sidecar check (should be 0):"
grep -rn "Process()\|NSTask\|posix_spawn" --include="*.swift" | grep -v "//\|test\|Test\|mock\|Mock" | wc -l

echo "5. Current agent_core state:"
ls agent_core/src/ 2>/dev/null || echo "agent_core/src/ does not exist yet — will be created"

echo "6. Pre-built Rust files from release:"
ls agent_core/src/*.rs 2>/dev/null | wc -l
ls agent_core/src/providers/*.rs 2>/dev/null | wc -l
ls agent_core/src/storage/*.rs 2>/dev/null | wc -l
```

After running pre-flight, state what you found. Then proceed to Phase 1.

---

## PHASE 1: READ ARCHITECTURE (do NOT skip)

Read these files IN ORDER before writing any code. They contain the complete agent system specification, gap analysis, and implementation code. These files are now in the project tree (placed by install.sh).

```bash
# Read the project rules (auto-loaded, but read explicitly for fresh context)
cat CLAUDE.md

# Read the full agent architecture spec
cat docs/agent-system/AGENT_ARCHITECTURE.md

# Read the gap analysis (what's missing and what's broken)
cat docs/agent-system/GAP_ANALYSIS.md

# Read current progress
cat docs/PROGRESS.md

# Read the current sprint file
cat docs/sprint-sessions/sprint-agent-1-living-loop.md
```

After reading, state: "I have read the architecture. The agent system needs: [summary]. First sprint: Agent-1 (Living Loop). First task: [Y]."

---

## PHASE 2: BUILD ORDER (follow EXACTLY)

### Sprint Agent-1: The Living Loop (MOST CRITICAL — build this first)

**Read the full task list:** `cat docs/sprint-sessions/sprint-agent-1-living-loop.md`

That file contains all 16 tasks in dependency order, the exact implementation rules, and the verification commands. Follow it task by task.

**Summary of what gets built:**
1. Rust agent_core crate (13 files): types, provider trait, ClaudeProvider SSE, tool registry, vault storage, agentic loop, UniFFI bridge, session management, HTTP retry, routing
2. Swift bridge layer (3 files): StreamingDelegate, AgentViewModel, OmegaPanel

**The install script may have already placed pre-built versions of these files.** If they exist, READ them first, then verify they match the architecture spec. If they need updates, modify them. If they're missing, create them from the sprint file's specifications.

```bash
# Check which files already exist from the release
echo "=== Pre-built files status ==="
for f in agent_core/src/lib.rs agent_core/src/types.rs agent_core/src/provider.rs \
    agent_core/src/agent_loop.rs agent_core/src/bridge.rs agent_core/src/error.rs \
    agent_core/src/prompts.rs agent_core/src/session.rs agent_core/src/routing.rs \
    agent_core/src/providers/claude.rs agent_core/src/tools/registry.rs \
    agent_core/src/storage/vault.rs \
    Epistemos/Bridge/StreamingDelegate.swift \
    Epistemos/ViewModels/AgentViewModel.swift \
    Epistemos/Views/OmegaPanel.swift; do
    [ -f "$f" ] && echo "EXISTS: $f" || echo "CREATE: $f"
done
```

For files marked EXISTS: review, integrate with the existing codebase, fix any compilation issues.
For files marked CREATE: build from the sprint file specs.

### Sprint Agent-2: Local Agent System
After completing Agent-1, start a FRESH session. Read `docs/sprint-sessions/sprint-agent-2-local.md` (create it from the bootstrap spec if it doesn't exist yet).

### Sprint Agent-3: MCP + Computer Use
Fresh session. Sprint file: `docs/sprint-sessions/sprint-agent-3-mcp.md`

### Sprint Agent-4: Multi-Provider + Polish
Fresh session. Sprint file: `docs/sprint-sessions/sprint-agent-4-polish.md`

---

## ANTI-DRIFT SYSTEM (baked into this prompt)

### Why Drift Happens
1. **Context compaction** — Codex auto-compacts at ~83.5% context window. Your rules from session start get compressed or dropped.
2. **Attention decay** — Transformer attention weights recent tokens more. Rules from 150K tokens ago decay.
3. **Satisficing** — LLMs produce plausible-looking output at 80% fidelity. The missing 20% is where bugs live.

### Five-Layer Defense (all layers active simultaneously)

**Layer 1: CLAUDE.md** — Auto-loaded every session. Contains rules, file map, and constraint list. Lives at project root. Tells Codex where every doc and source file lives so it never guesses.

**Layer 2: Post-Compaction Hook** — `.claude/settings.json` fires `cat .claude/context-essentials.txt` after every compaction. Re-injects constraints deterministically. Includes agent-specific rules (preserve thinking blocks, stream everything, agent decides termination).

**Layer 3: Sprint-Scoped Sessions** — Never implement the whole spec in one session. Each sprint gets a fresh session with focused context. Sprint files live in `docs/sprint-sessions/`.

**Layer 4: PROGRESS.md** — Living checklist at `docs/PROGRESS.md`. Updated after every sprint. Read at session start to know where to pick up.

**Layer 5: Post-Sprint Audit** — After each sprint, run `docs/audit-prompts/post-sprint-audit.md` in a FRESH session. Verify, don't implement.

### Hooks That Fire Automatically (from .claude/settings.json)
- **Post-compaction**: Re-injects constraints from `.claude/context-essentials.txt`
- **Post-write on .swift**: Warns if sidecar patterns detected (Process(), NSTask, posix_spawn)
- **Post-write on .rs**: Warns if unsafe block lacks // SAFETY: comment
- **Post-write**: BLOCKS if importing nonexistent SDKs (import Anthropic, import OpenAI)
- **Post-write**: BLOCKS if storing API keys in UserDefaults
- **Pre-bash**: BLOCKS dangerous commands (rm -rf /, drop table, truncate)

---

## PROVIDER MATRIX (verified March 2026)

| Provider | Model | Endpoint | Thinking | Tools | Computer Use | MCP |
|---|---|---|---|---|---|---|
| Anthropic | claude-opus-4-6 | api.anthropic.com/v1/messages | adaptive | ✅ | ✅ (beta) | ✅ |
| Anthropic | claude-sonnet-4-6 | api.anthropic.com/v1/messages | adaptive | ✅ | ✅ (beta) | ✅ |
| Anthropic | claude-haiku-4-5 | api.anthropic.com/v1/messages | disabled | ✅ | ❌ | ✅ |
| OpenAI | gpt-5.4 | api.openai.com/v1/responses | ❌ | ✅ | ❌ | ❌ |
| OpenAI | o4-mini | api.openai.com/v1/responses | built-in | ✅ | ❌ | ❌ |
| Perplexity | sonar-pro | api.perplexity.ai/chat/completions | ❌ | ❌ | ❌ | ❌ |
| Local | Qwen3.5/Hermes-3 | in-process MLX | <think> tags | grammar-constrained | ❌ | ❌ |

Anthropic beta header: `interleaved-thinking-2025-05-14`
Anthropic version: `2023-06-01`
Claude thinking config: `{ "type": "adaptive" }` with optional `effort` parameter

---

## TOOL ARSENAL (install once)

```bash
brew install ast-grep comby tree-sitter difftastic ripgrep fd sd bat \
  fq gron tokei scc dust eza watchexec qsv miller jless yq git-delta \
  git-absorb lazygit gh hyperfine procs bottom mise shellcheck shfmt \
  bacon periphery xcbeautify swiftlint grex zoxide choose semgrep \
  nushell xh hurl websocat caddy
cargo install sad git-branchless cargo-expand cargo-audit
```

---

## VALIDATION CHECKLIST (run before declaring ANY sprint complete)

```bash
echo "=== AGENT SYSTEM VALIDATION ==="

echo "1. Thinking preservation:"
grep -n "response_blocks.clone()" agent_core/src/agent_loop.rs && echo "✅" || echo "❌"

echo "2. Streaming (delegate calls inside stream loop):"
grep -c "delegate.*on_text_delta\|delegate.*on_thinking_delta" agent_core/src/agent_loop.rs

echo "3. Parallel execution:"
grep "try_join_all\|join_all" agent_core/src/agent_loop.rs && echo "✅" || echo "❌"

echo "4. Agent-decides termination:"
grep "EndTurn.*return\|end_turn.*Ok" agent_core/src/agent_loop.rs && echo "✅" || echo "❌"

echo "5. Permission timeout:"
grep "timeout\|120" Epistemos/Bridge/StreamingDelegate.swift && echo "✅" || echo "❌"

echo "6. No sidecar (should be 0):"
grep -rn "Process()\|NSTask\|posix_spawn" --include="*.swift" --include="*.rs" | grep -v "//\|test\|Test" | wc -l

echo "7. No fake SDKs (should be 0):"
grep -rn "import Anthropic\b\|import OpenAI\b" --include="*.swift" | wc -l

echo "8. Keychain usage:"
grep -rn "SecItemAdd\|SecItemCopyMatching" --include="*.swift" | wc -l

echo "9. UserDefaults secrets (should be 0):"
grep -rn "UserDefaults.*[Aa]pi[Kk]ey\|UserDefaults.*token\|UserDefaults.*secret" --include="*.swift" | wc -l

echo "10. Rust compilation:"
cd agent_core && cargo check 2>&1 | tail -5 && cd ..

echo "11. Swift compilation:"
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5

echo "12. Test suite:"
swift test 2>&1 | grep -E "passed|failed|error"
```

---

## HOW TO START EACH SESSION

**Session 1 (setup + Sprint Agent-1):**
```
Read docs/CODEX_AGENT_BOOTSTRAP.md and execute Phase 0 (self-install verification),
then Phase 1 (read architecture), then start Sprint Agent-1 by reading
docs/sprint-sessions/sprint-agent-1-living-loop.md. Execute all tasks in order.
Run verification after each task. Update docs/PROGRESS.md when done.
```

**Session 2+ (continuing work):**
```
Read docs/PROGRESS.md. Read the current sprint file from docs/sprint-sessions/.
Continue from where the last session left off.
```

**Post-sprint audit (separate session):**
```
Read docs/audit-prompts/post-sprint-audit.md. Verify, don't implement. Report findings.
```
