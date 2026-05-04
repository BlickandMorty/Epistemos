# The Anti-Drift System for Epistemos

> **Index status**: CANONICAL — 5-layer defense system against LLM drift (compaction + attention decay + satisficing); mechanistic discipline for long-running coding sessions.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/00_canonical_authority/`.


## How to Ensure Every Line of Your 1,019-Line Spec Actually Becomes Code

---

## Why Drift Happens — The Root Cause

The problem is not your prompt. The problem is how LLMs process long context during extended coding sessions. Three mechanisms conspire against you.

First, **context compaction.** Claude Code auto-compacts when the conversation reaches approximately 83.5% of its context window (~167K of 200K tokens). Compaction is a lossy summarization — Claude decides what survives based on recency, relevance, and frequency. Your architectural constraints from the beginning of the session ("NO SIDECAR PROCESSES") were mentioned once, 150K tokens ago. They get compressed into a vague summary or dropped entirely. The code Claude is actively editing survives. Your rules don't.

Second, **attention decay.** Even before compaction, transformer attention patterns naturally weight recent tokens more heavily than distant ones. In a 1,019-line spec loaded at session start, lines 1-50 (your preamble and constraints) get strong attention initially. By the time Claude is implementing Sprint 4 on line 600, the attention on those early constraints has decayed significantly. Claude isn't ignoring your rules — it literally can't attend to all of them simultaneously with equal weight.

Third, **satisficing over maximizing.** LLMs are trained to produce plausible-looking output, not to exhaustively check every requirement. When Claude implements a feature, it satisfies the *shape* of the request — "create an Anthropic provider" — without cross-referencing every capability flag, every API verification requirement, and every acceptance criterion. It produces something that looks right at 80% fidelity. The missing 20% is where your bugs live.

## The Solution: A Five-Layer Defense System

No single technique solves drift. You need defense in depth — multiple independent mechanisms that catch failures at different points. Here are the five layers, from innermost (always active) to outermost (periodic verification).

---

## Layer 1: CLAUDE.md (Always in Context — Advisory)

This file lives at your project root and is automatically loaded into every Claude Code session. It's advisory (Claude follows it roughly 60-80% of the time), but it's the foundation everything else builds on. Keep it SHORT — under 50 lines of critical rules. The full spec lives in separate files that Claude reads on demand.

**Create this file at `Epistemos/CLAUDE.md`:**

```markdown
# Epistemos — Project Rules

## Architecture
- Swift 6.0 + Rust (UniFFI FFI) + Metal compute shaders
- GRDB for persistence, MLX-Swift for local inference
- Multi-agent Omega system for agentic workflows

## NON-NEGOTIABLE CONSTRAINTS
- NO SIDECAR PROCESSES for inference. All inference in-process via Rust FFI, llama.cpp static lib, or MLX-Swift. Reject Process(), NSTask, localhost:port for inference. ONLY exception: oMLX bridge for oversized models.
- REAL APIs ONLY. Every cloud endpoint must be verified against provider docs. No fake features.
- HONEST CAPABILITY GATING. Local models get fast/thinking/research. Cloud models get agent/liveAgent. Never fake agent capability for local models.
- Zero test regressions against the 2,679-test suite.

