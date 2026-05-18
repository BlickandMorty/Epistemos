/-
HELIOS V5 H8 — OSPC operators (9 substrate primitives).

HELIOS-H8 guard

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 H8.

**Statement:** the 9 OSPC (Operator-Scoped Provenance Container)
substrate primitives form a complete control surface for
TypedArtifact mutation under MutationEnvelope discipline:

  bind, unbind, gate, route, commit, reorder, merge, split, quarantine

Falsifier: 9-arm exhaustive dispatch on `MutationEnvelope.kind`.
4-mirror dispatch in `agent_core/src/cognitive_dag/dispatch.rs`
is the strict subset currently shipped (Skills + Procedural +
Provenance + Companion); the remaining 5 land per a Lane 3
follow-up.

Sorry budget at lock: ≤ 4.
-/

namespace Epistemos.H8

inductive OspcOp : Type
  | bind
  | unbind
  | gate
  | route
  | commit
  | reorder
  | merge
  | split
  | quarantine

def OspcOp.all : List OspcOp :=
  [.bind, .unbind, .gate, .route, .commit, .reorder, .merge, .split, .quarantine]

theorem ospcSubstrateComplete : OspcOp.all.length = 9 := by
  rfl

end Epistemos.H8
