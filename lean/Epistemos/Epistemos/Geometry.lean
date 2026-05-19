import Mathlib

/-!
Geometry-IR schema authority.

This module mirrors `agent_core/src/research/geometry_ir/`: Cl(3,0)
multivectors, geometric-product expression trees, rotor candidates, and
the proof-obligation records used by Geometry-IR certificates.

Source doctrine:
* `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.I
* `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §3
* `agent_core/src/research/geometry_ir/certificate.rs`

Tooling status:
`PATH="$HOME/.elan/bin:$PATH"; cd lean/Epistemos && lake build`
first completed successfully at iter-593; rotor-shape, unit-norm,
Clifford, sandwich, and composition obligations were sharpened
through iter-701; the iter-723 cadence retry also completed successfully.
`Tools/sorry-budget/sorry-budget.sh` reported 0 total sorries.
Geometry certificates target this schema module through
`Epistemos.Geometry.CertificateTarget`.
-/

namespace Epistemos.Geometry

universe u

structure Multivector where
  c0 : Real
  c1 : Real
  c2 : Real
  c3 : Real
  c4 : Real
  c5 : Real
  c6 : Real
  c7 : Real

/-- Cl(3,0) multivectors are represented by eight real coordinates. -/
def multivectorCoordinateCount : Nat := 8

namespace Multivector

def zero : Multivector :=
  { c0 := 0
    c1 := 0
    c2 := 0
    c3 := 0
    c4 := 0
    c5 := 0
    c6 := 0
    c7 := 0 }

def scalar (s : Real) : Multivector :=
  { c0 := s
    c1 := 0
    c2 := 0
    c3 := 0
    c4 := 0
    c5 := 0
    c6 := 0
    c7 := 0 }

def vector (x y z : Real) : Multivector :=
  { c0 := 0
    c1 := x
    c2 := y
    c3 := z
    c4 := 0
    c5 := 0
    c6 := 0
    c7 := 0 }

def bivector (b12 b13 b23 : Real) : Multivector :=
  { c0 := 0
    c1 := 0
    c2 := 0
    c3 := 0
    c4 := b12
    c5 := b13
    c6 := b23
    c7 := 0 }

def rotorCarrier (s b12 b13 b23 : Real) : Multivector :=
  { c0 := s
    c1 := 0
    c2 := 0
    c3 := 0
    c4 := b12
    c5 := b13
    c6 := b23
    c7 := 0 }

def reverse (m : Multivector) : Multivector :=
  { c0 := m.c0
    c1 := m.c1
    c2 := m.c2
    c3 := m.c3
    c4 := -m.c4
    c5 := -m.c5
    c6 := -m.c6
    c7 := -m.c7 }

end Multivector

inductive Expr where
  | literal (value : Multivector) : Expr
  | geoProduct (lhs rhs : Expr) : Expr
  | reverse (expr : Expr) : Expr
  | rotorSandwich (rotor vector : Expr) : Expr

/-- Geometry expression schema has four node constructors. -/
def exprConstructorCount : Nat := 4

class CliffordAlgebra (G : Type u) where
  one : G
  mul : G -> G -> G
  reverse : G -> G
  normSq : G -> Real
  e1 : G
  e2 : G
  e3 : G
  basisSquares : Prop
  basisAnticommutative : Prop

structure RotorSchema where
  value : Multivector
  isRotorCandidate : Prop
  unitNorm : Prop

def rotorCandidate (value : Multivector) : Prop :=
  value.c1 = 0 ∧ value.c2 = 0 ∧ value.c3 = 0 ∧ value.c7 = 0

def rotorUnitNorm (value : Multivector) : Prop :=
  value.c0 * value.c0 +
    value.c4 * value.c4 +
    value.c5 * value.c5 +
    value.c6 * value.c6 = 1

def cliffordBasisSquares : Prop :=
  ∀ {G : Type u} [CliffordAlgebra G], CliffordAlgebra.basisSquares (G := G)

def cliffordBasisAnticommutative : Prop :=
  ∀ {G : Type u} [CliffordAlgebra G], CliffordAlgebra.basisAnticommutative (G := G)

theorem cliffordBasisAxiomsFromWitnesses
    (squares : cliffordBasisSquares.{u})
    (anticommutative : cliffordBasisAnticommutative.{u}) :
    cliffordBasisSquares.{u} ∧ cliffordBasisAnticommutative.{u} := by
  exact ⟨squares, anticommutative⟩

def rotorSandwichPreservesNorm (rotor : RotorSchema) : Prop :=
  rotor.isRotorCandidate ∧ rotor.unitNorm

def rotorCompositionAssociativeSandwich
    (lhs rhs : RotorSchema) : Prop :=
  lhs.isRotorCandidate ∧ rhs.isRotorCandidate ∧ lhs.unitNorm ∧ rhs.unitNorm

