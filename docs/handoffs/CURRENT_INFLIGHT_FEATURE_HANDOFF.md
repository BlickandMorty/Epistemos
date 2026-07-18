# Current In-Flight Feature Handoff

Updated: 2026-07-15

This file is the durable GitHub anchor for moving an unfinished Epistemos task
between Codex sessions or machines. A prompt alone does not transfer hidden
model context. The previous task must write its exact implementation state into
this file, commit the relevant work, push it, and report the remote commit SHA.

Authority boundary: this handoff reports state and evidence only. The owner's
full external July 8 master-canon folder controls execution order, and its
numbered `03_MINIMAL_PROMPT_PACK.md` is the sole prompt authority. This handoff,
the repository mirror, status documents, and the preparation packet must never
be used as replacement prompts.

Dated owner override: canon addendum
`11_FREE_V1_EPDOC_PLANNER_AND_CAPABILITY_RING_2026_07_13.md` controls the
free/paid product boundary where older July 8 MAS/June visibility language
conflicts. The active app edition is free V1: June, generative/model/agent
features, Browser, and ResearchHub are paid-only and hidden/inert. Kokoro and
the deterministic local capability ring remain free. This does not change the
current KEELSTONE execution key or external-canon authority.

Latest dated owner override: external/repository canon addendum
`14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md` supersedes every
conflicting LumenLens, June/AI, and Reckoner execution instruction. LumenLens
and all AI/agent/model/provider/generative work are canceled. Reckoner and
spreadsheet/database-product work are parked reversibly. All requested non-AI
work remains active except Reckoner, including the Editor Core, KEELSTONE,
Sync, Quick Capture, planner/calendar/Meeting, PDF, graphs, native integrations,
settings/performance hardening, export, and Kokoro. Browser and ResearchHub are
deterministic future paid possibilities only and remain absent from Free V1.

Directive-coverage companion:
`15_OWNER_DIRECTIVE_COVERAGE_AND_HARDENING_CHECKPOINT_2026_07_15.md` is the
durable add/remove/harden/test routing index. It preserves the subtle P0
Contextual Shadows/query/notebook/AI-compile/Reckoner/restoration/release-gate
work, current per-feature implementation and proof status, exact editor and
Kokoro contracts, KEELSTONE debt, and the safe resume order. Read it after 14;
do not reconstruct the queue from this handoff summary alone.

Newest sequential two-lane execution directive:
`16_TWO_LANE_REMOVAL_AND_REBUILD_DIRECTIVE_2026_07_15.md` authorizes two
non-overlapping source sessions under the same KEELSTONE key, but they execute
one at a time. Lane R is current and executes
`docs/prompts/FREE_V1_REMOVAL_AND_FAIL_CLOSED_PROMPT_2026_07_15.md`. Lane B
is deferred until Lane R records a stable source checkpoint, then executes
`docs/prompts/RETAINED_BUILD_EPDOC_AND_MULTITASK_GRAPH_PROMPT_2026_07_15.md`.
Lane R's legacy notebook removal means only the retired Chat/Sheet/Body-strip
workspace; it must preserve the future Epdoc-native notebook/structured-
document concept and canonical JSON `.epdoc` seams.
The owner reports the native Epdoc is visibly bare relative to the previous
rich Tiptap surface and the Multitask Graph opens blank. These are Lane B's
immediate P0 defects. Neither lane may edit Settings or overlap the other's
file map, and neither may run Xcode/app verification until both sequential
source checkpoints are stable.

Concurrent ownership note: the owner is cleaning up Settings in another
session. Preserve all current Settings-file edits as externally owned in-flight
work. Do not overwrite, revert, absorb, or independently “fix” those files;
reconcile and test their final state at the later one-current-build boundary.

## July 15 Owner-Scope Pause Checkpoint

The owner requested a review checkpoint. Production implementation, builds,
tests, and launches are paused. Do not use any older “exact next action” later
in this handoff until this section and canon `14` have been read.

### Repository identity at the pause

- branch: `feat/goose-surface`;
- local HEAD, `origin/feat/goose-surface`, and handoff publication commit:
  `668b52cfb43721de95db102260d9f327ae24e13e`;
- dirty owner/in-flight worktree intentionally preserved; do not reset,
  overwrite, or assume uncommitted current-source changes are on GitHub;
- canonical execution key remains
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`;
- private Columbia/VA/funding work is outside this repository.

### Current evidence boundary

- R109: one older Free V1 Release archive passed artifact scanners and omitted
  named June/model/provider/agent products. It is unsigned local evidence and
  stale relative to current source.
- R110: one partial runtime pass on R109 found small Markdown editing and Source
  switching usable, but also stale Settings copy, Source-width residue, missing
  Epdoc discoverability, toolbar overflow, and unexecuted graph routes. Its
  Epdoc typing leg was contaminated and is not product evidence.
- R113: the Free V1 App Store target compiled and four selected guards passed
  for Source wrap/no width slider, Landing commands, Epdoc graph source, and
  Home/Multitask plus two graph routes. It is stale relative to the next batch.
- The current editor batch has only Swift parse and `git diff --check` evidence.
  It has not received a replacement Xcode build, scheme-member test run, app
  launch, large-document runtime pass, memory pass, visual check, or
  accessibility check.

### Current unbuilt editor batch

Key current-source work includes:

- `MotionTitle.swift` and editor hosts: recovered ASCII/blur title reveal,
  bubble removal intent, activation/identity keys, Reduce Motion/occlusion;
- `EpdocDocument.swift`, `EpdocTextKit2EditorSession.swift`, and
  `EpdocTextKit2EditorView.swift`: autosave/explicit-save state, coalesced
  projections/checkpoints, reduced duplicate validation, no-op width handling;
- `EpdocEditorToolbar.swift` and `EpdocEditorChromeView.swift`: truthful native
  capabilities plus link/image/find actions and save-state presentation;
- `EpdocGraphProjector.swift`, `EpdocGraphRenderingMapper.swift`, and
  `EpdocQuery.swift`: retired complexity work removed from the graph/query path;
- `CodeEditorView.swift` and `CodeFileIconView.swift`: obsolete left identity
  chip removed;
- Landing, Notes sidebar, `HomeDocumentWorkspaceView`, UI state, graph routes,
  and Source wrap/format-label changes from the R113 batch;
- scheme-member App Store tests in
  `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`,
  `EpdocNativeToolbarTests.swift`, and `EpdocCanonicalContentTests.swift`.

This list is a batch map, not a compilation or behavior claim.

### Newly audited P0 contradictions

- Free V1 Contextual Shadows can still query and present stored chats.
- AI-diff/HandleWithCare suggestion code, AI bridge/provenance types, dormant
  AI views/services, and some chat/LLM-adjacent composition-root state remain
  compiled even where their visible controls are hidden.
- `.reckoner` remains advertised as a Free V1 capability and a pending dataset
  hook remains in `VaultIndexActor` despite the owner parking Reckoner.
- HTML Workspace/Setup copy and KEELSTONE source gates retain stale AI/June
  assumptions.
- Standalone Epdoc title identity has not proven parity with the shared
  Name/Tags/Where and rename/move popover.

### Exact safe resumption boundary

After owner review, under the same KEELSTONE key:

1. Seal the Free V1 AI/chat query, compile, bootstrap, settings/copy, and release-
   gate boundaries; remove Reckoner from active capability truth while retaining
   compatibility parsing and quarantined provenance.
2. Finish the retained non-AI editor batch and resolve Epdoc title-popover
   parity without expanding features.
3. Retire stale R113, perform the mandatory below-16-GiB resource preflight,
   and produce exactly one current App Store Debug build/test product.
4. Run the finite editor/navigation/graph/67k-72k/save/title/settings/Kokoro/
   accessibility/memory runtime matrix on that exact app.
5. Close KEELSTONE with one fresh Release archive and all artifact/release
   gates. Do not begin another canonical execution key.

The scope decision is in canon `14`; the complete directive inventory,
current-state matrix, and remaining capability order are in canon `15`.

## Owner Intent Checkpoint

Owner wording:

> "in case things dont go as planned ... send something to my github that the
> new codex can pull or reference that has an understanding ... i do not lose
> the present work it is an in flight feature set im working on"

Latest owner steer:

> "one executive note is that i want this to be on my github and my flash drive so please save it to my donwalods and put it on my github please that i can easily resuem our conversation and entire thread.
> Publish the exact Epistemos feature currently in flight so another Codex task on my other laptop can resume it without losing context.
>
> Repository: `/Users/jojo/Downloads/Epistemos`
> Branch: `feat/goose-surface`
>
> First read these files completely:
>
> 1. `AGENTS.md`
> 2. `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
> 3. `docs/handoffs/EXTERNAL_PLAN_ASSETS_RECOVERY_2026_07_12.md`
> 4. The current feature plan, intent ledger, verification ledger, source files, tests, logs, and existing diff.
>
> Do not summarize from memory. Inspect the actual repository state first.
>
> Update the `Previous-Task Checkpoint` in `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md` with:
>
> - exact feature and canonical execution key;
> - my latest owner steer verbatim;
> - intended behavior and done bar;
> - every modified file;
> - completed and incomplete work;
> - tests, builds, and manual checks actually performed;
> - retained logs and artifacts;
> - known failures and verification debt;
> - exact next action and commands;
> - commit, branch, and verified remote SHA.
>
> Preserve MAS-only June boundaries. Do not revive parked Goose, Pro, Experimental, 1Code, OpenChamber, sidecar, subprocess, local-server, Node, terminal, stdio-MCP, or browser-use product lanes.
>
> Stage only files that genuinely belong to the in-flight feature and the handoff. Never use `git add .` or `git add -A`. Do not revert, overwrite, or absorb unrelated changes.
>
> Commit the actual in-flight work, push `feat/goose-surface` to origin, fetch it again, and verify the local and remote SHAs match. If mixed ownership prevents a safe feature commit, push the updated handoff alone and explicitly list every file that remains local.
>
> Finish by giving me the exact New-Laptop Resume Prompt from the handoff, the verified remote SHA, committed files, uncommitted files, completed verification, and remaining debt."

