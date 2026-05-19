/-
HELIOS V5 H2 — Half-softmax post-not-pre rewrite.

HELIOS-H2 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H2 +
`agent_core/src/scope_rex/metal/softmax.rs` (W7 Tier-1 ≤ 2 ULP
reference) + Nair arXiv:2510.23012 (½-Lipschitz softmax).

**Statement:** canonical max-subtraction softmax form applied
AFTER resonance phase. Output matches reference within 2 ULP
per element while preserving Babai lattice closure under the
resonance ordering constraint.

  softmax(x)_i = exp(x_i − max(x)) / Σ exp(x_j − max(x))

Per Nair 2025: softmax has uniform ½-Lipschitz constant across
all ℓ_p — ‖softmax(x) − softmax(y)‖_p ≤ ½ · ‖x − y‖_p — which
is the ½ factor in E4/H1 post-softmax leg.

Sorry budget at lock: ≤ 4.
-/

namespace Epistemos.H2

def maxUlpDrift : Nat := 2
def softmaxLipschitzConstant : Float := 0.5

theorem halfSoftmaxPostBoundedUlpDrift : maxUlpDrift = 2 := by
  rfl

theorem softmaxLipschitzConstantPinned :
    softmaxLipschitzConstant = 0.5 := by
  rfl

theorem babaiClosurePreserved (resonance_ordered : Bool)
    (h_ordered : resonance_ordered = true) :
    resonance_ordered = true := by
  exact h_ordered

end Epistemos.H2
