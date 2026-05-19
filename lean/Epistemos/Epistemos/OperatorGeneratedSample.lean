import Epistemos.Operator

/-!
Handwritten generated-shape sample for the Operator-IR certificate
emitter.

This mirrors the constructor-routed Lean source emitted by
`agent_core/src/research/operator_ir/certificate.rs` for a minimal
Fourier-kernel operator. It keeps the generated namespace and theorem
layout checked by the Lean aggregate build.
-/

namespace Epistemos.Operator.Generated

def operator_branch_sample : Epistemos.Operator.LinearNetwork :=
  { inputDim := 2, outputDim := 2 }

def operator_trunk_sample : Epistemos.Operator.LinearNetwork :=
  { inputDim := 2, outputDim := 2 }

def operator_kernel_sample : Epistemos.Operator.KernelTransform :=
  (Epistemos.Operator.KernelTransform.fourier 1)

theorem operator_dim_match_schema_sample :
    operator_branch_sample.outputDim = operator_trunk_sample.outputDim := by
  rfl

def operator_expr_sample : Epistemos.Operator.Expr :=
  { branch := operator_branch_sample
    trunk := operator_trunk_sample
    kernel := operator_kernel_sample
    dimMatch := operator_dim_match_schema_sample }

def operator_fno_obligation_sample : Epistemos.Operator.FNOEquivalenceObligation :=
  Epistemos.Operator.fnoEquivalenceObligation operator_expr_sample

theorem operator_fourier_mode_bound_sample :
    Epistemos.Operator.fourierModeBound 1 := by
  simp [Epistemos.Operator.fourierModeBound]

def operator_fourier_obligation_sample :
    Epistemos.Operator.FourierIsometryObligation :=
  Epistemos.Operator.fourierIsometryObligation 1
    operator_fourier_mode_bound_sample

def operator_certificate_sample : Epistemos.Operator.CertificateTarget :=
  { expr := operator_expr_sample
    dim_consistent := operator_dim_match_schema_sample
    fno_equivalence := operator_fno_obligation_sample
    fno_expr_matches := rfl
    fourier_isometry := some operator_fourier_obligation_sample }

theorem operator_fourier_option_sample :
    operator_certificate_sample.fourier_isometry =
      some operator_fourier_obligation_sample := by
  exact Epistemos.Operator.CertificateTarget.fourierOptionMatches
    operator_certificate_sample
    (some operator_fourier_obligation_sample)
    rfl

theorem operator_certificate_fno_sample :
    operator_certificate_sample.fno_equivalence =
      operator_fno_obligation_sample := by
  exact Epistemos.Operator.CertificateTarget.fnoObligationMatches
    operator_certificate_sample
    operator_fno_obligation_sample
    rfl

theorem operator_certificate_fno_expr_match_sample :
    operator_certificate_sample.fno_equivalence.expr =
      operator_certificate_sample.expr := by
  exact Epistemos.Operator.CertificateTarget.fnoExprMatchesCarries
    operator_certificate_sample

theorem operator_certificate_dim_consistency_sample :
    operator_certificate_sample.expr.branch.outputDim =
      operator_certificate_sample.expr.trunk.outputDim := by
  exact Epistemos.Operator.CertificateTarget.dimConsistentCarries
    operator_certificate_sample

theorem operator_dim_consistency_sample :
    operator_expr_sample.branch.outputDim =
      operator_expr_sample.trunk.outputDim := by
  exact operator_expr_sample.dimMatch

theorem operator_fourier_isometry_sample :
    operator_fourier_obligation_sample.isometry := by
  exact Epistemos.Operator.fourierIsometryObligationCarries 1
    operator_fourier_mode_bound_sample

theorem operator_certificate_fourier_witness_sample :
    ∃ targetObligation : Epistemos.Operator.FourierIsometryObligation,
      operator_certificate_sample.fourier_isometry = some targetObligation ∧
        targetObligation.isometry := by
  exact Epistemos.Operator.CertificateTarget.fourierSomeCarries
    operator_certificate_sample
    operator_fourier_obligation_sample
    operator_fourier_option_sample
    operator_fourier_isometry_sample

theorem operator_fno_equivalence_sample :
    operator_fno_obligation_sample.statement := by
  exact Epistemos.Operator.fnoEquivalenceObligationCarries
    operator_expr_sample

theorem operator_certificate_fno_statement_sample :
    operator_certificate_sample.fno_equivalence.statement := by
  exact Epistemos.Operator.CertificateTarget.fnoStatementCarries
    operator_certificate_sample
    operator_fno_equivalence_sample

end Epistemos.Operator.Generated