Newest continuity steer:

> "teh main canon is that one folder - is the canon folder i attached that is
> the soruce of truth for my work."

> "the most important thing is that i make sure that i can cotninue working in
> order."

The attached executive-planner correction is controlling:

> "The external master-canon folder controls the plan. Repository handoffs and
> the preparation packet may help us understand evidence, but they must never
> become replacement prompts."

Interpreted intent:

- Preserve the exact unfinished feature state outside one Codex task.
- Give the previous task a precise protocol for publishing its context and
  code without staging unrelated work.
- Give the new laptop a deterministic read order and exact resume command.
- Preserve the current MAS master canon and low-RAM preparation packet that
  previously lived outside the repository.
- Resume the canon's exact Prompt 2 only. Do not create or use a custom Prompt
  A/B/C/D chain and do not let a handoff or status document reorder the canon.
- Keep private Columbia, VA, financial, credential, and personal data out of
  GitHub.

Hard constraints:

- Active product target is the MAS-only `Epistemos-AppStore` free V1 edition.
  June remains the only future paid agent, but it is not active in free V1.
- The current execution key is
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` until its evidence bar is
  honestly closed.
- The historical branch name `feat/goose-surface` does not authorize Goose,
  Pro, Experimental, OpenChamber, 1Code, a subprocess, local server, or Node
  backend as an active product lane.
- Never use `git add -A`, `git add .`, broad cleanup, reset, checkout-overwrite,
  or deletion to prepare the handoff.
- Do not claim runtime behavior from source parsing, static gates, or an old
  archive.

Non-goals:

- This file is not a substitute for committing the actual in-flight code.
- It does not declare KEELSTONE complete.
- It does not reopen parked product lanes or authorize unrelated refactors.
- It does not copy Codex databases, browser state, credentials, or private
  funding documents into the repository.
- It does not publish the older 42 MB before-autonomy-fix archive or its nested
  source ZIPs to this public repository.

## Verified Repository Baseline

```text
Repository: https://github.com/BlickandMorty/Epistemos
Branch: feat/goose-surface
Baseline commit: f0f72a21c7c1e405081357154edddaafecd6545b
Pre-publication branch tip: 38f5dd6a3b022f659c6e5a5b240b6f1b2af200ef
Pre-publication upstream state on 2026-07-12: 0 ahead / 0 behind
Product lock: MAS_ONLY_SHIP_LOCK_2026_07_07
Current execution key: EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08
Imported canon: docs/canon/epistemos_mas_master_canon_2026_07_08/
Imported preparation: docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/
```

Read first:

1. `AGENTS.md`
2. `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
3. `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/00_READ_FIRST.md`
4. `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/01_OWNER_LOCK_AND_CANONICAL_THESIS.md`
5. `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md`
6. `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/03_MINIMAL_PROMPT_PACK.md`
7. `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/11_FREE_V1_EPDOC_PLANNER_AND_CAPABILITY_RING_2026_07_13.md`
8. `docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/PREPARATION_PACKET_CORRECTION_LOG.md`
9. `docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/00_READ_FIRST_PREPARATION_ONLY.md`
10. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
11. `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
12. `docs/plans/keelstone/HANDOFF_MAS_BASE_APP_COMPLETION_2026_07_10.md`
13. `docs/plans/keelstone/HANDOFF_OWNER_STEERS_CLOSEOUT_2026_07_10.md`
14. `docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`
15. `docs/plans/keelstone/INTENT_LEDGER.md`
16. `docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md`
17. `docs/handoffs/EXTERNAL_PLAN_ASSETS_RECOVERY_2026_07_12.md`
18. This file, including the current continuation checkpoint below.

Before using the repository read order, verify the full external canon at
`/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/` and read its
numbered `03_MINIMAL_PROMPT_PACK.md`. The imported repository copy is a recovery
mirror, not higher authority.

## Current Authoritative Continuation Checkpoint — 2026-07-14

Status: `IN_FLIGHT_RUNTIME_MATRIX_RED_REPAIR_REQUIRED`

Exact feature:

`KEELSTONE free-V1 capability boundary, single current Release archive, exact
artifact proof, and pending owner-visible non-AI runtime matrix`

Canonical execution key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Latest owner steer:

> the v1 free versjon will have no ai at all.

> browser, research hub both are needing to be on paid version as well an
> hidden from v1 releawe

> movig forward there must be oe build whever testung u must delte the stale
> builds before building an ew app

Current intended behavior and done bar:

- Free V1 keeps KEELSTONE, LUMENLENS/Epdoc planner work, RECKONER, Meeting,
  Sync, Quick Capture, calendar/tasks, PDF/import, Kokoro, graph/search, and
  workspace/export.
- June, Epdoc Assist, models/providers, generative/agent actions, Browser, and
  ResearchHub are future paid MAS capabilities and must be absent/inert across
  navigation, settings, shortcuts, restoration, startup, and background work.
- Payment, StoreKit, enrollment, and Apple distribution signing are deferred.
  Do not ask for them or block free-V1 source/local evidence on them.
- KEELSTONE remains incomplete until the exact single archive has both green
  artifact gates and an owner-visible finite free-V1 runtime matrix with
  correlated logs. App Store submission readiness is a separate future gate.

Proven current state:

- Local `HEAD`, fetched `origin/feat/goose-surface`, and the handoff publication
  commit are exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 117 and
  `git diff --check` passes; nothing was reset or overwritten.
- The centralized `ProductCapabilityPolicy`, free build condition/settings,
  paid-route guards, and free resource omission path are implemented.
- The formerly Red14 watcher-warning leg now passes an exact focused 1/1 test
  and a fresh selected 25/25 regression with zero failed, skipped, expected-
  failure, issue, or direct Runtime Warning nodes. The test-only container
  release correction does not change production watcher behavior.
- Exactly one current archive exists:
  `/Users/jojo/Downloads/Epistemos/build/archives/Epistemos-FreeV1-current-2026-07-14.xcarchive`.
  Its exact app is universal `x86_64 arm64`, bundle
  `com.epistemos.appstore`, version 1.0.0 build 1, and locally ad-hoc signed for
  evidence with the App Store entitlements.
- Direct archive-result inspection reports `succeeded`, zero errors, and
  thirteen retained compiler/toolchain warnings. The exact Release graph
  archive was universal and had zero SQLite exports/string names before its
  disposable staging copy was removed.
- Strict deep signature verification passes. CDHash is
  `1e5bf8ec807e1cea25414214c663a554ac5b009b`; `TeamIdentifier` is absent, so
  this is not distribution signing. Executable SHA-256 after signing is
  `16773d596813727bcf8894b6719c2ec329fb5ac29d7a1f124d670fffb28575c8`.
- The exact built-app KEELSTONE gate and separately retained comprehensive
  scanner pass. App Sandbox is effective. The main privacy manifest matches
  source byte-for-byte; GRDB supplies the second expected nested manifest.
  `JuneWeb`, model/agent resources, paid linkage, test frameworks, quarantine,
  and all scanner forbidden findings are absent.
- Disposable archive DerivedData and the staged graph archive are absent.
  The only current Epistemos app is nested inside the only current archive.

Unproven and verification debt:

- No current-source runtime leg has begun against the July 14 archive. Still
  prove: paid surfaces absent/inert; disposable-vault save/relaunch/save; Epdoc
  rich-Markdown lens fidelity; deterministic Meeting/Capture/planner/Sync/
  calendar/PDF/export entry points; graph/search routing; and English Kokoro
  with no agent/model/provider startup.
- The local ad-hoc signature is not Apple distribution signing. Payment and
  submission readiness remain deferred and unproven.
- Archive warnings, broad non-App-Store suites, Eidos/Spotlight/rescan/manual-
  sync/structural-recovery coverage, bootstrap messages, performance/storage
  soak, distribution, and repeated-zero-fail evidence remain explicit later
  debt. Artifact-gate success is not a warning-free or release-ready verdict.

Exact next action:

1. Keep the sole current archive immutable and do not start another build.
2. Run a fresh complete runtime preflight. Stop before launch if swap used is
   not strictly below 16,384 MiB, free memory is below 25%, throttled pages are
   nonzero, a competing Xcode/compiler/model/Epistemos process exists, the sole
   archive/app identity changed, or the product inventory is no longer exact.
3. If and only if the preflight passes, launch the exact July 14 archive app
   with isolated disposable application-support and vault paths, and run only
   the finite free-V1 runtime matrix serially with correlated logs.
4. Do not access the owner's real vault, private/removable material, account or
   payment state, model/provider/secret paths, or paid June/Browser/ResearchHub
   surfaces. Update the existing evidence document and this handoff, then stop
   after the KEELSTONE verdict. Do not begin canon/feature work or another
   canonical execution key.

All older statements below that say June is currently active, that a model or
provider runtime leg is required for free V1, or that Apple signing is required
before local archive evidence are historical and superseded by this dated
checkpoint.

## Runtime Matrix Verdict Checkpoint — 2026-07-14

This checkpoint is newer than and supersedes the runtime-pending details in the
Current Authoritative Continuation Checkpoint immediately above.

Status: `IN_FLIGHT_RUNTIME_MATRIX_RED_REPAIR_REQUIRED`

Canonical execution key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Exact repository and artifact identity:

- branch `feat/goose-surface`;
- local `HEAD`, fetched `origin/feat/goose-surface`, and handoff publication
  `668b52cfb43721de95db102260d9f327ae24e13e`;
- dirty count 179; preserve all changes;
- sole archive
  `build/archives/Epistemos-FreeV1-runtime-isolation-current-2026-07-14.xcarchive`;
- executable SHA-256
  `468c76dc6fa2e0982af8bed768ce2ea17eecee50d25314003b16fbfca231bda7`;
- deterministic app-tree SHA-256
  `adaded48d7b114d0ea50cd734b4287b222536b0a75ac8968e141d8e942d16608`;
- archive `Info.plist` SHA-256
  `0583481459bbf1613cc3af5ac08f24dc05a1ad1b6665672a884ce4da12d23236`.

Runtime verdict:

`INCOMPLETE — RUNTIME MATRIX RED — NOT RELEASE READY`

The artifact gates remain green, but the finite runtime matrix found:

- visible Companions and stale agent/chat/provenance/Writing Tools surfaces in
  Free V1;
- actual Apple NaturalLanguage `mul_Latn` embedding-model load and
  512-dimensional embedding pushes despite the literal no-AI Free V1 lock;
- eager AVAudioEngine configuration and thousands of microphone-permission
  queries without an explicit Meeting/audio start;
- `/tmp` versus `/private/tmp` vault aliasing that created a nested
  absolute-derived path, containment failures, and failed file-first saves;
- repeated Eidos/index and Epdoc host-Markdown divergence errors;
- non-verbatim Source Markdown and a live CoreEditor-only path below the
  canonical MarkEdit fidelity requirement;
- absent calendar permission/entry contract, unproved Kokoro runtime, a
  roughly 40-second blank-Epdoc interaction delay, Settings inspection hangs,
  negative geometry/lifecycle diagnostics, and about 922 MiB of structured
  logs for this bounded matrix.

Positive boundaries remain exact: no June, cloud-provider request, Browser,
ResearchHub, Kokoro synthesis, HTTP endpoint, owner-vault, private/removable,
payment/account, provider-secret, or Columbia/VA/funding activity was found.
Normal onboarding, disposable-vault restoration, Quick Capture, Meeting
ready-state, HTML preview/export entry points, graph navigation, and Unicode
search produced partial positive evidence, but they do not cancel the red
legs.

The owner's latest Source lock is also durable: Markdown Source and its
preview/“eye” must use MarkEdit's donor typography, geometry, gutter,
scroll/selection behavior, and preview presentation almost verbatim while
retaining the Epistemos palette and owner toolbar. Current source has the full
MarkEdit donor and controller path, but production deliberately passes
`allowsMarkEditWindowToolbar: false` because the full bridge exposes file,
service, and clipboard APIs. The eventual repair must create a restricted
MarkEdit host; it must not merely flip that Boolean or invent a new title
ontology.

Exact stop and resumption boundary:

1. Stop after this final KEELSTONE verdict. Do not begin MAS canon, another
   feature, or another canonical execution key.
2. Keep the current archive immutable. Delete it only immediately before a
   later authorized build under the one-current-build rule.
3. If the owner explicitly resumes this same key, first add failing Free-build
   tests for compiled/visible agent surfaces, NaturalLanguage execution, eager
   audio setup, and microphone polling, then make the smallest repair.
4. Next centralize canonical/symlink-resolved vault-relative containment and
   prove save/relaunch/save without `/tmp` alias corruption.
5. Only after those runtime blockers are green, implement and prove the
   restricted-host near-verbatim MarkEdit Source/Preview contract.
6. Before every future test/build/archive/runtime leg, enforce swap used
   strictly below 16,384 MiB, free memory at least 25%, zero throttling, no
   competing process, and exactly one current product.

The detailed receipts, hashes, screenshot names, log classifications, and
matrix table are in
`docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`.

## Free V1 Compiler And Metadata Repair Checkpoint — 2026-07-14

This checkpoint is newer than the archive/runtime stop boundary immediately
above. It supersedes only the exact product inventory, artifact identity, and
next action; it remains inside the same KEELSTONE execution key and does not
start MarkEdit, Epdoc/PDF, LumenLens, Reckoner, Sync, canon feature work, or a
new key.

Status: `IN_FLIGHT_QUICK_CAPTURE_VOICE_OWNERSHIP_REPAIR_REQUIRED`

Canonical execution key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Repository identity and preservation boundary:

- branch `feat/goose-surface`;
- local HEAD, fetched `origin/feat/goose-surface`, and handoff publication all
  `668b52cfb43721de95db102260d9f327ae24e13e`;
- current `git status --porcelain=v1 -uall` count 313; preserve every owner and
  agent change, and do not reset or overwrite the dirty worktree;
- Free V1 keeps June/chat/agent/provider/general-model/Browser/ResearchHub
  hidden and uncompiled; Kokoro remains the sole bundled/app-owned model
  exception;
- payment, StoreKit enrollment, Apple-account recovery, and distribution
  signing are deferred and do not block source/tests/unsigned local evidence;
- do not inspect accounts, secrets, removable media, or private
  Columbia/VA/funding material.

Proven same-key repairs after the red runtime matrix:

- The whole-file June/QuickChat/Goose/legacy-AgentWorkspace compiler boundary
  is green. The exact App Store Swift input list contains 627 entries and has
  SHA-256
  `f3a5d439f5046a41cce2beae48fa43281818393c7d3d95ece64f2a2ceb84cea8`;
  all 33 mapped paid source files are absent while Kokoro, MarkEdit, visible
  speech, capture, deterministic search, and consent types required by free
  product seams remain.
- The false legacy `INIntentsSupported` array is removed from source and built
  plists. The exact current generated App Intents metadata still proves 13
  deterministic actions, 6 entities, 6 queries, zero enums, four approved
  shortcuts, empty assistant metadata, and none of the four paid/chat intent
  names.
- The privacy-metadata fail-first test recorded four expected source/built
  issues before product correction. The surgical correction changed only
  `Epistemos-AppStore-Info.plist`: the microphone explanation now names only
  explicit Meeting transcription, and
  `NSSpeechRecognitionUsageDescription` is absent.
- The accepted privacy replacement is
  `build/xcode-results/2026-07-14-free-v1-privacy-metadata-green-16gib.xcresult`:
  one passed, zero failed, zero skipped. Its 390530-byte log SHA-256 is
  `b16d9b199ca91772f0050422f702424ba9e509257d108dd567dd11f1b53dbb23`.
- The source audio-input entitlement remains true. The exact runtime still
  links Speech and AVFoundation, uses `SpeechAnalyzer`/`SpeechTranscriber`, and
  exposes no executable `SFSpeechRecognizer` or
  `SFSpeechRecognitionRequest` symbol/string.
- The complete current artifact audit is
  `build/xcode-results/2026-07-14-free-v1-privacy-metadata-green-16gib-artifact-audit.txt`,
  11278 bytes, SHA-256
  `4cc4b915a07dd5ecf38dd47112bdef3cd06cb55f47203eaae5a7652cab72320a`.
- Both MAS canon mirrors are byte-identical across all active numbered docs.
  Their recomputed active-doc digest and manifest value are
  `01f5090d3b7f43293166b9e128e84c3e22643083f6f473395995bc7a6393dc04`.

Current product and resource evidence:

- The prior archive is no longer the current product. The sole current product
  is the unsigned selected-test app at
  `/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`;
  there is no current archive and no `.appex` under the active root.
- Its built Info.plist is 3972 bytes with SHA-256
  `116cfce9887925f097299fc0a7b4854861a0552c6c54f259af10bef16ea84906`.
  The launcher SHA-256 is
  `54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`;
  its Debug runtime dylib SHA-256 is
  `4d4b32eac26ba38e1112890c8391025020a17e1d2b9af788b63bce5127a5709e`.
- The accepted-green preflight recorded 15880.19 MiB swap used, 54% free
  memory, zero throttled pages, and no competing Xcode/compiler/model/
  Epistemos process. The stale red app was deleted before exactly one serial
  replacement selected-test build.
- The test host bootstrapped for the assertion, but there was no normal
  interactive launch, microphone request, audio capture, model/provider load,
  secret access, or owner-vault/removable-media operation.

Remaining blocker and exact next action:

- Meeting is the real current owner-triggered native transcription path.
  Quick Capture's visible Dictate control still reaches fail-closed
  `AudioRecorder`/`AudioTranscriber` stubs in
  `UnavailableAudioCapture.swift`, and Settings overclaims voice support.
- The next action is one fail-first Quick Capture voice-honesty and shared-
  capture ownership boundary. Before wiring the control to
  `LiveVoiceInputService`, add a non-preemptive owner-scoped lease with
  deterministic busy/denied/cancelled states, explicit draft persistence, and
  owner-only stop/teardown; prove Meeting or another Quick Capture cannot be
  stopped, cleared, or stolen. Do not restore `SFSpeechRecognizer`, a
  subprocess, sidecar, local server, or second capture authority.
- If that safe contract cannot be implemented and evidenced within this gate,
  hide or truthfully disable the dead Free V1 control and correct Settings
  rather than shipping an App Completeness overclaim.
- Before any next test/build/archive, re-run the owner preflight: swap used
  strictly below 16,384 MiB, free memory at least 25%, zero throttled pages,
  no competing Xcode/compiler/model/Epistemos process; then delete the current
  app and retain only the one serial replacement product.

Overall verdict remains:

`INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY`

## Historical Program Truth Before Previous-Task Update

The last durable program handoff says KEELSTONE source work is substantially
converged, but exact current-source MAS runtime evidence remains open. The
high-value evidence matrix includes:

- exact MAS/June base-product identity;
- security-scoped vault select, save, quit/reopen restore, and no-loss proof;
- Epdoc open/switch/reopen rich-content fidelity;
- responsive editing and correct graph-to-editor routing;
- audible English Kokoro preview and read-aloud surface proof;
- June native-gateway output or a precise provider/model error;
- current MAS GGUF framework embedding/linkage, receipt, load, cancellation,
  and visible reply proof;
- current archive, release scan, and repeated zero-fail closeout after relevant
  source changes.

The previous task must replace uncertainty with its newer evidence. It must not
silently inherit these as completed.

## Previous-Task Checkpoint

Status: `PUBLISHED_AND_REMOTE_VERIFIED`

Exact feature name:

`KEELSTONE MAS-only base-app and release-gate convergence, owner-steer closeout,
and exact-current-source runtime evidence continuation`

Canonical execution key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Verbatim latest owner steer: preserved in full in the Owner Intent Checkpoint
above.

Interpreted behavior and done bar:

- Publish the exact current branch and a truthful, self-contained checkpoint so
  a new Codex task can resume without hidden task memory.
- Keep MAS-only June as the only active product/agent lane. The historical
  branch name is not authority for Goose or any parked runtime.
- KEELSTONE is complete only after one current-source `Epistemos-AppStore`
  Release archive passes its artifact gates and the finite owner-visible matrix
  proves: vault select/save/relaunch/save; Epdoc rich-content preservation
  through lens switches; writable/responsive Source, Prose, Epdoc, embedded-
  graph, and hologram routes; audible English Kokoro; June local GGUF or an
  exact visible failure; June cloud consent/output or an exact visible failure;
  current distribution/privacy truth; and repeated zero-fail closeout.
- Source parsing, source guards, old archives, and old runtime logs remain
  supporting evidence only. They cannot satisfy current runtime claims.

Why the work remains in flight:

- Source work and the owner-steer closeout are committed, but the exact-current-
  source build/archive/runtime evidence chain has never completed.
- The 2026-07-10 evidence pass stopped before launching any heavyweight work
  because swap was 95.1% occupied.
- `KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md` records SHA
  `0c7123ba442c959b23b87528d3fdff1560320498`, which is not an ancestor of this
  branch. It belongs to a divergent worktree/history and must not be treated as
  current-branch proof. Its methods and failure taxonomy may be reused, but all
  build, artifact, and runtime claims must be regenerated from the verified
  remote branch tip.

Files intentionally modified by this publication task:

- `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`

Files modified but uncommitted at the start of this publication task:

- None. `git status --porcelain=v1 -uall` was empty at
  `38f5dd6a3b022f659c6e5a5b240b6f1b2af200ef`.

Files deliberately not owned by this publication task:

- Every source, test, project, generated-asset, plan, and ledger path outside
  this handoff. No source correction was needed to publish the checkpoint.
- The committed feature surface is broad. Its exact history is authoritative;
  enumerate it with the commands below instead of relying on a lossy prose
  list. High-value current paths include `Epistemos/App/AppBootstrap.swift`,
  `Epistemos/Sync/VaultSyncService.swift`, JuneAgent and QuickChat/GGUF source,
  Kokoro and speech source, graph/editor source, App Store Keelstone tests,
  June substrate tests, and `scripts/keelstone-release-gate.sh`.

Implementation completed and committed before this publication:

- MAS-only surface consolidation and parked-lane removal/quarantine are
  represented by commit `8c46e2b6c` and its descendants on this branch.
- Owner-steer source patches cover editor/graph quiescence and worker bounds,
  Epdoc blank-snapshot and cross-lens reconciliation, clean editor-lease
  transfer, bounded vault-bookmark startup/restore, cancellable English Kokoro,
  bounded June/WebKit/model paths, exact model selection/error propagation,
  and current-source GGUF embedding/linkage gates.
- The July 8 master canon and corrected low-RAM preparation packet are committed
  under `docs/canon/` and `docs/plans/` by
  `38f5dd6a3b022f659c6e5a5b240b6f1b2af200ef`.
- This publication task changed no product source and launched no app, archive,
  model, provider, audio, or owner-vault operation.

Implementation incomplete / verification debt:

- Fresh compilation of the exact remote tip.
- One fresh serial `Epistemos-AppStore` Release archive and artifact gate.
- Vault selection, save, quit/reopen restore, and subsequent save.
- Persisted Epdoc -> Source -> Prose -> Epdoc content/table/formatting fidelity.
- Writable editor lease and typing/load latency for ordinary, embedded-graph,
  and hologram editor routes, including dirty-owner conflict behavior.
- Fresh current-source Kokoro Settings preview/read-aloud, audible English, and
  cancellation/memory reclamation.
- June local GGUF receipt/link/load/token/cancellation/visible-reply evidence.
- June OpenAI/Anthropic consent and either visible output or precise visible
  provider/model error, without reading secrets during preparation.
- Fresh distribution/privacy scan and repeated zero-fail closeout.

Tests, builds, and manual evidence actually performed:

- Earlier owner-steer closeout: focused Swift source/test parsing, shell syntax,
  and the expanded KEELSTONE source gate; the closeout reports 827 passing
  checks and zero swap.
- Earlier retained-artifact scan: finite and red with 12 findings (two GGUF
  embed/link, one parked account/backend marker, seven stale JuneWeb, and two
  privacy-manifest findings). This diagnoses the retained archive only.
- Earlier runtime reconciliation found a retained Kokoro package with 75
  declared files at declared sizes and an older exact-archive playback-
  completion log. No fresh current-source audible check ran.
- This publication pass: repository status/history/ancestry, local and remote
  branch tips, current source/test seams, retained logs, handoff diff,
  `git diff --check`, credential/private-data pattern review, and Git
  connectivity. No Xcode test/build/archive or manual app check ran.

Retained logs and artifacts:

- `docs/plans/keelstone/HANDOFF_OWNER_STEERS_CLOSEOUT_2026_07_10.md`
- `docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`
- `docs/plans/keelstone/INTENT_LEDGER.md`
- `docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md`
- `/tmp/keelstone-source-gate-20260710-*.log` on the original laptop only;
  `/tmp` logs are not durable GitHub assets.
- `/tmp/keelstone-retained-archive-gguf-link-20260710.log` and
  `/tmp/keelstone-retained-app-gate-20260710.log` on the original laptop only.
- `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/runtime-logs/exact-archive-runtime-kokoro-completed.log`
  if still locally retained; it is historical evidence, not current-tip proof.
- Imported canonical and preparation artifacts listed in the read order above.
- External archival receipts and flash-drive locations are recorded in
  `docs/handoffs/EXTERNAL_PLAN_ASSETS_RECOVERY_2026_07_12.md`.

Known failures / blockers:

- Current KEELSTONE verdict is `INCOMPLETE`.
- The latest retained MAS archive is red and physically lacks executable GGUF
  linkage; it is not a valid proxy for current source.
- Owner-observed graph/editor hanging, prior Epdoc loss/formatting risk, local
  June non-output, and voice uncertainty remain open until fresh evidence.
- Heavy verification must wait for a safe memory/swap window. Never run
  competing `xcodebuild` jobs or concurrent model loads.

External or owner-gated requirements:

- A safe resource window and explicit owner permission before any app launch,
  archive, model load, provider request, audio check, or owner-vault mutation.
- Provider/runtime checks must preserve Keychain secrecy and cloud consent.
- Manual evidence must use the exact `Epistemos-AppStore` / `MAS_SANDBOX`
  product, never a legacy or developer target.

Exact next action:

Verify the remote branch tip and a clean worktree, run the mandatory resource
preflight, and--only in a safe/authorized window--resume the finite KEELSTONE
evidence chain from current source. Do not open another source-hardening batch
unless a focused current-tip failure requires a surgical correction. Do not
advance to `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08` until the
KEELSTONE evidence bar is closed.

Exact next commands:

```bash
git fetch origin feat/goose-surface
git switch feat/goose-surface
git pull --ff-only origin feat/goose-surface
git status --short --branch
git rev-parse HEAD
git rev-parse origin/feat/goose-surface
git log -1 --format='%H %s' -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md
git diff --name-only f0f72a21c7c1e405081357154edddaafecd6545b..HEAD
memory_pressure
sysctl vm.swapusage
df -h .
bash -n scripts/keelstone-release-gate.sh
bash scripts/keelstone-release-gate.sh
```

Stop after the resource preflight if pressure/swap is unsafe. The release-gate
script's help/current plan must be consulted before supplying any archive or
runtime arguments; do not invent a target or launch the app merely because the
source-only gate is green.

Commit, branch, and remote verification:

- Branch: `feat/goose-surface`
- Pre-publication remote SHA verified with both the fetched tracking ref and
  `git ls-remote`:
  `38f5dd6a3b022f659c6e5a5b240b6f1b2af200ef`.
- Publication commit: the commit containing this completed checkpoint. Resolve
  it without a self-referential hard-coded hash using
  `git log -1 --format=%H -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`.
- Verified publication remote SHA: the post-push
  `origin/feat/goose-surface` tip. The publishing task must report its literal
  value alongside this handoff after push/fetch verification; local `HEAD`, the
  fetched tracking ref, and `git ls-remote` must all match it.

## Canon-First Reset Continuity Checkpoint — 2026-07-12

This checkpoint is newer than the publication checkpoint above. It updates
recovery truth and the exact resumption boundary; it does not replace or
rewrite canonical Prompt 2.

Canonical authority and current position:

- Sole prompt authority:
  `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/03_MINIMAL_PROMPT_PACK.md`.
- Active numbered prompt: `Prompt 2 - KEELSTONE Storage and MAS Release Gate`.
- Active execution key:
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.
- Do not begin Prompt 3 or recommend another execution key.
- Evidence continuation document:
  `docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`.

Recovery state now proven:

- The full external canon was restored to its original Downloads path from the
  verified flash-drive copy. Recursive comparison passed; it contains 36
  content files and all 18 original source ZIPs.
- The corrected low-RAM preparation folder was restored to its original
  Downloads path. Recursive comparison passed for all nine files.
- The flash drive has two verified complete Git bundles at publication SHA
  `f73b3244c09a76a14961050964969bcb5ac9fa70`, a verified Codex-state backup,
  and the full external plan-assets copy. A new Git bundle must be created
  after this checkpoint's commit is pushed so offline and GitHub tips agree.
- `scripts/resume-keelstone-after-reset.zsh` is the one safe canon-first entry
  point. It restores the two external folders when the flash drive is present,
  verifies canon identity, checks local/origin/live-GitHub/handoff identity,
  reports build prerequisites, applies the owner's resource thresholds, and
  points to canonical Prompt 2 without embedding a replacement prompt.

In-flight source correction preserved by this checkpoint:

- `scripts/keelstone-release-gate.sh` now fails closed on missing or stale
  staged/built JuneWeb and checks that the built MAS app embeds and links
  June's in-process `llama.framework`.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` pins those
  built-artifact checks.
