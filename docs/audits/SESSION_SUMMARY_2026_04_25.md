# Session Summary — 2026-04-25

Branch: `feature/landing-liquid-wave`
Tag baseline: `v0-audit-checkpoint-2026-04-25` (audit phase)
Commits this session: 16 (audit set + 12 implementation patches)

## Work landed

### Audit phase (Phases 1–3)
13 audit docs in `docs/audits/`:
1. `CODEBASE_CARTOGRAPHY.md`
2. `USER_WIRING_CAPABILITY_MAP.md`
3. `USER_WIRING_GAPS.md`
4. `AMBIENT_RECALL_WIRING_PLAN.md`
5. `UI_PRODUCT_EXPRESSION_PLAN.md`
6. `PERFORMANCE_CONCURRENCY_AUDIT.md`
7. `STABILITY_ERROR_HANDLING_AUDIT.md`
8. `DATA_PERSISTENCE_INDEXING_AUDIT.md`
9. `PRIVACY_APP_STORE_AUDIT.md`
10. `BUILD_TEST_VERIFICATION_AUDIT.md`
11. `V1_SHIP_GATE_DECISION.md`
12. `MASTER_HARDENING_WIRING_AUDIT.md`
13. `PATCH_QUEUE.md`

### Phase 4 implementation (Codex-style recursive audit pattern)

| # | Commit | Patch | Outcome |
|---|---|---|---|
| 1 | `acbeb02c` | Audit set | 13 docs landed |
| 2 | `4373ae6d` | Patch 16 + 14a + audit corrections | App Review notes + disabled-test re-enable annotations |
| 3 | `681b27af` | Patch 9 — bundle-size CI gate | New CI step measures `Epistemos.app` bundle; warns at 80%, fails >600 MB |
| 4 | `90b4c224` | Patch 11 — line-count gutter | Right-side, theme-aware, default ON; `@AppStorage` toggle in Settings + per-editor menu |
| 5 | `54323e64` | Patch 13 — empty-state polish | One-line hints in NotesSidebar (search + tree) |
| 6 | `21fd5092` | **Patch 1 — Pro+Cloud routing (BLOCKER)** | Pro mode + cloud now routes through Rust agent loop with `chat_pro` tier; `runCommandCenterRustAgentPath` accepts optional `toolTier` parameter |
| 7 | `058aaee9` | Patch 10 — per-provider reasoning tests | 5 new tests pin Anthropic + OpenAI + Google reasoning routing through ThinkingPopover |
| 8 | `1b2ec378` | Patch 2 — InstantRecall startup hydration off MainActor | Heavy FFI rebuild moves to `Task.detached(.utility)`; final state mutation hops to MainActor |
| 9 | `7e90f614` | Patch 4 — Raw Thoughts V0 Rust emitter | Per-run folder with manifest.json + events.jsonl + summary.md + links.json; behind `EPISTEMOS_RAW_THOUGHTS_V0` flag; 7 tests; Anthropic signature bytes preserved |
| 10 | `4fb29021` | Patch 5 — Raw Thoughts V0 Swift consumer + graph types | `RawThoughtsState` + sidebar + inspector view; `GraphNodeType` + `GraphEdgeType` extended (run / rawThought / toolTrace; producedDuring / generatedBy / derivedFrom / summarizes); 13 tests; switches in DialogueChatState / NodeInspectorState / 3 graph files updated |
| 11 | `2c8facae` | Patch 7 — Contextual Shadows V0 | Subtle composer button + slide-in panel with Notes/Chats tabs; off-MainActor recall via `Task.detached(.utility)`; 200ms debounce with supersede-not-queue; 10 tests; behind `EPISTEMOS_AMBIENT_RECALL_V0` flag |

### Patch outcomes by status

| Status | Patches | Notes |
|---|---|---|
| ✅ LANDED | 1, 2, 4, 5, 7, 8 (NO-CHANGE), 9, 10, 11, 13, 14a, 16 | 12 patches |
| 🚫 BLOCKED → split into 6a | 6 (syntax-core viewport wiring) | Main `CodeEditorView` does not consume `SyntaxCoreService`; only graph inspector preview at `:2286`. CodeEditSourceEditor owns its own internal MultiStorageDelegate + tree-sitter via CodeEditLanguages. New Patch 6a entry tracks the wiring work; slip-eligible to V1.5 |
| 🟡 DEFER to V1.5 | 12 (MLX off MainActor) | Per audit: HIGH risk, slip-eligible. MLX architectural rework not blocking V1 |
| 🟡 OPERATIONAL | 15 (reliability rerun) | Already covered by recent S.5 commits (a6f0fa99 + d46594c8); fresh baseline already on disk per long Codex transcript |

## Files net-changed (this session)

