# Agent System Implementation Progress

> **Index status**: CANONICAL-OPERATIONAL — Live session log replacement for older PROGRESS.md; canonical operational.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.

Last updated: **2026-05-12** — Graph plan Phase A → C algorithmic prep + vault fixes + HELIOS audit + backlog status. **The 2026-04-28 entry below remains canonical for everything before 2026-05-05; the 2026-05-05 entry remains canonical for that sprint; this entry covers 2026-05-12.**

## 2026-05-12 — Canonical graph plan + vault fixes + HELIOS audit (this session, 16+ commits)

**Test counts:**
| Metric | Pre-session | Post-session |
|---|---|---|
| graph-engine lib tests | 2,580 | 2,707 (+127 new across 9 modules) |
| graph-engine integration tests | 0 | 8 (`visual_equivalence`) |
| HELIOS canonical-consistency tests (`epistemos-research --features research`) | 113 | 113 (still green) |
| Swift Epistemos build | green | green (xcodebuild exit 0, SwiftLint warnings only on third-party CodeEdit deps) |
| HELIOS B5 invariant smoke (`scripts/check-helios-invariants.sh`) | sub-gate 1 FAIL (anchor drift) | PASS (all 3 sub-gates) |

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

7. **APP_ISSUES backlog status updates** (2 commits):
   - `907e17c19` ISSUE-2026-05-11-002 → Partially Fixed (Filters UI confirmed shipped in `cabf81df0`; selected-neighbor push-out physics tracked into Phase B).
   - `1edb5d107` ISSUE-2026-05-10-002 → Patched (APIKeysHealthRow shipped earlier in `58d998566`/`35120f79b`, closes the diagnostic loop).

**What's queued for the next /loop iterations:**

- Engine + renderer wiring of the Phase A/B/C pure-data modules into the live integrator + frame loop.
- MSL `.metal` translation of `force_kernels` / `grid_kernels` / `adaptive_kernels` / `visibility_kernels` into `Epistemos/Shaders/Graph/`.
- More APP_ISSUES auto-fix sweeps (ISSUE-2026-05-12-008 first-note hang, ISSUE-2026-05-12-009 sidebar+graph slow open).
- Cross-canon verification across the 105 HELIOS Swift guard tests + 113 research canonical-consistency tests on every iteration.

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

**Open:** OpenThinker3-7B catalog entry (needs Python MLX conversion step we can't run autonomously — wait for a community `mlx-community/OpenThinker3-7B-*-mlx` upload or run the conversion manually). Gemma 4 loader port (multi-file Swift MLX work in `LocalPackages/mlx-swift-lm/` — too big for autonomous landing, tracked in MASTER_MODEL_STACK_PLAN.md §3.a).

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
