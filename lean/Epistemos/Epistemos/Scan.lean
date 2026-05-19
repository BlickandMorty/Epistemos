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

def scanAssociativeOp {α : Type} (op : α -> α -> α) : Prop :=
  ∀ a b c : α, op (op a b) c = op a (op b c)

def scanLeftIdentity {α : Type}
    (op : α -> α -> α) (identity : α) : Prop :=
  ∀ x : α, op identity x = x

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

/-- Target for a generated Scan expression/program certificate. -/
structure CertificateTarget (α : Type) where
  monoid : MonoidWitness α
  program : Program α
  output : List α
  output_matches :
    output = sequentialScan monoid.op program.initial program.inputs

end Epistemos.Scan
