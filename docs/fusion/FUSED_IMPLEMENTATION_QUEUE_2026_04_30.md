# Fused Implementation Queue - Epistemos - 2026-04-30

> **Status:** Queue proposal only. This is not implementation approval.
> **Gate:** Every item requires a deliberation brief and Codex approval before code changes.
> **Floor:** `ac8c6d28` on `feature/landing-liquid-wave`, with 503 modified and 789 untracked status entries recorded in Phase 0.

## Global Rules For Every Item

- Do not raw-merge any worktree.
- Do not stage, commit, pop stashes, delete files, or change branches unless explicitly approved.
- Do not edit `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`, graph physics/render internals, `.rlib`, DerivedData, `.xcresult`, or build outputs without explicit Codex approval.
- Treat current `graph-engine/` dirty diff as high risk and not approved for modification.
- Classify every change as Core/MAS, Pro/direct-distribution, Both, or Research-only.
- Stop immediately on unexpected source edits, protected-path drift, test regression, or Pro leakage.

## 1. Build/Test Floor Verification And Protected-Path Audit

| Field | Plan |
|---|---|
| Source clusters | Main repo, `AGENTS.md`, release-audit skill, `KIMI_FUSION_REVIEW`, `WORKTREE_INVENTORY`. |
| Current code evidence | Main is dirty: 1292 status entries, 503 modified, 789 untracked. Protected `ProseEditor*.swift`, `MetalGraphView.swift`, and `HologramController.swift` are clean by Phase 0 audit. `graph-engine/` has 12 modified files and +1008/-118 diff. |
| Why now | No implementation can be trusted until the current dirty floor builds and test risk is known. |
| Core/Pro/Both | Both, verification only. |
| Likely files | `docs/fusion/` for logs or summaries only. No source files. |
| Forbidden files | All source, project, entitlements, generated, DerivedData, `.xcresult`, `.rlib`. |
| Tests/commands | `git status --short -uall`; protected-path `git diff --name-only`; `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`; `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test`; `cargo test` in `graph-engine`; `cargo test` in `agent_core`. |
| Manual verification | Confirm no unexpected new source changes after verification; preserve logs as evidence. |
| Rollback | None for read-only commands; delete only newly-created log docs if they are wrong and deletion is explicitly approved. |
| Acceptance criteria | Fresh logs exist; protected-path audit passes; failures are triaged with exact command/date/output. |
| Stop triggers | Build/test process mutates source unexpectedly, protected paths become dirty, generated artifacts enter git status, or tests fail in a way requiring product decision. |

## 2. Dirty-Diff Stabilization And Salvage Boundary

| Field | Plan |
|---|---|
| Source clusters | Main dirty state, stashes, Lane A, verified-state doc. |
| Current code evidence | Large dirty main spans Swift app, agent_core, graph-engine, tests, docs, plist/project files. Four stashes exist and are suspect. Lane A is behind main and has one dirty `ApprovalModalView.swift`. |
| Why now | Before feature extraction, the team needs to know what is current work, what is donor residue, and what must not be overwritten. |
| Core/Pro/Both | Both, process/documentation first. |
| Likely files | `docs/fusion/` deliberation/audit docs; optionally no source at all. |
| Forbidden files | Source code, stashes, branches, generated artifacts. |
| Tests/commands | `git status --short -uall`; `git stash list`; `git stash show --stat stash@{n}`; `git worktree list`; targeted `git diff --stat`. |
| Manual verification | Compare Source Control count to shell count; identify any new source delta created by tooling. |
| Rollback | Revert only docs created for this audit if needed. Do not pop or drop stashes. |
| Acceptance criteria | A clear map of dirty lanes, owner/risk, and no-touch areas exists before coding. |
| Stop triggers | Any request to pop stashes, delete generated files, stage changes, or overwrite current dirty source. |

## 3. Halo Live-Loop Audit And Minimal V1 Proof

| Field | Plan |
|---|---|
| Source clusters | Halo/Contextual Shadows research, current `HaloController`, `HaloEditorBridge`, `ShadowSearchService`, `ContextualShadowsPanel`, external C1 claim from `Pasted markdown.md`. |
| Current code evidence | Main has Halo controller/bridge/search service and tests, but Phase 0 did not prove editor typing reaches panel-visible recall results. |
| Why now | Halo is the V1 wedge and the clearest user-facing fusion differentiator. |
| Core/Pro/Both | Core/MAS. |
| Likely files | `Epistemos/Engine/HaloController.swift`, `Epistemos/Engine/HaloEditorBridge.swift`, `Epistemos/Engine/ShadowSearchService.swift`, `Epistemos/Views/Recall/ContextualShadowsPanel.swift`, tests under `EpistemosTests/`. |
| Forbidden files | `Epistemos/Views/Notes/ProseEditor*.swift` unless a later protected-path gate approves it; `HologramController.swift`; graph physics/render internals. |
| Tests/commands | `rg "HaloController|HaloEditorBridge|ShadowSearchService|ContextualShadows"`; `xcodebuild ... -only-testing:EpistemosTests/HaloControllerTests`; `xcodebuild ... -only-testing:EpistemosTests/HaloUITests`; full build after change. |
| Manual verification | Type in a note and confirm debounce, search, and visible non-blocking panel behavior; verify no per-keystroke disk/body load cascade. |
| Rollback | Revert touched Halo/search/panel files; remove any new test-only fixtures. |
| Acceptance criteria | Wired + Reachable + Visible proof for the minimal recall loop, with nil-engine guards and no editor hot-path regression. |
| Stop triggers | Need to edit protected editor internals, FFI crashes, typing jank, or panel appears without provenance. |

