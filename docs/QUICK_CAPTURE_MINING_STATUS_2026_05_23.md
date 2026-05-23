---
state: quick-capture-mining-status
created_on: 2026-05-23
worktree: /Users/jojo/Downloads/Epistemos-wrv-salvage
main_head: 24b5052cf2
donor_branch: claude/vigorous-goldberg-3a2d35
donor_head: 0e0234d9f1032942a6d1e49ffa25ecb2c28bebca
decision: no-code-mined-gated
---

# Quick Capture Mining Status - 2026-05-23

## Decision

Do not mine Quick Capture route, heal, effect, undo, nightbrain, gated
route/effect/heal evals, or modified `tools/*.rs` work in this pass.

The blocker is not file discovery. The blocker is ownership and wiring:
current main has System G / Agent Runtime v2 substrate files, but the
Swift bridge is still status-read-only and the full runtime flow is not
the settled production path for Quick Capture's diverged modules.

`Epistemos/SystemG/SystemGWiring.swift` states the current scope:

```text
status read only
full AgentBlueprint -> MissionPacket -> AgentEvent stream -> approval
-> MutationEnvelope -> RunEventLog -> AnswerPacket flow lands in
follow-up W-rows
```

That means the come-back condition from
`docs/QUICK_CAPTURE_FUTURE_RECONCILIATION_2026_05_19.md` is not met.

## Current State

Already on main:

- `tools_v2/` trait surface and 74 catalog modules
- `tools_v2/runner.rs`
- `tools_v2/breaker.rs`
- `tools_v2/reason_think.rs`
- semantic cache
- skill discovery
- browser engine
- first-run bootstrap
- JSON schemas and Quick Capture implementation plan docs

Still locked or gated on the donor branch:

| Area | Donor path | Current main path | Status |
|---|---|---|---|
| Route ladder | `agent_core/src/route/` | `agent_core/src/route/` | Diverged. Do not merge. |
| Heal/retry | `agent_core/src/heal/` | `agent_core/src/heal/` | Diverged. Do not merge. |
| Effect/receipt/appliers | `agent_core/src/effect/` | `agent_core/src/effect/` | Diverged. Do not merge. |
| Undo | `agent_core/src/undo/` | `agent_core/src/undo/` | Diverged. Do not merge. |
| Nightbrain | `agent_core/src/nightbrain/` | `agent_core/src/nightbrain/` | Diverged; main owns current shape. |
| Format/canon/grammar | `agent_core/src/{format,canon,grammar}/` | same | Diverged. Needs owner pass. |
| Workspace | `agent_core/src/workspace/mod.rs` | absent | Unique but gated on `ulid`, export, and caller ownership. |
| Capture tool | `agent_core/src/tools/capture.rs` | absent | Old tools namespace; wait typed-dispatch owner. |
| Heal/route evals | `agent_core/src/bin/*_eval.rs`, `agent_core/eval/route_v1.jsonl` | absent | Depend on diverged modules. |
| Souls | `agent_core/souls/*` | absent | Hermes-era pattern. Archive/reference only. |

Sampled line counts:

| Module | Donor `mod.rs` lines | Main `mod.rs` lines |
|---|---:|---:|
| `route` | 918 | 355 |
| `heal` | 743 | 246 |
| `format` | 89 | 101 |
| `nightbrain` | 334 | 247 |
| `effect` | 385 | 161 |
| `canon` | 213 | 63 |
| `undo` | 579 | 266 |
| `grammar` | 208 | 87 |

Standalone-looking donor files:

```text
agent_core/src/workspace/mod.rs       525 lines
agent_core/src/tools/capture.rs       153 lines
agent_core/src/bin/heal_eval.rs        92 lines
agent_core/src/bin/route_eval.rs      153 lines
agent_core/eval/route_v1.jsonl         36 lines
```

## Donor-Mining Test

### Diverged route/heal/effect/undo/nightbrain

| Question | Result |
|---|---|
| Unique vs main? | Yes, but in modules that also exist on main with different contracts. |
| Pure-additive? | No. Mining requires reconciling broad existing modules. |
| Compiles without old architecture? | Not acceptable to attempt as a batch. These modules depend on branch-era route/heal/effect/format/undo ownership. |
| Preserves doctrine? | No until System G real production path and typed dispatch ownership are settled. |
| Spine class | Spine-adjacent but gated. |

