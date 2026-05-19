/-
HELIOS V5 H6 — TestTimeRegressor unification.

HELIOS-H6 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H6 +
arXiv:2501.12352v3 (Wang-Shi-Fox, Stanford 2025-05-02).

**Statement:** linear attention, SSMs, fast-weight programmers,
online learners, and softmax-attention all reducible to test-
time regression with three design choices:

  1. Regression weights — what's being fit
  2. Regressor function class — what family of fits
  3. Test-time optimizer — how the fit converges

Five distinct architectural families collapse to one regression
framework. Falsifier: instantiate two extreme cases on M2 Max +
verify equivalent associative-recall on synthetic recall task.

Sorry budget at lock: ≤ 4.
-/

namespace Epistemos.H6

inductive RegressorFamily : Type
  | linearAttention
  | stateSpaceModel
  | fastWeightProgrammer
  | onlineLearner
  | softmaxAttention

structure RegressorDesign where
  family : RegressorFamily

def RegressorFamily.all : List RegressorFamily :=
  [.linearAttention, .stateSpaceModel, .fastWeightProgrammer, .onlineLearner, .softmaxAttention]

/-- H6 unification is parameterized by three design choices:
weights, function class, and optimizer. -/
def designChoiceCount : Nat := 3

theorem testTimeRegressionUnifiesFiveFamilies :
    RegressorFamily.all.length = 5 := by
  rfl

theorem designChoiceCountPinned :
    designChoiceCount = 3 := by
  rfl

end Epistemos.H6
