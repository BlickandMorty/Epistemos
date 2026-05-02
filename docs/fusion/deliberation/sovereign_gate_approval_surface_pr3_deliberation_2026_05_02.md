# Sovereign Gate Approval Surface PR3 Deliberation - 2026-05-02

## Slice

Sovereign Gate Approval Surface PR3 migrates the existing Swift agent tool
approval sheet through the shared app-owned `SovereignGate`.

## Tier

Core-safe Swift confirmation surface. This slice does not touch Rust, generated
transport, Omega policy, provider routing, subprocess execution, entitlements,
or protected editor/graph paths.

## Files Touched

- `Epistemos/Views/Approval/ApprovalModalView.swift`
- `EpistemosTests/SovereignGateTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/deliberation/sovereign_gate_approval_surface_pr3_deliberation_2026_05_02.md`

## Gate

Existing approval buttons now map to externally supplied
`SovereignGateRequirement`s:

- `approveOnce` uses category-scoped biometric auth for
  `agent-tool-<toolName>`.
- `applyLessInterruptions` and `approveAlways` use device-owner
  authentication because they change future approval behavior.
- `deny` and `timedOut` remain immediate and do not prompt.

Failed authentication resolves the approval as `.deny`; it does not change Rust
policy, Omega permissions, the approval transport, or the tool execution path.

## Forbidden Boundaries

- No `Epistemos/App/AppBootstrap.swift` or `Epistemos/App/EpistemosApp.swift`
  edits in this slice; the shared gate and lifecycle observer were already
  wired by PR2.
- No `Epistemos/Sovereign/SovereignGate.swift` edits in this slice.
- No note editor, graph, graph-engine, `agent_core`, generated transport,
  Xcode project, entitlement, build artifact, or target artifact edits.
- No LocalAuthentication API use outside `Epistemos/Sovereign/SovereignGate.swift`.
- No Swift-owned global action-class matrix; this sheet supplies only the
  requirement for its own existing decisions.

## Risks

- P0: `LAContext`, `LocalAuthentication`, `canEvaluatePolicy`, or
  `evaluatePolicy` appears outside `Epistemos/Sovereign/SovereignGate.swift`.
- P1: Approval semantics change beyond denying the approval when authentication
  fails.
- P1: Persistent permission choices bypass device-owner authentication.
- P1: A future surface copies this mapping instead of naming its own exact gate.

## Evidence

- Red log:
  `/tmp/epistemos-sovereign-gate-approval-pr3-red-20260502.log`
- Green log:
  `/tmp/epistemos-sovereign-gate-approval-pr3-green-20260502.log`
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/SovereignGateTests test`
- Result: 11 focused Swift Testing tests passed in the Sovereign Gate suite.
- Note: Xcode printed the known SwiftLint package-plugin noise after
  `TEST SUCCEEDED`; the test command exited 0.

## Runtime Claim

The agent approval sheet now routes approve decisions through the existing
shared `SovereignGate`. It remains a direct, native confirmation path: no cloud,
CLI, Hermes subprocess, provider routing, Rust policy matrix, generated
transport, or graph authority is introduced.

## Follow-Up

Future Sovereign Gate work should migrate additional existing confirmation
surfaces one at a time behind exact gates, or add the Rust/generated
requirement transport when those precise files and tests are named.
