# Patch Queue

Date: 2026-04-25
Authority: MASTER_HARDENING_WIRING_AUDIT.md
Sort order: build-breaking → crash/stability → MainActor/perf → data integrity → ambient recall wiring → user-facing UI → App Store/privacy → tests/instrumentation → polish.

Each patch self-contained. Implement only AFTER user approves this queue.

---

## Patch 1: PipelineService — Pro+Cloud routes through Rust agent loop with chat_pro tier

Priority: **P0 (BLOCKER)**

Goal: When a user is in Pro mode and uses a cloud model and asks "find my note about X", the agent loop must invoke `vault_search` and `vault_read` instead of free-form generating an answer.

Files:
- `Epistemos/Engine/PipelineService.swift:308-330` — `shouldUseToolLoop` short-circuit at `:313-314` (`guard case .localMLX = effectiveChatSelection else { return false }`)
- `Epistemos/App/ChatCoordinator.swift:361-373` — `if effectiveOperatingMode == .agent` gate

Change summary: Allow Pro mode + cloud selection to route through `runCommandCenterRustAgentPath` (or a dedicated Pro+cloud variant) with `ChatPro` tier. `max_turns=3`, `max_tool_calls=8` (already in `ResolvedExecutionPolicy`). Preserve existing Fast / Thinking direct-stream paths.

Why: MASTER_PLAN_2026-04-19 §HH.4 narrative claims a fix; the line is still in place. Live test config (Pro + cloud) silently has zero tools.

Risk: MEDIUM. Touches the routing fork. Coverable behind a shadow-test that asserts at least one tool call on a benchmark prompt.

Rollback: revert routing change; restore `case .localMLX` short-circuit.

Verification:
- `cargo test --manifest-path agent_core/Cargo.toml --lib` (no Rust change expected)
- `xcodebuild ... test -only-testing:EpistemosTests/PipelineServiceTests`
- New test: Pro + Anthropic Claude → message "find the note about kant" → assertion: at least one tool_call event with tool_name in `{vault_search, vault_read}` is emitted.
- Manual: open chat, switch to Pro + GPT-5.4, ask "find my note about X" — verify tool invocation in transcript.

Acceptance criteria:
- New shadow test green.
- No regression in existing 7-suite sanity sweep.
- Routing-rationale popover correctly explains "Pro on cloud uses agent loop with chat_pro tools".

Dependencies: Patch 0 (Rust mas-sandbox spot-check; verifies tools available in MAS profile).

---

## Patch 2: InstantRecallService — DEBUG precondition on sync `rebuildIndex`

Priority: **P0 (HIGH)**

Goal: Eliminate the @MainActor stall path during large vault import.

Files:
- `Epistemos/KnowledgeFusion/InstantRecallService.swift:258` (sync `rebuildIndex(notes:)`)

Change summary: Add `precondition(false, "Use rebuildIndexAsync(notes:) — sync path stalls @MainActor on large vaults")` inside `#if DEBUG`. Audit all callers; migrate to `rebuildIndexAsync`. In release build, leave the function but add a `Log.warning` so we surface telemetry if anything still hits it.

Why: Sync rebuild on @MainActor will stall during 1000+ note import.

Risk: LOW. Behavior change in DEBUG only; release prints warning.

Rollback: remove precondition.

Verification:
- `xcodebuild ... test -only-testing:EpistemosTests/InstantRecallServiceTests` (when re-enabled per Patch 14)
- New test: synthetic 1000-note rebuild via async path completes; sync path hits precondition in DEBUG.
- Manual: import 100+ note vault; verify typing remains 60fps during background re-encode.

Acceptance criteria:
- All production callers use async path.
- DEBUG run with sync path triggers precondition.

Dependencies: none.

---

## Patch 3: Rust mas-sandbox feature spot-check (subprocess + AX surfaces)

Priority: **P0 (HIGH)**

Goal: Verify that every Rust call site using `nix::process::*`, PTY/term/signal, or `omega-ax` is gated by `#[cfg(not(feature = "mas-sandbox"))]` or routed only through tools that are tier-gated.

Files:
- `agent_core/src/tools/registry.rs` and submodules
- `agent_core/src/pty.rs`
- `omega-mcp/src/pty.rs`
- `omega-mcp/src/dispatcher.rs`
- `omega-mcp/src/server.rs`
- `agent_core/src/providers/openai.rs` and any HTTP client paths if they use risky `nix` calls

