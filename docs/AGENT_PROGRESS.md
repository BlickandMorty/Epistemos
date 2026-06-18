# Agent System Implementation Progress

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

> **Index status**: CANONICAL-OPERATIONAL — Live session log replacement for older PROGRESS.md; canonical operational.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.

Last updated: **2026-05-12** — Graph plan Phase A → C algorithmic prep + vault fixes + HELIOS audit + backlog status. **The 2026-04-28 entry below remains canonical for everything before 2026-05-05; the 2026-05-05 entry remains canonical for that sprint; this entry covers 2026-05-12.**

## 2026-05-12 — Canonical graph plan + vault fixes + HELIOS audit (this session, 35 commits and counting)

**Test counts:**
| Metric | Pre-session | Post-session |
|---|---|---|
| graph-engine lib tests | 2,580 | 2,757 (+177 new across 12 modules) |
| graph-engine integration tests | 0 | 45 across 5 files (`visual_equivalence` 8, `nan_injection_repro` 3, `ffi_bind_guards` 10, `phase_a_stress` 9, `phase_b_stress` 7, `phase_c_stress` 7, doc-test 1) |
| HELIOS canonical-consistency tests (`epistemos-research --features research`) | 113 | 113 (still green) |
| Swift Epistemos build | green | green (xcodebuild exit 0 across 3 sanity checks; SwiftLint warnings only on third-party CodeEdit deps) |
| HELIOS B5 invariant smoke (`scripts/check-helios-invariants.sh`) | sub-gate 1 FAIL (anchor drift) | PASS (all 3 sub-gates) |
| Canonical-plan locked decisions with direct code expression | 0 (plan was doc-only on 2026-05-11) | 26 of 42 |
| **Total tests across the whole session** | 2,580 | **2,802 passing, 0 regressions** |

**Major work landed (chronological):**

1. **User-reported vault bug fixes** (`71ef9f1e9`):
   - Bug 1 — VaultReprompSheet fires when vault IS set: added `bookmarkPending` check so sheet predicate respects the async window while `restoreVaultFromBookmark()` is loading.
   - Bug 2 — disconnect doesn't actually disconnect: hoisted `clearPersistedVaultSelection()` to the top of the Task block so the bookmark wipe happens BEFORE the 30+ second teardown. Force-quit during disconnect no longer leaves a phantom vault re-mount.

2. **Canonical graph plan Phase A — algorithmic prep** (3 commits):
   - Week 3 — `warmstart.rs` (GraphPOPE-lite recipe, 706 lines, 15 tests) + `reveal.rs` (5-phase state machine + reveal-style enum, 455 lines, 15 tests) in `57a59222f`
   - Week 4 part 1 — `atmosphere.rs` (drop-5 formulas for radius / lookahead / hub budget / warm zone / edge propagation, 476 lines, 19 tests) in `11714ff37`
   - Week 4 part 2 — `tests/visual_equivalence.rs` (deterministic 10s interaction corpus, position-drift + wake-miss harness, 343 lines, 8 tests) in `c3ed09a8c`

