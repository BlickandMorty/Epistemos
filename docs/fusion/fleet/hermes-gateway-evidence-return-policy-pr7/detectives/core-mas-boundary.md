---
role: detective
slice: hermes-gateway-evidence-return-policy-pr7
concept: Core/MAS release split and Pro tunnel boundary
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §12
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/HermesGatewayPolicy.swift:56
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/HermesGatewayPolicyTests.swift:52
deliberations_consulted:
  - docs/fusion/deliberation/hermes_gateway_app_store_guard_pr5_deliberation_2026_05_02.md
  - docs/fusion/deliberation/hermes_gateway_route_policy_pr6_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: false
  canon_says: "NO shell, Bash, Docker, CLI, iMessage, background agents"
  code_says: "[paraphrase] HermesGatewayPolicy marks external gateway surfaces Pro/Research and disallows them in Core App Store builds."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/HermesGatewayPolicy.swift
load_bearing_quote: "Keep the Core/App Store path local-first and clean"
verdict: partial
usefulness: +1
usefulness_reason: Confirms PR7 must remain pure policy and cannot add runtime adapters or entitlements.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §12` makes the App Store profile bounded execution only and forbids shell/Docker/CLI/background-agent leakage.
- Current-state §4 says Hermes/gateway is the Pro/Research cloud/tool control surface, while direct CLIs are delegated tools behind it.
- Preflight PR7 tier-leakage grep hits only existing `dockerDevcontainer` enum policy classification lines; that is expected and not a runtime leak.

## Open Questions

- None. Current external App Store policy is not needed for this code-only policy helper because no entitlement, provider, or runtime App Store behavior changes.

## Recommendation

Keep PR7 confined to `HermesGatewayPolicy` and `HermesGatewayPolicyTests`; do not browse, call providers, spawn subprocesses, alter entitlements, or change prompt/runtime adapters.
