# Sovereign Gate Rust Matrix PR4 Deliberation - 2026-05-02

```text
Slice:          Sovereign Gate Rust Matrix PR4 - action-class classifier
Tier:           Core foundation, Pro/Research forward-compatible
Files touched:
- agent_core/src/sovereign/mod.rs
- agent_core/src/lib.rs
- docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
- docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
- docs/fusion/deliberation/sovereign_gate_rust_matrix_pr4_deliberation_2026_05_02.md
Protected paths:
- Epistemos/Sovereign/SovereignGate.swift
- Epistemos/Views/Approval/ApprovalModalView.swift
- Epistemos/Views/Notes/ProseEditor*.swift
- Epistemos/Views/Graph/**
- graph-engine/**
- epistemos-core/**
- generated UniFFI bindings / generated libraries
Gate:           SovereignGate touchpoint? Rust decision matrix only
Risks:          P0 if this calls LocalAuthentication, changes Swift prompting, edits generated transport, or lets Swift own the action-class matrix again.
Verification:   red/green Rust focused logs; grep proving no LAContext/Swift/generated/UI changes; diff-only invariant scan.
Rollback:       Remove agent_core/src/sovereign/mod.rs, remove the lib.rs module line, and remove PR4 doc/status lines.
```

## Authority

`docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.2 states that the
action-class matrix lives in the Rust kernel while Swift owns presentation
through the single `Epistemos/Sovereign/SovereignGate.swift` entrypoint.
`MASTER_RESEARCH_INDEX_2026_05_02.md` §3.2 names the class ladder:
Trivial, Reversible, Sensitive, Destructive, Sovereign.

Closed prior work:

- PR1: single Swift executor.
- PR2: lifecycle grace clearing.
- PR3: existing agent approval modal maps decisions to the shared Swift gate.

## Approved

- Add a small Rust module declaring the action classes, gate requirements,
  outcome shell, and deterministic classifiers for named doctrine intents.
- Add focused Rust tests proving doctrine examples map correctly.
- Add a conservative bridge from existing `RiskLevel` into the matrix:
  read-only -> Trivial, modification -> Reversible, destructive -> Destructive.
- Preserve lower-snake-case wire shape for future generated transport.

## Explicitly Not Approved

- Generated UniFFI exports.
- Swift prompt changes or Swift action-class policy.
- Any `LocalAuthentication` / `LAContext` movement.
- Migrating more confirmation dialogs.
- Secure Enclave key sealing implementation.
- Tool registry behavior changes, approval semantics, UI, Omega, ChatCoordinator,
  graph, renderer, editor, entitlements, or Xcode project edits.

## Implementation Contract

- Rust owns class selection; Swift only receives executable requirements later.
- `Sensitive` emits category-scoped biometric requirements with the canonical
  900-second grace.
- `Destructive` emits device-owner authentication every time, with no grace.
- `Sovereign` emits a Secure-Enclave key-release requirement for future
  Pro/Research transport, not a Core implementation claim.
- The PR4 code is additive and not wired into production execution yet.

## Verification

Red:

```bash
cd agent_core && cargo test sovereign --lib 2>&1 | tee /tmp/epistemos-sovereign-gate-rust-matrix-pr4-red-20260502.log
```

Green:

```bash
cd agent_core && cargo test sovereign --lib 2>&1 | tee /tmp/epistemos-sovereign-gate-rust-matrix-pr4-green-20260502.log
```

Guardrails:

```bash
git diff --check -- agent_core/src/sovereign/mod.rs agent_core/src/lib.rs docs/fusion
git diff -- agent_core/src/sovereign/mod.rs agent_core/src/lib.rs | rg -n 'LAContext|LocalAuthentication|evaluatePolicy|canEvaluatePolicy|Process\(\)|std::process::Command|memcpy|memmove|copyMemory|storageModeManaged|storageModePrivate|z3|kani|kissat|lean|cvc5|alloy' || true
git diff --name-only -- Epistemos/Sovereign Epistemos/Views/Approval Epistemos/Views/Notes Epistemos/Views/Graph graph-engine epistemos-core Epistemos.xcodeproj
```

## Acceptance

- Wired: `agent_core::sovereign` exists as the Rust action-class matrix module.
- Reachable: focused Rust tests cover doctrine examples, risk-level bridging,
  sensitive grace, destructive no-grace behavior, sovereign forward requirement,
  and lower-snake-case serialization.
- Visible: docs state this is not generated transport, not Swift policy, and
  not Secure Enclave sealing.

## Stop Triggers

- A generated transport edit becomes necessary.
- Any Swift prompt/presenter path changes.
- The classifier cannot stay deterministic and allocation-light.
- A broad tool-registry behavior change is needed.

## Closeout - 2026-05-02

Closed as implemented and verified.

Artifacts:

- `agent_core/src/sovereign/mod.rs`
- `agent_core/src/lib.rs`

Logs:

- Red: `/tmp/epistemos-sovereign-gate-rust-matrix-pr4-red-20260502.log`
- Green: `/tmp/epistemos-sovereign-gate-rust-matrix-pr4-green-20260502.log`
- Post-rustfmt green:
  `/tmp/epistemos-sovereign-gate-rust-matrix-pr4-green-20260502-r2.log`

Verification:

- `cargo test sovereign --lib`: 6 Rust tests passed; 797 filtered out.

Boundary:

This closes only the additive Rust action-class matrix seed. Generated
requirement transport, Swift presentation policy, additional popup migrations,
Secure Enclave key sealing, and production tool behavior remain future gates.
