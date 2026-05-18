# ACS Admission Field - 2026-05-18

## Placement

ACS (Anchored Cognitive Substrate (structure-view) / Autopoietic Cognitive Stack (process-view)) is the admission field above SCOPE-Rex. It is not a hot-path kernel, model-inference path, cloud fallback, or direct state mutator.

The admission order is:

1. Caller forms a typed request.
2. ACS evaluates policy, capabilities, risk, and bypass constraints.
3. ACS emits a pure-data verdict plus an audit record.
4. Only allow / allow-with-warning verdicts may proceed toward SCOPE-Rex witnessed durable mutation.

## Verdict Layer

The Rust surface is `agent_core/src/acs_admission/`.

Load-bearing types:

- `ACSAdmissionInput` carries a typed payload, risk vector, request time, and granted capabilities.
- `ACSAdmissionVerdict` is the pure-data verdict enum: allow, allow-with-warning, defer, quarantine, reject.
- `ACSRiskVector` keeps all risk axes finite and bounded.
- `ACSPolicy` is request-scoped and capability-aware.
- `ACSAuditRecord` is emitted for every verdict.

Typed inputs accepted by the field:

- `MutationEnvelope`
- `ActiveAssemblyPacket`
- `AnswerPacket`
- memory write request
- tool/action request
- kernel-promotion request
- model-adaptation request

No ACS admission path calls cloud services, runs model inference, or applies durable state directly.

## Bypass Rules

Durable memory writes must carry a MutationEnvelope integration point. Kernel promotion requests must also carry a MutationEnvelope integration point plus a signed plan hash. Missing or blank integration points are rejected and audited as bypass attempts.

## Layer Cross-Link

ACS-L0 is current event/governance admission: local writes, tool actions, AnswerPackets, and MutationEnvelopes.

ACS-L1 is agent/tool-loop admission: active assembly promotion and governed action loops before durable effects.

ACS-L2 is self-healing/research admission: kernel promotion and model adaptation requests. These remain above SCOPE-Rex and require explicit policy plus audit evidence before any durable runtime lane can consume them.

Canon cross-links:

- `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T18B
- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` MASTER_FUSION §3.8
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` ACS five-layer recursion and SCOPE-Rex / Rex naming rows
