# 12 - Live Reference and Free V1 Surface Registry

ID: `EPISTEMOS-MAS-FREE-V1-SURFACE-REGISTRY-2026-07-13`
Lock: `MAS-ONLY-SHIP-LOCK-2026-07-07`
Status: active dated owner addendum

July 15 supersession: read
`14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md` first. LumenLens
and AI are canceled; Reckoner is parked. Retain only non-AI editor correctness
and compatibility parsing from those lanes. The current Epdoc truth is native
JSON `.epdoc`; Markdown lenses remain one `.md` truth, and PDF/Markdown derived
outputs are explicit rather than synchronous mirrors.

This registry converts the July 13 workspace steer into executable boundaries.
It supplements, and does not weaken, KEELSTONE vault truth, the one-current-
build rule, MAS sandboxing, or the paid-source preservation rules.

## Owner intent checkpoint

Verbatim owner excerpts:

> there should eb no chats no ai other than kokoro ... i still see chats o the
> grsph whe there shoud not be chats at alll ... lots of settings parts and
> graph filters and just settigns nad things in general are stale and need to
> be removed.

> the source surface part of the app i want it to look like teh mark edit or
> more like mark edit ... i still want to keep my theme palette ... the rigth
> hand side ... should be the same color as the rest of the surface instead of
> a grey color.

> no the pla was to use the actual clone of the iron calc univer etc. but iron
> calc as the fromt end why was that taken off

> ep.doc is going to be the main default surface ... on the source and the
> prose, there should be an info section ... a popover that will explain all of
> the things that are embedded into that Markdown file ... ep.doc is going to
> be the one that has it all visual and that you can see, interact with it,
> edit, etc.

> I want it to be a PDF view added as like a fifth surface for the editors ...
> the same color palette the same font but just be a PDF ... an option to edit
> on it ... save it as PDF and then start looking at it.

> i wnat to be able to add images to epdoc ... make it as robust as it ca be ...
> rn its less trucutred but i want options tomake its trutured ... should be
> dynamic like that

Interpreted intent:

- Free V1 is a serious deterministic workspace, not a paid product preview:
  no chat, June, general model, agent, Browser, or ResearchHub surface remains
  visible or reachable. Kokoro local read-aloud is the sole bundled/app-owned
  model exception. Explicit owner-invoked macOS system dictation/text input may
  exist only as an OS service, never as another bundled model or background
  transcription route.
- The Source/Code editor should become more legible and direct, taking
  performance/editor motifs from the existing MarkEdit source while remaining
  recognizably Epistemos.
- Tabs and controls must belong to the application chrome rather than being
  interleaved with note body content. Stored paid/stub notebook records remain
  readable compatibility data, not free product features.
- RECKONER is free V1 and retains its real-source plan. The actual pinned
  IronCalc and Univer source clones are now present in the ignored research
  checkout; IronCalc owns the eventual visible grid and sole formula authority,
  while Univer remains required bounded supporting source. Their presence is
  not authorization to install or wire either one before the isolated MAS spike.
- Epdoc is the default full-fidelity rich-object lens. Prose and Source retain
  their own editing grammars but share one native object inspector so audio,
  drawings, images, tasks, calendar/reminder links, attachments, PDFs, meetings,
  and datasets can never become invisible merely because the active lens cannot
  render them inline.
- Epdoc can dynamically expose free-flow document, outline/project, timeline/
  agenda/calendar, and object/attachment-sidebar views over one manifest. PDF is
  the dedicated fifth canonical editor lens: full-size, native, and connected
  to the same title/object/source truth rather than a small isolated preview.

## Free V1 surface registry

