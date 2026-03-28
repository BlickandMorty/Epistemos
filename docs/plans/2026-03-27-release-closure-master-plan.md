# Epistemos Release Closure Master Plan

**Date:** 2026-03-27
**Status:** Active execution
**Builds on:** `docs/plans/2026-03-27-qwen-plus-knowledge-fusion-release-plan.md`

---

## 1. Executive Release Decision

Ship Qwen as the production local model. Keep Knowledge Fusion as a Qwen adapter layer. Keep Omega and research mode. Defer all custom base-model work. Finish the app honestly.

---

## 2. Current Verified Truth

After reading all 31 source files, 7 spec documents, and 3 audit reports:

### What looks structurally sound (pending runtime verification)

| Component | Evidence |
|---|---|
| Qwen model catalog (6 variants) | `LocalModelInfrastructure.swift` — 1042 lines, complete install/select/validate lifecycle |
| MLX inference runtime | `MLXInferenceService.swift` — 827 lines, thermal throttling, idle unload, request gating |
| Triage routing | `TriageService.swift` — 1494 lines, Apple Intelligence → Qwen → Cloud chain with anti-overclaim system prompt |
| LLM gateway | `LLMService.swift` — 969 lines, streaming + non-streaming, cloud fallback |
| Note chat | `NoteChatState.swift` — 512 lines, dual-mode panel+inline, instant recall integration |
| App bootstrap | `AppBootstrap.swift` — 777 lines, full service graph, graceful DB fallback |
| Onboarding | `SetupAssistantView.swift` — 240 lines, restrained honest copy, no overclaims |
| Root UI | `RootView.swift` — 813 lines, model picker, vault recovery overlay |
| Adapter registry | `AdapterRegistry.swift` — 165 lines, atomic writes, CRUD complete |
| Adapter loader | `AdapterLoader.swift` — 106 lines, hot-swap only, memory tracking |
| KTO trainer | `KTOTrainer.swift` — 134 lines, binary feedback, 20-signal minimum |
| QLoRA trainer | `QLoRATrainer.swift` — 311 lines, subprocess bridge, progress parsing |
| Instant recall | `InstantRecallService.swift` — 208 lines, <3ms search target |
| Event store | `EventStore.swift` — 648 lines, SQLite WAL, concurrent read/write |
| Ambient capture | `AmbientCaptureService.swift` — 192 lines, debounced, secret-redacted |
| MCP bridge | `MCPBridge.swift` — 188 lines, 26 registered tools, SQLite logging |
| Safari agent | `SafariAgent.swift` — 155 lines, 6 tools including readpagecontent, searchpapers |
| Notes agent | `NotesAgent.swift` — 399 lines, 9 tools including all research tools |
| Research orchestrator | `ResearchOrchestrator.swift` — 152 lines, confidence tracking, pause triggers |
| Orchestrator state | `OrchestratorState.swift` — 528 lines, full task lifecycle, research escalation |
| Omega inference bridge | `OmegaInferenceBridge.swift` — 180 lines, 26 tool schemas injected, research rules |
| Rust test suite | 2,540 passing tests (graph-engine + omega-mcp + omega-ax) |

### What required release fixes

| Issue | File | Problem | Status |
|---|---|---|---|
| Deploy gate half-open | `TrainingScheduler.swift:349` | Returned `passed: true` when weights file existed with no quality check | **Fixed** |
| "Overnight autoresearch" label | `OmegaSettingsDetailView.swift:81` | Implied autoresearch capability and lacked Experimental labeling | **Fixed** |
| TrainOnVaultView overclaims | `TrainOnVaultView.swift` | Used "Autoresearch" / "improves while you sleep" marketing language | **Fixed** |
| Research session note append path | `NotesAgent.swift` | Session-note appends could miss live editor state and leave open notes stale | **Fixed** |
| Execution trace count scaffold | `OmegaSettingsDetailView.swift:91` | Showed `Text("—")` placeholder instead of a live MCP trace count | **Fixed** |
| CognitiveSubstrate test failure | `CognitiveSubstrateTests.swift` | `noteSwitchPersistsDistinctSessions` — `@AppStorage` state leakage across tests | **Fixed** |
| NightBrain deferred jobs | `NightBrainService.swift:17-19` | Semantic summarization and embedding drift marked DEFERRED | **By design** |

### What does NOT exist and is NOT needed for release

- Custom 1B base model weights — deferred
- MOHAWK distillation pipeline — deferred
- Mamba-2 hybrid architecture — deferred
- CoreML custom model export — deferred
- GRPO reward model — deferred
- Real IFD scoring — deferred
- 50K general macOS traces — deferred

---

## 3. What Ships As Intended Stable

