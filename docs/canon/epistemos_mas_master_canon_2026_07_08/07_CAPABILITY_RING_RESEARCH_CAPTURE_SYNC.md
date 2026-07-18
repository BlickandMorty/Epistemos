# 07 - Capability Ring: Free Workspace + Future Paid Research/Browser

Capability-ring features plug into the MAS fabric after the relevant KEELSTONE,
LUMENLENS/Epdoc, and RECKONER seams are stable enough. They are not independent
product lanes and free-V1 features do not wait for June.

July 15 override: remove the LumenLens/Reckoner dependency from this statement.
Retained non-AI capability work depends on KEELSTONE and the Epistemos Editor
Core only. Reckoner is parked. All AI/agent/model/provider/generative work is
canceled. Browser and ResearchHub remain deterministic future paid
possibilities because the latest steer keeps non-AI work, but they remain absent
from Free V1 and may contain no autonomous research, AI assistant, model,
provider, scraping, Chromium, browser-use, server, or sidecar lane. Read
`14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md` first.

July 13 owner split:

- Free V1: Meeting, Sync, Quick Capture, calendar/tasks, PDF/import,
  Kokoro/local speech, graph/search, workspace, and export.
- Future paid and hidden/inert in free V1: ResearchHub and Browser, alongside
  June/agentic/generative features.
- Paid status does not weaken the MAS-safe source, WebKit, privacy, legality,
  provenance, or no-sidecar rules below.

Read `11_FREE_V1_EPDOC_PLANNER_AND_CAPABILITY_RING_2026_07_13.md` first.

## Free-V1 graph and state projection

Graph/search remain free capabilities only for free workspace records. The
free projection excludes chat sessions, agent runs, raw thought, tool traces,
model/provider records, June state, Browser state, ResearchHub state, and
other paid-only artifacts at every boundary: graph rebuild, stored-index query,
default active types, filter/color controls, deep links, and state restoration.
This is a visibility/projection rule, not a deletion rule: durable records stay
available for a later paid edition, but cannot leak into free-V1 UI or search.

## Future paid ResearchHub / LODESTAR source policy

ResearchHub is preserved for the future paid MAS product but must be hidden and
inert in free V1. Its retained rule remains: official APIs, RSS/Atom, legal
open-access infrastructure, or user-supplied credentials only.

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

## Epdoc planner, Meeting, and calendar

- Human-readable vault Markdown remains task, project, periodic-plan, goal, and
  Meeting-note truth.
- Inbox, Today, This Evening, Upcoming, Anytime, Someday, Logbook, calendar
  agenda, and task counts are rebuildable projections.
- Meeting links calendar context, agenda, decisions, sources, follow-up tasks,
  and referenced recording/transcript artifacts through the shared vault,
  provenance, graph, and event bus.
- Calendar/reminder access is optional, user-initiated, least-privilege,
  sandbox-entitled, and denial-safe. EventKit remains external calendar truth.
- Recording has explicit consent and persistent visible state. Kokoro read-
  aloud is local and does not require microphone access or activate June.
- No task/planner, Meeting, transcript, calendar, reminder, or sync database may
  become a second authority.

## Free-V1 MAS-safe capabilities

Active free MAS-safe capabilities:

- PDF/PDFKit and existing parse paths.
- Vision/OCR if using Apple APIs and consent/privacy disclosure.
- Speech/STT with consent and clear recording state.
- Kokoro local read-aloud without a general model/agent surface.
- Epdoc task/planner/Meeting/calendar integrations defined in the dated
  addendum.
- vault tools through security-scoped access and approval gates.

Future paid MAS-safe capabilities, hidden and inert in free V1:

- bundled WKWebView browser/lite browser only;
- ResearchHub/arXiv adapters under the official source policy above; and
- June-owned skills as user-approved, sandbox-safe procedural records, never
  code execution.

The central product-capability policy must block their routes, shortcuts, deep
links, restoration, provider/network startup, automatic jobs, and background
work in free V1. Do not add StoreKit/payment in this implementation slice.

Parked/forbidden on MAS:

- browser-use / Chromium automation.
- Python voice/runtime wrappers.
- terminal/code-exec.
- stdio MCP.
- local servers.
- subprocess helper lanes.
- fake provenance or fake capability labels.

## Future paid Obscura / browser decision

If old docs say "Obscura" inconsistently, split it:

- **Lightweight native/WKWebView browser surface**: potentially MAS-safe for
  the future paid edition, hidden/inert in free V1.
- **Automation engine / browser-use / Chromium / CDP lane**: parked for MAS.

Do not delete a useful WebKit browser because a browser-use automation lane is forbidden. Do not revive browser-use because a WebKit browser is allowed.

## F1-F6 integration

| Feature | F1 Vault | F2 Agent tools | F3 Status | F4 Graph | F5 Provenance | F6 Events |
|---|---|---|---|---|---|---|
| ResearchHub (future paid) | saved notes/media | search/read/save/monitor | reading source | paper/repo/item edges | source/license/retrievedVia | feedUpdated/itemSaved |
| Quick Capture | capture files/notes | capture.route/undo | filed/blocked | capture->note links | route/action trace | captureSaved/routed |
| Sync | vault events | infra | syncing/conflict | mutation updates | conflict witnesses | sync/conflict events |
| Epdoc tasks/calendar | markdown truth | future paid tools only | focused/blocked | task/project/event-reference edges | completion/reschedule/time-block | task/calendar events |
| Meeting | note + referenced artifacts | future paid tools only | recording/ready/blocked | meeting/source/follow-up edges | consent/recording/link/export | meeting events |
| PDF/Vision/Speech/Kokoro | sidecars/notes | future paid tools only | active/blocked | source links | citations/consent/claims | capability events |
| Browser (future paid) | saved links/notes | browse/read/save | reading/blocked | source links | URL/retrieval/citation | navigation/save events |
