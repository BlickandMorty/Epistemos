---
role: claude-red-team
slice: agent-event-apple-intelligence-generate-pr33
brief: docs/fusion/deliberation/agent_event_apple_intelligence_generate_pr33_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Tightens test seams and failure-class expectations before implementation.
---

## Attacks

### A1 - Test seam could accidentally bypass production safeguards [P2]

**Surface:** `AppleIntelligenceService.generate(...)`
**Attack:** If the test-only generation closure bypasses thermal clearance, breaker execution, or knowledge-aware system prompt resolution in production, the slice would silently weaken existing safety behavior. The implementation must keep default production closures wired to `ThermalGuard.shared`, `BreakerRegistry.shared.foundationModels`, and the existing FoundationModels path.
**Evidence:** `Epistemos/Engine/AppleIntelligenceService.swift:35-57`
**Mitigation proposed:** Inject closures only through the initializer defaults, keep `shared` on production defaults, and write tests against the public `generate(...)` method rather than a special test-only method.

### A2 - Prompt vault augmentation makes metadata leakage easier [P2]

**Surface:** `AppleIntelligenceService.knowledgeAwareSystemPrompt(from:)`
**Attack:** The service may augment a short user system prompt with model-vault context. Persisting resolved system prompt text, arbitrary error descriptions, or raw unavailable reasons would leak private vault context or host state.
**Evidence:** `Epistemos/Engine/AppleIntelligenceService.swift:165-177`
**Mitigation proposed:** Persist only char counts and a boolean for augmented-system-prompt presence; use bounded failure classes such as `unavailable`, `thermal_pause`, `cancelled`, and `generation_failed`.

## Brief Verdict

Ship the brief after applying both mitigations. No P0/P1 attack blocks implementation because the allowed files are narrow, Core-compatible, and additive provenance-only.
