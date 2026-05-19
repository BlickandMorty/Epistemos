/-
Primitive IR Stack - EML schema authority.

This module is the Lean-side schema for the Rust mirror at
`agent_core/src/research/eml/`.

Source doctrine:
* `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.I
* `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §3
* `docs/T5_BLOCKER_LEDGER.md` LEAN-TOOLCHAIN row

Tooling status:
`PATH="$HOME/.elan/bin:$PATH"; cd lean/Epistemos && lake build`
first completed successfully at iter-593; generated certificate
projection obligations were sharpened through iter-629; the iter-723
cadence retry also completed successfully. `Tools/sorry-budget/sorry-budget.sh`
reported 0 total sorries. Generated runtime certificates may still
carry explicit per-tree proof obligations when the Rust evaluator
caches non-symbolic floating values.
-/

import Mathlib

namespace Epistemos.EML

/-- EML term algebra: terminal `1` plus the binary primitive
`eml(x, y) = exp(x) - log(y)`. This mirrors
`agent_core/src/research/eml/grammar.rs`. -/
inductive Expr where
  | one : Expr
  | eml : Expr -> Expr -> Expr
deriving Repr, DecidableEq

/-- EML's schema-level term algebra has one terminal constructor
and one binary primitive constructor. -/
def exprConstructorCount : Nat := 2

namespace Expr

/-- Reference real semantics for the EML primitive. Rust executes the
floating mirror; Lean owns the schema and proof obligations. -/
noncomputable def eval : Expr -> ℝ
  | .one => 1
  | .eml x y => Real.exp (eval x) - Real.log (eval y)

/-- Structural node count, used by generated certificate metadata. -/
def size : Expr -> Nat
  | .one => 1
  | .eml x y => 1 + size x + size y

/-- Structural depth, with `one` at depth zero. -/
def depth : Expr -> Nat
  | .one => 0
  | .eml x y => 1 + max (depth x) (depth y)

theorem eval_one : eval .one = (1 : ℝ) := rfl

theorem eval_eml (x y : Expr) :
    eval (.eml x y) = Real.exp (eval x) - Real.log (eval y) := rfl

theorem size_one : size .one = 1 := rfl

theorem depth_one : depth .one = 0 := rfl

end Expr

/-- Branch-safety for EML: every right child of an `eml(_, y)` node
must have positive real semantics before `Real.log` is meaningful for
the intended elementary-function interpretation. -/
inductive BranchSafe : Expr -> Prop where
  | one : BranchSafe .one
  | eml {x y : Expr} :
      BranchSafe x ->
      BranchSafe y ->
      0 < Expr.eval y ->
      BranchSafe (.eml x y)

theorem one_branch_safe : BranchSafe .one := BranchSafe.one

theorem eml_node_branch_safe {x y : Expr}
    (hx : BranchSafe x)
    (hy : BranchSafe y)
    (hy_pos : 0 < Expr.eval y) :
    BranchSafe (.eml x y) :=
  BranchSafe.eml hx hy hy_pos

theorem eval_eml_right_one_positive (x : Expr) :
    0 < Expr.eval (Expr.eml x Expr.one) := by
  simpa [Expr.eval] using Real.exp_pos (Expr.eval x)

/-- Target type for Rust-generated EML certificates. The emitter should
construct a theorem or term establishing this structure for one
runtime-validated tree. -/
structure CertificateTarget where
  expr : Expr
  value : ℝ
  branch_safe : BranchSafe expr
  value_matches : Expr.eval expr = value
  positive_value : 0 < value

/-- Runtime evaluator witness for non-symbolic EML values. Rust may
cache a floating value for a well-formed tree; generated certificates
must carry this witness rather than hiding the equality proof. -/
structure RuntimeEvalWitness (expr : Expr) (value : ℝ) where
  value_matches : Expr.eval expr = value

/-- Runtime branch-safety witness for positive EML typestate trees
whose right-child positivity is not discharged by the current symbolic
schema lemmas. Generated certificates carry this witness explicitly
instead of emitting a hidden proof body. -/
structure RuntimeBranchSafeWitness (expr : Expr) where
  branch_safe : BranchSafe expr

theorem CertificateTarget.eval_positive (c : CertificateTarget) :
    0 < Expr.eval c.expr := by
  rw [c.value_matches]
  exact c.positive_value

def oneCertificateTarget : CertificateTarget :=
  { expr := Expr.one
    value := 1
    branch_safe := one_branch_safe
    value_matches := Expr.eval_one
    positive_value := by norm_num }

theorem oneCertificateTargetEvalPositive :
    0 < Expr.eval oneCertificateTarget.expr :=
  CertificateTarget.eval_positive oneCertificateTarget

/-- A sharper named obligation for generated certificates: the only
nontrivial branch condition at an EML node is positivity of the right
child. -/
structure BranchObligation where
  left : Expr
  right : Expr
  left_safe : BranchSafe left
  right_safe : BranchSafe right
  right_positive : 0 < Expr.eval right

theorem BranchObligation.discharge (o : BranchObligation) :
    BranchSafe (.eml o.left o.right) :=
  BranchSafe.eml o.left_safe o.right_safe o.right_positive

theorem exprConstructorCountPinned :
    exprConstructorCount = 2 := by
  rfl

end Epistemos.EML
