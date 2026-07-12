# 07 - Capability Ring: ResearchHub, Capture, Sync, Plan 3

Capability-ring features plug into the MAS fabric after KEELSTONE, MAS June, LUMENLENS, and RECKONER seams are stable enough. They are not independent product lanes.

## ResearchHub / LODESTAR source policy

Retained rule: official APIs, RSS/Atom, legal open-access infrastructure, or user-supplied credentials only.

Forbidden:

- Sci-Hub
- LibGen
- Google Scholar scraping
- forbidden publisher scraping
- unauthorized full-text downloads
- hidden paid-content access
- credential harvesting
- "find any PDF" mode
- ToS-violating scraping

Adapter rule before shipping: every retained provider needs an official source
URL, terms/rate-limit note, attribution rule, cache/purge rule, privacy note,
and local feature flag. If any of those are missing, the adapter remains
`REQUIRES LOCAL VERIFICATION` and cannot be presented as a ready MAS feature.

Provider policy summary:

| Source | Active status | Rule |
|---|---|---|
| arXiv | SAFE WITH CONDITIONS | official API/RSS only; acknowledge arXiv; respect rate limits and e-print copyright/redistribution limits |
| Crossref | SAFE WITH CONDITIONS | metadata/reference lookup; identify the app/contact; cache responsibly and avoid abusive polling |
| OpenAlex | SAFE WITH CONDITIONS | metadata graph use; watch API budget/rate limits and attribution expectations |
| Unpaywall | SAFE WITH CONDITIONS | legal OA resolver only; never treat "PDF found" as permission to download or redistribute |
| NCBI/PubMed/PMC | SAFE WITH CONDITIONS | follow tool/email/rate guidance and PMC/copyright/full-text limits |
| Semantic Scholar | SAFE WITH CONDITIONS | license-aware enrichment; API key and attribution/rate/suspension rules must be recorded |
| CORE/DOAJ/Europe PMC/OSF/bioRxiv | SAFE/RESEARCH NEEDED per current official docs | verify official API terms before each adapter ships |
| GitHub/Zotero/Readwise/Mastodon/Bluesky/X/Reddit | BYO or official API only | user tokens in Keychain; retention, export, deletion, and rate rules recorded per provider |
| Open Library / Internet Archive / Gutendex | SAFE WITH CONDITIONS | public-book metadata/text only under official API limits; no HTML scraping or high-traffic backend misuse |
| Publisher RSS | SAFE WITH CONDITIONS | headlines/links/metadata; no paywall bypass or automated full-text harvesting |
| Elsevier/Scopus/IEEE/Lens commercial APIs | PARK/FORBIDDEN unless licensed | use open metadata substitutes |

## Quick Capture / EMBERCATCH

Quick Capture is zero-loss ingress into the vault.

- Default destination: Quick Capture folder.
- Default model: unstructured first, structured later.
- Voice capture: mic consent and visible recording indication required.
- Text, voice, screenshots/files all write through KEELSTONE.
- Capture must survive app quit/crash.
- Later enrichment can suggest titles/tags/routes, but never blocks the initial durable save.
- Promotion to Epdoc preserves provenance to original capture.

## Sync

Sync is subordinate to KEELSTONE.

- No proprietary sync server.
- No parallel reconciler.
- `.epcache` remains local/derived.
- iCloud/Dropbox/Syncthing edits are external events to reconcile.
- Conflicts are visible; no silent last-writer-wins for dirty user work.

## Plan 3 capabilities

Active MAS-safe capabilities:

- PDF/PDFKit and existing parse paths.
- Vision/OCR if using Apple APIs and consent/privacy disclosure.
- Speech/STT with consent and clear recording state.
- WKWebView browser/lite browser only.
- arXiv/ResearchHub adapters under official source policy.
- vault tools through security-scoped access and approval gates.
- skills as user-approved, sandbox-safe procedural records, not code execution.

Parked/forbidden on MAS:

- browser-use / Chromium automation.
- Python voice/runtime wrappers.
- terminal/code-exec.
- stdio MCP.
- local servers.
- subprocess helper lanes.
- fake provenance or fake capability labels.

## Obscura / browser decision

If old docs say "Obscura" inconsistently, split it:

- **Lightweight native/WKWebView browser surface**: potentially MAS-safe.
- **Automation engine / browser-use / Chromium / CDP lane**: parked for MAS.

Do not delete a useful WebKit browser because a browser-use automation lane is forbidden. Do not revive browser-use because a WebKit browser is allowed.

## F1-F6 integration

| Feature | F1 Vault | F2 Agent tools | F3 Status | F4 Graph | F5 Provenance | F6 Events |
|---|---|---|---|---|---|---|
| ResearchHub | saved notes/media | search/read/save/monitor | reading source | paper/repo/item edges | source/license/retrievedVia | feedUpdated/itemSaved |
| Quick Capture | capture files/notes | capture.route/undo | filed/blocked | capture->note links | route/action trace | captureSaved/routed |
| Sync | vault events | infra | syncing/conflict | mutation updates | conflict witnesses | sync/conflict events |
| PDF/Vision/Speech/Browser | sidecars/notes | capability-specific | active/blocked | source links | citations/claims | capability events |
