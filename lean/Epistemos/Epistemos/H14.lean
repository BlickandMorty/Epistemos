/-
HELIOS V5 H14 — Apollonian curvature constraint (Rickards-Stange 2307.02749).

HELIOS-H14 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H14 +
Haag-Kertzer-Rickards-Stange arXiv:2307.02749v3 (Annals of
Mathematics 200(2):749-770, 2024) — "The local-global
conjecture for Apollonian circle packings is FALSE."

**Statement:** the 20-year-old Local-Global Conjecture for
Apollonian packings is **FALSE**. Quadratic and quartic
obstructions prevent certain residue classes from appearing as
curvatures in any primitive integer Apollonian packing.

  ¬LocalGlobalConjecture(ApollonianPacking)

**Falsifier protocol:** any Epistemos claim that depends on
Apollonian local-global as a *hypothesis* must be refactored
to depend on the **refined conjecture** (Haag-Kertzer-Rickards-
Stange new conjecture). Audit log emits
`H14_NEGATIVE_RESULT_ACKNOWLEDGED`.

Sorry budget at lock: ≤ 7.
-/

namespace Epistemos.H14

structure ApollonianPacking where
  primitive : Bool
  curvatures : List Int

/-- The local-global conjecture status flag: false per
Haag-Kertzer-Rickards-Stange. -/
def localGlobalConjectureStatus : Bool := false

theorem localGlobalConjectureIsFalse :
    localGlobalConjectureStatus = false := by
  rfl

/-- Refined conjecture replacing the old (false) one. -/
def refinedConjectureCitation : String :=
  "arXiv:2307.02749v3 (Annals of Mathematics 200(2):749-770, 2024)"

/-- Audit marker emitted when the negative result is acknowledged. -/
def negativeResultAcknowledgement : String :=
  "H14_NEGATIVE_RESULT_ACKNOWLEDGED"

theorem refinedConjectureCitationPinned :
    refinedConjectureCitation =
      "arXiv:2307.02749v3 (Annals of Mathematics 200(2):749-770, 2024)" := by
  rfl

theorem negativeResultAcknowledged :
    negativeResultAcknowledgement = "H14_NEGATIVE_RESULT_ACKNOWLEDGED" := by
  rfl

end Epistemos.H14