## Code Standards
- Use @Observable, not ObservableObject
- Use Swift Testing (@Test, #expect) for new tests
- All inference on background actors — never block @MainActor
- Every unsafe block gets // SAFETY: comment
- No try!, no force-unwraps, no print() in production paths
- API keys in macOS Keychain, never UserDefaults

## Build & Test
- Build: xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
- Test: swift test
- Lint: swiftlint

## DO NOT
- Edit .xcodeproj directly — use xcodegen
- Commit model files (.gguf, .safetensors, .mlx)
- Import SDKs that don't exist (Anthropic has NO Swift SDK, OpenAI has NO Swift SDK)
- Use Ollama, llama-server, or any subprocess for inference

## Spec Location
- Full build spec: docs/EPISTEMOS_FUSED_v3.md (read before each sprint)
- Progress tracker: docs/PROGRESS.md (update after completing each item)
- Post-compaction essentials: .claude/context-essentials.txt
```

---

## Layer 2: Post-Compaction Hook (Deterministic — 100% Reliable)

This is the most important layer. When context compacts, Claude loses your rules. This hook fires automatically after every compaction and re-injects your critical constraints as a system message. Unlike CLAUDE.md (advisory), hooks are deterministic — they always run.

**Create `.claude/context-essentials.txt`:**

```
CONTEXT RESTORED AFTER COMPACTION. Re-read these rules NOW:

CONSTRAINTS (violations = build failure):
1. NO SIDECAR — all inference in-process. No Process(), no localhost:port for inference.
2. REAL APIs ONLY — verify every endpoint against provider docs.
3. HONEST GATING — agent/liveAgent modes disabled for local models.
4. ZERO REGRESSIONS — 2,679 existing tests must pass.

CURRENT SPRINT: Check docs/PROGRESS.md for what's done and what's next.
FULL SPEC: Read docs/EPISTEMOS_FUSED_v3.md for the current sprint section.

Before continuing, state: "I have re-read the constraints. Current sprint: [X]. Next task: [Y]."
```

**Add to `.claude/settings.json`:**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "cat .claude/context-essentials.txt"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(jq -r .tool_input.file_path <<< \"$(cat)\"); case \"$FILE\" in *.swift) grep -l \"Process()\\|NSTask\\|posix_spawn\" \"$FILE\" 2>/dev/null && echo \"BLOCKED: Sidecar pattern detected in $FILE\" && exit 2; exit 0;; *) exit 0;; esac'"
          }
        ]
      }
    ]
  }
}
```

The PostToolUse hook re-injects your constraints after every compaction. The PreToolUse hook blocks writes containing sidecar patterns (`Process()`, `NSTask`, `posix_spawn`) — deterministically, every time, regardless of what Claude "remembers."

---

## Layer 3: Sprint-Scoped Sessions (Fresh Context Per Sprint)

This is the single most impactful practice. Never try to implement the entire spec in one session. Each sprint gets its own fresh Claude Code session with clean context focused entirely on that sprint's work.

**The protocol:**

Before each sprint, create a session file that contains ONLY that sprint's instructions, extracted from the full spec. This keeps Claude's context focused and prevents the "distant attention" problem.

**Create `docs/sprint-sessions/` directory with one file per sprint:**

**`docs/sprint-sessions/sprint-1-foundation.md`:**
```markdown
# Sprint 1: Foundation (Days 1-2)

Read docs/EPISTEMOS_FUSED_v3.md sections: Pre-Flight, Workstream 1 Phases 1.0-1.3

## Tasks (in order):
1. Run ALL 11 pre-flight greps. HALT if any differs from expected.
2. Create Epistemos/Services/Inference/ModelBackend.swift (exact code in spec)
3. Create Epistemos/Services/Inference/KVCacheConfig.swift (exact code in spec)
4. Create Epistemos/Models/ModelQuantization.swift (exact code in spec)
5. REPLACE entire LocalTextModelID enum with full registry (spec Phase 1.1)
6. Add tattn/LocalLLMClient SPM dependency
7. Create Epistemos/Services/Inference/GGUFInferenceService.swift (exact code in spec)
8. Wire backend routing switch in LLMService.swift (spec Phase 1.3)

## Verification (run ALL after completing):
```bash
grep -r "ModelBackend" --include="*.swift" | head -5  # Should exist
grep -r "KVCacheConfig" --include="*.swift" | head -5  # Should exist
grep -r "ModelQuantization" --include="*.swift" | head -5  # Should exist
grep -r "GGUFInferenceService" --include="*.swift" | head -5  # Should exist
grep -c "case" Epistemos/Models/LocalTextModelID.swift  # Should be 17+ cases
grep -r "switch.*backend" --include="*.swift" | head -5  # Routing exists
swift build 2>&1 | tail -20  # Compiles
swift test 2>&1 | tail -5  # Zero regressions
```

## After completing, update docs/PROGRESS.md:
Mark items 1.0-1.3 as ✅ with date and commit hash.
```

**Start each sprint session with:**
```bash
claude --resume sprint-1  # or start fresh
# Then paste:
# "Read docs/sprint-sessions/sprint-1-foundation.md and execute all tasks in order.
#  After each task, run its verification. After all tasks, update docs/PROGRESS.md."
```

**Why this works:** Each session starts with ~2K tokens of sprint-specific context instead of 15K tokens of full-spec context. Claude's attention is concentrated on exactly the tasks at hand. Context compaction is less likely because the session stays shorter. And if compaction does happen, the post-compact hook restores the critical constraints.

---

## Layer 4: PROGRESS.md (Living Checklist — Source of Truth)

This file lives in the repo and gets updated after every sprint. It's the definitive record of what's been implemented, what's pending, and what's blocked. Claude Code reads it at session start to know where to pick up.

**Create `docs/PROGRESS.md`:**

```markdown
# Epistemos Implementation Progress

Last updated: [DATE] | Last commit: [HASH]

## Sprint 1: Foundation
- [ ] Pre-flight greps run (all 11 passing)
- [ ] ModelBackend.swift created (.mlx, .gguf, .cloud)
- [ ] KVCacheConfig.swift created (turboQuant, standard, balanced)
- [ ] ModelQuantization.swift created (Q4, Q8)
- [ ] LocalTextModelID replaced with full registry (17+ local + 16+ cloud)
  - [ ] All 6 original MLX Qwen models preserved
  - [ ] All new models added with correct ramRequirementQ4GB
  - [ ] Every model has backend, tier, canActAsAgent, supportsDualThinkMode
  - [ ] isComingSoon set for Llama4Scout, MiniMax, Chroma
  - [ ] isUnrestrictedThinking set for 40B Opus Uncensored
  - [ ] ggufFileQ4 and ggufFileQ8 populated for GGUF models
  - [ ] activeParametersB populated for all models
- [ ] LocalLLMClient SPM dependency added
- [ ] GGUFInferenceService.swift created (in-process, NOT sidecar)
- [ ] Backend routing wired in LLMService.swift

## Sprint 2: Model Selector + TurboQuant
- [ ] LocalModelSelectorView.swift with 5-tier sections
  - [ ] RAM banner with dynamic ProcessInfo.physicalMemory
  - [ ] Q4/Q8 quantization picker per model
  - [ ] Badge system: MoE(purple), Code(blue), Think(orange), Uncensored(red), ComingSoon(gray), NeedsoMLX(orange)
  - [ ] TurboQuant indicator in RAM banner
  - [ ] canActAsAgent=false models show NO agent badge
- [ ] ModelDownloadManager GGUF extension
  - [ ] ggufModelPath(for:quantization:) implemented
  - [ ] downloadGGUF with URLSessionDownloadTask (resumable)
  - [ ] HuggingFace Bearer token for gated models (Keychain)
- [ ] TurboQuant wired: --kv-bits for MLX, --cache-type-k for GGUF
- [ ] TurboQuant toggle in Settings UI

## Sprint 3: Cloud API Integration
- [ ] CloudProvider.swift protocol (ProviderCapabilities struct)
- [ ] AnthropicProvider.swift
  - [ ] Real Messages API at api.anthropic.com/v1/messages
  - [ ] Tool calling (all models)
  - [ ] Computer use (Opus + Sonnet only, beta header)
  - [ ] Extended thinking (Opus + Sonnet, budget_tokens)
  - [ ] MCP connector (mcp_servers in request body)
  - [ ] Capability matrix matches verified table exactly
- [ ] OpenAIProvider.swift (Responses API at /v1/responses)
- [ ] GeminiProvider.swift (OpenAI-compat + free tier note)
- [ ] DeepSeekProvider.swift (with automatic fallback on outage)
- [ ] MistralProvider.swift (with FIM endpoint for Codestral)
- [ ] CohereProvider.swift (rerank + embed endpoints)
- [ ] QwenProvider.swift (DashScope international)
- [ ] CloudRouter.swift (unified OpenAI-compat dispatcher)
- [ ] SubscriptionProxy.swift (WKWebView cookies, localhost:8317)
- [ ] API key settings UI (Keychain storage, NOT UserDefaults)

## Sprint 4: Agent Overhaul
- [ ] EpistemosOperatingMode enum (5 modes)
  - [ ] requiresCloudModel returns true for agent/liveAgent
  - [ ] minimumModelSizeB returns 4.0 for thinking/research
- [ ] AgentModeSelectorView.swift with availableModes computed property
  - [ ] Agent/liveAgent DISABLED for local models
  - [ ] Thinking only for supportsDualThinkMode AND activeParametersB >= 4.0
- [ ] DAGExecutor.swift (replaces linear ReAct loop)
- [ ] Safari agent fixed
  - [ ] Wait-for-load after paste
  - [ ] AX tree verification (threshold check)
  - [ ] Screen2AX fallback when sparse
- [ ] Screen2AXService.swift (OmniParser V2 visual grounding)
- [ ] Grammar-constrained tool calling (processTokenStream)

## Sprint 5: Computer Use + Live Agent
- [ ] ComputerUseService.swift
  - [ ] ScreenCaptureKit (2-5fps, NOT screenshots)
  - [ ] Scale to XGA 1024x768 before sending
  - [ ] computer_20251124 tool definition
  - [ ] anthropic-beta: computer-use-2025-11-24 header
  - [ ] CGEvent execution with coordinate recalculation
  - [ ] Continuous loop until Claude returns text
- [ ] LiveAgentView.swift (real-time observation + Kanban)

## Sprint 6: SOAR Research + Memory
- [ ] TMSService.swift with calculateSOAR() and evaluateNLI()
- [ ] 4 SOAR tools in OmegaToolRegistry
  - [ ] deepsearchweb
  - [ ] captureandgradesource
  - [ ] checkcontradiction
  - [ ] synthesizeresearchnode
- [ ] MCPBridge SQLite migration
  - [ ] soarScore REAL
  - [ ] contradictionFlag INTEGER DEFAULT 0
  - [ ] citationHash TEXT
  - [ ] modelHash TEXT
- [ ] EpisodicMemory.swift (BM25 + vector retrieval)
- [ ] MCP: local stdio + cloud HTTP
- [ ] Prompt Repetition in SystemPromptBuilder.swift
  - [ ] withPromptRepetition function
  - [ ] Applied ONLY to non-thinking models

## Sprint 7: Release Blockers + Polish
- [ ] Entitlements populated (exact XML from spec)
  - [ ] network.client
  - [ ] files.user-selected.read-write
  - [ ] files.bookmarks.app-scope
  - [ ] cs.allow-jit
  - [ ] cs.allow-unsigned-executable-memory
  - [ ] cs.disable-library-validation
  - [ ] automation.apple-events
- [ ] PrivacyInfo.xcprivacy (exact XML from spec)
  - [ ] FileTimestamp C617.1
  - [ ] UserDefaults CA92.1
  - [ ] DiskSpace E174.1
- [ ] Deployment target 15.0 everywhere
- [ ] Top 10 try? → do/catch with Log.vault.error()
- [ ] Top 50 unsafe blocks with // SAFETY: comments
- [ ] ASAN clean
- [ ] TSAN clean
- [ ] UBSAN clean
- [ ] All 2,679 tests pass — ZERO regressions

## Workstream 5: oMLX
- [ ] OMLXBridgeService.swift (localhost:8000/v1)
- [ ] Model picker banner for oversized models

## Workstream 7: Memory + Skills
- [ ] EpisodicMemory.swift (task_intent, execution_plan, tool_calls, success, duration)
- [ ] Voyager-style skill library (hash + save successful plans)
- [ ] ODIA nightly QLoRA training (MoLoRA adapters)
```

---

## Layer 5: Post-Sprint Audit Prompt (Verification After Each Sprint)

After each sprint, paste this audit prompt into a FRESH Claude Code session. It systematically verifies that every acceptance criterion was met. This is the final safety net — it catches everything the implementation session missed.

**Save as `docs/audit-prompts/post-sprint-audit.md`:**

```markdown
# Post-Sprint Audit

You are auditing the Epistemos codebase AFTER a sprint implementation.
Your job is to verify, not implement. Do NOT write code. Only report findings.

## Instructions:
1. Read docs/PROGRESS.md to see what should be done
2. For every checked item, VERIFY it exists in code with grep
3. For every unchecked item, confirm it's genuinely not started
4. Report discrepancies: items marked done but not actually implemented

## Verification Commands:

### Sprint 1 Audit:
```bash
# ModelBackend exists with all 3 cases
grep -A5 "enum ModelBackend" --include="*.swift" -r

# KVCacheConfig exists with turboQuant static
grep "static let turboQuant" --include="*.swift" -r

# ModelQuantization exists
grep "enum ModelQuantization" --include="*.swift" -r

# Model count
grep -c "case " Epistemos/Models/LocalTextModelID.swift

# Each model has required properties
for prop in "ramRequirementQ4GB" "backend" "tier" "canActAsAgent" "supportsDualThinkMode" "activeParametersB" "isComingSoon" "ggufFileQ4"; do
  echo "=== $prop ==="
  grep -c "$prop" --include="*.swift" -r
done

# GGUFInferenceService is NOT a sidecar
grep -n "Process()\|NSTask\|localhost" Epistemos/Services/Inference/GGUFInferenceService.swift
# EXPECTED: ZERO results

# Backend routing exists
grep -B2 -A5 "switch.*backend\|\.mlx.*\.gguf.*\.cloud" --include="*.swift" -r

# Compiles and tests pass
swift build 2>&1 | tail -5
swift test 2>&1 | tail -10
```

### Sprint 3 Audit (Cloud APIs):
```bash
# Anthropic uses REAL endpoint
grep "api.anthropic.com" --include="*.swift" -r
# MUST find results

# OpenAI uses Responses API
grep "api.openai.com/v1/responses\|api.openai.com/v1/chat" --include="*.swift" -r

# NO fake Swift SDKs imported
grep "import Anthropic\|import OpenAI\b" --include="*.swift" -r
# EXPECTED: ZERO (these SDKs don't exist officially)

# API keys in Keychain
grep "SecItemAdd\|SecItemCopyMatching\|kSecClass" --include="*.swift" -r
# MUST find results

grep "UserDefaults.*apiKey\|UserDefaults.*api_key" --include="*.swift" -r
# EXPECTED: ZERO

# Computer use has real screenshot loop
grep "computer_20251124\|anthropic-beta.*computer-use" --include="*.swift" -r
# MUST find results for Opus/Sonnet

# Capability gating is honest
grep "canActAsAgent\|requiresCloudModel" --include="*.swift" -r
```

### Sprint 4 Audit (Agent System):
```bash
# Agent mode disabled for local
grep -A10 "availableModes" --include="*.swift" -r
# Verify: .agent and .liveAgent NEVER appear when selectedModel is non-nil

# DAGExecutor replaces ReAct
grep "DAGExecutor\|ExecutionPlan\|ExecutionNode" --include="*.swift" -r
# MUST find results

# Safari agent has wait-for-load
grep "wait.*load\|page.*load\|AXTree.*count\|Screen2AX" Epistemos/Services/Agent/Safari*.swift

# Grammar constraints for local models
grep "GBNF\|GrammarConstraint\|activateGrammarConstraint" --include="*.swift" -r
```

### Full Acceptance Audit:
```bash
# Count all acceptance criteria from spec
echo "=== CRITICAL CHECKS ==="

# No sidecar anywhere
echo "Sidecar patterns (should be 0):"
grep -rn "Process()\|NSTask\|posix_spawn" --include="*.swift" | grep -v "//.*Process\|test\|Test\|mock\|Mock" | wc -l

# No force unwraps in production
echo "Force unwraps (should be 0 in production paths):"
grep -rn "!" --include="*.swift" | grep -v "//\|test\|Test\|mock\|Mock\|IBOutlet\|IBAction\|!=\|guard.*!" | head -20

# No print() in production
echo "print() in production (should be 0):"
grep -rn "print(" --include="*.swift" | grep -v "//\|test\|Test\|mock\|Mock\|Log\." | head -20

# All unsafe blocks have SAFETY comments
echo "Unsafe without SAFETY (should be 0):"
grep -B1 "unsafe" --include="*.rs" -r | grep -v "SAFETY" | head -20

# Tests pass
swift test 2>&1 | grep -E "passed|failed|error"
```

## Output Format:
For each sprint, report:
- ✅ VERIFIED: [item] — confirmed in code at [file:line]
- ❌ MISSING: [item] — not found, should be at [expected location]
- ⚠️ PARTIAL: [item] — exists but incomplete: [what's missing]

Do NOT fix anything. Only report. Fixes happen in the next implementation session.
```

---

## The Complete Workflow — How to Use This System

**Step 1: Setup (once)**
Drop these files into your repo: `CLAUDE.md` at root, `.claude/settings.json` with hooks, `.claude/context-essentials.txt`, `docs/PROGRESS.md`, `docs/EPISTEMOS_FUSED_v3.md`, and `docs/sprint-sessions/` with one file per sprint, `docs/audit-prompts/post-sprint-audit.md`.

**Step 2: Before each sprint**
Start a FRESH Claude Code session. Name it with `/rename sprint-1-foundation`. Paste:

```
Read docs/sprint-sessions/sprint-1-foundation.md and execute all tasks in order.
After each task, run its verification grep.
After all tasks, update docs/PROGRESS.md with checkmarks and today's date.
If anything from docs/EPISTEMOS_FUSED_v3.md is unclear, read the relevant section.
```

**Step 3: During the sprint**
If you see context getting large (check with `/context`), proactively run `/compact focus on the current sprint tasks and the list of modified files`. The post-compact hook will re-inject your constraints automatically.

If the sprint is too large for one session, split it. End the session cleanly, update PROGRESS.md, and start a new session for the remaining tasks.

**Step 4: After each sprint**
Start a FRESH session. Paste the post-sprint audit prompt. Review the audit output. Any ❌ MISSING items become the first tasks of the next session.

**Step 5: Before the final ship**
Run the "Full Acceptance Audit" section of the audit prompt. This is the last gate before release.

---

## Why This System Works

The five layers address the five failure modes of agentic coding.

**Layer 1 (CLAUDE.md)** handles the common case: Claude reads it at session start, follows it most of the time, and it costs almost nothing in context. It prevents the most obvious violations.

**Layer 2 (Post-compact hook)** handles the compaction failure mode. When Claude's context gets summarized, the hook fires automatically and re-injects the constraints that matter most. This is deterministic — it runs every time, regardless of what Claude "remembers."

**Layer 3 (Sprint sessions)** handles the attention decay failure mode. By scoping each session to 5-8 tasks instead of 100, Claude's attention stays concentrated on exactly what needs to happen. No distant requirements competing for attention.

**Layer 4 (PROGRESS.md)** handles the state tracking failure mode. It's a source of truth that persists across sessions. When Claude starts a new session, it reads PROGRESS.md and knows exactly where to pick up — no "where were we?" ambiguity.

**Layer 5 (Audit prompts)** handles the satisficing failure mode. Claude implemented something that looks right but missed three acceptance criteria? The audit catches it. Running in a separate session means the auditor has fresh context and no "sunk cost" bias toward defending earlier work.

Together, these five layers create a system where drift is possible at any individual layer but essentially impossible across all five simultaneously. That's defense in depth.
