/-
HELIOS V5 PCF-10 — Interpretability-to-Runtime Transfer (Vault).

HELIOS-PCF-10 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §3 PCF-10.

**Statement (CANDIDATE, Lane 5 Vault):** a faithful (in the SPD
sense) parameter decomposition can be transferred to runtime
as an active-rank-one execution path with bounded perplexity
drift δ ≤ ε:

  faithful(SPD_decomposition) ⇒ runtime_PPL_drift ≤ ε

**Falsifier:** end-to-end PPL drift on Lambada subset ≤ 0.5
vs the reference (full-precision) inference path.

**Adversarial defense:** adversarial token sequences → output
equivalence test.

**MAS impact: zero — Vault only.** State:candidate per
v5.2 §B until active-rank-one kernels beat dense fallback on
M2 Max.

Sorry budget at lock: ≤ 7.
-/

namespace Epistemos.PCF10

structure InterpretabilityTransfer where
  transfer_id : String
  source_anchor_library_id : String
  ppl_drift_max : Float
  verified : Bool

def InterpretabilityTransfer.acceptanceMet (t : InterpretabilityTransfer) (ppl_drift_observed : Float) : Bool :=
  ppl_drift_observed ≤ t.ppl_drift_max

theorem acceptanceMetIffDriftWithinBudget
    (t : InterpretabilityTransfer) (ppl_drift_observed : Float) :
    t.acceptanceMet ppl_drift_observed = true ↔ ppl_drift_observed ≤ t.ppl_drift_max := by
  simp [InterpretabilityTransfer.acceptanceMet]

theorem driftWithinBudgetSatisfiesAcceptance
    (t : InterpretabilityTransfer) (ppl_drift_observed : Float)
    (h_drift : ppl_drift_observed ≤ t.ppl_drift_max) :
    t.acceptanceMet ppl_drift_observed = true := by
  exact (acceptanceMetIffDriftWithinBudget t ppl_drift_observed).2 h_drift

end Epistemos.PCF10
