---
role: detective
slice: local-agent-reflex-detector-eof-flush-completion-pr31
concept: LocalAgent reflex streaming EOF flush detector completion
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §8
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/LocalAgentLoop.swift:579
  - /Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/IncrementalToolCallDetector.swift:83
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/IncrementalToolCallDetectorTests.swift:147
deliberations_consulted:
  - docs/fusion/deliberation/local_agent_reflex_eof_flush_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "LocalAgent reflex streaming EOF flush is now closed."
  code_says: "HEAD calls flushOnStreamEnd, but HEAD detector lacks the method. Working tree adds it."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/IncrementalToolCallDetector.swift
load_bearing_quote: "Fix prevents premature EOF / token truncation on local-stream path during tool-call detection."
verdict: drift
usefulness: +1
usefulness_reason: closes a real compile/behavior seam left between the committed LocalAgentLoop call and the detector implementation
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §8` names the LocalAgent streaming truncation fix as a preservation watch, with `IncrementalToolCallDetector.swift` and its tests as the code anchors.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` already says the EOF flush is closed, so the detector method must be present and tested for the canon to match branch reality.
- Commit `2eee1afe` added `LocalAgentLoop`'s call to `detector.flushOnStreamEnd()`, but `HEAD:Epistemos/LocalAgent/IncrementalToolCallDetector.swift` has no `flushOnStreamEnd` symbol.
- The working tree adds the missing detector method and focused tests proving trailing plaintext flushes once while unterminated hidden/tool buffers are dropped.

## Open Questions

- None. This is a completion/stabilization slice, not a new runtime feature.

## Recommendation

Commit the detector method and focused tests as a narrow Core preservation fix. Do not touch model routing, tool parsing/execution, UI, AgentEvent, GraphEvent, Rust, generated bindings, or Xcode project files.
