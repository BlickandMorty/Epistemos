# MAS C Feature Plan - Lodestar

ID: `MAS-C-F07-LODESTAR-2026-07-08`
Codename: `LODESTAR`
Status: active after storage, June, and legality matrix

## Intent

Make ResearchHub a MAS-safe research capability: official sources, citations,
saved vault notes, graph links, and June-driven workflows. Do not ship risky
scraping or unlicensed commercial data.

## Scope

- Source search and ingest through official or permitted APIs.
- arXiv, Crossref, OpenAlex, Unpaywall, PubMed/NCBI, Semantic Scholar, and
  similar sources when terms allow.
- Source cards, citation records, and vault notes.
- Research workflows driven by MAS June.
- Source legality matrix before implementation.

## Fabric Mapping

- F1 vault bus: saved papers/items become vault notes/artifacts.
- F2 agent capability registry: June can search, save, summarize, cite, and
  compare sources.
- F3 MAS status/provenance: shows searching, reading, saving, blocked-by-terms.
- F4 graph: links sources, notes, authors, entities, claims.
- F5 provenance: records source URL/API, license, citation, and summary basis.
- F6 event bus: streams research operation state.

## Phases

1. Build source legality matrix.
2. Implement one low-risk source end to end.
3. Save source card and note into vault.
4. Add citation/provenance and graph links.
5. Wire MAS June research capability with approval and rate limits.

## Parked Or Forbidden

- Reddit API is parked until commercial terms/review are explicit.
- Google Scholar scraping is forbidden.
- Sci-Hub, LibGen, paywall bypass, and credential misuse are forbidden.
- Browser-use Chromium and Python automation are forbidden in MAS.

## Acceptance Evidence

- Source legality table.
- One saved source fixture.
- Citation/provenance record.
- MAS June workflow proof.
- Source failure/blocked behavior.
- App Review/privacy notes for network use.

