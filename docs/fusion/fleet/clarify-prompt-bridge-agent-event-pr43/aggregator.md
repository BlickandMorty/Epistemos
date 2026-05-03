---
role: aggregator
source_fleet: codex-own
slice: clarify-prompt-bridge-agent-event-pr43
date: 2026-05-03
detectives_consumed:
  - detectives/clarify-prompt-bridge-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: none
    sources: []
    resolution: none
drift_signals:
  - none
tier: Pro
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts the clarify callback bridge into an auditable bounded-provenance surface.
---

## Reconciled findings

- `ClarifyPromptBridge` is a local bridge for the Rust clarify callback, not a new Core/MAS surfaced tool or cloud/Hermes route.
- AgentEvents should record lifecycle identity, input mode, question scope, choice-count bucket, payload class, answer/cancel class, response-length bucket, and optional selected index.
- AgentEvent payloads must never persist raw question JSON, raw questions, raw choices, raw answers, prompt text, filesystem paths, or arbitrary UI/error text.
- The existing returned JSON payload remains the caller contract and is allowed to contain the user's actual answer.

## Recommended slice shape

Add a presenter seam to `ClarifyPromptBridge`, record sanitized requested/started/completed AgentEvents around the existing prompt path, and add focused Swift Testing coverage for free-form, choice, invalid/cancelled, and source-level raw-payload guards. Do not change Core/MAS tool policy, MCP/Hermes routing, Sovereign Gate, UI outside the existing NSAlert flow, graph, EventStore schema, generated bindings, or cloud/provider behavior.

## Failure-proof guardrails

- grep: `recordClarifyPromptEvent|clarify\\.ask|input_mode|question_scope|response_length_bucket|choice_count_bucket`
- log: `✔ Test "Clarify source never stores raw question JSON answers or choices" passed`
- test: `ClarifyPromptBridgeAgentEventTests`
