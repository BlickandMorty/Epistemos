# Epistemos Pre-Flight Audit Report

Generated: 2026-03-27
Auditor: Claude Code
Branch: feature/knowledge-fusion-v1

## CRITICAL ISSUES (block all implementation)

None. All previously critical issues from the master prompt (NotesAgent stub, FileAgent nil vault, ConfirmationGate polling, missing logExecution) have been resolved.

## HIGH PRIORITY ISSUES

- [HIGH] Screen2AXService.swift: VLM model not wired — returns placeholder `{"elements": []}`. Production fallback (Screen2AXFusion with Apple Vision OCR) works. VLM is Ω19+ work.
- [HIGH] Training data: 5 categories still under 20 examples (error_recovery: 17, temporal_sequential: 10, multi_app_workflow: 10, macos_knowledge: 6, error_diagnosis: 3). Functional but could benefit from more examples.
- [HIGH] `epistemos_vault` in MOHAWK Stage 3: Fixed in code but running pod has the OLD script. Stage 3 data will only load if the pod is restarted with the new script (the SFT watcher will compensate).
- [HIGH] ConstrainedDecodingService: `isFullyConstraining = false` — soft EOS penalties only, not true grammar masking. Correctly disabled.

## WARNINGS

- [WARN] AppStoreHelper.swift: UDS connection not implemented (`GatewayError.helperNotInstalled`). Expected per Ω17 prep.
- [WARN] No Cargo workspace root — each Rust crate builds independently.
- [WARN] Task.sleep in OrchestratorState.swift lines 186/195 — legitimate exponential backoff, NOT polling.

## TRAINING DATA STATUS

| Category | Examples | Min Target | Status |
|----------|--------:|----------:|--------|
| symbol_qa | 3,070 | 20 | ✅ |
| code_graph | 557 | 20 | ✅ |
| ax_atlas | 146 | 20 | ✅ |
| tool_call | 144 | 20 | ✅ |
| scroll_gesture | 66 | 20 | ✅ |
| axpress_schema | 51 | 20 | ✅ |
| trajectory | 43 | 20 | ✅ |
| code_grounded | 26 | 20 | ✅ |
| reasoning_chain | 23 | 20 | ✅ |
| negative | 20 | 20 | ✅ |
| error_recovery | 17 | 20 | ⚠️ close |
| temporal_sequential | 10 | 20 | ⚠️ low |
| multi_app_workflow | 10 | 20 | ⚠️ low |
| macos_knowledge | 6 | 20 | ⚠️ low |
| error_diagnosis | 3 | 20 | ⚠️ low |
| **TOTAL** | **4,192** | | |

Training data includes:
- ✅ Reasoning chains with `<think>` tags
- ✅ AXPress format (action/selector/value/modifiers)
- ✅ Scroll matrix (4 directions × 3 speeds × 5 app contexts)
- ✅ Code-grounded examples (source code ↔ UI element fusion)
- ✅ Negative examples (when NOT to act)
- ✅ Error recovery with AXPress format
- ✅ Multi-app workflows (Safari, Mail, Finder, Calendar, Messages, Terminal)
- ✅ macOS system knowledge (AX roles, CGEvent, TCC, key codes)
- ✅ Temporal/sequential task understanding

## ARCHITECTURE VIOLATIONS FOUND

**ZERO violations detected across all 43 Omega Swift files:**
- No ObservableObject (all use @Observable) ✅
- No @Published ✅
- No XCTest ✅
- No try! or force unwrap ✅
- No DispatchQueue.main.asyncAfter ✅
- No direct osascript calls from agents ✅
- No MLX inference in Rust ✅
- No state management in Swift/Omega ✅
- No layer skipping (Views → Tool layer) ✅

## STUB INVENTORY

| File | Status | Notes |
|------|--------|-------|
| Screen2AXService.swift | STUB | VLM not wired, returns empty elements. Production uses Screen2AXFusion (OCR). |
| AppStoreHelper.swift | PARTIAL | SMAppService real, UDS connection stub. Expected per Ω17. |

All other files (41/43) are **EXISTS-REAL** with production implementations.

## BUILD STATUS

| Component | Status | Tests |
|-----------|--------|-------|
| Rust omega-mcp | ✅ PASS | Compiles clean |
| Rust omega-ax | ✅ PASS | Compiles clean |
| Rust epistemos-core | ✅ PASS | Compiles clean |
| Rust graph-engine | ✅ PASS | 2,441 passed, 0 failed, 8 ignored |

## FILE EXISTENCE SUMMARY

| Category | Present | Total | Status |
|----------|--------:|------:|--------|
| Rust source files (.rs) | 94 | 94 | ✅ All present |
| Swift Omega files | 43 | 43 | ✅ All present |
| UniFFI .udl bindings | 3 | 3 | ✅ All present |
| Generated Swift bindings | 3 | 3 | ✅ All present |
| Training scripts (.py) | 5 | 5 | ✅ All present |
| JSONL training data | 17 files | 4,192 records | ✅ |
| Key documentation | 4 | 4 | ✅ |

## TRAINING PIPELINE STATUS

| Stage | Status | Notes |
|-------|--------|-------|
| MOHAWK Stage 1 | 🔄 Running | Step 1100/4577, loss 8.71, ~6h remaining |
| MOHAWK Stage 2 | ⏳ Queued | Auto-starts after Stage 1 |
| MOHAWK Stage 3 | ⏳ Queued | epistemos_vault wired at 15%, data uploaded |
| Post-MOHAWK SFT | ⏳ Watching | Auto-starts via run_sft_after_mohawk.sh in tmux |
| Training data | ✅ Ready | 4,192 examples across 15 categories on pod |

## RunPod Status

- Pod ID: wdee1fzm86gw7k
- GPU: A100 80GB
- Balance: ~$56 (need ~$55-65 total)
- Throughput: 10,500 tok/s
- ETA Stage 1 complete: ~6 hours from now

## WHAT IS READY (no changes needed)

- All 6 Omega Agents (NotesAgent, FileAgent, SafariAgent, TerminalAgent, AutomationAgent, OmegaAgent protocol)
- All 6 Orchestrator files (OrchestratorState, TaskGraph, ConfirmationGate, ResearchPause, OmegaInferenceBridge, OmegaTrainingCoordinator)
- All 10 Inference files (ToolCallParser, OmegaPlanningService, ConstrainedDecoding, MLXConstrained, ToolSchemaGrammar, DeviceAgent, DualBrain, HardwareTier, ReasoningLoop, ReasoningTraceLogger)
- All 5 Knowledge files (AgentGraphMemory, GhostBrainCoauthor, RecipeGraphSkills, ODIATraceGenerator, TraceDataMixer)
- All 4 Vision files (Screen2AXFusion, AXSemanticSelector, VisualVerifyLoop, ScreenCaptureService) — production pipeline is real
- All 7 Views/Omega files
- Graph engine (2,441 tests passing)
- All Rust crates compile clean
- Training data generated and uploaded to RunPod
