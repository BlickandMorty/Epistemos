# Epistemos Final Release Closure Report

> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



**Date:** 2026-03-27
**Status:** Code fixes complete. Build and full test suite verified. Partial manual runtime spot-checks completed. Full runtime verification still pending (requires user on real hardware).

---

## 1. What Was Fixed

### Deploy Gate — Fully Fail-Closed
**File:** `Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift`
**Before:** Three code paths in `runDeployGate()`:
- Missing eval infra → `passed: true` (dangerous default-pass)
- Weights file exists → `passed: true` (no quality verification)
- Weights file missing → `passed: false`

**After:** All three paths return `passed: false`:
- Missing eval infra → `passed: false`, reason: "Eval infrastructure not available"
- Weights file exists → `passed: false`, reason: "Automatic deployment disabled — activate adapters manually in Settings > Knowledge Fusion"
- Weights file missing → `passed: false`, reason: "No adapter weights produced"

Users activate adapters manually through the Adapter Selector UI.

### LoRA Rank Default Conflict
**File:** `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift`
**Before:** `defaultKnowledge` used rank 32 / alpha 64 — could OOM on 8GB hardware.
**After:** `defaultKnowledge` uses rank 16 / alpha 32 — matches KnowledgeFusionViewModel auto-config and the release-safe 8GB target.

### Cross-App PID Capture
**File:** `Epistemos/Omega/Orchestrator/OrchestratorState.swift`
**Before:** All embodied captures used `ProcessInfo.processInfo.processIdentifier` (Epistemos PID), so cross-app captures recorded Epistemos's AX tree instead of Safari/Terminal/Finder.
**After:** Added `resolveTargetPID(for:)` helper that maps agent names to bundle IDs and resolves real PIDs via `NSWorkspace.shared.runningApplications`. Falls back to Epistemos PID for unknown agents.

### TrainOnVaultView Messaging Overhaul
**File:** `Epistemos/KnowledgeFusion/UI/TrainOnVaultView.swift`
**Changes (8 string replacements):**
- "fine-tunes your local AI model" → "creates a personal adapter for your local model"
- "Voice Cloning" → "Style Adaptation"
- "Knowledge Absorption" → "Knowledge Exposure"
- "Tool Learning" → "Tool Familiarity"
- "Autoresearch" → "Background Training"
- "Your model improves while you sleep" → removed
- "The model memorizes facts...it just knows" → "The adapter is trained on facts...though results vary"
- "The model learns to recommend the right tool" → "The adapter can help the model suggest relevant tools"

### OmegaSettingsDetailView Labels
**File:** `Epistemos/Views/Settings/OmegaSettingsDetailView.swift`
**Changes:**
- "Overnight autoresearch" → "Overnight adapter training (Experimental)"
- "for Nano" → "for your trained adapter" (prior pass)
- Embodied capture help text now describes experimental trace collection instead of implying automatic adapter-quality gains

### Knowledge Fusion Experimental Labels
**Files:** `SettingsView.swift`, `TrainOnVaultView.swift`
**Changes:**
- Settings sidebar: "Knowledge Fusion" → "Knowledge Fusion (Experimental)"
- TrainOnVaultView header: "Knowledge Fusion" → "Knowledge Fusion (Experimental)"
- Start Training button: "Start Training" → "Start Training (Experimental)"

### Overnight Training Default
**File:** `OmegaSettingsDetailView.swift`
**Confirmed:** `@AppStorage("omega.overnightTraining")` defaults to `false`. Training never runs unless user explicitly enables it.

### Runtime Audit Vault Isolation
**File:** `Epistemos/Sync/VaultSyncService.swift`
**Before:** Disposable debug/manual runtime audits could still restore a previously bookmarked real vault.
**After:** `VaultSyncService.shouldRestoreVaultFromBookmark(...)` now honors `EPISTEMOS_SKIP_VAULT_RESTORE`, making isolated audit runs safer without changing normal app behavior.

