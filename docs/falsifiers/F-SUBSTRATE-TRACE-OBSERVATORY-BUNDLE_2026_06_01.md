---
state: candidate-falsifier-bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source: docs/fusion/SUBSTRATE_TRACE_OBSERVATORY_2026_06_01.md
status: backlog gates; no product promotion without tests/artifacts
---

# Falsifier Bundle - Substrate Trace Observatory

## Purpose

These gates prevent "observability" from becoming another vague dashboard. A
trace is useful only when it can be replayed, compared, redacted, diagnosed,
and tied back to the route, page, source, cache, verifier, tool, and answer it
claims to explain.

## Candidate falsifiers

| Falsifier | Must prove | Minimum artifact |
|---|---|---|
| `F-CognitiveTraceGraph-Completeness` | A mission trace contains required span classes for selected source, route, KV/cache, tool, verifier, cold-fault, and answer events, or explicit waivers. | JSON fixture plus schema validation. |
| `F-RouteMicroscopeFrame-Replay` | A visible frame can reopen the underlying span, selected unit, budget, latency, reason, and answer ref without stale links. | Rendered frame fixture plus replay test. |
| `F-AttentionKVTrace-ByteBinding` | KV bytes, hit/miss tokens, codec, compatibility fence, and quality caveat are separate from weight bytes and prompt text. | KV trace fixture with rejection cases. |
| `F-AlgorithmicFailureProbe` | A task probe distinguishes correct, incorrect, heuristic, and abstain cases on a frozen fixture instead of inferring from vibes. | Arithmetic/sorting fixture plus diagnosis table. |
| `F-HeuristicNeuronCard-Ablation` | A claimed neuron/feature route includes hook identity, fixture, ablation delta, caveat, and privacy class. | Pro Research dry-run artifact; MAS waiver by default. |
| `F-AgentActionFrame-ToolReplay` | Tool/editor/browser/shell actions carry capability scope, side-effect class, input/output digests, cancellation, and rollback when mutating. | Trace fixture over a fake tool. |
| `F-SourceReasoningOverlay-Citation` | Cited, unsupported, and contradicted claims are separated and trace back to source cards and retrieval/rerank spans. | Source overlay fixture with one supported and one unsupported claim. |
| `F-TraceComparisonDeck-Regression` | Candidate route/prompt/cache/layout changes compare against a baseline on quality, evidence, verifier, bytes, latency, and failures. | Baseline/candidate deck plus decision record. |
| `F-TelemetryToWorkingSetPatch` | A trace-derived patch names diagnosed layer, patch type, expected delta, held-out fixture, rollback, and promotion gate. | Patch fixture plus no-promotion negative. |
| `F-VisualProofCapsule-AnswerPacket` | An answer that claims visible proof links to route frames, source overlay, verifier refs, KV trace, cold-fault refs, and user-visible limits. | AnswerPacket fixture plus UI summary. |
| `F-TracePrivacyRedaction` | Private bookmark, browser, note, prompt, credential, and account data are redacted or local-only before durable research use. | Redaction test corpus with canary secrets. |
| `F-ObservableSubstrate-NoHiddenAuthority` | The observatory cannot wake bytes, mutate policy, or override SCOPE-Rex/SovereignGate without a route card and rollback. | Static architecture check plus negative route fixture. |

## Promotion rule

A trace feature promotes only if it:

1. carries a schema;
2. survives redaction;
3. replays or dry-runs against a frozen fixture;
4. diagnoses a layer rather than merely logging text;
5. links to RunEventLog and AnswerPacket when user-visible;
6. has rollback for any mutation; and
7. is cheaper than the bug class or uncertainty it removes.
