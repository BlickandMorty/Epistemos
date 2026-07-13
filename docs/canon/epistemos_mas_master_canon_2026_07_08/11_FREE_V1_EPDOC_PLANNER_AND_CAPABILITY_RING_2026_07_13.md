# 11 - Free V1 Epdoc Planner and Capability Ring Addendum

ID: `EPISTEMOS-MAS-FREE-V1-EPDOC-PLANNER-2026-07-13`
Lock: `MAS-ONLY-SHIP-LOCK-2026-07-07`
Status: active dated owner addendum

This document records the owner's July 13, 2026 product steer. It overrides
conflicting July 8 sequencing and free-product visibility language only where
named below. It does not weaken KEELSTONE storage truth, MAS sandboxing,
privacy, one-current-build evidence, or parked-lane boundaries.

## Owner intent checkpoint

Verbatim owner excerpt:

> i also wat toamke epdoc alot more useful taking all featres from things 3 ad
> the ohter creenshots adding that to the mas canon ... i ofc want to keep the
> voicer model ... the kokoro model ... remmeber idk if reckoner was the last
> thng i still had teh sync thing i ha oher thngs beyid reckoner.

Interpreted intent:

- Free V1 has no June, agentic behavior, cloud/local chat model, generative
  editor action, generative summary, or AI-only automatic job.
- Kokoro remains as an explicit local voice/read-aloud exception. It is not a
  reason to expose June or a model/agent surface.
- Epdoc becomes the central note, task, planner, calendar-context, and meeting
  workspace.
- LUMENLENS and RECKONER are followed by the capability ring. RECKONER is not
  the final product surface.
- Meeting, Sync, Quick Capture, calendar/tasks, PDF/import, Kokoro voice,
  search/graph, and export must connect through the same vault, provenance,
  and event seams rather than remain isolated rooms.
- Browser and ResearchHub remain in the MAS canon as future paid capabilities,
  but are hidden and inert in free V1.

## Free V1 product boundary

Active deterministic/local product spine:

1. KEELSTONE vault, access, atomic writes, reconciliation, conflict handling,
   rebuildable projections, pruning, and release evidence.
2. LUMENLENS Epdoc editing, Markdown fidelity, notebook/workspace references,
   provenance, task/planner syntax, and derived planning views.
3. RECKONER datasets, tables, calculation, charts, artifact tabs, and embeds.
4. Free capability ring: Meeting, Sync, Quick Capture, calendar/tasks,
   PDF/import, local speech/voice, graph/search, and export.

Deferred paid lane:

- MAS June is retained as the sole future agent if the owner explicitly
  reactivates paid-feature work.
- Epdoc Assist/MiniChat, agent tools, chat models, generative editing,
  generative summaries, model selection, cloud providers, and AI-only
  automation stay hidden and inert in free V1.
- Browser and ResearchHub are future paid capabilities and stay hidden and
  inert in free V1, including their routes, shortcuts, deep links, automatic
  jobs, provider/network startup, and background work.
- Apple enrollment, payment, signing, StoreKit, subscriptions, receipts, and
  paid activation are deferred. Do not block safe free-V1 source work on them.

## Reference motifs, not product cloning

The owner-supplied Things 3 screenshots contribute these product motifs:

- Inbox, Today, This Evening, Upcoming, Anytime, Someday, and Logbook views.
- Projects and areas, headings/sections, notes, checklists/subtasks, tags,
  scheduling, deadlines, reminders, recurrence, and quick entry.
- Calendar events shown beside tasks and deterministic rescheduling.

The owner-supplied NotePlan screenshot contributes these product motifs:

- Markdown notes, tasks, and calendar context in one workspace.
- Daily, weekly, monthly, quarterly, and yearly planning/goal notes.
- Time blocks, meeting organization, folders/projects/areas/resources/archive,
  linked notes/backlinks, and sync.

