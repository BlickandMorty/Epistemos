# PLAN 8 — ResearchHub: a multi-source research feed, deeply wired to Notes + Agents

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: read
> `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md` first. ResearchHub now
> targets MAS only. The dedicated native room, vault store, source adapters,
> citations, monitoring, and agent tools must be driven by MAS/June +
> in-process `agent_core`. Experimental/1Code/KINDRED readiness is no longer a
> prerequisite. Mascot/status ideas may be salvaged only as MAS-June state.

**Date:** 2026-07-03 · **Status: CANONICAL for MAS after 2026-07-07 pivot** ·
**Sequence: build agent-facing phases after MAS/June is ready enough to consume tools.**
OpenChamber/ProAgent/Experimental/KINDRED are not prerequisites. The payoff (June reads the
hub + MAS-safe status/provenance + note round-trips) depends on the MAS agent seam. The
open-source foundation (§Phase A) is safe to start independently whenever.

**What this is, in one line:** generalize Plan 3's arXiv capability into a **dedicated
"ResearchHub" room** that ingests many research sources (papers, X/Reddit/HN posts,
GitHub, Hugging Face, journals, preprints, books, courseware) into ONE beautiful native
feed the **user browses and engages directly**, and the **agents can read, search, cite,
and monitor** as a first-class capability — all backed by one vault store so notes,
graph, and agents share it.

