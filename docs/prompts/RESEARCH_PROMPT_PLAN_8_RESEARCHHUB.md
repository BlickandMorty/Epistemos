# DEEP-RESEARCH PROMPT — PLAN 8: RESEARCHHUB (multi-source research feed + agent capability)

**ID:** `EPI-RP-08-LODESTAR` · **Codename:** LODESTAR · Obey `RESEARCH_PROMPT_STANDARD.md` §3 rubric + §4 sources + §5 shape + §7 fabric (deep integration is graded).

> Paste below `─── BEGIN ───` into a deep-research model. Output = build-ready dossier. Owner
> authored 2026-07-06. **Build split: both builds (MAS + 1Code).** A prior source dossier exists
> (`docs/research/RESEARCHHUB_SOURCE_DOSSIER_2026_07_03.md`) — this brief re-researches to a
> build-ready depth; reconcile with it, don't ignore it.

─── BEGIN RESEARCH BRIEF ───

## 0. Who you are / deliverable
Principal research-aggregation architect. Produce a build-ready dossier for **ResearchHub** — a
dedicated in-app room + agent capability that pulls from many research sources into an adaptive
native timeline, deeply integrated with Notes, the Agent, and the Graph. External primary sources
(each provider's official API/ToS, OA infrastructure, feed/ingest design). Cite everything; invent
nothing. **Legality/ToS is a first-class constraint** here. Design against the file names below.

## 1. Product context (ground truth)
Epistemos = macOS-native PKM. It already has a **dedicated arXiv feature** (`Epistemos/Arxiv/
ArxivClient.swift`, `ArxivIngestService.swift`, `ArxivPullGateStatus.swift`, `Views/Arxiv/
ArxivSearchView.swift`) — **ResearchHub generalizes that pattern to many sources** without demoting
arXiv (arXiv + Obscura stay dedicated). Integration is via **shared vault files**: a research item
becomes a note; the Agent (June on MAS / 1Code on Experimental) can *use ResearchHub as a
capability*; the Graph links research to your knowledge. Two builds, ships in **both**. The look is
an **adaptive-card native timeline** (flat/minimal/theme-aware, per the nativeness doctrine).

## 2. Thesis
**One room where papers, posts, repos, and models from many sources flow into an adaptive native
timeline you can read, save-to-vault, link in the graph, and hand to an agent — sourced only through
legitimate, ToS-clean channels, with a clean open-access retrieval chain.**

## 3. Hard constraints
1. **Legitimate sourcing only** — official APIs / RSS/Atom / open-access infrastructure / BYO-
   credential lanes. **Never** Sci-Hub, never scholarly-site scraping that violates ToS, never
   credential-harvesting. The open-access PDF chain is **DOI → Unpaywall/OpenAlex → publisher OA
   PDF**; if no OA copy exists, link out, don't pirate. Document each source's ToS/rate limits.
2. **Files are truth** — a saved research item is a real vault note (with provenance to the source);
   ResearchHub's own store is a derived cache, not authority.
3. **Honest agent capability** — ResearchHub is exposed to the agent as a tool/capability with
   honest gating (rate limits, credentials, per-turn approval for network); MAS = no subprocess.
4. **Adaptive-card native timeline** — flat/minimal/theme-aware; performant with large/streaming
   feeds; not a web dump.
5. Platform hygiene: keys/tokens in Keychain (never UserDefaults); `@Observable`; never block
   `@MainActor`; don't touch the graph engine internals (use its public API to link).

## 4. What exists today (extend, don't reinvent)
- **arXiv template:** `Epistemos/Arxiv/*` (client, ingest service with a pull gate, search view) —
  the canonical shape to generalize. `ArxivIngestService` is the ingestion pattern.
- **Prior dossier:** `docs/research/RESEARCHHUB_SOURCE_DOSSIER_2026_07_03.md` (+ raw workflow docs).
- **Vault write:** `Epistemos/Sync/VaultSyncService.swift` (`createPage`) → notes; graph public API
  for linking; the Agent surfaces (June / 1Code) for the capability seam.
- Nativeness/look: `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

## 5. Research dimensions
### D1 — Source matrix (the legality-first core) ★
For EACH candidate source, document: official API/feed, auth model, rate limits, **ToS/licensing**,
data available, and a legality verdict (green / BYO-credential / avoid). Cover at least:
- **Papers/preprints:** arXiv (have), bioRxiv/medRxiv, PubMed/PMC, Semantic Scholar API, OpenAlex,
  Crossref, CORE, DOAJ, HAL, SSRN (ToS!).
- **Open-access retrieval chain:** DOI → **Unpaywall** / OpenAlex `oa_location` → publisher OA PDF;
  when no OA copy, link out. Detail the exact chain + fallbacks + caching rules.
- **Code/models:** GitHub (API, trending), Hugging Face (models/datasets/papers), Papers-with-Code.
- **Social/community:** Hacker News (Firebase/Algolia API), Reddit (API + new ToS/pricing reality),
  X/Twitter (API tiers + cost + ToS — be honest about feasibility), Mastodon/Bluesky (open APIs),
  Lobsters, RSS/Atom for anything else.
- **Journals/news:** publisher RSS, Nature/Science feeds (headlines vs full-text boundary).
For each: what's freely legal vs needs the user's own key/account (BYO-credential lane). No source
that requires ToS violation to be useful should be included as default.

### D2 — Ingest & normalization
- Generalize `ArxivIngestService` into a **multi-source ingest pipeline**: per-source adapters →
  a normalized "research item" schema (title/authors/abstract/date/source/ids(DOI/arXiv/HF)/links/
  OA-PDF/media/score) → dedup across sources (same paper from arXiv + OpenAlex + HN) → ranking/
  recency/relevance → a pull-gate (rate-limit-honest, like `ArxivPullGateStatus`). Streaming +
  incremental. Cite each API's response reality.

### D3 — The adaptive-card native timeline (UX)
- The native SwiftUI **adaptive-card** timeline: card variants per item type (paper/repo/model/post),
  flat/minimal/theme-aware, performant with large + streaming feeds, filters/sources/saved-searches,
  read/queue/save states. Cite best-in-class research readers (Elicit, Semantic Scholar, Papers,
  Readwise Reader, Zotero, arXiv-sanity/Connected Papers) for UX patterns to steal.

### D4 — Deep integration (Notes + Agent + Graph)
- **Save-to-vault**: item → real markdown note (provenance to source + OA PDF handling → Plan 3
  PDF→md boundary). **Graph**: link a saved item to related notes/entities via the graph public API.
  **Agent capability**: expose ResearchHub as a tool the agent calls ("find recent papers on X",
  "summarize + save the top 5", "watch this topic") — honest gating, MAS-safe. Define the tool schema.

### D5 — Watch/feed intelligence (optional, honest)
- Saved topics/authors/repos → a personal feed; digest generation; dedup over time; "why am I seeing
  this." All opt-in; don't spam. Cite feed/recommendation patterns without dark patterns.

### D6 — Legality, privacy, robustness
- A consolidated **ToS/rate-limit/attribution table** + the rule engine that keeps the app compliant
  (backoff, caching TTLs, attribution/citation, no-scrape guardrails). Privacy: tokens in Keychain,
  what leaves the device. Failure table: API down/changed, rate-limited, no OA copy, malformed feed.

### D7 — Competitive synthesis
- Cited table: Elicit, Semantic Scholar, Connected Papers, Research Rabbit, Readwise Reader, Feedly,
  Zotero. Columns: sources, OA retrieval, save-to-KB, agent use, graph links, legality. Copy/avoid +
  the novel edge (agent-native + graph-linked + honest OA).

### D★ — Deep Fabric Integration (F1–F6) — MANDATORY (`INTEGRATION_FABRIC.md`)
ResearchHub is the fabric's showcase — "not a room you visit, a capability the agents drive":
- **F1 vault:** a saved item becomes a real vault note (source provenance in frontmatter).
- **F2 capability:** the agent searches/pulls/summarizes/saves/watches via a ResearchHub tool — the
  exemplar capability. Define its schema + honest gating (rate limits, BYO-credentials, MAS-safe).
- **F3 presence:** the companion mascot sits on the ResearchHub button while reading; roster shows
  "currently reading arXiv."
- **F4 graph:** saved papers link to related notes/entities via the graph public API.
- **F5 provenance:** a note (and an agent answer that used it) CITES its source through the ledger.
- **F6 state bus:** streaming-feed + pull state publishes on the bus.
Hit every contract to the depth in `INTEGRATION_FABRIC.md`'s worked example. These six briefs form a
**single integrated product built one plan at a time**, not six apps.

## 6. Primary-source discipline
Cite each provider's **official API docs + ToS** (this is mandatory here), Unpaywall/OpenAlex/Crossref
docs. Where a source's API is paid/restricted (Reddit, X), say so honestly with the real tiers. No
invented endpoints. Distinguish observed vs inferred.

## 7. Deliverable
1. Executive thesis. 2. **Source matrix + legality verdicts + OA retrieval chain** (D1 — headline).
3. Multi-source ingest/normalization pipeline + item schema (D2). 4. Adaptive-card native timeline UX
(D3). 5. Notes+Agent+Graph integration + agent tool schema (D4). 6. Watch/feed intelligence (D5).
7. **ToS/rate-limit/attribution compliance engine + failure table** (D6). 8. Competitive table +
novel edge (D7). 9. Phased build order (generalize arXiv ingest → source adapters (green ones first)
→ item schema/dedup → native timeline → save-to-vault → graph links → agent capability → BYO-cred
lanes → watch feeds), each with a witnessable proven-done bar; flag Plan 1 agents + Plan 3 PDF→md
dependencies. 10. Open questions.

## 8. Anti-patterns
No Sci-Hub, no ToS-violating scraping, no credential harvesting, no pirated PDFs. No source that
needs a ToS violation to be useful as a default. No web-dump timeline. No tokens in UserDefaults.
Don't demote arXiv/Obscura. Don't let the ResearchHub cache become authoritative over vault files.

─── END RESEARCH BRIEF ───
