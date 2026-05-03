---
role: web-researcher
slice: agent-event-apple-intelligence-generate-pr33
external_dep: Apple Foundation Models / SystemLanguageModel
primary_source_url: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
source_date: 2026-04 crawled; Apple page itself undated
tier_compatibility: Core
local_canon_alignment:
  agrees_with: MASTER_RESEARCH_INDEX_2026_05_02.md §0 H3, §12
  disagrees_with: none
load_bearing_quote: "on-device text foundation model"
secondary_sources:
  - url: https://developer.apple.com/documentation/foundationmodels/languagemodelsession
    date: 2026-04 crawled; Apple page itself undated
    note: Confirms session-style FoundationModels generation object.
verdict: confirms-canon
usefulness: 0
usefulness_reason: Confirms the existing API framing; PR33 does not change FoundationModels calls.
---

## Summary

Apple documents `SystemLanguageModel` as the on-device text model powering Apple Intelligence and exposes availability checks before use. `LanguageModelSession` is the current session object for generation.

## Implication For The Slice

PR33 should not alter availability, prompt, session, or context-window behavior. It should only wrap the existing service boundary with sanitized provenance.

## Tier Note

The local canon lists Apple Intelligence as Core/App Store compatible bounded execution, and the official API is an Apple framework surface rather than a subprocess or Pro tunnel.