**Read-first references (do not re-derive these):**
- Source dossier (every API's 2026 reality, auth, cost, MAS-viability, legality):
  `docs/research/RESEARCHHUB_SOURCE_DOSSIER_2026_07_03.md` (+ its raw archives
  `RESEARCHHUB_WORKFLOW_RAW_*`). **This is the source-of-truth for WHICH sources and HOW.**
- The ingest template to reuse: `Epistemos/Arxiv/ArxivIngestService.swift`
  (`ingest(...)` → LiteParse PDF→md → `ArxivNoteDraft` → materialize into vault). Every
  adapter follows this shape.
- Plan 3 (`PROMPT_PLAN_3_CAPABILITIES.md`) — arXiv is already a dedicated room + agent
  capability with **mascot presence** ("agent reads arXiv → mascot on the arXiv button →
  landing shows 'currently reading arXiv'"). **ResearchHub generalizes that exact pattern
  to all sources.** Do not duplicate or fight Plan 3's arXiv; extend it.
- Plan 5 (`PROMPT_PLAN_5_COMPANION.md`) — the static+emotive mascot + identity/obligation
  profile; ResearchHub is a place the mascot appears when an agent is working a source.
- Product-shape canon (memory `project_product_shape_agent_center_2026_07_02`): rooms
  KEPT dedicated + those same powers as agent capabilities + integration via shared vault
  files (not agent-UI-everywhere).

---

## §0 LOCKED DECISIONS (owner intent + the design calls the owner delegated)

1. **Deep Notes + Agents integration is the whole point.** After the agents are built,
   they must be able to **read/search/research all of ResearchHub**; the **user engages
   directly** (browse, save, annotate, open-in-notes, ask-agent-about-this). One store,
   two engagement planes (§3–§5).
2. **DISPLAY DECISION (owner delegated "what makes most sense"): an adaptive-card
   "research timeline," rendered NATIVELY — not web/tweet embeds.** See §2. Short version:
   yes to the whole post (text + images + video + links), but rendered as a native card
   from a normalized item, so heterogeneous sources (a paper, a tweet, a repo, a thread)
   all sit in ONE gorgeous consistent feed that is also clean for the agent to read.
3. **Dedicated room, not a demotion.** ResearchHub is its own room (like arXiv/Obscura),
   AND its powers are agent capabilities. Existing dedicated features (arXiv, Browser)
   are absorbed as *sources within* the hub while staying reachable as themselves.
4. **Build once for MAS.** The adapters + feed + agent tool are App Store-safe
   (URLSession + vault + agent_core). Park Pro/Experimental variations unless a
   later owner directive reopens them.
5. **Legality is inherited from the dossier §2, non-negotiable:** never Sci-Hub/LibGen,
   never Google Scholar scraping/SerpApi, never Elsevier/Scopus/IEEE/Lens; OA papers
   resolve via the DOI→Unpaywall→PDF chain only; Reddit saves obey the 48h-delete rule;
   Reddit needs an NSFW filter for App Review.

---

## §2 THE DISPLAY — adaptive-card research timeline (native)

**One feed. Cards adapt to the item's `kind`. Rendered natively, never as web embeds.**

Why native cards, not full tweet/oEmbed widgets: web embeds pull third-party JS
(sandbox-hostile, ToS-fraught, breaks the theme, and each source would look different).
Normalizing to a `ResearchItem` and rendering a native card per kind gives (a) a
consistent, theme-aware, beautiful timeline across wildly different sources, (b) a clean
object the agent reads (normalized JSON, not scraped HTML), and (c) full media fidelity
without an iframe.

| item.kind | Card shows | Media handling |
|---|---|---|
| `post` (X/Reddit/Mastodon/Bluesky) | avatar · author · full text · engagement · source badge | **images inline** (vault-cached), **video tap-to-play** (native AVPlayer), **links → native preview card** (title/image/domain), quoted/nested posts, threads expandable |
| `paper` (arXiv/OpenAlex/preprints/journals) | title · authors · venue · date · abstract · citation count | one-tap **OA PDF** (DOI→Unpaywall chain) → hands off to Plan 2's PDFKit viewer |
| `repo` (GitHub) | name · owner · description · stars · language · README snippet | release notes inline |
| `thread` (HN/Lobsters/Stack Exchange) | title · points · comment count · top snippet | link preview + threaded comments on open |
| `video` (YouTube/lecture RSS) | thumbnail · title · channel · duration | tap-to-play (native) |
| `book` (OpenLibrary/Gutendex/IA) | cover · title · author · subjects | reader/handoff |

- **Density toggle:** rich cards ↔ compact list (power-reading mode).
- **Filters:** per-source, per-topic/tag, saved-only, unread, date. A "For You / Following
  / Saved / All" style top switcher.
- **Feed = a normal SwiftUI list of cards.** Theme-aware (reads Epistemos tokens like
  every surface). No WKWebView required for the feed itself (the lite Browser tab from
  Plan 3 remains separate, for opening a source in-app).

So the owner's instinct ("looks good like X posts") is honored — full text/images/
video/links — but unified and native, which serves the user *and* the agent.

---

## §3 DATA MODEL — one `ResearchItem`, a first-class vault object

Generalize `ArxivNoteDraft`/`ArxivIngestService.ingest` into a source-agnostic pipeline:

```
protocol ResearchSource {            // one per source; the arXiv service is the template
  var id: SourceID { get }           // openalex, github, xbookmarks, hn, reddit, …
  func fetch(_ query: FeedQuery) async throws -> [ResearchItem]   // feed/search/bookmarks
  func hydrate(_ id: ItemID) async throws -> ResearchItem          // full content on open
}
struct ResearchItem: Sendable, Codable {   // the unified schema (dossier §1)
  id, source, kind(post|paper|repo|thread|video|book|bookmark)
  title, authors[], body/abstract, url, pdfURL?, doi?, media[], links[],
  publishedAt, fetchedAt, savedAt?, tags[], metrics{citations?,stars?,points?},
  provenance{sourceURL, license, retrievedVia}, raw
}
```

- **Save-to-vault = same materialize path as arXiv** (write a note-adjacent object with
  provenance frontmatter; cache legal media into the vault). A saved item shares the
  vault ID space with notes → it is `[[linkable]]`, taggable, graph-node-able.
- **Provenance is mandatory** (ties into Plan 3's provenance moat): every item carries
  where it came from, when, and under what license, so the agent never cites a ghost.
- **Retention rules from the dossier:** CC0/CC-BY sources persist freely; Reddit/X
  obey delete-within-48h (a periodic "still exists?" purge job); publisher metadata is
  display-only, not stored as durable edges.

---

## §4 AGENT INTEGRATION — ResearchHub as a capability both agent builds consume

**One implementation, MAS surface:** expose ResearchHub to agents through the shared app tool
surface. MAS/June consumes it through `agent_core`. No per-engine reimplementation and no
OpenChamber, Experimental, or Kindred dependency.

**Tool verbs (the agent plane):**
- `search(query, sources?, since?)` — across the hub, returns normalized items.
- `read(itemId)` — full normalized content (the agent reads JSON, not a rendered card).
- `feed(source?, since?)` — recent items (e.g. "what's new in my arXiv follows").
- `related(itemId)` — citation graph / recommendations (OpenAlex `cites:` + Semantic
  Scholar recs, dossier §9).
- `monitor(kind, target)` — arm a client-side alert (new-by-author, new-citations-of-a-
  saved-paper, new-in-topic, new-release-of-a-repo) → the "research radar."
- `save(itemId, tags?)`, `annotate(itemId, text)` — the agent can curate too.

**Two planes over ONE store:**
- **User plane:** browse the feed, save, filter, annotate, "open in Notes", "ask the
  agent about this item" (drops the item into a chat with the agent).
- **Agent plane:** the tool verbs above. The agent can *research the whole hub* and
  write findings back into a note with real citations (§5) — closing the loop.

**Mascot presence (Plan 5 + the Plan 3 arXiv pattern, generalized):** when an agent runs
a researchhub verb against a source, that source's button shows the agent's mascot, and
the landing shows "currently reading &lt;source&gt;" (e.g. "reading X bookmarks",
"scanning new citations"). This is the SAME mechanism Plan 3 already built for arXiv —
generalize it to every source. Pressing the mascot → the agent's identity/obligation
profile + what it's currently doing in the hub.

---

## §5 NOTES INTEGRATION — the round-trip

- **Item → Note:** "Create note from this" seeds an Epdoc/note with the item embedded +
  provenance frontmatter (reuse the arXiv note-draft materialize path).
- **Highlight → block:** selecting text on a card creates a note block (Readwise-style
  highlights → notes), carrying the citation back to the item.
- **`[[wikilink]]` any item** from any note (shared vault ID space); backlinks show which
  notes cite an item.
- **Graph edges:** saved items become graph nodes; citation edges (OpenAlex/Semantic
  Scholar/Crossref/Europe PMC, dossier §9) become graph edges; a note that cites items
  gains edges to them. The agent's research findings land as a note whose citations are
  live graph edges to the source items — the user sees exactly what the agent read.

---

## §6 SOURCES + PHASING (which, in what order — all specifics in the dossier)

- **Phase A — Foundation (independent; can precede agent integration):** the unified
  `ResearchItem` + `ResearchSource` refactor (generalize the arXiv service) + the **open
  scholarly spine** adapters — OpenAlex, Crossref, Unpaywall (OA chain), Europe PMC, the
  **OSF one-adapter** (PsyArXiv/SocArXiv/EdArXiv/…), bioRxiv — + the adaptive-card feed
  room + save-to-vault. A useful dedicated research room on its own.
- **Phase B — Agent capability (needs MAS/June):** the `researchhub` app-hosted tool surface wired
  into June/agent_core + MAS-safe status/provenance + "ask agent about this item."
- **Phase C — Personal + open feeds + notes-deep:** Hacker News, HF Daily Papers,
  Wikipedia, OpenLibrary/Internet Archive, Gutendex, generic RSS/Atom; then BYO-credential
  GitHub / Reddit(OAuth) / Zotero / Readwise / Stack Exchange / Mastodon; X bookmarks
  (import-first via `twitter-web-exporter`, then BYO OAuth PKCE); + notes round-trip
  (create-note, highlights→blocks, `[[links]]`) + graph citation edges.
- **Phase D — Research radar + polish:** client-side monitors/alerts (new-by-author,
  new-citations, new-in-topic, new-repo-release), density/filter polish, per-source theming.

Discipline coverage (math/AI/bio/neuro/psych/econ/phil/chem/physics → best sources each)
and the Google-Scholar substitute stack (OpenAlex + Semantic Scholar + Crossref) are in
the dossier §5–§8; wire them as the search backend.

---

## §7 MAS CONSIDERATIONS

- **Shared, sandbox-legal:** all adapters are URLSession + vault + agent_core tools — no
  subprocess, no local server → clean on MAS. The feed is native SwiftUI.
- **BYO-credential secrets:** X/Reddit/Mastodon use OAuth **PKCE public-client** flows
  (no server secret — MAS-clean). **Raindrop's OAuth needs a `client_secret`** → route
  that token-exchange through the tiny proxy (the same proxy the MAS plan already stands
  up for cloud LLM). Readwise = a static per-user token (simplest → Keychain).
- **App Review:** Reddit NSFW filter required; Reddit/X saves obey 48h-delete; state in
  review notes that ResearchHub shows third-party content the user connects, attributed,
  no scraping.
- Keys/tokens in Keychain, never UserDefaults (same as the LLM keys).

## §8 BUILD ORDER + ACCEPTANCE

Per phase, each ends in a commit + owner-visual checkpoint:
- **A done:** the open scholarly spine ingests into the vault; the adaptive-card feed
  renders papers + at least one social source beautifully, theme-aware, with save-to-vault
  and the DOI→OA-PDF one-tap working.
- **B done:** MAS/June can `search`/`read`/`related` the hub via the app-hosted tool surface,
  MAS-safe status appears on a source while the agent reads it, and "ask agent about this item"
  works end-to-end.
- **C done:** ≥3 personal BYO sources connect (Keychain), X bookmarks import works,
  create-note-from-item + highlight→block + `[[link]]` + graph edges all land.
- **D done:** at least one live monitor fires a real alert (e.g. new citation of a saved
  paper) client-side.

## §9 GUARDRAILS

- Legality per dossier §2 (hard). Never scrape Scholar; never Sci-Hub/LibGen; never
  Elsevier/Scopus/IEEE/Lens.
- Reuse the arXiv ingest pipeline — do NOT invent a parallel one; do NOT touch Plan 2's
  PDFKit viewer (hand off to it). Absorb arXiv/Browser as sources without breaking their
  dedicated rooms.
- Never `git add -A`; keys in Keychain; Swift builds on isolated DerivedData
  (both schemes), BUILD SUCCEEDED before commit; no worktrees; commit per phase.
- Don't start the agent-facing phases (B+) until MAS/June + in-process
  `agent_core` are real enough to consume tools. Do not wait for or depend on
  Experimental/1Code/KINDRED; those lanes are parked.

---

## §12 HARDENING (baked in, per-phase gate — READ-FIRST `docs/research/AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`)

ResearchHub ingests the open internet, so **untrusted-content + prompt-injection hardening is
this plan's defining risk** — run the four lenses (security · memory-leak · data-leak ·
robustness/fluidity) per phase, thermonuclear-shape; a HIGH blocks the phase commit. Top risks:
1. **The instruction-source boundary is load-bearing here** (doctrine §1/§3B): every fetched
   post/paper/thread/README is DATA, never commands. An agent that "reads my ResearchHub" must
   NEVER act on instructions embedded in the content it read (forward emails, change settings,
   exfiltrate the vault). Quote-and-confirm, never auto-execute content-borne instructions.
2. **Untrusted rendering** (doctrine §3C): native adaptive cards render third-party text/media —
   sanitize, no script execution, no injection through a card; link previews/quoted posts are
   inert; media is tap-to-play, not auto-fetching trackers.
3. **Data-leak:** never send vault/personal data to a source, URL, or endpoint suggested by
   fetched content; no PII in query params; honor the **Reddit/X 48h-delete** retention rule
   (a periodic purge job); NSFW filter for Reddit (App Review). Saved third-party content is
   quarantined with provenance until the user saves it.
4. **Per-source resilience:** each adapter gets rate-limit + backoff + a **circuit breaker**
   (ring buffer; a source being down or throttling never breaks the feed — degrade that lane,
   keep the rest). BYO-credential keys in Keychain only; the Raindrop `client_secret` stays in
   the proxy, never the client.
5. Feed memory: virtualized lists + bounded caches (N items OR M bytes); teardown paths for any
   WebView the tab opens; the agent tool surface shares Plan 9's dry-run/confirm discipline for
   any write. Hardening HIGHs block the commit like a broken build.
