# Hermes Cloud Gateway Architecture Decision - 2026-05-02

Date: 2026-05-02
Scope: Doctrine/current-state clarification only
Code impact: None

## Decision

Hermes is the unified Pro/Research external-intelligence control surface for
cloud model orchestration, MCP/web/browser tooling, Docker/devcontainer work,
and user-installed coding CLI delegation. That does not mean every token must
flow through one Hermes subprocess. Fast in-process provider paths in Rex /
`agent_core` remain valid when a gate approves them.

Hermes is not the graph. It is not Rex. It is not the deterministic substrate.

Epistemos remains the local sovereign authority: Rex and the in-process
Swift/Rust substrate own the claim graph, ledger, residency hierarchy, KV/cache
state, verification ladder, provider security, and mutation/event logs. Hermes
may fetch, deliberate, coordinate external tools, or ask a CLI to produce a
result, but it returns structured evidence back into the substrate.

## Why

- Keeps Core/MAS clean: no Hermes, MCP, Docker, browser/computer-use, or coding
  CLI subprocesses in the App Store target.
- Keeps inference architecture direct: hot inference remains single-binary,
  in-process, and zero-copy; subprocesses are orchestration only.
- Keeps product UX unified: users see one Epistemos agent surface, not a pile of
  unrelated CLIs and provider adapters.
- Keeps provider churn contained: the unified gateway absorbs cloud model API,
  rate limit, MCP, and tool-execution variation while preserving direct
  in-process provider paths when they are faster and gated.
- Keeps graph truth local: cloud output is evidence to verify, not authority to
  mutate the graph without typed artifacts, mutation envelopes, and gates.

## Allowed

- Pro/Research Hermes gateway/control surface for cloud model orchestration and
  external tools.
- Gated Rex / `agent_core` direct provider streaming where speed, security, and
  Core/Pro separation require the in-process path.
- Hermes-mediated or gateway-registered Claude Code / Codex / Kimi / Gemini CLI
  delegation.
- Hermes-mediated or gateway-registered MCP, browser/computer-use, Docker, and
  devcontainer work.
- Local Hermes-family model prompt formatting through
  `Epistemos/LocalAgent/HermesPromptBuilder.swift`; this is separate from the
  Hermes subprocess gateway and can remain local/offline when the model is
  installed.

## Forbidden

- Treating Hermes as the graph, residency governor, claim DAG, or source of
  deterministic truth.
- Adding new direct Pro/Research cloud/CLI routes that bypass the unified
  gateway/control surface without a deliberation gate.
- Any Hermes/MCP/CLI/Docker/browser/computer-use surface in Core/MAS.
- Any subprocess inference path in any tier.
- Any hot-path tensor copy across CPU/GPU/ANE boundaries.

## Builder Rule

If a future slice says "cloud model", "external tool", "MCP", "browser",
"computer use", "Docker", or "Claude/Codex/Kimi/Gemini CLI" in Pro/Research,
start from the Hermes/gateway control surface and decide whether the concrete
adapter is in-process Rex/provider code or a Hermes subprocess. If the slice
says "graph", "Rex", "residency", "KV", "ledger", "verification", or
"mutation", start from the in-process substrate.

## Claude Read-Only Advisory

Claude Code was run read-only against the doctrine/current-state/queue/source
map and flagged a real ambiguity: "Hermes" names three separate things.

- Hermes-family local LLM / prompt format: can be Core-safe when in-process.
- Hermes subprocess / Python agent: Pro/Research orchestration only.
- Hermes/gateway control surface: product architecture seam for external
  intelligence, not necessarily a single subprocess transport.

This decision adopts that correction. It rejects Hermes-as-graph-authority and
also rejects forcing every provider token through a subprocess when Rex /
`agent_core` can do the direct, faster, gated in-process work.
