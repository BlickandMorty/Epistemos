/-
Primitive IR Stack - Tropical schema authority.

This module is the Lean-side schema for the Rust mirror at
`agent_core/src/research/tropical_ir/`.

Source doctrine:
* `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.I
* `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §3
* `agent_core/src/research/tropical_ir/certificate.rs`

Tooling status at iter-500:
Lean source emitted; `lake build` is gated because `elan`, `lean`,
and `lake` are not in PATH. Do not describe this module as
typechecked until the ledger's LEAN-TOOLCHAIN and LAKE-BUILD rows
resolve.
-/

import Mathlib

namespace Epistemos.Tropical

/-- Tropical scalar with an explicit bottom element for empty max
and max-plus zero. -/
inductive Scalar where
  | negInf : Scalar
  | finite : ℝ -> Scalar
deriving Repr, DecidableEq

namespace Scalar

/-- Tropical addition: maximum, with `negInf` as identity. -/
def max : Scalar -> Scalar -> Scalar
  | .negInf, b => b
  | a, .negInf => a
  | .finite a, .finite b => .finite (_root_.max a b)

/-- Tropical multiplication: ordinary addition, absorbing at bottom. -/
def plus : Scalar -> Scalar -> Scalar
  | .negInf, _ => .negInf
  | _, .negInf => .negInf
  | .finite a, .finite b => .finite (a + b)

/-- Real scaling extension used by the Rust `Scale` node. -/
def scale (s : ℝ) : Scalar -> Scalar
  | .negInf => .negInf
  | .finite a => .finite (s * a)

theorem max_negInf_left (x : Scalar) : max .negInf x = x := by
  cases x <;> rfl

theorem max_negInf_right (x : Scalar) : max x .negInf = x := by
  cases x <;> rfl

theorem plus_negInf_left (x : Scalar) : plus .negInf x = .negInf := by
  cases x <;> rfl

theorem plus_negInf_right (x : Scalar) : plus x .negInf = .negInf := by
  cases x <;> rfl

end Scalar

/-- Algebraic law surface required of any max-plus carrier used by
Tropical-IR certificates. Proof fields make the obligation explicit
without forcing generated certificates to invent the algebra. -/
structure TropicalSemiring (α : Type) where
  zero : α
  one : α
  tropicalMax : α -> α -> α
  tropicalPlus : α -> α -> α
  max_assoc :
    ∀ a b c : α,
      tropicalMax (tropicalMax a b) c = tropicalMax a (tropicalMax b c)
  max_comm :
    ∀ a b : α, tropicalMax a b = tropicalMax b a
  max_idem :
    ∀ a : α, tropicalMax a a = a
  plus_assoc :
    ∀ a b c : α,
      tropicalPlus (tropicalPlus a b) c = tropicalPlus a (tropicalPlus b c)
  left_distrib :
    ∀ a b c : α,
      tropicalPlus a (tropicalMax b c) =
        tropicalMax (tropicalPlus a b) (tropicalPlus a c)
  right_distrib :
    ∀ a b c : α,
      tropicalPlus (tropicalMax a b) c =
        tropicalMax (tropicalPlus a c) (tropicalPlus b c)

opaque scalarTropicalSemiringLaws : Prop := True

structure TropicalSemiringLawObligation where
  carrierName : String
  laws : Prop
  sourceRow : String

/-- Rust `TropicalExpr`: constants, variables, finite/empty max,
max-plus multiplication, and real scaling. -/
inductive Expr where
  | const : ℝ -> Expr
  | var : Nat -> Expr
  | max : List Expr -> Expr
  | plus : Expr -> Expr -> Expr
  | scale : ℝ -> Expr -> Expr
deriving Repr, DecidableEq

namespace Expr

/-- Reference schema semantics for Tropical-IR expressions. -/
mutual
  def eval (env : Nat -> Scalar) : Expr -> Scalar
    | .const v => .finite v
    | .var i => env i
    | .max args => evalMax env args
    | .plus x y => Scalar.plus (eval env x) (eval env y)
    | .scale s x => Scalar.scale s (eval env x)

  def evalMax (env : Nat -> Scalar) : List Expr -> Scalar
    | [] => .negInf
    | x :: xs => Scalar.max (eval env x) (evalMax env xs)
end

/-- Structural size, matching the Rust test invariant that every node
is counted once. -/
mutual
  def size : Expr -> Nat
    | .const _ => 1
    | .var _ => 1
    | .max args => 1 + sizeList args
    | .plus x y => 1 + size x + size y
    | .scale _ x => 1 + size x

  def sizeList : List Expr -> Nat
    | [] => 0
    | x :: xs => size x + sizeList xs
end

theorem eval_const (env : Nat -> Scalar) (v : ℝ) :
    eval env (.const v) = .finite v := rfl

theorem eval_var (env : Nat -> Scalar) (i : Nat) :
    eval env (.var i) = env i := rfl

theorem eval_empty_max (env : Nat -> Scalar) :
    eval env (.max []) = .negInf := rfl

end Expr

/-- Max-plus polynomial schema row used by Rust-generated
certificates. `arity` is metadata; `eval` is the carrier semantics. -/
structure MaxPlusPoly where
  arity : Nat
  eval : (Nat -> Scalar) -> Scalar

/-- Target for a generated Tropical expression certificate. -/
structure CertificateTarget where
  expr : Expr
  arity : Nat
  poly : MaxPlusPoly
  eval_matches :
    ∀ env : Nat -> Scalar, poly.eval env = Expr.eval env expr
  semiringLaws : TropicalSemiringLawObligation

end Epistemos.Tropical