- Shell syntax, Swift parsing, diff checks, and the focused static gate contract
  pass. With the stage absent, the gate is correctly red on exactly the missing
  staged index and shim. This is source/static evidence only.

Files owned by this continuity checkpoint:

- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
- `docs/handoffs/EXTERNAL_PLAN_ASSETS_RECOVERY_2026_07_12.md`
- `docs/plans/keelstone/INTENT_LEDGER.md`
- `docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md`
- `scripts/create-epistemos-codex-restore-backup.zsh`
- `scripts/keelstone-release-gate.sh`
- `scripts/restore-epistemos-codex-on-new-mac.command`
- `scripts/resume-keelstone-after-reset.zsh`

Current environment blockers and verification debt:

- Rust (`cargo`/`rustc`) is absent. The focused Xcode test cannot reach its
  assertion until the Rust build phase can run.
- Bun is absent.
- The App Store signing identity/profile is absent. The signed focused test
  stopped at provisioning; the unsigned retry stopped at Rust.
- `.june-web-stage` is absent.
- The owner-modified June donor checkout is absent. Its durable public base is
  `https://github.com/BlickandMorty/os-june.git`, branch
  `epistemos-vendor`, but the recorded local commit
  `7105c43c8622cc546075f7ff1e20680e2009f8bb` and its 92-file dirty overlay
  were never pushed and must not be invented. The private Codex-state backup
  retains the exact recorded patch evidence.
