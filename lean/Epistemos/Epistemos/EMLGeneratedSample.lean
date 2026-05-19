import Epistemos.EML

/-!
Handwritten generated-shape sample for the EML certificate emitter.

This mirrors the witness-free `Expr.one` certificate emitted by
`agent_core/src/research/eml/certificate.rs`, keeping the generated
namespace, branch-safety theorem, value-match theorem, and
`CertificateTarget.eval_positive` projection in the Lean build.
-/

namespace Epistemos.EML.Generated

noncomputable def eml_expr_sample : Epistemos.EML.Expr :=
  Epistemos.EML.Expr.one

noncomputable def eml_value_sample : ℝ :=
  1

theorem eml_branch_safe_sample :
    Epistemos.EML.BranchSafe eml_expr_sample := by
  exact Epistemos.EML.one_branch_safe

theorem eml_eval_matches_sample :
    Epistemos.EML.Expr.eval eml_expr_sample = eml_value_sample := by
  exact Epistemos.EML.Expr.eval_one

theorem eml_positive_value_sample :
    0 < eml_value_sample := by
  norm_num [eml_value_sample]

noncomputable def eml_certificate_sample :
    Epistemos.EML.CertificateTarget :=
  { expr := eml_expr_sample
    value := eml_value_sample
    branch_safe := eml_branch_safe_sample
    value_matches := eml_eval_matches_sample
    positive_value := eml_positive_value_sample }

theorem eml_certificate_data_fields_sample :
    eml_certificate_sample.expr = eml_expr_sample ∧
      eml_certificate_sample.value = eml_value_sample := by
  exact Epistemos.EML.CertificateTarget.dataFieldsMatch
    eml_certificate_sample eml_expr_sample eml_value_sample rfl rfl

theorem eml_branch_and_eval_sample :
    Epistemos.EML.BranchSafe eml_certificate_sample.expr ∧
      Epistemos.EML.Expr.eval eml_certificate_sample.expr =
        eml_certificate_sample.value := by
  exact Epistemos.EML.CertificateTarget.branchSafeAndEvalMatches
    eml_certificate_sample

theorem eml_eval_positive_sample :
    0 < Epistemos.EML.Expr.eval eml_expr_sample := by
  exact Epistemos.EML.CertificateTarget.eval_positive
    eml_certificate_sample

theorem eml_full_obligations_sample :
    Epistemos.EML.BranchSafe eml_certificate_sample.expr ∧
      Epistemos.EML.Expr.eval eml_certificate_sample.expr =
        eml_certificate_sample.value ∧
      0 < Epistemos.EML.Expr.eval eml_certificate_sample.expr := by
  exact Epistemos.EML.CertificateTarget.fullObligations
    eml_certificate_sample

end Epistemos.EML.Generated
