/-
HELIOS V5 PCF-3 — ParamAttributionGraph.

HELIOS-PCF-3 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §3 PCF-3.

**Statement (CANDIDATE):** the ParamAttributionGraph is a
directed graph over parameter components where edges carry
attribution weight in [0, 1]. The graph captures which
components contribute to which downstream decisions.

  edges : src_component → list of (dst_component, weight)

Visualization research artifact. NOT a behavioral hypothesis
about the model — purely an analytical surface.

Lane 3 RESEARCH-ONLY.

Sorry budget at lock: ≤ 5.
-/

namespace Epistemos.PCF3

structure AttributionEdge where
  src    : Nat
  dst    : Nat
  weight : Float    -- ∈ [0, 1]

structure ParamAttributionGraph where
  edges : List AttributionEdge

def AttributionEdge.weightInUnitInterval (e : AttributionEdge) : Bool :=
  e.weight ≥ 0.0 && e.weight ≤ 1.0

def ParamAttributionGraph.allWeightsInUnitInterval (g : ParamAttributionGraph) : Bool :=
  g.edges.all AttributionEdge.weightInUnitInterval

theorem emptyGraphWeightsInUnitInterval :
    ({ edges := [] } : ParamAttributionGraph).allWeightsInUnitInterval = true := by
  rfl

end Epistemos.PCF3
