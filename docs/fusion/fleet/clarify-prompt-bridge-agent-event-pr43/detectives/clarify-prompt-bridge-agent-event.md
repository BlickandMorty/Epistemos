---
role: detective
slice: clarify-prompt-bridge-agent-event-pr43
concept: ClarifyPromptBridge AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §13
tier: Pro
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ClarifyPromptBridge.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift
deliberations_consulted:
  - docs/fusion/deliberation/phase4_screen_watch_agent_event_pr42_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Privacy / Telemetry / Security"
  code_says: "[paraphrase] Clarify prompt had no bounded AgentEvent lifecycle emission before PR43."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ClarifyPromptBridge.swift
load_bearing_quote: "Performance is architecture."
verdict: open
usefulness: +1
usefulness_reason: Identifies the next small provenance bridge after Phase4 was closed.
---

## Findings

- `ClarifyPromptBridge.ask(questionJson:)` already owns the full Rust clarify callback to native NSAlert path and returns the caller-facing JSON contract.
- The bridge previously decoded raw `questionJson`, showed raw question/choice/answer material to the user, and returned raw answer JSON without recording AgentEvents.
- The correct slice is lifecycle-only provenance around the existing prompt call; raw question JSON, raw questions, choices, answers, and filesystem paths must remain out of AgentEvent arguments/results/errors.
- The implementation can preserve the singleton while adding an injectable presenter seam for Swift Testing.

## Open questions

- None for this slice.

## Recommendation

Add requested, started, and completed AgentEvents with sanitized buckets/classes only. Keep raw user-facing prompt/answer text in the existing UI and returned JSON path, not in persisted AgentEvent payloads.
