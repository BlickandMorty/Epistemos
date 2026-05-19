import Epistemos.Tropical

/-!
Handwritten generated-shape sample for the Tropical-IR rational
certificate emitter.

This mirrors the `RationalRepresentationObligation.refl` path emitted
by `agent_core/src/research/tropical_ir/certificate.rs` and keeps the
representation target checked in the aggregate Lean build.
-/

namespace Epistemos.Tropical.Generated

noncomputable def tropical_rational_num_sample : Epistemos.Tropical.Expr :=
  (Epistemos.Tropical.Expr.const (1 : ℝ))

noncomputable def tropical_rational_den_sample : Epistemos.Tropical.Expr :=
  (Epistemos.Tropical.Expr.const (0 : ℝ))

noncomputable def tropical_rational_form_sample :
    Epistemos.Tropical.RationalForm :=
  { numerator := tropical_rational_num_sample
    denominator := tropical_rational_den_sample }

noncomputable def tropical_rational_obligation_sample :
  Epistemos.Tropical.RationalRepresentationObligation
      tropical_rational_form_sample :=
  Epistemos.Tropical.RationalRepresentationObligation.refl
    tropical_rational_form_sample
    "sample-num"
    "sample-den"
    "docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR rational-form"

theorem tropical_rational_numerator_shape_sample :
    tropical_rational_form_sample.numerator =
      tropical_rational_form_sample.numerator := by
  exact tropical_rational_obligation_sample.numeratorShape

theorem tropical_rational_denominator_shape_sample :
    tropical_rational_form_sample.denominator =
      tropical_rational_form_sample.denominator := by
  exact tropical_rational_obligation_sample.denominatorShape

noncomputable def tropical_rational_certificate_sample :
    Epistemos.Tropical.RationalCertificateTarget :=
  { rational := tropical_rational_form_sample
    numeratorHash := "sample-num"
    denominatorHash := "sample-den"
    representation := tropical_rational_obligation_sample }

theorem tropical_rational_certificate_hash_fields_sample :
    tropical_rational_certificate_sample.numeratorHash = "sample-num" ∧
      tropical_rational_certificate_sample.denominatorHash = "sample-den" := by
  exact Epistemos.Tropical.RationalCertificateTarget.hashFieldsMatch
    tropical_rational_certificate_sample
    "sample-num" "sample-den" rfl rfl

theorem tropical_rational_certificate_numerator_hash_sample :
    tropical_rational_certificate_sample.numeratorHash = "sample-num" := by
  exact Epistemos.Tropical.RationalCertificateTarget.numeratorHashMatches
    tropical_rational_certificate_sample
    "sample-num"
    rfl

theorem tropical_rational_certificate_denominator_hash_sample :
    tropical_rational_certificate_sample.denominatorHash = "sample-den" := by
  exact Epistemos.Tropical.RationalCertificateTarget.denominatorHashMatches
    tropical_rational_certificate_sample
    "sample-den"
    rfl

theorem tropical_rational_certificate_representation_hash_fields_sample :
    tropical_rational_certificate_sample.representation.numeratorHash =
        tropical_rational_certificate_sample.numeratorHash ∧
      tropical_rational_certificate_sample.representation.denominatorHash =
        tropical_rational_certificate_sample.denominatorHash := by
  exact Epistemos.Tropical.RationalCertificateTarget.representationHashFieldsMatch
    tropical_rational_certificate_sample
    rfl
    rfl

theorem tropical_rational_certificate_representation_hash_values_sample :
    tropical_rational_certificate_sample.representation.numeratorHash =
        "sample-num" ∧
      tropical_rational_certificate_sample.representation.denominatorHash =
        "sample-den" := by
  exact Epistemos.Tropical.RationalCertificateTarget.representationHashFieldsCarry
    tropical_rational_certificate_sample
    "sample-num"
    "sample-den"
    rfl
    rfl
    rfl
    rfl

theorem tropical_rational_certificate_target_hashes_from_representation_sample :
    tropical_rational_certificate_sample.numeratorHash = "sample-num" ∧
      tropical_rational_certificate_sample.denominatorHash = "sample-den" := by
  exact Epistemos.Tropical.RationalCertificateTarget.targetHashFieldsFromRepresentation
    tropical_rational_certificate_sample
    "sample-num"
    "sample-den"
    rfl
    rfl
    rfl
    rfl

theorem tropical_rational_certificate_representation_sample :
    tropical_rational_certificate_sample.representation =
      tropical_rational_obligation_sample := by
  exact Epistemos.Tropical.RationalCertificateTarget.representationMatches
    tropical_rational_certificate_sample
    tropical_rational_obligation_sample
    rfl

noncomputable def tropical_rational_certificate_representation_obligation_sample :
    Epistemos.Tropical.RationalRepresentationObligation
      tropical_rational_certificate_sample.rational := by
  exact Epistemos.Tropical.RationalCertificateTarget.representationCarries
    tropical_rational_certificate_sample

theorem tropical_rational_certificate_numerator_shape_sample :
    tropical_rational_certificate_sample.rational.numerator =
      tropical_rational_certificate_sample.rational.numerator := by
  exact Epistemos.Tropical.RationalCertificateTarget.numeratorShape
    tropical_rational_certificate_sample

theorem tropical_rational_certificate_denominator_shape_sample :
    tropical_rational_certificate_sample.rational.denominator =
      tropical_rational_certificate_sample.rational.denominator := by
  exact Epistemos.Tropical.RationalCertificateTarget.denominatorShape
    tropical_rational_certificate_sample

theorem tropical_rational_certificate_shapes_sample :
    tropical_rational_certificate_sample.rational.numerator =
        tropical_rational_certificate_sample.rational.numerator ∧
      tropical_rational_certificate_sample.rational.denominator =
        tropical_rational_certificate_sample.rational.denominator := by
  exact Epistemos.Tropical.RationalCertificateTarget.representationShapes
    tropical_rational_certificate_sample

theorem tropical_rational_shapes_sample :
    tropical_rational_form_sample.numerator =
        tropical_rational_form_sample.numerator ∧
      tropical_rational_form_sample.denominator =
        tropical_rational_form_sample.denominator := by
  exact Epistemos.Tropical.RationalRepresentationObligation.shapes
    tropical_rational_obligation_sample

theorem tropical_rational_hash_fields_sample :
    tropical_rational_obligation_sample.numeratorHash = "sample-num" ∧
      tropical_rational_obligation_sample.denominatorHash = "sample-den" := by
  exact Epistemos.Tropical.RationalRepresentationObligation.hashFieldsMatch
    tropical_rational_obligation_sample
    "sample-num"
    "sample-den"
    rfl
    rfl

theorem tropical_rational_numerator_hash_sample :
    tropical_rational_obligation_sample.numeratorHash = "sample-num" := by
  exact Epistemos.Tropical.RationalRepresentationObligation.numeratorHashMatches
    tropical_rational_obligation_sample
    "sample-num"
    rfl

theorem tropical_rational_denominator_hash_sample :
    tropical_rational_obligation_sample.denominatorHash = "sample-den" := by
  exact Epistemos.Tropical.RationalRepresentationObligation.denominatorHashMatches
    tropical_rational_obligation_sample
    "sample-den"
    rfl

theorem tropical_rational_source_row_sample :
    tropical_rational_obligation_sample.sourceRow =
      "docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR rational-form" := by
  exact Epistemos.Tropical.RationalRepresentationObligation.sourceRowMatches
    tropical_rational_obligation_sample
    "docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR rational-form"
    rfl

end Epistemos.Tropical.Generated