Change summary: Audit only — if any unguarded `nix::process::*`, add `#[cfg(not(feature = "mas-sandbox"))]`. If any `omega-ax` consumer, ensure feature-gating. Document findings in commit message.

Why: MAS profile must not link risky subprocess/AX surfaces. Single-app gating per `project.yml:189-192` post-build scrub.

Risk: LOW (audit + targeted gate additions).

Rollback: remove gate annotations.

Verification:
- `cargo build --manifest-path agent_core/Cargo.toml --features mas-sandbox` succeeds without subprocess/AX symbols.
- `cargo build --manifest-path omega-mcp/Cargo.toml --features mas-sandbox` (if applicable).
- Spot-check `nm -gU build-rust/libagent_core.dylib` in MAS variant — no `nix_*` or AX symbols.

Acceptance criteria: MAS build is grep-clean for subprocess + AX symbols.

Dependencies: none.

---

## Patch 4: Raw Thoughts V0 — Rust artifact emitter

Priority: **P0 (HIGH)**

Goal: Persist per-run Raw Thoughts artifact (manifest + events.jsonl + summary + links) under flag `EPISTEMOS_RAW_THOUGHTS_V0`.

Files:
- new: `agent_core/src/storage/raw_thoughts.rs` — emitter that writes to `Vault/Raw Thoughts/<provider>/<YYYY-MM-DD_run-id>/`
- modify: `agent_core/src/agent_loop.rs` — emit on stream events (thinking_delta, signature_delta, tool_use, tool_result, reasoning_summary)
- modify: `agent_core/src/bridge.rs` — UniFFI export to enable/disable feature
- modify: `agent_core/src/lib.rs` — register module

Change summary: Add structured per-run folder. `manifest.json` (run id, prompt id, provider, model, started/ended, status). `events.jsonl` (one event per line, raw provider deltas). `summary.md` (planner + execution summary, app-owned). `links.json` (artifact + source + chat refs).

Why: USER_WIRING_GAPS G2; canonical product moat.

Risk: MEDIUM. New persistence path; must be off-MainActor.

Rollback: feature flag default OFF; remove emitter calls.

Verification:
- `cargo test --manifest-path agent_core/Cargo.toml --lib raw_thoughts`
- New test: synthetic chat with thinking + tool call → run folder appears; events.jsonl line-count matches stream event count; manifest fields populated.

Acceptance criteria: artifact folder created per run when flag is ON; absent when flag is OFF.

Dependencies: none.

---

## Patch 5: Raw Thoughts V0 — graph node/edge types + Swift consumer

Priority: **P0 (HIGH)**

Goal: Surface Raw Thoughts run artifacts in the typed graph and as a sidebar entry under existing model vault tree.

Files:
- modify: `Epistemos/Models/GraphTypes.swift` (`:7-25`) — add `Run`, `RawThought`, `ToolTrace` to `GraphNodeType`; add `produced_during`, `derived_from`, `cites`, `summarizes`, `generated_by` to edge types
- modify: `Epistemos/Models/SDGraphNode.swift`, `SDGraphEdge.swift` — migration + back-compat
- new: `Epistemos/State/RawThoughtsState.swift` (`@Observable @MainActor`)
- modify: existing model vault sidebar to render Raw Thoughts folder as a child of each model vault (file-type-driven, **NOT a new sidebar silo**)
- modify: ChatCoordinator to emit graph nodes/edges via Rust artifact emitter on chat completion

Change summary: Per gpt work / raw thoughts / claude work canon, Raw Thoughts is first-class run artifacts with typed graph integration. Reachable from the existing vault tree (file-type-driven), not a new silo.

Why: Same canon as Patch 4. Without the graph types, the artifacts are inert files.

Risk: MEDIUM. SwiftData migration. Mitigate with lightweight migration + tests.

Rollback: revert migration; remove new types.

Verification:
- `xcodebuild ... test -only-testing:EpistemosTests/GraphTypesTests` (new tests for Run/RawThought/ToolTrace types)
- Manual: send a chat → run folder appears in sidebar → graph shows Run node with edges to source notes.

Acceptance criteria: New types present and rendered; backward compat with existing 14-type system.

Dependencies: Patch 4.

---

## Patch 6: syntax-core viewport-scoped path ON by default for code files

Priority: **P1 (HIGH)** — **BLOCKED 2026-04-25, REQUIRES PATCH 6a FIRST**