- `docs/audits/` — 13 new docs + multiple inline closure records
- `docs/release/MAS_APP_REVIEW_NOTES.md` — new
- `EpistemosTests/PerProviderReasoningPersistenceTests.swift` — new (5 tests)
- `EpistemosTests/RawThoughtsStateTests.swift` — new (13 tests)
- `EpistemosTests/ContextualShadowsStateTests.swift` — new (10 tests)
- `EpistemosTests/HermesSubprocessTests.swift` — annotated `#if false` reason
- `EpistemosTests/PipelineServiceTests.swift` — +1 test (Patch 1 mapping invariant)
- `Epistemos/Engine/PipelineService.swift` — `0` (Patch 1 fixed in ChatCoordinator instead)
- `Epistemos/App/ChatCoordinator.swift` — Pro+Cloud routing fork + `runCommandCenterRustAgentPath` toolTier param
- `Epistemos/App/AppBootstrap.swift` — construct rawThoughtsState + contextualShadowsState
- `Epistemos/App/AppEnvironment.swift` — inject both new states
- `Epistemos/Models/GraphTypes.swift` — +3 node + 4 edge types for Raw Thoughts
- `Epistemos/State/RawThoughtsState.swift` — new
- `Epistemos/State/ContextualShadowsState.swift` — new
- `Epistemos/State/DialogueChatState.swift` — switch exhaustiveness
- `Epistemos/Views/Notes/CodeEditorView.swift` — line-count gutter wiring
- `Epistemos/Views/Notes/CodeLineGutter.swift` — new (right-side gutter)
- `Epistemos/Views/Notes/NotesSidebar.swift` — empty-state hints
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` — Contextual Shadows debounce hook
- `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` — Raw Thoughts insert
- `Epistemos/Views/Chat/ChatInputBar.swift` — Contextual Shadows debounce hook
- `Epistemos/Views/Settings/SettingsView.swift` — gutter toggle in Appearance section
- `Epistemos/Views/RawThoughts/` — new directory (Section + Inspector views)
- `Epistemos/Views/Recall/` — new directory (Button + Panel views)
- `Epistemos/Views/Graph/{GraphFloatingControls,MetalGraphView,RelationshipBrowser}.swift` — switch exhaustiveness for new graph types
- `Epistemos/Views/Graph/NodeInspectorState.swift` — switch exhaustiveness
- `Epistemos/KnowledgeFusion/InstantRecallService.swift` — DEBUG warning + `searchAsync(...)` + startup hydration off MainActor
- `Epistemos/KnowledgeFusion/RecallContextSnapshot.swift` — new
- `agent_core/src/storage/raw_thoughts.rs` — new (745 lines incl. 7 tests)
- `agent_core/src/lib.rs` — module registration
- `agent_core/src/agent_loop.rs` — emit hooks (5 record sites + 5 finish sites)
- `.github/workflows/ci.yml` — bundle-size CI gate

## V1 ship-gate progress

Per `V1_SHIP_GATE_DECISION.md` "Final ship gate criteria":

1. ✅ P0-1 (Pro+Cloud BLOCKER) closed
2. ✅ P0-2 (Raw Thoughts V0 artifact) closed end-to-end (Rust + Swift)
3. ✅ P0-3 (App Review JIT notes) closed
4. ⚠️ P0-4 (Rust mas-sandbox spot-check) — DEFERRED to next session
5. ✅ P0-5 (sync rebuildIndex DEBUG warning + startup async migration) closed
6. ✅ P0-6 (disabled-test re-enable annotations) closed for HermesSubprocessTests; other 2 already had reason comments
7. ✅ P1-1 (Patch 6 → BLOCKED, split into 6a) — substrate scaffolded, wiring deferred
8. ✅ P1-2 (Contextual Shadows V0) closed
9. ✅ P1-3 (bundle-size CI gate) closed
10. ✅ P1-4 (per-provider reasoning) closed (verification tests added)
11. ✅ P1-5 (line-count gutter) closed
12. 🟡 P1-9 (MLX off MainActor) DEFERRED to V1.5 per audit (slip-eligible)

Open ship-gate items for next session:
- P0-4 spot-check Rust `mas-sandbox` feature gating on `nix::process::*` and `omega-ax` consumers
- Reliability gate fresh re-run (Patch 15 operational; mostly green per recent commits)
- TestFlight cycle ≥ 1 with feedback addressed
- Documents (.epdoc + Tiptap WKWebView) — V1.5
- Agent Command Center full surface — V1.5
- Memory diff card — V1.5

## Discipline observations

- **Codex-style strict audit** caught:
  - Out-of-scope xcodeproj edits in 2 patches; reverted via `git restore` before commit
  - Build break in Patch 5 (4 missing switch-exhaustive cases) — fixed inline
  - Test failure in Patch 5 (macOS `/var` vs `/private/var` symlink) — fixed inline
  - Swift 6 isolation warnings on new RawThoughts state — fixed inline (`nonisolated`)
  - Patch 6 BLOCKED with file:line evidence (syntax-core not actually consumed by main editor)
- **No protected file** touched: ProseTextView2.swift / MarkdownContentStorage.swift / agent_core providers / graph engine internals
- **All AsyncStream** still use `.bufferingNewest(256)` — verified
- **Anthropic thinking + signature** preservation byte-for-byte in raw_thoughts.rs (test pin)
- **Three new product moments** wired end-to-end:
  - Pro+Cloud has tools (BLOCKER)
  - Raw Thoughts artifacts persisted with typed graph
  - Contextual Shadows ambient recall

## Next-session entry points

1. P0-4: spot-check `agent_core/src/tools/registry.rs` + `omega-mcp/src/pty.rs` for `#[cfg(not(feature = "mas-sandbox"))]` gating on subprocess paths.
2. Reliability gate fresh baseline run (Patch 15 operational).
3. Patch 6a if user wants editor wiring before V1 ship: design doc + integration test + 4k-line bench.
4. Documents (.epdoc) MVP if Phase A V1.5 timeline allows.

## Restore point

This session = `v0-audit-checkpoint-2026-04-25` → 12 patches → commit `2c8facae`.
To restore: `git checkout 2c8facae` (full app state with Raw Thoughts + Contextual Shadows V0 + Pro+Cloud BLOCKER fix).