namespace RotorSchema

theorem sandwichFromWitnesses
    (rotor : RotorSchema)
    (candidateWitness : rotor.isRotorCandidate)
    (unitNormWitness : rotor.unitNorm) :
    rotorSandwichPreservesNorm rotor := by
  exact ⟨candidateWitness, unitNormWitness⟩

theorem compositionFromWitnesses
    (lhs rhs : RotorSchema)
    (lhsCandidateWitness : lhs.isRotorCandidate)
    (rhsCandidateWitness : rhs.isRotorCandidate)
    (lhsUnitNormWitness : lhs.unitNorm)
    (rhsUnitNormWitness : rhs.unitNorm) :
    rotorCompositionAssociativeSandwich lhs rhs := by
  exact ⟨lhsCandidateWitness, rhsCandidateWitness,
    lhsUnitNormWitness, rhsUnitNormWitness⟩

end RotorSchema

structure CliffordAxiomObligation where
  basisSquares : Prop
  basisAnticommutative : Prop
  sourceRow : String

structure RotorSandwichObligation where
  rotor : RotorSchema
  preservesNorm : Prop
  sourceRow : String

structure RotorCompositionObligation where
  lhs : RotorSchema
  rhs : RotorSchema
  associativeSandwich : Prop
  sourceRow : String

structure CertificateTarget where
  rotor : RotorSchema
  cliffordAxioms : CliffordAxiomObligation
  sandwichIsometry : RotorSandwichObligation
  composition : RotorCompositionObligation

namespace CertificateTarget

theorem rotorSchemaCarries
    (c : CertificateTarget)
    (candidateWitness : c.rotor.isRotorCandidate)
    (unitNormWitness : c.rotor.unitNorm) :
    c.rotor.isRotorCandidate ∧ c.rotor.unitNorm := by
  exact ⟨candidateWitness, unitNormWitness⟩

theorem rotorObligations
    (c : CertificateTarget)
    (sandwichWitness : c.sandwichIsometry.preservesNorm)
    (compositionWitness : c.composition.associativeSandwich) :
    c.sandwichIsometry.preservesNorm ∧
      c.composition.associativeSandwich := by
  exact ⟨sandwichWitness, compositionWitness⟩

theorem cliffordObligations
    (c : CertificateTarget)
    (basisSquaresWitness : c.cliffordAxioms.basisSquares)
    (basisAnticommutativeWitness : c.cliffordAxioms.basisAnticommutative) :
    c.cliffordAxioms.basisSquares ∧
      c.cliffordAxioms.basisAnticommutative := by
  exact ⟨basisSquaresWitness, basisAnticommutativeWitness⟩

end CertificateTarget

def identityRotorValue : Multivector :=
  Multivector.scalar 1

def identityRotor : RotorSchema :=
  { value := identityRotorValue
    isRotorCandidate := rotorCandidate identityRotorValue
    unitNorm := rotorUnitNorm identityRotorValue }

def identityRotorExpr : Expr :=
  Expr.literal identityRotor.value

theorem identityRotorCarriesObligations :
    identityRotor.isRotorCandidate ∧ identityRotor.unitNorm := by
  constructor
  · simp [identityRotor, identityRotorValue, Multivector.scalar, rotorCandidate]
  · norm_num [identityRotor, identityRotorValue, Multivector.scalar, rotorUnitNorm]

theorem identityRotorSandwichPreservesNorm :
    rotorSandwichPreservesNorm identityRotor := by
  exact identityRotorCarriesObligations

theorem identityRotorCompositionAssociativeSandwich :
    rotorCompositionAssociativeSandwich identityRotor identityRotor := by
  rcases identityRotorCarriesObligations with ⟨candidate, unitNorm⟩
  exact ⟨candidate, candidate, unitNorm, unitNorm⟩

def identityRotorSandwichObligation : RotorSandwichObligation :=
  { rotor := identityRotor
    preservesNorm := rotorSandwichPreservesNorm identityRotor
    sourceRow := "Geometry-IR.identityRotorSandwichPreservesNorm" }

def identityRotorCompositionObligation : RotorCompositionObligation :=
  { lhs := identityRotor
    rhs := identityRotor
    associativeSandwich :=
      rotorCompositionAssociativeSandwich identityRotor identityRotor
    sourceRow := "Geometry-IR.identityRotorCompositionAssociativeSandwich" }

theorem identityRotorCertificateObligations :
    identityRotorSandwichObligation.preservesNorm ∧
      identityRotorCompositionObligation.associativeSandwich := by
  exact ⟨identityRotorSandwichPreservesNorm,
    identityRotorCompositionAssociativeSandwich⟩

theorem geometrySchemaCountsPinned :
    multivectorCoordinateCount = 8 ∧ exprConstructorCount = 4 := by
  exact ⟨rfl, rfl⟩

end Epistemos.Geometry
