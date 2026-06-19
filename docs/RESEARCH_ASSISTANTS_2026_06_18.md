# R-ASSISTANTS verdict — assistant/computer-use app survey (2026-06-18→19)

**Verdict: PATTERN-MINE, do NOT port any of them. Every app is Python or TS/Next.js
(NO-SIDECAR/MAS forbids running them) and Epistemos ALREADY owns native equivalents
of their two core capabilities — answer-engine RAG (DeerFlow deep-research + RRF
cross-index fusion + Eidos citations) and computer-use (DeviceAgentService +
AXorcist + ScreenCaptureKit + VisualVerifyLoop). Khoj is AGPL-3.0 → `research_only`
(viral copyleft, same block as R-FIELDTHEORY). The rest are MIT/Apache → pattern
adoption OK under ProvenanceGate. The single HIGHEST-VALUE mine is the computer-use
ACTION-SCHEMA + SYSTEM-PROMPT discipline (UI-TARS thought/action format, Agent-S
agent-computer interface, browser-use DOM-index + recovery loop, Open-Interpreter
confirm-before-exec) → fold into the native computer-use loop + deterministic
schemas (P8.2). Second mine: web-search + connector retrieval SOURCES for DeerFlow.
No code lifted (research-first).**

## Two families
**A — Answer-engine / RAG search:** Perplexica, Morphic, scira, Onyx, Khoj.
**B — Computer-use / agent frameworks:** Open-Interpreter, UI-TARS, Agent-S, browser-use.

## Per-app verdict (grounded where fetched ✓)
| App | License | Stack | What it is | Verdict for Epistemos |
|---|---|---|---|---|
| **Perplexica** ✓ | MIT | TS / Next.js + SearXNG | Privacy answer-engine: SearXNG web RAG → cited synthesis, Ollama/cloud, Speed/Balanced/Quality modes | **PATTERN**: add a SearXNG-style web-search retrieval SOURCE to DeerFlow (Epistemos owns synthesis + citations). Not a port. *(fetched README self-identified as a "Vane" rebrand — reconfirm repo identity if pursued.)* |
| **Morphic** | Apache-2.0 | TS / Next.js + Vercel AI SDK | Generative-UI answer engine (answer cards, streamed) | **PATTERN**: generative-UI answer cards → already the GenUI doctrine (schema-keyed renderers); mine the answer-card layout. Not a port. |
| **scira** (MiniPerplx) | Apache-2.0 | TS / Next.js + Vercel AI SDK | AI search w/ tool-calling | Covered by Perplexica/Morphic group + DeerFlow; **low-priority**, nothing net-new. |
| **Onyx** (Danswer) | MIT (core) | Python + TS | Enterprise RAG w/ 40+ CONNECTORS (Slack/Drive/Confluence…) | **PATTERN**: the connector taxonomy → Epistemos does this via MCP; mine the connector list as an MCP-server backlog. Not a port (Python). |
| **Khoj** ✓ | **AGPL-3.0** | Python + TS | "Second-brain": semantic RAG + agents + automations + Obsidian/Emacs | **`research_only`** — AGPL viral copyleft, MAS/closed-source-incompatible (same block as R-FIELDTHEORY). Inspiration only (the automation + editor-integration UX). |
| **Open-Interpreter** | MIT | Python | Local NL→code→execute agent ("the computer") | **PATTERN (have)**: agent_core `code_execution` + the approval gate already do confirm-before-exec; mine the NL→code UX. Not a port. |
| **UI-TARS** ✓ | Apache-2.0 (repo) | Python; Qwen2.5-VL-based **MODEL** | Open VLM + agent for GUI grounding (screenshot → `Thought:`/`Action:(coords)`) | **PATTERN**: the unified action-space + thought/action SYSTEM-PROMPT format → fold into DeviceAgentService/VisualVerifyLoop. The 7B VLM itself = future **Pro** local-GUI model (GPU/RAM-heavy, NOT M2-Pro-16GB today) → research-gated. |
| **Agent-S** (Simular) | Apache/MIT | Python | Computer-use framework w/ an Agent-Computer Interface (ACI) | **PATTERN**: the ACI structured-action abstraction → informs Epistemos's native computer-use action schema (deterministic schemas P8.2). Not a port. |
| **browser-use** ✓ | MIT | Python (+ Rust-core beta) + Playwright | LLM browser automation: DOM-index + screenshot + recovery loop | **PATTERN (Pro)**: DOM-extraction + recovery-loop for a future **Pro** browser-control surface (browser automation is outside the MAS sandbox; Playwright/Node = NO runtime sidecar). Its Rust-core direction aligns with agent_core. |

## What actually feeds HARNESS SYSTEMS (the synthesis)
1. **Computer-use action schema + system prompt (HIGHEST VALUE).** UI-TARS's `Thought:`→`Action:(coords)` unified action space, Agent-S's ACI, browser-use's DOM-index + recovery loop, and Open-Interpreter's confirm-before-exec are four independent takes on the same thing: a **typed, recoverable action interface between an agent and a surface**. Epistemos already has the native substrate (DeviceAgentService/AXorcist/CGEvent/VisualVerifyLoop) — what it should mine is their *discipline*: a deterministic action schema (folds into P8.2 deterministic schemas) + a recovery/verify loop (VisualVerifyLoop already exists) + a tight thought/action system-prompt. This hardens existing native computer-use; no port, no new dependency.
2. **DeerFlow retrieval sources.** The answer-engine family is, end to end, "SearXNG/connector retrieval → LLM → cited synthesis." Epistemos already owns synthesis (DeerFlow), fusion (RRF), and citations (Eidos). The mine is the *sources*: a web-search retrieval source (SearXNG-style) + a connector backlog (Onyx's taxonomy, delivered via MCP). Pattern, not port.
3. **Generative-UI answer cards** (Morphic) → already the GenUI doctrine; mine the layout for the deep-research renderer.
4. **Models.** UI-TARS-1.5-7B (Apache VLM) is the one genuinely-new *artifact* — a future **Pro** local GUI-grounding model, but GPU/RAM-heavy → not the M2-Pro-16GB ship rig; research-gated behind the existing exotic-quant/no-hidden-authority gates.

## Guardrails honored
- **NO-SIDECAR / MAS:** every app is Python or TS/Next.js — none runs as a runtime sidecar. Adopt PATTERNS natively; WebKit only for a genuine web surface (e.g. a SearXNG results view), Pro-gated.
- **ProvenanceGate:** Khoj (AGPL) → `research_only`/quarantine. MIT/Apache apps → pattern adoption permitted (descriptors/observed-behavior, not lifted code).
- **Honest gating:** browser-control + UI-TARS model are Pro/research (outside the MAS sandbox / hardware budget) — never offered on the MAS local-first surface.

## Net
None of these is a port target; collectively they're a *design corpus* for two things Epistemos already does natively. Bank the computer-use action-schema discipline (UI-TARS/Agent-S/browser-use/Open-Interpreter) into the native loop + P8.2 schemas, and the web-search/connector retrieval sources into DeerFlow. Khoj is license-blocked; the rest are pattern-only. No code lifted (research-first verdict). Cross-ref: DeerFlow deep-research, RRF fusion, Eidos citations, DeviceAgentService/VisualVerifyLoop, deterministic schemas P8.2, MCP connectors, R-FIELDTHEORY (same AGPL/Electron-vs-native lesson), R-CUA.