### Research Session Note Append Safety
**File:** `Epistemos/Omega/Agents/NotesAgent.swift`
**Before:** `collectsnippet` and `savecitation` appended to existing session notes by reading persisted body content directly, which could miss in-memory editor changes and leave open notes visually stale.
**After:** Both paths now request an editor flush before reading, save the merged body, and notify open editors after mutation. New regression tests cover both flows.

### Research Command Handoff Visibility
**Files:** `Epistemos/Views/MiniChat/MiniChatView.swift`, `Epistemos/Views/Chat/ChatView.swift`, `Epistemos/Omega/ResearchComplexityGate.swift`, `Epistemos/State/ChatState.swift`
**Before:** `/research ...` commands routed to Omega, but the chat surfaces gave no visible handoff acknowledgment and did not surface the Omega panel, making the flow feel broken.
**After:** Both chat surfaces now append a visible handoff message, open the Omega panel for non-empty research requests, and share the same handoff copy through `ResearchComplexityGate.handoffMessage(...)`. A new `ChatState.appendLocalMessage(...)` helper covers the main-chat side cleanly.

---

## 2. What Is Intended To Ship As Stable (Pending Verification)

These surfaces have no identified code defects and are structurally complete based on file audit. They are the intended stable release surfaces, but runtime verification is still only partial in this pass, so the remaining matrix in Section 6 is still the ship gate.

| Surface | Code audit status | Runtime verified? |
|---|---|---|
| Qwen 3.5 local inference (6 variants) | Structurally sound, no code changes needed | Partial — installed 4B tier responded in Mini Chat; clean install/select matrix still pending |
| Qwen-first triage routing (Apple Intelligence for light work, Qwen for heavy) | Anti-overclaim prompt in TriageService, routing logic complete | No — routing decisions not manually tested |
| Note editor AI (rewrite, summarize, expand, continue, analyze) | Code paths exist and compile | No — streaming output not manually tested |
| Omega task orchestration (26 tools, 5 agents) | Registered and wired, Rust tests pass | No — end-to-end task execution not manually tested |
| Research mode (evidence scoring, contradiction detection, pause-and-ask) | Orchestrator + tools complete, test suite exists | No — research flow not manually tested |
| Knowledge graph (Rust, 2,441 tests) | Rust tests pass | Yes (automated) |
| Instant recall vector search | Code complete | No |
| Vault sync | Code complete | No |
| Onboarding | Honest copy, no overclaims | No |
| Settings | All sections load, Experimental labels applied | Partial — Inference and Knowledge Fusion settings spot-checked live |

---

## 3. What Now Ships As Experimental

| Feature | Label | Location |
|---|---|---|
| Knowledge Fusion | "Knowledge Fusion (Experimental)" | Settings sidebar, TrainOnVaultView header |
| Train on Vault | "Start Training (Experimental)" | TrainOnVaultView button |
| Personal adapters | Part of KF Experimental section | AdapterSelectorView |
| KTO feedback | Part of KF Experimental section | Feedback indicator |
| Overnight training | "Overnight adapter training (Experimental)" | OmegaSettingsDetailView |
| Embodied capture | "Embodied data capture (Experimental)" | OmegaSettingsDetailView |

---

## 4. What Was Hidden/Deferred

