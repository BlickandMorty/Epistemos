---
state: claude-no-compromise-substrate-handoff
created_on: 2026-05-18
purpose: Single pasteable Claude handoff for the Epistemos / Helios no-compromise substrate hardening pass.
primary_source: docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md
---

# Claude No-Compromise Substrate Handoff - 2026-05-18

Paste the following prompt into Claude when handing off the Epistemos substrate hardening work.

```text
You are Claude working inside /Users/jojo/Downloads/Epistemos.

First, obey AGENTS.md. This is the macOS Opulent repo only. Do not touch ~/Epistemos-RETRO/, src-tauri/, or ~/meta-analytical-pfc/. Read before writing, write tests before code fixes, keep edits minimal, use the existing architecture, and never promote a file's existence into a feature claim.

Hardware floor:
Jojo runs on M2 Pro 14-inch (2023): 12-core CPU, 19-core GPU, 16GB unified memory, ~200 GB/s memory bandwidth. Every "M2 Pro falsifier" gate pins to this rig — not M2 Max, not M3 Max, not theoretical Apple bandwidth. F-ULP, F-KV-Direct, F-PageGather-Baseline, F-70B-Local-Cocktail-Lite all measure here.

Read this local canon first, in order:
1. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
2. docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md
3. docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md
4. docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md
5. docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md
6. docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md
7. docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md
8. docs/fusion/research/quickcapture-addenda/OBSCURA_BROWSER_ADDENDUM.md

Mission:
Execute the Epistemos / Helios no-compromise substrate hardening pass without collapsing product, research, and Vault into one pile.

Core doctrine:
Epistemos is not a notes app with AI, not a chatbot wrapper, and not Helios research everywhere. It is a native macOS verifiable cognition substrate. Models are engines. Epistemos is the memory, retrieval, permission, provenance, execution, graph, document, and UI substrate that makes those engines accountable.

Endgame name:
Active-Support Verified Cognitive Runtime. The system should select the smallest active support, check authority and error budget, execute through governed runtime paths, and leave a visible/replayable witness.

Permanent rules:
1. Build the spine, not feature sprawl.
2. Every meaningful action becomes a typed event before it becomes a UI effect.
3. A feature is not real until it is Wired, Reachable, Visible, and Verified.
4. Every item must be classified as current-wired, visible-working, visible-broken, hidden-working, hidden-dead, implemented-not-wired, feature-gated, scaffold-only, not-implemented, research-only, vault-only, or excluded-speculative.
5. Preserve all research, but promote nothing by vibes. Every branch gets a lane, tier, status, gate, and falsifier or preserved-speculation label.
6. Do not merge product lanes with memory tiers.
7. Do not materialize reality until the question forces it.

Preserve explicitly:
- Five product lanes: MAS/current app, Pro/direct, Research, Infrastructure/reserved, Vault.
- Three MAS tiers: Tier 1 ON by default, Tier 2 bundled/OFF by default, Tier 3 not MAS.
- Six/seven memory tiers: L0 hot, L1 compressed residual, L2 shadow/sketch, L3 SSD Oracle, L4/L5 cascade/adapters, L_SE self-evolving, L7 quarantine.
- UAS/UASA: stable address doctrine for notes, .epdoc blocks, graph nodes, events, tool results, retrieval chunks, memory pages, and future model components.
- ACS: composition/admission law, not a hot kernel or monolithic feature.
- Active Assembly Runtime: sparse execution doctrine; only the relevant slice wakes.
- Eidos V0: deterministic local search fusion and closed-citation retrieval.
- Eidos form layer: canonical object identity, mutation policy, witness policy, visibility, proof/evidence status.
- Lattice-Wyner-Ziv, LatticeCoder, TestTimeRegressor, WBO ledger, side-information decoding, Babai/GPTQ, Sherry, ShadowKV, QuIP/E8, residual/sketch compression.
- SCOPE-Rex, SovereignGate, CapabilityBridge, AnswerPacket, ClaimKind, VRM, TypedArtifact, MutationEnvelope, RunEventLog, AgentEvent, GraphEvent.
- Lean as schema/proof authority over time, not a hot-path runtime tax.
- EML/EML-IR, F-ULP Oracle, KV-Direct, PageGather, SSM/attention-as-interrupt, Parameter Connectome, Gate3/ternary, 70B cocktail as gated Research/Vault work.
- Hermes naming distinction: purged Hermes agent subprocess stays dead; Hermes prompt-format parity may remain; simulation-character work is unrelated.
- Agent naming is LOCKED. System G / Invader Agent is the user's canonical name. Aegis has been explicitly rejected by user direction — do not propose it, do not rename to it, do not retain it in code or docs. Code namespace is `agent_runtime_v2` when generic naming is needed.

Current priority order:
1. Product architecture ledger / anti-drift lock.
2. Vault recall contract and F-VaultRecall-50.
3. Eidos V0 closed-citation retrieval.
4. Brain Panel retrieved-source truth.
5. Eidos form layer.
6. One native governed research agent.
7. UAS/UASA metadata.
8. Lattice/WBO register.
9. ACS admission field.
10. M2 Pro falsifier handbook.
11. PageGather and UAS copy-count gates.
12. KV-Direct and F-ULP gates.
13. Pro CLI adapters only after native agents work.
14. 70B cocktail only as Research/Vault falsifier.

Launch order (from docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §3):
1. T09 Product Architecture Ledger (anti-drift lock)
2. T21 Vault Recall Contract / F-VaultRecall-50 (close the retrieval wound first)
3. T10 Eidos V0 (deterministic local search fusion + closed citations)
4. T10B Eidos Form Layer (read-only canonical schema)
5. T22B Brain Panel closed citations (make retrieved sources visible)
6. T11 Agent Runtime v2 / System G (neutral namespace; governed executor)
7. T14 Five-plane UAS-ACS wiring + T17B Lattice/WBO Register + T18B ACS Admission Field
8. T18 Residency Governor + T22 Substrate Health Panel
9. Falsifier gates as separate terminals: T12 F-ULP, T13 F-KV-Direct, T23 F-70B-Cocktail, T23B M2 Pro Falsifier Handbook
10. T27 WRV product surfacing using W-rows in docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md

In-flight terminal notice:
If T5 (codex/t5-emlir-2026-05-16) is still running on agent_core/src/research/operator_ir/, scan_ir/, or tropical_ir/, treat those directories as scope-locked-do-not-touch. T5 produces additive primitive functions; let it land before your work crosses that path. Check `git branch -a | grep t5` before claiming the path is free.

Do not build now as product:
- ModelSurgery
- Active Rank-One runtime acceleration
- 70B local cocktail execution
- runtime VPD training or PCF hot-path acceleration
- arbitrary runtime kernel birth
- p-adic or sheaf hot-path replacements
- private ANE paths
- open-ended CLI agents in MAS
- hidden cloud escalation
- hidden Python/subprocess behavior in MAS
- renaming any production module to "Aegis" (user direction; the name is rejected)

If you code:
- Write a failing test first.
- Keep scope locks tight.
- Do not refactor adjacent code.
- Do not duplicate existing modules.
- Run the narrow relevant tests and report exact commands/results.
- Mark anything without a caller as implemented-not-wired.
- Commit after every meaningful change. Jojo has lost work to git checkout before — never batch commits across feature boundaries.

If you write docs:
- Preserve wide, build narrow.
- Every table row needs lane, tier, status, evidence, missing proof, next action, and falsifier.
- Do not claim runtime proof from design docs alone.

Best first task:
Open docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md, choose the next unstarted prompt in launch order, and execute it with WRV discipline. If unsure, start T09 Product Architecture Ledger or T21 Vault Recall Contract, not 70B, model surgery, or agent wrappers.

Shortest commandment:
Preserve wide, build narrow. Current-app value first: product ledger, vault recall, Eidos V0, closed citations, one native governed agent (System G), UAS/UASA metadata, lattice/WBO register, ACS admission, and M2 Pro falsifier handbook. Keep model surgery, active rank-one runtime, PCF runtime acceleration, and 70B execution Vault/Research-only until falsifiers pass.

The 7-law theorem cocktail (from prompt deck §5):
1. Density law — Morph/EML approximates compact controller policies where the formal domain permits.
2. Address law — every cognitive object has a stable UAS/UASA address independent of residency.
3. Active-support law — only the relevant slice of notes/graph/memory/model/tools/agent state wakes.
4. Lattice-error law — every compressed or approximate representation pays into WBO.
5. Glue law — local context must cohere before it becomes global context.
6. Duplex law — hard compact and soft page-backed branches both allowed, but routing error is accounted.
7. Witness law — every meaningful action is typed, permissioned, logged, replayable, and visible.

Every research branch must fit one of these seven laws or be classified preserved-speculation.
```

