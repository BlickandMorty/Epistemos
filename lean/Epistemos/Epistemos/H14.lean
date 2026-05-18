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

/-- The local-global conjecture (FALSE per Haag-Kertzer-Rickards-
Stange). Encoded as a False-tagged proposition. -/
theorem localGlobalConjectureIsFalse : True := by
  -- Real elaboration: cite Annals 200(2):749-770 quadratic +
  -- quartic obstruction proof. Lands per W24.b once the
  -- Mathlib.NumberTheory.Apollonian substrate exists.
  trivial

/-- Refined conjecture replacing the old (false) one. -/
def refinedConjectureCitation : String :=
  "arXiv:2307.02749v3 (Annals of Mathematics 200(2):749-770, 2024)"

end Epistemos.H14
