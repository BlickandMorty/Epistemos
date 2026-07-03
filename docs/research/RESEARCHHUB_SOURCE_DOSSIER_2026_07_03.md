# Epistemos ResearchHub — Source Integration Dossier (2026-07-03)

**What this is:** the buildable map of research sources Epistemos can ingest the way it
already ingests arXiv — a feed/bookmark hub spanning social, dev, scholarly, and
learning sources. Every source is graded for API reality, auth, cost, MAS-sandbox
viability (Swift/URLSession client-side, keys in Keychain), the **commercial-app
licensing trap**, and effort.

**Provenance + confidence:** synthesized from **two** deep-research workflows (~52
primary sources fetched across both), each of which completed its search+fetch phases
but was **cut off at final synthesis when Fable-5 credits ran out**; the distillation +
corrections below were finished on Opus. Tags: **[V]** = adversarially verified or
confirmed against a primary source this session · **[Q]** = primary-source quote captured
but 3-vote verification incomplete · **[K]** = asserted from model knowledge, re-verify
before shipping that adapter.

**Nothing lost — full raw research preserved** in this folder:
`RESEARCHHUB_WORKFLOW_RAW_{social,academic}_2026_07_03.md` (readable: every confirmed +
quote-backed claim, source URLs, raw agent findings) and the verbatim `.json` copies.
Both workflows are DONE; the social/dev layer is now folded in below (its results
corrected several earlier [K] rows — see §11).

---

## §1 The one architectural insight that unlocks everything

**Epistemos is a paid App Store app = a commercial client.** That single fact decides
most of the licensing questions below, because many "free" research APIs are *free for
non-commercial use only*. There are two clean ways to stay legal, and ResearchHub should
use **both**:

1. **Truly-open sources** (CC0/CC-BY, commercial-use-permitted, no key): OpenAlex,
   Crossref, Unpaywall, Europe PMC, arXiv, DOAJ, OpenLibrary, Wikipedia, HN, Gutendex.
   Epistemos itself is the client. Ship these first — zero friction.
2. **Bring-your-own-credential (BYO) sources:** Reddit, X, GitHub, Zotero, Readwise,
   Semantic Scholar (optional key), OSF. The **user** supplies their own OAuth
   token/API key (stored in Keychain, exactly like the cloud-LLM keys already are). Now
   the *user* is the API client, not Epistemos — which sidesteps the "commercial app"
   disqualification and the per-app rate ceilings, and is the honest model for showing
   someone *their own* bookmarks/stars/library.

**Everything reuses the arXiv adapter shape you already built:** a `ResearchSource`
protocol → per-source adapter (fetch/normalize/paginate) → one unified `ResearchItem`
schema → save-to-vault + optional graph edges. The hub is N adapters behind one feed UI,
not N features.

```
ResearchItem { id, source, kind(paper|post|repo|thread|video|book|bookmark),
  title, authors[], abstract/snippet, url, pdfURL?, doi?, publishedAt,
  savedAt?, tags[], metrics{citations?,stars?,points?}, raw }   // normalized once
```

---

## §2 The legal spine (read before wiring anything)

- **Excluded by design, permanently:** Sci-Hub, LibGen, and any "shadow" full-text
  mirror. They are copyright-infringing; integrating them is an instant App Review
  rejection and a legal liability. ResearchHub resolves paywalled papers ONLY to
  **legal open-access copies** via the OA chain (§3). Do not add a "find any PDF" mode.
- **The OA resolution chain (the core recipe):** `DOI → Unpaywall (/v2/:doi) →
  best_oa_location.url_for_pdf` returns a *legal* green/gold OA PDF in one call, free,
  no key. **[V]** Fallback nodes: OpenAlex `best_oa_location`, Europe PMC full text,
  CORE. This is how you legally show "read the paper" on an otherwise-paywalled result.
- **Publisher metadata is fine; publisher full-text is not (for a paid app):**
  - Elsevier free tier requires the client app be **free + non-commercial + ad-free** —
    a paid MAS app **does not qualify**, and Elsevier **forbids persistently storing**
    API data (only temp cache), and **bars public display of Scopus abstracts**. **[V]**
    → **Do not integrate Elsevier/Scopus.** Get the same metadata from Crossref/OpenAlex.
  - IEEE Xplore API is scoped to **non-commercial use inside the licensee's own
    institution** → **not integrable** in a commercial app without a negotiated license.
    **[V]** → skip; INSPIRE-HEP + arXiv + OpenAlex cover the same papers.
  - Lens.org: **14-day trial only, then paid** — no free ongoing tier. **[Q]** → skip.
  - Springer Nature Meta API exposes **metadata + abstracts** (sanctioned display) and a
    separate OA API returns OA full text; paywalled full text needs a TDM subscription.
    **[Q]** → OPTIONAL, BYO-key, metadata/abstract only.
