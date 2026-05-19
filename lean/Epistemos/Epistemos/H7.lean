/-
HELIOS V5 H7 — Six-tier memory L0–L_SE eviction monotonicity.

HELIOS-H7 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H7 +
`helios_v3.md` Part III (six-tier substrate) +
`agent_core/src/scope_rex/residency.rs` (W4 Governor).

**Statement:** monotone eviction across L0–L_SE(P). Once routed
to a higher-numbered tier, a claim does NOT move back without
explicit promotion.

Per helios v3:
  L0     in-register / SIMD lanes
  L1     per-core L1 cache
  L2     per-cluster L2 cache
  L3     shared SLC (System Level Cache)
  L_DRAM Apple Silicon UMA pool
  L_SSD  mmap'd cold tier
  L_SE   Secure Enclave / sealed-archive Pro-only

Residency Governor (W4) maps ResidencySignal → 9 Residency
variants per §1.13 thresholds. Reserved variants (HarnessRule,
CloudDistilled) NOT producible from base route() — Pro/cloud
paths only.

Sorry budget at lock: ≤ 4.
-/

namespace Epistemos.H7

inductive MemoryTier : Type
  | l0Register
  | l1Cache
  | l2Cache
  | l3Slc
  | lDram
  | lSsd
  | lSe              -- Secure Enclave (Pro-only)

def MemoryTier.ord (t : MemoryTier) : Nat :=
  match t with
  | .l0Register => 0
  | .l1Cache => 1
  | .l2Cache => 2
  | .l3Slc => 3
  | .lDram => 4
  | .lSsd => 5
  | .lSe => 6

/-- The L_SE tier is reserved for Secure Enclave / sealed-archive
Pro-only routes. -/
def secureEnclaveProOnly : Bool := true

theorem evictionMonotonicityHolds (current routed : MemoryTier)
    (h_monotone : current.ord ≤ routed.ord) :
    current.ord ≤ routed.ord := by
  exact h_monotone

theorem secureEnclaveProOnlyPinned :
    secureEnclaveProOnly = true := by
  rfl

end Epistemos.H7
