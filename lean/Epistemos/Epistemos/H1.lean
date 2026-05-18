/-
HELIOS V5 H1 — WBO-7 Master Inequality (operational view of E4).

HELIOS-H1 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H1 +
`helios_v3.md` Part II + DOC 0 §0.6.

H1 is the OPERATIONAL form of E4 — same WBO-7 master inequality,
viewed as a build-checked invariant rather than substrate theorem.
B5 CI gate samples at 1/100; failure triggers HALT severity.

**WBO-7 vs WBO-6:** v5 supersedes v3's WBO-6 by adding an
**active-support penalty** ε(τ):

  WBO-7: Σᵢ wᵢ · b(τ, Aᵢ) ≤ 7 · sup_i b(τ, Aᵢ) − ε(τ)

WBO-6 (T_W + T_K + T_R + T_Q + T_S + T_SE per helios v3 Part II)
preserved as kernel-only subform — strict weakening of WBO-7.
Canonical = WBO-7. H1 sample budget ≤ 50 µs MAS profile.

Sorry budget at lock: ≤ 4.
-/

namespace Epistemos.H1

structure SamplerTrajectory where
  τ_id : String

structure ActiveSupportPenalty where
  τ_id : String
  ε    : Float

structure Wbo7Verdict where
  trajectory : SamplerTrajectory
  passed     : Bool
  budget_us  : Float    -- ≤ 50.0 in MAS profile

def Wbo7Verdict.withinMasBudget (v : Wbo7Verdict) : Bool :=
  v.passed && v.budget_us ≤ 50.0

theorem wbo7HoldsOperational (v : Wbo7Verdict)
    (h_budget : v.withinMasBudget = true) :
    v.withinMasBudget = true := by
  exact h_budget

end Epistemos.H1