Audit verdict (2026-04-25): the main `CodeEditorView` does NOT consume `SyntaxCoreService` at all. The only call site repo-wide is `CodeSyntaxHighlighter.apply` at `CodeEditorView.swift:2286`, used only by `CodeInspectorPreview` (`:2262`) and `CodeInspectorEditor` (`:2559+:2586`) — both NSTextView-based graph-inspector views, NOT the main editor. The main editor uses `SourceEditor(...)` from CodeEditSourceEditor at `:1503`, which owns its own internal `MultiStorageDelegate` + tree-sitter via `CodeEditLanguages`. There is no `highlightProvider` injection point bridging syntax-core into that path (grep across `Epistemos/` for `highlightProvider|setHighlightProvider|TreeSitterClient|HighlightProviding` returns zero matches).

Flipping the default would NOT improve 4k-line fluidity because the main editor doesn't consume syntax-core today. Patch 6 is therefore deferred until Patch 6a lands.

### Patch 6a: Wire SyntaxCoreService into CodeEditSourceEditor's highlight pipeline (NEW)

Priority: **P1.5 (HIGH, post-V1)** — significant editor rework; slip-eligible to V1.5

Goal: Make `SyntaxCoreService` the actual syntax provider for CodeEditorView's main `SourceEditor`. Either:
1. Add a custom `HighlightProviding` adapter to CodeEditSourceEditor that delegates to `SyntaxCoreService.tokensForViewport(...)` + `applies as NSAttributedString` attributes on viewport-visible ranges; OR
2. Replace the SourceEditor binding with a custom NSTextStorage path that calls `SyntaxCoreService.edit(...)` from `textViewDidChangeText` with real byte deltas.

Both options are non-trivial and may run into the same MultiStorageDelegate ownership issue that previously caused the custom-NSTextStorage path to be reverted (per CODE_EDITOR_FEATURE_AUDIT.md history).

