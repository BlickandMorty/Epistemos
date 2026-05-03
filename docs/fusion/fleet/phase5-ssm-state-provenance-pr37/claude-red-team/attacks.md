---
role: codex-red-team
slice: phase5-ssm-state-provenance-pr37
brief: docs/fusion/deliberation/phase5_ssm_state_provenance_pr37_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Pre-emptively constrains payload sanitization and Phase5 scope creep.
---

## Attacks

### A1 - Raw SSM action payload could leak model ids or filesystem paths [P2]

**Surface:** `Phase5Bridge.manageSsmState(actionJson:)`
**Attack:** The incoming JSON can contain arbitrary `model_id`, action names, and future fields. AgentEvent arguments/results must not persist raw `actionJson`, model identifiers, state URLs, or cache details.
**Evidence:** `Epistemos/Bridge/Phase5Bridge.swift:31`
**Mitigation proposed:** Persist bounded `action_class` and `model_scope` only; source tests must encode captured events and assert forbidden raw strings are absent.

### A2 - Scope could accidentally expose save/load SSM cache control [P2]

**Surface:** `Phase5Bridge.manageSsmState(actionJson:)`
**Attack:** The bridge currently rejects `save` and `load` because live MLX cache access belongs to the generation context. Instrumentation must not turn those into callable paths.
**Evidence:** `Epistemos/Bridge/Phase5Bridge.swift:79`
**Mitigation proposed:** Keep `save`/`load` as requested+failed events with `failure_class=unsupported_action` and preserve existing external error.

## Brief verdict

Approved. The brief can ship if tests prove raw payload exclusion, unsupported action failure, bootstrap-unavailable failure, and one completed read-only SSM action.
