# Adaptation Subsystem Spec v1

## Purpose
The Adaptation Subsystem exists to host bounded, reversible, helper-model-first adaptation without destabilizing the main runtime.

This is where LoRA, micro-TTT, anchor state, rollback, and canary validation live.

## Scope
Allowed early:
- LoRA-based helper-model adaptation
- chunked micro-updates
- session-scoped domain adaptation
- knowledge-ingestion helper tuning
- retrieval/reranker helper adaptation

Not allowed early:
- default main-model adaptation
- full-weight fine-tuning
- silent learning from arbitrary chat
- base-weight mutation

## Adaptation entities
- `adapt_session_id`
- `adapter_id`
- `update_chunking`
- `stabilizer`
- `rollback_ref`
- `canary_policy_ref`

## Hard rules
- adaptation is session-scoped
- adaptation is never silent
- adaptation is delta-only
- adaptation is MLX-first
- adaptation is helper-model-first
- no primary-chat default adaptation
- no base-weight mutation

## Stabilization requirements
Every adaptation-capable flow must support:
- anchor state
- canary validation
- rollback
- update norm caps
- telemetry

## First viable implementation
LoRA micro-TTT helper model path:
- rank-limited adapters
- chunked updates
- anchor state
- rollback log
- canary checks
- explicit adaptation telemetry

## Suggested first use cases
- note ingestion
- graph enrichment
- summarization helper improvement
- retrieval reranker improvement
- small domain-specific helper adaptation
