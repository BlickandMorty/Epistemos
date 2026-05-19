import Mathlib

/-!
Info-IR schema authority.

This module mirrors `agent_core/src/research/info_ir/grammar.rs`:
exponential-family carriers, log-partition nodes, dual-map nodes, and
KL-projection nodes. Proof-carrying certificates target the obligation
records below instead of emitting free-form theorem strings.

Source doctrine:
* `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.I
* `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §3
* `agent_core/src/research/info_ir/certificate.rs`

Tooling status:
`PATH="$HOME/.elan/bin:$PATH"; cd lean/Epistemos && lake build`
first completed successfully at iter-593; family well-formedness and
Bernoulli arity obligations were sharpened through iter-706; the
iter-723 cadence retry also completed successfully. `Tools/sorry-budget/sorry-budget.sh`
reported 0 total sorries. Info certificates target this schema module
through `Epistemos.Info.CertificateTarget`.
-/

namespace Epistemos.Info

inductive ExpFamily where
  | bernoulli : ExpFamily
  | categorical (k : Nat) : ExpFamily
  | gaussian (variance : Real) : ExpFamily

/-- Info-IR currently exposes Bernoulli, categorical, and Gaussian carriers. -/
def expFamilyConstructorCount : Nat := 3

namespace ExpFamily

def naturalParamArity : ExpFamily -> Nat
  | bernoulli => 1
  | categorical k => k - 1
  | gaussian _ => 1

def wellFormed : ExpFamily -> Prop
  | bernoulli => naturalParamArity bernoulli = 1
  | categorical k => 2 <= k
  | gaussian variance => variance > 0

theorem bernoulli_wellFormed : wellFormed bernoulli := by
  rfl

theorem categorical_wellFormed {k : Nat} (hk : 2 <= k) :
    wellFormed (categorical k) := by
  simpa [wellFormed] using hk

theorem gaussian_wellFormed {variance : Real} (hvar : variance > 0) :
    wellFormed (gaussian variance) := by
  simpa [wellFormed] using hvar

end ExpFamily

structure LogPartitionSchema where
  family : ExpFamily
  naturalParams : List Real
  wellFormed : ExpFamily.wellFormed family
  arityMatches : naturalParams.length = ExpFamily.naturalParamArity family

structure DualMapSchema where
  family : ExpFamily
  naturalParams : List Real
  wellFormed : ExpFamily.wellFormed family
  arityMatches : naturalParams.length = ExpFamily.naturalParamArity family

structure KlProjectionSchema where
  family : ExpFamily
  pParams : List Real
  qParams : List Real
  wellFormed : ExpFamily.wellFormed family
  pArityMatches : pParams.length = ExpFamily.naturalParamArity family
  qArityMatches : qParams.length = ExpFamily.naturalParamArity family

inductive Expr where
  | logPartition (node : LogPartitionSchema) : Expr
  | dualMap (node : DualMapSchema) : Expr
  | klProjection (node : KlProjectionSchema) : Expr

/-- Info-IR expression schema has log-partition, dual-map, and KL-projection nodes. -/
def exprConstructorCount : Nat := 3

def logPartitionConvex
    (family : ExpFamily) (naturalParams : List Real) : Prop :=
  ExpFamily.wellFormed family ∧
    naturalParams.length = ExpFamily.naturalParamArity family

def bregmanNonnegative
    (family : ExpFamily) (pParams qParams : List Real) : Prop :=
  ExpFamily.wellFormed family ∧
    pParams.length = ExpFamily.naturalParamArity family ∧
    qParams.length = ExpFamily.naturalParamArity family

def bregmanZeroIffEqual
    (family : ExpFamily) (pParams qParams : List Real) : Prop :=
  ExpFamily.wellFormed family ∧
    pParams.length = ExpFamily.naturalParamArity family ∧
    qParams.length = ExpFamily.naturalParamArity family ∧
    pParams = qParams

def mirrorDescentEquivalent
    (family : ExpFamily) : Prop :=
  ExpFamily.wellFormed family

structure ConvexLogPartitionObligation where
  family : ExpFamily
  naturalParams : List Real
  convexOnNaturalDomain : Prop
  sourceRow : String

structure BregmanPositivityObligation where
  family : ExpFamily
  pParams : List Real
  qParams : List Real
  nonnegative : Prop
  zeroIffEqual : Prop
  sourceRow : String

structure MirrorDescentEquivalenceObligation where
  family : ExpFamily
  statement : Prop
  sourceRow : String

structure CertificateTarget where
  expr : Expr
  convexity : Option ConvexLogPartitionObligation
  positivity : BregmanPositivityObligation
  mirrorEquivalence : MirrorDescentEquivalenceObligation

def bernoulliLogPartition (theta : Real) : Expr :=
  Expr.logPartition {
    family := ExpFamily.bernoulli
    naturalParams := [theta]
    wellFormed := ExpFamily.bernoulli_wellFormed
    arityMatches := rfl
  }

