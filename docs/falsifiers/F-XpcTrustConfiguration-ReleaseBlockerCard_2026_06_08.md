# F-XpcTrustConfiguration-ReleaseBlockerCard - 2026-06-08

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Status

PASS as metadata-only L1/T1 source-card evidence.

- Artifact:
  `artifacts/falsifiers/xpc_trust_configuration_release_blocker_card/result.json`
- Command:
  `Tools/falsifiers/f_xpc_trust_configuration_release_blocker_card.sh`
- Falsifier id: `F-XpcTrustConfiguration-ReleaseBlockerCard`
- Artifact commit SHA: `6d4cdf3a65933b7bbb2230b0240ac953a481215b`
- Deterministic address:
  `sha256:c31f39a6a7ce6bf47839acf9aa80e34adf9a793c794f51698a4ffb044ef1d19f`
- Next cursor:
  `small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`

## What It Proves

The witness consumes `F-ToolExecutionSurface-ReleaseBlockerCard` and the
retained release-audit family `xpc_trust_configuration`, then binds:

- 1 retained XPC trust issue.
- 12 source refs across XPC trust, service protocols, clients, service
  entrypoints, XPC smoke tests, capability bridge tests, and XPC canon docs.
- 18 invariants.
- 5 focused commands.
- 32 rejected red fixtures.
- Zero XPC connections opened.
- Zero XPC services launched.
- Zero tool commands executed.
- Zero model/runtime/provider bytes.
- Zero provider calls.

## Required Invariants

The card requires App Group service names, `setCodeSigningRequirement` before
connection resume, `anchor apple generic`, service identifier, team OU,
development-team drift guard, agent/provider client trust wiring, thin service
delegates, capability-bridge subject split, rollback, RunEventLog,
AnswerPacket, and abstention before XPC-backed runtime claims can promote.

It rejects process-identifier trust, unwhitelisted payload claims, hidden
provider/XPC fallback, cloud/tool promotion, L2/L3/product green, live dense
70B, SSD-as-RAM, provider calls, and byte leaks.

## Research Notes

Local canon anchors:

- `docs/fusion/XPC_RESEARCH_INTAKE_2026_05_04.md`
- `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md`
- `Epistemos/XPC/XPCTrust.swift`
- `EpistemosTests/XPCSmokeTests.swift`
- `EpistemosTests/CapabilityBridgeTests.swift`

Official Apple validation: `NSXPCConnection.setCodeSigningRequirement(_:)`
enforces a peer code-signing requirement and should be called before
`resume()`; malformed requirements are fatal/exceptional and mismatched peers
invalidate the connection. Apple also documents listener-side
`setConnectionCodeSigningRequirement(_:)` for incoming XPC connections.

- https://developer.apple.com/documentation/foundation/nsxpcconnection/3943309-setcodesigningrequirement
- https://developer.apple.com/documentation/foundation/nsxpclistener/setconnectioncodesigningrequirement%28_%3A%29

## Layer Truth

- L1: architecture side-card advanced.
- L2: product capability route remains
  `vault_research_route_with_packetized_mitigation`.
- L3: user-facing release readiness remains red.

Correct phrasing: "L1 XPC trust source-card advanced; product capability /
user surface did not."
