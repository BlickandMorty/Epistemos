# INTEGRATION FABRIC — the shared nervous system every plan plugs into

> Epistemos is **one living app, not a bundle of rooms.** Every feature integrates through a shared
> fabric of contracts. This doc defines that fabric so each plan's research designs its **deep
> plug-in** rather than a standalone silo. Owner authored 2026-07-06. Referenced by
> `RESEARCH_PROMPT_STANDARD.md` §7 and by every `RESEARCH_PROMPT_PLAN_*.md`.

## The rule
Deep integration is a **graded deliverable**, not a seam footnote. Every plan's research MUST
include a headline **"Deep Fabric Integration"** section that designs how the feature plugs into
**each relevant contract below** — with real seams (which side owns what), honest gating, and a
"this is why it feels like one app" argument. A dossier that treats its feature as an island fails
the Integration-depth rubric axis (`RESEARCH_PROMPT_STANDARD.md` §3).

This does NOT conflict with anti-collision naming: the **research docs stay scoped** (one codename/ID
each, no drift), but each scoped doc must design its integration **into the shared fabric**. Fabric =
the shared contract; each plan = a deep plug-in to it.

## The six fabric contracts

### F1 — Vault bus (the integration substrate)
Shared markdown files in the vault are the medium features integrate through. A capture, a research
item, an agent edit, a note — all are vault files; a change by one feature reflects live everywhere
(open editor, graph, search). No feature invents a private store that becomes authoritative over the
vault. **Every plan states: what it reads/writes in the vault, and how its changes propagate.**

### F2 — Agent capability registry (features ARE agent capabilities)
This is the core of "deeply integrated with the agents." While `MAS-ONLY-SHIP-LOCK-2026-07-07`
is active, every feature exposes itself to **MAS/June** as a **callable, honestly-
gated capability/tool** (backed by `agent_core`'s tool registry + the vault MCP). The agent can
*drive* every room: "find recent papers on X and save the top 5" (ResearchHub), "capture this
thought" (Quick Capture), "restructure this note" (Editor), "chart this table" (Data). **Every plan
states: the tool/capability schema it registers, its gating (per-turn approval, rate limits, MAS-no-
subprocess), and how MAS/June invokes it.** 1Code/Experimental companion capabilities are parked
provenance unless a later owner directive reopens them.

### F3 — MAS status/provenance (the app feels alive across features)
Plan 5 KINDRED is parked. Active MAS work still emits real activity/run-state so June/native
surfaces can show useful status/provenance: "currently reading arXiv," "editing a note," or
"cleaning column C." **Every plan states: the activity/run-state it emits, how MAS/June renders it
honestly, and how parked Kindred/presence symbols are excluded from the App Store archive.**

### F4 — Knowledge graph (everything links)
Features link their objects into the graph via its **public API** (never its internals): research
items ↔ notes ↔ entities ↔ captures. **Every plan states: what graph nodes/edges it creates and how
its objects relate to existing knowledge.** (The graph engine internals stay off-limits; use the API.)

### F5 — Provenance & citation (attributed, citable, honest)
Everything an agent does is attributed and citable across features, on the shared `agent_core`
provenance ledger: an agent edit (Editor), a saved paper (ResearchHub→note with source provenance),
a capture's origin, a claim's evidence. "Press the companion → see what it did" works because the
ledger spans features. **Every plan states: what it records to the ledger and how its provenance is
surfaced + cited in other features (a note can cite a ResearchHub source; an edit shows its rationale).**

### F6 — State/event bus (one truth, all MAS surfaces)
Real run-state (thinking/reading/editing/tool/done/blocked) + feature activity stream from `agent_core`
to **MAS surfaces** — native SwiftUI/AppKit and the June WKWebView — in lock-step, no double
source of truth. This is what keeps status, provenance, and live edits consistent across native +
WebView. **Every plan states: what events it publishes/consumes on this bus.**

## The depth bar — a worked example (ResearchHub / LODESTAR)
Not "a feed you browse," but: (F2) an agent capability — the agent searches sources, pulls OA PDFs,
summarizes, and saves; (F1) a saved item becomes a real vault note (source provenance in frontmatter);
(F5) that note **cites** its source through the ledger, and an agent answer that used it cites it too;
(F4) the note is graph-linked to related notes/entities; (F3) while the agent reads arXiv, MAS-safe
status/provenance says "reading arXiv"; (F6) all of that streams live to MAS/June and native
surfaces. Every plan should hit its relevant fabric contracts to *this* depth.

## Build-order implication
The fabric is the **spine**: the agent capability registry (F2), vault bus (F1), MAS status/provenance
(F3), graph API (F4), provenance ledger (F5), and state bus (F6) are shared dependencies. Define/
harden the fabric contracts first (much already exists in `agent_core` + the graph + the ledger;
Plan 5 presence is parked provenance); then each feature plugs in. **Owner preference (2026-07-06): build these ONE PLAN
AT A TIME** — not in parallel — so the whole coheres into a single, deeply-integrated piece of work
rather than six modules that merely coexist. Each plan, as it lands, must plug fully into the
fabric before the next begins. Integration is not the last step; it's the substrate, and cohesion
is worth more than throughput here.