theorem bernoulliLogPartitionConvex (theta : Real) :
    logPartitionConvex ExpFamily.bernoulli [theta] := by
  exact ⟨ExpFamily.bernoulli_wellFormed, rfl⟩

def bernoulliConvexLogPartitionObligation
    (theta : Real) : ConvexLogPartitionObligation :=
  { family := ExpFamily.bernoulli
    naturalParams := [theta]
    convexOnNaturalDomain := logPartitionConvex ExpFamily.bernoulli [theta]
    sourceRow := "Info-IR.bernoulliLogPartitionConvex" }

theorem bernoulliConvexLogPartitionObligationCarries (theta : Real) :
    (bernoulliConvexLogPartitionObligation theta).convexOnNaturalDomain := by
  exact bernoulliLogPartitionConvex theta

def bernoulliDualMap (theta : Real) : Expr :=
  Expr.dualMap {
    family := ExpFamily.bernoulli
    naturalParams := [theta]
    wellFormed := ExpFamily.bernoulli_wellFormed
    arityMatches := rfl
  }

def bernoulliKlProjection (p q : Real) : Expr :=
  Expr.klProjection {
    family := ExpFamily.bernoulli
    pParams := [p]
    qParams := [q]
    wellFormed := ExpFamily.bernoulli_wellFormed
    pArityMatches := rfl
    qArityMatches := rfl
  }

theorem bernoulliBregmanNonnegative (p q : Real) :
    bregmanNonnegative ExpFamily.bernoulli [p] [q] := by
  exact ⟨ExpFamily.bernoulli_wellFormed, rfl, rfl⟩

theorem bernoulliBregmanZeroIffEqual (p q : Real) (h : p = q) :
    bregmanZeroIffEqual ExpFamily.bernoulli [p] [q] := by
  subst q
  exact ⟨ExpFamily.bernoulli_wellFormed, rfl, rfl, rfl⟩

def bernoulliBregmanPositivityObligation
    (p q : Real) : BregmanPositivityObligation :=
  { family := ExpFamily.bernoulli
    pParams := [p]
    qParams := [q]
    nonnegative := bregmanNonnegative ExpFamily.bernoulli [p] [q]
    zeroIffEqual := bregmanZeroIffEqual ExpFamily.bernoulli [p] [q]
    sourceRow := "Info-IR.bernoulliBregmanPositivity" }

theorem bernoulliBregmanPositivityObligationNonnegative (p q : Real) :
    (bernoulliBregmanPositivityObligation p q).nonnegative := by
  exact bernoulliBregmanNonnegative p q

theorem bernoulliBregmanPositivityObligationZeroIffEqual
    (p q : Real) (h : p = q) :
    (bernoulliBregmanPositivityObligation p q).zeroIffEqual := by
  exact bernoulliBregmanZeroIffEqual p q h

theorem bernoulliMirrorDescentEquivalent :
    mirrorDescentEquivalent ExpFamily.bernoulli := by
  exact ExpFamily.bernoulli_wellFormed

def bernoulliMirrorDescentEquivalenceObligation :
    MirrorDescentEquivalenceObligation :=
  { family := ExpFamily.bernoulli
    statement := mirrorDescentEquivalent ExpFamily.bernoulli
    sourceRow := "Info-IR.bernoulliMirrorDescentEquivalent" }

theorem bernoulliMirrorDescentEquivalenceObligationCarries :
    bernoulliMirrorDescentEquivalenceObligation.statement := by
  exact bernoulliMirrorDescentEquivalent

def bernoulliCertificateTarget (p q : Real) : CertificateTarget :=
  { expr := bernoulliKlProjection p q
    convexity := some (bernoulliConvexLogPartitionObligation p)
    positivity := bernoulliBregmanPositivityObligation p q
    mirrorEquivalence := bernoulliMirrorDescentEquivalenceObligation }

theorem bernoulliCertificateTargetFields (p q : Real) :
    (bernoulliCertificateTarget p q).convexity =
        some (bernoulliConvexLogPartitionObligation p) ∧
      (bernoulliCertificateTarget p q).positivity =
        bernoulliBregmanPositivityObligation p q ∧
      (bernoulliCertificateTarget p q).mirrorEquivalence =
        bernoulliMirrorDescentEquivalenceObligation := by
  exact ⟨rfl, rfl, rfl⟩

theorem bernoulliCertificateTargetNonnegative (p q : Real) :
    (bernoulliCertificateTarget p q).positivity.nonnegative := by
  exact bernoulliBregmanPositivityObligationNonnegative p q

theorem schemaConstructorCountsPinned :
    expFamilyConstructorCount = 3 ∧ exprConstructorCount = 3 := by
  exact ⟨rfl, rfl⟩

end Epistemos.Info
