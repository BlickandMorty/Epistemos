---
role: web-researcher
slice: overseer-core-mas-tool-permission-fallback-pr1
external_dep: Apple App Review Guideline 2.5.2
primary_source_url: https://developer.apple.com/appstore/resources/approval/guidelines.html
source_date: undated - verified 2026-05-03
tier_compatibility: Core
local_canon_alignment:
  agrees_with: MASTER_RESEARCH_INDEX_2026_05_02.md §12
  disagrees_with: none
load_bearing_quote: "may not read or write data outside the designated container area"
secondary_sources: []
verdict: confirms-canon
usefulness: 0
usefulness_reason: Confirms the local Core/App Store bounded-execution canon; does not change the implementation.
---

## Summary

Apple's current official App Review Guidelines continue to frame App Store apps as self-contained and bounded. The local canon already encodes the stricter Epistemos policy: Core/App Store must not advertise or execute shell, Docker, CLI, or external agent-style surfaces.

## Implication For The Slice

The external source reinforces the existing local rule. This slice should not add new App Store policy; it should simply make the degraded Overseer fallback obey the existing `ToolSurfacePolicy` gate.

## Tier Note

Core/App Store only. Pro/Research can keep external gateway names when routed through approved Hermes/ToolTier/Omega gates.
