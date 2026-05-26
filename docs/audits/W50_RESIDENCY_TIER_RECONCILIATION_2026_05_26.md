# W-50 Residency Tier Reconciliation - 2026-05-26

Status: hardening guard landed.

## Problem

After Wave 2, the codebase intentionally contains several concepts with
similar names:

1. `agent_core::uas::ResidencyTier`
2. `Epistemos.Engine.RuntimeExecutor.ResidencyTier`
3. `agent_core::scope_rex::residency::Residency`
4. `agent_core::lattice_wbo::ResidencyTier`
5. `agent_core::resonance::ResidencyLevel`

These are not interchangeable. Collapsing them would corrupt the architecture:

- UAS `ResidencyTier` answers whether a substrate concept is current app,
  verified floor, or capability ceiling.
- Swift RuntimeExecutor `ResidencyTier` mirrors the UAS shipping-policy wire
  tags for routing ceilings.
- SCOPE-Rex `Residency` answers where a claim lives after the residency
  governor processes it.
- Lattice/WBO `ResidencyTier` answers which memory/coding tier accounts for
  WBO loss and falsifier coverage.
- Resonance `ResidencyLevel` answers display/retrieval warmth for claim
  resonance.

## Decision

Do not rename or merge the enums in this pass. The safe W-50 move is a guard
that makes the distinction executable:

- Swift runtime tier wire values must stay aligned with the Rust UAS
  shipping-policy tags: `current_app`, `verified_floor`,
  `capability_ceiling`.
- Rust UAS docs must keep the anti-drift warning against SCOPE-Rex residency.
- SCOPE-Rex and lattice/WBO enums must remain visibly separate axes.

## Verification

Added `RuntimeCapabilityAndPerformancePolicyTests.
residencyTierNamesKeepSeparateMeanings`.

The test reads the mirrored source files and fails if a future edit removes the
key distinctions or silently changes the wire tags.

## No-Orphan Check

- Motion: Project / Compress / Recall.
- UAS address: no new address, source-guard only.
- Plane: Verification.
- Residency: CurrentApp documentation/test guard.
- WBO/error policy: protects the lattice/WBO residency axis from being
  collapsed into UAS or SCOPE-Rex residency.
- Witness: Swift source-guard test.
- Falsifier: W-50 drift guard test in
  `RuntimeCapabilityAndPerformancePolicyTests`.
- Tier: Tier 1 hardening.
- Rollback: revert this doc plus the single source-guard test.
