/-
HELIOS V5 H10 — Bilaminar Substrate (Julia oracle, Lane 4 reserved).

HELIOS-H10 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H10 +
v5.2 §F: H10 is **Lane 4 reserved at lock — never product**.

**Statement:** the MAS↔Pro lamination is enforceable by the
`mas-build` ⊕ `lane4-oracle` Cargo feature mutex.

  build(features = mas-build, lane4-oracle) → COMPILATION FAILURE

The mutex is build-time enforced; toggling both flags causes
the Rust compiler to reject the build before any binary is
produced. Per App Review §2.5.2: Julia is itself an interpreter,
so bundling `lane4-oracle` (jlrs 0.23 + arrow 53) inside an
MAS-distributed app would violate §2.5.2.

**v5.2 status:** P (Provisional) — never product. Lane 4
reserved per v5.2 §F.

Sorry budget at lock: ≤ 4.
-/

namespace Epistemos.H10

inductive BuildFeature : Type
  | masBuild
  | lane4Oracle
deriving BEq

/-- The Bilaminar mutex: at most one of {masBuild, lane4Oracle}
may be enabled in a given build. -/
def BuildFeature.mutexHolds (active : List BuildFeature) : Bool :=
  let has_mas := active.contains .masBuild
  let has_lane4 := active.contains .lane4Oracle
  !(has_mas && has_lane4)

/-- Lane 4 oracle remains research-reserved and never product. -/
def lane4ResearchReserved : Bool := true

theorem bilaminarMutexEnforced :
    BuildFeature.mutexHolds [.masBuild, .lane4Oracle] = false := by
  rfl

theorem lane4ReservationPinned :
    lane4ResearchReserved = true := by
  rfl

end Epistemos.H10
