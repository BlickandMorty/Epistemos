/-
Primitive IR Stack - EML schema authority.

This module is the Lean-side schema for the Rust mirror at
`agent_core/src/research/eml/`.

Source doctrine:
* `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.I
* `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §3
* `docs/T5_BLOCKER_LEDGER.md` LEAN-TOOLCHAIN row

Tooling status at iter-498:
Lean source emitted; `lake build` is gated because `elan`, `lean`,
and `lake` are not in PATH. Do not describe this module as
typechecked until the ledger's LEAN-TOOLCHAIN and LAKE-BUILD rows
resolve.
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

/-- Target type for Rust-generated EML certificates. The emitter should
construct a theorem or term establishing this structure for one
runtime-validated tree. -/
structure CertificateTarget where
  expr : Expr
  value : ℝ
  branch_safe : BranchSafe expr
  value_matches : Expr.eval expr = value
  positive_value : 0 < value

theorem CertificateTarget.eval_positive (c : CertificateTarget) :
    0 < Expr.eval c.expr := by
  rw [c.value_matches]
  exact c.positive_value

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

end Epistemos.EML