Classification: **blocked**.

### `workspace/mod.rs`

| Question | Result |
|---|---|
| Unique vs main? | Yes. |
| Pure-additive? | File-additive, but requires `ulid` dependency and `pub mod workspace;`. |
| Compiles without old architecture? | Not proven. Current main already fails `agent_core` compile with missing `ulid` in `skill_discovery` and stale `crate::tools::*` imports in `tools_v2`. |
| Preserves doctrine? | Probably, once System G owns the job/workspace story. Not ready today. |
| Spine class | Spine-adjacent, mine later. |

Classification: **implemented-not-wired / gated**.

### `tools/v2_catalog` donor path

| Question | Result |
|---|---|
| Unique vs main? | No for the catalog/runner/breaker/reason_think behavior. Main has it under `agent_core/src/tools_v2/`. |
| Pure-additive? | File-additive only because the donor path is old. |
| Compiles without old architecture? | No reason to import old `tools/` namespace. |
| Preserves doctrine? | No. Current doctrine uses `tools_v2/`. |
| Spine class | Already handled. |

Classification: **archive**.

## Compile / Verification Status

The explicit installed Rust toolchain is:

```text
stable-aarch64-apple-darwin
```

Current `agent_core` compile is not green from this worktree. The same
baseline blockers surfaced during M3:

```text
src/cache/mod.rs:328: unresolved import crate::tools::VariantId
src/tools_v2/legacy_adapter.rs:148: unresolved import crate::tools::runner
src/tools_v2/legacy_adapter.rs:149: unresolved import crate::tools::Status
src/tools_v2/reason_think.rs:115: unresolved import crate::tools::runner
src/tools_v2/reason_think.rs:116: unresolved import crate::tools::Status
src/tools_v2/reason_think.rs:161: unresolved import crate::tools::SchemaValidator
src/tools_v2/reason_think.rs:210: unresolved import crate::tools::SchemaValidator
src/tools_v2/v2_catalog/mod.rs:561: unresolved import crate::tools::Profile
src/skill_discovery/mod.rs:309: missing crate/module ulid
```

Because this pass is donor mining, not baseline repair, these compile
blockers are recorded but not fixed here.

## WRV Classification

| Candidate | Classification | Reason |
|---|---|---|
| Route/heal/effect/undo/nightbrain | blocked | Diverged modules with no settled System G caller chain. |
| Workspace | feature-gated / implemented-not-wired | Unique and plausible, but no owner/caller and needs dependency/export. |
| Capture tool | implemented-not-wired | Old namespace and no typed-dispatch decision. |
| Heal/route evals | blocked | Depend on diverged modules. |
| Tools v2 catalog donor path | archive | Already on main under `tools_v2/`. |

## Hardening Notes

- No code was mined.
- No broad existing files were touched.
- No hidden subprocess, cloud, or tool execution behavior was introduced.
- Feature-flag fallback remains the current System G behavior: status read
  only, default off, MAS mode disabled.
- The stale/invalid path is handled by status: do not mine branch-era
  modules until their current owner path exists and compiles.

## Verification Performed

```bash
sed -n '1,220p' docs/QUICK_CAPTURE_FUTURE_RECONCILIATION_2026_05_19.md
git show salvage/auxiliary-branch-salvage-ledger-2026-05-23:docs/AUXILIARY_BRANCH_SALVAGE_LEDGER_2026_05_23.md
rg -n 'System G|LocalAgentLoop|typed dispatch|tools_v2|agent_runtime_v2|effect|undo|nightbrain' docs agent_core/src Epistemos
rg --files agent_core/src | rg '^(agent_core/src/)?(route|heal|effect|undo|nightbrain|format|canon|grammar|workspace|tools_v2|agent_runtime_v2)'
sed -n '1,220p' agent_core/src/agent_runtime_v2/mod.rs
sed -n '1,220p' Epistemos/SystemG/SystemGWiring.swift
```

## Final M4 Status

M4 is closed as **gated/status-only**. Quick Capture remains preserved.
Do not mine the locked modules until System G's real production path and
typed dispatch ownership are green and current.
