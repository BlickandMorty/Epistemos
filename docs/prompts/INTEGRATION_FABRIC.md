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
This is the core of "deeply integrated with the agents." Every feature exposes itself to **both**
agent surfaces — **June (MAS)** and the **1Code/Experimental companion** — as a **callable, honestly-
gated capability/tool** (backed by `agent_core`'s tool registry + the vault MCP). The agent can
*drive* every room: "find recent papers on X and save the top 5" (ResearchHub), "capture this
thought" (Quick Capture), "restructure this note" (Editor), "chart this table" (Data). **Every plan
states: the tool/capability schema it registers, its gating (per-turn approval, rate limits, MAS-no-
subprocess), and how each agent surface invokes it.** (Companion-exclusive capabilities are 1Code-only.)

### F3 — Companion presence (the app feels alive across features)
Plan 5 KINDRED is the presence layer, and **every feature lights it up**: when an agent works a
feature, its mascot appears on that feature's surface/button and the landing roster shows "currently
<doing X>" (reading arXiv, editing a note, capturing). **Every plan states: the activity/run-state it
emits so the companion can render presence on it**, and where its mascot pins. (Presence renders on
1Code/Experimental only; MAS shows the feature without the companion.)

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

### F6 — State/event bus (one truth, all surfaces)
Real run-state (thinking/reading/editing/tool/done/blocked) + feature activity stream from `agent_core`
to **all surfaces** — native SwiftUI and the WebView agents (June + 1Code) — in lock-step, no double
source of truth. This is what keeps presence, status, and live edits consistent across native +
WebView. **Every plan states: what events it publishes/consumes on this bus.**

## The depth bar — a worked example (ResearchHub / LODESTAR)
Not "a feed you browse," but: (F2) an agent capability — the agent searches sources, pulls OA PDFs,
summarizes, and saves; (F1) a saved item becomes a real vault note (source provenance in frontmatter);
(F5) that note **cites** its source through the ledger, and an agent answer that used it cites it too;
(F4) the note is graph-linked to related notes/entities; (F3) while the agent reads arXiv its mascot
sits on the ResearchHub button and the roster says "reading arXiv"; (F6) all of that streams live to
both agent surfaces. Every plan should hit its relevant fabric contracts to *this* depth.

## Build-order implication
The fabric is the **spine**: the agent capability registry (F2), vault bus (F1), companion presence
(F3), graph API (F4), provenance ledger (F5), and state bus (F6) are shared dependencies. Define/
harden the fabric contracts first (much already exists in `agent_core` + the graph + the ledger +
Plan 5 presence); then each room plugs in. Rooms can be built in parallel **because** they share one
fabric — as long as the fabric's contracts are stable before they plug in. Integration is not the
last step; it's the substrate.
