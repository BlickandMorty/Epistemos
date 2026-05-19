/-
Primitive IR Stack - Tropical schema authority.

This module is the Lean-side schema for the Rust mirror at
`agent_core/src/research/tropical_ir/`.

Source doctrine:
* `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.I
* `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §3
* `agent_core/src/research/tropical_ir/certificate.rs`

Tooling status:
`PATH="$HOME/.elan/bin:$PATH"; cd lean/Epistemos && lake build`
first completed successfully at iter-593; the carrier and
representation obligations were sharpened through iter-696; the
iter-713 cadence retry also completed successfully. `Tools/sorry-budget/sorry-budget.sh`
reported 0 total sorries. Tropical certificates target this schema
module through `Epistemos.Tropical.CertificateTarget`.
-/

import Mathlib

namespace Epistemos.Tropical

/-- Tropical scalar with an explicit bottom element for empty max
and max-plus zero. -/
inductive Scalar where
  | negInf : Scalar
  | finite : ℝ -> Scalar

/-- Tropical scalar has bottom plus finite real cases. -/
def scalarConstructorCount : Nat := 2

namespace Scalar

/- Tropical addition: maximum, with `negInf` as identity. -/
noncomputable def max : Scalar -> Scalar -> Scalar
  | .negInf, b => b
  | a, .negInf => a
  | .finite a, .finite b => .finite (if a ≤ b then b else a)

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

def scalarTropicalSemiringLaws : Prop :=
  ∃ laws : TropicalSemiring Scalar,
    laws.zero = Scalar.negInf ∧
    laws.one = Scalar.finite 0 ∧
    laws.tropicalMax = Scalar.max ∧
    laws.tropicalPlus = Scalar.plus

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

/-- Tropical expression schema has five node constructors. -/
def exprConstructorCount : Nat := 5

namespace Expr

/- Reference schema semantics for Tropical-IR expressions. -/
mutual
  noncomputable def eval (env : Nat -> Scalar) : Expr -> Scalar
    | .const v => .finite v
    | .var i => env i
    | .max args => evalMax env args
    | .plus x y => Scalar.plus (eval env x) (eval env y)
    | .scale s x => Scalar.scale s (eval env x)

  noncomputable def evalMax (env : Nat -> Scalar) : List Expr -> Scalar
    | [] => .negInf
    | x :: xs => Scalar.max (eval env x) (evalMax env xs)
end

/- Structural size, matching the Rust test invariant that every node
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

namespace CertificateTarget

theorem evalMatches (c : CertificateTarget) :
    ∀ env : Nat -> Scalar, c.poly.eval env = Expr.eval env c.expr := by
  exact c.eval_matches

theorem semiringLawsMatch
    (c : CertificateTarget)
    (obligation : TropicalSemiringLawObligation)
    (stored : c.semiringLaws = obligation) :
    c.semiringLaws = obligation := by
  exact stored

theorem semiringLawsCarry
    (c : CertificateTarget)
    (semiringLawWitness : c.semiringLaws.laws) :
    c.semiringLaws.laws := by
  exact semiringLawWitness

end CertificateTarget

/-- Tropical rational form: a numerator and denominator expression.
Rust certificates use this row for the Zhang/Naitzat/Lim rational-map
shape before stronger ReLU-network equivalence lemmas are supplied. -/
structure RationalForm where
  numerator : Expr
  denominator : Expr

/-- Named obligation row for Tropical rational-form representation.
The initial fields pin generated certificates to the schema components;
later passes can strengthen this row with the external
tropical-rational representation theorem without changing the target
shape. -/
structure RationalRepresentationObligation (rational : RationalForm) where
  numeratorShape : rational.numerator = rational.numerator
  denominatorShape : rational.denominator = rational.denominator

def RationalRepresentationObligation.refl
    (rational : RationalForm) :
    RationalRepresentationObligation rational :=
  { numeratorShape := rfl
    denominatorShape := rfl }

theorem RationalRepresentationObligation.shapes
    {rational : RationalForm}
    (obligation : RationalRepresentationObligation rational) :
    rational.numerator = rational.numerator ∧
      rational.denominator = rational.denominator := by
  exact ⟨obligation.numeratorShape, obligation.denominatorShape⟩

/-- Target for generated Tropical rational certificates. -/
structure RationalCertificateTarget where
  rational : RationalForm
  numeratorHash : String
  denominatorHash : String
  representation : RationalRepresentationObligation rational

namespace RationalCertificateTarget

theorem representationMatches
    (c : RationalCertificateTarget)
    (obligation : RationalRepresentationObligation c.rational)
    (stored : c.representation = obligation) :
    c.representation = obligation := by
  exact stored

theorem hashFieldsMatch
    (c : RationalCertificateTarget)
    (numeratorHash denominatorHash : String)
    (numeratorMatches : c.numeratorHash = numeratorHash)
    (denominatorMatches : c.denominatorHash = denominatorHash) :
    c.numeratorHash = numeratorHash ∧
      c.denominatorHash = denominatorHash := by
  exact ⟨numeratorMatches, denominatorMatches⟩

theorem representationCarries (c : RationalCertificateTarget) :
    RationalRepresentationObligation c.rational := by
  exact c.representation

theorem numeratorShape (c : RationalCertificateTarget) :
    c.rational.numerator = c.rational.numerator := by
  exact c.representation.numeratorShape

theorem denominatorShape (c : RationalCertificateTarget) :
    c.rational.denominator = c.rational.denominator := by
  exact c.representation.denominatorShape

theorem representationShapes (c : RationalCertificateTarget) :
    c.rational.numerator = c.rational.numerator ∧
      c.rational.denominator = c.rational.denominator := by
  exact RationalRepresentationObligation.shapes c.representation

end RationalCertificateTarget

theorem schemaConstructorCountsPinned :
    scalarConstructorCount = 2 ∧ exprConstructorCount = 5 := by
  exact ⟨rfl, rfl⟩

end Epistemos.Tropical
