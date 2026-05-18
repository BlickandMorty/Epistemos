/-
HELIOS V5 PCF-6 — ModelSurgeryEnvelope (Vault).

HELIOS-PCF-6 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §3 PCF-6.

**Statement (CANDIDATE, Lane 5 Vault):** editing a component
subset S of size ≤ s_max bounds downstream PPL drift on
out-of-edit prompts:

  PPL_drift(out_of_edit) ≤ O(s_max · σ_max(W_edit))

where σ_max(W_edit) is the largest singular value of the edit
matrix.

**Falsifier:** emoticon-style edit on 4-layer model;
off-distribution PPL drift ≤ 1.0.

**MAS impact: zero — Vault only.** Mutates weights; cannot ship
in MAS.

Sorry budget at lock: ≤ 7.
-/

namespace Epistemos.PCF6

structure ModelSurgeryEnvelope where
  envelope_id : String
  target_components : List Nat
  s_max : Nat
  sigma_max_w_edit : Float
  ppl_drift_max : Float

/-- Edit safety bound: PPL drift on out-of-edit prompts is
bounded by O(s_max · σ_max(W_edit)). -/
def ModelSurgeryEnvelope.driftUpperBound (e : ModelSurgeryEnvelope) : Float :=
  (e.s_max.toFloat) * e.sigma_max_w_edit

theorem driftUpperBoundExpands (e : ModelSurgeryEnvelope) :
    e.driftUpperBound = (e.s_max.toFloat) * e.sigma_max_w_edit := by
  rfl

end Epistemos.PCF6