Files:
- `Epistemos/Engine/SyntaxCoreService.swift` (existing)
- `Epistemos/Views/Notes/CodeEditorView.swift` (consumer)
- LocalPackages/CodeEditSourceEditor/* — DO NOT modify directly; if the highlight provider extension point doesn't exist, file an upstream issue instead

Risk: HIGH (touches the editor hot path). Requires:
- Integration test asserting viewport tokens are applied as foreground-color `NSAttributedString` attributes after a keystroke
- 4k-line keystroke benchmark with <16ms p99 acceptance
- Visual parity test (screenshot-diff or color-palette assertion) so the new path matches the existing CodeEditSourceEditor color scheme

Until Patch 6a lands, the syntax-core scaffolding remains useful for the inspector path and as ground for later work. Patch 6 cannot land standalone.

Goal (original): Wire syntax-core for code-file-shaped notes; ensure 4k-line files stay fluid.

Files:
- modify: `Epistemos/Views/Notes/CodeEditorView.swift:2118-2170+2254` — flip `EPISTEMOS_USE_SYNTAX_CORE` default to ON for code MIME types
- modify: `Epistemos/Engine/SyntaxCoreService.swift:10-11` — default `useSyntaxCore` to true for `.swift`, `.rs`, `.py`, etc.; fallback to `markdown_parse_code_tokens` for unknown
- new FFI surface: ensure `SyntaxEditDelta`, `SyntaxViewportRequest`, `SyntaxTokenSpan` are bridged to Swift via `syntax-core-bridge/syntax_core.h` (verify; may already exist)
- modify: `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift` — add 4k-line .swift open + keystroke benchmark; commit baseline to `docs/architecture/BENCHMARK_BASELINES.csv`

Change summary: Per PLAN_V2 §23.4, viewport-scoped tokens with `SyntaxEditDelta` per keystroke (not full document text). Generation counter for stale-parse cancellation.

Why: BLOCKER for fluid 4k-line code experience.

Risk: HIGH. Editor regression risk. Keep `EPISTEMOS_USE_SYNTAX_CORE=0` env var as escape hatch. Differential test.

Rollback: flip default OFF.

Verification:
- Run the new 4k-line benchmark. Targets: open <500ms; keystroke-to-highlight <16ms p99.
- `xcodebuild ... test -only-testing:EpistemosTests/CodeEditorTests`
- Manual: open 4k-line .swift; type continuously; verify zero hitches in Instruments → Time Profiler.

Acceptance criteria: benchmark green; no regression in 100KB file; visual diff shows correct highlighting.

Dependencies: none (syntax-core already linked).

---

## Patch 7: Contextual Shadows V0 — state class + button + panel

Priority: **P1 (HIGH)**

Goal: Surface ambient recall (Notes + Chats tabs) per AMBIENT_RECALL_WIRING_PLAN.md.

Files:
- new: `Epistemos/State/ContextualShadowsState.swift` (`@Observable @MainActor`)
- new: `Epistemos/KnowledgeFusion/RecallContextSnapshot.swift` (`@Sendable`)
- new: `Epistemos/Views/Recall/ContextualShadowsButton.swift`
- new: `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
- modify: `Epistemos/KnowledgeFusion/InstantRecallService.swift` — add `searchAsync(query:topK:)`
- modify: `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` — 200ms debounce hook → `ContextualShadowsState.requestRecall(snapshot:)`
- modify: chat composer (likely `Epistemos/Views/Chat/ChatInputBar.swift` or equivalent) — same hook

Change summary: Per AMBIENT_RECALL_WIRING_PLAN.md. Off-MainActor query; subtle button only when results exist; panel with Notes + Chats tabs; hover preview via preview cache; click opens result.

Why: Canonical V1 product moment.

Risk: MEDIUM (perf cliff if hot path goes on MainActor). Hard rule: every step off MainActor except final state mutation.

Rollback: feature flag `EPISTEMOS_AMBIENT_RECALL_V0` default OFF.

Verification:
- New `ContextualShadowsStateTests` suite.
- Manual: type in note → button appears within 200ms after pause; click → top-5 results render <100ms.
- Instruments: verify no main-thread spans during query.

Acceptance criteria: 60fps typing maintained; recall results visible; off-MainActor verified.

Dependencies: Patch 2 (sync rebuildIndex deprecated first).

---

## Patch 8: MetalGraphView batch payload pre-allocation audit

Priority: **P1 (MEDIUM)** — **CLOSED 2026-04-25, NO-CHANGE-NEEDED**

Audit verdict (2026-04-25): both call sites are guarded — `commitGraphData()` at `MetalGraphView.swift:940/947` only fires on `lastGraphDataVersion != graphState.graphDataVersion` bumps; `commitIncrementalAdds()` at `:1056/1063` only fires when `pendingNodeAdds`/`pendingEdgeAdds` are non-empty. Neither is per-frame. Both `makeVisibleNodeBatchPayload` and `makeVisibleEdgeBatchPayload` already use `reserveCapacity(...)` discipline before `append` loops. The Rust reference pattern in `renderer.rs:3018+3212` addresses GPU scratch buffers, which is a different concern. No code change required. Audit retained as a regression-watch; if a future change moves either function into the per-frame render path, this patch must be reopened.

Goal (original): Audit `GraphNodeBatchPayload` / `GraphEdgeBatchPayload` mutation sites; reuse buffers.

Files:
- audit: `Epistemos/Views/Graph/MetalGraphView.swift`
- modify (if found): convert mutable Var arrays to `with_capacity` + reuse pattern

Change summary: Mirror Rust-side `renderer.rs:3018+3212` discipline ("Reuse pre-allocated scratch buffer") on Swift side.

Why: 10K-node graph 60fps target; per-frame growth kills latency.

Risk: LOW (mechanical audit + reuse pattern).

Rollback: trivial (revert).

Verification:
- New benchmark: 10K-node graph 60fps signpost p99 <8.3ms.
- Manual: pan/zoom 10K-node graph; verify smooth.

Acceptance criteria: signpost evidence; no allocation per frame in Allocations Instrument.

Dependencies: none.

---

## Patch 9: Bundle-size CI gate

Priority: **P1 (MEDIUM)**

Goal: Alert if MAS bundle exceeds 600MB.

Files:
- modify: `.github/workflows/ci.yml`

Change summary: Add post-build step measuring `Epistemos-AppStore.app` total bundle size; fail CI if >600MB.

Why: bundle size unmonitored; regression risk on each model-manifest or framework addition.

Risk: LOW (CI only).

Rollback: remove step.

Verification: CI green; manual: build MAS variant; bundle size logged.

Acceptance criteria: CI step active; current size logged.

Dependencies: none.

---

## Patch 10: Per-provider reasoning summary persistence verification

Priority: **P1 (MEDIUM)**

Goal: Verify Anthropic thinking summary, OpenAI reasoning summary, Google `includeThoughts` all route through ThinkingPopover and persist to `SDMessage.thinkingTrace`.

Files:
- audit: `Epistemos/Engine/LLMService.swift:2405+`
- audit: `Epistemos/Bridge/StreamingDelegate.swift`
- audit: `agent_core/src/providers/{claude.rs,openai.rs,gemini.rs}`

Change summary: Per-provider integration test that sends a reasoning-eligible prompt; verifies stream events; verifies persistence; verifies render after reload.

Why: USER_WIRING_GAPS G15.

Risk: LOW (test addition).

Rollback: trivial.

Verification: 4 new tests (one per provider); existing thinking tests pass.

Acceptance criteria: each provider's reasoning visible in popover during stream; trail persists across reload.

Dependencies: none.

---

## Patch 11: Line-count gutter (code editor)

Priority: **P1 (MEDIUM)**

Goal: Right-side line-number gutter that respects theme tokens and Dynamic Type.

Files:
- modify: `Epistemos/Views/Notes/CodeEditorView.swift`
- new: `Epistemos/Views/Notes/CodeLineGutter.swift` (small helper view)
- modify: `Epistemos/Theme/*` — add gutter tokens
- modify: Settings → editor → toggle

Change summary: Subtle gutter; right-aligned numerals; uses theme `editorGutterFg` / `editorGutterBg`. Toggle on/off via Settings + per-editor context menu. No per-frame allocation; render in scrolling container.

Why: USER_WIRING_GAPS G5; user explicitly requested.

Risk: LOW–MEDIUM (theme conflict if not careful).

Rollback: feature flag.

Verification: Manual visual review across all themes; toggle on/off; no theme clash.

Acceptance criteria: visible gutter; readable in all themes; toggle works.

Dependencies: Patch 6 (syntax-core path doesn't conflict).

---

## Patch 12: MLXInferenceService LocalMLXClient → off MainActor — **DEFERRED to V1.5 (2026-04-25)**

Closure (2026-04-25): Per `V1_SHIP_GATE_DECISION.md`, `LocalMLXClient`'s `MainActor.run` fences for setup/teardown are an acceptable Apple pattern (not a per-token hot loop). Architectural rework deferred to V1.5; risk class is HIGH and the model lifecycle is sensitive. No V1 blocker.

Priority: **P1 (LOW–MEDIUM)** — slip-eligible to V1.5

Goal: Move `LocalMLXClient` off `@MainActor`; isolate UI state to a dedicated view-model.

Files:
- modify: `Epistemos/Engine/MLXInferenceService.swift:492+1450+1664`

Change summary: Architectural — replace MainActor.run fences with proper actor isolation. Generation work runs on a dedicated actor; UI state mutates only on main.

Why: Reduces stall during model load/teardown.

Risk: HIGH (model lifecycle is sensitive). Slip to V1.5 if at risk.

Rollback: revert.

Verification: Model load/swap during chat list scroll → no stutter.

Acceptance criteria: signpost evidence.

Dependencies: none. Slip-eligible.

---

## Patch 13: Empty-state polish

Priority: **P1 (LOW)**

Goal: Add concise first-run guidance to bare empty states.

Files:
- modify: `Epistemos/Views/Notes/NotesSidebar.swift`, vault empty state
- modify: search empty state, chat empty state, graph empty state

Change summary: One-line hint per surface. No marketing copy. No images that bloat bundle.

Risk: LOW.

Rollback: trivial.

Verification: Manual review.

Acceptance criteria: each surface has concise hint or stays as deliberate minimal state.

Dependencies: none.

---

## Patch 14: Disabled-test triage

Priority: **P1 (MEDIUM)** — corrected from P0/HIGH after direct verification. `InstantRecallTests.swift` is ACTIVE; only 3 files disabled.

Goal: Document explicit re-enable plan for the 3 disabled test files.

Files (corrected 2026-04-25):
- `EpistemosTests/HermesSubprocessTests.swift` (was bare `#if false`)
- `EpistemosTests/ExecutionContextTests.swift` (already had reason comment)
- `EpistemosTests/HermesBridgeIntegrationTests.swift` (already had reason comment)

Sub-patches:
- **Patch 14a**: ✅ DONE 2026-04-25 — annotated `HermesSubprocessTests.swift` with explicit re-enable plan (Phase Omega-2 Swift health-check bridge).
- **Patch 14b**: not needed — `ExecutionContextTests.swift` and `HermesBridgeIntegrationTests.swift` already had reason comments referencing absent legacy types.

Change summary: Document the re-enable conditions inline so future readers don't treat the suites as lost coverage.

Risk: NONE (comment-only).

Rollback: trivial.

Verification: `grep '#if false' EpistemosTests/*.swift | wc -l` returns 3; each has a comment block above describing why and when to re-enable.

Acceptance criteria: zero bare `#if false` suites without reason comment.

Dependencies: none.

---

## Patch 15: Reliability gate baseline re-run + evidence — **EFFECTIVELY CLOSED (2026-04-25)**

Closure (2026-04-25): Recent commits a6f0fa99 (docs(S.5): record full reliability gate green evidence), 4a35105b (timestamp protected reliability DerivedData roots), and d46594c8 (decouple reliability DerivedData from RESULT_ROOT and record /tmp baseline green) constitute the most recent baseline evidence. Per the long Codex audit transcript pasted into this session, baseline + ASAN + UBSAN + TSAN + soak-repeat all completed green outside protected `~/Downloads` paths. New rerun deferred to next session as part of pre-submission validation.

Priority: **P1 (MEDIUM)**

Goal: Run `bash scripts/run_reliability_quality_gates.sh` baseline; commit fresh evidence.

Files:
- run script
- artifact: `artifacts/reliability/<timestamp>/baseline.log`
- update: `docs/PHASE_S_AUDIT.md` with green-tail evidence

Change summary: Operational only.

Risk: LOW (read-only verification).

Rollback: n/a.

Verification: green tail in fresh log.

Acceptance criteria: documented green run within 7 days of ship.

Dependencies: Patches 1–14 landed.

---

## Patch 16: App Review JIT entitlement justification doc

Priority: **P0 (BLOCKER for submission, not for code)**

Goal: Reviewable artifact for App Store submission notes.

Files:
- new: `docs/release/MAS_APP_REVIEW_NOTES.md`

Change summary: 2–3 paragraphs explaining JIT used exclusively for MLX on-device inference (no user code execution). Cite specific entitlement keys.

Risk: NONE.

Verification: Doc reviewed before submission.

Acceptance criteria: doc exists; contents factual.

Dependencies: none.

---

## P2 (deferred — do not implement before V1)

| Patch | Reason |
|---|---|
| Documents (.epdoc + Tiptap WKWebView) | V1.5 |
| Agent Command Center full surface | V1.5 |
| Memory diff card | V1.5 |
| Embedded terminal (Pro) | Pro V1.5 |
| Bundled `rg`/`fd` | Pro V1.5 |
| Knowledge Core production view-model wiring | deterministic perf Sprint 3 |
| Frame-aligned token coalescing | only if benchmarks show benefit |
| Metal binary archive | deterministic perf Sprint 3 |
| substrate-rt zero-copy ring | deterministic perf Sprint 4 |
| PGO + bumpalo arenas | deterministic perf Sprint 5 |
| Diagnostics panel | V1 polish |
| Voice/dictation in note composer | V1 polish |

---

## Patch dependency graph

```
Patch 3 (mas-sandbox spot-check) ────► Patch 1 (PipelineService Pro+Cloud)
Patch 2 (rebuildIndex precondition) ──► Patch 7 (Contextual Shadows)
Patch 4 (Rust raw thoughts emitter) ──► Patch 5 (Swift+graph types)
Patch 6 (syntax-core viewport)    ────► Patch 11 (line-count gutter)
Patch 8 (graph batch audit) ──────────► (independent)
Patch 9 (bundle-size CI) ─────────────► (independent)
Patch 10 (per-provider reasoning) ────► (independent)
Patch 12 (MLX off MainActor) ─────────► (independent, slip-eligible)
Patch 13 (empty states) ──────────────► (independent)
Patch 14 (disabled tests) ────────────► (independent, before P1-1 ideally)
Patch 15 (reliability rerun) ─────────► after Patches 1–14
Patch 16 (App Review notes) ──────────► before submission
```

---

## Implementation rules (from CLAUDE.md / AGENTS.md / canon)

- Every patch must compile, pass focused tests, and ship behind a flag where risky.
- No batched commits — one patch per commit (per memory `feedback_commit_after_change`).
- No `try!`/`as!`/`unbounded`/`DispatchQueue.main.sync`/`.repeatForever`.
- Every `unsafe` Rust block gets a `// SAFETY:` comment.
- Every change cited in the patch entry; no ad-hoc edits adjacent to scope.
- Verify with the patch's verification block before declaring done.

---

## Status

This patch queue is the input to Phase 4 (implementation). No code change should land without an entry here. Approve the queue (or modify it) before any P0/P1 implementation begins.