These are capability references, not permission to copy screenshots, trade
dress, proprietary file formats, proprietary sync, wording, icons, or visual
composition. Epistemos must express them through its own native design system,
Epdoc semantics, and MAS architecture.

Official reference validation:

- Things documents Today/Upcoming/Anytime/Someday as date-derived views and
  describes calendar context, Inbox, Logbook, rescheduling, projects/areas,
  reminders, tags, headings, and Quick Entry:
  https://culturedcode.com/things/support/articles/4001304/
  and https://culturedcode.com/things/support/articles/1059358/
- NotePlan documents daily notes containing tasks, goals, time blocks, and
  meeting notes, plus daily/weekly/monthly/yearly planning:
  https://help.noteplan.co/article/43-part-1-daily-notes and
  https://noteplan.co/meta_002
- Apple requires explicit access through EventKit, least-privilege calendar or
  reminder permission, denial-safe behavior, and the macOS Calendar sandbox
  entitlement when calendar data is read:
  https://developer.apple.com/documentation/eventkit/accessing-the-event-store

## Epistemos-native information architecture

Durable truth:

- Human-readable vault Markdown remains task, project, goal, meeting-note, and
  planning truth.
- Approved audio, transcript, PDF, dataset, and export files remain referenced
  artifacts.
- Stable IDs must survive rename/move and may be added only through a readable,
  round-trippable Markdown convention proven against existing Epdoc content.
- RECKONER workbook/dataset formats remain artifact truth for tabular data.

Rebuildable projections:

- Inbox, Today, This Evening, Upcoming, Anytime, Someday, Logbook, calendar
  agenda, task search, and task counts are indexes over vault truth.
- Calendar events and reminders remain EventKit truth. Epistemos stores stable
  references and user-authored links/context; it does not silently duplicate
  the user's whole calendar into a private authoritative database.
- Search, graph, GRDB, caches, thumbnails, embeddings, and planner indexes are
  derived and disposable.

Shared seams:

- Writes flow through KEELSTONE coordinated/atomic write paths.
- Epdoc/LUMENLENS owns visible Markdown editing and minimal-diff writeback.
- One provenance schema records task moves, completion, rescheduling, meeting
  links, time-block/calendar publication, capture promotion, and exports.
- One event bus publishes note/task/meeting/calendar/sync/dataset changes.
- No task room, planner database, meeting database, transcript database, sync
  authority, or parallel reconciler may be added.

## Epdoc planner capabilities

Required product capabilities, delivered in testable slices:

1. Readable task blocks: title, completion/cancellation, notes,
   checklists/subtasks, tags, parent project/area, and stable identity.
2. Deterministic dates: start/scheduled date, deadline, reminder reference,
   recurrence rule, completion timestamp, and optional This Evening grouping.
3. Projects/areas and headings: vault-native organization with backlinks and
   a visible archive/logbook path.
4. Derived focus views: Inbox, Today, Upcoming, Anytime, Someday, and Logbook,
   with the source note/project always reachable.
5. Quick Entry: keyboard-first capture of task title and optional notes,
   project/area, tags, date, deadline, reminder, and checklist without June.
6. Calendar context: permission-gated events beside tasks, explicit
   user-initiated links, and deterministic rescheduling/time-block actions.
7. Periodic planning: daily, weekly, monthly, quarterly, and yearly Markdown
   notes/templates; goals can link down into tasks and up into source projects.
8. Epdoc fidelity: task metadata, unknown Markdown, frontmatter, links,
   comments, and unsupported blocks round-trip without silent loss.

Natural-language date entry may be added only as a deterministic local parser
with locale/time-zone tests. It must not call June, a provider, or a model.

## Meeting integration

Meeting is a workspace capability, not a separate room.

- A meeting note can link to an EventKit event identifier, calendar title,
  time range, attendee references, agenda, decisions, sources, follow-up tasks,
  and referenced audio/transcript artifacts.
