---
role: claude-red-team
slice: clarify-prompt-bridge-agent-event-pr43
brief: docs/fusion/deliberation/clarify_prompt_bridge_agent_event_pr43_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Confirms the brief is safe if raw prompt/answer content never enters AgentEvents.
---

## Attacks

### A1 - Clarify prompts can contain secrets [P2]

**Surface:** `ClarifyPromptBridge.ask(questionJson:)` AgentEvent arguments/results.
**Attack:** Clarifying questions and answers can include API keys, private filenames, vault names, or user instructions. Persisting raw question JSON, choices, or answers into AgentEvents would turn a diagnostic ledger into sensitive data storage.
**Evidence:** `Epistemos/Bridge/ClarifyPromptBridge.swift`; `docs/fusion/deliberation/clarify_prompt_bridge_agent_event_pr43_deliberation_2026_05_03.md`.
**Mitigation proposed:** Persist only input mode, question scope, choice-count bucket, payload class, result class, response-length bucket, and optional selected index. Leave raw text only in the existing UI and returned JSON path.

## Brief verdict

Approved. No P0/P1 attacks remain if implementation keeps the returned JSON contract unchanged while ensuring AgentEvent arguments/results/errors never include raw question JSON, questions, choices, answers, paths, or prompt text.
