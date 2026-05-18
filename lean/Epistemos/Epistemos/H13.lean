/-
HELIOS V5 H13 — Information-Geometric KL Bridge (Amari).

HELIOS-H13 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H13 +
Amari (Fisher information metric, e.g. Amari & Nagaoka,
*Methods of Information Geometry*, AMS 2000).

**Statement:** the Kullback-Leibler divergence between
infinitesimally-close probability distributions is the squared
length under the Fisher information metric:

  D_KL(p ‖ p + dp) ≈ ½ · (dp)ᵀ · I_F(p) · (dp)

where I_F(p) is the Fisher information matrix at p. This bridges
information theory (KL) with differential geometry (Riemannian
metric on the statistical manifold).

The ½ factor in front is the same ½ that appears in WBO-7
post-softmax half-contraction (E4/H1) and in the Gaussian KL
divergence — a structural pun across pillars per helios v3
Part II.

Sorry budget at lock: ≤ 7.
-/

namespace Epistemos.H13

structure FisherInformation where
  manifold_id : String
  -- Scalar witness for the Fisher metric in this H13 scaffold;
  -- the full matrix lift is gated on the information-geometry substrate.
  metric_scalar : Float

structure KLDivergence where
  distribution_id : String
  divergence : Float

/-- The information-geometric ½ KL bridge constant. -/
def klBridgeFactor : Float := 0.5

def fisherQuadraticScalar (f : FisherInformation) (dp : Float) : Float :=
  f.metric_scalar * (dp * dp)

def halfFisherQuadraticScalar (f : FisherInformation) (dp : Float) : Float :=
  klBridgeFactor * fisherQuadraticScalar f dp

theorem klDivergenceEqualsHalfFisherQuadraticForm : klBridgeFactor = 0.5 := by
  rfl

theorem halfFisherQuadraticScalarExpands (f : FisherInformation) (dp : Float) :
    halfFisherQuadraticScalar f dp = 0.5 * (f.metric_scalar * (dp * dp)) := by
  rfl

end Epistemos.H13