- The last reviewed July 10 stage is recoverable only when reconstruction
  matches all three hash oracles: main asset
  `9d38c92dea2a70bf15e88741c47ea9833da3fee8ecfc053fd593f4befc8a1144`,
  index `30790bb4f65afaf93dd9db5bd4fc9ec396708d4f22f7cb881a24c0cbeec2c00e`,
  and shim `7440986d70a044689fea50f8a181441dfc05c5b8736421691db8b2980979e77a`.
  A source tree or stage that does not match must be reviewed as new evidence.
- No fresh current-tip test, Release archive, app launch, model load, provider
  request, Keychain secret read, owner-vault mutation, audio operation, or
  runtime matrix was completed in this continuity pass.

Exact next action after reset:

1. Run `scripts/resume-keelstone-after-reset.zsh` from the verified branch.
2. If it reports a fatal identity mismatch, stop without resetting or
   overwriting anything.
3. Restore Rust, Bun, Apple signing, and an exact reviewed JuneWeb stage/donor.
4. Re-run the script. The owner's 2026-07-14 superseding mandatory threshold is
   swap used strictly below 16 GiB (16,384 MiB), at least 25% free memory, zero
   pages throttled, and no competing
   Xcode/compiler/model/Epistemos process.
5. Only when identity, prerequisites, and safety are green: run the narrow
   serial compile/regression batch, produce exactly one
   `Epistemos-AppStore` Release archive, run every artifact gate, then run the
   finite correlated runtime matrix. Update the existing exact-runtime evidence
   document and stop after the final KEELSTONE verdict.

