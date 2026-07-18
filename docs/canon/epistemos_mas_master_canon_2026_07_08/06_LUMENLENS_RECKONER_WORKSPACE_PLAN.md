# 06 - LUMENLENS + RECKONER Workspace Plan

## July 15 status - retired combined plan

Do not execute this plan. LumenLens as a named lane and every AI/suggestion/
copilot/agent obligation are canceled. Reckoner and spreadsheet/database
product work are parked reversibly. The only surviving material is non-AI
editor correctness—load-vs-edit safety, serialization fidelity, save/conflict/
recovery discipline, stable editor navigation, and user-data compatibility—
re-owned by the Epistemos Editor Core and KEELSTONE under
`14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md`. The current
Epdoc authority is standalone JSON `.epdoc`, not the old shared Markdown-
derived LumenLens suggestion/object architecture.

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

### Free-V1 Source surface and notebook projection

- The existing `LocalPackages/MarkEdit` MIT vendor is the source-editor
  implementation reference. Its Epistemos bridge, not an independently
  re-cloned shell, owns source editing.
- Preserve the Epistemos palette while making editor canvas, line-number gutter,
  and right/minimap strip one coherent field; keep accessible active-line and
  cursor contrast.
- Use a readable source default only for users without an explicit saved
  preference. Do not overwrite user type settings.
- Notebook controls belong in the native toolbar/accessory seam, not inside
  note content. In free V1, stored Chat or unimplemented Sheet launcher records
  are compatibility data and must not become visible tabs or placeholders.
- Any typing/scroll performance claim requires a fresh serial measurement on
  representative 4k- and 20k-line files; static debounce settings are not
  runtime proof.

## RECKONER dataset truth

RECKONER active obligations:

- Dataset truth is vault artifact: CSV for flat datasets; XLSX/`.icalc` for workbooks; `.dataset.md` for metadata.
- GRDB is derived working cache.
- The real IronCalc and Univer source clones are both required RECKONER inputs.
  IronCalc is the selected free-V1 spreadsheet front end and sole calculation
  authority.
- Univer remains a retained, bounded supporting source rather than an optional
  archival reference. It cannot replace IronCalc as the free-V1 front end or
  activate a second formula engine.
- Swift Charts is primary charting path.
- Dataset tabs open inside the existing note/workspace tab system.
- Dataset embeds carry references only, never row blobs.
- Free V1 makes direct deterministic, user-initiated data edits only.
  `TabularSuggestions` is future paid-June work and requires separate approval
  when that lane is explicitly reactivated.
- No Data room and no data chat.

RECKONER real-source recovery is complete only at the source-checkout stage:
the actual pinned IronCalc and Univer repositories are in the ignored research
checkout with recorded refs, license texts, and tracked-file digests. The July
13 owner clarification supersedes the historical silent-Univer-screen choice:
IronCalc is the free-V1 front end and sole formula authority; Univer remains a
required bounded supporting source. Run a small isolated MAS packaging spike
before installing or wiring either source. Do not silently replace IronCalc
with an unrelated grid, drop the Univer source, or let Univer displace
IronCalc. Read `13_EXECUTIVE_CONTINUITY_AND_FREE_V1_REMEDIATION_2026_07_13.md`.

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

1. IronCalc front-end source-recovery and MAS packaging spike.
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
- No secondary spreadsheet formula engine or front end can displace IronCalc
  or persist computed values outside the vault-artifact transaction path.
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
