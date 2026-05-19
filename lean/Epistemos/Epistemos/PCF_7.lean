/-
HELIOS V5 PCF-7 — DualConnectomeTrace.

HELIOS-PCF-7 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §3 PCF-7 +
Bushnaq-Braun-Sharkey 2025 (SPD) + Bricken et al. 2023 (SAE) +
Cunningham et al. 2023 (sparse autoencoders).

**Statement (CANDIDATE, Lane 3):** a dual decomposition combining
parameter-space (SPD) and activation-space (SAE) is *more
faithful* than either alone:

  MSE(SPD ⊕ SAE joint) < min(MSE(SPD only), MSE(SAE only))

The two decompositions are complementary; their union strictly
improves reconstruction.

**Falsifier:** joint reconstruction MSE strictly less than
min(SPD-only, SAE-only) on toy benchmark.

Lane 3 RESEARCH-ONLY.

Sorry budget at lock: ≤ 7.
-/

namespace Epistemos.PCF7

structure DualTraceSample where
  token_position : Nat
  layer : Nat
  param_activations : List Float    -- SPD
  act_activations : List Float       -- SAE

structure DualConnectomeTrace where
  trace_id : String
  samples : List DualTraceSample

def DualConnectomeTrace.sampleCount (t : DualConnectomeTrace) : Nat :=
  t.samples.length

/-- PCF-7 remains a Lane 3 research-only dual-decomposition trace. -/
def lane3ResearchOnly : Bool := true

theorem emptyDualTraceHasZeroSamples :
    ({ trace_id := "empty-dual-trace", samples := [] } : DualConnectomeTrace).sampleCount = 0 := by
  rfl

theorem singletonDualTraceHasOneSample
    (trace_id : String) (token_position layer : Nat)
    (param_activations act_activations : List Float) :
    ({ trace_id := trace_id
       samples := [{ token_position := token_position
                     layer := layer
                     param_activations := param_activations
                     act_activations := act_activations }] } : DualConnectomeTrace).sampleCount = 1 := by
  rfl

theorem lane3ResearchOnlyPinned :
    lane3ResearchOnly = true := by
  rfl

end Epistemos.PCF7
