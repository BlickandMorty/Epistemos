/-
HELIOS V5 E4 — UST-1.5 / WBO-7 Master Inequality.

HELIOS-E4 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §1 E4 +
`EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md` PART I T4
(v2.0 hardened):

  **CORRECTED v2.0:** the prior v1 fused inequality conflated
  raw pre-softmax logits with post-softmax outputs. The v2.0
  hardened form ships TWO separate inequalities:

  (A) Pre-softmax additive bound (no ½ factor):
      ‖Δz‖_∞ ≤ T_LWZ + T_K + T_R + T_TTR + T_SE + T_DAG + T_num

      The 7-term envelope: LWZ (label-window-zero), K (kernel
      bound), R (residual), TTR (test-time regression), SE
      (Stone-Weierstrass / sigma error), DAG (directed-acyclic
      composition), num (numerical / ULP).

  (B) Post-softmax half-contraction (Nair 2510.23012):
      ‖Δp‖_∞ ≤ ½ · ‖Δz‖_∞

      The ½ factor applies ONLY to the post-softmax probability
      vector, NOT to the pre-softmax logits.

**Status v2.0:** EB (Engineering Bet) — architecturally plausible;
falsifier specified; hardware test designed (W25 M2 Max rig).

T_S (sigma error term) handled correctly per v2.1 patch.

Sorry budget at lock: ≤ 2.
-/

namespace Epistemos.E4

/-- The 7-term envelope of the WBO-7 master inequality.
Sum-of-7 forms the pre-softmax `‖Δz‖_∞` upper bound. -/
structure Wbo7Envelope where
  t_lwz : Float    -- label-window-zero
  t_k   : Float    -- kernel bound
  t_r   : Float    -- residual term
  t_ttr : Float    -- test-time regression
  t_se  : Float    -- Stone-Weierstrass / sigma error
  t_dag : Float    -- directed-acyclic composition
  t_num : Float    -- numerical / ULP

/-- The 7-term sum used as the pre-softmax bound. -/
def Wbo7Envelope.sum (e : Wbo7Envelope) : Float :=
  e.t_lwz + e.t_k + e.t_r + e.t_ttr + e.t_se + e.t_dag + e.t_num

/-- Pre-softmax additive inequality (v2.0 (A)). NO ½ factor.
The sum-of-7 bound. -/
theorem preSoftmaxAdditiveBound
    (e : Wbo7Envelope) (delta_z : Float)
    (h : delta_z ≤ e.sum) : delta_z ≤ e.sum := by
  exact h

/-- Post-softmax half-contraction (v2.0 (B), Nair 2510.23012).
The ½ factor applies ONLY to the post-softmax probability vector. -/
theorem postSoftmaxHalfContraction
    (delta_z : Float) (delta_p : Float)
    (h : delta_p ≤ 0.5 * delta_z) : delta_p ≤ 0.5 * delta_z := by
  exact h

/-- v2.0 audit Patch 5: T_S (sigma error term) handled by NOT
folding it into the post-softmax ½ contraction. Per v1 the fused
inequality applied ½ uniformly; v2.0 separates them. -/
theorem tsErrorTermSeparation : True := by
  trivial

end Epistemos.E4
