# 06 - LUMENLENS + RECKONER Workspace Plan

## Product thesis

LUMENLENS and RECKONER are one workspace fabric. LUMENLENS owns note/editor truth, suggestions, provenance, notebooks, and lens-fidelity disclosure. RECKONER owns dataset artifacts, grid/calc behavior, data tools, charts, and dataset embeds/tabs. Neither creates a second room or second chat.

The July 13 free-V1 addendum expands this fabric: Epdoc also owns the visible
Markdown task/planner/Meeting editing experience and derived planning views.
RECKONER remains a major workspace organ but is not the last feature set; the
free capability ring continues afterward. Read
`11_FREE_V1_EPDOC_PLANNER_AND_CAPABILITY_RING_2026_07_13.md`.

## LUMENLENS editor truth

LUMENLENS active obligations:

- Epdoc/Tiptap in bundled WKWebView is the richest/default lens.
- Native editor chrome remains native.
- Load-vs-edit guard uses loadEpoch + suppression window + transaction filtering; never trust `emitUpdate:false` alone.
- Serializer tiers:
  - Tier A canonical-lossless.
  - Tier B custom extensions with explicit serializers/previews.
  - Tier C byte-preserving quarantine.
- Minimal-diff writeback splices in memory and writes full buffer through KEELSTONE `AtomicVaultWriter`.
- Lens-fidelity disclosure ensures complex content is not silently invisible in Source/Prose.
- Epdoc Notebook stores tab/reference manifests in markdown; content remains referenced artifacts, not embedded blobs.
- Human-readable task, project, goal, periodic-plan, and Meeting blocks remain
  vault truth; planner indexes and focus views are rebuildable projections.
- Epdoc exposes Inbox, Today, This Evening, Upcoming, Anytime, Someday, and
  Logbook as source-reachable views, not as a private task database.
- Task dates, deadlines, recurrence, time blocks, reminders, EventKit links,
  Meeting follow-ups, and Quick Entry must round-trip without activating June.
- Free V1 mounts no Epdoc Assist/MiniChat. Kokoro read-aloud remains available
  through a local voice seam that does not expose a general model surface.

## RECKONER dataset truth

RECKONER active obligations:

- Dataset truth is vault artifact: CSV for flat datasets; XLSX/`.icalc` for workbooks; `.dataset.md` for metadata.
- GRDB is derived working cache.
- IronCalc is sole calc authority.
- Univer is renderer only; formula engine silenced.
- Swift Charts is primary charting path.
- Dataset tabs open inside the existing note/workspace tab system.
- Dataset embeds carry references only, never row blobs.
- Agent data changes stage as TabularSuggestions and require approval.
- No Data room and no data chat.

## Shared suggestion/provenance shape

One schema must support both prose spans and tabular ranges:

- author / run / turn
- object ID and object type
- abstract range payload (markdown offsets, ProseMirror spans, A1 ranges, dataset IDs)
- before / after summary
- rationale
- source/citation pointer
- accept state: pending / accepted / rejected
- append-only staged/resolved events
- updated timestamp

## F1-F6 seam map

| Fabric | LUMENLENS role | RECKONER role | Forbidden duplication |
|---|---|---|---|
| F1 Vault bus | Note markdown read/write via KEELSTONE | Dataset artifacts via KEELSTONE | private authoritative stores |
| F2 Agent registry | note edit/suggest/apply tools | dataset query/clean/chart/transform tools | second tool registry |
| F3 MAS status | editing/suggesting/conflict status | cleaning/charting/recalc status | fake Kindred presence |
| F4 Graph | wikilinks/backlinks client | dataset/note/entity edges | touching graph internals |
| F5 Provenance | editor suggestion ledger | tabular suggestion ledger | parallel schemas |
| F6 Event bus | dirty/clean/load/conflict events | datasetChanged/calcCompleted/embedInvalidated | polling-only UI state |

Epdoc planner and Meeting reuse the same table: task/meeting Markdown and
referenced artifacts use F1; future paid June tools may use F2 only when
reactivated; focus/recording/conflict state uses F3; task/project/meeting edges
use F4; completion/reschedule/link/export events use F5; task/calendar/meeting
changes use F6.

## Build phases

### LUMENLENS

1. Bridge/load-state epoch.
2. Suggestion seam.
3. Serializer tiers.
4. Minimal-diff writeback.
5. Session state/conflict handoff.
6. Provenance ledger.
7. Epdoc Notebook + lens-fidelity disclosure.
8. Task/planner Markdown contract + deterministic parser fixtures.
9. Derived focus views + source navigation.
10. Periodic notes/time blocks + permission-gated calendar context.
11. Meeting-note/follow-up integration + Kokoro read-aloud.

### RECKONER

1. Silent-Univer spike.
2. Truth/persistence/artifact writeback.
3. Dataset tab mount.
4. Dataset embed.
5. Tools + tracked changes.
6. MAS status + parked-presence leak check.
7. Swift Charts + provenance.
8. Scale/hardening.

## Acceptance tests

- Stale epoch transaction is rejected.
- Frontmatter survives byte-identical unless deliberately structured-edited.
- Unknown/Tier-C content is preserved and disclosed.
- One paragraph edit yields one-region diff.
- Two windows cannot silently clobber each other.
- Dataset embed markdown contains no cell data.
- Loading dataset emits zero autosave/change events.
- Univer never persists a computed value; IronCalc does.
- Agent edit cannot apply without suggestion UI approval.
- Chart has provenance before render.
- Prose/Source disclosure can preview/export complex content.
- Rebuild and incremental reconciliation produce identical task projections.
- Task completion/reschedule is a minimal source diff and cannot silently
  clobber another dirty editor.
- Empty, Unicode, malformed metadata, recurrence, time-zone/DST, rapid toggle,
  rename/move, and unsupported-block fixtures pass.
- Calendar denial/deletion/change is visible and does not damage vault truth.
- Meeting follow-up tasks appear in the same focus/project/search/graph views
  and retain a source link to the meeting note.
- Free V1 exposes no June, Browser, ResearchHub, or Epdoc Assist route while
  Kokoro and the deterministic workspace remain usable.