Publication and offline outcome:

- The continuity implementation is committed locally as
  `06ef0e3a1acd7c62670e29ce85ab0a51c1ba8e33`.
- GitHub publication is not yet complete. The HTTPS push failed because this
  reset Mac has no GitHub credential, GitHub CLI, or SSH key; the in-app browser
  is also signed out. No credential was inspected, created, or transmitted.
- Live `origin/feat/goose-surface` remains
  `f73b3244c09a76a14961050964969bcb5ac9fa70`. Local history is ahead and must
  not be described as remote-protected until an authenticated push and fetch
  prove equality.
- The flash drive contains a checksum-verified, complete-history bundle named
  from the current local checkpoint:
  `/Volumes/treasure/Epistemos-InFlight-Resume-2026-07-12-<short-sha>/`.
  Its `READ_FIRST.md` records the literal bundled SHA and authenticated push
  procedure. This is the authoritative fallback if the laptop is reset before
  GitHub authentication is restored.
- On an authenticated machine, clone or fetch that latest bundle, push
  `feat/goose-surface` to `https://github.com/BlickandMorty/Epistemos`, fetch it
  again, and run the reset/resume entry point. Do not force-push or overwrite a
  divergent remote; stop and inspect any mismatch.

## Prompt To Paste Into The Previous Codex Task

```text
Publish a durable cross-laptop handoff for the exact Epistemos feature you are
currently implementing. Do not start a new feature and do not summarize from
memory alone.

Repository: /Users/jojo/Downloads/Epistemos
Durable handoff:
docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md

First read AGENTS.md, the current feature prompt/plan and its intent/evidence
ledgers, docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md, and the entire
existing durable handoff. Also read the imported master canon at
docs/canon/epistemos_mas_master_canon_2026_07_08/00_READ_FIRST.md and the
low-RAM correction log at
docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/PREPARATION_PACKET_CORRECTION_LOG.md.
Inspect the current source, git status, diff, recent commits, tests, logs, and
artifacts before writing.

Update only the Previous-Task Checkpoint and any immediately necessary read
order/status text in the durable handoff. Preserve my latest owner wording
verbatim. Record the exact feature/canonical execution key, interpreted done
bar, modified files, completed and incomplete behavior, tests actually run,
retained evidence, failures, verification debt, owner/external gates, and the
exact next commands. Distinguish source-patched, build-proven, and manually
witnessed behavior. Do not mark untested behavior complete.

The active product is the MAS-only free V1 edition. June is retained only as
the future paid agent; June, generative/model/agent surfaces, Browser, and
ResearchHub must remain hidden and inert in free V1. The current canonical
execution sequence uses the full July 8 IDs. Do not revive Goose, Pro,
Experimental, 1Code, OpenChamber, subprocess, local-server, Node, terminal,
stdio-MCP, or browser-use lanes. The historical branch name
feat/goose-surface is not product authority.

Before committing, inspect the diff and search for contradictions, stale
directives, credentials, personal data, Columbia/VA/financial data, absolute
secret paths, tokens, and generated/build output. Never use git add -A or git
add . Stage only the handoff plus exact feature files that you own and that are
needed to preserve the in-flight implementation. Do not revert or absorb
unrelated user/agent changes. Run the narrowest relevant checks, then any safe
broader source guards required by the feature. Record every deferred runtime or
heavy verification item honestly.

Commit the handoff and the exact in-flight feature work to the current branch,
push that branch to origin, fetch the remote, and verify the remote SHA equals
the local SHA. If a safe commit is impossible because ownership is mixed,
commit and push the handoff alone, list every uncommitted feature path and why
it remains local, and do not claim the code is protected by GitHub.

Finish by reporting:
1. local commit SHA;
2. remote branch and remote SHA;
3. exact files committed;
4. exact files still uncommitted;
5. verification run and remaining debt;
6. the exact New-Laptop Resume Prompt from the durable handoff.
```