- Meeting creation starts from an Epdoc template or a user-selected calendar
  event and writes through KEELSTONE.
- Follow-up tasks are ordinary vault tasks and appear in the same Today,
  Upcoming, project, search, and graph projections.
- Recording requires explicit consent, a persistent visible recording state,
  bounded retention, and crash-safe artifact finalization.
- Local speech-to-text may be used only through an MAS-safe, consented,
  non-agentic path with honest availability. It must not silently enable June,
  a provider, a sidecar, or a separate transcript database.
- Kokoro may read selected Epdoc or meeting text aloud locally. Microphone
  consent is not requested for read-aloud alone.

## Capability ring after RECKONER

The free-V1 sequence continues with:

- Sync: KEELSTONE-coordinated iCloud/external-folder coexistence, visible
  conflicts, placeholders, rename/move identity, and no proprietary server.
- Quick Capture: zero-loss text, voice, screenshot/file, link, and task ingress
  with later promotion into Epdoc/project/meeting records.
- Calendar/tasks: EventKit permission boundary, derived agenda, reminders,
  time blocks, recurrence, and source-reachable projections.
- PDF/import: PDFKit/native parsing, legal user-selected imports, citations,
  and portable artifacts without an agent dependency.
- Local voice: Kokoro read-aloud and consented MAS-safe speech input; no
  Python/subprocess voice wrapper or hidden runtime.
- Search/graph/export: deterministic indexes, backlinks, task/meeting/data
  edges, and portable vault/artifact export.

Future paid capability ring, retained but not free-V1-active:

- ResearchHub: official API/RSS/OA/BYO sources, legal metadata/import, and
  save-to-vault citations/provenance. Paid status never permits scraping,
  paywall bypass, hidden full-text access, or credential harvesting.
- Browser: bundled WebKit browser-lite only. Paid status never permits
  Chromium, browser-use automation, CDP, local servers, or sidecars.
- Both require the same centralized product-capability gate as June so free V1
  cannot enter them through navigation, shortcuts, deep links, restoration,
  automatic jobs, provider startup, or stale saved state.

## Acceptance and evidence bars

- Free-V1 capability policy hides and disables every June/generative/agent
  route while preserving Kokoro and deterministic Meeting/planner paths.
- Markdown round-trip fixtures cover empty/nil, Unicode, malformed metadata,
  recurrence, time zones/DST, concurrent edits, rapid completion/reschedule,
  rename/move, and unsupported blocks.
- Rebuild from vault yields the same task/planner projection as incremental
  reconciliation.
- A task edit produces a minimal source diff and does not clobber a dirty note
  in another window.
- EventKit denial, restricted access, deleted events, changed identifiers,
  recurrence, and event-store refresh all fail visibly and safely.
- Meeting-to-follow-up-task, Quick-Capture-to-task, and task-to-calendar/time-
  block paths preserve source reachability and provenance.
- Sync conflict and crash/quit tests prove no silent task, meeting, or capture
  loss.
- Kokoro read-aloud proves local routing and does not expose June/model picker
  UI or start an agent/provider.
- Release claims still require the exact current app/archive evidence defined
  by KEELSTONE and the one-current-build rule.

## Execution order and exact next action

1. Finish or explicitly debt-log the current KEELSTONE non-AI storage and
   artifact gate under execution key
   `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.
2. Inspect existing Epdoc task syntax, calendar/Meeting routes, Sync,
   Quick Capture, and Kokoro call sites before choosing schema or UI.
3. Land the smallest test-first Epdoc task-index slice that preserves existing
   Markdown and uses KEELSTONE writes.
4. Expand serially into focus views, periodic notes/time blocks, Meeting links,
   Sync/Capture integration, PDF/import, Kokoro, graph/search, and export.
5. Do not start the June execution key or payment/signing work. When future
   paid work is explicitly reactivated, June remains the only allowed agent.
