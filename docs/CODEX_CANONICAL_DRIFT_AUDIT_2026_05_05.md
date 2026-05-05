# Codex canonical drift audit - 2026-05-05

**Status:** Initial overseer audit, not a full release sign-off.

This document records the Codex pass requested by the user after the
Claude V2 closeout. The rule is strict: code and docs must be canonical,
or they must explicitly supersede canon with a stronger implementation and
verification record. They cannot silently drift below canon.

## Authority order used

1. Current repository code and passing local verification logs.
2. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`.
3. `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md`.
4. `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`.
5. `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`.
6. Session closeout and handoff docs, treated as maps rather than truth.

No arbitrary calendar gate is introduced here. A gate is valid only if it
is a capability, verification, distribution, entitlement, licensing, or
explicit doctrine gate.

## Current verdict

V2.3 LSP was below canon after the Claude closeout because it removed the
subprocess but did not implement the plan's literal semantic LSP path.
Codex corrected that in the dirty worktree with real `tower-lsp` payload
types and `tree-sitter` same-file hover/definition.

The larger app is **not** fully canon-signed yet. The highest-risk drift is
not LSP anymore; it is Cognitive DAG authority language. Phase 8.A-8.G may
be useful implementation work, but it cannot be called release-canonical
until Codex verifies the Phase 1-7 preconditions, mirror coverage, replay
gates, CI/doctrine gates, and capability-bound edge verification.

## Drift register

| ID | Area | Classification | Evidence | Required action |
|---|---|---|---|---|
| CD-001 | V2.3 LSP runtime | SUPERSEDED / ALIGNED | `agent_core/src/lsp_runtime/mod.rs` now uses `tower_lsp::lsp_types` plus `tree_sitter`; focused Rust and Swift LSP tests pass. | Keep the corrected status in `docs/V2_3_LSP_MIGRATION_PLAN_2026_05_05.md`. Remaining work is richer IDE semantics, not the basic Tower/tree-sitter path. |
| CD-002 | V2 final closeout V2.3 row | DRIFT FIXED | The closeout said Stage F Tower/tree-sitter was deferred. | Patched `docs/SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md` to say Codex added same-file Tower/tree-sitter semantics and only richer cross-file/scope-aware work is deferred. |
| CD-003 | Codex verification handoff counts and LSP status | DRIFT FIXED | Handoff said 32 commits and Stage F pending; `git rev-list --count 7a063f4a..HEAD` reports 44 at `b238f085`. | Patched `docs/CODEX_VERIFICATION_HANDOFF_2026_05_05.md` with a Codex addendum and corrected scope language. |
| CD-004 | V2.1 Phase 8 authority | BLOCKED / NOT SIGNED | May 4 plan and DAG doctrine require Phase 1-7 readiness and authority gates before Phase 8 can be treated as canonical authority. | Do not mark V2.1 8.A-8.G as release-shipped until Codex verifies prerequisites, mirror coverage, replay parity, and authority flip criteria. |
| CD-005 | DAG edge signatures | DRIFT / BLOCKER | `Edge` docs promise capability-bound Merkle signatures. `put_edge` currently rejects all-zero signatures only; it does not verify against a held capability hash at the storage boundary. | Add a capability-aware insert/verify path, or explicitly downgrade storage enforcement to "Phase 8.A structural guard" everywhere it is described. Authority flip must wait. |
| CD-006 | DAG mirror auto-invoke coverage | UNVERIFIED | Handoff says only `commit_evidence`, `commit_claim`, `record_outcome`, and `SkillRouter::load` were wired. | Inventory every legacy write path and confirm whether companion registration, evolution events, replay writes, and skill/procedure mutation paths should dispatch mirrors. |
| CD-007 | MAS-first subprocess discipline | PARTIAL ALIGNMENT | Gemini/Kimi passthrough registration is under `#[cfg(feature = "pro-build")]` and `enable_bash`; that matches MAS doctrine for that slice. | Run a full source guard over every `Command::new`, `Process`, and `Pipe` surface before signing MAS canon. |
| CD-008 | Full-app verification | BLOCKED BY TIME / NOT CHECKED | LSP focused tests passed; full app build/test and manual runtime release audit have not been repeated after the dirty worktree edits. | Run the release-audit validation matrix before any "whole app canon" claim. |
| CD-009 | Benchmark result JSON dirtiness | UNRELATED DIRTY ARTIFACTS | Several `benchmarks/results/*.json` files became dirty during local test/build activity. | Do not commit them unless intentionally refreshing benchmark baselines. |

## Verification performed in this Codex pass

| Surface | Command | Result | Log |
|---|---|---|---|
| Rust LSP semantic runtime | `cargo test --manifest-path agent_core/Cargo.toml --features lsp-runtime lsp_runtime` | PASS, 17/17 | `/tmp/epistemos-codex-verify-20260505/cargo-agent-core-lsp-runtime-rerun2.log` |
| Rust LSP MAS feature variant | `cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features mas-build,lsp-runtime lsp_runtime` | PASS, 17/17 | `/tmp/epistemos-codex-verify-20260505/cargo-agent-core-lsp-runtime-mas.log` |
| Rust LSP Pro feature variant | `cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features pro-build,lsp-runtime lsp_runtime` | PASS, 17/17 | `/tmp/epistemos-codex-verify-20260505/cargo-agent-core-lsp-runtime-pro.log` |
| Swift focused LSP suite | `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LSPMessageTests -only-testing:EpistemosTests/LSPClientTests -only-testing:EpistemosTests/LSPTransportTests -only-testing:EpistemosTests/RustLSPTransportTests` | PASS, 37/37 | `/tmp/epistemos-codex-verify-20260505/xcodebuild-lsp-focused-rerun.log` |
| Whole-app Debug build | `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build` | PASS; one warning in `AgentQueryEngine.swift` about unused `MainActor.run` result | terminal |
| Patch hygiene | `git diff --check` | PASS | terminal |

## Verification still required before whole-app canon sign-off

- Full or release-relevant `xcodebuild ... test` pass, not only the LSP focused suite.
- `cargo test` for `graph-engine`.
- `cargo test` for `agent_core` feature combinations touched by V2.1, V2.3, V2.4, and CLI passthrough.
- Doctrine linter and replay verification commands introduced by Phase 8.F/8.G.
- Source guard that MAS builds do not include live subprocess, cloud, Pro-only, ES, NE, or temporary-exception surfaces.
- Manual/runtime verification for app bootstrap, settings observability, Halo ledger ribbon, LSP editor flow, and any release-risk UI surface before ship language.

## Non-negotiable corrections from this pass

- Do not call the previous lifecycle-only LSP kernel a completed V2.3 semantic LSP. The corrected dirty worktree is the canonical LSP baseline.
- Do not call DAG storage signature enforcement complete until insertion verifies against capability context, not merely non-zero bytes.
- Do not let "implemented" become "released" without Codex verification and the relevant doctrine gates.
- Do not commit generated benchmark JSON unless the task is explicitly to refresh baselines.