## New-Laptop Resume Prompt

```text
Resume the exact in-flight Epistemos feature from its durable GitHub handoff.
Do not begin implementation until you have grounded yourself in current source
and verified the external canon and remote state. This is a bootstrap prompt,
not a replacement execution prompt.

1. Clone or open https://github.com/BlickandMorty/Epistemos.
2. Fetch origin and switch to the branch recorded in
   docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md. Pull with --ff-only.
3. Connect the flash drive if available and run
   scripts/resume-keelstone-after-reset.zsh. It must restore/verify
   /Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08 and the corrected
   preparation folder. If it reports a fatal identity mismatch, stop without
   resetting or overwriting anything.
4. Read the external canon's 00_READ_FIRST.md, 01, 02, numbered
   03_MINIMAL_PROMPT_PACK.md, and dated free-V1 addendum
   11_FREE_V1_EPDOC_PLANNER_AND_CAPABILITY_RING_2026_07_13.md first. The
   external numbered prompt pack controls execution order; the dated addendum
   controls the newer free/paid product boundary. Then read AGENTS.md,
   docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md, the low-RAM correction
   log, current KEELSTONE prompt/plan and intent/evidence ledgers, and this
   handoff in its entirety. Handoffs and preparation are evidence only; do not
   create a custom Prompt A/B/C/D chain or replace canonical Prompt 2.
5. Run the following and verify its result equals local `HEAD`,
   `origin/feat/goose-surface`, and the publication SHA supplied with this
   handoff. If any differ, stop and explain the mismatch without resetting or
   overwriting anything:

   `git log -1 --format=%H -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
6. Inspect git status, the recorded feature files, nearby contracts/call sites,
   tests, retained logs/artifacts, and the diff from the handoff baseline.
7. Restate the exact owner intent, canonical execution key, hard constraints,
   done bar, proven state, verification debt, and exact next action before
   editing.
8. Continue only canonical Prompt 2,
   EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08, from the recorded resource
   preflight boundary. Restore only the reported free-V1 prerequisites first;
   Bun, June donor/assets, payment, StoreKit, and Apple distribution signing
   are future-paid/distribution status and do not block free-V1 source or local
   ad-hoc evidence. Preserve MAS-only architecture, keep June/Browser/
   ResearchHub paid-only and hidden/inert, use surgical edits, and do not claim
   runtime behavior without current exact evidence. If the sole current archive
   is retained and unchanged, do not rebuild it. When the Mac is unlocked,
   repeat the resource preflight and complete only the finite non-AI runtime
   matrix with correlated logs. Do not begin Prompt 3 or another execution key.

Private Columbia/VA/funding work is not stored in this repository and must not
be inferred from this handoff.
```

## Handoff Acceptance Checks

- [x] Previous-Task Checkpoint no longer says `AWAITING_PREVIOUS_TASK_UPDATE`.
- [x] Exact feature files are committed, or every local-only path is listed.
- [x] No unrelated files were staged or reverted.
- [x] No credential, personal, Columbia, VA, or financial data was committed.
- [x] Narrow checks and verification debt are recorded.
- [ ] Local continuity commits are pushed and the remote SHA is verified.
      GitHub remains at `f73b3244c09a76a14961050964969bcb5ac9fa70`;
      the checksum-verified flash bundle is the newer offline authority until
      authenticated fast-forward publication succeeds.
- [x] New-laptop prompt names the actual remote branch and gives a deterministic
      publication-SHA verification command.

## Final Treasure-Drive Audit And Cleanup Checkpoint — 2026-07-12

Owner-authorized scope:

- Keep one unambiguous Epistemos continuation set and remove superseded
  recovery duplicates created by this continuity work.
- Remove the explicit Columbia transfer bundle and its temporary staging
  material because the owner reports that work is retained on another laptop.
- Preserve unrelated research/personal files and ambiguous root-level source
  documents rather than interpreting broad cleanup as permission to delete
  them.

Recovery evidence established before cleanup:

- The 123 GB `treasure` ExFAT volume had 47.2 GB free before cleanup. Its FSKit
  ExFAT check completed successfully; SMART is not supported by the device.
- The 56 GB full APFS sparse-image verifier passed its SHA-256, image/container,
  APFS volume, read-only mount, critical Codex paths, exact Git snapshot,
  worktree, Xcode scheme count, and SQLite snapshot checks.
- The independent 9.7 GB Codex-state archive passed its SHA-256, gzip, and tar
  structure checks.
- All four pre-cleanup Git bundles passed their manifests and `git bundle
  verify`, recorded complete history, and listed the expected
  `feat/goose-surface` tip. The newest `e3903b1af...` bundle additionally
  cloned, passed `git fsck --full --strict`, matched the handoff commit, and
  accepted its recorded uncommitted intent-ledger patch with `git apply
  --check`.
- The external master canon and corrected preparation packet recursively
  matched their restored Downloads copies; the historical canon ZIP tested
  clean. The incremental Codex thread checkpoint and all recovery-script
  syntax checks passed.
- The reset/resume drill failed closed on exactly one fatal condition: local
  and handoff `e3903b1af...` versus live/origin
  `f73b3244c09...`. It separately reported Rust, Bun, the reviewed June stage,
  the unpushed June donor overlay, and Apple signing as prerequisites.

Final retained recovery shape:

- Preserve the verified full restore kit, independent Codex-state archive,
  complete external canon/preparation assets, one final complete-history Git
  bundle, one final current-thread checkpoint, root read-first/checksum/restore/
  publication helpers, and the GitHub Desktop installer while authentication
  remains unavailable.
- Superseded Git bundles and thread checkpoints are removable only after their
  final replacements pass checksum, strict clone/fsck, handoff identity, and
  restore-entry checks.
- Private Columbia/VA/funding work remains outside the public repository. The
  authorized flash-drive transfer copy may be deleted, but no such material is
  imported or inferred here.

Current continuation boundary remains unchanged:

- Prompt authority: external July 8 master canon
  `03_MINIMAL_PROMPT_PACK.md`.
- Active prompt/key: Prompt 2 only,
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.
- GitHub publication, Rust, Bun, reviewed JuneWeb bytes, the exact June donor
  overlay, Apple signing, fresh archive/artifact gates, and the finite runtime
  matrix remain open. Do not begin Prompt 3.

Forced-shutdown recovery update:

- The owner force-powered off the laptop while macOS's ExFAT service had stuck
  read requests. On the fresh boot, treasure volume UUID
  `FC33F188-7A19-33E7-BCF7-65496C19C7DC` passed
  `fsck_exfat -n -x` with exit code zero and the previously stuck recovery
  helper files read normally.
- Volatile final-pack staging under `/tmp` did not survive, as expected. The
  final Git bundle and incremental thread checkpoint must be regenerated from
  this newer committed handoff before superseded drive packs are deleted.
- The only post-reboot worktree delta removed three indirect SwiftPM pins from
  `Package.resolved`. The prior verification ledger already identifies this
  exact file as package-resolution tool drift restored after inspection. The
  committed pin set was restored surgically; no product source changed.
- Current resource threshold is safe: zero swap, 87% free memory, zero
  throttled pages, 777 GiB internal free space, and no competing build,
  compiler, model, or Epistemos process. Build execution remains blocked until
  the separately required Rust, Bun, JuneWeb/donor, and Apple-signing checks
  are current and green.

## Post-Reset Prompt 2 Continuation Checkpoint — 2026-07-12

This checkpoint supersedes only the stale prerequisite/status statements above;
it does not replace the external master canon or begin a new execution key.

- Canon authority remains the external July 8 master canon and numbered
  `03_MINIMAL_PROMPT_PACK.md`; active key remains
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` (Prompt 2 only).
- Rust, Bun, the Metal Toolchain, the June donor reconstruction, and a current
  28-file `.june-web-stage` are now present. The recovered shim matches the
  historical SHA-256 oracle exactly; the current main/index outputs are new
  evidence and do not match the old generated-artifact oracles.
- The restored App Store target compiles. The final exact-state unsigned Debug
  run passed all 71 KEELSTONE tests in 2 suites with zero failures. The source
  gate passed 49 checks. This proves compilation and focused regressions only.