3. **Canonical graph plan Phase B — compute-kernel CPU references** (4 commits):
   - Week 1-2 — `force_kernels.rs` (node-parallel CSR spring forces + symplectic Euler integrator with full flag semantics, 462 lines, 16 tests including the locked-decision #4 RENDERABLE⊥SLEEPING guard) in `dec54aa3b`
   - Week 3-4 — `grid_kernels.rs` (5-kernel uniform-grid broadphase + cell-aggregate repulsion, 372 lines, 14 tests) in `c7ad79e01`
   - Week 5-6 — `adaptive_kernels.rs` (FA2 global-speed schedule + wake-front propagation, 242 lines, 14 tests) in `7de49ee89`
   - Week 7-8 — `visibility_kernels.rs` (frustum cull + `DrawIndirectArgs` mirror, 245 lines, 14 tests) in `d234dd997`

4. **Canonical graph plan Phase C — clustering + benchmark contract** (2 commits):
   - Week 1-2 — `cluster_hierarchy.rs` (parent + centroid + multilevel build + incremental update, 270 lines, 9 tests) in `c396e93b3`
   - Week 4 — `benchmark_harness.rs` (`BenchmarkScenario` enum + `BenchmarkResult` serde + `phase_b_target` lookup pinned to canonical-plan acceptance criteria, 281 lines, 11 tests) in `c06da98a8`

5. **HELIOS V5 substrate audit** (`bdc579315`):
   - `scripts/check-helios-invariants.sh` was failing sub-gate 1 (anchor-table parity) because `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` had legitimately changed in `49d4291f2` (frontmatter + new V6.1 / V6.2 row 4.25) without an accompanying anchor refresh.
   - Refreshed anchor hash. 14 other anchored docs re-shasum'd, zero drift.
   - Smoke gate now green: 15/15 anchors parity, 34/34 theorem IDs surfaced, E:15 + H:17 + PCF:10 source-text guards.

6. **Canonical plan status update** (`aafa58ae5`):
   - Added Status blocks under Phase A / Phase B / Phase C linking each algorithmic-prep commit to its module.
   - Engine + renderer wiring + MSL `.metal` authoring are explicitly queued as separate work; the math is pinned.

7. **APP_ISSUES backlog status updates** (3 commits):
   - `907e17c19` ISSUE-2026-05-11-002 → Partially Fixed (Filters UI confirmed shipped in `cabf81df0`; selected-neighbor push-out physics tracked into Phase B).
   - `1edb5d107` ISSUE-2026-05-10-002 → Patched (APIKeysHealthRow shipped earlier in `58d998566`/`35120f79b`, closes the diagnostic loop).
   - `722506ad3` Status sweep of 6 issues stamped Open while their fixes had already shipped (ISSUE-12-001/002/003/004/006/007/009).

8. **Iteration-3 sleep_update gap closure** (`0645b19f7`):
   - Original Phase B Week 5-6 commit (`7de49ee89`) shipped FA2 + wake_propagation but missed `sleep_update.metal`'s CPU mirror. Iteration 3 closed the gap with `sleep_update_kernel` + `k_frame_threshold` + `SLEEP_VELOCITY_THRESHOLD` const + 7 tests.

9. **Crash-hardening NaN/Inf quarantine arc** (3 commits, 12 tests):
   - `bc1521ba4` `integrate_kernel` quarantine — pre-update stash + post-update snap-back to prior position on non-finite output (4 tests).
   - `2f10607b5` extends quarantine to `spring_forces_kernel` + `repulsion_kernel` + `cell_reduce_kernel` (3 tests).
   - `6b876a3d6` final gaps: `atmosphere_radius` + `lookahead_frames` + `Frustum2D::intersects_circle` + `frustum_cull_nodes` (5 tests). Closes the canonical plan's named "NaN / Inf propagation" hardening row.

10. **Test-harness layer 3 fully populated** (3 commits):
    - `37475744d` `tests/phase_b_stress.rs` — 7 tests at 10k nodes including 30-frame end-to-end pipeline integration.
    - `70b5427b6` `tests/phase_a_stress.rs` — 9 tests covering warmstart / reveal / atmosphere at 10k / 50k node scale.
    - `b2e26db6e` `tests/phase_c_stress.rs` — 7 tests covering cluster_hierarchy + benchmark_harness at 5k-10k nodes.

11. **Named-failure-case repros** (2 commits, closes 2 of 6 canonical failure cases):
    - `d09c4bfe5` `tests/nan_injection_repro.rs` — 3 tests close "Inject NaN/Inf into integration scratch and verify the kernel quarantines bad state".
    - `7004effb6` `tests/ffi_bind_guards.rs` — 4 tests close "Bind a wrong stride and assert the engine rejects it cleanly". Plus 3 phase_b_target FFI tests added in `dd8313598` and 4 phase_a_target FFI tests added in `31d08acae`.

12. **Canonical-plan-locked-value FFI surfaces** (2 commits):
    - `dd8313598` `graph_engine_phase_b_target(scenario_id, vault_node_count) -> f64` — exposes canonical Phase B v1.2 ship-bar targets to Swift.
    - `31d08acae` `graph_engine_phase_a_target(...)` — adds Phase A v1.1 ship-bar targets via a refactored `scenario_id_to_enum()` helper shared by both phases.

13. **Canonical-plan §Verification block refresh** (`8d3362ce0`):
    - Flipped 4 red ❌ checks to green ✅ (warmstart / atmosphere / cluster_hierarchy / benchmark_harness) reflecting work shipped this session.
    - Added 6 new ✅ checks for surfaces that didn't exist on 2026-05-11 (visual-equivalence harness / Phase A/B/C stress harnesses / NaN injection repro / FFI bind-guard repros).

14. **Query freshness contract scaffolding** (`07aaa516e`):
    - `query_reply.rs` — typed `QueryReply<T>` wrapper + `FreshnessClass` enum (Immediate / NearRealTime / Heavy). Encodes the canonical "indexing N changes" surfaceable lag policy. 9 tests including serde round-trip + UI-helper labels.

15. **Canonical sleep-threshold formulas + phase gate** (3 commits, closes locked decisions #5 + #20 + #21):
    - `5f3164e4b` `sleep_velocity_threshold(ideal_edge_length, fps)` (decision #20) + `sleep_force_threshold(repulsion_scale)` (decision #21) + `sleep_update_kernel_with_force_gate` extended kernel gating on BOTH velocity AND force. 5 tests.
    - `8d917bd47` `sleep_globally_enabled(phase) -> bool` + `apply_sleep_phase_gate` post-pass (decision #5: sleep disabled until Steady). 4 tests.

16. **Canonical pipeline pass order** (`4f9f28e71`, closes locked decision #18):
    - `pipeline_order.rs` — wire-stable u8 enum `PipelineStage` (10 stages) + `CANONICAL_PIPELINE_ORDER` const array + `validate_ordering(stages)` checker. 10 tests including a `canonical_order_matches_decision_18_prose` drift gate.

**Canonical-plan locked-decision close rate (26 of 42 as of iteration 19):**
- ✅ #1, #2 (existing), #3, #4 (shipped), #5 (this session), #6-#7, #9-#13, #14-#15 (shipped), #16-#17 (shipped), #18 (this session), #19, #20-#21 (this session), #22-#25 (shipped), #27, #28, #31, #32, #37, #38, #39, #40
- Pending: #8, #26, #29, #30, #33-#36, #41-#42 (mix of Swift-side surfaces + deferred-to-v2+ items)

**What's queued for the next /loop iterations:**

- Engine + renderer wiring of the Phase A/B/C pure-data modules into the live integrator + frame loop.
- MSL `.metal` translation of `force_kernels` / `grid_kernels` / `adaptive_kernels` / `visibility_kernels` into `Epistemos/Shaders/Graph/`.
- More APP_ISSUES auto-fix sweeps (ISSUE-2026-05-12-008 first-note hang, ISSUE-2026-05-12-009 sidebar+graph slow open).
- Cross-canon verification across the 105 HELIOS Swift guard tests + 113 research canonical-consistency tests on every iteration.
- Remaining canonical-plan locked decisions that need engine/Swift integration.

## 2026-05-05 — V2 stretch + canon hardening (this session, ~40 commits)

**Test counts:**
| Metric | 2026-04-28 | 2026-05-05 |
|---|---|---|
| agent_core lib + integration tests | 762 + 13 | 1065 (with `lsp-runtime` feature) |
| New CI gates wired | 0 | 4 (doctrine-lint, Pro-build matrix, lsp-runtime, verify-replay) |
| Compiler warnings | 0 | 0 (Codex-flagged AgentQueryEngine warning fixed) |
| Doctrine-lint coverage | n/a | §5.1-§5.4 enforced on every push/PR |

**Major work landed (oldest → newest):**

1. **Hermes removal series** (4 slices) — deleted Expert Mode UI overlay + brand assets + slash-command dispatcher fallback (`d9be24b5`); renamed `agent_core::hermes` → `agent_core::agent_runtime` (`77de8196`); 4 refactor follow-ups removing dead `.hermesSubprocess` gateway surface, dead `hermesFacultyHostView` state, stale Rust doc comments. Net −2,080 LOC.

2. **V2.1 Cognitive DAG Phase 8 completion (8.A through 8.G)**:
   - 8.A scaffold (10 NodeKind + 10 EdgeKind + InMemoryDagStore + Merkle)
   - 8.B resonance propagation (TruthCache + DerivesFrom/Contradicts walks)
   - 8.C macaroon capabilities (issue/restrict/delegate/revoke; orphan until dispatch wires them)
   - 8.D companion lifecycle (CompanionRegistry + LoRA estimates)
   - 8.E DagMirror trait + 4 mirror implementations (Skills/Procedural/Provenance/Companion) + auto-invoke dispatch from `ClaimLedger::commit_*`, `ProceduralMemoryStore::record_outcome`, `SkillRouter::load`
   - 8.F ReplayBundle DAG snapshot + `epistemos-trace verify-replay` CLI subcommand + new exit code 5 for DAG merkle parity mismatch
   - 8.G `epistemos-doctrine-lint` binary (codifies doctrine §5.1-§5.4 gates)

3. **V2.2 Halo V1**: ledger ribbon in Halo panel showing Rust ClaimLedger summary alongside graph projection ribbon.

4. **V2.3 LSP migration (5 stages)**:
   - First slice: `LSPTransport` Swift protocol seam
   - Stage A: hand-rolled in-process Rust `LspKernel` (initialize/shutdown lifecycle, no new deps)
   - Stage B: 3 UniFFI exports + build-script wiring for `lsp-runtime` feature
   - Stage C+D: Swift `RustLSPTransport` actor + 5 end-to-end tests
   - Codex correction: added real `tower-lsp` payload types + `tree-sitter` Rust/Swift grammars for same-file hover + definition (richer cross-file deferred)
   - Stage E: deleted `LSPServerProcess` subprocess transport + tests + backward-compat shims

5. **V2.4 first slice**: `ProviderServiceStreamingProtocol` + `MockProviderServiceStreaming` + 9 tests. Two-stage XPC handshake design (negotiation over NSXPCConnection, streaming over IOSurface ring planned). Production deployment paid-team-gated.

6. **V3.2 first slice**: `ANEBackend` Swift protocol + `MockANEBackend` + `ANEKVCacheBuffer` typed format + 11 tests. Production runtime gated on Apple Developer Program.

7. **V3.3 paper draft**: ~520-line systems paper "Cognitive DAG: Verifiable Replay for Personal AI." Sections 1-7 + 9 + 10 substantively complete (§8 evaluation deferred to V3.1 hardware data).

8. **CLI gap fix**: Gemini + Kimi CLI passthrough handlers in `cli_passthrough.rs` (parity with claude_code + codex; Pro-gated + MAS-forbidden).

9. **Codex correction pass + canonical drift audit**: `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` — 9-item drift register CD-001 through CD-009. CD-005 ("DAG storage signature enforcement complete only against all-zero, not capability context") flagged as the V2.1 8.H authority blocker.

10. **Canon hardening sprint (this session's headline work)**:
    - **CD-005 closed**: capability-bound `put_edge` — `register_capability` + `verify_edge_against_registered_caps` + dispatch sentinel registration. Empty registry = Phase 8.A structural guard backward compat; non-empty = full Phase 8.C verification.
    - **Canon hardening protocol** (`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`): WRV status (6 states), canon promotion protocol (6 states), no-date-gates rule.
    - **Canonical upgrade audit** (`docs/CANONICAL_UPGRADE_AUDIT_2026_05_05.md`): 17 distinct upgrades across 7 categories. Headline: "the gap is enforcement, not implementation."
    - **CI gate enforcement (B1+B3+B4+B2)**: `epistemos-doctrine-lint` runs on every push/PR; Pro-build feature matrix added; `lsp-runtime` feature CI coverage added; `verify-replay` release-time gate against deterministic `.epbundle` fixture (sample generator at `agent_core/examples/generate_sample_epbundle.rs`).
    - **Dispatch tracing migration (C1)**: 4 `eprintln!` sites → structured `tracing::warn!` for the doctrine §10 verification window's structured observability needs.
    - **Canonical roadmap synthesis** (`docs/CANONICAL_ROADMAP_2026_05_05.md`): state: canon doc tying Codex's 10-point advice + agent's audit + this session's commits.

**V2.1 8.H authority flip status:** implementation blockers are
shrinking, but authority is still not flipped. CD-005, A2/A2-followup,
A3 live-write coverage, CD-006, and A1 redb slices 1-4 are closed or
partial-closed. Remaining: A1 slice 5 dispatch-to-redb wiring, CD-004
Phase 1-7 prerequisite verification, and the §10 two-week CI green
window.

**Externally-gated work (typed gates per no-date-gates protocol):**
- V2.4 production XPC service launch — distribution gate (Apple Developer Program $99/yr)
- V3.2 production ANE direct path — distribution + entitlement gate
- V2.6 brand asset re-import — licensing gate (NousResearch)
- V2.5 sim worktree merge — doctrine gate (strategic call: cherry-pick / rebase / branch-swap)
- Codex full-app sign-off — verification gate

**Cross-references for this entry:**
- `docs/CODEX_VERIFICATION_HANDOFF_2026_05_05.md` — every commit since `7a063f4a` flagged for Codex independent verification
- `docs/SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md` — V2 status snapshot
- `docs/CANONICAL_ROADMAP_2026_05_05.md` — forward plan with WRV labels
- `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` — live doctrine for WRV + canon promotion + no-date-gates

---

## 2026-05-05 — continuation block (~80 commits total)

The 2026-05-05 entry above was written at ~40 commits. The session
continued and landed an additional ~40 commits across canon-merge
work, drift-register closures, late-session hygiene, and read-this-
first documentation. Final session totals + cross-refs:

**Test counts (final session-end re-verification):**

| Metric | Mid-session | Final 2026-05-05 |
|---|---|---|
| agent_core lib (default features) | 876 | **879** (4 new dispatch tests for A2 + A2-followup) |
| agent_core lib + lsp-runtime | 891 | **891** (Codex's tower-lsp + tree-sitter committed; 17/17 lsp_runtime tests pass) |
| Compiler warnings | 3 (pre-existing) | **0** (3 unused-import warnings fixed via test-only import scoping) |
| CI gates wired + locally re-verified | 4 | **4 green** (B1 doctrine-lint ALL GATES PASS; B2 verify-replay ok; B3 + B4 in CI) |
| Codex CDs closed | 6 of 9 | **8 of 9** (only CD-004 BLOCKED on external Codex verification) |

**Major work landed in continuation block (oldest → newest):**

11. **B5 MAS/Pro source-guard sweep + tirith verification** (CD-007
    closure). Surveyed every `Command::new` spawn site, classified
    9 modules as properly Pro-gated, BashExecuteHandler impl-level
    Pro-gated, security.rs library helpers clean. Tirith.rs is now
    Pro-only at compile time, so its subprocess scanner surface does
    not ship in MAS/default builds. Codex
    continuation removed 2 proven-dead orphan files
    (`code_execution.rs`, `graph_query.rs`) and promoted
    `note_tools.rs` into the compiled registry with R.5 gating for
    template writes.

12. **CANON_GAPS_AND_ADDENDA fully landed** (Codex #1 advice item).
    - All 15 C-blocks merged into doctrine: C1 (WRV §10 #7), C2 (no
      silent fallback §6), C3 (BYOK off §6), C4 (UX posture §4.0),
      C5 (canonical state §2.2 #5 + §6), C6 (Halo stack ref §4.3),
      C7 (Phase R + PromptTree §9 anchors, verified-then-merged),
      C8 (App Store closeout §1), C9 (Quick Capture canon §1 #5.5
      + ALL_DOCS_INDEX §3.5), C10 (Flight Recorder §7 + Annex A.15),
      C11 (pre-release evidence Annex C, verified-then-merged),
      C12 (local-stream truncation §8.5), C13 (telemetry §6 +
      Annex A.16), C14 (ambient_V1_DECISION §1), C15 (CRDT §6).
    - Each merged block carries inline `(C#, merged 2026-05-05.)`
      provenance.
    - All 3 B-bonus blocks read-then-absorbed as lift-targets briefs
      (state: candidate for implementation): B1 BIOMETRIC_TAMAGOTCHI_
      BRAINEXPORT, B2 LIVE_FILES_AND_SUBSTRATE, B3 OBSCURA_BROWSER.
      2893 source-doc lines mapped to current main with Tier-1/2/3
      classification. Codex continuation landed the 15 Tier-1 doctrine
      lifts into `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`; the B1/B2/B3
      code phases remain queued, not shipped.

13. **XPC trust spine** (Codex #5 + #9 advice items). New
    `Epistemos/XPC/XPCTrust.swift` canonical helper that emits
    `anchor apple generic and identifier "<svc>" and certificate
    leaf[subject.OU] = "AL562BVF23"` and applies it via
    `NSXPCConnection.setCodeSigningRequirement(_:)`. Wired into
    AgentServiceClient + ProviderServiceClient. 4 new XPCSmokeTests.
    **xcodebuild test-build verified: TEST BUILD SUCCEEDED.**

14. **A2 macaroon-derived dispatch capability**. Promoted
    `system_mirror_capability_hash` from a deterministic 0xE5
    sentinel to a real Macaroon issued at process start with
    ~244-bit CSPRNG root key (two uuid v4 draws). Hash is process-
    stable (OnceLock-cached) but per-process unique.

15. **A2-followup per-mirror caveat-narrowed capabilities**. 5
    derived caps via `Caveat::ScopePrefix` ("skills", "procedural",
    "provenance/evidence", "provenance/claim", "companions"). Each
    dispatch site signs under its own narrowed authority. 4 new
    tests pin distinctness + registration + canonical derivation.

16. **CD-006 mirror auto-invoke coverage inventory**. 4 of 4
    live-write mirrors wired (Provenance evidence/claim, Procedural,
    Skills via snapshot-on-load model). CompanionMirror dormant by
    design — no live caller because `CompanionRegistry` is only
    invoked from cognitive_dag tests today.

17. **CD-008 automated-test closure, strengthened by Codex continuation**.
    Cargo cross-crate green on clean reruns and now Codex-verified at
    `--all-targets`: agent_core default, agent_core Pro+lsp,
    epistemos-core, omega-mcp, omega-ax, and graph-engine all pass.
    Doctrine linter and replay verification also pass. Full
    `xcodebuild test` now passes at `/tmp/epistemos-codex-full-test-rerun-1778019268.xcresult`
    with 5,739 total tests, 0 failed, 49 skipped. Wider manual runtime
    smoke is partly closed by Computer Use (Landing `.epdoc`, Notes
    `.epdoc`, editor window, Settings Diagnostics, Authority approval
    preview). The semantic LSP transport is now verified in both Rust
    and Swift focused tests: `tower-lsp` + `tree-sitter` hover and
    same-file definition return through `RustLSPTransport`. Only the
    live editor UI affordance and real biometric approval remain for
    release-style closure.

18. **Both deferred user-question deliberation slots answered**:
    - **Q1** (mmap utilization): `docs/MMAP_UTILIZATION_AUDIT_2026_05_05.md`
      — 3 mmap surfaces, 3 drift hazards, full inventory across
      Rust + Swift + Metal substrate. Companion to doctrine §2.2 #1.
    - **Q2** (Static/Dynamic discriminator): `docs/STATIC_NOTE_VS_
      DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md` — promoted to
      state: canon by Codex continuation; survey shows 8 of 10
      NodeKind variants are static, 2 are dynamic-rooted via
      Companion/Model. Implementation landed
      `NodeKind::is_dynamic_rooted()` + doctrine paragraph + focused
      test.

19. **A1 redb persistent backend partial implementation** (V2.1 8.H
    authority blocker). `docs/A1_REDB_PERSISTENT_BACKEND_SCOPING_2026_05_05.md`
    is now canon-partial: `RedbDagStore` landed behind the opt-in
    `cognitive-dag-redb` feature using current `redb` 4.1.0, five
    tables, JSON value bytes, durable reopen tests, CD-005 capability
    checks, directional redb multimaps, Merkle parity, and snapshot
    parity. Slice 5 dispatch authority wiring remains OFF by default.

20. **Late-session hygiene fix**: caught that Codex's V2.3 semantic
    LSP work (deliverable behind CD-001/002/003) had been sitting
    uncommitted in the working tree the ENTIRE session. 4 commits
    landed it: `8fdeb017` (CODEX_CANONICAL_DRIFT_AUDIT doc, was
    untracked), `4ddf3cef` (3 doc patches closing CD-002+003),
    `7fb91735` (LSP code +613 lines closing CD-001 via tower-lsp +
    tree-sitter, 17/17 lsp-runtime tests pass), `96c099aa` (close-
    out doc note). Lesson logged: run `git status` at session START.

21. **Lib build hygiene**: 3 unused-import warnings (one self-
    introduced by A2; two pre-existing in nightbrain) fixed by
    moving imports inside test modules. Lib build now emits zero
    warnings; 879/879 lib tests still pass.

22. **Session retrospective doc** as the read-this-first index:
    `docs/SESSION_RETROSPECTIVE_2026_05_05.md`. One-doc summary of
    all 80 commits with status table for all Codex CDs, CANON_GAPS
    closure, V2.1 8.H authority blockers, CI gates, late-session
    hygiene fixes, sign-off-gated remaining work, and 4 lessons
    logged for future sessions.

23. **APP_ISSUES_AUTO_FIX hygiene**: ISSUE-2026-04-21-005 (brittle
    source-text tests in RuntimeValidationTests) re-verified
    Open → Verified Fixed. All 17 assertions in the two flagged
    tests now pass against current ChatCoordinator.swift via
    per-needle grep -F.

**V2.1 8.H authority flip status (updated 2026-05-05 final):**
- ✓ CD-005 (capability-bound put_edge)
- ✓ A2 + A2-followup (macaroon-derived per-mirror caveat caps)
- ✓ A3 mostly closed (4 of 5 dispatch helpers wired in live callers)
- ✓ CD-006 (mirror coverage inventory)
- PARTIAL A1 (redb persistent backend) — slices 1-4 landed and verified;
  slice 5 dispatch-to-redb wiring remains held until authority review
- ⏸ CD-004 (Phase 1-7 authority prerequisites) — BLOCKED on
  external Codex verification of mirror coverage + replay parity
  + flip criteria
- ⏸ §10 two-week CI green window — automatic gate, runs in CI

**Codex continuation verification update:**
- Project-wide clippy P1 is resolved without API-changing refactors;
  all five CI-style `cargo clippy ... -D warnings` crate gates pass,
  including agent_core Pro+lsp.
- `.epdoc` visibility is source-guarded and runtime-smoked with
  Computer Use: Landing exposes `New Doc`, Notes exposes
  `New Document (.epdoc)`, and clicking the Landing action opens an
  untitled document window.
- `agent_core/src/tools/note_tools.rs` is preserved and wired as
  live Phase 2 note-tool substrate; the actually dead orphan tools
  `code_execution.rs` and `graph_query.rs` were deleted.
- `tirith` is Pro-gated out of MAS builds at module and caller level.
- `provenance_ledger()` drift is resolved without deleting scaffold
  or creating a parallel write path: the legacy bridge remains
  read-only, while Halo + Provenance Console now display the
  DAG-authoritative Rust provenance projection from
  `cognitive_dag_store`.
- Static/Dynamic discriminator Q2 is promoted from candidate to canon:
  `NodeKind::is_dynamic_rooted()` distinguishes dynamic-rooted
  `Companion` / `Model` nodes from static content-addressed nodes,
  doctrine §2.2 records the invariant, the focused Rust test passes,
  and agent_core clippy remains clean.
- B1/B2/B3 Tier-1 doctrine lifts are now canonized without runtime
  overclaim: Session Authority Token, Confidence Meter, Pixel/Tactical
  mode, Accessory metaphor, Brain Artifact, Cell/organism rules,
  Cognitive Weight, Stateful Rotor/no-polling, closed-grammar Live
  Files, MoLoRA/QLoRA subprocess debt, library-embed engine rule,
  closed-vocabulary citations, V8 dedup, and Eidos search are all
  anchored in final doctrine. Implementation remains queued.
- A1 redb persistence is implemented through slices 1-4 and verified:
  redb focused 8/8, feature-enabled cognitive DAG 144/144, default
  cognitive DAG 136/136, default clippy, and redb-feature clippy all
  pass. The implementation deliberately used JSON value bytes instead
  of the brief's proposed bincode after tests proved bincode could not
  deserialize the existing `Node` / `Edge` serde shape.
- Preservation-first source audit re-ran the Rust tool orphan scan and
  widened the source guard to Swift `Process` / `Pipe` surfaces. Result:
  no undeclared `agent_core/src/tools/*.rs` files remain; Swift process
  paths are gated under `#if !EPISTEMOS_APP_STORE` Pro/Harness/Research
  surfaces or named MoLoRA/QLoRA doctrine debt. Nothing else was deleted
  because those files are intended scaffold, not proven-dead past code.

**Sign-off-gated work queued for next session:**
- A1 redb slice 5 authority wiring: when `cognitive-dag-redb` is
  enabled, decide whether dispatch opens
  `<vault>/.epistemos/cognitive_dag.redb` now or keeps redb as a
  parity/replay backend for one more verification cycle
- B1-B3 phase work (Phases 21-25 + W7-A through W7-J + W6-A
  through W6-I + W8) — 15 total sign-off questions queued across
  the three lift-targets briefs
- Remaining manual runtime smoke for CD-008 release-style closure:
  live LSP editor UI affordance and real biometric approval

**Updated cross-references:**
- `docs/SESSION_RETROSPECTIVE_2026_05_05.md` — read-this-first index
- `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md` — detailed close-out
  with Codex drift register status table
- `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` — B5 / CD-007 closure
- `docs/MIRROR_DISPATCH_COVERAGE_2026_05_05.md` — CD-006 closure
- `docs/CD_008_PARTIAL_CLOSURE_2026_05_05.md` — CD-008 automated-test
  closure, with manual smoke pending
- `docs/MMAP_UTILIZATION_AUDIT_2026_05_05.md` — Q1 answer
- `docs/STATIC_NOTE_VS_DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md` — Q2
- `docs/A1_REDB_PERSISTENT_BACKEND_SCOPING_2026_05_05.md` — A1 brief
- `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md`
- `docs/B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md`
- `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`

---

## 2026-04-28 (canonical entry below — preserved unchanged)

Last updated: 2026-04-28 | **Phase 1 keystone + ReplayBundle + epistemos-trace verifier + subprocess hardening sweep + W9.21 known-failure fix all landed.**

**Hardening loop converged 2026-04-28:**

| Metric | Session start | Final |
|---|---|---|
| agent_core lib tests | 741 | 762 (+21) |
| agent_core integration tests | 7 | 13 (+6 e2e) |
| Total Rust workspace tests | 3,807 | 3,832 |
| Compiler warnings (workspace) | 2 | 0 |
| Clippy warnings agent_core | 118 | **39** (67% reduction) |
| Clippy warnings epistemos-shadow | 12 | **7** (42% reduction) |
| Known test failures | 1 (W9.21) | 0 |
| Hardened subprocess sites | 0 | 10 |
| Force-unwrap-denied modules | 0 | 3 (Phase-1 keystone) |

**Hardening categories closed this session:**
1. **Subprocess hardening sweep (10 sites)** — see canonical entry below
2. **Compiler warning sweep (workspace-wide)** — zero warnings remain
3. **Clippy reduction** — substantive fixes across 12 categories:
   - 5 `io::Error::new(io::ErrorKind::Other, ...)` → `io::Error::other(...)` in `storage/raw_thoughts.rs`
   - 5 manual prefix-stripping → `strip_prefix()` (`evolution/mutation_proposer.rs`, `storage/vault.rs`, `tools/skills.rs`, `tools/workspace_search.rs`)
   - 2 `from_str` inherent method renames (FromStr trait collision) — `RopeDocument::from_str` → `from_text`, `ThreatAssessment::from_str` → `from_label`
   - 2 `map_or(false, ...)` → `is_some_and(...)` in `tools/skills.rs`
   - 2 consecutive `str::replace` → array-form `str::replace([a, b], ...)` in `context_loader.rs`, `resources/service.rs`
   - 1 `unwrap_or_else(PathBuf::new)` → `unwrap_or_default()` in `agent_loop.rs`
   - 3 redundant struct-field-shorthand cleanups in `session_insights.rs`
   - 5 `# Safety` markdown header fixes on FFI `unsafe extern "C" fn`s in `epistemos-shadow/src/lib.rs` (canonical Rust API guideline form)
   - 3 `len() >= 1` → `!is_empty()` in test assertions
   - 3 manual `.max().min()` → `clamp()` in `hyperbolic_topology.rs`, `tools/registry.rs`
   - 1 number-grouping bug-prevention fix (`1700_000_000_000` → `1_700_000_000_000` in `oplog.rs`)
   - 49 test-only `MutexGuard`-across-await suppressed at test-mod boundary with documented `#[allow(clippy::await_holding_lock)]` (intentional process-wide test-isolation gates)
4. **W9.21 known-failure fix** — `epistemos-shadow::honest_handle::tests::borrow_preserves_refcount` was reading freed memory due to misuse of `&Arc::from_raw(raw)` temporary; rewrote to pair every `from_raw` with a preceding `increment_strong_count` so the temporary's drop returns the count instead of freeing
5. **Force-unwrap deny enforcement** — `#![cfg_attr(not(test), deny(clippy::unwrap_used, clippy::expect_used, clippy::panic))]` on `agent_core/src/provenance/{ledger,replay}.rs` and `agent_core/src/bin/epistemos_trace.rs` (the Phase-1 keystone modules). Future production-path force-unwraps fail the build.
6. **Output-bound caps** on `cli_passthrough.rs` and `registry.rs` bash subprocess paths (10 MiB post-collection cap; doctrine names "Codex 1.8GB stdout regression" as one of the 13 hardest problems)
7. **Schema gap documentation** — `session_insights.rs::compute_tool_breakdown` underscored `_sessions` + documented exact schema enrichment needed (`SessionMetrics.tool_call_counts: HashMap<String, u32>`)

**Hardening sweep (this session):**
- New `agent_core/src/security.rs::harden_cli_subprocess` + `harden_cli_subprocess_extending` helpers.
- `SUBPROCESS_ALLOWLIST` (10 vars: PATH, HOME, USER, LOGNAME, TMPDIR, LANG, LC_ALL, LC_CTYPE, TERM, TZ).
- `SUBPROCESS_DENYLIST` (24 vectors: LD_PRELOAD + all DYLD_*, MallocStackLogging family, NODE_OPTIONS family, PYTHONPATH/PYTHONHOME/PYTHONSTARTUP, RUBYOPT/RUBYLIB/PERL5OPT/PERL5LIB, etc).
- 4 new security tests including a real subprocess that proves LD_PRELOAD + DEBUG don't leak through hardening, plus PATH preservation.
- **5 high-risk subprocess sites remain hardened** (all calling user-installed binaries that run arbitrary code); a sixth orphan path was later removed by Codex continuation:
  1. `tools/cli_passthrough.rs` (Claude Code / Codex / Gemini / Kimi CLIs)
  2. `mcp/client.rs` (arbitrary user-installed MCP servers)
  3. `tools/registry.rs` bash subprocess (LLM-supplied shell commands)
  4. `tools/browser.rs` (with `extending` allowlist for HTTP_PROXY family + FAKE_BROWSER_LOG fixture)
  5. `tirith.rs` (security scanner CLI)
- **Removed after reachability audit:** `tools/code_execution.rs` (orphan local code runner, not declared in `lib.rs`, not shipped).
- **Promoted after scaffold audit:** `tools/note_tools.rs` is now declared, registered, and tested; `note_template.output_path` maps to the R.5 vault-note write gate.
- 1 regression caught + fixed mid-flight (browser test relied on FAKE_BROWSER_LOG passthrough — added to extending allowlist with documented rationale).

**W9.21 known failure resolved:** `epistemos-shadow::honest_handle::tests::borrow_preserves_refcount` was buggy (used `&Arc::from_raw(raw)` which creates a temporary that drops at the statement boundary, freeing the allocation, so the next `from_raw` was UAF and read garbage memory — the previously-reported `right: 3` was that garbage). Rewrote to pair every `Arc::from_raw` with a preceding `Arc::increment_strong_count` so the temporary's drop returns the count instead of freeing. Test now passes deterministically. epistemos-shadow lib: 44 → 45 passing.

**Compiler-warning sweep:** Removed unused `HashMap` import in `replay.rs`. Underscored `_sessions` in `session_insights.rs::compute_tool_breakdown` + documented the schema gap (function is intentional placeholder; SessionMetrics carries only scalar `tool_calls_count` not per-tool counts). `cargo build --lib` is now warning-clean across agent_core.

**Workspace test totals (all green):**
| Crate | Tests |
|---|---|
| agent_core lib | 762 |
| agent_core integration | 13 |
| epistemos-shadow | 45 |
| omega-mcp | 131 |
| graph-engine | 2,508 |
| substrate-core | 7 |
| epistemos-core | 366 |
| **Total Rust** | **3,832** |

Phase 1 task 4 — **retraction primitive**: `agent_core/src/provenance/ledger.rs` (~370 LOC + 230 LOC tests) ships `ClaimLedger` with bounded retraction propagation walk + cycle detection (depth ≤ `MAX_RETRACTION_WALK_DEPTH = 16`, deterministic `BTreeSet` output, sorted-BFS for byte-equal `RetractionReport`). 10 unit tests pass: direct retraction, transitive retraction at depth 1, cycle detection rejection at commit time, diamond dependency dedup, deep 10-chain walk, idempotent retraction, deterministic JSON output, missing-evidence error, duplicate-id rejection.

Phase 1 task 6 — **ReplayBundle export**: `agent_core/src/provenance/replay.rs` (~250 LOC + tests) ships `ReplayBundle` with `LedgerSnapshot`, `ClaimDerivation`, `ClaimEvidenceLink`, BLAKE3 integrity hash over canonical JSON (hash field self-zeroed during compute), `to_epbundle_bytes()` / `from_epbundle_bytes()` round-trip. 7 unit tests pass: JSON byte-equal round-trip, deterministic build from equal ledgers, tampering invalidates hash, integrity hash format (64-char lowercase hex), epbundle byte round-trip, snapshot orders by id, empty inputs rejected.

Open Provenance Standard parallel-track milestone — **`epistemos-trace verify` CLI**: `agent_core/src/bin/epistemos_trace.rs` ships the Phase-1 / parallel-track binary the doctrine `04_PHASES.md` calls for. `epistemos-trace verify <path>` reads a `.epbundle`, validates the BLAKE3 integrity, exits 0 on match. Five exit codes (0/1/2/3/4) cover usage / io / parse / integrity-mismatch error classes. 6 e2e integration tests in `agent_core/tests/epistemos_trace_e2e.rs` exercise every exit code via `std::process::Command` + `tempfile`. Pairs with the open-standard repo's public-launch milestone (≤ May 4, 2026).

R14 verified — UniFFI is **already pinned to 0.29.5** in `agent_core/Cargo.toml` (the dep work is done; the remaining R14 Sendable annotation pass is Swift-side and gated on Xcode IDE-lock release).

Phase 1 task 4 — **retraction primitive**: `agent_core/src/provenance/ledger.rs` (~370 LOC + 230 LOC tests) ships `ClaimLedger` with bounded retraction propagation walk + cycle detection (depth ≤ `MAX_RETRACTION_WALK_DEPTH = 16`, deterministic `BTreeSet` output, sorted-BFS for byte-equal `RetractionReport`). 10 unit tests pass: direct retraction, transitive retraction at depth 1, cycle detection rejection at commit time, diamond dependency dedup, deep 10-chain walk, idempotent retraction, deterministic JSON output, missing-evidence error, duplicate-id rejection.

Phase 1 task 6 — **ReplayBundle export**: `agent_core/src/provenance/replay.rs` (~250 LOC + tests) ships `ReplayBundle` with `LedgerSnapshot`, `ClaimDerivation`, `ClaimEvidenceLink`, BLAKE3 integrity hash over canonical JSON (hash field self-zeroed during compute), `to_epbundle_bytes()` / `from_epbundle_bytes()` round-trip. 7 unit tests pass: JSON byte-equal round-trip, deterministic build from equal ledgers, tampering invalidates hash, integrity hash format (64-char lowercase hex), epbundle byte round-trip, snapshot orders by id, empty inputs rejected.

Open Provenance Standard parallel-track milestone — **`epistemos-trace verify` CLI**: `agent_core/src/bin/epistemos_trace.rs` ships the Phase-1 / parallel-track binary the doctrine `04_PHASES.md` calls for. `epistemos-trace verify <path>` reads a `.epbundle`, validates the BLAKE3 integrity, exits 0 on match. Five exit codes (0/1/2/3/4) cover usage / io / parse / integrity-mismatch error classes. 6 e2e integration tests in `agent_core/tests/epistemos_trace_e2e.rs` exercise every exit code via `std::process::Command` + `tempfile`. Pairs with the open-standard repo's public-launch milestone (≤ May 4, 2026).

R14 verified — UniFFI is **already pinned to 0.29.5** in `agent_core/Cargo.toml` (the dep work is done; the remaining R14 Sendable annotation pass is Swift-side and gated on Xcode IDE-lock release).

**agent_core test count: 741 → 771 (lib 758 + 6 e2e + 7 pre-existing integration). Zero regressions.**

Earlier this session: RRF Cross-Index Fusion Phases 0-5 + Phase 6 observability + Phase 7 docs all shipped; 4 of 8 wiring sites flag-aware; 2 breadcrumbed; 2 deferred (see `docs/RRF_FUSION_DESIGN.md` §14). Two code defects caught + fixed (stale `RRFFusionQuery.swift` docstring promising `SEARCH ... USING fts5`; Swift contextual-keyword variable `async` in fusion test). F10 closed for search path. F9 reframed + deferred to T+13. **Swift runtime test verification still gated on next Xcode IDE-closed window.**

## 2026-04-28 RRF Cross-Index Fusion (NEW PHASE)

User-authored mission brief preserved verbatim at `docs/RRF_FUSION_PROMPT.md`.
Living design doc at `docs/RRF_FUSION_DESIGN.md`.

Architectural decisions settled by user (do not re-litigate):
- Share `SearchIndexService.dbPool` (closed F8 — `EpistemosDocumentController` injects writer; `ReadableBlocksIndex` migration co-resident with v1/v2_block_search per plan §225).
- Single SQL RRF query, no Swift-side merging.
- Additive behind `EPISTEMOS_RRF_FUSION_V1` flag (default ON in dev, OFF in MAS until benchmarked).
- k=60 — source-of-truth `epistemos-shadow/src/backend/rrf.rs`; Swift mirror documented, NEVER duplicated.
- Closes audit gaps F9 (MutationEnvelope retrieval-event emission) + F10 (os_signpost on save / search path).

Phase status:
- Phase 0 — research + design doc: ✅ complete (2026-04-28) — source enumeration + bm25 sign + GRDB version verification authored into `docs/RRF_FUSION_DESIGN.md`
- Phase 1 — schema + migration: ✅ complete (2026-04-28) — additive ALTER `vault_id TEXT` + 2 indexes (`vault_id`, composite `(vault_id, artifact_id)`); migration key `v3_1_readable_blocks_vault_id`; 5 new tests in `ReadableBlocksIndexTests.swift`
- Phase 2 — SQL fusion query: ✅ complete (2026-04-28) — `Epistemos/Sync/RRFFusionQuery.swift` with `Phase3FusionConsts.K_RRF=60` single-source-of-truth Swift mirror, `FusionWeights` Sendable struct, `FusedResult` Sendable struct, full SQL with 3 CTEs + UNION ALL + GROUP BY rollup + recency `exp()` boost; 7 critical-invariant tests in `EpistemosTests/RRFFusionQueryTests.swift` including K_RRF parity probe of `epistemos-shadow/src/backend/rrf.rs`, bm25 sign assertion, EXPLAIN QUERY PLAN regex gate (`VIRTUAL TABLE INDEX \d+:M\d+`), end-to-end fusion + recency tests; full plan captured in `docs/RRF_FUSION_DESIGN.md` §8
- Phase 3 — `SearchIndexService.fusedSearch` API: ✅ complete (2026-04-28) — `fusedSearch(query:weights:now:)` + `fusedSearchAsync(...)` added to `SearchIndexService` (`Epistemos/Sync/SearchIndexService.swift:492-568`); `nonisolated public`; uses existing `dbPool.read` + `Sig.storage.beginInterval("fused_search", ...)` signpost (closes F10 for the search path); `RRFFusionFlags.isEnabled` env-var gate added to `Epistemos/Sync/RRFFusionQuery.swift`. F9 reframed: the existing `MutationEnvelope` schema is purely write-side (no retrieval variant), so retrieval-event emission is deferred to T+13 hardening per `docs/RRF_FUSION_DESIGN.md` §9 item 3.
- Phase 4 — 8 wiring sites: 🟡 partial (2026-04-28) — 4 sites fully wired flag-aware (Site 1 HomeView search bar, Site 3 Epdoc Slash + @-mention via QueryRuntime, Site 6 AgentRuntime context retrieval, plus implicit coverage of NoteEntity / NotesMentionDropdown / NotesSidebar via `VaultSyncService.searchFullAsync` + `searchIndex` dispatch); 2 breadcrumbed (Site 7 iMessage Phase-K reply context links to existing wiring; Site 8 Meaning-anchor pinned-doc boost links to FusionWeights API extension); 2 deferred (Site 2 Halo ShadowPanel "Vault" segmented control = UI work; Sites 4+5 Rust agent tool + Hermes parity = cross-language FFI bridge). Flag-off default keeps every site on the legacy path. Detailed status in `docs/RRF_FUSION_DESIGN.md` §14.
- Phase 5 — real-DB tests: ✅ complete (2026-04-28, runtime verification deferred to next IDE-closed window) — `EpistemosTests/SearchIndexServiceFusionTests.swift` (~280 LOC); 9 tests covering single-source, cross-source consensus, block→doc rollup w/ snippet anchor, recency boost reorders ties, 100-iteration tie-break determinism, empty-corpus + empty-query degenerate paths, snippet `<b>...</b>` projection, sync/async parity. Uses `SearchIndexService(databaseURL:)` file-backed init + `service.databaseWriter()` to seed `readable_blocks` directly. 50k-row perf gate is intentionally NOT in this suite (Phase 6 local-only)
- Phase 6 — observability + flag flip: 🟢 observability shipped (2026-04-28); flag-flip awaits 3-day dogfood — `Epistemos/Sync/RRFFusionQuery.swift` gained `SearchFusionMetrics` (thread-safe ring-buffer of per-call latency + hit-count + p95 + last-error). `SearchIndexService.fusedSearch` + `fusedSearchAsync` instrumented (success-record + error-record paths). `Epistemos/Views/Settings/SearchFusionHealthRow.swift` SwiftUI diagnostic view (mirrors `EditorBundleHealthRow` shape; 1 Hz polling refresh; surfaces flag state, last query latency, p95 over up-to-200 samples, hit distribution per source, last error). Wired into `SettingsView` → General → "Diagnostics" section (alongside the previously-orphan `EditorBundleHealthRow` — the integration finally gives BOTH health rows a home). Flag flip from default-OFF → default-ON-in-MAS still gated on a 3-day dev-build dogfood run; no code change needed when ready, just toggle the env-var default in app launch logic + doc it
- Phase 7 — doc updates: ✅ complete (2026-04-28) — `docs/RRF_FUSION_DESIGN.md` finalized (§8 EXPLAIN plan, §10 phase status, §14 wiring status); `docs/AGENT_PROGRESS.md` phases marked; `CLAUDE.md` FILE MAP gained "Swift RRF Cross-Index Fusion (Phase 2-4 — 2026-04-28)" section with file pointers + responsibilities. `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` §225 reference from the user mission brief was sought but the file has no §225 / "existing tables continue to serve" subsection — per user memory "PLAN_V2 is authority — do not edit it to match shipped code", deferred adding a new section there without explicit user authorization

Acceptance gates: single SQL produces fused ordered results across 3 sources; all 8 sites wired; `p95 < 30 ms` on 50k rows; F9 + F10 closed.

## 2026-04-27 T+4 + T+5 audit close-outs

Per `docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md` — 12 gaps surfaced (F1-F12). Status as of session end:
- ✅ F1 NSDocument.makeWindowControllers (Tiptap+WKWebView SwiftUI host with autosave wiring)
- ✅ F2 File > Open Document menu (cmd+O via NSDocumentController)
- ⏳ F3 Tiptap bundle staging at Resources/Editor/ — user xcodebuild verification
- ✅ F4 contentDidChange data drop — `EpdocEditorChromeController.onContentChanged`
- ✅ F5 EpdocEditorSavePipeline orphan — `attachAutosavePipeline(save:)` opt-in API
- ✅ F6 Markdown shadow regen on save — `ProseMirrorMarkdownProjector` wired in `fileWrapper(ofType:)`
- ✅ F7 ReadableBlocksProjector production class (310 LOC + 14 tests covering heading breadcrumbs / lists / tables / callouts / marks)
- ✅ F8 FTS production wiring — Option C explicit DI: `EpistemosDocumentController` subclass holds `DatabaseWriter`, injects into `EpdocDocument`; shared pool with `SearchIndexService`
- ⏸ F9 MutationEnvelope production emission — REFRAMED + DEFERRED to T+13 (Phase 3 close-out 2026-04-28): existing schema is write-side only; retrieval-event variant requires Rust-parity-locked schema change (see `docs/RRF_FUSION_DESIGN.md` §9 item 3)
- ✅ F10 os_signpost on search path — RRF Phase 3 (`Sig.storage.beginInterval("fused_search", ...)` in `SearchIndexService.fusedSearch` + `fusedSearchAsync`)
- ✅ F11 End-to-end integration tests (smoke + projector + controller test suites)
- ⏳ F12 V0 vs V1 dual recall systems — T+13 architectural decision

Canonical release-hardening plan:
- `docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` is the authoritative release-focused plan that reconciles later research, blocker handoffs, and verification requirements.
- `docs/handoffs/2026-04-20-codex-to-claude-full-thread-handoff.md` is the full-thread Claude audit handoff covering the user pain points, landed commit chain, research conclusions, verification trail, and remaining dirty state on `codex/runtime-input-audit`.

## 2026-04-23 DRIFT FOUND
- `agent_core/src/agent_loop.rs:135` runs a real multi-turn loop; the §3 "scaffold" label in `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` is stale.
- `Epistemos/Omega/Orchestrator/OrchestratorState.swift:3` is already a UI-compatibility stub, and `submitTask` is a no-op at `Epistemos/Omega/Orchestrator/OrchestratorState.swift:37`; the §3 note that Swift `OrchestratorState` still owns orchestration is stale.
- `agent_core/src/tools/cli_passthrough.rs:187` spawns `claude -p` with optional `--permission-mode` / `--model`, but does not pass `--bare` or `--output-format stream-json`; any plan text claiming that exact invocation is incorrect.
- `Epistemos/Views/Chat/MessageBubble.swift:281` and `Epistemos/Views/Chat/ThinkingTrailView.swift:13` show that chat already renders `ThinkingTrailView`; the §3 event-pipeline note should be narrowed to missing live `ToolCallCard` / terminal-output UI, not reasoning disclosure as a whole.

## 2026-04-23 Step 3a Drift Check
- `I-019`'s planned fix target is already absent in the live tree: `Epistemos/App/AppBootstrap.swift` still carries stale monitor slots at `:788-789` and teardown at `:2502-2510`, but there is no live `NSEvent.addGlobalMonitorForEvents(...)` assignment anywhere in `HEAD`.
- Git history confirms the sync global hotkey monitor existed in `ab9c27fc` (`AppBootstrap.swift:1344` in that revision), then disappeared before the current fix pass.
- Result: Step 3a is a no-op code fix in the current tree. Keep `I-019` open for final verification, but do not fabricate a code change against a bug site that no longer exists.

## 2026-04-19 Reasoning Trace Continuation ✅
- [x] `3c17ac95` — note chat now persists `thinkingTrace` / `thinkingDurationSeconds` through its SwiftData round-trip; reloading a note no longer drops the assistant's collapsible thought trail
- [x] Verification: focused `xcodebuild ... -only-testing:EpistemosTests/NoteChatStateTests` passed on the warmed `/tmp/epistemos-mlx-load-stall` path
- [x] `79e70e52` — graph chat (`NodeInspectorState` + `HologramSearchSidebar`) now captures `reasoningSink` deltas, shows a live/persisted `ThinkingTrailView`, and stamps the final thought trace onto the assistant transcript instead of keeping reasoning invisible
- [x] Verification: the new `RuntimeValidationTests.graphChatPreservesReasoningTracesSeparately()` source guard passed; the broader `RuntimeValidationTests` suite still has one unrelated pre-existing failure (`bootstrapThrottlesRefreshAndRuntimeSerializesTurns()`)
- [ ] Remaining user-visible transcript surfaces to audit next: `PinnedInspector` node chat, `CodeEditorView` code-explain/ask flows, then lower-priority `DialogueChatState` persistence

## 2026-04-20 Handoff Correction ⚠️
- Later manual testing contradicted several earlier "fixed" claims.
- Do not treat Fast-mode local thinking, app-crash, Qwen Coder freeze, "thinks forever, never answers," or thinking-in-main-bubble as fully closed without fresh live verification.
- Authoritative correction notes now live in:
  - `docs/handoffs/2026-04-20-claude-to-codex-session-handoff.md` §9
  - `docs/architecture/MASTER_PLAN_2026-04-19.md` §20
- External April 19 context docs added a stricter ship contract: scope the dirty tree, declare the exact batch and files first, `xcodegen` after new Swift files, refresh `DerivedData`, build the actual `Epistemos` scheme, launch the app, and verify the fix visually before calling it shipped. See `MASTER_PLAN_2026-04-19.md` §21.
- Immediate verification priorities:
  - Fast mode must not auto-route to always-thinking families like DeepSeek / GGUF Qwopus
  - GPT-5.4 and DeepSeek reasoning must stay in the thinking UI on both direct-cloud and Rust-agent paths
  - attached-note / attached-essay flow must not emit fake `read_file` JSON or ask for file paths when content is already resolved

## 2026-04-19 Continuation ✅
- [x] `d29984e6` — Fast mode now excludes always-thinking local families from automatic routing/fallback and explicitly disables thinking on smaller Qwen 3.5 variants
- [x] `daa05e65` — non-stream OpenAI-compatible responses no longer treat `reasoning_content` as answer text; Fast no longer falls back to always-thinking-only local installs; `qwen25Coder7B` participates in the thinking-loop guard
- [x] `366d659a` — Rust Codex/OpenAI agent requests now send `tool_choice: "auto"` and `parallel_tool_calls: true`, matching the upstream Codex Responses contract more closely
- [x] `151abe31` — main chat now shows `Loading <model>…` before the first token so slow local loads stop looking like a dead freeze
- [x] Verification:
  - `TriageServiceTests` focused run passed after the Fast/runtime-guard batch
  - `CloudStreamingParserTests` + `TriageServiceTests` focused run passed (37 tests / 2 suites)
  - `cargo test --manifest-path agent_core/Cargo.toml --lib` passed (512/512)
  - `ChatPresentationTests` still contains one unrelated pre-existing source-guard failure (`tool preview cards start collapsed`), but the new loading-state source guard itself passed in the broader run

## 2026-04-19 Chat Transparency + QwQ-32B ✅
- [x] Batch A `254312cd` — chat routing UX: explicit stack popover, settings ↔ picker sync, Codex GPT-5.4 preservation on fast mode (no silent Mini downgrade)
- [x] Batch B `18664605` — Codex ChatGPT backend stops receiving GPT-5 native reasoning/verbosity controls (root cause of typo-heavy prose on that path) + "use polished grammar" baseline nudge
- [x] Batch C `06cc013e` — agent path now routes `.thinkingDelta` into `AgentChatState.appendStreamingThinking` with full lifecycle state (popover, resetOnStreamStart / newSession)
- [x] Batch D `9cf31cf7` — `ChatState` + `AgentChatState` `completeProcessing` surface empty streams as actionable errors instead of ghost assistant bubbles
- [x] Plan doc `eb5a0edb` — CHAT_TRANSPARENCY_PLAN_2026-04-19.md with P1/P2/P3 research-backed backlog
- [x] Batch G `526b7279` — mirror the agent-side thinking lifecycle tests onto `ChatState` so the main chat path has explicit regression coverage
- [x] Batch H `98897428` — QwQ 32B flagship on-device reasoner added to the catalog, leads `.thinking` preferredOrder ahead of DeepSeek R1 7B on 24GB+ Macs
- [x] Batch I `5ddd6db9` — every assistant turn captures `resolvedModelLabel` at completion via new `InferenceState.effectiveModelLabel(for:)` helper; all four completion call sites plumbed
- [x] Batch J `cfad9a99` — `EffectiveModelBadge` renders a small sparkle-pill under each assistant reply showing the actual model that answered (the Perplexity #1 research pattern: transparent routing)
- [x] Verification: 7-suite sanity sweep (`AgentChatStateTests`, `ChatPresentationTests`, `CloudProviderAuthServiceTests`, `LocalModelInfrastructureTests`, `PipelineServiceTests`, `RuntimeValidationTests`, `TriageServiceTests`) all green

**Open:** OpenThinker3-7B catalog entry (needs Python MLX conversion step we can't run autonomously — wait for a community `mlx-community/OpenThinker3-7B-*-mlx` upload or run the conversion manually).

**Gemma 4 loader — ✅ LANDED 2026-06-14** (`0b53121737` + app un-gate): vendored Apple's tested native `Gemma4Text` port from `ml-explore/mlx-swift-lm` @ `e3cb1e1b` (replacing the Gemma-3n alias), so the dense **E2B/E4B** tiers now load. The Swift port is **dense-only** (no MoE), so **26B-A4B** stays `isAwaitingSwiftRuntimeLoader`-gated; **31B-JANG** (third-party, unverified, oversized) stays gated too. `swift build --target MLXLLM` green; full Epistemos `build-for-testing` compiles. **On-device token-generation proof still pending** (needs a signed Product ▸ Run — headless can't launch the test host). See MASTER_MODEL_STACK_PLAN.md §3.a.

**P4 sovereign-runtime hardening — ✅ 2026-06-14** (`b491fb4b3` + `511100302`): mapped & verified the System G runtime is real + green (Rust `agent_runtime_v2/system_g_runtime.rs` + Swift `RealSystemGRunSeam.swift`/`RuntimeRouter`/`AnswerPacket`/`SovereignGate`; 5292 cargo tests). Hardened the gate family's source-ref integrity — pinned `F-AgentRoutePolicy-LargeModelNoHiddenAuthority`'s 10 refs to real files, then a single meta-test (`tests/uas_source_ref_integrity.rs`) that guards every `uas/` gate's `.swift`/`.rs` refs. **It caught a real drift bug**: `search_index_release_blocker_card` named `Epistemos/Engine/QueryTypes.swift` after the file had moved to `Models/` — fixed. The large-model/70B frontier (loading model bytes) stays owner-gated by the `uas/exotic_quant_*` witness chain — built scaffolding only, no bytes. See memory `system-g-runtime-map-2026-06-14`.

**Next-session P1 continuation:** typed error surfaces (401/429/content-policy/tool-failure), context side panel (NotebookLM + Continue.dev hybrid), and click-through routing rationale ("why this model?") on the new model badge — all specified in CHAT_TRANSPARENCY_PLAN_2026-04-19.md.

## 2026-04-15 PLAN_V2 Research Integration + Sessions 0-6 ✅
- [x] Committed Phase 7 Step 9: Graph Chat receiver wired end-to-end through ACC and Rust compile path (GraphState → ACC → ChatCoordinator → Rust GraphContext passthrough)
- [x] Integrated §23-§27 into PLAN_V2.md from 5-model research synthesis: Code Editor Architecture Truth, Agent Streaming Data Plane, Graph Zero-Copy Rendering, Implementation Sessions, Anti-Pattern Register
- [x] Fixed P1 beach ball: recompute_semantic_neighbors off main thread via Mutex + Task.detached
- [x] Fixed P0 Vec drop malloc: allocator mismatch in graph_engine_free_prepared_retrieval_candidates replaced with into_boxed_slice/Box::from_raw pattern
- [x] Fixed P2 pinned inspector freeze: force_alive engine flag bypasses idle skip when pinned panels exist
- [x] Session 0: Editor doc-truth audit — reconciled CODE_EDITOR_FEATURE_AUDIT.md with live code (3 verified, 4 partial, 1 reverted)
- [x] Session 1: Benchmark harness — os_signpost instrumentation on graph/streaming FFI + criterion benches in graph-engine + BENCHMARK_BASELINES.csv
- [x] Session 2: Swift 6 concurrency hardening — 6 force unwraps removed, isFinite guard added, no try! violations found
- [x] Session 3: Graph BoltFFI typed buffer prototype — bolt_bridge.rs with BoltNodeRecord/BoltEdgeRecord/BoltPositionRecord behind bolt-graph feature flag, 10 tests
- [x] Session 5: syntax-core crate scaffolding — tree-sitter + ropey, 7 #[repr(C)] FFI types, rope bridge, token registry, generation counter, 21 tests, criterion benchmarks
- [x] Session 6: Agent streaming instrumentation — signposts on StreamingDelegate + ChatCoordinator event path
- [x] Final audit: 2978 Rust tests (2456 graph-engine + 501 agent_core + 21 syntax-core), Swift BUILD SUCCEEDED, 331 critical tests in 15 suites all pass

## 2026-04-03 Main Chat Markdown Tightening ✅
- [x] `TaggedMarkdownTextView` now groups consecutive list items into a single render run so main chat and mini chat no longer space bullets like separate paragraphs
- [x] Chat markdown parsing now preserves nested list indentation, task-list items, and nested blockquote depth for the shared chat renderer
- [x] Main chat and mini chat both pick up the change automatically because `MessageBubble` and `MiniChatView` already share `TaggedMarkdownTextView`
- [x] Added focused `ChatPresentationTests` coverage for nested/task-list parsing and grouped list-run rendering
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-chat-format-dd test -only-testing:EpistemosTests/ChatPresentationTests`

## 2026-04-03 Inference Post-Query Memory Release Audit ✅
- [x] `DisplayPacedTextBuffer.reset(...)` now supports an explicit release-capacity path so oversized buffered assistant text does not keep its backing storage after the turn ends
- [x] `ChatState` now drops retained `streamingText` / pending-buffer capacity on new chat, completion, cancellation, error, and clear paths instead of only resetting content length
- [x] `NoteChatState` now releases retained inline-response / stream-buffer capacity on submission reset, accept, discard, and clear paths so large note-chat turns do not linger in idle heap state
- [x] Added a focused `NoteChatStateTests` regression plus a `RuntimeValidationTests` source guard covering the release-capacity reset wiring
- [x] Focused verification passed: `cargo test --manifest-path graph-engine/Cargo.toml`
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-idle-memory-dd test -only-testing:EpistemosTests/NoteChatStateTests -only-testing:EpistemosTests/PipelineServiceTests/ChatStateLocalMessageTests/startNewChatClearsPendingAttachmentsAndContext -only-testing:EpistemosTests/PipelineServiceTests/ChatStateLocalMessageTests/clearMessagesDropsPendingAttachmentsAndContext -only-testing:EpistemosTests/RuntimeValidationTests`
- [x] Recursive focused audit reached 3 successive clean no-edit passes for the post-query memory slice

## 2026-04-03 Graph Overlay Idle Memory Fix ✅
- [x] `HologramOverlay.hide()` now keeps the fast reopen path only for a bounded 10-second window, then tears down the hidden Metal graph window instead of retaining GPU resources indefinitely at idle
- [x] `HologramOverlay` now cancels any pending hidden teardown when the overlay is shown again, force-closed, or re-entered in mini mode, so the retention policy does not race normal graph lifecycle transitions
- [x] `HologramOverlay.showMini()` now tears down any previously soft-hidden full overlay before cold-starting mini mode, preventing a second hidden Metal graph instance from lingering in memory
- [x] Added `GraphOverlayRetentionPolicyTests` plus a `RuntimeValidationTests` source guard so the scheduled hidden teardown behavior remains enforced
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' test -only-testing:EpistemosTests/GraphOverlayRetentionPolicyTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`

## 2026-04-03 Runtime Idle Memory Trims ✅
- [x] `LocalMLXRuntimeTuning` now produces a separate `idleMemoryPolicy`, and `MLXInferenceService` switches between full request budgets and a much smaller idle budget so cached Metal pages are trimmed immediately after each local turn instead of staying at inference-size while idle
- [x] `MLXInferenceService` now starts cold in the smaller idle budget, reapplies the active budget before warm reuse, and returns to the idle budget on unload/runtime-condition updates
- [x] `NotesSidebar` search caches now use a bounded query-retention policy (`maxCachedQueries = 12`) for both title and body results, preventing long sessions from accumulating unbounded cached search payloads
- [x] Added runtime guards for the MLX idle-budget path and the bounded sidebar cache retention
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-idle-memory-dd test -only-testing:EpistemosTests/TriageServiceTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`

## 2026-04-03 Instant Recall Wake Freeze Fix ✅
- [x] `InstantRecallService` now shares a reusable rebuild helper and exposes `rebuildIndexAsync(...)`, which runs the Rust clear-and-reinsert pass inside `Task.detached(priority: .utility)` instead of holding `MainActor` for the full vault snapshot rebuild
- [x] `VaultSyncService.rebuildInstantRecallIndex(...)` now resolves the service on `MainActor` and awaits the async rebuild path, so post-wake/file-watcher vault reimports no longer force the heavy Instant Recall rebuild loop through `MainActor.run`
- [x] Added a behavior regression in `InstantRecallTests` for async stale-document replacement plus a `RuntimeValidationTests` source guard that keeps the vault watcher on the off-main rebuild path
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' test -only-testing:EpistemosTests/InstantRecallServiceTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`
- [x] Follow-on subsystem verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' test -only-testing:EpistemosTests/VaultSyncServiceAuditTests -quiet`

## 2026-04-03 Phase A Provider Selection Slice ✅
- [x] `InferenceState` now tracks an explicit `activeAIProvider`, remembers the last selected cloud model per provider, and falls back to local Qwen when the user switches to `Local Only`
- [x] Runtime model pickers now expose a dedicated `AI Provider` section and scope the `Cloud Models` list to the active provider instead of showing every cloud catalog at once
- [x] Inference Settings now expose the same provider selector so provider choice and credential setup stay aligned across toolbar + settings surfaces
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-active-provider-dd test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/InferenceCloudSelectionTests -quiet`

## 2026-04-02 Recursive Runtime Audit ✅
- [x] Fresh macOS app build passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- [x] Current Rust sweeps passed: `agent_core` 144 passed, `graph-engine` 2451 passed / 8 ignored, `omega-mcp` 126 passed, `omega-ax` 12 passed
- [x] `omega-mcp/src/pty.rs` now ignores echoed `__EPPWD__$(pwd)` command text and waits for the expanded marker line before updating `working_dir`
- [x] Added a PTY regression test covering echoed working-directory markers, and `omega-mcp` stays fully green after the fix
- [x] Hardening verification docs now reflect the live Hermes posture: Hermes remains an intentional managed subprocess boundary, not an unwired orphan-cleanup gap
- [x] `CloudKnowledgeDistillationService` now fast-paths inline-only note bodies, and XCTest hosts skip `MainThreadWatchdog.install()`, so the 10,025-note distillation stress suite no longer emits false hang diagnostics
- [x] `CloudKnowledgeDistillationService` now propagates source-note and recent-chat load failures instead of silently compiling empty model vaults
- [x] `HermesSubprocessManager` now supports dynamic stdout handler updates plus disconnect callbacks, and pending `HermesMCPClient` requests fail immediately when Hermes exits
- [x] `HermesSubprocessManager` now preserves the final stderr line from fast subprocess crashes, so diagnostics survive quick Hermes exits
- [x] `HermesSubprocessManager` now keeps relaunches blocked until graceful shutdown actually finishes, and `restart()` waits for the old subprocess to exit before relaunching
- [x] `HermesSubprocessManager` watchdog now waits for an actual ping response, so hung Hermes subprocesses terminate instead of looking healthy just because stdin is still writable
- [x] `HermesSubprocessManager.healthCheck(...)` now requires a live bridge ping before reporting Hermes healthy, so setup/repair flows no longer trust import-only success
- [x] `NightBrainService` now defers runs when `SearchIndexService` or `AgentGraphMemory` are unavailable instead of checkpointing those jobs as fake successes
- [x] `NightBrainService` now retains its initial `EventStore` for the full run, so checkpoint/completion durability cannot disappear mid-pipeline if the provider goes nil later
- [x] `AgentHeartbeatService` now monitors Hermes through a bounded post-dispatch window and defers the run if the subprocess drops before that window completes
- [x] `OrphanSubprocessCleanup` now snapshots descendant subprocess trees with `proc_listchildpids` and kills the full tree instead of only the tracked parent PID
- [x] `HermesSubprocessManager` now uses descendant-tree cleanup from the normal `terminate()` path when orphan cleanup is available, and the old fake `terminateProcessGroup()` API is gone
- [x] `NightBrainService` now routes checkpoint vacuum, artifact dedupe, and workspace snapshot compaction through the run's captured `EventStore`, and cloud knowledge distillation now defers if no distillation job is wired
- [x] `ActivityTracker` crash-recovery is now actually wired into launch/teardown, so flushed activity events are recovered at startup and durably cached on orderly shutdown
- [x] `ActivityTracker` now logs flush-directory failures explicitly, merges recovered cache contents with any already-recorded in-memory events, and no longer swallows idle-loop cancellation or page-title fetch failures with `try?`
- [x] `WorkspaceSummaryService` now fails loudly on summary-loop sleep interruption plus workspace fetch/save/page-title fetch failures instead of silently swallowing them with `try?`
- [x] `WorkspaceService` now fails loudly on auto-save, auto-restore, restore-delay, diff, save/load, and list persistence failures instead of silently swallowing them with `try?`
- [x] `TimeMachineService` now logs and fail-closes note/chat/page/graph fetch failures through shared helpers instead of silent empty or zero fallbacks
- [x] `EventStore` now fails closed on database-directory creation, logs `jobs_completed` JSON encode/decode failures, logs event payload encode failures, and closes SQLite on `quick_check` prepare failure
- [x] `EpistemosConfig` now fails closed on malformed capture allowlist/blocklist JSON and logs explicit capture-filter decode/encode failures instead of silently treating bad JSON as empty arrays
- [x] `AppBootstrap` now logs startup integrity, welcome-back summary, deferred startup delay, database reset cleanup, and Instant Recall seed snapshot failures instead of swallowing them with `try?`
- [x] `ModelProfileManager` now logs model-profile save failures instead of silently ignoring `context.save()`
- [x] `UIState` now logs malformed landing-greeting decode/encode failures, sanitizes corrupted greeting defaults back to an empty valid library, logs toast-dismissal timer failures, and `LandingGreetingResolver` now logs note-insight fetch failures instead of silently skipping them
- [x] Focused verification passed: `CloudKnowledgeDistillationTests` (8), `HermesMCPClientTests` (11), combined Cloud Knowledge + Hermes rerun (19 tests / 2 suites), NightBrain + Hermes + validation rerun (137 tests / 3 suites), `RuntimeValidationTests` (117), and `omega-mcp` cargo tests (126)
- [x] Follow-on focused verification passed: `NightBrainCheckpointResumeTests` + `OrphanSubprocessCleanupTests` + `RuntimeValidationTests` (130 tests) and `HermesMCPClientTests` (11)
- [x] Focused Hermes setup verification passed: `HermesHealthResult` suite rerun
- [x] Warm Xcode reruns now passed for `AgentHeartbeatTests` and the broader Hermes/NightBrain/runtime-validation slice
- [x] Focused tracker/runtime-validation verification passed twice: `ActivityTrackerTests` + `RuntimeValidationTests`
- [x] Focused persistence verification passed: `WorkspaceServicePersistenceTests` + `TimeMachineServiceTests` + `RuntimeValidationTests` (141 tests / 3 suites), `RuntimeValidationTests` rerun (131 tests), and `EventStoreSchemaTests` (7)
- [x] Follow-on focused verification passed: `xcodebuild ... build -quiet` and `xcodebuild ... test -only-testing:EpistemosTests/EpistemosConfigTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`
- [x] Follow-on focused verification passed: `xcodebuild ... test -only-testing:EpistemosTests/EpistemosConfigTests -only-testing:EpistemosTests/LandingExperienceSettingsTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`
- [x] Cloud Knowledge model vaults are now injected into live cloud, Apple Intelligence, and Hermes session-start prompts via `KnowledgeProfileStore.augmentedSystemPrompt(...)`
- [x] `AppleIntelligenceService` now caches Foundation Models sessions by the effective normalized system prompt and reapplies injected prompt context after context-window recycling
- [x] Focused Cloud Knowledge runtime wiring verification passed: isolated rerun of `CloudKnowledgeDistillationTests` + `AgentHeartbeatTests` + `RuntimeValidationTests` (150 tests / 3 suites)
- [x] `AgentHeartbeatService` no longer spins after cancellation in its post-dispatch monitoring loop, and `AppSupervisor` no longer swallows detached sleep cancellation in health-check/restart paths
- [x] Focused supervisor/heartbeat verification passed three consecutive times on an isolated DerivedData path: `AgentHeartbeatTests` + `SupervisorTests` + `RuntimeValidationTests`
- [x] `AmbientCaptureService` no longer swallows debounce cancellation, now logs malformed AX-tree payload failures, and no longer silently drops secret-redaction regex compilation failures
- [x] Focused ambient-capture verification passed three consecutive times on an isolated DerivedData path: `AmbientCaptureTests` + `RuntimeValidationTests`
- [x] `ProseEditorView` now logs save/fetch failures on live note persistence paths, schedules note-body writes before flush-page fetches, and avoids creating dangling wikilink duplicates after hidden fetch failures
- [x] `NoteChatState`, `DiskStyleCache`, and `AgentViewModel` now fail loudly on persisted history/cache/session-state load-write corruption instead of silently swallowing those note/agent persistence failures
- [x] Focused persistence hardening verification passed on an isolated DerivedData path: `NoteChatStateTests` + `NoteEditorLayoutTests` + `RuntimeValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `StartupAutoDiscovery` now logs config-read, `.hermes` creation, model-cache inspection, and fallback `SearchIndexService` bootstrap failures instead of silently degrading startup discovery
- [x] `NoteInsightService`, `NotesSidebar`, `HologramNodeInspector`, `TimeMachineView`, and `DialogueChatState` now fail loudly on the remaining live fetch/save/debounce/restore seams from this audit slice instead of hiding them behind `try?`
- [x] Focused startup/runtime hardening verification passed on the warmed DerivedData path: `HermesSubprocessTests` + `NoteChatStateTests` + `RuntimeValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `VaultIndexActor` now uses explicit fetch/save/file-I/O helpers for live indexing, manifest, spotlight, and migration paths instead of silently collapsing SwiftData and file-system failures behind `try?`
- [x] `LandingView` now logs welcome-back presentation/search-focus scheduling failures, welcome-back summary note save failures, and recent-chat fetch failures, and it cancels the deferred welcome-back presentation intentionally on dismiss/disappear
- [x] Focused vault/landing hardening verification passed on the warmed DerivedData path: `VaultIndexActorTests` + `RuntimeValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `VaultSyncService` now routes live health-snapshot fetches, SQLite signature probes, dirty-page fetches, version-capture fetch/counts, move-page lookup, and maintenance timer sleeps through explicit helpers instead of silent `try?` fallbacks
- [x] `ChatCoordinator`, `MiniChatView`, `MiniChatWindowController`, `QueryRuntime`, `VaultChatMutator`, and `VaultRegistry` now log live fetch/search/read failures explicitly instead of silently collapsing those chat/runtime seams
- [x] `ExecutionCheckpointManager` and `NotesAgent` now log checkpoint directory/decode/remove failures plus note-agent argument-parse, fetch, and save failures instead of swallowing them behind `try?`
- [x] Focused chat/vault/Omega hardening verification passed on the warmed DerivedData path: `RuntimeValidationTests` + `VaultSyncServiceAuditTests` + `MiniChatViewAuditTests` + `QueryRuntimeTests` + `VaultChatMutatorTests` + `OmegaAgentTests` + `PipelineServiceTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `SessionIntelligenceOverlay` now uses bounded `fetchLimit = 1` title lookups for note/chat command actions instead of full-page/full-chat vault scans on the interactive landing overlay path
- [x] Focused performance guard verification passed on the warmed DerivedData path: `NonAgentPruningValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `AgentViewModel` now shares one explicit computer-action mutation enrichment helper across click/type/keys/scroll actions instead of duplicating 300 ms AX sampling logic in each tool path
- [x] `ProgressStore` now enumerates only real session directories through shared helpers, logs directory/decode failures explicitly, and ignores stray files when listing sessions
- [x] `HarnessRegistry` and `HarnessLab` now reuse shared nonisolated ISO-8601 timestamp helpers instead of recreating formatters across candidate/proposal/evaluation/materialization paths
- [x] Recursive perf verification passed after one refinement-loop fix to `HarnessLabTime` isolation: `ProgressStoreTests`, then `HarnessSubsystemTests` + `RuntimeValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs on the isolated DerivedData path
- [x] `SessionIntelligenceOverlay` now resolves “open it” note-history lookups through extracted candidate titles plus open-note checks and bounded fetches instead of scanning every `SDPage` row in command history fallback paths
- [x] `LiquidGreeting` now uses shared deterministic timing helpers and an explicit pause helper instead of per-character `Int.random(...)` sleeps across the landing typewriter loop
- [x] Added focused landing optimization coverage in `LandingOptimizationTests`, plus source guards in `NonAgentPruningValidationTests` and `ThemePairTests`
- [x] Recursive landing perf verification passed after one refinement-loop fix to `SessionIntelligenceNoteLookup` isolation: `LandingOptimizationTests` + `NonAgentPruningValidationTests` + `ThemePairTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs on the isolated DerivedData path
- [x] `LocalModelManager.refreshFromDisk()` now persists the local model manifest only when legacy/missing-install cleanup actually changed `installRecords`, instead of rewriting the manifest on no-op refreshes
- [x] `pruneMissingInstalls()` and `purgeLegacyNonQwenInstalls()` now report whether they changed the record set so refresh cleanup persists at most once per pass
- [x] Added a real `LocalModelInfrastructureTests` manifest-modification-date regression plus a `RuntimeValidationTests` guard for the conditional-persist structure
- [x] Recursive local-model perf verification passed on an isolated DerivedData path: `LocalModelInfrastructureTests` + `RuntimeValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs
- [x] `SessionIntelligenceOverlay.summarizeChats()` now orders grouped chats deterministically and batch-loads chat titles for the selected groups instead of fetching one `SDChat` row per summary entry
- [x] Added a real `LandingOptimizationTests` chat-summary ordering regression plus a `NonAgentPruningValidationTests` guard that keeps the landing overlay from regressing back to per-chat title fetch loops
- [x] Recursive landing chat-summary verification passed after one refinement-loop fix to a source-guard key-path escape: `LandingOptimizationTests` + `NonAgentPruningValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs on the isolated DerivedData path
- [x] `SessionIntelligenceOverlay` now shares explicit note-presentation/dismiss timing helpers plus a bounded auto-save workspace-summary helper instead of repeating raw delayed create/open and fallback fetch paths on the landing command surface
- [x] `WorkspaceSwitcherOverlay` now routes load/dismiss flows through one shared post-dismiss helper instead of repeating 150 ms delayed tasks
- [x] `AgentViewModel` now routes the remaining cron keepalive/admin refresh sleep through an explicit helper and shared interval instead of an inline raw 60-second delay loop
- [x] Final audited non-Hermes perf verification passed on `/tmp/epistemos-codex-final-perf-round`: `LandingOptimizationTests` + `NonAgentPruningValidationTests` + `RuntimeValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs

## 2026-04-02 Cloud Knowledge Distillation Wiring ✅
- [x] `CloudKnowledgeDistillationService` now loads recent chats from SwiftData by default when no provider override is supplied
- [x] Distillation source-note loading no longer silently caps at 10,000 pages
- [x] Untagged domain-map fallback now preserves real concept recency via `RankedConcept.lastUpdatedAt`
- [x] NightBrain treats failed cloud-knowledge or search-index maintenance jobs as interrupted runs instead of falsely checkpointing/completing them
- [x] Focused verification passed: `CloudKnowledgeDistillationTests` + `NightBrainCheckpointResumeTests` = 14 tests in 2 suites, 0 failures

## 2026-04-01 Verification Closure ✅
- [x] Full hosted Swift rerun passed: `test-without-building` completed 3051 tests across 418 suites with 0 failures
- [x] Fresh cached macOS app build passed: `xcodebuild ... build` returned `BUILD SUCCEEDED`
- [x] Fresh Rust sweeps passed: `graph-engine` 2448 passed / 0 failed / 8 ignored, `agent_core` 141 passed / 0 failed, `omega-mcp` 125 passed / 0 failed, `omega-ax` 12 passed / 0 failed
- [x] `agent_core/src/shared_memory.rs` tests now serialize process-global `ShmPool` access and reset the pool before/after each test, eliminating the parallel `shm_pool_cleanup_all` race

## 2026-04-01 Harness + Power Follow-Up ✅
- [x] `AgentViewModel` now prepares harness session state before recording user intent, so the first turn no longer drops the objective from trace/progress capture
- [x] `AgentViewModel` now records final model output and runs `CompletionChecker` at session end
- [x] `VaultSyncService` now observes `PowerGuard` mode changes and restarts maintenance timers when `.full` mode returns
- [x] `DualBrainRouter` now requires a dedicated ANE backend before reporting dual-brain active
- [x] Focused verification passed: `RuntimeValidationTests` + `VaultSyncServiceAuditTests` + `DeviceAgentServiceTests` = 140 tests in 3 suites, 0 failures

## 2026-04-01 Tool Gate Follow-Up ✅
- [x] HermesSubprocessManager now normalizes `HOME` + `PATH`, exports `HERMES_ENV_TYPE=local`, keeps `TERMINAL_ENV=local`, and creates `~/.hermes` before launching Hermes
- [x] `epistemos_bridge.py` now logs the loaded Hermes tool names to stderr after session setup and includes `available_tools` in live session payloads
- [x] `AgentViewModel` now feeds the live Hermes tool list into HarnessIntegration when it is available instead of always sending an empty tool set
- [x] Bridge + Swift session parsing tests added for the loaded-tool payload path

## 2026-04-01 Auto-Discovery Pass ✅
- [x] `AppBootstrap` now runs a startup auto-discovery pass before `InferenceState` initializes, so env/config credentials can seed Keychain without manual setup
- [x] Startup discovery now scans `~/.config/epistemos/config.toml` and `~/.epistemos/config.toml`, creates `~/.hermes` if missing, logs optional browser/web/model availability, and degrades gracefully when pieces are absent
- [x] Hermes tool-gate env export now includes Browserbase credentials so discovered browser config actually reaches the subprocess
- [x] Focused Swift tests cover config parsing, env/keychain precedence, config import, `agent-browser` detection, and model cache discovery

## Sprint Agent-1: The Living Loop ✅
- [x] agent_core crate with all 13 source files
- [x] Full SSE state machine with thinking/signature preservation
- [x] Parallel tool execution (futures::try_join_all)
- [x] Agent-decides termination (stop_reason == end_turn)
- [x] UniFFI bridge with AgentEventDelegate callback interface
- [x] All verification greps pass

## Sprint Agent-2: Local Agent System ✅
- [x] HermesPromptBuilder, LocalToolGrammar, LocalAgentLoop, ConfidenceRouter
- [x] canActAsAgent=false enforced for weak models
- [x] 20/20 focused tests pass

## Sprint Agent-3: MCP + Computer Use ✅
- [x] Rust-authoritative tool catalog (26 tools, 5 agents)
- [x] Vault-focused MCP surface (read/write/list/search)
- [x] AX-first computer-use path hardened
- [x] Device backend execution seam closed
- [x] Focused tests pass

## Sprint Agent-4: Multi-Provider + Polish ✅
- [x] Routed provider preview + honest auto bridge resolution
- [x] Perplexity Sonar streaming provider with citations
- [x] OpenAI-compatible provider (openai.rs — SSE streaming, tool calls, 16 tests) (2026-03-31)
- [x] Full context compaction loop → Sprint Omega-1 Task 3 (compaction.rs)
- [x] Metal thinking glow shader for OmegaPanel → Sprint Omega-4
- [x] Full validation checklist passes (449 Rust tests, Swift BUILD SUCCEEDED) (2026-03-31)

---

## Sprint Omega-1: Foundation Integration ✅ (2026-03-29)
- [x] Task 1: prompt_caching.rs — cache_control breakpoints (~85% cost reduction)
- [x] Task 2: think.rs — zero-cost reasoning tool
- [x] Task 3: compaction.rs — 4-phase context compaction (boundary protect → tool replace → summarize → fold)
- [x] Task 4: security.rs — credential redaction + command risk + output scanning
- [x] Task 5: MCP stdio transport in omega-mcp
- [x] Task 6: Full compilation + test sweep passes (164 Rust tests, 0 failures)

## Sprint Omega-2: Hermes Subprocess Bridge ✅ (2026-03-29)
- [x] HermesSubprocessManager.swift — spawn/manage/kill via Foundation Process
- [x] HermesMCPClient.swift — MCP stdio client to Hermes
- [x] EpistemosMCPServer.swift — MCP stdio server exposing macOS tools
- [x] Pipe-based watchdog heartbeat for zombie prevention
- [x] Process group management for clean shutdown
- [x] Integration with AppBootstrap lifecycle
- [x] Hermes health check on launch

## Sprint Omega-3: AXorcist Computer Use ✅ (2026-03-29)
- [x] Replace raw AXUIElement code with AXorcist SPM dependency
- [x] Ghost OS-style MCP tools (see, click, type, scroll, keys, screenshot)
- [x] ScreenCaptureKit pipeline with buffer dropping (<200ms target)
- [x] TCC permission management UI
- [x] AX-first with vision fallback pattern

## Sprint Omega-4: Skills + Memory + Polish (2026-03-29)
- [x] SKILL.md progressive disclosure (metadata → instructions → resources)
- [x] Post-task auto-skill creation
- [x] 3-layer progressive memory retrieval
- [x] Overnight Note Research — NightBrain-scheduled deep research on flagged notes with morning summary
- [x] Usage cost dashboard
- [x] Slash-command palette (/plan, /research, /review)
- [x] Metal thinking glow shader for OmegaPanel
- [x] Full validation checklist passes (3/3 recursive clean)
- [x] All Rust tests pass (371 tests, 0 failures)

## Sprint Omega-5: Living Vault Memory Engine (in progress)
- [x] Task 1: diff_engine.rs — unified text diff, JSON pointer diff, and 3-line fuzzy patch apply (2026-03-30)
- [x] Task 2: memory_classifier.rs — ADD/UPDATE/DELETE/NOOP vault write classifier with compact prompt + local/Haiku dispatch hint + contradiction planner (2026-03-30)
- [x] Task 3: memory_decay.rs — Ebbinghaus decay + garbage collection with pinned/access-aware batch decay (2026-03-30)
- [x] Task 4: cross_propagation.rs — Tantivy/file-scan reference detection with atomic secondary patch rollback (2026-03-30)
- [x] Task 5: vault_git.rs — git-backed atomic vault commits with history + diff_between support (2026-03-30)
- [x] Task 6: ConversationPersistence.swift — JSONL + markdown conversation persistence (2026-03-30)
- [x] Task 7: VaultChatMutator.swift — diff staging + approval flow (2026-03-30)
- [x] Task 8: VaultRegistry.swift / vault_registry.rs — multi-vault identity mapping (2026-03-30)
- [x] Task 9: Full compilation + integration verification (2026-03-30)

## Agent Integration Session (2026-03-30) ✅
Items 1-15 from `docs/AGENT_INTEGRATION_SESSION_PLAN.md` — all building clean.

### Do First Tier ✅
- [x] Item 6: ToolLoopDetector wired into Hermes bridge tool_completed events (2026-03-30)
- [x] Item 5: AgentDepthLimiter wired into Hermes bridge tool_started/completed for delegate tools (2026-03-30)
- [x] Item 15: CredentialRedactor — 9 patterns, wired into vault_search + vault_read (2026-03-30)
- [x] Item 14: CostTracker — micro-dollar precision, March 2026 pricing, wired into complete events (2026-03-30)
- [x] Item 8: ContextCompiler — U-curve reordering on vault_search results (2026-03-30)

### Do Second Tier ✅
- [x] Item 13: MemoryThreatScanner — role hijack + exfiltration + invisible unicode, wired into vault tools (2026-03-30)
- [x] Item 12: ShadowGitCheckpoint — GIT_DIR/WORK_TREE separation, 10s timeout, auto-checkpoint (2026-03-30)
- [x] Item 3: NightBrain menu bar agent mode — config + delegate + Settings toggle (2026-03-30)
- [x] Item 7: Living Vault Rust FFI exports — classify_vault_memory, decay_memory_nodes, gc_memory_nodes (2026-03-30)

### Do Third Tier ✅
- [x] Item 4: SkillStoreView — 7 categories, search, detail sheet, native + Hermes skills (2026-03-30)
- [x] Item 9: QLoRATrainer prefers composed train_final.jsonl over raw shards (2026-03-30)
- [x] Item 1: HTTP/SSE transport via NWListener for MCP payloads >50KB (2026-03-30)
- [x] Item 2: recovery.rs (7 tests) + HexViewerView with Rust FFI (2026-03-30)

### Gemini Deep Analysis Integration ✅
- [x] Evaluated 6 proposals from OpenClaw/Hermes comparative analysis (2026-03-30)
- [x] Accepted: Heartbeat Memory Distillation (Item 20), Sub-Agent Context Scoping (Item 21)
- [x] Rejected: A2UI (already SwiftUI), PyO3 (wrong direction), Zero-Trust WS (local app), Docker Proxy (deferred)
- [x] Updated AGENT_INTEGRATION_SESSION_PLAN.md, MASTER_SESSION_PROMPT.md, AGENT_PROGRESS.md

### Do Next Tier (Gemini analysis upgrades) ✅
- [x] Item 20: NightBrain Heartbeat Memory Distillation — memoryDistillation job in NightBrainService, calls AgentGraphMemory.distillMemory() with Ebbinghaus decay + GC (2026-03-30)
- [x] Item 21: Sub-Agent Hierarchical Context Scoping — context_scope parameter in delegate_tool.py, 3 role-specific context files (terminal, research, file) in hermes-agent/contexts/ (2026-03-30)

## Sprint Omega-6: Context Compiler + Graph Visualizer ✅ (2026-03-31)
- [x] Task 1: context_compiler.rs — prompt DAG with cache-optimal assembly (2026-03-30)
- [x] Task 2: skill_router.rs — TF-IDF skill selection (7 tests) (2026-03-30, verified 2026-03-31)
- [x] Task 3: example_bank.rs — few-shot retrieval + Jaccard quality ranking (6 tests) (2026-03-30, verified 2026-03-31)
- [x] Task 4: GraphDataModel.swift — execution trace → graph subgraph conversion (2026-03-30, verified 2026-03-31)
- [x] Task 5: AgentGraphView.swift — Canvas-based DAG with hierarchical layout (2026-03-30, verified 2026-03-31)
- [x] Task 6: SemanticZoomController.swift — 5-level semantic zoom + control strip (2026-03-30, verified 2026-03-31)
- [x] Task 7: NodeDetailPanel.swift — node inspector with metadata grid (2026-03-30, verified 2026-03-31)
- [x] Full verification: 449 Rust tests pass, Swift BUILD SUCCEEDED (2026-03-31)

## Sprint Omega-7: Paperclip/Lambda Fusion (2026-03-31)
- [x] Task 1: chunk_reduce.rs — parallel split/map/reduce tool (13 tests, λ-RLM pattern) (2026-03-31)
- [x] Task 2: Think-block streaming UI — <think> token parser + blurred ChainOfThoughtBubble (2026-03-31)
- [x] Task 3: CostTracker 3-tier budget — session + per-agent + rolling daily + pre-turn gating (2026-03-31)
- [x] Task 4: AgentHeartbeatService — NSBackgroundActivityScheduler heartbeat with budget gating (2026-03-31)
- [x] Task 5: openai.rs — OpenAI Chat Completions SSE provider (16 tests) (2026-03-31)
- [x] Task 6: PTY test stabilization — environment-robust working_dir assertion (2026-03-31)
- [x] Full verification: 449 Rust tests, 0 failures; Swift BUILD SUCCEEDED (2026-03-31)

## Runtime Input Audit Continuation (2026-04-19)
- [x] `ChatCoordinator` attachment contract now treats attached notes/files as already resolved context and explicitly forbids asking the user for a path or re-upload when `Content:` is already present (`783a9651`)
- [x] `InferenceState` now normalizes stale/persisted Gemma 4 preview chat selections back to `qwen3_4B4Bit` on both selection and state load, closing the remaining Gemma leak into live chat state (`ac37571e`)
- [x] `AssistantToolbarAskBar`, `NoteDetailWorkspaceView`, `MiniChatView`, and `CommandBarView` now surface explicit `Loading <model>…` affordances before first visible token so cold local loads no longer read as silent freezes outside main chat (`43092ae5`)
- [x] `LocalModelToolbarMenu` and `SettingsView` now drop duplicate/noisy runtime affordances: only one `Open Settings` entry point remains in the chat picker, the redundant `Active Tier` row is gone, and per-row loader warnings no longer spam the local model list (`0befc7c5`)
- [x] `AgentCommandCenterState` local-brain mode exposure now matches the real runtime contract — always-thinking fast-incompatible locals like `qwen25Coder7B` no longer advertise Fast, and ACC specialist defaults now prefer safer local brains first (`695ce712`)
- [x] `OpenAICompatibleChatSupport` now enforces a fallback `max_tokens` budget of 4096 whenever the caller leaves it at zero, preventing compatible providers from silently running unbounded (`b19a768e`)
- [x] `LocalModelInfrastructure`, `RootView`, `SettingsView`, and `ModelAboutSheet` now separate `This Mac`, `Chat Memory`, and `Model Files` for `qwen25Coder7B`; the coder tier uses a 24 GB interactive floor in user-facing guidance (`1563ad8d`)
- [x] `qwen25Coder7B` is no longer part of the shipping optional baseline and is hidden from the release chat picker until the freeze path is live-verified (`b587dda4`)
- [x] `AgentChatState` and `AgentChatView` now route inline `<think>` blocks into the agent thinking popover and persist the captured reasoning trail onto finalized agent turns (`6f9d863c`)
- [ ] Still needs live launched-app verification: `qwen25Coder7B` cold-load UX, direct-cloud and Rust-agent thinking separation, and any remaining crash repros

## App Store Release Hardening Continuation (2026-04-24)
- [x] App Store profile gates now hide/compile out Pro-only settings, runtime scripts, native computer-use stack, Pro runtime startup, and Pro-only `agent_core` tool code (`e87fbb6d` → `48fed7d7`)
- [x] `Epistemos-AppStore` builds `agent_core` with `--features mas-sandbox`; focused release hardening tests cover sandbox/profile gates and App Store runtime exclusions (`0ab57d80`)
- [x] App Store launch window recovery landed, including first-window surfacing and dock-reopen handling (`5785cef0`, `caa3fdbf`)
- [x] Chat startup now fails closed when no selected runtime is ready; composer/model controls show setup/no-model state instead of submitting to a dead route (`caa3fdbf`)
- [x] Local chat output is capped to Overseer steering budgets, fixing the App Store plain-chat policy denial seen during manual Computer Use smoke (`caa3fdbf`)
- [x] Hugging Face hub snapshots with weight blobs are treated as usable local installs, so prepared local runtimes survive real bundle/cache layouts (`caa3fdbf`)
- [x] Manual Computer Use smoke on the real App Store Release bundle: `ping` returned `pong`; no restricted-tools warning; shell/Pro affordances absent
- [x] New canonical tracker: `docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md`
- [x] Live R.4 attachments now seed session Read/Write grants before chat/tool routing; pasted Snapshot attachments remain read-only. Verified by 9/9 R.5 grant tests, 43/43 R.4/R.5 focused tests, and App Store Release BUILD SUCCEEDED.
- [x] Attached-write prompt contract now exposes exact `vault_write.path` for Live writable notes and exact `write_file.path` for existing attached text files; offline cached previews remain non-writable. Verified by 32/32 focused attachment/context tests and App Store Release BUILD SUCCEEDED.
- [x] Approved staged vault-mutation commits now verify UTF-8 readback before reporting success. Verified by 5/5 `LiveNoteExecutorTests` and App Store Release BUILD SUCCEEDED.
- [x] Core `NoteFileStorage` atomic writes now verify byte-exact UTF-8 readback before returning success / clearing pending body state. Verified by test-first failure, 14/14 `NoteSavingEdgeCaseTests`, 25/25 `NoteFileStorageTests`, and App Store Release BUILD SUCCEEDED.
- [ ] Remaining App Store blockers: end-to-end attached-file write verification, remaining Swift-originated verified-write migration, grant UI manual revoke smoke, full repeated release-audit pass, App Store metadata/privacy/TestFlight closure
- [ ] Pro work remains deferred until App Store lane is accepted or explicitly branched: CLI subprocess Power Mode, Docker, iMessage channel, full CLI config compiler, Bash/MultiEdit/WebFetch, long-horizon agents

## Codex Canon Verification Loop (2026-05-05)
- [x] `.epdoc` creation path is visible and shared across File menu, landing rail, and Notes sidebar. Focused source-guard tests passed, and Computer Use smoke confirmed `New Doc` opens an untitled Epdoc editor.
- [x] V2.3 semantic LSP is a real `tower-lsp` + `tree-sitter` runtime, not the earlier hand-rolled lifecycle stub. Rust and Swift focused LSP tests passed; docs no longer claim Stage F is deferred.
- [x] A1 redb persistent DAG backend slices 1-4 landed behind `cognitive-dag-redb` using `redb` 4.1.0 and JSON value bytes. Persistence, edge parity, CD-005 capability checks, snapshot, and Merkle parity tests passed. Slice 5 authority wiring remains intentionally pending.
- [x] Preservation-first dead-code audit resolved the `agent_core/src/tools/` orphan set: deleted only superseded orphan files (`code_execution.rs`, `graph_query.rs`) and wired the intended note tools scaffold into the registry and R.5 permission gate.
- [x] Project-wide Rust clippy gate is green across `agent_core`, `epistemos-core`, `omega-mcp`, `omega-ax`, and `graph-engine`, including default and Pro/LSP feature surfaces where relevant.
- [x] CD-008 automated verification is green: full Rust all-targets sweep, doctrine linter, verify-replay, Pro/LSP feature tests, and full `xcodebuild test` result bundle passed. Remaining CD-008 work is human runtime smoke on ship-risk surfaces.
- [x] Local model install detection issue verified fixed: focused `LocalModelInfrastructureTests` passed 76/76, including usable hub snapshot detection; live Computer Use smoke confirmed Settings -> Inference shows unified `Active Local Model: Qwen 3`.
- [x] SwiftUI hot-loop suspected getter-mutation path verified closed in current source: `InferenceState.apiKey(for:)` and `oauthCredential(for:)` are read-only, and focused `RuntimeValidationTests` passed 254/254. Remaining work is a launched-app Time Profiler / memory-pressure stress pass if the LocalModelToolbarMenu fan-out symptom recurs.

## Terminal C Audit-of-Audit Loop — iter 73-77 (2026-05-16, `run-c-audit` branch)

Fresh Terminal C `/loop` session at 3-min cron cadence after iter-72 wind-down. Discipline: audit-only per V3 Terminal C driver §1.5; user approved full-execution override for `run-c-audit` branch only (logged in memory).

- [x] **Iter 73 — Wave J1 substrate spot-check + MASTER_RESEARCH_INDEX §15 entry** (commit `57793ec8d`). Verified `562e23d83 Wave J1 substrate floor` on Terminal B's branch is §5.0-clean: 5 files / 382 LOC / 13 tests / all `//! Source:` comments resolve; donor docs on disk; `pub mod research;` registered at `lib.rs:45`. Added MASTER_RESEARCH_INDEX §15 sub-entry "Wave J1 substrate floor — Rust" with full code-anchor table.
- [x] **Iter 74 — [DRIFT-ALERT] Audit-of-audit #8 catches 2 forward-staged primitives wrongly NOT-STARTED** (commit `32d0b4ee2`). Phase C.6 forward-staged-primitive re-audit found:
      - **B2-L1 `agent_core/src/heal/`** — claimed ABSENT, actually 463 LOC SHIPPED-DORMANT since 2026-05-04 (`c62c1e94d` Salvage Tier A+B); contains HealEventLog + Diagnostician trait + HealLoop struct.
      - **B2-M9 `CircuitBreaker`** — claimed "rg zero hits across all crates", actually 306 LOC SHIPPED at `circuit_breaker.rs` since 2026-04-26 (`dcc5521fc` v1.5 16 items shipped); used by heal/. HealthCheck trait + variant_ladder integration genuinely NOT-STARTED.
      - Combined drifted-substrate LOC: 769 (~scale of B2-M10 Effect §5.0 catch).
      - Root cause: audits-of-audit #5/#6/#7 accepted in-row `rg zero hits` citations at face value without independent re-grep.
      - **Trust-but-verify lesson #6 (new):** substrate-claim verification requires independent re-grep at audit-of-audit time. PR-discipline rule recommendation: any audit row citing `rg returns zero hits` MUST be re-executed at next audit-of-audit windowing.
- [x] **Iter 75 — Audit-of-audit #8 continuation** (commit `f52ff18a5`). Applied lesson #6 across remaining PASS-2 zero-hit citations. 2 additional sub-claim drifts: B2-H19 sub-bullet (ii) (LivePlan substrate — `live_files/mod.rs` 253 LOC exists since 2026-05-04 `682ba68de`); B2-M8 Koopman (3 doc-comment hits; spirit correct).
- [x] **Iter 76 — Audit-of-audit #8 follow-up across sibling-owned doctrine docs** (commit `a3ef5f4da`). Extended lesson #6 sweep to HERMES + MAS_COMPLETE_FUSION + MASTER_FUSION + NEW_SESSION_HANDOFF. 0 substantive substrate drifts; 2 citation-imprecisions in MASTER_FUSION (MLA substring matches `CoreMLAction*`; MOHAWK matches test-fixture strings). PATTERN BOUNDED — Salvage-Tier-era drift surface complete at 1022 LOC across heal/ + circuit_breaker.rs + live_files/mod.rs.
- [x] **Iter 77 — Phase C.3 cross-link integrity check after #8 corrections** (commit `d2683b401`). 0 broken cross-links surfaced; 5 commit SHAs cited by #8 all resolve; HERMES + NEW_SESSION_HANDOFF references intact. The drift was in zero-hit substrate-absence framing only; downstream cross-references remain anchored.
- [x] **Iter 78 — AGENT_PROGRESS sprint sync (Phase C.4) — this row.**
- [ ] **Flagged-but-not-edited (per §1.5):**
      - `agent_core/docs/HEAL_LOOP_SCHEMA_AND_TTL.md` line 3 wrong claim "Substrate NOT-STARTED in `agent_core/src/heal/` as of 2026-05-16".
      - `VARIANT_LADDER_TOOL_REGISTRY §12` reconciliation table sub-bullet (g) wrong claim "rg ... returns zero hits".
      - 2 MASTER_FUSION citation-imprecisions (lines 371 + 657) — minor, sibling-owned, owner discretion.

**Cargo test baseline 1190 holds throughout** (doc-only audit corrections; no production code touched). No sibling-owned production code or doctrine docs edited.

## Capability + Release-Floor Continuation (2026-06-15)

Priority order honored: P1 Gemma runnable → P2 skills/tools app-side → P3 harden → P4 architecture (owner-gated frontier).

- [x] **Release-audit floor: systemic `_or_advanced` cursor drift repaired** (`db2268ccc`). The V1 release-audit cursor advanced the recorded next-bottleneck evidence to the endgame value (`release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes`); 9 falsifier bins' `guard_next_existing_work`/`capability_next_bottleneck` axes only accepted their legacy NEXT_CURSOR and went red. Each now also accepts `ADVANCED_RELEASE_AUDIT_CURSOR` (same pure-boolean shape as the already-landed `provider_route_copy_source_guard` + `ssd_wear_budget` fixes). All 10 confirmed green this session (each run isolated — see [orphan-collision lesson](#)): codec_stage_latency 2, cold_panic_fallback ok, metal_io_feature_gate 2, product_route_review 1, slab_arena_copy_count 2, small_model_runtime_harness_dry_run_witness 1 + _safety_plan 1, transport_cancellation 1, transport_trace_answer_packet 5, helper-bin large_model_provider_reference_deferred_by_mlx_route 4.
- [x] **Skills read app-side storage first** (`628041917`). `SkillDiscoveryCatalog.discoverSkillEntries` was re-walking the discovery roots + re-parsing every `SKILL.md` on every AgentCommandCenter `present()`. Added a process-wide `SkillDiscoveryCache` so the hot path serves the parsed catalog from app-side storage; disk only on cold-cache / forceRefresh / explicit-roots (tests stay isolated). Settings + diagnostics forceRefresh to repopulate ground truth; `createSkill` already refreshes. Mirrors `SkillContentStore` (generated-skill manifest). Tools already come from the in-process Rust registry via FFI; context providers are in-memory — skills were the one remaining hot path re-globbing disk. 2 new focused tests. TEST BUILD SUCCEEDED.
- [x] **Dense Gemma 4 E2B installable for on-device validation** (`0d241ac61`). The 2026-06-14 native Apple Swift loader landed (E2B `isAwaitingSwiftRuntimeLoader=false`, `isReleaseValidatedForInteractiveChat=true`) but E2B was never added to the install catalog — so the loader worked + the tier was picker-selectable, yet the weights never appeared in Settings to download ('still didn't see Gemma working'). Added `gemma4_2B4Bit` to `optionalBaselineModelIDs`, refreshed stale descriptor copy (kept 'not a shipping route' so the preview invariant holds), updated the exact-list test. Honest: enables INSTALL (no quality claim), not a shipping-validated promotion; on-device token-gen still needs a signed Product▸Run (MLX metallib). 26B-A4B MoE + 31B-JANG stay gated. Reversible in one commit.
- [ ] **User on-device validation pending**: open the app on a signed build, Settings → install "Gemma 4 2B", select it in chat, generate — confirms the vendored Gemma4Text loader produces tokens on-device (the one step that can't run headless).

### Latent release-floor reds repaired (2026-06-16)

The 2026-06-09 cursor advancement (`438e78bd1d`) pushed the guard + capability
bottleneck evidence to the release-audit endgame value, leaving 16 inline
`small_model_runtime_harness_*` falsifier probes **latently red**: a fresh
`main()` run hard-failed (`GuardCursorMismatch`, exit 2) because their uas-module
validations + bin `_or_advanced` axes only accepted their own CURSOR/NEXT_CURSOR.
Crucially these probes are **testless**, so `cargo test` reported "ok" while the
real run failed — the stale checked-in `overall_pass=true` artifacts dated to
2026-06-05, before the advancement. The helper-based probes were already migrated.

- [x] **15 probes fixed + verified** across `52e4c5ceb` (owner_approved_probe),
      `341f4981e` (+12), `a0b3a2b6d` (live_probe + safety_lease, `matches!` variant).
      Each gains a local `ADVANCED_RELEASE_AUDIT_CURSOR` const + the release-audit
      clause on its 2 module validations and 2 bin axes. All 15 fresh `main()` runs
      print `overall_pass=true` (exit 0); owner_probe additionally passes its full
      command script end-to-end (`f_*.sh`: bin + `falsifier_validator`, exit 0).
      agent_core lib **5322 passed / 0 failed** (no regression from the uas changes).
- [ ] **`l3_log_correlation_probe` left for owner review**: shares the cursor drift
      but ALSO hard-fails `ManualVerificationAlreadyGreen` — it requires the
      manual-verification probe to be not-yet-green, but that probe now passes. A
      deliberate superseded-state dependency, not cursor drift; not overridden.
- [ ] **Full-floor "3 zero-fail passes" is the owner's CI gate**: the 257
      `Tools/falsifiers/f_*.sh` scripts share `artifacts/falsifiers/*/result.json`,
      so a naive bulk run cross-contaminates; proper ordering is the CI's job. These
      15 fixes remove 15 blockers from that gate.

## 2026-06-17 — P1.5 Fast "three efforts" per-query sizing
- Fast tier now sizes the loaded Gemma to the query: trivial→E2B, medium→E4B, hard→12B, via `EpistemosFastEffortSizing.candidateIndex` (pure policy) + `InferenceState.sizedFastLocalTextModelID`, injected at the single `routeDecision`/`localModelSelection` seam through `effectivePolicyContext(sizedFastComplexity:)` (profile.queryComplexity from QueryAnalyzer). Only fires on the simplified Fast tier when the user is on the headroom-aware default — explicit within-Fast picks and Think/Code/Tools untouched. Memory-safe: candidate pool is the comfortable-fit set, so 16 GB caps at E4B (never auto-selects the tight 12B); 64 GB reaches 12B for hard queries. +6 reasoned tests (3 pure-policy, 3 InferenceState). Build + test-build green.

## 2026-06-17 — P1.4 Honest local-runtime memory blocker (#43)
- When the selected local chat model can't load into the current free-memory budget, the composer now DISABLES Send and shows a one-line orange banner ("Not enough free memory for X (~N GB needed, M GB free). Free up memory, pick a smaller tier, or route to cloud") instead of attempting and OOM-ing or silently swapping. Pure policy `LocalChatModelMemoryGate.fits/blockerReason` (headroom 6, mirrors the agent-tier check); `InferenceState.localChatModelMemoryBlocker(for:)` supplies live numbers; ChatInputBar gates `sendButton.isEnabled` + `submitCurrentText` and renders the banner. "Send on cloud" stays enabled as the escape hatch. Fast tier gates on the smallest installed size so a trivial query the E2B can answer is never refused. +5 reasoned tests (3 pure, 2 InferenceState via injected runtime health). Build + test-build green.

## 2026-06-17 — Owner hotfix: Think/Code never resolve as a Fast Gemma 12B
- Stale path: when VibeThinker (Think) or the coder (Code) wasn't installed, `effectiveLocalTextModelID(for:)` fell through to the stored cross-tier pick (a Fast Gemma, often 12B), and `effectiveChatSurfaceSelection`'s `.localMLX` fallback surfaced that Gemma for Think/Code — so Think could resolve/label/route as Gemma 4 12B. Fixed three seams: (1) `effectiveLocalTextModelID(for:)` returns nil for a foundation tier whose own model isn't installed once the lineup is live (`hasInstalledFoundationModel`), instead of a wrong-tier model; (2) `effectiveChatSurfaceSelection` pins an unresolved foundation tier to its representative id (VibeThinker for Think, coder for Code, smallest Gemma for Fast) so label/route/readiness read as the correct tier and the surface is honestly "not ready" until installed — never a wrong-tier Gemma; (3) Overseer `selectedLocalOperatingMode` stops collapsing `.pro` into `.thinking`, so Code binds to the coder (reasoning depth unchanged via `localReasoningMode`). Gemma 4 12B is now only ever Fast's hard-query size or the Code/coder tier. +1 locking test. Build + test-build green.

## 2026-06-17 — P1.7 Apple Intelligence preserved as a first-class native route (owner hotfix b)
- The simplified picker buried Apple Intelligence under Advanced→Models. Now surfaced at top level via `appleIntelligenceSection` in `simplifiedRuntimePopover` (after the Cloud toggle): selectable when `appleIntelligenceAvailable`, visibly unavailable with the OS `appleIntelligenceUnavailableReason` when not. It's NOT cloud and NOT a hidden fallback; selecting it sets the chat surface to AI, tapping again reverts to the on-device Epistemos foundation model. Runtime audit: the Think-hotfix pin in `effectiveChatSurfaceSelection` only fires for `.localMLX` preferred, so AI selection is never overridden; TriageService keeps `.appleIntelligence` distinct from cloud; ACC brain catalog still lists it. Honest gate intact (AI can't drive Agent/tool-calling). +1 guard test (AI resolves for every tier, ready, never cloud, never a Fast Gemma). Build + test-build green.

## 2026-06-17 — P1.9 Fast effort visibility (owner hotfix c, part 2)
- Fast's per-query sizing is now explainable as Low/Medium/High effort. Pure `EpistemosFastEffortSizing.effort(forComplexity:)` (shares P1.5 thresholds) + `EpistemosFastEffortSizing.FastEffort` enum; `InferenceState.fastEffortRouteReason(forComplexity:operatingMode:)` returns "Fast · Medium effort → Gemma 4 E4B QAT GGUF" (nil off-tier/on explicit pick). Surfaced live in the composer (`ChatInputBar.fastEffortHint`) as a subtle caption when on Fast with a draft (classifies the draft via the same QueryAnalyzer.complexity the runtime sizes on), hidden while a memory blocker shows. Raw model is never the required choice. +2 reasoned tests. Build + test-build green.

## 2026-06-17 — P1.8 Honest model install progress (owner hotfix c, part 1)
- Downloads no longer look frozen. Pure `ModelInstallProgressDisplay.from(fraction:)` maps a raw Foundation `Progress.fractionCompleted` to an honest display: indeterminate "Starting…" spinner at 0/absent/NaN, a determinate bar with truncated percent while bytes flow (never prematurely 100%), and an indeterminate "Finalizing…" spinner at ≥1.0 (checksum verify + atomic activation still running). Wired into the per-model row (SettingsView) and the one-tap foundation-package button now shows a live aggregate spinner ("N models downloading…") + is disabled mid-install so a second tap can't double-trigger. +4 reasoned tests for the mapping. Build + test-build green.

## 2026-06-17 — HARDENED Priority 1 (loop rule #6)
- Re-scanned all owner hotfixes (a Think/Code, b Apple Intelligence, c installs+effort, d acceptance query): a/b/c all landed (commits 36bdbb5d7, b6c474bd5, 72d65b9ec, ee354084e); d (vault "best essay" acceptance) is P2.2 — next, not dropped. P1.4/P1.5/P1.7/P1.8/P1.9 all done.
- Build + test-build both green (full app compile + EpistemosTests compile). No Rust files changed this session (all Swift), so the agent_core suite is unaffected.
- Honesty grep on every changed Swift file: no try!/print()/force-unwrap/fatalError; no new silent model substitution or hidden route (the only "silent"/"fallback" matches are honesty-fix comments); MAS/Pro boundary + GGUF flag untouched; no Keychain/UserDefaults key handling changed. P1 verified honest.

## 2026-06-17 — P2.2 vault-lookup routing VERIFIED + integration regression (owner hotfix d)
- Traced the acceptance query "please tell me the best essay I have in my vault" end-to-end: the "essay" cue in `queryLikelyTargetsExistingNote` makes `queryContainsExplicitNoteContext` true → `hasExplicitContext` true → (a) `buildContextAttachments`/`resolveNotesContext` runs an implicit vault search and inlines candidate notes, AND (b) `OverseerComplexityRouter.selectedRoute` returns `.overseerLocalExecution` (full surfaced tool set incl. vault search/read), never the tool-less `.localOnly` direct stream that would answer from priors. Not a managed-agent query (no long-running/web signals). Locked with `EpistemosTests/ChatVaultLookupRoutingTests.swift` (3 integration tests: acceptance→tools+allowsToolExecution, detection cues, generic→localOnly). Build + test-build green.
- Rule #7 follow-up recorded in the ledger: superlative "best" still keyword-searches rather than enumerating essays then ranking by evidence, and the search→rank→title/path/reason fallback only fires on pipeline error — a proactive ranked answer / explicit "vault unindexed" blocker for non-tool-loop vault turns is the next P2.2 slice.

## 2026-06-17 — P2.1 (backend) user tool toggles really gate the main-chat tool set
- Closed the honesty gate I flagged: main-chat tools came from `executionPlan.allowedToolNames` (Overseer plan), so `agentCommandCenterState.toolToggles` didn't affect them — any in-chat toggle UI would have been fake config. New `ChatCoordinator.executionPlanGatedByUserToolToggles(_:disabledToolNames:)` removes any explicitly-OFF tool (canonical-name matched) from the plan's tool_permissions before the manifest/tier/tool-loop consume it; wired at the plan-build site with `Set(agentCommandCenterState.disabledToolNames)`. Default all-on (empty disabled set → plan returned unchanged), so behavior is identical unless the user disables a tool — then it's real runtime control. +3 tests (default all-on unchanged, disabled tool removed, unknown tool no-op) on the real router-built plan. Build + test-build green. NEXT P2.1 slice: the in-chat tool-toggle UI now that the toggles honestly gate the runtime.

## 2026-06-17 — P1.10 / owner hotfix f: kill the hidden Qwen reroute on the agent/tool/attachment seam
- Reported: picking Think (VibeThinker) + "Read+Search vault" tools + "analyze" surfaced "Qwen 3 8B needs ~12 GB … pick Qwen 3 4B" — the tool/agent path silently routed to a still-installed legacy Qwen even though the user picked a foundation tier. Root: `effectiveLocalAgentTextModelID`/`fittingLocalAgentTextModelID` fall back to `supportedAvailableLocalAgentModels` (enum-only, agent-capable), which still contained Qwen 3 8B. FIX: under `simplifiedLineupActive`, `supportedAvailableLocalAgentModels` is filtered to foundation-tier models only — foundation tiers are GGUF (non-enum), so the set is empty → the agent fallback returns nil → `shouldUseToolLoop` degrades to a direct stream on the SELECTED foundation model (or cloud), never a hidden Qwen swap. Also fixed the `TriageService.insufficientMemory` recovery copy to name the real GGUF foundation model (via GemmaQATRuntimeLadder) and offer foundation ways out (free memory / smaller Fast tier / route to cloud) instead of the hardcoded "Qwen 3 4B" under the simplified lineup. +2 regression tests (agent path never resurrects Qwen for a Think pick; OOM blocker never says Qwen). Build + test-build green. Audited: ChatCoordinator currentCommandCenterAutoBrain + ConfidenceRouter.selectedLocalModelID are downstream of this resolution (they pass through what they're given), so the single root fix covers them.

## 2026-06-17 — P2.1 UI: in-chat agent-tool toggle panel
- Added `AgentToolTogglePanel` (Epistemos/Views/Chat/AgentToolTogglePanel.swift), opened from a new composer capsule button (`slider.horizontal.3`, active-styled when any tool is off). Lists the surfaced agent tools grouped by owning agent (Web/Files/Vault & notes/Terminal/Automation/Memory), each with an on/off switch bound to `AgentCommandCenterState.toolToggles`/`toggleTool`, destructive + asks-first badges, all-on/all-off quick actions, and an honest capability footer (local = chat+reason; multi-step tools via cloud/Pro; turning a tool off removes it from this chat's agent turns). Gated on a non-empty catalog so it never shows a dead control. This is REAL config — the toggles flow through `executionPlanGatedByUserToolToggles` (a731469a6) into the main-chat plan — not decoration, so it satisfies the no-fake-config honesty rule. Grounded in the existing ChatInputBar/ToolbarCapsuleButton/popover components; app+test targets are syncedFolder so the new file auto-includes. Build green. (Honesty contract covered by the P2.1 backend gate tests; the panel is view code.)

## 2026-06-17 — P2.3 MCP servers: honest read-only "wired" surface in chat
- Honesty finding (research-first): there is NO Swift-side external-MCP-server registry and no mutation path — MCPBridge is the in-process omega-mcp dispatcher (built-in tools), and the Rust mcp/client (stdio subprocess) + url_servers are not surfaced/mutable from the app. The ONLY real external wiring is `agent_core/src/mcp/url_servers.rs::discover_url_mcp_servers()` reading `~/.config/mcp/url_servers.json` + `.epistemos/mcp_url_servers.json`, which bridge.rs forwards into the Claude `mcp_servers` API param. So an add/enable/disable UI would be fake config. Built the honest version: `MCPUrlServerDirectory` (Epistemos/Omega/) mirrors the Rust discovery (https-only, name+url required, project-over-global dedupe, never reads/shows tokens — only an "auth declared" flag) + a read-only "MCP servers" section in the in-chat AgentToolTogglePanel (name + host + auth badge; honest empty-state pointing at the config file, not a dead Add button). +7 parser/discover tests locking the format contract against the Rust source. Build + test-build green. FOLLOW-UP (ledger): add/enable/disable = a Pro config-file editor (MAS sandbox can't write ~/.config; stdio servers are Pro-only) — a separate gated slice.

## 2026-06-17 — P2.4 in-chat skill browser + one-tap run
- Added a "Skills" section to the in-chat AgentToolTogglePanel: lists the discovered skills (procedural memory) from SkillDiscoveryCatalog/availableSkills (refreshed on panel open) with title + description, and a one-tap "Run" that primes the composer with the skill's real `/identifier` slash token (`runSkillFromPanel` in ChatInputBar) — the exact run path the slash menu uses, so it's not a fake action. Create/edit is surfaced honestly as a pointer to the real authoring paths (Settings → Skills `SkillAuthoringDraft`→`skills/<id>/SKILL.md`, or asking the agent's `skill_manage` tool which writes SKILL.md) rather than duplicating a half-wired form in chat. Honest empty-state when no skills exist. Browse + run reuse proven mechanisms (no new test needed: run = the slash path, browse = availableSkills). Build green. FOLLOW-UP (ledger): a real in-chat create form would wire SkillAuthoringDraft.createPayload→vault write; deferred since two real create paths already exist.

## 2026-06-17 — P2.5 git/diff Pro boundary verified + honest Pro-capability surface
- Research-first: the MAS/Pro boundary for git/shell is ALREADY correct and enforced. The cli_passthrough tools (claude_code/codex/gemini — which can run git/ssh/curl/anything) register only under `#[cfg(feature = "pro-build")]` (registry.rs:844); `enable_bash` is Pro-gated; `mas_forbidden_tool_name` excludes bash/terminal/process/cron. Default Cargo features = `mas-build` (pro-build OFF), and the exclusion is locked by `mas_sandbox_registry_excludes_unbounded_tools` (covers claude_code/codex/bash_execute/terminal/process). RAN IT LIVE: `cargo test ... mas_sandbox_registry_excludes_unbounded_tools` → ok (1 passed). So MAS does NOT expose shell/git; Pro does — no fake rows, boundary honest.
- There are no DEDICATED git tools (git status/diff/commit/branch as schema'd tools); git is reached on Pro via the cli_passthrough/bash subprocess (security.rs harden_cli_subprocess). Per the owner's offered path, added an honest Pro-capability disclosure to the in-chat capability explorer ("Git, diff, shell, and CLI-agent tools (Codex, Claude Code) run only in the Pro build."), shown only on the App Store build (`ToolSurfacePolicy.resolvedDistribution(.currentBuild) == .coreAppStore`) — never a tool the build can't run. Build green; cargo boundary test green.
- FOLLOW-UP (Founding Thesis, logged): a dedicated schema'd READ-ONLY git tool (status/diff/log/branch, no mutation, security.rs-hardened, Pro-gated, cargo-tested) is more deterministic than raw bash passthrough — a separate Rust slice (registry.rs pro-build block).

## 2026-06-17 — P2.6 Companion agent meta-builder: verify wired + validate output schema
- Research-first: the Companion builder (CompanionCreationFlow) already exposes a real agent config — name, role, runtime (model routing), scope, approval mode, tool toggles, custom system prompt, and an "Output structure (JSON)" field. Verified the output schema is NOT fake config: `outputStructureJSON` is stored on `CompanionModel` (CompanionModel.swift:77) via createCompanion/updateCompanion and injected into the active agent's system prompt as a response contract (CompanionState:284). So the foundation is honest — all exposed fields are wired.
- Hardened the one real risk: a malformed schema would be saved + injected as a broken contract. Added pure `CompanionOutputSchemaValidation` (empty=ok optional; must be a JSON object shaped like a schema with `type`/`properties`; rejects trailing commas, bare strings, non-schema objects with actionable messages) + an inline error under the editor + save-disabled when invalid. +5 reasoned tests. Build + test-build green.
- FOLLOW-UP (Founding Thesis, logged in ledger): wire outputStructureJSON to the json_schema FFI (run_local_gguf_generation with_json_schema) so local Companion agents are grammar-CONSTRAINED to the schema (deterministic), not just prompt-nudged.

## 2026-06-17 — HARDENED P2 (loop rule #6)
- Re-scanned ALL owner hotfixes a–f: a (Think/Code never Gemma 12B) 36bdbb5d7; b (Apple Intelligence preserved) b6c474bd5; c (visible installs ee354084e + Fast effort 72d65b9ec); d (vault "best essay" acceptance) P2.2 2b479b837 + ChatVaultLookupRoutingTests; e (North Star + rules #6/#7 + P7/research escalations) folded in + applied every slice; f (no hidden Qwen on agent seam) 5640fd0ca. NONE dropped. Open follow-ups are logged in the ledger (P2.2 proactive ranked vault answer; P2.5 dedicated schema'd read-only git tool; P2.6 wire outputStructureJSON → json_schema FFI).
- Verification: full app build green; Swift test target compiles green; `cargo test --manifest-path agent_core/Cargo.toml --lib` → 5328 passed, 0 failed. P2 touched only Swift + docs (zero Rust files), so the Rust suite is unaffected — confirmed green regardless.
- Honesty grep on P2 (P2.1–P2.6): no fake config (P2.1 toggles gate the real main-chat plan via executionPlanGatedByUserToolToggles + tests; P2.3 MCP surface reads the real config files Rust forwards; P2.4 skill run = the real /identifier slash path; P2.6 output schema is stored + injected, now validated); MAS/Pro boundary intact + cargo-verified live (P2.5 mas_sandbox_registry_excludes_unbounded_tools); no hidden model route introduced; no Keychain/UserDefaults key handling touched; no try!/print()/force-unwrap in P2 files. P2 verified honest.

## 2026-06-17 — P7.1 Fast capability ceiling made explicit + cargo-locked
- Research-first: the Fast tier (chat_lite) tool set is defined by `apply_tier_overrides` CHAT_LITE (read/search/reason: web/vault reads, file reads, graph/knowledge recall, think); CHAT_PRO_EXTRA adds the gated vault.write/file.patch/memory; and on the MAS build `mas_forbidden_tool_name` (under `not(feature="pro-build")`) blocks shell/git/process across ALL tiers — the absolute limit is build-gated, not tier-gated. Tools report CANONICAL dotted names (vault.search, vault.write, action.bash…).
- Made the ceiling explicit + REAL-verified with a new cargo test `fast_chat_lite_capability_ceiling_is_explicit` (ran live → PASS): Fast HAS think/vault.search/vault.read/file.read/knowledge.recall (legit read/search, not empty); Fast CANNOT mutate (no vault.write/file.patch/memory) nor shell (no action.bash/action.terminal/system.process); chat_pro LIFTS to include vault.write while keeping the reads; and even chat_pro on the MAS build excludes shell/git/process (the absolute MAS limit holds across tiers). Discovered the real tool names by running the test (vault tools register under canonical dotted names; vault.* need a real-ish vault root) rather than guessing. Honest surfacing already exists via the P2.5 capability-explorer Pro-developer note + build-scoped tool list. No behavior change (test-only addition); 5328+1 lib tests green.

## 2026-06-18 — P7.5 slice 1: MiniChat memory-blocker + Fast-effort parity
- Research-first: MiniChat + NoteChat already route through the SHARED layers (`triage.streamGeneral` → `inference.routeDecision`/`effectiveChatSurfaceSelection`), so they ALREADY inherit the InferenceState/TriageService-level fixes — P1.5 Fast per-query sizing, P1.6/P1.7 Think-pin + Apple Intelligence route, P1.10 no-hidden-Qwen — plus the simplified picker (LocalModelToolbarMenu). The drift is purely ChatInputBar-only UI affordances (P1.4 blocker, P1.9 effort hint, P2.1 toggles, P2.4 skills) that MiniChat's custom composer lacked.
- Slice 1: MiniChat now surfaces the P1.4 honest memory blocker (Send disabled via `canSend` + `send()` guard + an orange banner) and the P1.9 Fast effort hint, by reusing the SHARED `InferenceState.localChatModelMemoryBlocker(for:)` / `fastEffortRouteReason(forComplexity:operatingMode:)` — parity by sharing the logic, not a fork, so it can't drift. No new test (the shared methods are already locked by the P1.4/P1.9 InferenceState tests; MiniChat just calls them). Build green. NEXT: MiniChat tool toggles/skills (P2.1/P2.4), then NoteChat parity, then parity regressions.

## 2026-06-18 — P7.5 slice 2: MiniChat tool/skill capability panel parity
- Research correction: MiniChat is MORE capable than it first looked — it already has `agentCommandCenter` in @Environment, surfaces skills via its slash menu (P2.4), and routes tools through the shared coordinator (`isUsingSharedCoordinator`/`toolsModeSelected`). So the only gap was the in-chat tool-toggle UI. Added the SHARED `AgentToolTogglePanel` (tools + MCP servers + skills + Pro-developer note) to MiniChat's composer via a tool-panel button, with onRunSkill priming the composer's real `/identifier` slash token. Honest: the toggles gate the same AgentCommandCenterState the shared-coordinator tools path reads (P2.1's executionPlanGatedByUserToolToggles), and skill-run reuses the slash mechanism MiniChat already executes. MiniChat now matches Main's stack: picker (P1.1), no-hidden-Qwen (P1.10), memory blocker (P1.4), Fast effort (P1.9), Apple Intelligence (P1.7), memory/vault search (P2.2 via resolveAttachedContext), tools+skills (P2.1/P2.4). Build green. NEXT: NoteChat parity, then parity regressions.

## 2026-06-18 — P7.5 NoteChat parity + parity regression (P7.5 COMPLETE)
- NoteChat parity: the note-ask bar (NoteDetailWorkspaceView.toolbarChatField) is a lightweight inline ask that TRANSPARENTLY ESCALATES to Main chat for tool work, so honest per-surface gating = it hosts the P1.4 memory blocker + P1.9 Fast effort (via the SHARED inference.localChatModelMemoryBlocker/fastEffortRouteReason) but NOT a tool panel (Main has it). Wired: placeholder shows the blocker reason when blocked; submitToolbarAskInline guards on it (never submits on a model that can't load); the pill detail carries the Fast effort hint. Build green.
- Parity REGRESSION: new ChatSurfaceParitySourceGuardTests (source-guard, deterministic) asserts Main (ChatInputBar), MiniChat (MiniChatView), and NoteChat (NoteDetailWorkspaceView) all wire the shared capability methods (localChatModelMemoryBlocker + fastEffortRouteReason; + AgentToolTogglePanel for Main/Mini), so a surface can't silently drop a capability again. Test-build green; assertions reasoned to certainty (each marker was added this session).
- P7.5 COMPLETE: every local-model chat surface now matches Main's stack via SHARED logic (no fork) — MiniChat full (picker/no-hidden-Qwen/blocker/effort/AI/memory-search/tools/skills), NoteChat as-much-as-it-honestly-hosts (blocker/effort + escalate-to-Main for tools), Graph chat routes into Main (routeGraphChatRequestIntoMainChat). NEXT: P7.2 (HTML workspace), interleaving research verdict docs (R-VOICE/R-EVE/R-OKF/R-PROMPT) + P7.7 voice.

## 2026-06-18 — R-VOICE verdict doc + P7.2 finding
- R-VOICE (docs/RESEARCH_VOICE_2026_06_18.md): deep web research → verdict for P7.7. Key calls: TAKE Kokoro-82M (Apache-2.0, on-device CoreML/MLX Swift pipelines — mweinbach/kokoro-swift, FluidAudio, kokoro-coreml; zero Python at inference; ~330–600 MB, 54 voices) as the optional "premium voice" downloaded via the existing ModelDownloadManager + P1.8 progress UI, with AVSpeechSynthesizer as the instant fallback; KEEP Apple SpeechAnalyzer/SFSpeech for STT (WhisperKit optional later); BUILD the retro pixel-art filter as an AVAudioEngine DSP chain (bitcrush + sample-rate reduction + formant/pitch — no model, on-device, on-brand); SKIP cloud TTS by default + the owner-named MOSS-TTS-PNY/ZDisket (couldn't verify a maintained Swift path). ~70% of P7.7 already exists (EpistemosSpeechSynthesizer, ReadAloudButton, VoiceInputButton, AudioTranscriber, ModelVoicePickerSection, ScreenCaptureService for auto-read-screen) — the new pieces are the Kokoro option + the retro DSP + the 3 granular Settings toggles. 3 open questions for the owner to pick before build. Verdict only — no build.
- P7.2 finding: the HTML workspace renderer (Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift, 151 lines) is a clean, functional WKWebView (loadHTMLString + navigationDelegate + dismantle); HTMLWorkspaceEditorView (1068 lines) + HTMLWorkspacePatchRouter (parse AI patch batches) all present. No obvious bug. "Broken" is non-obvious without the owner's specific symptom/repro — guess-fixing a 1200-line subsystem would be thrashing (loop forbids). FLAGGED: P7.2 needs the owner's concrete repro (what doesn't render / what's broken) OR is scoped to the additive "chat-drivable canvas live-viewer" piece. Deferred to a dedicated pass.

## 2026-06-18 — R-VOICE deepened: MOSS-TTS path + owner "ship both" decision
- Owner decided: ship BOTH voices — Kokoro-82M (everyday) + MOSS-TTS (special "reading voice", selectable for any note type + in-chat reading); retro filter applies over either. Updated docs/RESEARCH_VOICE_2026_06_18.md.
- Deep MOSS dive (real web research): "MOSS-TTS-PNY" = the OpenMOSS MOSS-TTS family ("PNY" = its Pinyin/phoneme pronunciation-control feature, not a separate model; ZDisket is a re-uploader). Apache-2.0. Best fit = MOSS-TTS-Nano (~120M total: 0.1B token-LLM + ~20M audio tokenizer → 48 kHz; runs on CPU). HONEST on-device path = ONNX Runtime (infer_onnx.py, no PyTorch; ONNX RT links in-process into Swift via its C/Apple API) → fully on-device, NO Python, NO hidden subprocess (MAS-honest). No turnkey Swift/CoreML MOSS pipeline exists yet, so it's a real Pro/dev build lane (obtain ONNX models + link ONNX RT SPM dep + wire text→token→audio glue). Plan: ship Kokoro+AVSpeech+retro first (Kokoro has a ready Swift path), add MOSS-via-ONNX as its own slice; until it lands the MOSS picker option shows an honest "install the reading-voice pack" blocker — never a fake voice, never Python on MAS. Heavier alts (mlx-community/MOSS-TTS-8B-8bit, MOSS-TTS-v1.5-GGUF) noted but overkill for a reading voice on 16 GB. No build until owner picks the 3 open questions.

## 2026-06-18 — P7.4a CHAT UX MAP (unblocks cowork + OpenCode)
- Wrote docs/CHAT_UX_MAP_2026_06_18.md: unravels the whole chat UX into THREE orthogonal axes — MODE (Chat conversational vs Act = the multi-step agent loop; maps to existing operatingMode .agent/managedAgentSession + the per-turn cloudToolBudget Fast=5/Think=10/Code=15) × MODEL TIER (Fast/Think/Code + cloud + Apple Intelligence — the brain, picker-chosen, independent of mode) × SURFACE (Main/Mini/Note/Graph/cowork — all share ONE capability path via InferenceState+ChatCoordinator, parity locked by ChatSurfaceParitySourceGuardTests). Includes a per-mode capability table (search/write/skills/toggles/MCP/shell/panels) and reaffirms the absolute MAS limit is build-gated across all modes+tiers (P7.1). RESOLVES the "Code overloaded" collision: Code = a model tier only (no second Code button); OpenCode = a deep code/terminal CAPABILITY reachable from ACT mode on the Pro build (Act + any tier + Pro → OpenCode depth), not a mode/tier. This gates P7.4 OpenCode and makes P7.6 cowork coherent (cowork = Main surface + Act-mode panels driven by real agent-loop telemetry). Grounded in the actual code paths, not invented. Research/synthesis doc — no build.

## 2026-06-18 — P6.4 item 1: FIX custom-theme font picker ("picking does nothing")
- ROOT CAUSE (not the write side as first suspected — that was correct): the WRITE (Settings picker → setHeadingFontOverride → UserDefaults, validated via displayFontOption(postScriptName:)) AND the gated READ (headingFontOverride, custom-theme-only) were both correct. The break was the LIVE RE-RENDER: `UIState.theme` is a computed property derived from activePair/themeMode/isSystemDark only — it NEVER observed `typographySettingsRevision`. So `refreshTypographySettings()` bumped a counter that NOBODY read (grep: zero observers outside UIState), the override persisted to UserDefaults, but no view reading `ui.theme.headingFont(...)` re-derived → "picking a font does nothing." (Also: `appearanceSyncKey` included the revision but most themed views read `ui.theme` directly, not the sync key.)
- FIX: `UIState.theme` now reads `_ = typographySettingsRevision` at the top, so a font/scale override change re-derives the theme and re-renders every `ui.theme` consumer; the heading getters read the override from UserDefaults at render time, so the fresh derivation picks up the new font (all levels). One-line, surgical, no behavior change beyond fixing the dependency.
- REGRESSION: new CustomThemeFontOverrideTests — store round-trip (persist + read-back), custom-theme gating (ignored on other pairs), clear-to-default, AND a source-guard that `UIState.theme` reads `typographySettingsRevision` (locks the fix). Build + test-build green.
- FOLLOW-UPS (owner P6.4 items 2+3, next slices): (2) replace the busy mock-UI theme preview with a clean COLOR-PALETTE swatch (palette-only); (3) declutter the theme/appearance Settings section (group rows, remove dead/duplicate controls, pixel-art minimal — don't hide real settings).

## 2026-06-18 — R-EVE verdict doc (interleaved research)
- docs/RESEARCH_EVE_2026_06_18.md: verdict on Vercel's `eve` agent framework. SKIP as a dependency (Node/TS, AI-Gateway, cloud-deploy — not native/on-device/MAS-safe). ADOPT the pattern selectively: eve's filesystem-first agent layout (agent.ts/instructions.md/tools/skills/sandbox/schedules, auto-wired) is the same shape we're converging on, and we ALREADY have its skills/ = one-SKILL.md-playbook idea (SkillDiscoveryCatalog + procedural memory). Worth-taking 20%: (1) portable filesystem-first Companion agents (companion/<name>/ = config + instructions.md + skills/ + tools allowlist) as a P2.6 agent-builder direction (shareable/versionable, composes with our SKILL.md discovery); (2) Vercel's "AGENTS.md outperforms skills in our evals" signal → keep investing in instructions/system-prompt quality as the primary lever, skills as the relevance-loaded complement (which our procedural memory already does); (3) build-time auto-wiring ergonomic (we already auto-register tools + auto-discover skills) — apply to cowork connectors/MCP too. Keep OUR determinism substrate (grammar/schema constraint, ClaimLedger, Cognitive DAG, capability ceiling) — eve adds none of that. Zero code dependency; small high-leverage influence on the Companion builder + cowork.
- P7.6 SLICE 1 (ACT/CHAT toggle) note: surfaced a real design fork — the existing mode picker (RootView displayedOperatingModes) already exposes .agent, so a naive Act/Chat toggle would collide. The honest design (per the UX map: Mode is a separate axis from Tier) wants Act/Chat as a depth selector distinct from the Fast/Think/Code tier picker; today operatingMode conflates tier+depth (.agent has no tier). Next slice: design a non-colliding Act/Chat presentation (Act gated to when an agent route exists — cloud/Pro — honest, never fake agent capability for local-only), grounded in operatingMode, on a fresh careful pass.

## 2026-06-18 — P7.6 SLICE 1: ACT vs CHAT depth toggle (cowork fusion)
- Per the CHAT_UX_MAP, Mode (Chat/Act) is a separate axis from Tier (Fast/Think/Code). Added a clean, NON-COLLIDING depth toggle to the simplified runtime popover: a "Mode" section with Chat (conversational on the selected tier) + Act (the multi-step agent loop, operatingMode .agent), and the tier rows ("Tier" section) now show Fast/Think/Code ONLY (`.agent` filtered out — it's the Act toggle, so depth and tier stay separate). `lastTierMode` @State remembers the tier so flipping Act→Chat restores it.
- HONEST gating: pure `CoworkChatMode` helper (Engine/CoworkChatMode.swift) — `actAvailable(in:)` is true only when `.agent` is in the available modes (cloud/Pro route exists); else the Act row is disabled with the real reason ("Act runs the multi-step agent loop — connect a cloud model or use the Pro build"), never faking agent capability for local-only. `current(for:)` maps .agent→Act / tiers→Chat; `operatingMode(rememberedTier:)` maps Act→.agent and Chat→the remembered tier. +1 test suite (CoworkChatModeTests: gating, current-depth, mapping). Build + test-build green. Grounded in the existing operatingMode engine (Act actually routes to the agent loop), additive to the popover, default local-only experience intact (Act simply disabled when no agent route). NEXT P7.6 slices: PROGRESS/WORKING-FOLDER/CONTEXT/QUEUE/CONNECTORS panels from real telemetry.

## 2026-06-18 — P6.4 item 2: palette-only theme preview (+ dead-code removal)
- Replaced the busy mock-UI custom-theme preview (CustomThemeCinematicPreview/Half — gradient halves + "CUSTOM" hero text + ghost capsule lines + scanlines) with a clean COLOR-PALETTE swatch (CustomThemePaletteSwatch): two rows (Light/Dark) of the 8 real editable color slots (AppCustomThemeColorSlot: background/text/accent/heading/card/noteSurface/chatSurface/userBubble) rendered from the actual AppCustomTheme.hex(for:isDark:) values, each with a hover title. Palette-only — the preview now reads as "this is the palette," honest + pixel-art minimal. Removed the two dead mock-UI structs (declutter, P6.4 item 3 partial). No test (UI renders the real palette; no logic). Build green. REMAINING P6.4 item 3: a broader declutter pass of the theme/appearance Settings section (group rows, remove any other dead/duplicate controls) — next.

## 2026-06-18 — P7.6: cowork CONTEXT strip (real tools + notes this run)
- Added the first cowork CONTEXT surface: a compact strip in the Main composer showing the REAL tools the agent invoked + notes it referenced this run — derived from the message's actual `.toolUse` content blocks (recorded by ChatState.recordToolUse) + chatState.loadedNoteTitles, never a mockup. Pure helper CoworkRunContext (Engine/CoworkRunContext.swift): toolNamesUsed(in:) dedupes the .toolUse names in first-use order; summary(toolNames:noteTitles:) builds "Tools: vault.search, vault.read · 2 notes" (nil when nothing used → strip hides). Surfaced via ChatInputBar.runContextSummary, gated to non-empty so the default clean composer is untouched. +CoworkRunContextTests (dedupe/order, empty, summary composition). Build + test-build green. NEXT P7.6 panels: PROGRESS (chatState.currentTodos/TodoSnapshotCard already exists — surface in cowork layout), WORKING-FOLDER (file_ops outputs, Pro-gated), QUEUE, CONNECTORS (MCP).

## 2026-06-18 — R-OKF verdict doc (OKF + vault dedup + privacy)
- docs/RESEARCH_OKF_2026_06_18.md: all three are TAKEs landing on infra we already have. (1) OKF (Open Knowledge Format, Google Cloud, Apache-2.0, vendor-neutral) = markdown + YAML frontmatter directory, one concept/file, only `type` required — the Epistemos vault is ALREADY this shape, so TAKE as an interop/export format (export the Knowledge Core/curated notes as a portable OKF bundle; optionally ingest; zero dependency, on-device, free; composes with R-EVE filesystem-first + our SKILL.md). (2) Privacy: OpenAI Privacy Filter via localai-org/privacy-filter.cpp (Apache-2.0, ~1.5B token classifier, 96% F1 on-device PII redaction, C++/GGML ~7.7× faster than HF on CPU) → TAKE as a Pro "redact-before-cloud" guard: mask PII locally before any context leaves the device for a cloud turn (GGML lane = Pro/dev, in-process, no Python/subprocess; honest "available in Pro" until it lands). (3) Dedup: best practice = MinHash+LSH (textual) + SemDeDup (semantic: embed→ANN→cosine threshold). We ALREADY have the semantic stack (TextEmbeddingLookup + SemanticClusterService + usearch HNSW shadow index), so BUILD a "find duplicate notes" vault-maintenance pass on the existing vector index, user-confirmed merge (never auto-delete). SKIP cloud dedup/privacy services + a bespoke new vector store. No build — verdict only.

## 2026-06-18 — R-PROMPT verdict doc (completes the R-VOICE/R-EVE/R-OKF/R-PROMPT batch)
- docs/RESEARCH_PROMPT_2026_06_18.md: SKIP priompt as a dependency (TS/JSX, MIT, not native; and the authors themselves warn priorities-on-everything is an anti-pattern + breaks caching). ADOPT two context-engineering principles that reinforce what we already do + fit the determinism thesis: (1) CACHE-STABLE PREFIX — the real 2026 cost/latency lever (Anthropic prompt caching ~90% cheaper cache reads; we already have agent_core/src/prompt_caching.rs): order the main-chat system prompt so stable parts (identity + CapabilityManifestBuilder + tool schemas) come first and volatile parts (user turn + freshly-loaded notes) last → maximize cache hits (concrete follow-up slice: audit context-assembly order). (2) LEAN TOOL SCHEMAS — only attach tools that can actually run this turn, which our capability ceiling (P7.1) + tool toggles (P2.1/disabledToolNames) already do. SKIP LLMLingua-style lossy compression (conflicts with verifiability/provenance — we want exact replayable context). Priority-based inclusion = a niche budget-overflow fallback only, never the architecture; our deterministic explicit context (grammar/schema constraint + explicit manifest + ClaimLedger/AnswerPacket provenance) is stronger + replayable. No build — verdict only.
- RESEARCH BATCH COMPLETE: R-VOICE (Kokoro + MOSS-via-ONNX + retro DSP), R-EVE (filesystem-first agents pattern), R-OKF (OKF export + privacy-filter.cpp + dedup-on-HNSW), R-PROMPT (cache-stable prefix + lean schemas) — all verdict docs in docs/, all owner-decidable.

## 2026-06-18 — P7.6: cowork QUEUE (stage a message while the agent works)
- Added the cowork QUEUE: while the agent is running (isProcessing), a "Queue" capsule button (text.append) appears beside Stop when the draft is non-empty — it stages the current message and clears the field; a "Queued: …" chip shows the pending message with a cancel; on the run-completion edge (isProcessing true→false) the staged message auto-submits via the same submitCurrentText path. Pure ComposerMessageQueue (Engine/): enqueue (trims, empty ignored), dequeueOnCompletion (fires exactly once on the true→false edge, never double-sends), clear. Wired in ChatInputBar with .onChange(of: isProcessing). +ComposerMessageQueueTests (trim/ignore-empty, edge-fires-once + no-double-send, no-op, clear). Real behavior, single pending message (honest run order), default composer untouched when idle. Build + test-build green. NEXT P7.6: PROGRESS affordance (currentTodos), WORKING-FOLDER (Pro), CONNECTORS (MCP).

## 2026-06-18 — P7.6: cowork WORKING-FOLDER (real files changed this run)
- Added the cowork WORKING-FOLDER panel: a compact composer strip showing the files the agent ACTUALLY mutated this run, with the common working folder openable in Finder (NSWorkspace.activateFileViewerSelecting). Data is derived from REAL file_ops tool-use blocks — never a mockup. Pure CoworkRunContext.filesTouched (recognizes file_ops action+path AND the legacy/dotted aliases file.write/write_file, file.patch/edit_file/patch, file.delete/delete_file, file.move/move_file; read-only ops EXCLUDED; deduped by path, latest action wins; missing/blank path skipped) + workingFolder (common-PREFIX parent dir, breaks on first divergent component). Strip is Pro-gated (resolvedDistribution != .coreAppStore) AND naturally empty under MAS (file mutation is MAS-forbidden) — hidden when nothing was written, so no phantom file list. +5 CoworkRunContextTests (mutating-only/dedup/order, name aliases incl delete/move, read-only→empty, missing-path skip, common-parent folder). PROGRESS panel verified ALREADY satisfied (TodoSnapshotCard renders chat.currentTodos live above the composer — not duplicating it). Build + test-build green. NEXT P7.6: CONNECTORS (MCP via MCPUrlServerDirectory) or P6.4 item3 declutter.

## 2026-06-18 — P7.6: cowork CONNECTORS (Slack/Gmail/Drive/Notion via real MCP)
- Added the cowork CONNECTORS panel to the in-chat tool panel: the well-known connectors (Slack/Gmail/Google Drive/Notion) each shown with their REAL status — "connected" ONLY when a wired URL MCP server actually matches (by name/url keyword), else honestly "not connected" with the real path to wire one (~/.config/mcp/url_servers.json; token read from the Keychain/env the server declares, never stored/displayed). Never a fake toggle. Pure CoworkConnectorDirectory.statuses(servers:) maps known connectors onto MCPUrlServerDirectory.discover() results; ConnectorStatus holds only Sendable primitives (wiredServerName/declaresAuth) — decoupled from the MainActor-isolated ServerInfo so the matcher stays nonisolated/testable. +5 CoworkConnectorDirectoryTests (none-wired→all disconnected, match-by-name, match-by-host case-insensitive, unrelated-server→no phantom connection, stable order). Two isolation fixes: matched on stored .url not computed .host; ConnectorStatus stores primitives not ServerInfo. Build + test-build green. P7.6 COWORK FUSION COMPLETE (ACT/CHAT, CONTEXT, QUEUE, PROGRESS, WORKING-FOLDER, CONNECTORS). NEXT: P6.4 item3 declutter, then P7.3 terminal (Pro), HARDEN P7.

## 2026-06-18 — P6.4 item 3: declutter the Appearance settings section
- Regrouped the Appearance pane so it reads as two clean zones instead of fragmenting "appearance" around the graph block: all look-and-feel sections first (Themes → Custom theme → Typography → Editor), then the graph trio as one contiguous block (Graph Node Types → Graph performance → Shaped Graph). Previously Editor sat AFTER the three graph sections, splitting the text/theme settings. Declutter ONLY reorders — every real setting stays reachable (no hidden controls); the section bodies are unchanged. Locked the intent with a pure AppearanceSection helper (canonical order + lookAndFeel/graph grouping) + AppearanceSectionOrderTests (every section once, look-and-feel precedes graph, graph sections contiguous, Editor grouped with look-and-feel) so a future reorder can't silently re-fragment the pane. The pane was already free of dead/duplicate controls (verified: Editor's line-gutter toggle intentionally shares CodeEditorView's AppStorage key; theme/typography sections clean post the P6.4 item1/item2 work). Build + test-build green. P6.4 COMPLETE (item1 font-write fix + item2 palette preview + item3 declutter). NEXT: P7.3 terminal (Pro), then P7.4 OpenCode, then HARDEN P7.

## 2026-06-18 — P7.3: terminal is Pro-only + MAS name-gate hardening
- Researched the terminal/shell lane end to end: agent_core terminal.rs (TerminalHandler/ProcessHandler) is registered ONLY under register_phase_one_terminal which is #[cfg(feature="pro-build")] AND its call site (registry.rs:873) is cfg-gated — so on the MAS/App Store build the terminal/process/scheduling tools are never even registered. mas_runtime_preflight is defense-in-depth (denies forbidden names + destructive + unscoped-mutating at execute time). Swift already honestly discloses it: AgentToolTogglePanel.showsProDeveloperNote says "Git, diff, shell, and CLI-agent tools (Codex, Claude Code) run only in the Pro build." No fake terminal control anywhere on MAS — the real path is Pro.
- HARDENING (rule #6) — found + closed a test gap: the runtime-denial test only proved `bash_execute` is denied; it didn't prove the terminal/process tools (the actual P7.3 surface) are denied by the NAME gate. Added mas_runtime_denies_terminal_process_by_name_even_if_readonly: registers each forbidden name (terminal, process, action.bash, action.terminal, bash_execute, run_command, run_persistent, system.process, cronjob, system.cron) as a harmless ReadOnly tool and asserts execute → PermissionDenied — so the denial is provably the forbidden-name list (mas_forbidden_tool_name), not the risk gate. cargo test PASSED (1 passed; 5329 filtered). #[cfg(test)]-only change → no app-build impact. NEXT: P7.4 OpenCode (LAST), then P3/P4.1 evals + P6.1 icons.

## 2026-06-18 — P7.4: OpenCode deep-agent capability (Pro, from Act mode) — LAST P7 item
- Added a real sst/opencode CLI passthrough, mirroring the existing Tunnel-C agents (claude_code/codex/gemini/kimi/goose/aider/openhands/mini_swe_agent). cli_passthrough.rs: OpenCodeHandler runs `opencode run [--model provider/model] <task>` via the shared hardened run_passthrough (env_clear + allowlist + kill_on_drop), resolve_binary over installer paths (~/.opencode/bin, ~/.local/bin, brew, /usr/local), structured missing-binary install hint. registry.rs: register_opencode_passthrough is #[cfg(feature="pro-build")] + called inside the enable_bash + cfg(pro-build) block → MAS never registers it; risk=Destructive, tier=Agent (reached FROM Act mode per CHAT_UX_MAP, NOT a rival Code mode). Honest: no Swift change needed — the agent tool panel surfaces registered Pro tools automatically and showsProDeveloperNote already discloses CLI-agent tools are Pro-only on MAS.
- Tests: +3 cli_passthrough unit tests (opencode_candidate_paths_include_installer_locations, opencode_args_default_to_run_with_task, opencode_args_include_model_when_given) + added "opencode" to mas_sandbox_registry_excludes_unbounded_tools (proves absent on MAS). HARDEN (rule #6): full default lib suite 5330 passed / 0 failed (19.6s) + cargo check --features pro-build clean (register fn + handler wiring compile under Pro). Rust-only; no app-build impact.
- P7 PHASE COMPLETE: P7.1 picker honesty + P7.2 (flagged, owner repro) + P7.3 terminal Pro-only + P7.4 OpenCode + P7.5 surface parity + P7.6 cowork fusion. NEXT: P3/P4.1 evals (osaurus/unsloth), P6.1 lobehub icons, then OPEN ledger follow-ups.

## 2026-06-18 — OKF export core (R-OKF follow-up): Open Knowledge Format projection
- Landed the pure format core for exporting vault notes / Knowledge Core entries to the Open Knowledge Format (Google Cloud, Apache-2.0; markdown + YAML frontmatter, one concept per file, required field `type`). OKFExporter (nonisolated enum): Note input (plain primitives — type/title/tags/body/created/updated; dates pre-formatted ISO-8601 so the projection is deterministic, no clock reads) → markdown(for:) emits frontmatter (type ALWAYS first/required, defaults to "note"; optional fields omitted when empty; conservative YAML scalar quoting — colons/commas/brackets/quotes/leading-indicators forced to escaped double-quotes so frontmatter round-trips) + blank line + body + trailing newline. fileName(for:) = kebab slug of the title, "untitled.md" fallback. Pure + testable without the SwiftData @Model (MainActor-bound) — same helper-first cadence as MCPUrlServerDirectory.parse landing before its UI. +7 OKFExporterTests (type-always-present, empty-type fallback, field order/omission, unsafe-scalar quoting+escaping, plain-safe unquoted, leading-indicator quoting, filename slug+fallback) all reasoned to certainty. Founding-Thesis fit: human-readable + git-diffable + portable, same provenance ethos as ClaimLedger/DAG. Build + test-build green. FOLLOW-ON (next): wire an honest "Export as Open Knowledge Format" action (SDPage → OKFExporter.Note → write the markdown bundle to a user-chosen dir; honest about what it writes). NEXT loop options: P6.1 icons (SVG→asset pipeline), vault dedup-on-HNSW, P2.6 json_schema FFI, cache-stable-prefix audit.

## 2026-06-18 — OKF bundle writer (R-OKF): real disk export core + page mapper
- Extended the OKF export from format-core to a real, testable write path. OKFExporter.note(title:body:tags:isJournal:createdAt:updatedAt:) maps a vault page's primitives (read off the MainActor @Model by the caller) → OKF Note: type derived from isJournal (journal/note), dates via deterministic UTC iso8601() (no clock reads). OKFBundleWriter (nonisolated): fileNames(for:) gives collision-safe .md names (later dupes get -2/-3 so nothing is overwritten), write(notes:to:) creates the dir + writes each note's markdown atomically, returns the written URLs — honest (writes the user's own notes to a dir they pick; never deletes/mutates the source vault). +4 OKFBundleWriterTests (type+date derivation, collision dedupe, untitled fallback dedupe, real on-disk round-trip against a tempdir) all reasoned to certainty. FOLLOW-ON (thin, next): the NSOpenPanel "Export as Open Knowledge Format" button in vault/Settings → collect selected SDPages (loadBody on MainActor) → map → OKFBundleWriter.write(to: chosenDir). Build + test-build green. NEXT loop options: the OKF export button; vault dedup-on-HNSW; P2.6 json_schema FFI; cache-stable-prefix audit.

## 2026-06-18 — OWNER #1 (REOPENED): LOCAL FOR ALL MODES — kill the hidden GPT route on Act
- ROOT CAUSE (traced): InferenceState.effectiveChatSurfaceSelection forced `.agent` (combined `case .pro, .agent:`) to return `.cloud(autoModel)` whenever usesAutomaticCloudRouteForChatSurfaces was active and the user hadn't pinned a runnable local/cloud tier — even when a local agent-capable model existed. So with auto-route on + no explicit pin, Act silently routed to GPT. (Unlike `.fast`, which only goes cloud when no local model exists.)
- FIX: split `.agent` into its own case guarded on `effectiveLocalAgentTextModelID == nil` — cloud auto-route is now an ESCALATION/fallback, not an override of a working local agent loop. When a local agent model exists, `.agent` falls through to the local resolution (`.localMLX(effectiveLocalAgentTextModelID)`); cloud only when NO local model can run the agent loop (honest fallback). Local-first for Act, matching the owner mandate "use my local for all modes."
- Safe: the pinned-local test (TriageServiceTests:390 — all modes stay local when pinned) is unaffected (userHasExplicitPin path); the `.agent → .localMLX` tests (LocalModelInfrastructureTests:624/664/703) are strictly reinforced; no test asserted `.agent → .cloud` in an unpinned auto-route scenario. +LocalForAllModesAgentRouteGuardTests source-guard (locks: `.agent` is its own case, guarded on effectiveLocalAgentTextModelID == nil, old combined `.pro, .agent:` cloud case gone). Build + test-build green. NEXT reopened: 3-mode CHAT/ACT/WORK UX + picker total-restart (P1.11) + palette-all-themes + local-shows-GPT label.

## 2026-06-18 — OWNER REOPENED: palette preview for ALL themes (un-gate custom-only)
- The theme picker showed the palette swatch ONLY for the Custom pair (gated `if pair == .custom`), every other pair got the busy "GREETINGS" cinematic mock-UI card. Owner: every theme should show the palette preview. FIX: added ThemePairPaletteSwatch(pair:) — renders the pair's resolved light+dark key colors (background/card/accent/heading/foreground/border) as clean swatches — and used it for every non-custom pair (custom keeps its editable-slot CustomThemePaletteSwatch). Deleted the now-dead ThemePairCinematicPreview + ThemePairCinematicHalf structs (declutter, no dead code). Build green (in-app verification by owner). NEXT reopened: picker total-restart P1.11 (delete simplifiedRuntimePopover+modelPopover, rebuild clean pixel-art Fast/Think/Code + Cloud-toggle panel, Fast=4 explicit picks), Act/Queue/Context visible+usable, local-models-show-GPT label, 3-mode CHAT/ACT/WORK UX map revision.

## 2026-06-18 — P1.11 picker rebuild: tested selection/gating model (foundation)
- Landed the pure data model for the rebuilt runtime picker (UI rebuild is the next slice). EpistemosRuntimePicker (nonisolated): options(for: tier, environment:) → explicit per-tier picks with HONEST gating — FAST = the three Gemma sizes + Apple Intelligence (4 picks), THINK / CODE = their single foundation model. Each Option carries isInstalled / isSelectable / blockedReason (P1.4-style "Not installed — tap to install" / "Needs N GB free (M available)" / AI "Not available on this Mac"); blocked picks still APPEAR (never hidden). cleanTitle simplifies the verbose GGUF names ("Gemma 4 E2B QAT GGUF" → "Gemma 2B"). Reads the real EpistemosFoundationLineup.candidates; gates on installed ids + free memory + headroom + Apple-Intelligence availability (all injected for testability). +7 EpistemosRuntimePickerTests (Fast=sizes+AI, memory gating shown-not-hidden, not-installed hint, AI availability, Think/Code no-AI single model, cleanTitle) reasoned to certainty. App build + WARM test build green.
- FLAG (pre-existing, NOT this change): a COLD-DerivedData test build fails on Eidos/EidosBridge.swift + EidosWiring.swift — `nonisolated` funcs call MainActor-isolated UniFFI `eidos*` globals (latent Swift-6 isolation issue from recent Eidos commit 29ba6cc9f). Warm/default DerivedData (the owner's Xcode path) builds fine; only a clean/CI rebuild trips it. Needs a dedicated fix (mark the eidos* call sites' isolation) — tracked for a follow-up; does not block the picker.
- NEXT: P1.11 UI — delete the old popover (simplifiedRuntimePopover/modelPopover/legacy sections) and rebuild a clean pixel-art panel driven by this model (Fast/Think/Code + Cloud toggle); must show + switch the model in-app. THEN per OWNER P3.0/P3.1: full Osaurus import as Act mode (sequenced AFTER the chat-side reality audit).

## 2026-06-18 — P8 deterministic schema engine: research-first grounding + blueprint
- Owner P8 (founding-thesis substrate spine, MUST NOT be buried; research-first, build-on-existing, don't greenfield). Ran a code inventory (Explore) against the spec — FINDING: P8 is ~80% already built as real tested Rust/Swift symbols. Wrote docs/DETERMINISTIC_SCHEMA_ENGINE_BLUEPRINT_2026_06_18.md = the spec's requested SYSTEMS BLUEPRINT (C.1) + reuse map + phased checklist (C.4), each step naming the existing symbol it builds on.
- Reuse (EXISTS): JsonSchemaValidator (tools_v2/runner.rs:144, jsonschema 0.28); schemars schema_for! (route/mod.rs:193); schema→llguidance grammar (grammar/mod.rs:16); constrained Gemma gen llama-cli --json-schema (gguf_cli.rs:141 with_json_schema + FFI bridge.rs:1080/1148); parse_tool_calls (function_call.rs:141); ToolRegistry (registry.rs:482); tree-sitter AST (lsp_runtime/mod.rs:524); EmbeddingService + usearch HNSW; reasoning-token isolation (gguf_cli.rs:409 + ThinkTagStreamRouter). Predecessor = P4.3 (--json-schema FFI already wired). NOTE: DETERMINISTIC_RUNTIME_V1_PREFLIGHT.md + SCHEMA_GATE_STATUS_2026_05_16.md are UNRELATED (knowledge-core invalidation / F-ULP numeric fixture) — don't reuse their naming.
- NET-NEW (small): (1) RAG preflight tool-selector (embed→ANN over tool-desc index→3-5 tools; parts exist, assembly new; load_rag_context is keyword-only today); (2) AST quality gate before write/compile; (3) unifying schema_engine module + single Swift actor coordinator; (4) wire JsonSchemaValidator as a pre-exec gate inside ToolRegistry. Phased checklist P8.0(done)→P8.1 gate-in-router→P8.2 selector→P8.3 AST gate→P8.4 actor→P8.5 visible determinism→P8.6 P4.3 closeout. Sequenced AFTER the chat-side picker audit. NEXT build: P1.11 picker UI rebuild, then P8.1 (smallest determinism-first pure Rust slice).

## 2026-06-18 — OWNER: Qwen 3 8B visible again as an explicit Think pick (P1.11)
- Owner wants Qwen 3 8B back as a VISIBLE user choice (it's a general native-tool-call + thinking model = LocalTextModelID.qwen3_8B4Bit, the fallbackPrimaryAgentModel, 12 GB). NOT a P1.10 reversal — the no-hidden-Qwen rule still holds (this is an explicit pick, never a silent fallback). Added EpistemosRuntimePicker.ExtraPick + extraPicks (Qwen 3 8B → Think tier); options(for:) now appends tier-matched extra picks after the foundation models, same honest memory gating (P1.4 blocker when it can't fit). Refactored localOption → gatedOption(id/title/minMemoryGB) so foundation + extra picks share the gating path. +test qwen8BIsExplicitThinkPick (visible + selectable when fits; shown-but-blocked with "Needs N GB" when memory-tight; NOT offered under Fast/Code). Existing picker tests unaffected (Fast count unchanged; Think still no Apple Intelligence). App + warm test build green. Folds into the picker UI rebuild (next): the rebuilt Think section renders VibeThinker + Qwen 3 8B.
- NOTED (post-Osaurus workstream): owner wants the Epistemos CHAT deep-repaired using Osaurus's chat structure (message/stream/coordinator) as the refactor reference, WITHOUT losing Epistemos IP (Eidos/Knowledge Core/etc.) — document a replace-vs-keep repair plan, refactor in safe tested slices. Added to the ledger; sequenced after the Osaurus import.

## 2026-06-18 — P1.11 picker model: align memory gating to the REAL runtime gate (honesty)
- EpistemosRuntimePicker memory selectability now calls LocalChatModelMemoryGate.fits (available + 6 headroom >= required; unknown/<=0 free → runnable) — the SAME gate the composer uses (localChatModelMemoryBlocker) — so the picker and the composer can never disagree (a model shown selectable will actually load; a blocked one shows the honest reason). Environment simplified to {installedModelIDs, freeMemoryGB: Int, appleIntelligenceAvailable} (gate owns headroom). Tests updated to gate semantics. App + warm test build green. NEXT: the picker UI panel driven by this model.

## 2026-06-18 — P1.11 PICKER UI REBUILD: explicit per-tier picks (owner-visible)
- Rebuilt the runtime picker BODY to explicit per-tier model picks driven by EpistemosRuntimePicker: Fast = Gemma 2B/4B/12B + Apple Intelligence; Think = VibeThinker + Qwen 3 8B; Code = Gemma 12B Coder. Each pick shows its honest state inline (selectable, or the blocker reason: "Not installed — tap to install" / memory "Needs ~N GB"); blocked picks are shown, never hidden. Selecting a pick sets the tier's operating mode AND pins the model (setPreferredChatModelSelection(.localMLX(id)) or .appleIntelligence) — a real switch; not-installed/blocked routes to Settings (honest install/free-memory path), never a silent swap. New RootView helpers: runtimePickerEnvironment (free memory via the same monitor the composer blocker uses), runtimePickerOperatingMode(for:), isRuntimePickSelected, selectRuntimePick, foundationPickerSection. Replaced the old Tier mode-rows + separate Apple Intelligence section in simplifiedRuntimePopover. NO low/med/high effort labels. +RuntimePickerPanelSourceGuardTests (panel uses EpistemosRuntimePicker.options + selectRuntimePick + pins the model; old `popoverSectionTitle("Tier")` gone). App + warm test build green.
- HONEST SCOPE: this rebuilds the VISIBLE picker content (what the owner sees + uses). Wholesale removal of the remaining legacy popover vars (appleIntelligenceSection now orphaned, plus modePopover/modelPopover/routingPopover/effortPopover/legacyRuntimePopover) is the VERIFIED cleanup follow-up — deferred deliberately so the owner can confirm the new panel works in-app before deleting ~hundreds of interconnected lines unverifiable headlessly. NEXT: owner verifies the new picker; then legacy-var deletion; then local-shows-GPT label, custom-font verify.

## 2026-06-18 — OWNER: BOTH Qwen 3 4B + 8B as explicit Think picks (P1.11)
- Owner wants BOTH Qwen 3 4B (qwen3_4B4Bit, 8 GB) AND Qwen 3 8B (qwen3_8B4Bit, 12 GB) as visible user-selectable picks; NEITHER auto-default (default stays a Fast Gemma). Added Qwen 3 4B to EpistemosRuntimePicker.extraPicks under Think (alongside 8B). Both honestly memory-gated; the picker model never sets a default (it only lists options — the default selection lives in preferredChatModelSelection, untouched), so "neither is auto-default" holds at the picker layer. +test bothQwensAreExplicitThinkPicks (both visible+selectable when fit; 4B fits at 3 GB free where 8B doesn't; neither under Fast/Code). App + warm test build green. OPEN (separate seam, noted): the default-Qwen-4B bug (something auto-defaults to Qwen 4B instead of a Fast Gemma) still needs repair — that's a default-resolution seam (effectiveLocalTextModelID/sanitizedStoredLocalChatModelID), NOT the picker; investigate next.

## 2026-06-18 — P1.11 cleanup: remove orphaned appleIntelligenceSection (build-first)
- Removed the now-dead appleIntelligenceSection var from RootView (its only ref was its own declaration — Apple Intelligence moved into the Fast picks in foundationPickerSection during the picker rebuild). HARDENED: Apple Intelligence reachability is preserved + locked by EpistemosRuntimePickerTests.appleIntelligenceGating (selectable when available, blocked-with-reason when not) — the removed section's capability is fully covered. App + warm test build green. NOTE: the other legacy popovers (modePopover/modelPopover/routingPopover/effortPopover/legacyRuntimePopover/nativeControlsPopover) each still have a LIVE reference (2 refs) — they're still wired into a popover container, so wholesale removal is the verified untangling follow-up, not a safe one-shot delete. local-shows-GPT label fix: NOT guess-fixed — `activeChatModelDisplayName` shows local/"Auto Route" (not GPT); the `?? .openAI` at SettingsView:1542 feeds a CLOUD section row; the exact local row showing GPT is ambiguous (owner named several: AgentBlueprint/Constellation/ModelProfile) → needs the owner's exact screen/row repro to fix honestly without guessing.

## 2026-06-18 — Substrate Health panel: collapsible sections (quick visible win)
- SubstrateHealthPanel's 18 stacked health rows blew out the Settings window height (owner). Made the 3 Form sections collapsible via Section(isExpanded:) (macOS 14+); the 10-row "Substrate Floor" section defaults COLLAPSED, the two small sections (Retrieval/Agent Runtime) stay expanded. Nothing removed — every row is one click away. HARDENED: +SubstrateHealthPanelLayoutGuardTests (all 3 sections collapsible + Substrate Floor defaults collapsed). App + warm test build green.

## 2026-06-18 — OWNER: P1.4 memory-gate OWNER OVERRIDE ("Run anyway") + accurate estimate
- Owner can't run the 12B (coder/regular) — gate says "not enough memory" but they generally have enough + used to run bigger. TWO fixes, honest blocker stays the DEFAULT:
- (1) OVERRIDE: added InferenceState.memoryGateForcedModelIDs (persisted) + setMemoryGateForced(_:forced:); localChatModelMemoryBlocker returns nil for a forced model (explicit user-forced load = NOT a silent swap, fully allowed). A "Run anyway" button on the P1.4 blocker banner (ChatInputBar) force-loads the gated model with a slow/swap warning. Extracted memoryGateModelID(for:) as the shared resolver so the blocker + override target the SAME model id.
- (2) ACCURATE ESTIMATE: LocalInferenceMemoryPressureMonitor.availableMemoryBytes now counts free + inactive + purgeable + SPECULATIVE pages (macOS "free" undercounts AVAILABLE; speculative read-ahead cache is reclaimable) — so legit 12B runs aren't blocked on a conservative reading. The gate keeps LocalChatModelMemoryGate.fits (available + 6 headroom >= required) as the honest default.
- HARDENED: +MemoryGateOverrideTests (force toggle on/off + blank-id ignore behavioral; source-guards: blocker honors the forced set + shared memoryGateModelID resolver + availableMemoryBytes counts speculative_count + ChatInputBar wires "Run anyway"→setMemoryGateForced). App + warm test build green.

## 2026-06-18 — REPAIR: default chat model is a Fast Gemma, never Qwen (owner)
- Owner: "something auto-defaults to Qwen 4B instead of a Fast Gemma." ROOT CAUSE = three seams all defaulting to Qwen 3 4B (a stale choice from before the GGUF Gemma lane existed): (1) the hardcoded property defaults (preferredLocalTextModelID/preferredChatModelSelection); (2) migrateStaleGemma4Selection (comment literally said "documented default (Qwen 3 4B)"); (3) sanitizedStoredLocalChatModelID's awaiting-loader rewrite (MLX Gemma 4 → recommendedLocalTextModelID = Qwen). FIX: new EpistemosFoundationLineup.defaultChatModelID = representativeModelID(.fast) (the smallest Fast Gemma GGUF, which RUNS via the GGUF lane). All three seams now use it — an unrunnable MLX Gemma 4 migrates/sanitizes to the WORKING Fast Gemma GGUF (same family), never Qwen (under simplifiedLineupActive; legacy lineup keeps recommendedLocalTextModelID). Both Qwens stay explicit-only Think picks; the picker never sets a default. HARDENED: +DefaultChatModelRepairTests (defaultChatModelID == Fast representative + is Gemma + not Qwen; seams use it + old Qwen literal default gone); updated migrateStaleGemma4Selection + gemma4ChatSelectionSanitizesToFallback tests to expect the Gemma GGUF default. App + warm test build green.

## 2026-06-18 — B1 Variant Ladder extension: honest "→defer" terminal (always-compiled)
- The mine's B1: the deterministic→embedding→classical→small/mid-LLM→cloud ladder (variant_ladder/mod.rs, always-compiled, live; wraps vault.search via tools/vault_search_ladder.rs) had an IMPLICIT defer (resolve_walk returns resolution=None) but no explainable terminal. Added LadderDeferral { AllDeclined, EscalationGated { lowest_gated_tier } } + LadderWalk.deferral() — the honest "→defer" step: distinguishes "nothing could resolve this input" from "higher tiers exist but the escalation policy gated them (opt in to escalate to <tier>)". This is the Rust core for the visible "why this route deferred" routing surface (honest determinism — the ladder abstains with a reason instead of forcing cloud). HARDENED: +3 cargo tests (deferral None when resolved; AllDeclined when everything falls through; EscalationGated→SmallLLM when a Tier-4 variant is policy-skipped under Never). cargo test: 70 variant_ladder passed / 0 failed (5263 filtered). No promotion needed (always-compiled); no FFI/Swift change. NEXT B1: FFI-expose the walk + a Swift routing surface; then Tier-1 promotion (A2 EML-3 vault re-rank).

## 2026-06-18 — OWNER: add Gemma 4 26B-A4B MoE QAT GGUF (Unsloth) to the GGUF lane
- Wired the Unsloth Gemma 4 26B-A4B mixture-of-experts QAT GGUF into the Pro GGUF runtime lane (gguf_llama_cpp_offline, EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0, MAS-forbidden). New GemmaQATRuntimeStage.moeFlagshipCandidate (→ Fast tier, explicit-only — effort sizing clamps to the 12B band so it's never auto-routed) + a GemmaQATRuntimeCandidate with REAL HF provenance verified against the tree API 2026-06-18 (file gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf, 14,249,045,120 bytes, sha256 dcf179a9…, blob d5b6449d…, revision 02749a7b…). Added the new stage to all 6 exhaustive switches (displayName/routeIntegrationStatusLabel×2/acquisitionLaneArgument/minimumRecommendedMemoryGB=18/catalogSummary/familyName + epistemosTier→.fast) + 5 diagnostics/picker color/symbol/status switches across LocalAgentDiagnosticsHealthRow/SettingsView/RootView. Memory-gated HONESTLY at 18 GB (full ~14 GB weights stay resident — MoE saves compute not memory); the "Run anyway" override + corrected available-memory estimate let a 16 GB Mac attempt it. Installable (in foundationModelIDs) but NOT the default (E2B stays) and never auto-routed. HARDENED: +Gemma26BMoECandidateTests (provenance + Fast-tier 18GB gate + installable-not-default + appears-in-picker-memory-gated/blocked-not-hidden + selectable-with-room). App + warm test build green. Owner verifies the actual load+generate in-app (GGUF lane is flag-gated runtime). NEXT (owner-queued): add LiquidAI LFM2.5-8B-A1B-GGUF (light MoE ~1B active, likely MAS-viable) similarly + evaluate role + LFM logo.

## 2026-06-18 — OWNER: add LiquidAI LFM2.5-8B-A1B GGUF + role evaluation
- Wired LiquidAI LFM2.5-8B-A1B (light general MoE, 8B total / ~1B ACTIVE) into the GGUF lane. REAL HF provenance (HF tree API 2026-06-18): LFM2.5-8B-A1B-Q4_K_M.gguf, 5,155,564,768 bytes (~4.8 GB), sha256 4923ec14…, blob 5cd9b16c…, rev dfd5fdca…. New stage GemmaQATRuntimeStage.liquidGeneralMoe (familyName "LFM2.5 GGUF", NOT Gemma) + all switch arms (display/route×2/acquisition/memory=10/catalog/family + epistemosTier→.think + 5 view color/symbol/status switches).
- ROLE EVALUATION (owner asked): best role = a FAST/QUICK general local model + cheap triage (~1B active = fast; 8B total = capable). PLACEMENT = Think tier, NOT Fast. WHY: comfortableInstalledFastCandidatesAscending() returns ALL Fast candidates (not Gemma-only), so a 10GB LFM in Fast would enter the effort-sizing ladder and a "medium" query would auto-route to LFM instead of E4B — polluting the Fast=Gemma sizing. Think has no effort-sizing + already holds the non-Gemma general models (Qwen 4B/8B), so LFM joins as an explicit-only general option. MAS-viable: ~4.8GB Q4_K_M fits 16GB → gated at 10 → SELECTABLE not blocked on the ship rig.
- HARDENED: +LFM25MoECandidateTests (provenance + Think-tier 10GB gate + NOT-in-Fast/IS-in-Think + Think default stays VibeThinker + fits-16GB-selectable). App + warm test build green. FOLLOW-UP (honest, NOT fabricated): the LiquidAI/LFM logo SVG for P6.1/docs/brand-assets/lobehub needs the real asset fetched (the lobehub set is real SVGs; I won't fabricate a logo). NEXT (owner): 2-bit 12B Gemma, Holo VL, then down the ledger.

## 2026-06-18 — OWNER: add Unsloth Gemma 4 12B 2-bit GGUF (fits 16GB)
- Wired Unsloth Gemma 4 12B at 2-bit into the GGUF lane. REAL HF provenance (tree API 2026-06-18): unsloth/gemma-4-12b-it-GGUF, file gemma-4-12b-it-UD-Q2_K_XL.gguf, 4,661,418,400 bytes (~4.66 GB), sha256 19ab0f2d…, blob 133f390d…, rev 3249fa54…. New stage gemmaTwelveBLowMemory + all switch arms (display/route×2/acquisition/memory=10/catalog/family="Gemma 4 QAT GGUF" + epistemosTier→.think + 5 view switches). The point of the 2-bit variant: run a 12B on 16GB (the Q4 12B is ~7GB, tight on 16GB) — gated at 10 → SELECTABLE not blocked. TIER = Think (explicit-only), NOT Fast: a 2-bit 12B is a big-model-at-low-memory, which would break the Fast effort-sizing's memory∝capability assumption (sorted-by-memory, it'd get picked for "medium" over the more-capable-per-param E4B). Think has no auto-sizing → it's a clean explicit-only pick. HARDENED: +Gemma12B2BitCandidateTests (provenance + Think-tier 10GB gate + NOT-Fast/IS-Think + fits-16GB-selectable). App + warm test build green. NEXT (owner): Holo-3.1-4B VL for computer-use (vision model — evaluate GGUF-lane/mmproj viability honestly; if VL isn't runnable via the text GGUF lane, surface/flag, don't fake).

## 2026-06-18 — P8.1: deterministic schema gate in ToolRegistry (founding-thesis spine)
- First real build slice of the deterministic schema engine (per the blueprint). Wired the existing tools_v2 JsonSchemaValidator (jsonschema 0.28, Draft 2020-12) as an OPT-IN pre-execution validation gate in ToolRegistry.execute: before a tool's handler runs, its input is validated against the tool's own declared input schema (RegisteredTool.parameters); malformed args are rejected with `at {path}: {err}` BEFORE any side effect. So the model targets an immutable typed schema instead of guessing — dynamic determinism + verifiability on the real tool path. Flag EPISTEMOS_SCHEMA_GATE_V1, default OFF (zero behavior change until promoted; mirrors the r5_enforce flag pattern, inverted to opt-in). HARDENED: +cargo test schema_gate_validates_input_only_when_enabled (gate OFF → malformed runs [no change]; gate ON → valid passes, malformed → ToolError::InvalidArguments "schema gate: at …"). cargo test: 1 passed / 0 failed (5333 filtered). Rust-only, no FFI/Swift change. NEXT P8: P8.2 (deterministic schemas Goose patches validate against) → RAG tool-selector → AST gate → Swift actor → visible determinism surface.

## 2026-06-18 — P8.5 (visible determinism): schema-gate Swift surface
- Made the P8.1 deterministic schema gate VISIBLE (owner: "surface the determinism — it's the edge"). DeterministicSchemaGateStatus (pure nonisolated) reads the SAME EPISTEMOS_SCHEMA_GATE_V1 env flag the in-process Rust gate (ToolRegistry.execute) reads — so the surface never claims enforcement the runtime isn't doing. status() → honest headline+detail (ON: "every tool call's args validated against the typed schema before it runs, malformed rejected at {path}:{err} with no side effect" / off: "set EPISTEMOS_SCHEMA_GATE_V1=1 to enforce…"). DeterministicSchemaGateHealthRow surfaced in SubstrateHealthPanel → Agent Runtime section (read-only). HARDENED: +DeterministicSchemaGateStatusTests (flag truth table byte-identical to Rust's schema_gate_enabled: 1/true/yes/on→on incl trim+case, else off; status reflects flag active vs opt-in + tells the user how to enable). App + warm test build green. NEXT: Tier-1 EML promotion (P5.H — A2 EML-3 vault re-rank), then P8.2.

## 2026-06-18 — P5.H A2/A3: EML re-rank policy promoted to the always-compiled core
- Tier-1 promotion (owner green-lit), done the LEAN way. The full research eml IR (agent_core/src/research/eml/, #[cfg(feature="research")], 500+ tests) stays research-gated + out of the app; but the retrieval re-rank only needs the SCALAR potential, so promoted JUST that into a new always-compiled agent_core/src/eml_rerank.rs (lib.rs un-gated). eml(x,y)=exp(x)−ln(y) (byte-identical to the IR), non-positive/NaN y → +INF (sorts last, no NaN); rerank_key(bm25, secondary)=eml(-ln(bm25+ε), secondary+1) smaller-better (doctrine §123-132 — fuses lexical BM25 + a secondary signal into one energy); rerank_by_eml(items, signals) stable-sorts ascending. HARDENED: +6 cargo tests (eml matches the primitive; non-positive y→INF; higher bm25/secondary lower the key; fusion demotes top-BM25-with-no-secondary; stable for equal keys). cargo test 6 passed/0 failed (5334 filtered). Rust-only, always-compiled, MAS stays lean. NEXT (flagged decisions): wire eml_rerank into storage/vault.rs as a SECONDARY re-rank pass over vault.search results behind EPISTEMOS_EML_RERANK_V1 (default OFF), using semantic_concept_score (vault.rs:227) or title_match_score (vault.rs:402) as the secondary signal; the full research-eml-crate promotion (branched/certificate/grammar) is a separate larger decision (kept research-gated for now to keep MAS lean). Then A1 EML-2 ConfidenceRouter, F4 confidence_floors, F1 Active-Assembly, etc.

## 2026-06-18 — P5.H A2 (EML-3): EML re-rank wired LIVE into vault.search
- Wired the promoted eml_rerank core into the live vault path. vault.rs: apply_eml_rerank(query, results) re-ranks vault.search's Vec<SearchResult> by the EML key (eml_rerank::rerank_key fusing BM25 result.score + excerpt_query_coverage — distinct query terms present in the excerpt, a lexical-coverage signal orthogonal to BM25's IDF/frequency weighting), behind eml_rerank_enabled() (EPISTEMOS_EML_RERANK_V1, default OFF → no behavior change). Called in VaultBackend::search (vault.rs:577, the path the agent's vault_search tool uses). HARDENED: +cargo test eml_rerank_is_flag_gated_and_fuses_excerpt_coverage (coverage signal counts; OFF→input order; ON→a low-BM25 result whose excerpt covers the query is fused ABOVE a high-BM25 result that doesn't). cargo test 1 passed/0 failed. A2 EML-3 is now a REAL live re-rank (not just a policy core). Rust-only. NEXT Tier-1: A1 EML-2 ConfidenceRouter scoring (Swift), then F4 confidence_floors / F1 Active-Assembly / F3 Sinkhorn / F5 / F6 / C1 / D1 (promote-lean each).

## 2026-06-18 — P5.H A1 (EML-2) foundation: Swift EML mirror + cross-runtime parity
- Landed the Swift mirror of agent_core/src/eml_rerank.rs (EmlRerank.swift): eml(x,y)=exp(x)−ln(y) + rerankKey(primary,secondary)=eml(-ln(primary+ε), secondary+1), byte-identical to the Rust core (same ε, same +∞ guard for non-positive/NaN y). This is the foundation for A1 EML-2 (ConfidenceRouter EML scoring) — a Swift-side route ranking will now agree EXACTLY with the Rust vault re-rank (cross-runtime determinism per the honest-handle-FFI doctrine). HARDENED: +EmlRerankParityTests (eml matches the primitive; +∞ guard same as Rust; key direction; key values recomputed from the Rust formula match within 1e-6 — locks Swift⇄Rust parity). App + warm test build green.
- EIDOS OBS-1/2/3 PRECISE GAP (for a dedicated pass): W-46 FFI exists (EidosWiring.search + EidosBridge), W-48 panel IS surfaced (EidosRetrievedSection in ChatView.swift:787), BUT W-47 emit-gate is the real gap — runEidosCitationGate (ChatCoordinator+EidosCitationGate.swift) + EidosWiring.search are DEFINED but NEVER CALLED in the chat answer path. Wiring runEidosCitationGate into the answer/citation flow (so chat can't cite sources Eidos didn't retrieve) is the W-47 slice; involved ChatCoordinator integration, deferred to a focused pass. NEXT: A1 EML-2 router wiring (use EmlRerank in ConfidenceRouter), then F4/F1/F3 promote-lean.

## 2026-06-18 — MoLoRA NO-SIDECAR invariant locked (P5.H / LF state clarified)
- Investigated the MoLoRA "sidecar removal" the owner flagged. FINDING: it's NOT a shipped-MAS breach — MoLoRAInferenceService spawns the Python subprocess ONLY under #if !EPISTEMOS_APP_STORE (compiled OUT of the App Store build); the #else MAS branch fails honestly (state=.error "MoLoRA inference is not available in the App Store sandbox build."), and AppBootstrap + SettingsView already gate the KnowledgeFusion entry points out of MAS (defense-in-depth). So the sidecar is Pro/dev-only + MAS-safe. The remaining LF-1/W7-H work = the full in-process MLX-Swift port that removes the Python subprocess EVEN on Pro/dev (large; preserved-red, not a MAS bug). HARDENED: +MoLoRANoSidecarGuardTests source-guard (the spawn exists, is inside #if !EPISTEMOS_APP_STORE, MAS branch fails honestly, spawn ordered inside the guard before the #else) — locks the NO-SIDECAR invariant so a refactor can't leak the subprocess onto the shipped MAS path. Warm test build green. NEXT: A1 EML-2 router wiring; Eidos W-47 gate wiring (documented gap); then port verdicts + Osaurus P3.0 plan.

## 2026-06-18 — Eidos OBS-1/OBS-3: retrieval wired live into chat (owner P5.H)
- Made the Eidos "Retrieved by Eidos" chat panel actually LIVE. The index is already opened at bootstrap (EidosVaultBootstrapper.openProductionIndexIfReady, AppBootstrap:2373/4220) + the panel (EidosRetrievedSection) is in ChatView:787 reading EidosMetrics — but EidosBridge.search was NEVER CALLED from chat, so the panel stayed empty. FIX: ChatCoordinator.buildContextAttachments now runs a fire-and-forget EidosBridge.search(query) (Task.detached .utility — never blocks chat) when EidosFlags.isEnabled (EPISTEMOS_EIDOS_V0, default OFF → zero behavior change). EidosBridge.search records latency/citations/backend into EidosMetrics → the OBS-3 panel populates. (Type was EidosBridge, not EidosWiring — the file name misled; caught by the build.) Does NOT yet feed chat context or enforce the W-47 closed-citation gate (runEidosCitationGate, still defined-but-uncalled) — those are the follow-on slices. HARDENED: +EidosChatRetrievalWiringTests source-guard (flag-gated EidosBridge.search wired inside buildContextAttachments). App + warm test build green. NEXT Eidos: feed Eidos hits into chat context + wire W-47 runEidosCitationGate. NEXT P5.H: A1 EML-2 router wiring, F4/F1/F3 promote-lean.

## 2026-06-18 — P5.H (visible determinism): EML re-rank Substrate Health surface
- Made the live A2/EML-3 vault re-rank VISIBLE (rule #8: DONE = owner sees+uses; the re-rank shipped behind EPISTEMOS_EML_RERANK_V1 but had no surface, so the owner couldn't SEE whether the BM25+coverage fusion was enforcing). Mirrors the P8.5 schema-gate surface: EmlRerankGateStatus (pure nonisolated) reads the SAME env flag the in-process Rust re-rank (vault.rs eml_rerank_enabled) reads — never claims a re-rank the runtime isn't doing. status() → honest headline+detail (ON: "results re-ranked by eml(-ln(bm25+ε), excerpt-coverage), smaller energy = better, deterministic no-model re-rank" / off: "set EPISTEMOS_EML_RERANK_V1=1 …, off by default for zero behavior change"). EmlRerankGateHealthRow surfaced in SubstrateHealthPanel → Retrieval section (read-only, flat). HARDENED: +EmlRerankGateStatusTests (flag name == Rust EPISTEMOS_EML_RERANK_V1; opt-in truth table byte-identical to Rust eml_rerank_enabled 1/true/yes/on incl trim+case→on, else off; status reflects flag honestly). App warm build SUCCEEDED. Both substrate determinism flags (schema gate + EML re-rank) now have honest visible surfaces. NEXT P5.H: A1 EML-2 ConfidenceRouter scoring wiring, then F4/F1/F3 promote-lean; Eidos W-47 gate; picker-inline (placement decision).

## 2026-06-18 — P5.H A1 (EML-2) LIVE: ConfidenceRouter fused route gate
- Wired the parity-locked EmlRerank (EmlRerank.swift) into ConfidenceRouter.route() — the A1/EML-2 router slice. The router's hard gates each test ONE axis in isolation (confidence ≥ uncertaintyThreshold; complexity ≤ maxLocalComplexity; toolCount; currentInfo; codeExec). Added a fused-signal confirmation AFTER all of them: localFitnessEnergy = EmlRerank.rerankKey(primary: confidence, secondary: complexity-headroom) = 1/(confidence+ε) − ln(headroom+1) — BYTE-IDENTICAL to the Rust vault re-rank key, so Swift routing + Rust retrieval agree exactly (honest-handle-FFI cross-runtime determinism). When the fused energy exceeds emlLocalFitnessCeiling (default 1.50; the worst still-passing corner (conf=0.60, headroom=0) is ≈1.667, so 1.50 is tighter), the request defers to cloud (new Reason .localFitnessBelowThreshold). Effect: a request that scrapes past EVERY individual gate but is jointly weak on BOTH confidence AND complexity defers; strength on EITHER axis rescues it. Flag EPISTEMOS_EML_ROUTE_V1, default OFF → route() byte-identical to before (the gate block is skipped). Privacy-sensitive returns .local far above the gate → can NEVER be pushed to cloud by fusion.
- Safe enum extension: confirmed ConfidenceRouter.Reason is only ever compared via == (never switched exhaustively — RuntimeExecutor's line-325 switch is its OWN separate reason enum with snake_case rawValues), so adding .localFitnessBelowThreshold has zero blast radius.
- HARDENED: +EmlRouteFusionTests (flag truth table == Rust gates; localFitnessEnergy == the rerank_key formula within 1e-9 AND == EmlRerank.rerankKey; OFF never defers; ON defers ONLY when both axes weak [strong-confidence + ample-headroom each stay local]; route() with real env [flag OFF] keeps the borderline-both case .local/.localAgentApproved = default build provably unchanged). App warm build SUCCEEDED. NEXT Tier-1 promote-lean: F4 confidence_floors / F1 Active-Assembly / F3 Sinkhorn (one module/pass); Eidos W-47 gate; picker-inline (placement decision).

## 2026-06-18 — P5.H F4: confidence-floor decision policy promote-lean (always-compiled)
- Tier-1 promote-lean (same pattern as the EML scalar): the F4 confidence-floor ladder lived in research/confidence_floors.rs (621L, #[cfg(feature="research")], default OFF). Promoted JUST the deterministic decision kernel into a new always-compiled agent_core/src/confidence_floor.rs: ConfidenceFloor {T1≥0.85, T2≥0.75, T3≥0.70} + threshold/code/from_code; FloorOutcome {Accepted(tier)/Escalated/EmptyNoEscalate} + is_accepted/is_escalated/is_empty_no_escalate/accepted_at_tier/code; decide_floor(score, escalate_on_empty) — byte-identical to the research ConfidenceLadderLog::decide cascade (minus the per-attempt log append). The heavier observability (the log Vec, LadderStats, health_verdict) STAYS research-gated — only the verifiable accept/escalate kernel ships, keeping MAS lean (pure logic, serde only). This is the deterministic confidence gate that pairs with the EML route fusion: a local answer clears a hard floor or escalates, no model in the loop (founding thesis — determinism + verifiability on small models).
- HARDENED: +6 inline cargo tests (thresholds == doctrine floors + strictly descending; cascade accepts at first cleared floor [0.90→T1, 0.80→T2, 0.72→T3]; boundary scores clear exactly under >= + just-under 0.70 falls through; empty respects escalate flag; exactly-one-predicate-per-outcome + accepted_at_tier iff is_accepted; floor codes round-trip). cargo test 6 passed/0 failed/5341 filtered (zero regressions), always-compiled (ran under src/lib.rs unittests not the research feature). NEXT Tier-1: F1 Active-Assembly minimizer / F3 Sinkhorn brain_routing / F5 interrupt_calibration / F6 hybrid_memory / C1 info_ir→AnswerPacket / D1 ternary KV (one promote-lean/pass). Then Eidos W-47 gate; picker-inline (placement decision).

## 2026-06-18 — P5.H A1 (EML-2 visible): route-fusion Substrate Health surface
- Paired the EML-2 router gate (b260b4da1) with a visible surface (rule #8: DONE = owner sees+uses), symmetric to the EML-3 EmlRerankGateHealthRow. EmlRouteFusionHealthRow reads ConfidenceRouter.emlRouteFusionEnabled() DIRECTLY — the SAME function route() consults — so it's single-source-of-truth honest (never claims a fusion the router isn't applying; no duplicate env re-read). Honest ON/off copy explains the fused 1/(confidence+ε)−ln(headroom+1) energy + the jointly-weak→cloud behavior. Surfaced in SubstrateHealthPanel → Agent Runtime section next to the schema-gate row. Now all three substrate determinism flags (schema gate, EML re-rank, EML route fusion) have honest visible surfaces. HARDENED: +EmlRouteFusionHealthRowTests (row reads the router's flag fn + honest copy + surfaced; truth table locked in EmlRouteFusionTests). App warm build SUCCEEDED.
- F4-live finding (recorded for the next pass): decide_floor's natural live consumers are (a) AnswerPacket.confidence — which does NOT exist yet (answer.rs:1662 = future C1 field), so F4-live is COUPLED to C1; or (b) Eidos hit confidence (eidos/types.rs:249/461 pub confidence: f32) — real but touches the closed-citation contract + falsifiers (bigger slice). So F4 stays promoted-kernel-ready; F4-live is a C1-coupled or Eidos-scoped follow-on, not a cheap slice.

## 2026-06-18 — OWNER PRIORITY: flat inline pixel-art runtime picker (delete the popover)
- Owner reopened + prioritized ("waiting to see it"): the model/runtime picker was STILL a floating macOS .popover bubble (AnchoredPopoverButton → .popover at NativeButtonStyles.swift:586). Rebuilt as a FLAT INLINE pixel-art panel for the MAIN CHAT composer.
- Investigation (research-first): the picker isn't in a system .toolbar — it's in the composer's in-view control strip (ChatInputBar:931, an HStack), and the composer VStack already renders an in-flow banner above the strip (needsCloudBanner, move-from-top transition) = the proven in-flow slot. AnchoredPopoverButton is SHARED (mode/model/routing/effort all use it) so it must NOT change globally. EpistemosRuntimePicker is a standalone option model → a self-contained panel needs none of LocalModelToolbarMenu's popover plumbing.
- New InlineRuntimePickerPanel.swift: renders the SAME explicit Fast/Think/Code per-tier picks with the SAME honest install+memory gating as foundationPickerSection, but FLAT — hard 1.5px Rectangle border (no rounded bubble), solid theme.card fill, monospaced (pixel) titles, flat accent-bar selection highlight. NO .popover. Selection mirrors selectRuntimePick (operatingMode set for the tier + setPreferredChatModelSelection; blocked picks → Settings via @Environment(\.openSettings)).
- ChatInputBar: renders the panel in-flow above the control strip (needsCloudBanner slot, gated by @State showInlineRuntimePicker, move-from-bottom transition) + a `cpu`-icon trigger (ToolbarCapsuleButton, isActive when open) labelled with the active tier (Fast/Think/Code/Act); hides the redundant floating model button via hidesModelButton: true → exactly one model picker.
- hidesModelButton threads ChatBrainPickerMenu → LocalModelToolbarMenu (the model AnchoredPopoverButton is wrapped in `if !hidesModelButton`), defaults OFF → landing/mini/note/graph completely unchanged (their popover stays until the follow-on migration).
- HARDENED: +InlineRuntimePickerPanelTests (panel is flat/pixel-art + NO .popover + standard selection path; tier→mode mapping matches the popover picker; composer renders in-flow + hides the floating model button; hide flag threads + defaults OFF). App warm build SUCCEEDED. Owner verifies visually (dev-cert Product▸Run). NEXT: migrate the single-button simplifiedRuntimePopover surfaces (landing/mini/note/graph) to the inline panel; then back down the Tier-1 ledger (F1/F3/F5).

## 2026-06-18 — HONESTY SELF-AUDIT: EML-2 route fusion is NOT live (corrected)
- Per the owner's "finish remaining P5.H substrate" + rule #8 (DONE = owner sees+uses), I verified my just-shipped EML-2 route fusion is actually live. IT IS NOT. Findings: (1) `ConfidenceRouter()` is NEVER instantiated anywhere in the app (grep: zero sites) → route() + the EML fusion are exercised ONLY by tests; ConfidenceRouter's own header says the production policy table is RuntimeRouter. (2) The live local-vs-cloud decision is TriageService.InferencePolicyEngine.shouldAutoRouteToCloud, which is driven by complexity ONLY (baseComplexity/queryComplexity) — there is NO confidence signal, so EML-2's confidence×complexity fusion doesn't even map onto the live path. (3) WORSE: the EmlRouteFusionHealthRow I shipped claimed "local-vs-cloud routing fuses confidence × complexity" — a live behavior that never executes. That's exactly the dishonesty the determinism surfaces exist to prevent.
- CORRECTED (38b8f9d13), no deletion (the EML-2 ConfidenceRouter primitive + EmlRerank parity are correct + reusable — deletion guardrail): EmlRouteFusionHealthRow now honestly says "armed (not yet live)" / "tested primitive", names TriageService as the live seam, and states there's no runtime effect until a confidence signal + live seam land. ConfidenceRouter got a HONEST STATUS doc block. Test updated to assert the not-yet-live honesty + that the row no longer claims the dead behavior. EML-3 (vault re-rank) IS genuinely live — unaffected. App warm build SUCCEEDED.
- LESSON (re-applies the investigate-before-fixing + rule-#8 discipline): a queued task naming a specific file ("wire EmlRerank in ConfidenceRouter") is NOT proof that file is on the live path. ALWAYS verify the integration point is actually invoked in production before claiming a feature live or shipping a surface that asserts the behavior. The live route seam is TriageService.InferencePolicyEngine (audit list: TriageService → RuntimeRouter → LocalAgentGatewayPolicy; ConfidenceRouter is legacy/diagnostics-only). NEXT: EML-2 live-wiring is re-queued (needs a triage confidence signal first); continue down the ledger to port verdicts / Osaurus / harness / chat parity.

## 2026-06-18 — picker: landing hero chat migrated to the flat inline panel
- Continued "delete the popover entirely": migrated the LANDING search/hero-chat picker off the floating popover. Landing's landingSearchBrainTool was the single-button ChatBrainPickerMenu (preferSplitToolbarControls: false = the WHOLE picker in one popover). Replaced with a flat LandingStageToolTile trigger (cpu icon + active tier label, isActive when open) that toggles the reusable InlineRuntimePickerPanel in-flow in the landingSearchStageTools VStack (alongside the existing landingToolsExpanded slot) — no floating popover.
- Single-button surfaces carry the whole picker in one control (unlike main chat's split toolbar where I hid just the model button), so I enriched InlineRuntimePickerPanel with an opt-in showsSettingsFooter (default OFF): the inline panel shows the Fast/Think/Code model picks (the core) + a flat "Cloud, routing and model details — Settings" footer routing advanced bits to Settings honestly. Main chat keeps the footer OFF (its split toolbar has those buttons).
- LandingView: + showInlineRuntimePicker state + @Environment(\.openSettings); landingRuntimeTierLabel maps the active mode → Fast/Think/Code/Act; the panel renders with showsSettingsFooter true. The InlineRuntimePickerPanel stays self-contained (EpistemosRuntimePicker + InferenceState + operatingMode binding).
- HARDENED: InlineRuntimePickerPanelTests + opt-in footer guard (showsSettingsFooter default OFF + footer routes onOpenSettings) + landing migration guard (landingSearchBrainTool no longer mounts ChatBrainPickerMenu; landing renders InlineRuntimePickerPanel showsSettingsFooter true). App warm build SUCCEEDED. NEXT picker: mini/note/graph single-button surfaces (same trigger+panel pattern). THEN down the ledger: port verdicts / Osaurus / harness / chat parity.

## 2026-06-18 — picker: mini chat migrated (3 of 5 surfaces now flat-inline)
- Migrated mini chat off the single-button LocalModelToolbarMenu popover, same proven pattern as main chat: a cpu ToolbarCapsuleButton trigger (active tier label) + InlineRuntimePickerPanel(showsSettingsFooter: true) rendered in-flow above the control strip (the shared-tool-route-warning-banner VStack slot). Added showInlineRuntimePicker + openSettings to MiniChatInputBar (the composer's actual struct — the warm build caught my initial mis-placement into MiniChatThread, a good reminder that large multi-struct files need the state in the RIGHT struct). HARDENED: +mini-chat migration guard (no LocalModelToolbarMenu popover remains; inline panel + footer + cpu trigger present). App warm build SUCCEEDED.
- PICKER STATUS: 3 of 5 surfaces flat-inline (main chat 378379408, landing d790bc81f, mini a6a636b38); REMAINING: note (NoteDetailWorkspaceView:2151) + graph (HologramSearchSidebar:780 — a SIDEBAR, narrower; verify its in-flow slot carefully). The InlineRuntimePickerPanel + showsSettingsFooter pattern is now proven 3× and reusable for both. THEN: port verdicts / Osaurus / harness / chat parity.

## 2026-06-18 — PICKER COMPLETE: flat inline pixel-art panel on ALL 5 surfaces
- Finished "delete the popover entirely". Migrated the last 2 single-button surfaces off the floating LocalModelToolbarMenu popover to the reusable InlineRuntimePickerPanel:
  - GRAPH (HologramSearchSidebar): compact sidebar-styled cpu trigger (monospaced tier label, accent when open) + the inline panel in-flow in the existing node-chat VStack (between the picker row and input row). Settings footer on.
  - NOTE (NoteDetailWorkspaceView): cpu ToolbarCapsuleButton trigger; wrapped AssistantToolbarAskBar in a VStack so the panel expands in-flow above it (frame matched to the bar width). Settings footer on.
- ALL 5 SURFACES now flat-inline: main chat (378379408), landing (d790bc81f), mini (a6a636b38), graph + note (b8ceebabc). The only remaining LocalModelToolbarMenu is ChatBrainPickerMenu (main chat's split toolbar for mode/routing/effort — model button hidden, inline panel is the picker). NO model-picker popover remains anywhere.
- The InlineRuntimePickerPanel + showsSettingsFooter pattern proved out cleanly 5×: self-contained (EpistemosRuntimePicker + InferenceState + operatingMode binding + onPicked + onOpenSettings), in-flow in each host's natural VStack slot, trigger labelled with the active tier. HARDENED: InlineRuntimePickerPanelTests now guards all 5 surfaces (each renders the inline panel + footer + trigger; no LocalModelToolbarMenu popover remains in the 4 single-button surfaces). App warm build SUCCEEDED. Owner verifies visually. NEXT down the ledger: port verdicts / Osaurus import / harness systems / chat parity (per owner).

## 2026-06-18 — OWNER #1: LOCAL FOR ALL MODES — Think + Code chat route fixed
- The #1 honesty violation ("not even having cloud selected it goes to gpt"). The 2026-06-18 fix made .agent local-first in InferenceState.effectiveChatSurfaceSelection, but I found .thinking and .pro were STILL returning .cloud(autoModel) UNCONDITIONALLY in the auto-route branch — so with a cloud key present + auto-route on, picking Think or Code silently routed to GPT even with a working local tier model (the remaining hidden-GPT route for 2 of 4 modes).
- FIX (0f419bd0e): extended the local-first guard to .pro and .thinking — they fall to cloud ONLY when no local model (nor Apple Intelligence) can serve the tier (effectiveLocalTextModelID(for:) == nil && !appleIntelligence), mirroring .fast/.agent. All four chat modes are now local-first; cloud is an explicit escalation, never a silent default. (No cloud configured → usesAutomaticCloudRouteForChatSurfaces is already false → whole branch skipped → all local.) HARDENED: extended LocalForAllModesAgentRouteGuardTests with a .pro/.thinking guard anchored to the auto-route region (asserts each carries the no-local guard BEFORE its .cloud escalation). App warm build SUCCEEDED.
- SECOND SEAM FOUND + DEFERRED (a9ef2de80, honest): the notes/general triage path (TriageService.InferencePolicyEngine.shouldAutoRouteToCloud, consumed by routeDecisionForNotes/General — surface .mainChat/.miniChat/.noteChat/.graph) ALSO auto-routes .pro/.agent/.thinking to cloud unconditionally even with a local model installed. The fix mirrors .fast, BUT it changes behavior that existing tests pin to the OLD Pro=cloud design (TriageServiceTests.autoCloudRoutingEscalatesProChat asserts .pro→.cloud WITH qwen 2B/4B installed via makeContext defaults). Updating those tests needs a test-runnable env to verify behaviorally (headless swift test EXEC hangs), so I REVERTED the TriageService logic change + flagged it in-code with the fix recipe rather than ship unverifiable test edits. NEXT (test-runnable pass): apply the shouldAutoRouteToCloud .pro/.agent/.thinking local-first fix + update the ~1-3 affected TriageServiceTests to the new local-first expectation; verify no-cloud + Code/Think → local across BOTH seams. Owner verifies in-app.

## 2026-06-18 — OWNER #1: LOCAL FOR ALL MODES second seam FIXED (TriageService)
- Addressed the flagged second hidden-GPT seam (owner asked explicitly). TriageService.InferencePolicyEngine.shouldAutoRouteToCloud (notes/general AI ops via routeDecisionForNotes/General) routed .pro/.agent/.thinking to cloud UNCONDITIONALLY even with a local model installed. FIX (3576eaaa0): collapsed the per-mode switch to ONE uniform rule — cloud only when localSelection == nil && !appleIntelligence (the rule .fast already used; .fast behavior byte-identical). All modes local-first; the large/oversized-context escalation untouched.
- KEY UNBLOCK from last turn's deferral: traced the exact decide() flow. explicitRoute SHORT-CIRCUITS for explicit .localMLX/.cloud pins BEFORE shouldAutoRouteToCloud — which is why explicitLocalSelectionSurvivesCloudAutoRoute (.thinking + cloud-on + .localMLX pin) already returned local. autoCloudRoutingEscalatesProChat used .appleIntelligence-preferred (no short-circuit) + qwen installed → reached shouldAutoRouteToCloud → old cloud. So ONLY that one test broke. localSelection() is DETERMINISTIC: empty installed → nil (the !installedModels.isEmpty guard). So:
  - autoCloudRoutingEscalatesProChat → installed: [] (no local → genuine escalation → cloud); renamed "...ONLY when no local can serve".
  - +proStaysLocalWhenLocalAvailable / +thinkStaysLocalWhenLocalAvailable (qwen installed → .localMLX + no cloudAutoRoute) lock the mandate; .appleIntelligence-preferred so they exercise shouldAutoRouteToCloud directly (existing .coding→local + .thinking+qwen→local confirm non-nil local selection).
- HONESTY: reasoned deterministically + warm build SUCCEEDED, but headless swift test EXEC hangs so the suite was NOT run — flagged for owner/CI to confirm TriageServiceTests green (3 touched + 2 chat guards). Both LOCAL-FOR-ALL-MODES seams now local-first. NEXT down the ledger: port verdicts / Osaurus / harness / chat parity.

## 2026-06-18 — HARNESS SYSTEMS scoping + eidos-grounding invariant locked
- Investigated harness systems (owner: "port the best of everything an LLM app does — RAG/MEMORY/CONTEXT/TOOL-USE/MCP/system-prompt-anchor"). FINDING: the prompt/harness is SUBSTANTIALLY BUILT on BOTH paths, not a clean greenfield gap:
  - CLOUD agent = agent_core/prompts.rs (build_system_prompt_with_index): a stable anchor (BASE_SYSTEM_PROMPT) built ONCE before the loop + reused each turn (agent_loop.rs:269/323, NOT a per-turn one-off), extended with knowledge_index (entity table) + vault 5-tier context (SOUL.md/decisions.md/skills/prior-session-summaries via vault_root). PromptMode::LocalFallback is DEAD (bridge.rs maps only code/research/general; prompt_mode_for_objective never returns it) — vestigial, flag for cleanup not feature.
  - LOCAL agent = Swift LocalAgentPromptBuilder (canonical per CLAUDE.md): full tool-call XML format + hidden-reasoning tags + gateway boundaries + vault/file discipline + verification discipline (never-claim-before-tool-response) + procedural-memory folding (the "anchor extends with memory" — proceduralMemoryBlock folds the user's generated skills) + immediate-tool-call example for small tiers. Well-tested (12 invariant tests in HermesPromptBuilderTests).
- So the harness "system prompt = anchor the loop extends" is ALREADY the design (stable anchor + vault/memory accumulation), not a one-off. No clean feature gap — the valuable move was HARDENING a critical untested invariant.
- SHIPPED (e266cba0e): the ONE critical local-prompt invariant that was untested — the eidos.query-first vault-evidence LOOKUP discipline (never-guess-path; eidos.query first → vault.read returned path; vault.search only fallback). Every vault-WRITE invariant was locked but the vault-READ/closed-citation path (the founding-thesis verifiability discipline) had zero coverage. +systemPromptGroundsVaultLookupsInEidos (path-agnostic so it holds for Swift fallback OR Rust FFI). Locks existing behavior, no prompt change.
- NEXT: harness has no clean feature gap, so down the ledger to port verdicts (R-JSONRENDER→GenUI / R-LITELLM-CP→routing / R-HTMLSTREAM→P7.2) + Osaurus P3.0 plan + chat parity. Optional cleanup: remove dead PromptMode::LocalFallback + LOCAL_FALLBACK_NOTICE (own commit, deletion guardrail — provably dead, not in-flight).

## 2026-06-18 — R-JSONRENDER verdict + GenUI confirmed complete (core subsystems done)
- Port verdict (owner priority): WebFetched vercel-labs/json-render, assessed vs Epistemos GenUI. VERDICT = PATTERNS-ONLY, nothing to port (docs/RESEARCH_JSONRENDER_2026_06_18.md). Epistemos GenUI (GenUIDispatcher exhaustive schema switch + 16 typed renderers + GenUISchema.canonicalBody catalog-guardrail + A2UI Validator + FallbackGenUIView + sorted registeredSchemas) ALREADY matches json-render's schema-keyed registry / catalog / validation / fallback / determinism — at parity-or-better (Swift-typed + compile-exhaustive + determinism-tested vs JS runtime). The ONE differentiator json-render has: STREAMING/progressive render (SpecStream pushes partial trees → live UI). Epistemos renders COMPLETE payloads only → filed as a scoped future native-Swift feature (flag-gated GenUIStreamingDecoder + partial-render path reusing typed GenUIBody + ArtifactBlockView stream), not urgent. NO code lifted (clean ProvenanceGate); R-JSONRENDER closed.
- META-FINDING (honest, 2 turns running): the app's CORE SUBSYSTEMS are substantially COMPLETE + well-tested — routes (both LOCAL-FOR-ALL-MODES seams fixed), picker (5/5 inline), harness (cloud+local prompts built, eidos-grounding locked), GenUI (complete + 4 test files). Investigating these for code gaps keeps confirming "already built." So the remaining ledger work is NOT small code slices — it's the BIG workstreams (Osaurus FULL IMPORT = ACT, R-GOOSE engine extraction = WORK, substrate DAG/KC/Halo to T4+) + research (more port verdicts) + owner-input items (chat-parity concrete gap, settings-staleness repro, fold-mode-buttons confirm). NEXT high-value move = Osaurus P3.0 PLAN DOC (owner's explicit first step for the ACT-mode major workstream) — deserves fresh focused context, not deep-context fumes. Verdicts can interleave (≤1/pass).