## 4. Quick Capture To Typed Artifact Slice

| Field | Plan |
|---|---|
| Source clusters | Main `QuickCaptureView`, `QuickCaptureIntent`, Quick Capture worktree phases 0-12.5, mutation/provenance spine. |
| Current code evidence | Main has Quick Capture UI/intent. Worktree has route capture, semantic cache, universal undo, ExecutionReceipt, heal loop, and Tool trait patterns. |
| Why now | Quick Capture is sibling-canonical and should become a small substrate-aligned Core flow, not a raw branch merge. |
| Core/Pro/Both | Core/MAS for capture; Pro-only pieces excluded. |
| Likely files | `Epistemos/Views/Capture/QuickCaptureView.swift`, `Epistemos/Intents/Custom/NoteActionIntents.swift`, `Epistemos/Models/MutationEnvelope.swift`, graph/index projection files only after deliberation. |
| Forbidden files | Worktree raw merges, `agent_core` tool registry flattening, Pro-only browser/computer-use tools, protected editor and graph render files. |
| Tests/commands | New Swift Testing case proving capture creates typed artifact/envelope; targeted build; optional App Intent invocation test. |
| Manual verification | Trigger menu-bar/App Intent capture, confirm saved artifact appears in vault/sidebar/graph with provenance. |
| Rollback | Revert capture view/intent/envelope projection changes; feature-flag incomplete projection if needed. |
| Acceptance criteria | One minimal capture path persists durably and projects visibly without introducing parallel registry architecture. |
| Stop triggers | Capture bypasses `MutationEnvelope`, writes loose markdown only, or requires raw Quick Capture worktree merge. |

## 5. Raw Thoughts / Provenance Spine Hardening

| Field | Plan |
|---|---|
| Source clusters | `MutationEnvelope`, `RunEventLog`, verified BLAKE3/Merkle claims, Quick Capture undo/ExecutionReceipt donor patterns. |
| Current code evidence | Swift and Rust `MutationEnvelope` exist with parity tests. Dirty `agent_core` files include event/log/provider/tool areas and must be audited before edits. |
| Why now | Halo, capture, graph, and audit all rely on durable provenance rather than loose UI state. |
| Core/Pro/Both | Both; Core-safe substrate first. |
| Likely files | `Epistemos/Models/MutationEnvelope.swift`, `agent_core/src/mutations/envelope.rs`, event/log tests, possibly `agent_core/src/oplog.rs` after deliberation. |
| Forbidden files | Any large `agent_core` rewrite; stash pop; graph-engine; Pro tool surfaces. |
| Tests/commands | `xcodebuild ... -only-testing:EpistemosTests/MutationEnvelopeParityTests`; `cargo test -p agent_core`; targeted rg for `RunEventLog|MutationEnvelope|prev_hash`. |
| Manual verification | Trigger one UI action and verify durable event ordering before UI success claim. |
| Rollback | Revert substrate files and related tests together. |
| Acceptance criteria | Append-only event chain is tested, and UI paths can cite envelope/log IDs. |
| Stop triggers | Parity mismatch, missing durable commit, or broad Rust API churn. |

## 6. Code Editor And `.epdoc` Guardrail Verification

| Field | Plan |
|---|---|
| Source clusters | Editor verdict, current `SwiftTreeSitterLiveHighlighter`, `.epdoc` document bridge, tests. |
| Current code evidence | Main has SwiftTreeSitter highlighter, CodeEditor views, `EpdocDocument`, bridge, KaTeX preview, and related tests. |
| Why now | Older research repeatedly proposes editor replacements; the active decision is to preserve TextKit 2 notes and Tiptap `.epdoc`. |
| Core/Pro/Both | Core/MAS. |
| Likely files | Tests/docs first; source only if a specific failing test proves a bug. |
| Forbidden files | `ProseEditor*.swift` without protected gate; broad editor replacement; CodeEditSourceEditor/AppFlowy/Flutter swap. |
| Tests/commands | `.epdoc` tests; highlighter tests; build; targeted large-file manual test. |
| Manual verification | Open note editor, code block/editor surface, and `.epdoc`; confirm no invisible text, range drift, or bridge crash. |
| Rollback | Revert only narrow bug fix; leave architecture intact. |
| Acceptance criteria | Current editor/document direction is verified and protected from fusion drift. |
| Stop triggers | Any proposal to replace editor stack or touch protected note internals without gate. |