These are the intended stable release surfaces once manual runtime verification is complete.

| Surface | Files | Intended release role |
|---|---|---|
| Qwen local inference | Engine/*.swift | Chat, note AI, Omega planning all stream |
| Apple Intelligence routing | TriageService.swift | Light operations route correctly |
| Note editor + AI | NoteChatState, PipelineService | Rewrite/summarize/expand/continue/analyze work |
| Knowledge graph | graph-engine (Rust) | 2,441 tests pass |
| Omega task orchestration | OrchestratorState, MCPBridge | Tool calls execute and log |
| Research mode | ResearchOrchestrator, research tools | Evidence scoring, contradiction detection, pause-and-ask |
| Vault sync | VaultSyncService | Read/write cycle stable |
| Instant recall | InstantRecallService | Sub-3ms vector search |
| Settings | SettingsView | All sections load and persist |
| Onboarding | SetupAssistantView | Honest, restrained copy |

---

## 4. What Ships As Experimental

| Feature | UI Label | Files |
|---|---|---|
| Train on Vault | "Knowledge Fusion (Experimental)" | TrainOnVaultView, KnowledgeFusionViewModel |
| Personal adapters | "(Experimental)" in section | AdapterSelectorView, TrainingHistoryView |
| KTO feedback | Part of KF Experimental | KTOTrainer, feedback logger |
| Overnight training | "Overnight adapter training (Experimental)" | TrainingScheduler, OmegaSettingsDetailView |
| Embodied capture | "Embodied data capture (Experimental)" | OrchestratorState, EmbodiedCaptureService |

---

## 5. What Is Hidden Or Deferred

| Item | Action | Reason |
|---|---|---|
| MOHAWK distillation | No UI, keep code | Not shipping a custom model |
| Custom 1B base model | No UI, keep code | Deferred per executive decision |
| Mamba-2 hybrid | No UI, keep code | Deferred |
| RunPod teacher-student | No UI | Deferred |
| "Nano" as a shipping model name | Replace in user-facing strings | Model does not exist yet |
| "Autoresearch" as a shipping promise | Reword to "adapter training" | Unproven capability |
| Plugin SDK / broad porting | Not started | Out of release scope |
| VLM Agent Desktop | Not started | Out of release scope |
| Agent Profiles | Not started | Out of release scope |

---

## 6. Qwen Recovery Plan

The Qwen runtime code looks structurally sound based on file audit. No code fixes were identified — but production-readiness requires manual runtime verification that has not yet been performed.

**Verified by file read:**
- `LocalModelInfrastructure.swift`: 6 Qwen 3.5 variants with hardware-tier recommendations
- `MLXInferenceService.swift`: Full thermal/memory management with idle unload
- `TriageService.swift`: Anti-overclaim system prompt ("Do not claim to be a different model")
- `PipelineService.swift`: Clean error when no model installed
- `SetupAssistantView.swift`: Restrained "local-first knowledge engine" copy
- `RootView.swift`: Model picker with "install a local qwen model" guidance

**Remaining verification (manual):**
1. Cold-start install of recommended Qwen variant
2. Model switching mid-session
3. Streaming in chat, note AI, and Omega planning
4. Error states when no model installed

---

## 7. Knowledge Fusion Release Stabilization Plan

### 7.1 Deploy gate — keep it fully fail-closed

**Current state:** The deploy gate now returns `passed: false` across release paths. Automatic deployment is disabled until real evaluation exists.

**Release stance:** Keep manual adapter activation through the Adapter Selector UI. Do not reintroduce auto-trust without real evaluation.

### 7.2 TrainOnVaultView messaging

**Current state:** Release-visible copy has been reworded around "adapter training" and "personalization" without the old overclaims.

**Guardrail:** Keep future strings away from "Autoresearch", "improves while you sleep", and similar self-improving model claims.

### 7.3 OmegaSettingsDetailView labeling

**Current state:** The toggle now reads "Overnight adapter training (Experimental)", nearby helper text refers to "your trained adapter", and the execution trace row now reflects the live MCP count instead of a placeholder.

**Guardrail:** Keep Experimental labeling on user-facing training toggles and embodied-capture controls.

### 7.4 Config consistency

**Current state after prior fix:** `QLoRATrainer.defaultKnowledge` now uses rank 16/alpha 32 (matches KnowledgeFusionViewModel auto-config).

**Verify:** No other code path overrides these to rank 32.

---

## 8. Omega / Research Simplification Plan

Omega and research are already well-shaped for release based on file audit:

- `OrchestratorState.swift`: Full task lifecycle with research escalation, embodied capture, ODIA trace generation
- `ResearchOrchestrator.swift`: Confidence tracking, pause triggers, max 2 escalations
- `SafariAgent.swift`: 6 tools including readpagecontent, searchpapers
- `NotesAgent.swift`: 9 tools including collectsnippet, savecitation, createresearchnote, analyzecontradiction, scoreevidence
- `OmegaInferenceBridge.swift`: Research planning rules injected when task starts with "research:"
- `MCPBridge.swift`: 26 tools registered

**One release-safe code fix was needed.** Session-note append tools now flush editor state before reading and notify open editors after mutation. Otherwise research mode remains correctly structured as an Omega task type.

**Messaging check:** Verify no Omega UI copy describes it as an "autonomous brain" or "self-improving agent."

---

## 9. UI / Messaging Cleanup Plan

### Already clean (verified by file read)
- `SetupAssistantView.swift` — "local-first knowledge engine", no overclaims
- `TriageService.swift` — "Do not claim to have browsing, external tool use, research mode, or hidden capabilities"
- `RootView.swift` — "install a local qwen model"
- `PipelineService.swift` — "No usable local Qwen model is available"

### Cleaned in this pass
| File | Outcome | Status |
|---|---|---|
| `TrainOnVaultView.swift` | Reworded to adapter-training language without overclaims | Done |
| `OmegaSettingsDetailView.swift:81` | Overnight training labeled Experimental | Done |
| `SettingsView.swift:1058` | "base model" help text kept as acceptable technical context | Keep |

---

## 10. Spec-Derived Cherry Picks For This Release

### Allowed now (already done or trivially small)
| Item | Status |
|---|---|
| Research tool registration (7 tools) | Already in code |
| `/research` routing in chat | Already in code |
| OmegaPanel research quick action | Already in code |
| Deploy gate fail-closed | Done |
| PID capture fix | Done in prior pass |
| LoRA rank unification | Done in prior pass |
| Experimental labeling | Done |

### Deferred after release
- CI/CD pipeline, Plugin SDK, VLM Desktop, Agent Profiles, Dataview queries, Kanban, Terminal emulator, full BFCL eval gate, real IFD scoring, GRPO, 50K traces, all broad porting work

### Explicitly out of scope
- Custom base model, distillation, MOHAWK, Mamba-2, RunPod, CRDT collaboration, Excalidraw port

---

## 11. Full Verification Matrix

| Category | Test | Method | Pass Criteria |
|---|---|---|---|
| Build | Swift project compiles | `xcodebuild build` | BUILD SUCCEEDED |
| Build | Rust crates compile | `cargo test` in each crate | All pass |
| Tests | Swift test suite | `xcodebuild test` | All pass |
| Tests | Research mode tests | Part of Swift suite | Research assertions pass |
| Tests | Omega agent tests | Part of Swift suite | Omega agent assertions pass |
| Runtime | Qwen model loads | Manual | Model loads, responds to query |
| Runtime | Triage routing | Manual | Apple Intelligence handles light, Qwen handles heavy |
| Runtime | Chat streaming | Manual | Tokens stream without stalls |
| Runtime | Note AI | Manual | Rewrite/summarize/expand produce output |
| Runtime | Omega task | Manual | Tool calls execute and log |
| Runtime | Research task | Manual | Multi-step plan, evidence collected, note created |
| KF | Train on Vault UI | Manual | Opens, shows Experimental label, doesn't crash |
| KF | Adapter lifecycle | Manual | Activate/deactivate doesn't break base Qwen |
| KF | Overnight default | Inspect code | `omega.overnightTraining` defaults false |
| KF | Deploy gate | Inspect code | Always returns `passed: false` without real eval |
| Messaging | No "Nano" in UI | Grep | Zero user-facing "Nano" as shipping model |
| Messaging | No custom model claims | Grep | Zero "new model" / "own model" promises |
| Messaging | Experimental labels | Visual | KF section, Train button, Overnight toggle labeled |

---

## 12. Final Ship Checklist

- [x] Deploy gate fully fail-closed (line 349 fixed)
- [x] TrainOnVaultView messaging audit complete
- [x] OmegaSettingsDetailView "Overnight" labeled Experimental
- [x] No remaining "Nano" in user-facing strings
- [x] No overclaim language in any settings/onboarding surface
- [x] `xcodebuild build` succeeds
- [x] `xcodebuild test` passes
- [x] `cargo test` passes in graph-engine, omega-mcp, omega-ax
- [ ] Qwen runtime verified (chat, note AI, Omega planning)
- [ ] Knowledge Fusion surfaces verified (safe, labeled, non-destructive)
- [ ] Research mode verified (tools registered, execution visible)
- [x] Final report written at `docs/plans/2026-03-27-final-release-closure-report.md`
