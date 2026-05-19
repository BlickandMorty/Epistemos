import Epistemos.Scan

/-!
Handwritten generated-shape sample for the Scan-IR certificate emitter.

This mirrors the generic theorem layout emitted by
`agent_core/src/research/scan_ir/certificate.rs`: monoid law projection,
SSD discharge through `SSDEquivalenceLemma`, and direct
`CertificateTarget` construction.
-/

namespace Epistemos.Scan.Generated

theorem scan_monoid_assoc_sample :
    ∀ (T : Type) (w : Epistemos.Scan.MonoidWitness T),
      Epistemos.Scan.scanAssociativeOp w.op := by
  intro T w
  exact w.assoc

theorem scan_left_identity_sample :
    ∀ (T : Type) (w : Epistemos.Scan.MonoidWitness T),
      Epistemos.Scan.scanLeftIdentity w.op w.identity := by
  intro T w
  exact w.left_identity

theorem scan_right_identity_sample :
    ∀ (T : Type) (w : Epistemos.Scan.MonoidWitness T),
      Epistemos.Scan.scanRightIdentity w.op w.identity := by
  intro T w
  exact w.right_identity

theorem scan_ssd_equivalence_sample :
    ∀ (T : Type) (_ssdLemma : Epistemos.Scan.SSDEquivalenceLemma T)
      (w : Epistemos.Scan.MonoidWitness T)
      (initial : T) (inputs : List T) (B : Nat),
      B ≥ 1 ->
      Epistemos.Scan.ssdEquivalentToSequential
        w.op w.identity initial inputs B := by
  intro T ssdLemma w initial inputs B hB
  exact Epistemos.Scan.SSDEquivalenceLemma.discharge
    ssdLemma w initial inputs B hB

def scan_certificate_target_sample
    (T : Type) (w : Epistemos.Scan.MonoidWitness T)
    (program : Epistemos.Scan.Program T) (output : List T)
    (h : output =
      Epistemos.Scan.sequentialScan w.op program.initial program.inputs) :
    Epistemos.Scan.CertificateTarget T :=
  { monoid := w
    program := program
    output := output
    output_matches := h }

theorem scan_certificate_program_output_fields_sample
    (T : Type) (w : Epistemos.Scan.MonoidWitness T)
    (program : Epistemos.Scan.Program T) (output : List T)
    (h : output =
      Epistemos.Scan.sequentialScan w.op program.initial program.inputs) :
    (scan_certificate_target_sample T w program output h).program = program ∧
      (scan_certificate_target_sample T w program output h).output = output := by
  exact Epistemos.Scan.CertificateTarget.programOutputFieldsMatch
    (scan_certificate_target_sample T w program output h)
    program output rfl rfl

theorem scan_certificate_output_matches_sample
    (T : Type) (w : Epistemos.Scan.MonoidWitness T)
    (program : Epistemos.Scan.Program T) (output : List T)
    (h : output =
      Epistemos.Scan.sequentialScan w.op program.initial program.inputs) :
    (scan_certificate_target_sample T w program output h).output_matches = h := by
  exact Epistemos.Scan.CertificateTarget.outputMatchesField
    (scan_certificate_target_sample T w program output h)
    h
    rfl

theorem scan_certificate_output_sequential_sample
    (T : Type) (w : Epistemos.Scan.MonoidWitness T)
    (program : Epistemos.Scan.Program T) (output : List T)
    (h : output =
      Epistemos.Scan.sequentialScan w.op program.initial program.inputs) :
    (scan_certificate_target_sample T w program output h).output =
      Epistemos.Scan.sequentialScan w.op program.initial program.inputs := by
  exact Epistemos.Scan.CertificateTarget.outputMatchesSequential
    (scan_certificate_target_sample T w program output h)

theorem scan_certificate_output_length_sample
    (T : Type) (w : Epistemos.Scan.MonoidWitness T)
    (program : Epistemos.Scan.Program T) (output : List T)
    (h : output =
      Epistemos.Scan.sequentialScan w.op program.initial program.inputs) :
    (scan_certificate_target_sample T w program output h).output.length =
      program.inputs.length + 1 := by
  exact Epistemos.Scan.CertificateTarget.outputLengthMatches
    (scan_certificate_target_sample T w program output h)

theorem scan_certificate_monoid_laws_sample
    (T : Type) (w : Epistemos.Scan.MonoidWitness T)
    (program : Epistemos.Scan.Program T) (output : List T)
    (h : output =
      Epistemos.Scan.sequentialScan w.op program.initial program.inputs) :
    Epistemos.Scan.scanAssociativeOp w.op ∧
      Epistemos.Scan.scanLeftIdentity w.op w.identity ∧
      Epistemos.Scan.scanRightIdentity w.op w.identity := by
  exact Epistemos.Scan.CertificateTarget.monoidLawWitnesses
    (scan_certificate_target_sample T w program output h)

end Epistemos.Scan.Generated