## 7. Pro-Only Hermes / CLI / MCP Gate Audit

| Field | Plan |
|---|---|
| Source clusters | Hermes parity worktree, Advice research, `MASTER_FUSION`, Pro gate register. |
| Current code evidence | Hermes parity branch contains provider chain, session persistence, process registry, and tool registration work. Main has agent/provider/tool files dirty. |
| Why now | Pro features are attractive but dangerous for Core/MAS release safety. |
| Core/Pro/Both | Pro/direct-distribution only, except isolated Core-safe metadata utilities. |
| Likely files | Pro gate docs first; later `agent_core/src/tools/registry.rs`, provider settings, and build flags only after deliberation. |
| Forbidden files | Core/MAS App Store target leakage, entitlements, hidden subprocess launch paths, MCP/CLI in MAS. |
| Tests/commands | MAS compile audit; `rg "Hermes|MCP|stdio|subprocess|docker|cli_passthrough"`; build both Core/MAS and Pro targets if configured. |
| Manual verification | Confirm Pro UI is gated and Core build has no visible Hermes/CLI/MCP controls. |
| Rollback | Revert Pro gate wiring; leave Core unaffected. |
| Acceptance criteria | Clear symbol/build separation and explicit capability prompts for Pro. |
| Stop triggers | MAS target references Pro-only symbols or grants hidden persistent access. |

## 8. Benchmark Harness And Graph-Engine Quarantine

| Field | Plan |
|---|---|
| Source clusters | Inspiring-Heisenberg benchmark harness, BoltFFI audit, current `graph-engine/` dirty diff. |
| Current code evidence | `graph-engine/` has 12 dirty modified files, including `knowledge_core/store.rs` +808 lines, physics/force/render/bridge changes. Protected graph render internals are not approved for modification. |
| Why now | Performance is architecture, but graph/FFI changes can crash or regress silently without benchmarks. |
| Core/Pro/Both | Both for benchmark infrastructure; graph-engine implementation remains blocked. |
| Likely files | Test/benchmark harness files only after brief; docs/logs first. |
| Forbidden files | `graph-engine/src/renderer.rs`, physics/force/motion internals, `MetalGraphView.swift`, generated `.rlib`, production BoltFFI switch. |
| Tests/commands | `cargo test`; criterion benchmarks; os_signpost baseline; Swift graph benchmark tests if available. |
| Manual verification | Run graph view under realistic vault and confirm no crash/jank before and after any future graph change. |
| Rollback | Revert benchmark-only files if they destabilize build; do not touch current graph dirty diff. |
| Acceptance criteria | Baseline exists before any graph-engine or BoltFFI work. |
| Stop triggers | Builder attempts to "fix" graph-engine dirty files before benchmark/parity brief. |

## 9. App Store / Direct Distribution Release Split

| Field | Plan |
|---|---|
| Source clusters | Release audit skill, `AGENTS.md`, App Store plist/scheme dirty files, Pro gate research. |
| Current code evidence | App Store plist/scheme/project files are dirty. Pro-only features must disappear from MAS, not merely fail at runtime. |
| Why now | Fusion work must not make release readiness worse or blur MAS vs direct distribution. |
| Core/Pro/Both | Both, with MAS/Core as release floor. |
| Likely files | Release docs/logs first; App Store plist/scheme only with dedicated gate. |
| Forbidden files | Entitlements, schemes, project file edits without release brief; hidden network/cloud fallback; Pro tools in MAS. |
| Tests/commands | Full `xcodebuild test`; archive/build validation; bundle entitlement inspection; rg for unsupported model modes and Pro symbols. |
| Manual verification | Launch MAS build profile, inspect settings/features, verify unsupported modes are absent. |
| Rollback | Revert release config changes as a unit. |
| Acceptance criteria | Explicit App Store vs direct distribution readiness matrix with zero-fail verification logs. |
| Stop triggers | Unsupported model modes remain visible, Pro symbols leak, or release config changes without audited rationale. |

## Required Next Gate

Before any queue item advances to code, create:

`docs/fusion/deliberation/<slice>_deliberation_2026_04_30.md`

It must include repo evidence, worktree donor evidence if any, research evidence, alternatives, files likely touched, protected files, tests/logs, manual verification, rollback, stop triggers, and a Core/Pro/Research classification. Codex must audit and approve that brief before implementation begins.