- Exactly one current app product remains at
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app`.
  It is an unsigned XCTest-bearing Debug product, not Release evidence.
- Durable owner rule: before every future Epistemos build, test build, or
  archive, stop prior test hosts and delete all stale Epistemos app/archive
  products. Retain and identify only the one artifact produced by the active
  evidence leg. This rule is also in root `AGENTS.md`, `CLAUDE.md`, and the
  KEELSTONE intent ledger.
- Xcode GUI-created scheme drift and SwiftPM pin drift were inspected and
  restored to the committed files after the final test. Xcode is closed.
- Release/archive progression is blocked by zero Apple code-signing identities
  and no provisioning-profile directory. After the restart, GitHub CLI
  authentication for `BlickandMorty` is available again. The final continuity
  commit containing this checkpoint must be pushed only as a normal
  fast-forward, fetched again, and compared with live GitHub; never force-push
  over a divergence.
- No signed Release archive, archive artifact-gate pass, owner-visible runtime
  matrix, model load, provider request, Keychain-secret read, owner-vault
  operation, or audio operation is claimed.

Exact next action:

1. Publish this final continuity checkpoint through the authenticated normal
   fast-forward path, fetch it again, and verify local/tracking/live identity.
2. When the owner is present, connect the Apple Developer/Xcode signing account
   without exposing credentials.
3. Re-run the owner's resource preflight.
4. Delete the surviving Debug app and every stale Epistemos archive.
5. Produce exactly one signed `Epistemos-AppStore` Release archive and run all
   artifact gates against that exact archive.
6. Launch only if every artifact gate passes, then run the finite runtime matrix
   serially and update the existing evidence document.
7. Stop after the final KEELSTONE verdict. Do not begin Prompt 3.

## Post-Restart Setup And Evidence Finalization — 2026-07-12

- The external owner-attached master canon is present with 36 files: all 18
  active/provenance files plus all 18 original source ZIPs. Every ZIP matches
  its recorded byte size and SHA-256 and passes ZIP integrity. All nine
  corrected low-RAM preparation files match the repository import exactly.
- The sole byte difference between the external canon's active content and the
  repository import is two removed trailing spaces in the blank-list template
  inside `10_LOCAL_AGENT_REDIRECT_AND_STATUS_TEMPLATES.md`; there is no content
  difference. The external folder and numbered `03_MINIMAL_PROMPT_PACK.md`
  remain authority.
- The recovered June donor is clean at
  `adffe8fdc6ed8da868b705ed37ace96ff182d314`. The current 28-file June stage
  hashes are now pinned by the reset/resume helper as current post-reset
  evidence; they are not mislabeled as the older July 10 generated bytes.
- The exact final Xcode `.xcresult` survived in DerivedData and was moved into a
  checksum-verified durable archive under
  `/Users/jojo/Downloads/Epistemos-Aftercare-Local-2026-07-12/keelstone-evidence-32d5d264e/`.
  Its extracted summary reports 71 passed, zero failed, zero skipped. A fresh
  no-build source-only gate log in the same folder reports 49 passes.
- The Treasure drive was synced, passed post-write ExFAT verification with exit
  zero, and was software-ejected. Its current complete-history recovery pack
  preserves Epistemos `32d5d264...` and June `adffe8fd...`; GitHub publication
  of this newer handoff commit becomes the primary continuity authority after
  the required post-push identity check.
- Exactly one unsigned Debug `Epistemos.app` remains and no Epistemos archive
  exists. Before the signed Release leg, delete that app and every stale
  archive, then retain exactly one newly produced Release artifact.

The final continuity publication commit is the commit containing this section.
Resolve it with:

`git log -1 --format=%H -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`

After authenticated push/fetch, local `HEAD`, `origin/feat/goose-surface`, live
GitHub, and that resolved handoff commit must match exactly. The only remaining
owner-account gate is Apple signing. KEELSTONE remains `INCOMPLETE`; do not
begin Prompt 3.

## Same-Key Quick Capture Ownership Repair Checkpoint — 2026-07-14

This section supersedes the older “exact next action” statements above. It
does not replace the external July 8 master canon and does not begin Prompt 3.

### Exact continuity identity

- Branch: `feat/goose-surface`.
- Local `HEAD`, `origin/feat/goose-surface`, and this handoff's last published
  commit all resolve to
  `668b52cfb43721de95db102260d9f327ae24e13e`.
- Canonical execution key remains
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.
- The worktree remains intentionally dirty with the owner's broader in-flight
  work. Do not reset, overwrite, discard, or stage unrelated changes.

### Retained expected-red evidence

- Fail-first test:
  `AppStoreKeelstoneLaneTests.freeV1QuickCaptureDictationUsesScopedNativeVoiceCapture()`.
- Result:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-lease-red-16gib.xcresult`;
  one test, zero passed, one failed, 13 intended contract issues.
