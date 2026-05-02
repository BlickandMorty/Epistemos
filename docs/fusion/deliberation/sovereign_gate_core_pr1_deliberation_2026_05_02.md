# Sovereign Gate Core PR1 Deliberation - 2026-05-02

```text
Slice:          Sovereign Gate Core PR1 - single Swift authorization executor
Tier:           Core
Files touched:
- Epistemos/Sovereign/SovereignGate.swift
- EpistemosTests/SovereignGateTests.swift
- docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
- docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
- docs/fusion/deliberation/sovereign_gate_core_pr1_deliberation_2026_05_02.md
Protected paths:
- Epistemos/Views/Notes/ProseEditor*.swift
- Epistemos/Views/Notes/ProseTextView2.swift
- Epistemos/Views/Graph/MetalGraphView.swift
- Epistemos/Views/Graph/HologramController.swift
- graph-engine/**
- agent_core/**
- epistemos-shadow/**
- omega-mcp/**
- epistemos-core/**
- substrate-core/**
Gate:           SovereignGate touchpoint? new
Risks:          P0 if LocalAuthentication appears outside Epistemos/Sovereign/SovereignGate.swift; P0 if this slice implements the Rust action-class matrix in Swift; P1 if it migrates existing dialogs or caches approvals across lock/sleep/background.
Verification:   focused Swift test logs under /tmp/epistemos-sovereign-gate-pr1-*-20260502.log; Sovereign Gate leakage grep; diff-only invariant greps; protected-path staged-set audit.
Rollback:       Remove SovereignGate.swift, SovereignGateTests.swift, and the PR1 doc/status lines.
Stop triggers:
- The slice needs agent_core, generated UniFFI, entitlements, project files, existing dialog migrations, protected editor/graph paths, or Rust kernel changes.
- Swift starts deciding which app actions are Sensitive or Destructive instead of executing an externally supplied gate requirement.
- LocalAuthentication, LAContext, canEvaluatePolicy, evaluatePolicy, biometric, or TouchID appears outside Epistemos/Sovereign/SovereignGate.swift.
- Sensitive grace survives explicit clearing, crosses category boundaries, or applies to destructive requirements.
```

## Doctrine Anchor

`docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.2 defines the Sovereign Gate:

- Every confirmation surface eventually routes through one biometric gate.
- The Rust kernel decides whether a touch is required; Swift owns how it is presented.
- Core supports Trivial, Reversible, Sensitive, and Destructive classes using public `LocalAuthentication`.
- Sensitive uses a 15-minute category-scoped grace window.
- Destructive uses device-owner authentication every time and has no grace.
- `Epistemos/Sovereign/SovereignGate.swift` is the single Swift entrypoint.

This PR intentionally implements only the Swift presentation/authorization executor. It does not implement the Rust action-class matrix, Rust `GateRequirement`, generated UniFFI transport, Secure Enclave key sealing, Pro/Research Sovereign class, or existing popup migration.

## Research Anchors

Donor research only, not code authority:

- `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_NO_COMPROMISE_ARCHITECTURE.md`: tier-gated Core/Pro/Research split and biometric Dark Node direction.
- `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/uasa.agent.final.md`: high-risk biometric gate and Secure Enclave safety architecture.
- `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/Kimi_Agent_Deterministic AI Deep Dive/personal/acs_meta_layer.md`: Secure Enclave as root-of-trust/nucleus analogy.

## Why This Slice Now

- The doctrine lists Sovereign Gate Core classes as not started.
- No production `LAContext`, `LocalAuthentication`, or `SovereignGate` symbol exists today; the first implementation can enforce the single-entrypoint rule before ad-hoc biometric prompts appear.
- Halo V1 needs protected editor files, live GraphEvent consumers need protected graph/Halo surfaces, and Omega/broader AgentEvent work touches heavily dirty runtime paths.
- This slice is greenfield, Core-safe, public-API only, and does not touch inference, Metal, Rust, graph renderer, note editor, entitlements, project files, generated artifacts, or Xcode schemes.

## Implementation Contract

- Add `Epistemos/Sovereign/SovereignGate.swift` as the only source file allowed to import `LocalAuthentication` or instantiate `LAContext`.
- Model an externally supplied `SovereignGateRequirement`, not a Swift-owned app-action matrix:
  - `.none` allows immediately.
  - `.biometric(category:graceDuration:)` executes the Sensitive-class presentation policy and caches success only for that category and grace duration.
  - `.deviceOwnerAuthentication` executes the Destructive-class presentation policy every time with no grace.
- Add an injectable authenticator seam so focused tests never trigger real Touch ID.
- Reject empty reasons for any requirement that prompts the user.
- Add explicit `clearGrace()` so future app lifecycle hooks can clear approvals on lock, sleep, background, kernel mode change, or policy-profile change.
- Do not migrate existing popups, alerts, permission surfaces, Settings footers, Omega approvals, vault destructive actions, Rust kernels, or generated bindings in this PR.

## Verification

Red first:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/SovereignGateTests test 2>&1 | tee /tmp/epistemos-sovereign-gate-pr1-red-20260502.log
```

Green focused:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/SovereignGateTests test 2>&1 | tee /tmp/epistemos-sovereign-gate-pr1-green-20260502.log
```

Guardrails:

```bash
git diff --check -- Epistemos/Sovereign/SovereignGate.swift EpistemosTests/SovereignGateTests.swift docs/fusion
rg -n 'LAContext|canEvaluatePolicy|evaluatePolicy|deviceOwnerAuthentication|TouchID|biometric|LocalAuthentication' Epistemos EpistemosTests --glob '!Epistemos/Sovereign/SovereignGate.swift' --glob '!EpistemosTests/SovereignGateTests.swift'
git diff -- Epistemos/Sovereign/SovereignGate.swift EpistemosTests/SovereignGateTests.swift | rg -n 'Process\(\)|swift-subprocess|Foundation\.Process|std::process::Command|memcpy|memmove|\.copyMemory|Data\(bytes:|storageModeManaged|storageModePrivate|z3|kani|kissat|lean|cvc5|alloy' || true
git diff --name-only -- Epistemos/Views/Notes Epistemos/Views/Graph Epistemos/Graph graph-engine agent_core epistemos-shadow omega-mcp epistemos-core substrate-core Epistemos.xcodeproj
```

Actual logs:

- Red first: `/tmp/epistemos-sovereign-gate-pr1-red-20260502.log`.
- Initial green: `/tmp/epistemos-sovereign-gate-pr1-green-20260502.log`.
- Hardened green after adding clock-rollback and invalid-duration cases:
  `/tmp/epistemos-sovereign-gate-pr1-green-20260502-r2.log`.

## Acceptance

- Wired: the app has exactly one Swift Sovereign Gate entrypoint capable of executing Core-safe prompt requirements.
- Reachable: focused tests can exercise no-auth, Sensitive-style biometric grace, category boundaries, grace expiry, explicit clearing, destructive every-time authentication, missing reasons, failed authentication, clock rollback, and invalid grace durations without real Touch ID.
- Visible: source guard proves `LocalAuthentication` / `LAContext` are confined to `Epistemos/Sovereign/SovereignGate.swift`.
- Boundary: no existing dialogs are migrated; no protected paths, Rust kernel, generated bindings, entitlements, project files, graph renderer, note editor, subprocesses, solver hot paths, or tensor/memory hot paths are touched.
