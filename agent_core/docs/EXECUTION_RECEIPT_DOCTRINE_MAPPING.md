# Execution Receipt Doctrine Mapping — 2026-05-04

This document preserves the Quick Capture worktree's execution-receipt
prototype as canonical recovery input without copying its donor runtime into
main. It maps `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/effect/receipt.rs`
onto Epistemos' T2 Provenance + Sovereign Gate track.

## Donor Authority

Source:

- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/effect/receipt.rs`

The donor file implements the canonical receipt shape, a typed capability enum,
a `SigningKey` abstraction, an HMAC-SHA256 structural placeholder, and tests for
sign/verify, tamper invalidation, malformed signatures, hash width, and signed
capability payloads.

## Canonical Shape

Each applied effect needs one tamper-evident receipt attached to the run/event
log row:

| Field | Canonical meaning |
|---|---|
| `call_id` | Per-call ULID / RunEventLog / AgentEvent correlation id |
| `plan_hash` | Hash of the LivePlan, route decision, or typed intent plan that authorized the call |
| `tool` | Canonical dotted Tool V2 name, for example `vault.write` or `reason.think` |
| `input_hash` | SHA-256 of canonical bytes for the exact tool input |
| `output_hash` | SHA-256 of canonical bytes for the resulting effect or apply error |
| `timestamp` | Event ordering timestamp, encoded as RFC3339 in the donor |
| `capabilities_used` | Exact Sovereign Gate grants exercised by this call |
| `signature` | Tamper-evident signature over the canonical payload |

This shape is part of the trust spine. A completed agent action is not merely a
log line; it is an auditable claim that can be verified against the original
input, output, capability grants, and plan hash.

## Capability Mapping

| Donor capability | Fusion mapping |
|---|---|
| `VaultPath { path, verb }` | Resource grant over a vault-relative path and verb such as read/write/delete |
| `NetworkHost { host }` | BYOK/cloud/network grant with explicit host scope |
| `BiometricSession { ttl_secs }` | Secure Enclave / LocalAuthentication grace session; do not replace with a UI-only flag |
| `Other { name }` | Forward-compatible escape hatch only; new recurring capabilities should become typed variants |

Capability receipts must align with the no-compromise XPC and sandbox doctrine:
no PID-based trust decisions, no unsigned execution claims, no silent cloud
fallback, and no folded "for now" trust geometry.

## Production Gap

The donor `HmacSha256SigningKey` is intentionally a placeholder. It proves the
payload shape and tamper invalidation property, but production needs an
asymmetric verifier path:

1. Per-vault signing key material lives behind Keychain / Secure Enclave /
   `.biometryCurrentSet` policy.
2. The production algorithm is Ed25519 or an equivalent asymmetric signature
   chosen in the T2/XPC implementation brief.
3. Public verification must not require exposing the signing secret.
4. Signature verification must be wired into Provenance Console visibility,
   not hidden as a background-only diagnostic.

## Recovery Placement

Track: T2 Provenance + Sovereign Gate.

Recovery stage:

- A-F recovery: preserve the shape and Tool V2 name binding.
- B.1 / Sovereign Gate slice: introduce the main Rust type after reading the
  current RunEventLog, AgentEvent, MutationEnvelope, and XPC entitlement paths.
- V2 XPC Mastery: move signing and verification across the final service
  boundary without weakening the same contract.

## Non-Negotiables

- Use canonical dotted Tool V2 names in `tool`.
- Hash canonical bytes, not pretty-printed debug output.
- Sign the capability list as part of the same payload.
- Treat malformed signatures as verification failures, not crashes.
- Surface receipt verification in user-facing provenance UI.
- Do not copy the donor placeholder as final cryptography.

## Verification To Preserve

When the live type lands in main, preserve these donor test properties:

- Signing and verifying the untouched receipt succeeds.
- Mutating any signed field invalidates verification.
- Capability payloads participate in the signed bytes.
- Malformed hex signatures fail verification without panic.
- `input_hash` and `output_hash` are 32-byte SHA-256 hex digests.