- Log:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-lease-red-16gib.log`;
  698805 bytes, SHA-256
  `31f20c29a1d92fa03a83b38a7e983d370b1007b69c3d05cc49ad086c4c15c559`.
- The sole retained app is the stale pre-implementation red artifact at
  `/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`.
  It is not evidence for current source and must be deleted only immediately
  before the one replacement build. No active Epistemos archive exists.

### In-flight source shape — not yet compiled or behavior-proven

- `LiveVoiceInputService` now carries capture purpose, exact-owner leases, a
  single registry, typed admission results, scoped start/stop/teardown/consume,
  and explicit partial promotion.
- `EpistemosSpeechAnalyzer` now carries a distinct session ID across every
  asynchronous start edge, result/progress task, termination/configuration/
  permission callback, rearm path, and scoped teardown.
- `VoiceInputButton` now retains its lease in SwiftUI state and drains only its
  own transcript. Quick Capture uses that shared public native route rather
  than its fail-closed recorder/transcriber stubs.
- Meeting uses a per-attempt lease and the cached utility-panel close signal is
  panel-specific, so it cannot stop the separately embedded Meeting surface.
- The microphone purpose now names explicit Meeting transcription and Quick
  Capture Dictate; the obsolete speech-recognition purpose key remains absent.
- Related source guards, fakes, and a pure lease-registry test were migrated.

No Swift parse, compile, replacement test/build, normal app launch,
microphone/audio operation, model load, provider request, signing/account
operation, secret access, removable-media access, or private-data access has
proved this source shape.

### Resource observation and latest owner override

The first post-edit preflight observed 17163.44 MiB swap used, 63–64% free
memory, zero throttled pages, 520385952 KiB available disk, and no competing
Xcode/compiler/model/Epistemos process. Work initially stopped because swap was
779.44 MiB above the then-active strict 16-GiB ceiling.

The owner's newer explicit steer is: “please jsut contieu do nto worry about
the limit stop worry about the limit do not stop”. Therefore swap remains a
recorded diagnostic but is no longer a stop condition for this continuation.
The one-current-build rule, serial execution, no competing process, sufficient
disk, zero throttled pages, and honest evidence requirements remain active.

### Verification debt and exact continuation boundary

1. Re-read the changed regions. Fix the known Meeting close-durability order:
   scoped stop, owner-drain the promoted last partial, record it as final,
   flush the crash-recovery draft, then scoped teardown.
2. Add deterministic coverage for typed denial/cancellation, close while
   preparing, non-owner stop/consume/teardown, stale analyzer termination, and
   Meeting-versus-Quick-Capture non-preemption.
3. Add crash-safe Quick Capture draft restoration before any zero-loss claim.
4. Run plist lint, Swift parse, focused source guards, and diff checks. Record
   swap/memory/disk/process observations without stopping for swap alone.
5. Immediately before the replacement build, stop any prior test host and
   delete all stale Epistemos app/archive products. Run exactly one serial
   focused batch for Quick Capture, privacy, lease-registry, Meeting, and voice
   regressions.
6. Audit the exact replacement app's privacy metadata, entitlement, App
   Intents inventory, linked/symbol surface, product count, path, hashes, and
   result/log identities before any runtime launch.
7. Update the existing evidence, intent, and handoff documents. Overall
   KEELSTONE remains `INCOMPLETE` and not release ready until later artifact,
   finite-runtime, distribution, and repeated-zero-fail evidence passes.

The broader App Intents/Shortcuts, Spotlight, widgets, Calendar/Reminders,
accessibility, rich ep.doc media, PDF, sharing, notification, and performance
program remains queued behind this repair. Missing paid signing blocks exact
signed-entitlement, installed-system/TCC, and distribution proof; it does not
block source work, deterministic tests, unsigned builds, editor/PDF work, or
performance hardening. Do not start a new execution key until the current
KEELSTONE verdict is recorded.

## Same-Key Quick Capture Compile-Repair Checkpoint — 2026-07-14

This section supersedes the immediately preceding continuation boundary where
it differs. It does not begin Prompt 3 and does not reopen MAS canon feature
work.

### Continuity identity

- Branch: `feat/goose-surface`.
- HEAD during this checkpoint:
  `668b52cfb43721de95db102260d9f327ae24e13e`.
- Canonical execution key:
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.
- Worktree remains intentionally dirty; do not reset, discard, or overwrite
  owner/in-flight changes.

### Owner intent and current constraints

- Free V1 keeps all AI/chat/browser/ResearchHub/June/model/provider surfaces
  hidden/not compiled, except Kokoro voice remains retained.
- One-current-build rule remains active before any build/test/archive: stop
  prior Epistemos/Xcode test hosts and delete stale Epistemos app/archive
  products from the active build location.
- Resource preflight remains active. Current retained ceiling is swap strictly
  below 16 GiB, free memory at least 25%, pages throttled zero, and no
  competing Xcode/compiler/model/Epistemos runtime.
- Do not claim runtime behavior without current exact evidence.

### Source repair made

The R6 focused build stopped before tests because Free V1 `InferenceState`
lacked the paid-lane contract property used by
`AgentCommandCenterState.refreshBrainCatalog(from:)`:

`Value of type 'InferenceState' has no member 'configuredCloudProviders'`

Surgical repair applied:

- `Epistemos/State/InferenceState.swift`
  - added Free V1 neutral provider-list property:
    `var configuredCloudProviders: [CloudModelProvider] { [] }`.

This admits zero cloud providers and preserves the Free V1 no-provider policy.
`git diff --check` passed.

### Verification state

- R6: real source compile failure from missing `configuredCloudProviders`;
  repaired by the source change above.
- R7/R8: foreground reruns progressed past the R6 compile error but ended
  `BUILD INTERRUPTED` / rc `143`; no tests ran; `.xcresult` bundles incomplete.
- R11: invalid because its preflight recorded a competing
  `/private/tmp/Epistemos-FreeV1-InferenceState-R26` Xcode build. R11 and R26
  were stopped.
- R12: uncontaminated `tmux` run after clearing competing build and children.
  It reached package/app build, Rust/JS bundle, resource, asset catalog, and
  Metal compilation, then ended `BUILD INTERRUPTED` / rc `143` before tests.
  No source error was captured and no tests ran. Post-interrupt resources were
  healthy; orphaned `ibtoold` helpers were cleared.

Durable evidence was appended to:

`docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`

with hashes for R6/R7/R8/R11/R12 logs and preflights.

### Exact next action

1. Do not begin MAS canon, paid feature work, archive, or runtime matrix yet.
2. Confirm no R26/R11/R12 or other Xcode/compiler/bundle child remains active.
3. Delete stale Epistemos app/archive products from the active build location.
4. Re-run the same focused Quick Capture/Privacy/Voice batch using one current
   build lane. Prefer `tmux`; if rc `143` repeats with no Swift/source error,
   switch to a lower-concurrency diagnostic run (`-jobs 1`) or split into a
   build-only proof leg before tests, and record it as an execution-environment
   failure until a real source/test verdict exists.
5. Only after the focused batch reaches a valid green/red test result should
   artifact gates, archive, finite runtime matrix, or broader editor/MAS-canon
   work resume.
## Same-Key R13-R16 Focused Compile Checkpoint — 2026-07-14

Continue the same key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

No MAS canon, paid feature work, archive, runtime matrix, app launch, model
load, provider request, secret access, or audio operation began.

### Source repairs now present

- `Epistemos/State/InferenceState.swift`
  - Free V1 `configuredCloudProviders` returns `[]`.
- `Epistemos/State/AgentCommandCenterState.swift`
  - Free V1 `ACCBrainSelection.supportedNativeProviderEfforts` returns `[]`
    before referencing paid provider cases.

Both repairs preserve the owner's Free V1 policy: no cloud providers are
admitted.

### Verification state

- R13: valid focused `-jobs 1` build leg; stopped with rc `65` on
  `CloudModelProvider` missing `.anthropic` under Free V1. Repaired by the
  `AgentCommandCenterState.swift` conditional above.
- R14: invalid; first preflight caught a competing
  `/private/tmp/Epistemos-FreeV1-InferenceState-R25` build, then a background
  launch produced a zero-byte log/no done marker.
- R15: invalid; started after clean preflight but a new
  `InferenceState-R25/R29` build spawned after preflight, contaminating the
  run. R15 and R29 were stopped.
- R16: valid preflight and `tmux` launch; reached package compilation and the
  `Build Rust Engine` phase, then ended `** BUILD INTERRUPTED **`. No source
  error, no tests, and the `.xcresult` bundle is incomplete/corrupt.

Retained hashes:

- R13 preflight:
  `afc0fef72e2fae060f9afb56d224aa87d2921d22f93942a3ef91b91edc01e226`
- R13 log:
  `81ba6c5c56c8e2e73df6af827765af1572c7173e1e29ef6cb736f702e54c5d9c`
- R14 preflight:
  `6bc4b4639c16cbd4231d7e2617c2037e94f218e8ec5dea675f36e7f81437e37b`
- R15 preflight:
  `d3db1029cb63f90bb9dc9c7cf37398a97fcd27159cb466c7b3b9eb4d4f6a21af`
- R15 log:
  `ff92290a0679555d84c1dcf0bae3677a792871d1e0a16fca3046c4c50844ccd3`
- R16 preflight:
  `396a224abca1bf50b92279c9cfa7a781da3a6f4d495a3716df12d95e5b8ecf29`
- R16 log:
  `b78abd8033ca39ba440e4f173625bcffe23410c8e3c063720730ec21b80d33d6`
- R16 stale-product log:
  `7c030d59e4df8698fff6b4eb72f446c7520adbdd2b8de6c373601bd8d4aedef2`

### Current verdict

**INCOMPLETE.** The focused Quick Capture/Privacy/Voice batch still has no
valid green/red test result. R16 is the latest usable boundary and stopped by
execution interruption before tests, not by a source compile error.

### Exact next action

1. Do not begin MAS canon, archive, runtime matrix, or paid feature work.
2. Confirm no R14/R15/R16/R25/R29 Xcode/compiler child remains.
3. Delete stale Epistemos app/archive products from the active build location.
4. Re-run the same focused batch only after a fresh resource preflight. If the
   same `BUILD INTERRUPTED` condition repeats with no source error, stop and
   isolate the execution/build-script interruption before further test claims.

## Same-Key R18 Build-Phase Isolation Checkpoint — 2026-07-14

Continue the same key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

R18 isolated the Xcode `Build Rust Engine` phase by running the Free V1 script
subset directly:

- `build-rust.sh`
- `build-syntax-core.sh`
- `MAS_SANDBOX=1 build-epistemos-core.sh`
- `build-epistemos-shadow.sh`
- `build-epistemos-code-index.sh`
- `build-substrate-rt.sh`
- `build-tiptap-bundle.sh`
- `build-coreeditor-bundle.sh`

Result: `rc=0`. This was not a Swift test pass and not runtime evidence. It
only proves the standalone Free V1 build-phase script chain completed after
R16's Xcode-session interruption.

Retained hashes:

- R18 preflight:
  `6f351ee47457e980f3ade2306e29d2673ed67c49f4c36d7e10ae928b87526e1f`
- R18 log:
  `22de66e46992379a1ea7baae9e9b4ee4a8159e143fff7f224cd6582cd6c8ecb6`

### Current verdict

**INCOMPLETE.** The focused Quick Capture/Privacy/Voice batch still has no
valid green/red test result.

### Exact next action

1. Confirm R18 left no active compiler/build children.
2. Delete stale Epistemos app/archive products from the active build location.
3. Run a fresh resource preflight.
4. If thresholds pass, re-run the same focused Quick Capture/Privacy/Voice
   batch as the next evidence leg.

## Same-Key R19 Focused Retry Contamination Checkpoint — 2026-07-14/15

Continue the same key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

R19 had a passing resource preflight, cleaned stale Quick Capture products,
and started the same focused Quick Capture/Privacy/Voice Xcode test batch in
`tmux` with `-jobs 1`.

After launch, an unrelated stale Codex-app-server child spawned a competing
Free V1 build at:

`/private/tmp/Epistemos-FreeV1-InferenceState-R25`

The competing command used:

`RUN_TAG="2026-07-14-free-v1-runtime-state-r33"`

R19 was stopped as contaminated. It has no valid focused test result and no
done marker.

Retained hashes:

- R19 preflight:
  `794d7daf4fcbfddd968637560c0a75ae7c9727148770c70e0c59cbf242c42952`
- R19 stale cleanup:
  `a28e29e8af6574e1783aae72933685904a72a9ebebbfcb1f436a29a6852faffa`
- R19 partial log:
  `eb72a589c5e23b1cda1ce8abd428a8dd553ae467b583429f0ab86806920b4919`
- Stale `runtime-state-r33` log:
  `9419eb2fc797201d6073b799ca3238492a3652632d1143b8f408e47e476cb93b`

### Current verdict

**INCOMPLETE.** The focused batch still has no green/red result.

### Exact next action

1. Confirm no R19/R25/R33 Xcode/compiler children remain.
2. Run one short no-build-process watch before retry.
3. If clean, fresh preflight and retry the same focused batch once.
4. If R25/R33 respawns again, stop and treat the ghost build source as the
   blocker before further Xcode evidence attempts.

## Same-Key R20 Prewatch Blocker Checkpoint — 2026-07-14/15

Continue the same key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

R20 did not launch another focused test build. It ran the required quiet-watch
after R19 contamination. The watch immediately found another stale
Codex-app-server build at:

`/private/tmp/Epistemos-FreeV1-InferenceState-R25`

The competing command used:

`RUN_TAG="2026-07-14-free-v1-runtime-state-r34"`

This repeated the R19 `runtime-state-r33` contamination pattern. R34 was
terminated. A final process check found no active R19/R25/R33/R34
Xcode/compiler/Cargo/Epistemos child process, and `git diff --check` passed.

Retained hashes:

- R20 prewatch:
  `fa19e5d12951fa552ed92602528f6d5f051602b9bbc4fc740df1561596cd0358`
- Stale `runtime-state-r34` log:
  `4cb4b4cb7dcdb6c970f2f148d7108aa1f65ca2c8fac81055ccb855bde744935a`

### Current verdict

**INCOMPLETE / BLOCKED BY REPEATING GHOST BUILD.** The focused Quick
Capture/Privacy/Voice batch still has no valid green/red result.

### Exact safe resumption boundary

1. Do not start another Xcode build/test/archive until the stale
   Codex-app-server `runtime-state-r33/r34` build source is gone.
2. Before retry, run a clean no-build-process watch.
3. Then fresh resource preflight, stale-product cleanup, and the same focused
   Quick Capture/Privacy/Voice batch.
4. Do not begin MAS canon, paid features, archive, runtime matrix, app launch,
   model load, provider request, secret access, or audio operation before the
   focused batch has a valid green/red result or the owner explicitly redirects.
