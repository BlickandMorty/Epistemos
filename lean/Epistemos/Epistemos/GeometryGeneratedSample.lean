import Epistemos.Geometry

/-!
Handwritten generated-shape sample for Geometry-IR certificate targets.

This checks the identity-rotor path through `CertificateTarget` and
the named sandwich/composition obligation rows. Generic Clifford axiom
witnesses remain external source obligations.
-/

namespace Epistemos.Geometry.Generated

def geometry_rotor_value_sample : Epistemos.Geometry.Multivector :=
  Epistemos.Geometry.identityRotorValue

def geometry_rotor_sample : Epistemos.Geometry.RotorSchema :=
  Epistemos.Geometry.identityRotor

def geometry_clifford_obligation_sample :
    Epistemos.Geometry.CliffordAxiomObligation :=
  { basisSquares := Epistemos.Geometry.cliffordBasisSquares.{0}
    basisAnticommutative := Epistemos.Geometry.cliffordBasisAnticommutative.{0}
    sourceRow := "Hestenes-Sobczyk 1984 Ch. 1" }

def geometry_sandwich_obligation_sample :
    Epistemos.Geometry.RotorSandwichObligation :=
  Epistemos.Geometry.identityRotorSandwichObligation

def geometry_composition_obligation_sample :
    Epistemos.Geometry.RotorCompositionObligation :=
  Epistemos.Geometry.identityRotorCompositionObligation

def geometry_certificate_sample :
    Epistemos.Geometry.CertificateTarget :=
  { rotor := geometry_rotor_sample
    cliffordAxioms := geometry_clifford_obligation_sample
    sandwichIsometry := geometry_sandwich_obligation_sample
    composition := geometry_composition_obligation_sample }

theorem rotor_candidate_sample :
    geometry_rotor_sample.isRotorCandidate := by
  rcases Epistemos.Geometry.identityRotorCarriesObligations with ⟨candidate, _⟩
  exact candidate

theorem rotor_unit_norm_sample :
    geometry_rotor_sample.unitNorm := by
  rcases Epistemos.Geometry.identityRotorCarriesObligations with ⟨_, unitNorm⟩
  exact unitNorm

theorem geometry_certificate_rotor_schema_sample :
    geometry_certificate_sample.rotor.isRotorCandidate ∧
      geometry_certificate_sample.rotor.unitNorm := by
  exact Epistemos.Geometry.CertificateTarget.rotorSchemaCarries
    geometry_certificate_sample rotor_candidate_sample rotor_unit_norm_sample

theorem geometry_certificate_obligations_sample :
    geometry_certificate_sample.cliffordAxioms =
        geometry_clifford_obligation_sample ∧
      geometry_certificate_sample.sandwichIsometry =
        geometry_sandwich_obligation_sample ∧
      geometry_certificate_sample.composition =
        geometry_composition_obligation_sample := by
  exact Epistemos.Geometry.CertificateTarget.obligationFieldsMatch
    geometry_certificate_sample
    geometry_clifford_obligation_sample
    geometry_sandwich_obligation_sample
    geometry_composition_obligation_sample
    rfl rfl rfl

theorem rotor_sandwich_isometry_sample :
    geometry_sandwich_obligation_sample.preservesNorm := by
  exact Epistemos.Geometry.identityRotorCertificateObligations.left

theorem geometry_certificate_sandwich_field_sample :
    geometry_certificate_sample.sandwichIsometry =
      geometry_sandwich_obligation_sample := by
  exact Epistemos.Geometry.CertificateTarget.sandwichIsometryMatches
    geometry_certificate_sample
    geometry_sandwich_obligation_sample
    rfl

theorem rotor_composition_sample :
    geometry_composition_obligation_sample.associativeSandwich := by
  exact Epistemos.Geometry.identityRotorCertificateObligations.right

theorem geometry_certificate_clifford_axioms_sample :
    geometry_certificate_sample.cliffordAxioms.basisSquares ->
    geometry_certificate_sample.cliffordAxioms.basisAnticommutative ->
    geometry_certificate_sample.cliffordAxioms.basisSquares ∧
      geometry_certificate_sample.cliffordAxioms.basisAnticommutative := by
  intro basisSquaresWitness basisAnticommutativeWitness
  exact Epistemos.Geometry.CertificateTarget.cliffordObligations
    geometry_certificate_sample
    basisSquaresWitness
    basisAnticommutativeWitness

theorem geometry_certificate_rotor_obligations_sample :
    geometry_certificate_sample.sandwichIsometry.preservesNorm ∧
      geometry_certificate_sample.composition.associativeSandwich := by
  exact Epistemos.Geometry.CertificateTarget.rotorObligations
    geometry_certificate_sample
    rotor_sandwich_isometry_sample
    rotor_composition_sample

end Epistemos.Geometry.Generated
