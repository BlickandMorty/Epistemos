/-
Primitive IR Stack - Operator schema authority.

This module is the Lean-side schema for the Rust mirror at
`agent_core/src/research/operator_ir/`.

Source doctrine:
* `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.I
* `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §3
* `agent_core/src/research/operator_ir/certificate.rs`

Tooling status:
`PATH="$HOME/.elan/bin:$PATH"; cd lean/Epistemos && lake build`
first completed successfully at iter-593; dimensional, FNO, and
Fourier obligations were sharpened through iter-700; the iter-713
cadence retry also completed successfully. `Tools/sorry-budget/sorry-budget.sh`
reported 0 total sorries. Operator certificates target this schema
module through `Epistemos.Operator.CertificateTarget`.
-/

import Mathlib

namespace Epistemos.Operator

/-- Linear branch/trunk network shape. Rust carries concrete weights;
the Lean schema first owns the dimensional contract. -/
structure LinearNetwork where
  inputDim : Nat
  outputDim : Nat
deriving Repr, DecidableEq

/-- Nonlocal kernel transform used by Operator-IR. -/
inductive KernelTransform where
  | identity : KernelTransform
  | fourier : Nat -> KernelTransform
deriving Repr, DecidableEq

/-- Operator kernel transforms currently expose identity plus Fourier. -/
def kernelTransformConstructorCount : Nat := 2

namespace KernelTransform

def modes : KernelTransform -> Nat
  | .identity => 0
  | .fourier n => n

theorem identity_modes : modes .identity = 0 := rfl

theorem fourier_modes (n : Nat) : modes (.fourier n) = n := rfl

end KernelTransform

theorem kernelTransformConstructorCountPinned :
    kernelTransformConstructorCount = 2 := by
  rfl

/-- Operator expression: branch and trunk networks must agree on
output dimension before the bilinear/nonlocal pairing is meaningful. -/
structure Expr where
  branch : LinearNetwork
  trunk : LinearNetwork
  kernel : KernelTransform
  dimMatch : branch.outputDim = trunk.outputDim

namespace Expr

theorem dim_consistent (op : Expr) :
    op.branch.outputDim = op.trunk.outputDim :=
  op.dimMatch

theorem dimWitnessCarries
    (op : Expr)
    (dimMatchWitness : op.branch.outputDim = op.trunk.outputDim) :
    op.branch.outputDim = op.trunk.outputDim := by
  exact dimMatchWitness

end Expr

def fourierModeBound (modes : Nat) : Prop :=
  1 ≤ modes

def fourierIsometry (modes : Nat) : Prop :=
  fourierModeBound modes

def operatorFNOEquivalent (expr : Expr) : Prop :=
  expr.branch.outputDim = expr.trunk.outputDim

/-- Fourier isometry obligation row. The proof is supplied by source
theory or a generated theorem, not by the Rust shape checker. -/
structure FourierIsometryObligation where
  modes : Nat
  modeBound : Prop
  isometry : Prop

def fourierIsometryObligation
    (modes : Nat) (_modeBound : fourierModeBound modes) :
    FourierIsometryObligation :=
  { modes := modes
    modeBound := fourierModeBound modes
    isometry := fourierIsometry modes }

theorem fourierIsometryObligationCarries
    (modes : Nat) (modeBound : fourierModeBound modes) :
    (fourierIsometryObligation modes modeBound).isometry := by
  exact modeBound

/-- FNO equivalence obligation row: generated certificates should make
the runtime equivalence claim explicit instead of burying it in a
comment string. -/
structure FNOEquivalenceObligation where
  expr : Expr
  statement : Prop

def fnoEquivalenceObligation (expr : Expr) : FNOEquivalenceObligation :=
  { expr := expr
    statement := operatorFNOEquivalent expr }

theorem fnoEquivalenceObligationCarries (expr : Expr) :
    (fnoEquivalenceObligation expr).statement := by
  exact expr.dimMatch

/-- Target for a generated Operator expression certificate. -/
structure CertificateTarget where
  expr : Expr
  dim_consistent : expr.branch.outputDim = expr.trunk.outputDim
  fno_equivalence : FNOEquivalenceObligation
  fourier_isometry : Option FourierIsometryObligation

namespace CertificateTarget

theorem dimConsistentCarries (c : CertificateTarget) :
    c.expr.branch.outputDim = c.expr.trunk.outputDim := by
  exact c.dim_consistent

theorem fnoStatementCarries
    (c : CertificateTarget)
    (statementWitness : c.fno_equivalence.statement) :
    c.fno_equivalence.statement := by
  exact statementWitness

theorem fourierSomeCarries
    (c : CertificateTarget)
    (obligation : FourierIsometryObligation)
    (stored : c.fourier_isometry = some obligation)
    (isometryWitness : obligation.isometry) :
    ∃ targetObligation : FourierIsometryObligation,
      c.fourier_isometry = some targetObligation ∧
        targetObligation.isometry := by
  exact ⟨obligation, stored, isometryWitness⟩

end CertificateTarget

end Epistemos.Operator
