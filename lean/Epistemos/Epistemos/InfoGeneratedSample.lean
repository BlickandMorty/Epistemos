import Epistemos.Info

/-!
Handwritten generated-shape sample for the Info-IR certificate emitter.

This module mirrors the constructor-routed source shape emitted by
`agent_core/src/research/info_ir/certificate.rs` for a Bernoulli
log-partition certificate. It keeps the generated namespace and theorem
layout in the Lean build while Rust round-trip tests continue to guard
the emitted source strings.
-/

namespace Epistemos.Info.Generated

def info_expr_sample : Epistemos.Info.Expr :=
  (Epistemos.Info.Expr.logPartition
    { family := Epistemos.Info.ExpFamily.bernoulli
      naturalParams := [(0 : Real)]
      wellFormed := Epistemos.Info.ExpFamily.bernoulli_wellFormed
      arityMatches := rfl })

theorem info_convexity_witness_sample :
    Epistemos.Info.logPartitionConvex
      Epistemos.Info.ExpFamily.bernoulli [(0 : Real)] := by
  exact ⟨Epistemos.Info.ExpFamily.bernoulli_wellFormed, rfl⟩

def info_convexity_obligation_sample :
    Epistemos.Info.ConvexLogPartitionObligation :=
  Epistemos.Info.convexLogPartitionObligation
    Epistemos.Info.ExpFamily.bernoulli [(0 : Real)]
    info_convexity_witness_sample
    "docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §3 + §5 Info-IR"

theorem info_bregman_nonnegative_witness_sample :
    Epistemos.Info.bregmanNonnegative
      Epistemos.Info.ExpFamily.bernoulli [(0 : Real)] [(0 : Real)] := by
  exact ⟨Epistemos.Info.ExpFamily.bernoulli_wellFormed, rfl, rfl⟩

theorem info_bregman_zero_witness_sample :
    Epistemos.Info.bregmanZeroIffEqual
      Epistemos.Info.ExpFamily.bernoulli [(0 : Real)] [(0 : Real)] := by
  exact ⟨Epistemos.Info.ExpFamily.bernoulli_wellFormed, rfl, rfl, Iff.rfl⟩

def info_bregman_obligation_sample :
    Epistemos.Info.BregmanPositivityObligation :=
  Epistemos.Info.bregmanPositivityObligation
    Epistemos.Info.ExpFamily.bernoulli [(0 : Real)] [(0 : Real)]
    info_bregman_nonnegative_witness_sample
    info_bregman_zero_witness_sample
    "Amari 2016 Ch. 6 §6.2"

theorem info_mirror_descent_witness_sample :
    Epistemos.Info.mirrorDescentEquivalent Epistemos.Info.ExpFamily.bernoulli := by
  exact Epistemos.Info.ExpFamily.bernoulli_wellFormed

def info_mirror_descent_obligation_sample :
    Epistemos.Info.MirrorDescentEquivalenceObligation :=
  Epistemos.Info.mirrorDescentEquivalenceObligation
    Epistemos.Info.ExpFamily.bernoulli
    info_mirror_descent_witness_sample
    "Beck-Teboulle 2003 §2"

def info_certificate_sample : Epistemos.Info.CertificateTarget :=
  { expr := info_expr_sample
    convexity := some info_convexity_obligation_sample
    positivity := info_bregman_obligation_sample
    mirrorEquivalence := info_mirror_descent_obligation_sample }

theorem info_certificate_obligations_sample :
    info_certificate_sample.convexity = some info_convexity_obligation_sample ∧
      info_certificate_sample.positivity = info_bregman_obligation_sample ∧
      info_certificate_sample.mirrorEquivalence =
        info_mirror_descent_obligation_sample := by
  exact Epistemos.Info.CertificateTarget.obligationFieldsMatch
    info_certificate_sample
    info_convexity_obligation_sample
    info_bregman_obligation_sample
    info_mirror_descent_obligation_sample
    rfl rfl rfl

theorem info_log_partition_convexity_sample :
    info_convexity_obligation_sample.convexOnNaturalDomain := by
  exact Epistemos.Info.convexLogPartitionObligationCarries
    Epistemos.Info.ExpFamily.bernoulli [(0 : Real)]
    info_convexity_witness_sample
    "docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §3 + §5 Info-IR"

theorem info_certificate_positivity_field_sample :
    info_certificate_sample.positivity = info_bregman_obligation_sample := by
  exact Epistemos.Info.CertificateTarget.positivityObligationMatches
    info_certificate_sample
    info_bregman_obligation_sample
    rfl

theorem info_certificate_convexity_field_sample :
    info_certificate_sample.convexity = some info_convexity_obligation_sample := by
  exact Epistemos.Info.CertificateTarget.convexityOptionMatches
    info_certificate_sample
    info_convexity_obligation_sample
    rfl

theorem info_certificate_convexity_target_sample :
    ∃ targetObligation,
      info_certificate_sample.convexity = some targetObligation ∧
        targetObligation.convexOnNaturalDomain := by
  exact Epistemos.Info.CertificateTarget.convexityObligationCarries
    info_certificate_sample
    info_convexity_obligation_sample
    rfl
    info_log_partition_convexity_sample

theorem info_bregman_positivity_sample :
    info_bregman_obligation_sample.nonnegative := by
  exact Epistemos.Info.bregmanPositivityObligationNonnegative
    Epistemos.Info.ExpFamily.bernoulli [(0 : Real)] [(0 : Real)]
    info_bregman_nonnegative_witness_sample
    info_bregman_zero_witness_sample
    "Amari 2016 Ch. 6 §6.2"

theorem info_bregman_non_degeneracy_sample :
    info_bregman_obligation_sample.zeroIffEqual := by
  exact Epistemos.Info.bregmanPositivityObligationZeroIffEqual
    Epistemos.Info.ExpFamily.bernoulli [(0 : Real)] [(0 : Real)]
    info_bregman_nonnegative_witness_sample
    info_bregman_zero_witness_sample
    "Amari 2016 Ch. 6 §6.2"

theorem info_certificate_bregman_obligations_sample :
    info_certificate_sample.positivity.nonnegative ∧
      info_certificate_sample.positivity.zeroIffEqual := by
  exact Epistemos.Info.CertificateTarget.bregmanObligations
    info_certificate_sample
    info_bregman_positivity_sample
    info_bregman_non_degeneracy_sample

theorem info_mirror_descent_equivalence_sample :
    info_mirror_descent_obligation_sample.statement := by
  exact Epistemos.Info.mirrorDescentEquivalenceObligationCarries
    Epistemos.Info.ExpFamily.bernoulli
    info_mirror_descent_witness_sample
    "Beck-Teboulle 2003 §2"

theorem info_certificate_mirror_equivalence_sample :
    info_certificate_sample.mirrorEquivalence.statement := by
  exact Epistemos.Info.CertificateTarget.mirrorEquivalenceCarries
    info_certificate_sample
    info_mirror_descent_equivalence_sample

end Epistemos.Info.Generated