| Surface or artifact | Free V1 status | Required enforcement |
|---|---|---|
| Kokoro local read-aloud | active | no general model picker/provider/agent startup |
| Epdoc, planner, Meeting, Sync, Capture, PDF/import, graph/search, export | active | vault/artifact truth and deterministic native paths |
| Epdoc native rich objects | active program, admitted per object family | full inline view/edit only after schema, permission, accessibility, performance, portability, and recovery gates pass |
| Source/Prose object inspector | required active seam | one typed derived manifest; native keyboard/VoiceOver popover; no second document or object store |
| PDF fifth editor lens | active program after typed-manifest foundation | full-size PDFKit viewer; Epdoc-derived palette/font rendition; imported-PDF fidelity; annotation/form editing and explicit save/export; no second document authority |
| June/Epdoc Assist/MiniChat | preserved paid source, invisible | product policy plus graph/notebook/settings/shortcut/deep-link/restoration guards |
| Chat/model/provider/agent runs/raw thought/tool trace | durable paid data if already stored; not free-visible | exclude from graph build/query/default/filter/restoration and notebook tabs |
| Saved-workspace and Time-Machine AI/chat history | durable paid data if already stored; not free-visible | sanitize summary presentation; do not render chat activity or reconstruct chat history in free V1 |
| Browser/ResearchHub | preserved paid source, invisible | no route, shortcut, deep link, provider/network startup, job, or restored surface |
| Sheet launcher/unfinished dataset tab | compatibility only until RECKONER proves it | no disabled/degraded free-V1 placeholder presented as a feature |

The registry is fail closed: a stored paid-only record does not create a free
surface merely because it can be parsed.

## Native rich-object cross-lens registry

Markdown and its referenced portable artifacts remain durable truth. A derived
typed object manifest is rebuilt from that truth and consumed by every lens.
Epdoc renders and edits admitted objects inline; Prose and Source expose the
same inventory in a native information popover and may add inline presentation
only after their own fidelity and performance evidence passes.

| Object family | Durable authority | Epdoc | Source and Prose |
|---|---|---|---|
| Tasks, lists, checklists, projects, headings, tags, dates, priority | readable Markdown syntax/metadata | native macOS-quality inline controls and views | source/prose location plus typed inspector; safe native text representation |
| Calendar events and reminders | EventKit; Markdown stores stable reference and user context | permission-gated context, linking, scheduling, and status | inspector always; inline only where deterministic and denial-safe |
| Voice notes and audio | portable vault artifact plus Markdown reference | explicit recording controls and inline playback | inspector with state/duration/path status; optional bounded player only after proof |
| Dictation/transcript | user-approved text plus source-audio/provenance reference | explicit dictation/transcript editing | normal text plus inspector linkage; no eager speech/model startup |
| Drawings/sketches | portable drawing/image artifact plus accessible description/reference | native edit/view surface | inspector and optional local preview; never opaque page-world file access |
| Images and attachments | user-owned portable artifact plus stable relative reference | inline view, metadata, replace/remove/open actions | inspector and safe local preview where supported |
| Meeting, RECKONER dataset/chart | existing artifact authority and provenance contract | inline/embed or linked workspace representation | inspector plus source-reachable reference; no row/blob duplication |
| Epdoc PDF rendition | Markdown plus referenced artifacts; PDF is derived output | export style preserves approved palette/fonts/hierarchy/images | dedicated PDF lens plus inspector/source anchor; body edits return to source and regenerate |
| Imported PDF | original user-owned PDF artifact | inline reference and open-in-PDF-lens action | dedicated PDF lens; original page content remains byte/visual faithful; annotations/forms save explicitly |
| Unknown or missing object | original Markdown bytes/reference | visible unsupported/missing state without destructive rewrite | mandatory inspector diagnostic and exact source navigation |

The manifest records stable ID, type, source range/reference token, authorized
vault-relative artifact path, availability, permission status, accessible
label, and safe lens actions. Full rebuild must equal incremental parsing.
Selecting an inspector entry navigates to the exact source reference or the
Epdoc object; it does not create a second title ontology, media library, task
database, calendar store, transcript store, or sync authority.

Native list/checklist quality is an acceptance boundary, not a style pass. The
component must cover hierarchy, hit targets, hover/focus/pressed/completed/
disabled states, drag/reorder, keyboard commands, VoiceOver, reduced motion,
undo/redo, rapid toggles, large documents, minimal-diff save, and light/dark
Epistemos themes while retaining the owner-approved palette and font identity.

Dynamic structure is also an authority boundary. Document, outline/project,
timeline/agenda/calendar, and object/attachment-sidebar views must all rebuild
from the same manifest, preserve source reachability and dirty/selection/scroll/
undo state, and never create a structured-note, image library, or attachment
database. Images remain portable vault-relative artifacts with accessible
descriptions and tested insert/replace/remove/move/missing/relink/export paths.

