# F-RustRouteKernel-ModelCheck — 2026-06-03

Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only primary witness on 2026-06-03.

Artifact: `artifacts/falsifiers/rust_route_kernel_model_check/result.json`

Command: `Tools/falsifiers/f_rust_route_kernel_model_check.sh`

## Scope

This witness checks the bounded Rust route-state relation that sits after `F-ProofCarryingRouteCard`. It proves that proof-carrying route cards cannot approach live execution unless the route kernel rejects missing route cards, invalid transitions, missing preconditions, missing rollback, missing AnswerPacket visibility, unpinned toolchains, hidden live mutations, budget increases, stale toolchain pins, and high-uncertainty or high-conflict non-abstention.

It is deliberately metadata-only. It did not run Kani, Verus, Aeneas, hax, live route mutation, unsafe FFI calls, local model inference, 70B model bytes, or product runtime probes.

## L1 / L2 / L3 Meaning

L1: advanced. The architecture cursor moves from `F-RustRouteKernel-ModelCheck` to `F-BrainRouteCard-MultiModel` when the regenerated guard sees this artifact.

L2: not advanced to product-ready. `F-Capability-Ceiling-Evaluation-Kernel` still reports `vault_research_route_with_packetized_mitigation`; live KV-Direct 128K, live sparse 70B, and product local-agent runtime gates remain separate.

L3: not user-facing. No settings, onboarding, UI, or runtime model capability is promoted by this witness.

## Evidence

- `state_count=7`
- `action_count=7`
- `checked_transition_count=147`
- `invalid_case_count>=1`
- `model_check_address=uas:route-kernel-model-check:a592a79f16d37cb7aeb2acf887b4994fdde54115b1518fb036ae2059fe13448a`
- `no_runtime_bytes_loaded=true`

Required pass axes include upstream route-card artifact pass, bounded state-space enumeration, total transition relation, invalid-transition rejection, admission preconditions, rollback, AnswerPacket visibility, pinned toolchain, abstention on uncertainty/conflict, rollback reachability, monotonic budgets, hidden-live-mutation rejection, empty unsafe FFI surface, deterministic address, missing route-card rejection, and stale-toolchain rejection.

## Rollback

If this witness is missing, stale, or red, route policy stays shadow-only at `F-ProofCarryingRouteCard`. Future `F-BrainRouteCard-MultiModel` work must not cite route-kernel proof until the guard artifact again reports `rust_route_kernel_model_check_available=true` and `next_existing_work=brain_route_card_multi_model`.
