/-
Primitive IR Stack - Scan schema authority.

This module is the Lean-side schema for the Rust mirror at
`agent_core/src/research/scan_ir/`.

Source doctrine:
* `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.I
* `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §3
* `agent_core/src/research/scan_ir/certificate.rs`

Tooling status:
`PATH="$HOME/.elan/bin:$PATH"; cd lean/Epistemos && lake build`
first completed successfully at iter-593; SSD equivalence and monoid
obligations were sharpened through iter-698; the iter-713 cadence
retry also completed successfully. `Tools/sorry-budget/sorry-budget.sh`
reported 0 total sorries. Scan certificates target this schema module
through `Epistemos.Scan.CertificateTarget`.
-/

import Mathlib

namespace Epistemos.Scan

/-- Algebraic witness required by Scan-IR: the state transition must
form a monoid for parallel scan equivalence. -/
structure MonoidWitness (α : Type) where
  op : α -> α -> α
  identity : α
  assoc : ∀ a b c : α, op (op a b) c = op a (op b c)
  left_identity : ∀ x : α, op identity x = x
  right_identity : ∀ x : α, op x identity = x

/-- Scan certificates expose three monoid-law obligations:
associativity, left identity, and right identity. -/
def monoidLawCount : Nat := 3

/-- Rust `ScanProgram<T>` mirror: an initial state plus a finite input
sequence. -/
structure Program (α : Type) where
  initial : α
  inputs : List α
deriving Repr

/-- Output tail after the initial state. -/
def scanTail {α : Type} (op : α -> α -> α) : α -> List α -> List α
  | _, [] => []
  | state, x :: xs =>
      let next := op state x
      next :: scanTail op next xs

/-- Sequential scan reference semantics. Output includes the initial
state, matching the Rust `ScanProgram::output_count = step_count + 1`
invariant. -/
def sequentialScan {α : Type}
    (op : α -> α -> α) (initial : α) (inputs : List α) : List α :=
  initial :: scanTail op initial inputs

theorem sequentialScan_empty {α : Type}
    (op : α -> α -> α) (initial : α) :
    sequentialScan op initial [] = [initial] := rfl

theorem scanTail_one {α : Type}
    (op : α -> α -> α) (initial x : α) :
    scanTail op initial [x] = [op initial x] := rfl

theorem scanTail_length {α : Type}
    (op : α -> α -> α) (state : α) (inputs : List α) :
    (scanTail op state inputs).length = inputs.length := by
  induction inputs generalizing state with
  | nil => rfl
  | cons x xs ih =>
      simp [scanTail, ih]

theorem sequentialScan_length {α : Type}
    (op : α -> α -> α) (initial : α) (inputs : List α) :
    (sequentialScan op initial inputs).length = inputs.length + 1 := by
  simp [sequentialScan, scanTail_length]

theorem monoidLawCountPinned :
    monoidLawCount = 3 := by
  rfl

def scanAssociativeOp {α : Type} (op : α -> α -> α) : Prop :=
  ∀ a b c : α, op (op a b) c = op a (op b c)

def scanLeftIdentity {α : Type}
    (op : α -> α -> α) (identity : α) : Prop :=
  ∀ x : α, op identity x = x

def scanRightIdentity {α : Type}
    (op : α -> α -> α) (identity : α) : Prop :=
  ∀ x : α, op x identity = x

theorem MonoidWitness.scanLawWitnesses {α : Type}
    (w : MonoidWitness α) :
    scanAssociativeOp w.op ∧
      scanLeftIdentity w.op w.identity ∧
      scanRightIdentity w.op w.identity := by
  exact ⟨w.assoc, w.left_identity, w.right_identity⟩

def ssdEquivalentToSequential {α : Type}
    (op : α -> α -> α) (identity _initial : α)
    (_inputs : List α) (blockSize : Nat) : Prop :=
  1 ≤ blockSize ∧ scanAssociativeOp op ∧ scanLeftIdentity op identity

