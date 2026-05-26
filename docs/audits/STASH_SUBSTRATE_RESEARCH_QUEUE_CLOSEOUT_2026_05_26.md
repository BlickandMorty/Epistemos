# Stash Substrate / Research Queue Closeout - 2026-05-26

Status: closed for current product recovery.

Sources inspected:

- `stash@{2}` - Terminal E rev-2 docs before fresh main.
- `stash@{5}` - Terminal E ACS gate pre-main rev2.
- `stash@{7}` - ambient/settings/voice/app shell auto-stash.
- `stash@{8}` - T12 F-ULP oracle.
- `stash@{9}` - T11 agent runtime v2 handoff.
- `stash@{13}` - multi-terminal ACS admission module exposure.
- `stash@{14}` - T17B lattice/WBO formatting donor.
- `stash@{18}` - large old-main UI/UX donor.

Recovery rule: this slice was inspected with `git stash show`, `git show`, and
`git diff` only. No stash was popped, dropped, checked out, or bulk-applied.

## Decision

The remaining active stash queue no longer contains merge-ready product code
that should be applied to `main`. It contains either:

1. work already represented on current `main`,
2. stale donor code superseded by newer product architecture,
3. documentation that is already resolved by newer closeout docs, or
4. research-tier work that belongs in the named architecture backlog, not in a
   raw stash merge.

The stashes remain preserved as historical references. They are no longer
active merge queues.

## Current Product Representation

### ACS / Terminal E

`stash@{2}` and `stash@{5}` carried Terminal E ACS docs and pre-main product
wiring. Current `main` already has the durable pieces:

- `agent_core/src/lib.rs` exports `pub mod acs_admission;`.
- `agent_core/src/acs_admission/audit_sink.rs` exposes
  `ACSRunEventLogSink`.
- `agent_core/src/agent_runtime_v2/mission_run.rs` routes tool calls through
  `MissionRun::admit_and_record_tool_call(...)`.
- `agent_core/src/scope_rex/admission_proof.rs` carries
  `SCOPERexAdmissionProof`.
- `Epistemos/KnowledgeFusion/CloudKnowledgeDistillationService.swift` calls the
  CSI gate before `store.save(vault)`.
- `Epistemos/Engine/ProvenanceConsoleProjectionService.swift` surfaces the ACS
  verdict column as unlinked until row-level ACS record IDs exist.

The stale green-chip posture from the Terminal E stash is intentionally not
restored. `ACSAdmissionHealthRow` remains honest: production code paths exist,
but the Settings row stays `substrate-only - gate not witnessed` until it
observes a production `ACSRunEventLogSink` admission witness and the canonical
anchor-addressing falsifier is closed.

The old `DECISION_NEEDED_ACS_ANCHOR_ADDRESSING_2026_05_24.md` ambiguity is
preserved only as a historical record. The resolved authority is
`DECISION_RESOLVED_ACS_ANCHOR_ADDRESSING_2026_05_24.md`: Terminal E owns the
product admission gate; canonical `F-ACS-Anchor-Addressing` remains deferred as
D-27 under codeword `RESUME ACS ANCHOR HARNESS`.

### Ambient / Voice / Settings

`stash@{7}` is closed by two focused docs:

- `STASH7_VOICE_INPUT_SERVICE_RECOVERY_2026_05_26.md`
- `STASH7_AMBIENT_SETTINGS_SUPERSESSION_2026_05_26.md`

Current `main` keeps the newer compact ambient flow, persistent live player,
voice input service bridge, and verified-floor settings rows. Raw stash replay
would downgrade those surfaces.

### F-ULP Oracle

`stash@{8}` added one adversarial replay test for operation `gate_tier` type
drift before raw numeric overflow. Current `main` already contains
`replay_rejects_operation_gate_tier_type_before_raw_overflow` in
`agent_core/src/research/eml_ir/witness.rs`.

### Agent Runtime Capability

`stash@{9}` added a caveat append-order doctrine pin. Current `main` already
contains `restrict_appends_caveat_at_end_preserving_existing_order_byte_for_byte`
in `agent_core/src/agent_runtime_v2/capability.rs`.

### Lattice / WBO

`stash@{14}` carried a formatting-only tweak against the old monolithic
`agent_core/src/lattice_wbo/mod.rs`. Current `main` has the newer decomposed
lattice/WBO module façade with tests split under `agent_core/src/lattice_wbo/tests/`.
The equivalent serde round-trip coverage lives in `serde_roundtrip.rs`, so the
old monolith hunk is historical only.

### Large Old-Main UI/UX Donor

`stash@{18}` is closed for current product recovery by:

- `STASH18_AGENT_COMMAND_CENTER_DONOR_SYNTHESIS_2026_05_26.md`
- `STASH18_UI_UX_CLOSEOUT_2026_05_26.md`

The old tree remains useful as donor history, but it is not a merge queue.

## Remaining Work After This Closeout

The next work is not "merge more stashes." The next work is the named
architecture backlog:

- Wave 3: AgentBlueprint end-to-end replay UI and agent metadata badges.
- Wave 4: deeper UAS / ClaimLedger rows, Cognitive DAG visualizer, and
  Tri-Fusion typed mutations.
- Deferred codewords: `RESUME ACS ANCHOR HARNESS`, `RESUME XPC MASTERY`,
  `RESUME L_SE RESEARCH`, `RESUME F-70B`, `RESUME LEAN PROOFS`, and the other
  entries in `docs/DEFERRED_WORK_GUARANTEE_2026_05_23.md`.

## Guardrail

`EpistemosTests/StashSubstrateResearchQueueCloseoutTests.swift` keeps this
decision executable. The test confirms:

1. the ledger says no active product-recovery stash rows remain,
2. ACS product wiring exists on current `main`,
3. the Settings row does not overclaim production green,
4. the F-ULP and runtime-capability doctrine pins are present, and
5. the lattice/WBO monolith hunk is superseded by the decomposed module.