## PDF fifth-surface registry

The fifth editor surface is one full-size native PDFKit lens in the shared
editor switcher and identity chrome. It must provide fit-width/fit-page/zoom,
page navigation, thumbnails or outline, search, selection/copy under existing
policy, keyboard commands, VoiceOver labels, object/source inspection, and
stable restoration without constraining the page to a small preview card.

For an Epdoc note, the PDF lens shows a derived rendition generated from
Markdown and referenced portable artifacts. The explicit Epistemos export
style uses the approved palette, registered Matrix/Chonky/Greeting font policy,
document hierarchy, images, links, supported rich objects, and deterministic
pagination. A live rendition is debounced, cancellable, cached, and generated
off the typing/scroll path. It never becomes save truth.

PDFKit annotation and form editing—highlight, underline/strikeout, text note,
free text, ink/drawing, link, and supported widget fields—is legitimate in-lens
editing. Arbitrary imported PDF body-text rewrite/reflow is not promised:
structural content edits use Epdoc/Source and regenerate a derived PDF. Imported
PDFs are never silently recolored to the app theme; the Epistemos palette/fonts
apply to chrome and newly created annotation defaults while original page
appearance stays faithful.

All PDF writes use KEELSTONE and security-scoped access. Save a Copy is the
default imported-PDF mutation path until in-place atomic replacement, external
change/conflict, interruption, and reopen evidence passes. Visual acceptance
requires page rendering to PNG plus inspection for clipped text, missing fonts,
incorrect colors, broken images/links, overlaps, and unreadable glyphs.

## MarkEdit live reference registry

Verified local vendor facts:

| Field | Value |
|---|---|
| Local path | `LocalPackages/MarkEdit` |
| Upstream | `https://github.com/MarkEdit-app/MarkEdit.git` |
| Pinned ref | `7d56e2e64322e983c43aa789bc08e238860f0069` |
| License | MIT |
| Form | tracked vendored source; not a Git submodule or worktree |
| Existing Epistemos seam | `MarkEditCoreEditorView`, `MarkEditCoreEditorState`, `CodeEditorView`, `MarkEditShellCompatibility` |

This vendor is already integrated; do not re-clone it, restore its own app
shell, app group, extension, entitlement, updater, or branding. Preserve its
license notices for any retained substantial source. Use its native/CodeMirror
editor techniques only through Epistemos-owned bridge and palette code.

Source-surface done bar:

1. A user without a saved preference receives a readable source default; an
   existing preference is never overwritten.
2. Editor canvas, line-number gutter, and right/minimap strip use the same
   Epistemos surface field; active-line and cursor contrast remains accessible.
3. Notebook/source controls move to the native toolbar/accessory seam rather
   than document content. Chat/stub tabs disappear in free V1 without deleting
   manifest parsing.
4. The bridge continues to debounce full-buffer snapshots and save work; any
   4k- and 20k-line typing/scroll performance claim is backed by fresh manual
   evidence, not static source inspection.
5. The owner eye/preview popover and the rich-object information popover are
   distinct public native controls with narrow typed payloads. Neither restores
   MarkEdit's denied general file/service/clipboard bridge authority.

## RECKONER real-source recovery registry

Verified current state:

- The exact historical IronCalc and Univer commits are checked out detached and
  clean under ignored `.research-clones/work/`; neither is a project package,
  target member, runtime asset, or shipping claim.
- Historical plans also record Teable `498e255` and Baserow `d5901c0`. They
  are historical provenance only, not active RECKONER recovery targets.
- The official upstream recovery sources are
  `https://github.com/ironcalc/IronCalc` and
  `https://github.com/dream-num/univer`. Historical pins alone would not prove
  availability; the detached checkouts and receipt hashes above are the current
  local proof. Future sessions must reverify those ignored paths and receipts
  before relying on them.
- The historical build plan used `@ironcalc/wasm` `0.7.0` and
  `@univerjs/*` `0.25.1`; these are historic source facts, not installed current
  dependencies.