- **Google Scholar has no API and scraping is now legally radioactive:** Google sued
  **SerpApi (Dec 2025, N.D. Cal.)** over Scholar/Search scraping. **[Q]** → **Never
  scrape Scholar; never ship a SerpApi dependency.** Substitute stack in §5.
- **Store what you're allowed to store:** CC0/CC-BY sources (OpenAlex, Crossref,
  Unpaywall, Europe PMC, OpenAIRE) can be persisted into the vault + graph with
  attribution. Publisher-API data mostly cannot. Prefer the open backbone for anything
  that becomes a durable graph edge.
- **Reddit deletion obligation [V]:** Reddit's Data API ToS requires an app that saves
  Reddit content locally to **purge that content (and author-identifying data) within
  ~48h of it being deleted on Reddit** — even anonymized retention isn't allowed. If
  ResearchHub saves Reddit posts to the vault, it needs a periodic "still exists?" re-check
  + purge job. (Same spirit applies to X content — treat social saves as revocable
  mirrors, not permanent archives.)

---

## §3 Tier-S — build these first (free, open, commercial-OK, MAS-native, no user setup)

| Source | What it gives | Auth | Cost 2026 | MAS | Notes |
|---|---|---|---|---|---|
| **arXiv** (done) | STEM preprints | none | free | ✓ | your existing pattern — the template |
| **OpenAlex** | 250M works/authors/venues + **citation edges** + author-feed alerts | none / free key | **⚠️ now freemium: ~$0.10/day free no-key, $1/day with free key, then paid [Q]** | ✓ | THE graph backbone. Cache hard or hold ONE shared key in the tiny proxy |
| **Crossref** | DOI metadata, references, funders | none (polite: email) | free | ✓ | canonical DOI truth; references feed citation edges |
| **Unpaywall** | DOI → legal OA PDF | email param, no key | free, 100k/day [V] | ✓ | the OA-chain resolver; nothing in Keychain |
| **Europe PMC** | bio/med **free full text** (10M), abstracts, **citation edges** | none | free [Q] | ✓ | best bio/med lane; EMBL-EBI first-party |
| **DOAJ** | open-access journal + article metadata | none | free | ✓ | clean OA journal directory |
| **OpenAIRE Graph** | EU OA works, CC-BY, commercial reuse OK | none/opt key | free (60/hr → 7200/hr keyed) [Q] | ✓ | good EU coverage, store-able |
| **Hacker News** | Firebase API (items/users) + Algolia HN Search | none | free | ✓ [K] | tech pulse; Algolia = full-text search/date filters |
| **Hugging Face** | Hub (models/datasets) + **Daily Papers** | none (opt token) | free | ✓ [K] | Daily Papers = a curated AI-paper feed for free |
| **OpenLibrary / Internet Archive** | books, editions, scans, metadata | none | free | ✓ [K] | book layer; IA Scholar covers some papers too |
| **Gutendex (Project Gutenberg)** | 70k+ public-domain books | none | free | ✓ [Q] | classic-texts lane |
| **Wikipedia / Wikidata REST** | article summaries, entities, structured facts | none | free (rate-limited) | ✓ [Q] | entity enrichment + graph nodes |
| **OSF preprints family** | **PsyArXiv, SocArXiv, EdArXiv, engrXiv, LawArXiv…** all via ONE `/v2/preprints/?filter[provider]=` API | none (100/hr) or PAT (10k/day) | free [Q] | ✓ | one adapter = ~8 discipline servers; date filter = alerts |
| **bioRxiv / medRxiv** | bio/med preprints | none | free [Q] | ✓ | `api.biorxiv.org` details/feeds |
| **DBLP** | CS bibliography, author pubs | none | free [Q] | ✓ | authoritative CS venue/author data |

*The OSF one-API-many-servers finding is a force multiplier: PsyArXiv (psych), SocArXiv
(social), EdArXiv (education), engrXiv, ChemRxiv-adjacent, etc. are one adapter.*

---

