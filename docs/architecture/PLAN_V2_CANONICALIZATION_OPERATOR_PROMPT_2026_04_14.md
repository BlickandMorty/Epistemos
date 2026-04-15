# PLAN_V2 Canonicalization — Operator Prompt

Date: 2026-04-14
Audience: Claude Code, one-shot paste
Companion: `docs/architecture/PLAN_V2_CANONICALIZATION_MASTER_PROMPT_2026_04_14.md` (read this if any step below is unclear)

## Your job

Make the repo canonical with `PLAN_V2` through Phase 6. Audit Phases 1–6, fix the real drifts, update the plan where code is already ahead, and decide whether Phase 6 is ready to close. This is not a greenfield build — every phase has real code.

## Invariants — never violate

1. Rust is the sole control-plane authority. No second control plane in Swift.
2. `gguf` / `mlx` / `remote` are sibling runtimes. No silent reroute. No silent cloud escalation. No mid-generation backend switching.
3. Destructive communication actions stay explicit and auditable. No hidden permission expansion.
4. Architecture docs override stale handoffs. Current code overrides stale implementation-status claims.
5. Do not widen Phase 6 into Phase 7, memory redesign, marketplace, or runtime-contract rewrites.

## Read in this order before editing

1. `AGENTS.md`
2. `docs/architecture/PLAN_V2.md`
3. `docs/architecture/PHASE_6_PROTOCOL.md`
4. `docs/architecture/PHASE_6_CLARK_HANDOFF_2026_04_14.md`
5. `docs/architecture/PLAN_V2_CANONICALIZATION_MASTER_PROMPT_2026_04_14.md` ← authoritative drift list lives here

## Stale claims — do NOT repeat these

Re-verify against current code; several Clark 2026-04-14 findings have been fixed:

- capability handshake landed (`epistemos-core/src/runtime_contract.rs`, `Epistemos/Engine/BackendRuntimeContract.swift`)
- `planTracePresent` is a real runtime field
- iMessage driver has a 60/hour per-contact rate limiter
- iMessage settings use dynamic model suggestions, not hardcoded presets
- relay→native fallback telemetry exists
- local-agent tool allowlist propagates through Swift bridge into Rust registry
- `DataviewService` folder-predicate crash was fixed this session — do not undo

## Real drifts to resolve (ordered by severity)

- [ ] **Drift 1 — highest.** `CommandCenterRequestCompiler.swift` still owns context resolution, runtime selection, tool permission, and routing truth. Move request compilation behind a new Rust FFI entry point (e.g. `compile_command_center_request(...)`). Swift stays as parser + UI binder only. Add tests for explicit brain choice, unavailable brain truth, allowlist, inspector diagnostics parity.
- [ ] **Drift 2 — high, docs.** `PLAN_V2` roadmap stops at Phase 5. Add a Phase 6 section and either a §4.7 Channel Layer or a standalone `CHANNEL_SUBSYSTEM_SPEC_v1.md`. Document `send_message` vs inbound driver vs relay worker vs contact routing vs pairing modes.
- [ ] **Drift 3 — medium.** `image_generate` in `agent_core/src/tools/media.rs` is FAL cloud-only while PLAN_V2 §5.1/§16 says MLX. Pick one: (A) amend plan to allow explicit remote image generation with MLX deferred, or (B) add an MLX-first path with FAL as opt-in. Do not leave the mismatch undocumented.
- [ ] **Drift 4 — closure blocker, human-only.** Phase 6 manual runtime verification still incomplete. Perform the protocol-required live checks where credentials/permissions exist, otherwise document each blocker as `credential` / `OS permission` / `environment`.
- [ ] **Drift 5 — verification integrity.** Rerun a full fresh `xcodebuild … test` pass and capture exit status. The Dataview fix landed but a clean end-to-end full-suite success has not been recaptured yet.

## Work sequence

1. Build a Phase 1-6 canonicality matrix against `PLAN_V2`. Do not edit before the matrix exists.
2. Separate stale handoff claims from real drift. Do not conflate "not documented" with "not implemented" or "not manually verified" with "not coded."
3. Fix in order: command-center authority → plan/docs drift → remaining Phase 6 code gaps → verification → stale handoffs.
4. Keep scope disciplined. Phase 6 canonicalization only.

## Verification — rerun these yourself

```bash
cargo test --manifest-path /Users/jojo/Downloads/Epistemos/agent_core/Cargo.toml
cargo test --manifest-path /Users/jojo/Downloads/Epistemos/epistemos-core/Cargo.toml
(cd /Users/jojo/Downloads/Epistemos/graph-engine && cargo test)
(cd /Users/jojo/Downloads/Epistemos/omega-mcp && cargo test)
(cd /Users/jojo/Downloads/Epistemos/omega-ax && cargo test)
xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
```

Noise rule: `CodeEditTextView` / `CodeEditSourceEditor` SwiftLint lines in xcodebuild output are vendored and irrelevant. Trust exit code and test-count totals.

## Deliverables at end of session

1. Phase 1-6 canonicality matrix
2. Drift list ordered by severity, with before/after for any drift you closed
3. Exact files changed
4. Exact commands run + pass/fail totals
5. Manual verification evidence or precise blockers (classify each as code / docs / test / environment / credential / OS permission)
6. Updated `PLAN_V2.md` (and new channel spec if chosen) so the plan is truthful again
7. Direct verdict: **Phase 6 ready to close** or **Phase 6 not ready to close** — with reasons

Do not claim closure without the manual-verification matrix or explicit blockers. Do not restart Phase 6 from scratch. Do not revert the Dataview fix. Do not widen scope.
