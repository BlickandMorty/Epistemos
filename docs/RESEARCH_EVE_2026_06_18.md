# R-EVE — Vercel `eve` agent framework verdict (2026-06-18)

Research-first verdict on **eve** ("Like Next.js, for agents", `npm i eve`,
open-source by Vercel). Owner ask: what maps onto our `agent_core` loop / Companion
builder / skills? Take/skip + free-vs-paid + license + on-device-vs-cloud + UX.

## TL;DR

**Do NOT port/adopt eve as a dependency** — it's a Node/TypeScript framework
(server/CLI runtime, AI-Gateway-flavored), not native, not on-device, not MAS-safe
to embed. **DO adopt its *pattern* selectively** as the blueprint for the Companion
agent-builder + cowork. The headline: **eve's filesystem-first agent layout is
the same shape we're already converging on**, and we **already have its `skills/`
= one-Markdown-playbook idea** (our `SKILL.md` + procedural memory). Treat eve as a
design reference, not code.

| eve concept | Our equivalent | Verdict |
|---|---|---|
| **agent.ts** (model config, provider fallback) | `CompanionModel` (name/model/tools/system-prompt/output-schema) + RuntimeRouter fallback | Have it. Consider a portable **agent folder** form (below). |
| **instructions.md** (system prompt) | `Companion.customSystemPromptTemplate` (P2.6, validated) | Have it. See "AGENTS.md > skills" note. |
| **tools/** (one TS file = one tool) | Rust `agent_core` tool registry (tiered, MAS/Pro-gated, P7.1) | Ours is stronger (determinism + capability ceiling). Keep. |
| **skills/** (one .md playbook, loaded when relevant) | `SkillDiscoveryCatalog` → `skills/<id>/SKILL.md` + procedural memory (P2.4) | **Already have the exact pattern.** ✅ |
| **sandbox/** (isolated compute + file tools) | Pro containerization (osaurus direction) + `security.rs` subprocess hardening | Roadmap (Pro-only). eve confirms the shape. |
| **schedules/** (cron jobs) | `agent_core/scheduling.rs` + the scheduling tool | Have it. |
| Durable execution / human-in-the-loop / subagents | session persistence + `AgentAuthority` approvals + `delegate_task` tool | Have all three; validate parity. |

## What's genuinely worth taking (the 20%)

1. **Filesystem-first, portable Companion agents.** eve's best idea: *an agent is
   a directory* — drop a file to add a tool/skill/schedule, auto-wired. Today a
   Companion is a `CompanionModel` row. Worth evolving the **agent meta-builder
   (P2.6)** toward a portable folder: `companion/<name>/` = `config.json` +
   `instructions.md` + `skills/` + a tools allowlist. Benefits: shareable/
   exportable agents, human-readable, versionable, and it composes with our
   existing `SKILL.md` discovery for free. **TAKE as a direction** (not urgent).
2. **"AGENTS.md outperforms skills in our evals" (Vercel).** Their own evals found
   a single strong instructions file beat granular skills for many tasks. Signal
   for us: keep investing in the **instructions/system-prompt** quality (and the
   capability manifest) as the primary lever; skills are the *focused-playbook*
   complement, loaded when relevant — which is exactly how our procedural memory
   already gates them. Don't over-rotate to many tiny skills.
3. **Build-time auto-wiring (no register boilerplate).** Our Rust registry already
   auto-registers; our `SkillDiscoveryCatalog` already auto-discovers. eve
   validates the "no manual registration" ergonomic — keep it for the cowork
   connectors/MCP (P7.6) too (drop a config → it appears).

## What to SKIP

- The runtime/dependency itself (Node/TS, Vercel AI Gateway, cloud-deploy
  orientation) — conflicts with local-first, on-device, MAS. We are Swift + Rust.
- Its sandbox backends (Vercel/cloud sandboxes) — we use native security.rs +
  Pro containerization.

## Founding-Thesis fit

eve is model-agnostic plumbing; it does **not** add determinism/verifiability —
that's *our* edge (grammar/json-schema constraint, ClaimLedger/AnswerPacket,
Cognitive DAG, capability ceiling). So: borrow eve's **ergonomics** (filesystem-
first, auto-wire, portable agents), keep **our** determinism substrate. Net: a
small, high-leverage influence on the Companion builder + cowork, **zero code
dependency.**

## Sources

- [Introducing eve (Vercel changelog)](https://vercel.com/changelog/introducing-eve-an-open-source-agent-framework)
- [Introducing eve (blog)](https://vercel.com/blog/introducing-eve)
- [vercel/eve (GitHub)](https://github.com/vercel/eve)
- [eve docs — Introduction](https://eve.dev/docs/introduction)
- [AGENTS.md outperforms skills in our agent evals (Vercel)](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals)
