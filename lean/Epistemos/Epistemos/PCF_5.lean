/-
HELIOS V5 PCF-5 — Active Rank-One Execution (Vault).

HELIOS-PCF-5 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §3 PCF-5 +
Wang-Shi-Fox arXiv:2501.12352 (regression interpretation) +
Ramsauer arXiv:2008.02217 (sparsity at retrieval).

**Statement (CANDIDATE, Lane 5 Vault):** per inference step,
only the rank-one subcomponents whose pre-activation magnitude
exceeds threshold τ contribute meaningfully — at least (1−δ)
of the output norm comes from a sparse subset:

  ‖output ↾ {c : magnitude(c) > τ}‖ ≥ (1 − δ) · ‖output‖

**Falsifier:** sparsity ratio measured on 10³ prompts; require
≥ 95% norm-recovery from ≤ 5% subcomponents.

**MAS impact: zero — Vault only.** Modifies inference path; Pro-
tier only after long burn-in.

Sorry budget at lock: ≤ 7.
-/

namespace Epistemos.PCF5

structure ActiveSubcomponent where
  component_id : Nat
  magnitude    : Float

structure ActiveStep where
  step_index : Nat
  active : List ActiveSubcomponent
  τ : Float
  δ : Float

def ActiveStep.activeCount (s : ActiveStep) : Nat :=
  s.active.length

/-- Empty active-set schema row has no active rank-one components. -/
theorem emptyActiveStepCountIsZero :
    ({ step_index := 0, active := [], τ := 0.0, δ := 0.0 } : ActiveStep).activeCount = 0 := by
  rfl

theorem singletonActiveStepCountIsOne
    (step_index component_id : Nat) (magnitude τ δ : Float) :
    ({ step_index := step_index
       active := [{ component_id := component_id, magnitude := magnitude }]
       τ := τ
       δ := δ } : ActiveStep).activeCount = 1 := by
  rfl

end Epistemos.PCF5
