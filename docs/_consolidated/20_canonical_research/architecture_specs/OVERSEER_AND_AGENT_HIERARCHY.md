# Overseer and Agent Hierarchy

> **Index status**: CANONICAL-RESEARCH — Architectural spec cited from PLAN_V2.md (load when item touched).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/architecture_specs/`.



## Purpose
This document defines the supervisory and multi-agent coordination model for Epistemos.

The goal is hierarchical coordination, not swarm behavior.

## Overseer is a role, not a model family
Do not define:
- overseer = SSM
- overseer = one fixed provider
- overseer = one giant second brain

The overseer is an architectural role.

## Overseer responsibilities
- task framing
- review
- critique
- explanation
- budget recommendation
- safety recommendation
- intervention requests
- periodic quality audits
- user-facing transparency about what the system is doing

## Overseer decomposition

### Planner Overseer
Role:
- high-level planning
- task framing
- review
- critique
- “what should happen next?”

Can later be:
- local strong model
- remote strong model
- hybrid

### Guardrail Overseer
Role:
- local budget review
- safety checks
- confidence estimation
- “is this worth more compute?”
- “should this continue?”
- “should this write?”

Should be:
- smaller
- cheaper
- more local
- more deterministic

### SSM Memory Sidecar
Role:
- session compression
- memory distillation
- timeline summarization
- long-note condensation

This is the right place for SSM/Mamba by default.

## Authority boundary
Overseers may:
- recommend
- critique
- redirect
- request verification
- deny adaptation
- suggest escalation

Overseers may not:
- silently switch backend
- silently mutate policy
- silently write to knowledge
- silently trigger remote execution

Rust still decides.

## Agent hierarchy
Roles:
- overseer
- main agent
- sub-agents
- Rust control plane

### Allowed topology
Allowed:
- overseer -> main agent
- main agent <-> overseer
- main agent -> sub-agents
- sub-agents -> main agent

Disallowed by default:
- sub-agent <-> sub-agent
- sub-agent -> overseer directly
- overseer -> sub-agent directly

## Inter-agent message protocol
All messages must be structured:
- `message_id`
- `task_id`
- `parent_task_id?`
- `sender_role`
- `sender_id`
- `recipient_role`
- `recipient_id`
- `message_type`
- `instruction`
- `constraints`
- `budget_ref`
- `evidence_refs?`
- `confidence?`
- `requested_action`
- `timestamp`

## Budget rules
Every interaction is bounded by:
- recursion depth
- child-agent count
- review rounds
- token budget
- wall-clock budget
- allowed tools
- escalation permission

## Audit trail
Every message must be logged with:
- sender
- recipient
- purpose
- evidence
- confidence
- cost
- whether it changed the final result
