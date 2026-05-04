# Five Laws And Phase I Recovery Bridge — 2026-05-04

Track: T0 substrate unification / T5 Hermes-agent runtime / T13 tooling.

This document preserves the durable substrate synthesis from the
`codex/runtime-memory-hardening` branch without letting its older phase order
override the current fusion recovery sequence.

## Donor Authority

Sources:

- branch `codex/runtime-memory-hardening`
- commit `35669655` — `docs/UNIFIED_SUBSTRATE_RESEARCH.md`
- branch `docs/CODEX_MASTER_PROMPT.md` unified-substrate section
- branch `docs/VISION_BACKLOG.md` Phase I and substrate-sprint section

## The Five Laws

| Law | Recovery interpretation |
|---|---|
| 1. Measure before you cut | Architecture PRs need measurements: allocation count, frame time, call frequency, binary size, or latency evidence |
| 2. Entity store is a new crate | `substrate-core` grows beside existing models; do not refactor Swift identity in place |
| 3. Identity unification first | `EntityID` as a Rust-owned generational key exposed as a stable scalar; migrate notes first, then links/tags |
| 4. UniFFI stays until profiling proves otherwise | Use UniFFI for cold/control paths; only measured hot paths graduate to C ABI / shared memory / typed buffers |
| 5. Python leaves the shipping runtime | In current fusion terms: MAS/Core runtime is Swift + Rust + Metal. Any subprocess or Python-like path is explicit, gated, non-hot-path, and not a silent dependency |

The original branch wording said "Python out-of-process immediately." Current
fusion canon is stricter for shipping: the app is macOS Opulent, Swift + Metal
+ Rust FFI, and no hidden Python runtime belongs in MAS V1. Pro/research
experiments can be separately gated.

## Four Substrate Sprints

| Sprint | Donor intent | Current fusion placement |
|---|---|---|
| 0. Audit | inventory identity types, state owners, FFI calls, Python invocations, binary size | Recovery audit / dirty-tree map / substrate inventory |
| 1. EntityID + runtime isolation | new `substrate-core`, slotmap-style entity identity, isolate Python | T0/T1 foundation and MAS runtime purity |
| 2. Action grammar | `AppAction` Rust enum plus event log for mutations | T1 MutationEnvelope / RunEventLog / AgentEvent |
| 3. Window singularity | same note in two windows propagates through one canonical store within one frame | T9 editor plus Rust-owned substrate projection |
| 4+. Measure and iterate | profile again and migrate by evidence | V2 deepening after recovery |

## Seed Crystal

The branch's useful seed:

> Build `substrate-core` as a new Rust crate with generational entity storage
> and an `AppAction` event log. Expose `EntityID` as a scalar over FFI. Migrate
> note identity first. Keep everything else running. Measure everything.

Fusion mapping:

- `substrate-core` remains a valid T0/T1 substrate candidate.
- `AppAction` must reconcile with current `MutationEnvelope`, `TypedArtifact`,
  `AgentEvent`, `GraphEvent`, and `RunEventLog` names.
- Identity migration must be incremental and reversible; no broad model rewrite.

## Phase I Rust Agent Migration

Donor Phase I requires the agent runtime to become pure Rust before release:

1. providers in Rust;
2. tool dispatch in Rust;
3. skills loader in Rust;
4. MCP server in Rust;
5. scheduler in Rust;
6. drop Python dependency;
7. final validation.

Current fusion status:

- The named intent is preserved: local agent runtime should converge toward
  Swift + Rust + Metal, no hidden Python dependency, and no hot-path subprocess.
- The current recovery sequence is still authoritative: A-F recovery first,
  then V1 ship gate, then Substrate V2, then V3 research tier.
- Implementation slices must respect XPC no-compromise, MAS/Pro separation,
  Tool V2 migration, and Sovereign Gate capability receipts.

## Anti-Overrides

Do not use this branch to:

- replace the current canonical recovery sequence;
- introduce Python as a hidden MAS dependency;
- collapse XPC trust services "for V1";
- mass-migrate FFI without profiling;
- rewrite Swift models in place;
- start the agent-harness substrate before the identity/action/event substrate
  exists.

## Recovery Placement

Use this bridge as a lens for:

- T0 substrate unification;
- T1 entity/action/event schemas;
- T5 Hermes runtime recovery;
- T9 window-singularity editor proof;
- T13 tooling migrations.

It is research/prototype canon, not an immediate cherry-pick list.
