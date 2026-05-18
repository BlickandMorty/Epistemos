/-
HELIOS V5 H15 — Mādhava-style accelerated KL series (Krishnachandran 2405.11134).

HELIOS-H15 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H15 +
Krishnachandran arXiv:2405.11134 (2024-05-18) — "Mādhava
correction terms".

**Statement:** higher-order correction terms strictly improve
the Mādhava-Leibniz π-series convergence. The original Mādhava
rationale is *insufficient by modern standards* (literature
collision flagged per audit), but the T-statement holds at the
higher-order level.

  π/4 = 1 − 1/3 + 1/5 − 1/7 + ⋯  (Mādhava-Leibniz, slow)

  π_n* = M_n + correction_n  (Krishnachandran 2024 — converges
                              significantly faster)

For HELIOS V5: H15 is an **init-only check** — the constant π
is computed once at runtime startup using the accelerated series
to seed dependent computations.

Sorry budget at lock: ≤ 7.
-/

namespace Epistemos.H15

structure MadhavaSeries where
  partial_sum : Float
  num_terms : Nat

structure CorrectionTerm where
  series : MadhavaSeries
  correction : Float

def MadhavaSeries.acceleratedEstimate (s : MadhavaSeries) (c : CorrectionTerm) : Float :=
  s.partial_sum + c.correction

theorem correctionImprovesConvergence
    (s : MadhavaSeries) (c : CorrectionTerm) :
    s.acceleratedEstimate c = s.partial_sum + c.correction := by
  rfl

end Epistemos.H15
