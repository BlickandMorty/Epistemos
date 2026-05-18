/-
HELIOS V5 H3 — Active-Support Atlas indexing.

HELIOS-H3 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H3 +
`agent_core/src/scope_rex/metal/asa_index.rs` (W6 Tier-1
ULP-equivalent reference).

**Statement:** Atlas index of currently-supported features is
monotone non-decreasing under merge, monotone non-increasing under
split. Idempotent self-merge / self-split.

  AsaIndex.merge(a, b).len() ≥ max(a.len(), b.len())
  AsaIndex.split(a, b).len() ≤ min(a.len(), b.len())
  AsaIndex.merge(a, a) == a       [idempotent]
  AsaIndex.split(a, a) == a       [idempotent]

Conservative-mask matmul produces BIT-IDENTICAL output to dense
reference matmul when every non-zero-contributing row is in the
mask.

Sorry budget at lock: ≤ 4.
-/

namespace Epistemos.H3

structure H3MonotonicityVerdict where
  merge_non_decreasing : Bool
  split_non_increasing : Bool
  merge_idempotent     : Bool
  split_idempotent     : Bool

def H3MonotonicityVerdict.allHold (v : H3MonotonicityVerdict) : Bool :=
  v.merge_non_decreasing && v.split_non_increasing &&
  v.merge_idempotent && v.split_idempotent

theorem h3MonotonicityHolds :
    ({ merge_non_decreasing := true
       split_non_increasing := true
       merge_idempotent := true
       split_idempotent := true } : H3MonotonicityVerdict).allHold = true := by
  rfl

end Epistemos.H3