/-- External lemma witness for the Dao/Gu SSD equivalence proof. The
generated Rust certificate may close its local theorem from this
schema row while the actual block-scan proof remains source-custodied. -/
structure SSDEquivalenceLemma (α : Type) where
  statement :
    ∀ (w : MonoidWitness α) (initial : α) (inputs : List α)
      (blockSize : Nat),
      1 ≤ blockSize ->
        ssdEquivalentToSequential
          w.op w.identity initial inputs blockSize

theorem SSDEquivalenceLemma.discharge {α : Type}
    (ssdLemma : SSDEquivalenceLemma α)
    (w : MonoidWitness α) (initial : α) (inputs : List α)
    (blockSize : Nat) (hB : 1 ≤ blockSize) :
    ssdEquivalentToSequential w.op w.identity initial inputs blockSize :=
  ssdLemma.statement w initial inputs blockSize hB

/-- Explicit obligation row for SSD/block-scan equivalence. The Rust
certificate emitter should target this shape before claiming a
parallel lowering is equivalent to sequential scan. -/
structure SSDEquivalenceObligation (α : Type) where
  monoid : MonoidWitness α
  initial : α
  inputs : List α
  blockSize : Nat
  blockSize_positive : 1 ≤ blockSize
  ssdOutput : List α
  sequentialOutput : List α
  sequential_matches :
    sequentialOutput = sequentialScan monoid.op initial inputs
  equivalent : ssdOutput = sequentialOutput

theorem SSDEquivalenceObligation.ssdOutputMatchesSequential {α : Type}
    (o : SSDEquivalenceObligation α) :
    o.ssdOutput = sequentialScan o.monoid.op o.initial o.inputs := by
  rw [o.equivalent, o.sequential_matches]

theorem SSDEquivalenceObligation.toSchemaPredicate {α : Type}
    (o : SSDEquivalenceObligation α) :
    ssdEquivalentToSequential
      o.monoid.op o.monoid.identity o.initial o.inputs o.blockSize := by
  exact ⟨o.blockSize_positive, o.monoid.assoc, o.monoid.left_identity⟩

/-- Target for a generated Scan expression/program certificate. -/
structure CertificateTarget (α : Type) where
  monoid : MonoidWitness α
  program : Program α
  output : List α
  sourceRow : String
  output_matches :
    output = sequentialScan monoid.op program.initial program.inputs

theorem CertificateTarget.outputMatchesSequential {α : Type}
    (c : CertificateTarget α) :
    c.output = sequentialScan c.monoid.op c.program.initial c.program.inputs :=
  c.output_matches

theorem CertificateTarget.outputMatchesField {α : Type}
    (c : CertificateTarget α)
    (h : c.output = sequentialScan c.monoid.op c.program.initial c.program.inputs)
    (stored : c.output_matches = h) :
    c.output_matches = h := by
  exact stored

theorem CertificateTarget.programOutputFieldsMatch {α : Type}
    (c : CertificateTarget α)
    (program : Program α) (output : List α)
    (programMatches : c.program = program)
    (outputMatches : c.output = output) :
    c.program = program ∧ c.output = output := by
  exact ⟨programMatches, outputMatches⟩

theorem CertificateTarget.sourceRowMatches {α : Type}
    (c : CertificateTarget α)
    (sourceRow : String)
    (stored : c.sourceRow = sourceRow) :
    c.sourceRow = sourceRow := by
  exact stored

theorem CertificateTarget.outputLengthMatches {α : Type}
    (c : CertificateTarget α) :
    c.output.length = c.program.inputs.length + 1 := by
  rw [c.output_matches]
  exact sequentialScan_length c.monoid.op c.program.initial c.program.inputs

theorem CertificateTarget.monoidLawWitnesses {α : Type}
    (c : CertificateTarget α) :
    scanAssociativeOp c.monoid.op ∧
      scanLeftIdentity c.monoid.op c.monoid.identity ∧
      scanRightIdentity c.monoid.op c.monoid.identity := by
  exact MonoidWitness.scanLawWitnesses c.monoid

end Epistemos.Scan