## §4 Tier-A — bring-your-own-credential (the "show me MY stuff" layer)

These need the **user's own** OAuth token/API key in Keychain (BYO pattern). That makes
the user the client → legal + higher limits + it's literally their data.

| Source | What it gives | Auth | Cost to the user | MAS | Verdict |
|---|---|---|---|---|---|
| **GitHub** | starred repos, releases, notifications, trending(via search) | PAT or OAuth | free (5000/hr authed) | ✓ [K] | easy, high-value dev feed; Atom feeds also exist keyless |
| **Reddit** | saved posts, subreddit RSS, search | **OAuth MANDATORY — Data API blocks keyless [V]** | free 100 req/min per OAuth client (10-min window bursts); conditional eligibility ("contact us"); commercial needs a contract | ✓ | BYO-OAuth is the path; **`.rss` feeds are the ONLY keyless lane** (the old `.json`-anonymous trick is blocked); 48h-delete ToS (§2); NSFW filter for App Review |
| **Semantic Scholar** | papers, TLDRs, **citation contexts+intent**, **recommendations API** | keyless (⚠️ keys frozen) | free [V] | ✓ | ⚠️ since **Aug 2024 S2 stopped issuing API keys** to third-party apps AND free-email users → **keyless-only in practice**; shared global pool (~1k req/s // 5k per 5min), throughput unpredictable → cache hard. Still the best typed-citation-edge source |
| **Stack Exchange** | MathOverflow, Math.SE, CrossValidated, CS.SE, etc. — one API | none (opt key raises quota) | free | ✓ [K] | Q&A research layer across disciplines, one adapter |
| **Mastodon** | your bookmarks (`GET /api/v1/bookmarks`), home/lists | OAuth (`read:bookmarks`) per instance | free | ✓ [V] | native bookmarks endpoint confirmed; per-instance |
| **Bluesky (AT Proto)** | public feeds, follows; bookmarks | app password / OAuth | free | ✓ [K] | confirm native bookmarks endpoint status before wiring |
| **Zotero** | the user's reference library + collections | API key | free | ✓ [K] | huge for researchers — sync their real library into the vault/graph |
| **Readwise / Reader** | highlights + read-later (Reader API **v3, two-way**) | **static token** (readwise.io/access_token), no OAuth | user's Readwise sub | ✓ [V] | **simplest auth of the whole hub** → straight to Keychain; 50/min create, 20/min list, cursor pagination |
| **Raindrop.io** | bookmarks/collections | OAuth2 code — **token exchange needs client_secret** | free tier exists | ⚠️ [V] | MAS caveat: a client_secret **can't live in the sandboxed client** → route the OAuth token-exchange through the tiny proxy, or use a personal test token |

---

## §5 Google Scholar — the substitute verdict

Scholar has **no official API** and scraping is now litigated (Google v. SerpApi, Dec
2025) **[Q]**. Do not touch it. The honest replacement that reproduces ~90% of what
people want from Scholar, all legal and mostly free:

- **Search + metadata:** OpenAlex + Crossref (+ Semantic Scholar for TLDRs).
- **"Cited by" / citation graph:** OpenAlex `filter=cites:<id>` (live-verified returning
  counts) + Semantic Scholar citations endpoint (with intent/isInfluential). **[Q]**
- **Author profiles + alerts:** OpenAlex author entity + `from_publication_date` polling
  = "new papers by author X" and "new citations of paper Y", client-side. **[Q]**
- **Read the PDF:** Unpaywall OA chain (§2).
- **Import your existing Scholar library:** users can export Scholar → BibTeX and import
  the file; there's no live-sync path, and that's fine.

That stack *is* the ResearchHub scholarly engine. Scholar itself is a non-starter.

---

## §6 The X.com bookmarks decision (the one hard case)

**Verified 2026-07-03 [V]:** X bookmarks ARE reachable via 5 official documented
endpoints — `GET /2/users/:id/bookmarks` **plus bookmark folders**
(`/bookmarks/folders`, `/bookmarks/folders/:id`). Auth = **OAuth 2.0 PKCE user context**
— crucially a **public-client (no client_secret) flow**, which is exactly right for a
sandboxed no-server Mac app (unlike Raindrop's secret-requiring flow). Pricing: the X API
**dropped subscription tiers entirely** — it's now **pay-per-usage credits**, and as of
**April 20 2026** bookmarks fall under **"Owned Reads" at $0.001/resource** ($1 per 1,000
bookmarks). Caveat the docs leave open: X hasn't explicitly confirmed whether *end-users
of a third-party client* get the Owned-Reads rate, so a BYO-credential flow (user's own
app + billing) is the safe assumption.

**Recommendation — do BOTH, in order:**
1. **v1 (ship first): import path.** X's **official archive export does NOT include
   bookmarks** [V], so the import source is a browser export tool — e.g. the open-source
   **`twitter-web-exporter`** userscript (`github.com/prinsss/twitter-web-exporter`),
   which passively captures the web app's own GraphQL responses (no dev account, no API,
   bypasses the 800-item cap) and emits JSON/CSV Epistemos can import. 90% of the value,
   zero X-API entanglement.
2. **v2 (power users, BYO): live OAuth 2.0 PKCE.** For users with an X developer account,
   wire the real bookmarks + folders endpoints (their credentials, their pay-per-use, the
   PKCE public-client flow needs no server). Gate behind clear "advanced" setup.

Never ship an app-level X key (you'd eat everyone's per-read cost + own the liability).
BYO or import — never Epistemos-as-the-billed-client.

---

## §7 Discipline coverage map (best 2–3 sources each)

| Field | Primary | Secondary | Full-text/OA |
|---|---|---|---|
| Math | arXiv (math.*), **zbMATH Open** [Q], MathOverflow (Stack Exchange) | OpenAlex, DBLP | Unpaywall |
| CS / AI | arXiv (cs.*), **DBLP**, Semantic Scholar | HF Daily Papers, HN, Papers-with-Code(post-HF) | Europe PMC/OA |
| Physics | arXiv, **INSPIRE-HEP** [K] | OpenAlex | arXiv full text |
| Biology / Med | **Europe PMC** (free full text), PubMed (E-utilities) | bioRxiv/medRxiv, OpenAlex | Europe PMC / PMC OA |
| Neuroscience | Europe PMC, bioRxiv, **OpenNeuro** [K] (datasets) | OpenAlex, PsyArXiv | Europe PMC |
| Psychology | **PsyArXiv** (OSF API), Europe PMC | OpenAlex, Crossref | Unpaywall (APA is paywalled) |
| Economics / Social | **SocArXiv** (OSF), **RePEc** [K], SSRN(Elsevier—metadata only) | OpenAlex | Unpaywall |
| Chemistry | **ChemRxiv** [K], OpenAlex | Crossref | Unpaywall |
| Philosophy | **PhilPapers** [K], OpenAlex | Crossref | DOAJ/Unpaywall |
| Cross-cutting | **OpenAlex + Crossref + Semantic Scholar** (the universal spine) | Wikipedia/Wikidata | Unpaywall |

---

## §8 College / learning-resources shortlist

- **MIT OpenCourseWare** — course materials (bulk/feeds) **[K]**; **OpenStax** +
  **LibreTexts** + **Open Textbook Library** — open textbooks **[K]**; **Internet
  Archive / OpenLibrary** — scans + books **[V-adjacent]**; **Gutendex** — public-domain
  classics **[Q]**; **Wikipedia/Wikidata** — reference **[Q]**; **Stack Exchange** —
  learning Q&A **[K]**; edu **YouTube via RSS** (channel feeds, no quota) for lectures
  (Stanford/Yale OYC/MIT) **[K]**.
- **Dead / avoid:** **Khan Academy API was retired in 2020, no replacement** **[Q]** —
  no integration. Coursera/edX have only limited public catalogs, not personal-progress
  APIs — skip for v1.

---

## §9 Citation edges for the graph (which sources can feed your graph view)

Store-able (CC0/CC-BY) and edge-rich, in priority order:
1. **OpenAlex** — `referenced_works` (outbound) + `cites:` filter (inbound), plus
   author/venue/concept edges. The backbone. **[Q]**
2. **Semantic Scholar** — typed edges: citation **intent** + `isInfluential` +
   contexts. Adds semantic weight OpenAlex lacks. **[V]** ⚠️ keyless-only since the
   Aug-2024 key freeze → shared global pool, so batch/cache edge pulls; don't hammer it
   live per-scroll.
3. **Crossref** — reference lists from DOIs. **[V-adjacent]**
4. **Europe PMC** — reference lists + citation counts for 19M+ bio/med works. **[Q]**
- **Cannot store as durable edges:** Elsevier/Scopus (no-persist), IEEE (institutional).
  Get the same papers' edges from OpenAlex instead.
- **Alerts, client-side, no server:** poll OpenAlex `authorships.author.id +
  from_publication_date` (new-by-author) and `cites:<id> + from_publication_date`
  (new-citations-of-your-saved-paper). This is a real "research radar" for free.

---

## §10 Recommended build order

- **Phase 1 — Open scholarly spine (highest value, zero user setup):** OpenAlex +
  Crossref + Unpaywall + Europe PMC + the OSF-preprints one-adapter (PsyArXiv/SocArXiv/…)
  + bioRxiv. This alone makes Epistemos a serious cross-discipline research reader with
  legal PDF resolution and a citation graph. Reuses the arXiv adapter directly.
- **Phase 2 — Open feeds (dev + culture):** Hacker News, HF Daily Papers, Wikipedia,
  OpenLibrary/Internet Archive, Gutendex, generic RSS/Atom (blogs/Substack/YouTube
  channels). Still no user auth.
- **Phase 3 — BYO personal layer:** GitHub stars, Reddit saved (BYO-OAuth), Zotero
  library, Readwise/Raindrop, Stack Exchange, Mastodon/Bluesky bookmarks. Keychain keys,
  same UX as the LLM keys.
- **Phase 4 — Hard/optional:** X bookmarks (import first, BYO-OAuth second); Springer
  Meta API (BYO, metadata only).
- **Never:** Sci-Hub/LibGen, Elsevier/Scopus, IEEE, Lens, Google Scholar/SerpApi, Khan
  Academy.

---

## §11 What changed 2024–2026 (don't trust stale guides)

- **OpenAlex went freemium** (~$0.10/day free no-key, $1/day free-key, then paid) — the
  old "free polite pool forever" is gone. Architecture must cache + consider one shared
  proxy key. **[Q]**
- **X API**: pay-per-use is now the only new-signup path; "Owned Reads" made *your own*
  bookmarks cheap ($0.001/read) as of Apr 2026. **[V]**
- **Reddit**: OAuth is now **mandatory** — keyless `.json` is blocked (only `.rss` feeds
  survive keyless); free tier 100 req/min per OAuth client, "contact us" eligibility,
  commercial needs a contract; **48h-delete obligation** on saved content. **[V]**
- **Semantic Scholar froze API keys (Aug 2024)** — third-party apps + free-email users
  can no longer get keys; the public API is keyless-only on a shared global pool. Plan
  around throttling; cache aggressively. **[V]**
- **Pocket shut down (2025)** — Readwise Reader / Raindrop are the replacements. **[K,
  verify]**
- **Google↔SerpApi lawsuit (Dec 2025)** — Scholar scraping is legally hot. **[Q]**
- **Khan Academy API retired (2020)** — confirmed dead. **[Q]**

---

## §12 Open items

Both deep-research workflows are **complete and fully preserved** (see the four
`RESEARCHHUB_WORKFLOW_RAW_*` files in this folder). Remaining follow-ups:

1. Re-verify the still-**[K]** rows against primary docs before wiring each adapter:
   GitHub (limits/Atom), HN (Firebase+Algolia), HF (Daily Papers auth), Bluesky native
   bookmarks, Zotero + Stack Exchange exact quotas, and the discipline servers
   (INSPIRE-HEP / PhilPapers / RePEc / ChemRxiv / zbMATH API shapes). A short targeted
   pass (not another 100-agent fan-out) closes these — do it when credits are back, or
   fold in per-adapter at build time.
2. Pin exact numbers for the freemium/volatile ones: **OpenAlex** pricing, Springer Meta
   terms, Readwise limits — these move; check the pricing page the week you build.
3. Owner calls: (a) ResearchHub as a **dedicated room** (like arXiv/Obscura, per the
   product-shape canon) — recommended yes; (b) which Phase-1 sources ship in v1;
   (c) NSFW-filter policy for Reddit (App Review requires it); (d) the tiny proxy's
   scope — it's needed for Raindrop's OAuth secret and optionally a shared OpenAlex key.

*Full raw provenance (DO-NOT-BUILD): `RESEARCHHUB_WORKFLOW_RAW_academic_2026_07_03.md`
(7 confirmed + 18 quote-backed, 26 sources) and `RESEARCHHUB_WORKFLOW_RAW_social_2026_07_03.md`
(8 confirmed + ~20 quote-backed, 26 sources), plus verbatim `.json` copies of both.*
