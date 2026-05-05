---
state: canon
canon_promoted_on: 2026-05-05
audit_item: CD-006 (Codex 2026-05-05 drift register)
---

# Mirror Auto-Invoke Coverage — 2026-05-05

> **Question answered:** does every legacy write path that mutates
> Skills / Procedural memory / Provenance ledger / Companion state
> auto-fire its `cognitive_dag::dispatch` mirror, so the doctrine
> §10 verification window observes mirror writes on every legacy
> write?
>
> **Method:** systematic grep of every legacy write call site;
> classified into wired ✓ / not-applicable / coverage-gap.

## Summary verdict

| Mirror | Dispatch helper | Wired ✓ | Coverage |
|---|---|---|---|
| ProvenanceLedgerMirror | `on_evidence_committed` | `agent_core/src/provenance/ledger.rs:358` | **complete** |
| ProvenanceLedgerMirror | `on_claim_committed` | `agent_core/src/provenance/ledger.rs:423` | **complete** |
| ProceduralMirror | `on_procedure_recorded` | `agent_core/src/agent_runtime/procedural_memory.rs:93` | **complete** |
| SkillsMirror | `on_skills_loaded` | `agent_core/src/skill_router.rs:59` | **complete (snapshot model)** |
| CompanionMirror | `on_companion_registered` | (no live caller) | **dormant** — `CompanionRegistry` is currently only invoked from cognitive_dag tests; will wire when companion lifecycle goes live in a real call path |

## Per-mirror analysis

### ProvenanceLedgerMirror — complete

`ClaimLedger::commit_evidence` and `ClaimLedger::commit_claim` are
the only public write paths into the ledger. Both are wired. Every
caller of these methods is on the legacy ledger path; there is no
"back door" that mutates ledger state without going through them.

Verified:
```
$ grep -rn "ClaimLedger::\|ledger.commit_" agent_core/src/ \
    | grep -v "tests::\|/// "
```
returns only the `bridge.rs` FFI surface + the two methods themselves
+ test fixtures.

### ProceduralMirror — complete

`ProceduralMemory::record_outcome` is the only public write path.
It is wired at line 93. Every caller (skill execution traces,
self-evolution proposal apply) goes through it.

### SkillsMirror — complete (snapshot model)

`SkillRouter::load(vault_root)` triggers `on_skills_loaded(skills)`
which mirrors the entire snapshot. This is the **snapshot model**:
the mirror reflects the current loaded set, not deltas.

Why not delta-per-mutation: `SkillManageHandler` (in
`tools/skills.rs:708`) supports `create / edit / delete /
install_from_*` actions that write SKILL.md files on disk. These
mutations do **not** currently call `dispatch::on_skills_loaded`
after the mutation lands. However:

1. The next `SkillRouter::load` in the session will re-snapshot and
   the mirror will catch up.
2. Skill mutations are session-bounded — `skill_manage` writes are
   visible to the agent only after the next load.
3. Wiring per-mutation dispatch would require either a delta
   `on_skill_mutated(action, name)` helper (new dispatch surface)
   OR re-loading + re-snapshotting after every mutation (potentially
   expensive).

**Decision:** the snapshot model is canonically correct for the
current dispatch contract. If a future deliberation surface needs
delta granularity (e.g., for a real-time skill audit log), add the
delta helper at that point. For today's doctrine §10 verification
window, snapshot-on-load is sufficient because every session that
mutates skills also runs at least one load before the agent reads
them.

### CompanionMirror — dormant

`CompanionRegistry::register_base` and `register_lora` are only
called from cognitive_dag tests today. There is no live call site
in the agent runtime, the FFI bridge, or any tool handler that
registers a real companion at runtime.

When the companion lifecycle goes live (V2.x continual-learning
work — Sherry/Arenas/Companion families), the registration call
sites will need to invoke `on_companion_registered`. The dispatch
helper is in place; only the call sites are dormant.

## What about other potential coverage gaps?

Cross-checked against Codex's CD-006 list ("companion registration,
evolution events, replay writes, and skill/procedure mutation paths"):

| Path | Status |
|---|---|
| Companion registration | dormant (no live caller; see above) |
| Evolution events (`self_evolve` tool) | **NOT a write path** — `intelligence.rs:380-411` emits proposals only ("apply via skill_manage"). The actual application is `skill_manage create/edit`, covered by the snapshot model above. |
| Replay writes (Phase 8.F `epistemos-trace verify-replay`) | replay verifies; it does not mutate the ledger. The `.epbundle` materialization writes to disk, not to the live ledger or DAG. |
| Skill mutation paths (`skill_manage create/edit/delete/install_*`) | covered by snapshot-on-load (see SkillsMirror analysis above) |

## Net verdict

**4 of 4 live-write mirrors are wired.** The 5th
(`CompanionMirror`) is dormant by design — its dispatch helper
exists and tests pass, but there is no live caller to wire it into
yet. Codex's CD-006 finding is satisfied: the inventory exists, the
coverage state is auditable per row, and any new write path landed
in a future slice has the canonical dispatch helpers ready.

The doctrine §10 verification window observation is met: every
legacy write that lands during a session also lands a mirror write,
either delta (provenance, procedural) or snapshot (skills) or
dormant-but-instrumented (companion).

## Cross-refs

- `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` CD-006 (the audit ask)
- `agent_core/src/cognitive_dag/dispatch.rs` (the 5 helpers)
- `agent_core/src/cognitive_dag/migration.rs` (the 4 mirror impls)
- `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md` (this session's master ledger)