- Historical July plans selected a silent-Univer-screen/IronCalc-calculator
  split because they favored Univer's then-more-mature grid UI. That choice is
  superseded: the owner explicitly selected the actual IronCalc source as the
  free-V1 front end. Recover both real source clones; IronCalc owns the visible
  surface and calculation authority, while Univer remains a bounded supporting
  source that cannot replace IronCalc or introduce a second active formula
  engine.

Pinned checkout receipt:

| Source | Detached commit | Git tree | Tracked-file manifest SHA-256 | License-text SHA-256 |
|---|---|---|---|---|
| IronCalc | `1bd4bb6005ffda4fcb1f287f4d4e7b564e310ddc` | `7b812148f9c2dc4c2972a455518d0ccd6b3a1752` | `354d7e4f7be0b302e947fbebaf756e5e7c0ed6b6e923ec5e1b654560b3e17c34` | Apache-2.0 `508d09859d3ef9a73985e8862c9e617ae9020451546e83d86830e5b1c42ad38f`; MIT `2daf68cb21cba8ec3b9e76138fa1ae5ff3707823dc6a89ff3df321d7a5213df0` |
| Univer | `6ae8eb3ef05c7645ed1425b13358bab1d8155a32` | `fb6da75584067acc196df4739a048b10ae782bef` | `af451df5cb36326eaf147720b728da27744a2870283488c646629a31e997795c` | Apache-2.0 `a6cba85bc92e0cff7a450b1d873c0eaa2e9fc96bf472df0247a26bec77bf3ff9` |

Source-checkout and later integration gate:

1. Complete the admission record: official upstream URL, exact ref, detached
   commit, tree/content digest, license texts, dependency license/notice
   questions, ignored quarantine location, ownership boundary, and removal path.
2. Keep both actual source checkouts isolated from app targets and packages;
   do not run either project, load owner data, or make a shipping claim.
3. Bind the recorded IronCalc source to the front-end and calc-authority
   contract. Keep the recovered Univer clone as a reviewed, bounded supporting
   source with an explicit non-displacing, non-computing role; it is not an
   optional archival artifact. Reject a second active formula engine, a Data
   room, a data chat, GRDB durable truth, embedded row blobs, and agent writes.
4. Run an isolated MAS WebView/package-size/license spike that loads no owner
   data and writes no production source. Only then choose the first real grid
   slice.

RECKONER's retained free-V1 product shape is workspace dataset tabs/embeds,
vault CSV/XLSX/`.icalc` artifacts as truth, one calc authority, native Swift
Charts primary, and shared Epdoc/provenance/event seams. No paid AI feature is
required for the deterministic grid.

## Execution order and evidence

1. Preserve the current KEELSTONE execution key and complete its locked runtime
   matrix when the Mac is available; never bypass the lock or mutate its sole
   evidence archive.
2. Correct the highest-risk free-V1 escape first: graph/notebook projection and
   stale paid settings/controls, with a failing test then a narrow source fix.
3. Correct the MarkEdit bridge's surface seam and add source guards; measure
   visual/typing behavior only after a fresh one-current-build evidence leg.
4. Recover RECKONER sources through the gate above while continuing independent
   Epdoc/planner/Meeting/Sync/Capture work.
5. After KEELSTONE and restricted-host MarkEdit proof, begin native-rich Epdoc
   with a current-source object inventory and a failing typed-manifest rebuild/
   round-trip test; admit object families serially rather than as an unverified
   all-at-once surface rewrite.
6. Add images and read-only dynamic structure/object-sidebar projections, then
   the full-size read-only PDF lens and a palette/font-faithful Epdoc PDF
   fixture. Admit annotation/form writes, Save a Copy, and live PDF rendition
   only after authority, render, sandbox, and performance evidence passes.
7. One edit/build owner may delegate read-only audits but must re-read cited
   files, inspect each diff, and consolidate evidence before handoff.

## Non-goals

- No cloning Things, NotePlan, MarkEdit, Teable, Baserow, or any proprietary
  product design or format.
- No StoreKit, payment, paid activation, provider/model startup, or June key.
- No deletion of retained paid data/source merely to hide it in free V1.
- No runtime, visual, or performance completion claim without exact current
  source/build/manual evidence.