| Item | Status |
|---|---|
| MOHAWK distillation | Code remains, no UI exposure, not a release milestone |
| Custom 1B base model | No UI, deferred indefinitely |
| Mamba-2 hybrid architecture | No UI, deferred indefinitely |
| RunPod teacher-student training | No UI, deferred |
| CoreML custom model export | No code, deferred |
| "Autoresearch" language | Replaced with "Background Training" |
| "Nano" as shipping model name | Only "GPT-5.4 Nano" (OpenAI's model) remains — correct |
| "Improves while you sleep" | Removed |
| Automatic adapter deployment | Disabled — deploy gate always returns `passed: false` |

---

## 5. Verification Commands Run

### Rust Tests
```
graph-engine: 2,441 passed, 0 failed, 8 ignored
omega-mcp:       89 passed, 0 failed
omega-ax:        10 passed, 0 failed
Total:        2,540 passed, 0 failed
```

### Swift Build
`xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
**Result:** BUILD SUCCEEDED

### Swift Tests
`xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test`
**Result:** 2,601 tests in 346 suites — **ALL PASSING, 0 failures.**

Three tests were fixed in this pass:
1. `noteSwitchPersistsDistinctSessions` — `@AppStorage` cross-test pollution: prior test set `frictionEnabled = false` via shared UserDefaults. Fix: explicitly set `frictionEnabled = true` in test config and restore after disabled test.
2. `blocklistRejects` — Same `@AppStorage` pollution: prior test's allowlist persisted. Fix: reset `allowlistJSON = "[]"` before assertions.
3. `knowledgeHyperparams` — Asserted old rank 32/alpha 64. Fix: updated test + Python script to match new rank 16/alpha 32 defaults.

Two regression tests were added in a later audit pass:
1. `NotesAgent collectsnippet flushes editor state and notifies body changes for session notes`
2. `NotesAgent savecitation flushes editor state and notifies body changes for session notes`

### Manual Verification (from master plan Section 11)
**Result:** PARTIALLY PERFORMED. Full runtime verification is still pending.

Completed live spot-checks:
- Settings -> Inference loaded with a local Qwen 3.5 tier selected and installed
- Mini Chat returned a basic local-Qwen response on the installed 4B tier
- Settings -> Knowledge Fusion label rendered as "Knowledge Fusion (Experimental)"

Still unverified:
- Qwen install/select from a clean state
- Triage routing (Apple Intelligence vs Qwen vs Cloud)
- Chat streaming outside the Mini Chat spot-check, plus note AI streaming
- Omega task execution and research task execution end to end
- Adapter lifecycle (activate/deactivate)
- Failure states are non-destructive

### Grep Verifications
| Check | Result |
|---|---|
| `passed: true` in TrainingScheduler.swift | **0 matches** — fully fail-closed |
| "Autoresearch" in TrainOnVaultView.swift | **0 matches** — all replaced |
| "improves while you sleep" in all .swift | **0 matches** — removed |
| "self-improving" in all .swift | **0 matches** — clean |
| "autonomous brain" in all .swift | **0 matches** — clean |
| "Experimental" labels present | **6 locations** — KF sidebar, TrainOnVault header, Start Training button, Overnight toggle, Embodied capture toggle, Graph settings (unrelated) |
| "Nano" user-facing (excluding OpenAI model name) | **0 matches** — clean |

---

## 6. Remaining Items

| Item | Severity | Notes |
|---|---|---|
| Full manual runtime matrix incomplete | **Blocking** | Partial spot-checks passed for Inference settings, KF labeling, and a basic Mini Chat Qwen response; onboarding, note AI, Omega/research, and adapter lifecycle still require manual testing |
| NightBrain deferred jobs (semantic summarization, embedding drift) | By design | Explicitly marked DEFERRED in code comments. Not release-blocking. |
| Full BFCL eval integration in deploy gate | Deferred | Too complex for this release. Manual adapter activation is the safe path. |

---

## 7. Final Release Readiness Verdict

**Code fixes are complete. The app is NOT yet verified as release-ready.**

What is done:
- **All identified code fixes** are applied and the project compiles cleanly.
- **Deploy gate** is fully fail-closed.
- **Messaging cleanup** is complete — no overclaims, no custom-model promises, experimental labels applied.
- **2,540 Rust tests** pass. **2,601 Swift tests** pass with zero failures. **Swift build** succeeds.
- **Three previously failing tests** fixed (friction persistence, blocklist isolation, hyperparameter compliance).
- **Later regression fixes** added coverage for NotesAgent session-note safety, research handoff visibility, vault-restore isolation, and Omega experimental training copy.
- **Grep verification** confirms no remaining problematic user-facing strings.

What is NOT done:
- **Qwen runtime** has been audited by file read and only lightly spot-checked live, not fully manually tested end to end.
- **Manual verification** of KF safety, Omega/research execution, onboarding flow, and note-AI streaming is only partially complete.
- These require user interaction on real hardware with a running app instance.

**Verdict: Code-complete and test-verified. Partial runtime spot-checks are in place, but full manual runtime verification by user is still the remaining gate before ship.**
