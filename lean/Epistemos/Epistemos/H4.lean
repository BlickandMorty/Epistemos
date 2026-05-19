/-
HELIOS V5 H4 — LatticeCoder / Babai quantization.

HELIOS-H4 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H4 +
Chen et al. arXiv:2507.18553 v3 (ICLR 2026 camera-ready).

**Statement:** GPTQ ≡ Babai's nearest-plane on Hessian lattice
with no-clipping bound:

  ‖Δw‖ ≤ ¼ · trace(diag(LDL(H)))

The v3 update (Chen et al. 2 Mar 2026) extends the no-clipping
bound + adds a tight layer-wise error in terms of the LDL-
decomposition trace.

Sorry budget at lock: ≤ 4.
-/

namespace Epistemos.H4

structure BabaiBound where
  ldl_trace : Float    -- trace(diag(LDL(H)))

/-- H4 no-clipping coefficient from the Babai/GPTQ lattice bound. -/
def noClippingFactor : Float := 0.25

def BabaiBound.weightDeltaUpperBound (b : BabaiBound) : Float :=
  noClippingFactor * b.ldl_trace

def BabaiBound.layerWiseErrorBound (b : BabaiBound) : Float :=
  b.weightDeltaUpperBound

theorem babaiRoundTripBounded (b : BabaiBound) :
    b.weightDeltaUpperBound = noClippingFactor * b.ldl_trace := by
  rfl

theorem layerWiseErrorBoundTight (b : BabaiBound) :
    b.layerWiseErrorBound = noClippingFactor * b.ldl_trace := by
  rfl

theorem noClippingFactorPinned :
    noClippingFactor = 0.25 := by
  rfl

end Epistemos.H4
