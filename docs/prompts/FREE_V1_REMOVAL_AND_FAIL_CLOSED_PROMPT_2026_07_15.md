# Epistemos Free V1 Removal and Fail-Closed Execution Prompt

Task ID: `EPISTEMOS-FREE-V1-REMOVAL-LANE-R-2026-07-15`
Canonical execution key: `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`
Role: Lane R, sole removal/fail-closed edit owner
Execution order: current first session; Lane B is not active

Execute this prompt. Do not stop after producing another plan.

## Live coordinator refresh and delivery contract

This file is live, coordinator-owned execution input. The Lane R worker must
not edit it. Goal continuation, context reload, or compaction does not by
itself guarantee that changed file contents enter the worker's context.

At the start of every goal turn or automatic continuation, after every resume,
reload, or compaction, before each new implementation batch, and before each
`deep-hardening-loop` cycle:

1. Re-read this entire file from its absolute path on disk and run
   `shasum -a 256` on it. Record the hash, local timestamp, and whether it
   changed in the Lane R scoped ledger.
2. If the hash changed, stop before the next source edit. Add the changed owner
   wording or exact excerpt to the ledger's intent checkpoint, reconcile the
   implementation order, ownership boundaries, acceptance tests, and
   verification debt, then continue from the updated contract.
3. Treat a live addition as executable Lane R scope only when it is grounded
   in current canon/source evidence and remains inside the ownership boundary
   below. If it conflicts with owner intent, canon, an existing constraint, or
   Lane B ownership, record the contradiction and stop for owner/coordinator
   direction; do not guess and do not cross the lane.
4. If the file cannot be read completely or its hash cannot be recorded, fail
   closed: make no further source edit until refresh succeeds.

The coordinator may append versioned live additions while Lane R is active.
Each addition must identify the evidence, affected seam, required removal or
hardening behavior, intended proof, and ownership disposition. If an addition
applies to a phase already implemented, handle it in the next hardening cycle.
A prompt update never silently authorizes Lane B, Settings edits, Xcode/app
execution, commits, or a release claim. A later numbered live addition may
explicitly override a named boundary: addition 054 authorizes batched build/test
verification, and addition 055 authorizes the verified checkpoint commit and
automatic successor rebuild. Those overrides are narrow; every boundary they
do not name remains in force.

The already-running worker must receive one explicit steer to re-read this
section before its next source edit. Editing this file alone is not delivery
to an agent that read an earlier revision.

## Grounding before any edit

Repository: `/Users/jojo/Downloads/Epistemos`
Branch: `feat/goose-surface`

1. Fetch origin. Verify the current branch, local HEAD,
   `origin/feat/goose-surface`, and
   `git log -1 --format=%H -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
   match. If they do not, stop without resetting or overwriting anything and
   explain the mismatch.
2. Read in full, in this order:
   - `AGENTS.md`
   - `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
   - `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/00_READ_FIRST.md`
   - canon `14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md`
   - canon `15_OWNER_DIRECTIVE_COVERAGE_AND_HARDENING_CHECKPOINT_2026_07_15.md`
   - canon `16_TWO_LANE_REMOVAL_AND_REBUILD_DIRECTIVE_2026_07_15.md`
   - `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
   - `docs/plans/keelstone/INTENT_LEDGER.md`
   - `docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`
   - `docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/PREPARATION_PACKET_CORRECTION_LOG.md`
   - the current source, call sites, target membership, tests, fixtures, logs,
     retained artifacts, and diff for every seam below.
3. Load and follow `agentic-engineering-protocol`. When the bounded source
   implementation appears complete, use `deep-hardening-loop`; do not claim
   product/release completion without the integration evidence defined below.
4. Inspect `git status --porcelain=v1 -uall`. Preserve all dirty work.
   Settings files belong to another owner session: do not edit, revert,
   format, stage, or absorb them.
5. Create and maintain your scoped ledger only at:
   `docs/plans/two_lane_2026_07_15/REMOVAL_INTENT_AND_EVIDENCE.md`.
   Record this owner directive verbatim, interpretation, constraints,
   non-goals, tests, files, proof, verification debt, and every later steer.
   Do not edit the central canon, handoff, central intent ledger, exact runtime
   evidence, or manifest; those are coordinator-owned.

## Exact owner intent

Remove or fail-close everything current canon classifies as canceled, parked,
stale, forbidden, or misleading in Free V1. This is a real compile/query/
presentation/runtime removal, not hiding buttons. Preserve user data,
historical receipts, safe migrations, and bounded compatibility parsing. Do
not remove deterministic product features merely because they share old files
with canceled AI or Reckoner work.

Newest owner steer, verbatim: “i told the agent to remove emembedings but i
change my mind i wnattokeep it but it must be auditted and hardened because it
has issues i want my sea3rch to bebetter”. Interpret this as an explicit Free
V1 decision, not a future-edition placeholder: retain and improve local
embedding-backed paragraph semantic/hybrid note search. This supersedes every
earlier lexical-only or remove-all-embeddings instruction in this prompt and
the scoped ledger. It does not restore generation, chat, June, Goose, agents,
providers, credentials, prompts, or model-driven analysis. Embedding execution
is allowed only inside the audited note-search closure defined by the revised
addition 011 and additions 030–031 below.

The worker also received this direct owner clarification, verbatim: “it should
remain in free build est embeddignservice thi maybe even look up better helper
models etc.” Treat `EmbeddingService` here as the desired local embedding-
search capability, not as advance approval for every responsibility or caller
of the current Swift type with that name. Researching a better helper model is
authorized inside the architecture checkpoint; adopting one is not. Select the
canonical implementation only through the measured comparison and removal
boundary in additions 011, 030, and 031.

Newest model-selection steer, verbatim: “i do not care about the embedding
model being larger i wat effectiveness”. Measured Epistemos retrieval
effectiveness—not model size—is the primary selection objective. Do not prefer
a smaller model when a larger locally bundled candidate produces a material,
reproducible improvement on the required paragraph-query corpus, exact-title
behavior, negative cases, and false-positive controls. Model/bundle size,
memory, latency, energy, license/provenance, local-only availability, App Store
compatibility, maintenance surface, and bounded index/rebuild work remain hard
feasibility and release gates, but size is only a tie-breaker after candidates
clear those gates and their effectiveness is compared. This steer does not
preselect a model or authorize an implicit download, provider/credential path,
general transformer/generation runtime, or unmeasured architecture change.

Newest verification steer, verbatim: “it is allowed to build but must do it in
batches so i can have to code and do build/test chevkpoints”. Interpret this as
explicit permission for Lane R to code coherent owned slices and periodically
run the batched build/test checkpoints in addition 054. This supersedes prior
blanket source-only/no-Xcode/no-build wording only for those scoped verification
commands. It does not authorize Lane B or Settings edits, model downloads or
execution, public app launch/manual product use, signing/notarization/release,
deployment, or treating one Debug build as release or artifact proof.

Newest transition steer, verbatim: “also when it gets to the point where it is
done and can mass commit dont wait for me just have it save the chefkpoint and
the  start the simulated rebuild. should feel like a v2 of the app deeply”.
This is the owner's advance authorization for the checkpoint commit and the
successor whole-app simulated rebuild in additions 055 and 039. Do not pause for
another owner approval after the readiness conditions are honestly satisfied.
“Can mass commit” still means the intended baseline is attributed, reconciled,
verified, and safe to snapshot; it never means absorbing unexplained or active
multi-owner work. “Feel like a V2” requires materially better product behavior,
coherence, architecture, interaction quality, and resilience across the whole
app, not a version-label change, cosmetic reskin, report, or shallow cleanup.

“Notebook removal” in this prompt means only the legacy multi-surface
Chat/Sheet/Body-strip workspace, its stale tabs, launchers, disclosures,
restoration, and presentation. Do not remove or prohibit the notebook product
concept. Preserve the canonical JSON `.epdoc` architecture so a later
Epdoc-native notebook/structured-document capability can be built without
Chat, Sheet/Reckoner, Tiptap, AI, or the retired tab ontology.

## Your owned implementation scope

Implement canon 15 P0-A, P0-A2, P0-A3, P0-B, P0-C, P0-D, P0-E, and P0-F in
the exact internal order recorded there:

1. Make Contextual Shadows note-only in Free V1. Remove chat queries, results,
   fallback selection, tab/count, preview, copy/drag/insert payload, and open
   actions. Retain chat bytes/decoding without reachability.
2. Sanitize QueryParser/StructuredQueryParser/QueryCompiler/QueryRuntime and
   final graph/query results. Hidden chat/run/raw-thought/tool-trace/provider/
   model IDs, labels, snippets, paths, neighbors, and edge endpoints must never
   escape even when a caller requests them directly.
3. Remove the Free legacy workspace's Chat/Sheet/Body-strip, TOC, disclosure,
   launcher, restoration, recovery, export, and saved-workspace presentation.
   Retain a bounded byte-preserving compatibility parser and normalize stale
   tab IDs. Do not delete the general notebook concept or future Epdoc-native
   structured-document seams.
4. Remove `.reckoner` from Free capability truth, tests, routes, commands,
   restoration, graph, export, copy, and the pending dataset hook. Preserve
   quarantine receipts, licenses, old sheet/dataset decoding, GRDB/SQLite used
   for derived note search/index/cache/migrations, ordinary Markdown tables,
   and safe unknown-record presentation.
5. Split the Free JS editor entrypoint and package graph so EpdocAIDiff,
   HandleWithCare suggestion machinery, assistant commands/events/marks, and
   AI-only bridge/review/provenance types are absent from the Free target and
   artifact. Preserve document-load epochs, minimal-diff writeback,
   transactions, selection, undo, serialization, conflict handling, and the
   note session state machine.
6. Remove canceled LLM/chat/triage/meaning/summary/approval services, objects,
   sheets, observers, jobs, and initialization from the Free composition root,
   environment, and root UI after auditing retained deterministic callers.
7. Correct stale HTML/onboarding/Home/recovery copy and route assumptions
   outside Settings. Existing user-authored HTML documents remain
   deterministically openable/editable/previewable/exportable; AI regeneration,
   recent-chat context, and agent patching do not.
8. Reconcile `project.yml` Free source membership and
   `scripts/keelstone-release-gate.sh`. Stop requiring canceled June/Goose/
   `agent_core` source. Use a reviewed Free allow/deny manifest and recursive
   semantic scans across executable, plist, resources, Swift/Intents metadata,
   JS/CSS, and decoded Brotli assets—not exact-line-only matching.
9. Finish generation/provider `InferenceState` and Epdoc complexity removal
   only after proving no retained deterministic route, migration, search,
   graph, Kokoro, or compatibility decoder depends on it. Preserve only the
   minimal local embedding runtime/state needed by the audited Free paragraph
   semantic/hybrid note-search closure; do not preserve NaturalLanguage or any
   other model execution as an unnamed helper outside that closure.

## Coordinator live additions

### `LR-LIVE-2026-07-15-001` — repair P0 execution-order drift

- Evidence: this prompt claimed canon 15's exact internal order but previously
  placed P0-B and P0-C before P0-D. The Lane R ledger currently records P0-B
  source work as complete while current `ProductCapabilityPolicy.swift` still
  classifies `.reckoner` as Free V1 and names P0-C as the next action.
- Required action: do not discard or rewind the completed P0-B work. Before the
  next P0-C source edit, complete P0-D's fail-first capability, restoration,
  deep-link, graph, export, dataset-hook, and compatibility boundary. Then
  resume P0-C and re-audit P0-B target membership after the later target graph
  reconciliation.
- Intended proof: the scoped ledger records the order correction and P0-D
  evidence; Free capability truth excludes Reckoner; stale routes/defaults
  fail closed; old records remain byte-preserved and visibly unsupported; no
  calc engine or dataset product starts.
- Ownership: Lane R owns the policy, dataset hook, non-Settings routes/copy,
  tests, and target checks. Settings remains an explicit external handoff.

### `LR-LIVE-2026-07-15-002` — close indirect metadata and resource residue

- Evidence: current target work excludes the obvious AI analysis intent and
  `ChatEntity`, but paid identities remain reachable through adjacent source
  and resources: `AppCoordinator.swift` still has a `TriageService` contract;
  `EpistemosFocusFilters.swift` retains agent/model/provider defaults-key
  names outside its Free compile guard; `AIPartnerService.swift` consumes that
  seam; and `Resources/Localizable.xcstrings` still contains provider/model/
  AI-facing strings. These are not proven absent merely because their visible
  controls are guarded.
- Required action: for P0-C/P0-E/P0-F and target reconciliation, map the full
  Free dependency closure across App Intents/Shortcuts/Focus metadata,
  Spotlight entities, menus/commands, localized resources, defaults and
  restoration keys, observers/jobs, and generated metadata. Remove canceled
  files/types/resources from Free membership where safe; retain only bounded
  compatibility identifiers that are required to decode or clear stale state.
  A compile guard or unavailable button is insufficient when paid strings,
  types, jobs, or generated metadata still enter the Free artifact.
- Intended proof: source guards validate the reviewed Free allow/deny
  membership and localization/resource set; adversarial release-gate fixtures
  cover generated App Intents/Spotlight metadata and localization catalogs;
  the later exact artifact contains no canceled user-facing identity while
  deterministic note/search/capture/Focus behavior remains.
- Ownership: Lane R owns these Free membership and non-Settings seams. Record
  an exact integration request instead of editing a Lane B or Settings file.

### `LR-LIVE-2026-07-15-003` — keep the protected native editor seam honest

- Evidence: the scoped ledger records that the Free JS graph is pruned but
  protected `Views/Epdoc/EpdocEditorChromeView.swift` still binds native
  suggestion callbacks/events, with dependent bridge/coordinator/provenance
  types remaining. Lane R may not cross that Lane B ownership boundary.
- Required action: preserve the exact cross-lane seam and compile-tested
  removal order in the ledger. Do not describe the full Free native target or
  artifact as suggestion/AI-symbol-free until the later serial integration
  transaction removes or edition-isolates that seam.
- Intended proof: Lane R may mark its owned source diff stable, but its final
  checkpoint must pair `READY_FOR_SERIAL_INTEGRATION_VERIFICATION` with an
  explicit `NOT_FULL_FREE_TARGET_PROVEN` caveat and the named integration
  prerequisite until the protected seam and exact artifact scan pass.
- Ownership: no Lane B edit is authorized by this addition.

### `LR-LIVE-2026-07-15-004` — nil paid services are still compiled services

- Evidence: the partial P0-C diff removes paid constructions but leaves
  Free-visible typed storage/accessors for `LLMService`, `CloudLLMClient`,
  `TriageService`, and `WorkspaceSummaryService` in the 3,684-line
  `AppBootstrap.swift` by changing them to optionals guarded by
  `requireInitialized`. `AppCoordinator.swift` and those service definitions
  are not yet excluded by `project.yml`. The same Free root still eagerly owns
  `MCPBridge`, `PreparedModelRegistryState`, `PreparedModelRegistry`, a
  `SovereignGateLifecycleObserver`, and a lazy `NoteInsightService`; each
  requires a retained deterministic-caller classification rather than a name-
  or nil-based assumption.
- Required action: P0-C must remove canceled executable types from the Free
  composition API and target dependency closure, not merely avoid constructing
  them. Move paid declarations, forwarding methods, environment/keychain
  helpers, observers, and service files outside Free membership or behind an
  edition boundary that prevents their types from compiling. Audit every
  remaining eager/lazy registry, bridge, observer, and task; retain it only
  with a named deterministic caller and proof that it performs no generation,
  provider, agent, credential, unrelated network, permission, or paid
  restoration work. The one local search-embedding exception must be isolated
  to the reviewed addition 011/030 closure; a mixed generation/search registry
  is not acceptable.
- Maintainability bar: do not finish P0-C by scattering more one-off edition
  branches through giant bootstrap/root files. Prefer one explicit Free
  composition boundary and a reviewed dependency closure so entire paid
  branches and accessors disappear together. Compatibility-only data shapes
  must be separated from executable services when historical decode requires
  them.
- Intended proof: a source test fails on Free-visible paid service type names,
  accessors, constructors, registrations, scheduled tasks, and target members;
  the reviewed target manifest excludes their dependency closure; focused
  bootstrap tests prove deterministic services initialize once and canceled
  services initialize zero times. Exact artifact/type/string proof remains
  integration debt.
- Ownership: Lane R owns bootstrap/environment/root composition and Free target
  membership. Record an exact handoff instead of editing Settings or Lane B.

### `LR-LIVE-2026-07-15-005` — P0-F is removal, not an inference-state rename

- Evidence: current `ProductRuntimeState.swift` is 4,421 lines with 129 edition
  preprocessor directives. Compared with the deleted `InferenceState.swift`
  after normalizing the type name, it adds 555 lines and removes only 20. Its
  Free branch still exposes model/provider-shaped enums, selections, defaults,
  accessors, and no-op stubs, while `AppBootstrap` constructs it and retains a
  prepared-model registry. This is not the smallest deterministic runtime
  state required by canon 15 P0-F.
- Required action: do not use filename/type renaming, inactive paid branches,
  placeholder providers, or no-op model APIs as deletion evidence. Map the few
  retained deterministic callers first, including supervisor, restoration,
  graph/search, Kokoro, and legacy-default cleanup. Keep only the minimal state
  those callers actually require in the Free target; move paid model/provider/
  credential/routing implementations into excluded source or delete them when
  safe. Put legacy defaults decoding/purging in a bounded data-only
  compatibility helper that cannot initialize a runtime.
- Explicit model boundary: Free may construct or load only the local embedding
  asset, vector index, and smallest search-specific manifest/state selected by
  the addition 011/030 audit. It must not retain general generation-model
  registries, credential caches, provider validation/routing, chat-model
  availability, or mixed prepared-model state. Map `PreparedModelRegistry*`
  callers and split a minimal search-only asset/index descriptor if semantic
  retrieval genuinely needs it; do not make the entire paid registry an
  embedding exception or leave Free on `NoModelTextEmbeddingLookup`.
- Intended proof: source membership and semantic guards show no paid
  generation/provider/runtime implementation outside the exact allowlisted
  search-embedding closure; migration/restoration fixtures prove stale
  defaults are cleared or decoded without loss; retained search, graph, and
  Kokoro compile-test later. Exact artifact scans must match the reviewed
  embedding dependency/model manifest and reject every unrelated old or
  renamed inference identity. Line-count reduction alone is not proof, but a
  near-copy with hundreds of stubs is explicit non-proof.
- Ownership: Lane R owns runtime-state removal, composition, and membership.
  Do not alter Lane B graph hosts/renderers or Settings to satisfy this item.

### `LR-LIVE-2026-07-15-006` — graph projection must reject paid provenance, not only forbidden enum types

- Evidence: `ProductCapabilityPolicy.allowsGraphProjection` currently accepts
  only a `GraphNodeType`, and the corresponding gates in `QueryRuntime`,
  `FilterEngine`, and `GraphFilterSnapshot` therefore inspect only the enum.
  Yet `GraphNodeMetadata` carries `originChatId`; both `EntityExtractor` and
  `MeaningAnchorService` write that field onto `.idea` records generated from
  paid chats. Because `.idea` is an allowed Free type, those records can pass
  the current policy. `QueryResultNode` drops record metadata, so the final
  `sanitizeForCurrentProduct` type check occurs after the authoritative
  provenance needed to reject the record has been lost. The focused removal
  test currently seeds only one `.note` and one `.chat`, leaving this allowed-
  type/paid-origin case unproved.
- Required action: define one authoritative record-level Free projection
  predicate in the product-policy boundary. It must first reject forbidden
  types, then reject records with typed paid provenance or a known durable
  paid identity even when their presentation type looks allowed. Preserve
  genuinely user-authored notes, ideas, sources, and ordinary text; do not use
  broad keyword or substring censorship for words such as `chat`, `model`, or
  `provider`. Keep type-only checks as parser/compiler preflight if useful, but
  make the record-level predicate the definitive gate wherever a record exists.
- Query/traversal order: apply the definitive predicate before conversion to
  `QueryResultNode`, label/snippet construction, candidate ranking, ordering,
  offset/limit, aggregation, direct/fuzzy/label resolution, edge projection,
  and every neighbor/path traversal. Run traversal on the allowed induced
  subgraph: a hidden intermediate record must not make two allowed endpoints
  appear connected, shorten a route, change a visible connection count, or
  influence an aggregate. Search, semantic, event-projection, graph-filter,
  Time Machine, export, Spotlight, and restoration consumers must either use
  this same policy before projection or record an exact owner handoff.
- Intended proof: extend the fail-first matrix with a user-authored `.idea`, a
  chat-origin `.idea` carrying `originChatId`, every forbidden graph type, and
  an allowed-hidden-allowed path. Exercise ID, label/fuzzy, node filter,
  neighbor, path, edge, full-text/semantic result conversion where available,
  ordering/paging, graph-filter snapshot, and connection-count/aggregation
  behavior. Include an adversarial visible note/idea whose ordinary content
  mentions paid terms so the test also proves the policy is provenance-based
  rather than a false-positive text filter.
- Ownership: Lane R owns the product policy, query runtime, and its focused
  removal tests. Reconcile shared filter/snapshot ownership before editing and
  record an exact integration request for any prohibited Lane B graph host,
  container, renderer, route, or test; this addition does not authorize those
  edits.

### `LR-LIVE-2026-07-15-007` — the legacy parser must be bounded after an opener too

- Evidence: `EpdocNotebookManifest.parseFencedManifest` enforces its 65,536-
  UTF-16 scan limit only while `isInsideManifest == false`. Once an early
  `epistemos-notebook` fence opens, the `|| isInsideManifest` condition permits
  scanning and accumulating every remaining line until a close fence or EOF.
  A single giant line also makes the unbounded newline search occur before the
  next offset check. `YAMLFrontmatterBlock.find` similarly scans from an
  opening delimiter to EOF without a content limit. The existing test named
  “manifest parsing is bounded” places a valid manifest after 5,000 ordinary
  lines; it proves only that a late opener is ignored, not that an early,
  oversized, or unterminated block is bounded. The focused Lane R test covers
  only one valid small manifest.
- Required action: revisit P0-A3 before final checkpoint and bound work in all
  dimensions: opener search, individual line/value size, total manifest or
  frontmatter span, parsed line/tab count, and temporary allocation. Enforce
  the limit while looking for the newline/closing delimiter rather than first
  scanning an unbounded suffix. An invalid, excessive, or unterminated legacy
  block must fail closed as compatibility-only input, construct no retired
  surface, schedule no recovery work, and leave the original Markdown/package
  bytes untouched. Never partially accept a truncated set of tabs as though it
  were a valid active manifest.
- Intended proof: add fail-first fixtures for an opener immediately followed
  by an oversized single line, many bounded-size lines, excessive tabs,
  malformed attributes/quoting, missing close fence, oversized/missing-close
  frontmatter, and a large ordinary Markdown document. Assert empty/inert
  product state, stable body selection, no TOC/Lens/reference reconstruction,
  and exact input-byte equality across the available pure save/reopen or
  snapshot projection seam. Retain the late-opener test and record runtime/
  allocation measurement as serial-integration debt; a wall-clock-only unit
  threshold is not a substitute for structural limits.
- Restore matrix: separately exercise stale selected-tab IDs, saved workspace
  snapshots, deep links, graph state, and restore records containing chat,
  agent, Browser, arXiv, or sheet data, as canon 15 requires. They may restore
  only allowed note/graph/Meeting state without deleting the retained source
  bytes. If a restore seam is outside Lane R ownership, name its file, owner,
  fixture, and expected normalization in the scoped ledger.
- Ownership: this is Lane R notebook-removal/parser/test work. It authorizes no
  Lane B Epdoc file, shared Lane B test, Settings, build, app launch, or runtime
  action.

### `LR-LIVE-2026-07-15-008` — owner override: remove June and canceled paid product code from Free

- Owner steer, verbatim: “i forgot that i was telling agetns to hide june and
  stuff but it should be removed because this is the free version”. This
  supersedes the earlier owner wording that June should be hidden. Record this
  steer verbatim in the scoped intent checkpoint before the next source edit.
- Interpreted intent: June, Goose, `agent_core`, and the canceled paid AI,
  chat, agent, LLM, triage, meaning, summary, provider, model, approval, and
  suggestion product branches must be removed from the Free product boundary.
  They may not remain as hidden UI, unavailable controls, nil optionals, no-op
  services, inactive Free-visible types, compile-guarded declarations that
  still enter the Free target, parked source copied into the app bundle, or
  release-gate “required” identities. A fail-closed return is only a boundary
  for stale external input; it is not a substitute for removing executable
  product code from Free membership.
- Removal boundary: remove these branches from the Free target dependency
  closure, composition API, generated metadata, Intents/Shortcuts/Focus,
  Spotlight, menus/commands, localization/resources, JS/package graph,
  embedded frameworks/dylibs/executables, defaults-driven activation,
  restoration routing, observers/jobs, and final artifact. Paid source may
  remain elsewhere in the repository for a separately owned future edition
  only when `project.yml` and the reviewed allow/deny closure prove it cannot
  compile, link, copy, register, initialize, or be discovered in Free V1.
- Data-preservation boundary: do not interpret “remove” as permission to erase
  user-authored notes, historical chat/sheet/dataset bytes, receipts,
  licenses, quarantine records, unknown records, or safe migrations. Retain
  only the smallest bounded data-only decoder or stale-key cleanup required to
  preserve/read those bytes safely; isolate it from executable June/agent/
  provider/model services and present old records only through the already
  authorized inert/unsupported compatibility treatment.
- Intended proof: the Free allow/deny manifest has no June/Goose/`agent_core`
  or other canceled executable/resource member and no positive gate assertion
  requiring them; source-closure tests reject hidden/nil/no-op/guard-only
  substitutes; recursive semantic scans cover source membership, build
  settings, generated metadata, localized resources, compressed assets, and
  embedded binaries. The later exact artifact scan must prove absence. Add
  preservation fixtures showing historical bytes/receipts survive without
  registering or invoking a canceled service.
- Ownership/order: apply this override to P0-C, P0-E, P0-F, their later
  hardening passes, and the serial integration checklist. Do not delete a
  separately owned future-edition source tree, cross Lane B, edit Settings, or
  run a build/app/artifact action in this source-only lane; record exact
  handoffs where those owners must complete removal.

### `LR-LIVE-2026-07-15-009` — remove paid build choreography; post-build scrubbing is not the boundary

- Evidence: the current `project.yml` header still describes the canonical
  App Store target as “with June and its in-process agent core.” The Free
  target's own prebuild phase still names `build-omega-mcp.sh`,
  `build-agent-core.sh`, and `build-june-web.sh` behind a runtime edition
  conditional. Its generic postbuild asset script contains the complete June
  copy path and handles Free by deleting `JuneWeb`; a second postbuild phase
  checks for paid frameworks after the build. The release gate then positively
  requires the `build-agent-core.sh` string, June gateway, Goose runner, and
  `agent_core` source. This is a guarded/scrubbed paid build graph, not a
  positive Free-only graph.
- Source-membership evidence: directory exclusions cover `JuneAgent/**`,
  `Goose/**`, and `LocalAgent/**`, but plainly agent-facing files such as
  `AgentCommandCenterState.swift`, `CommandCenterRequestCompiler.swift`, and
  `LLMService.swift` remain target members, along with numerous
  `canImport(agent_coreFFI)` fallbacks and the near-copy runtime state covered
  by `LR-LIVE-2026-07-15-005`. Directory-name exclusion alone is therefore not
  dependency-closure proof. Classify each such member by actual deterministic
  caller; split out a minimal compatibility data shape when required and
  exclude the executable agent/service remainder.
- Required action: make the Free target's source, build-phase, link, and
  resource graph a positive allowlist. Its invoked prebuild scripts must not
  contain or dispatch paid agent/June/Goose/model/MCP build commands, even as a
  skipped branch. Its asset path must copy only reviewed deterministic Free
  resources; do not stage/copy paid material and then delete it. Artifact
  denial and postbuild scrubbing may remain as defense in depth, but they
  cannot mask an overbroad source or build graph. Update stale target and gate
  wording from “hidden/inert” to “removed from Free V1.”
- Release-gate proof: delete every positive requirement for paid source,
  runner, gateway, build command, or staged web tree. Replace it with static
  assertions that the Free target/build phases/allowlist do not reference
  those paths and with recursive semantic artifact denial. Add adversarial
  manifest fixtures in which paid commands are renamed, nested in conditionals,
  introduced by an included helper script, or staged then scrubbed; all must
  fail. A separately owned future-paid target/script may reference them, but
  the Free graph must not invoke that shared path.
- Ownership: P0-E owns `project.yml`, the Free asset/build script seam, and
  `scripts/keelstone-release-gate.sh`; P0-C/P0-F own classification of their
  included Swift dependency closure. Preserve future-edition repository source
  outside Free membership and preserve user data. Do not run Xcode or an app/
  artifact scan in Lane R; record those as serial-integration proof.

### `LR-LIVE-2026-07-15-010` — note-only Shadows must not read or index chat files

- Evidence: `ShadowVaultBootstrapper.bootstrap()` still unconditionally calls
  both `crawl(domain: .notes)` and `crawl(domain: .chats)`. The chat branch
  enumerates `<vault>/chats/**/*.json`, reads each file with unbounded
  `Data(contentsOf:)`, decodes `ShadowVaultChatPayload`, flattens the full chat
  body, and enqueues a `.chats` document into the Shadow index. `AppBootstrap`
  constructs this bootstrapper on vault setup and launches `bootstrap()` from
  a utility task. Presentation-time filtering therefore leaves real chat I/O,
  parsing, allocation, derived storage, and search reachability behind. The
  current focused Lane R test exercises filtered hits but never boots a fixture
  vault containing a chat file, so the P0-A “note-only” checkpoint overclaims
  the ingestion boundary.
- Required action: remove the operational chat crawl, discovery contract,
  loader/flattening branch, progress domain, and any chat indexing/update job
  from the Free bootstrap path. Do not enumerate or open the chats directory at
  all. Make the Free search/query API notes-only by construction so an internal
  caller cannot request `.chats`; if the Rust wire format or a persisted DTO
  still needs the raw `chat` discriminator or `chatCount`, isolate it as inert
  data-only decode compatibility rather than an active query-domain enum.
- Upgrade boundary: handle previously derived Shadow chat rows without touching
  their source files. Rebuild or migrate the derived Shadow index to a notes-
  only projection, or otherwise prove old chat rows cannot be searched,
  counted as visible work, warmed, ranked, restored, or returned after upgrade.
  Preserve original chat JSON and any historical receipts exactly. Do not
  solve stale derived rows only with a final UI filter.
- Intended proof: bootstrap a fixture vault containing an allowed note plus a
  readable, uniquely searchable chat and assert that only the note is
  discovered/read/enqueued. Add an unreadable or very large chat fixture whose
  access would fail the test, proving the directory is not touched. Exercise a
  pre-populated derived index containing a chat row and prove the Free upgrade
  projection removes or makes it unreachable while the original chat bytes
  remain identical. Source guards must reject `.chats` crawl/load/flattening
  calls and Free-visible chat search entry points; record exact Rust ABI or
  integration debt if a data-only discriminator cannot yet be split.
- Performance proof: record removed chat enumeration/file-count/body-byte work
  and later measure vault bootstrap with a chat-heavy fixture. Do not claim a
  speedup from source inspection alone, but do not defer the structural removal
  of that work.
- Ownership: Lane R owns Contextual Shadows/bootstrap/query seams and may
  reconcile the `AppBootstrap` caller within P0-C. Do not edit Settings or any
  prohibited Lane B graph/Epdoc host; record a handoff for protected tests or a
  Rust owner seam if required.

### `LR-LIVE-2026-07-15-011` — keep and harden Free paragraph semantic/hybrid Shadow search

- Owner override: the newest steer explicitly keeps embeddings in Free because
  paragraph semantic search matters and current search has issues. Stop the
  in-progress lexical-only conversion. Do not reset or discard the worker's
  unrelated note-only/chat-removal, API-contraction, provenance-removal, test,
  or safety edits; surgically rework only the superseded embedding decision.
  Record this steer verbatim in the scoped ledger before the next source edit.
- Current evidence: the original Shadow semantic backend combines Model2Vec,
  usearch/HNSW, BM25, and RRF, but it is not release-hardened. It initializes
  `StaticModel::from_pretrained("minishlab/potion-base-8M")` before lexical
  index open, may silently perform a roughly 30 MB Hugging Face download, and
  has ignored real-model tests. It embeds each whole note rather than stable
  paragraph chunks. Its RRF score at rank one is at most about `2 / 61 =
  0.0328`, while `HaloController` defaults to a `0.2` threshold, so the normal
  UI can discard every fused hit. The old semantic feature also accepts chat
  domains, mixes derived sidecar pairs without a complete transactional
  manifest, and uses unchecked lock-poison `expect` paths. The partial current
  diff makes `free-lexical` the sole Free backend and moves semantics to a
  future-only feature; that build decision is now superseded.
- Product contract: Free ships note-only local BM25 plus embedding-backed
  paragraph retrieval and a deterministic hybrid ranker. Preserve the newly
  contracted notes-only Swift/Rust API/ABI—restoring embeddings does not
  restore a generic domain argument, chat indexing, chat counts, chat files,
  agent provenance, VaultRecall traces, Eidos fixture data, or provider/model
  routing. Lexical search must remain independently usable whenever the
  embedding asset/index is absent, corrupt, rebuilding, canceled, or too old.
  Semantic degradation must be explicit and must never turn a lexical match
  into an empty or falsely successful result.
- Architecture checkpoint before edits: map both existing embedding stacks—
  Shadow Model2Vec/HNSW and Apple `EmbeddingService` NaturalLanguage/prepared
  retrieval—plus callers, data shapes, model delivery, dimensions, index
  persistence, threading, memory, and current tests. Select and document one
  canonical Free paragraph-search embedding path using relevance, availability,
  privacy, App Store, latency, memory, and maintenance evidence. Do not keep two
  full stacks by default, but do not delete either or its compatible vector
  cache until the comparison and migration plan prove which one is redundant.
  Split any selected search asset/index descriptor from general generation or
  provider registries.
- Model/network hardening: runtime index open, note edit, typing, query, and
  warmup must never call an implicit `from_pretrained` network path. Prefer a
  reviewed bundled local model; an explicit user-initiated install is allowed
  only through a separately owned UI handoff with HTTPS origin allowlisting,
  redirect policy, byte/time limits, cancellation, atomic staging, exact
  SHA-256, model ID/version/dimension/normalization/license manifest, regular-
  file and symlink checks, and no credential or executable-code download. With
  no verified model, stay lexical and leave any preexisting asset untouched.
  Note/query text never leaves the Mac, enters download requests, or appears in
  unbounded logs/telemetry. Do not start a model download or full embedding
  crawl at cold launch merely to prewarm search.
- Paragraph/index contract: segment note title/body deterministically into
  bounded Unicode-safe heading/paragraph chunks with stable versioned chunk
  IDs and explicit note ID, vault key, source range, content hash, and model
  version. Bound note bytes, chunk bytes/count, overlap, batch size, vector
  dimension/count, decoded JSON/mapping size, and temporary allocation. On edit
  or delete, atomically upsert current chunks and remove stale chunks; on vault
  switch/reset/cancellation, old work may not publish. Return a matching-chunk
  snippet but deduplicate to one best result per note, exclude the originating
  note before final ranking, and apply the record-level paid-provenance policy
  before ranking or paging. Never enumerate or embed historical chat, trace,
  quarantine, provider, model, or raw-thought records.
- Ranking/relevance contract: calibrate lexical, cosine, and fused scores into
  an explicit comparable confidence/rank contract; do not compare a raw RRF
  reciprocal-rank sum to a cosine/BM25 threshold. Define deterministic
  tie-breaking and candidate-pool limits. Add a versioned, note-only relevance
  corpus covering exact title/rare-token matches, paraphrases with no shared
  keywords, related-but-wrong negatives, current-note exclusion, long notes,
  Unicode, stale edits/deletes, duplicated chunks, empty/stop-word queries,
  and corrupted/missing model/index state. Measure lexical versus semantic
  versus hybrid Recall@k/MRR or nDCG and false-positive rate. Hybrid may not
  regress exact lexical/title fixtures and must improve the labeled paraphrase
  set; tune with recorded evidence rather than guessed thresholds.
- Persistence/concurrency contract: use a versioned manifest tying lexical
  generation, vector generation, doc/chunk map, model hash/dimension, and vault
  identity together. Validate before mmap/load; stage and atomically publish a
  complete generation, recover or rebuild on partial/corrupt state, and never
  expose a new lexical generation with stale vector mappings. Convert poisoned
  locks, malformed sidecars, dimension drift, FFI panic/error, unavailable
  assets, and cancellation into bounded typed failure with lexical fallback.
  Preserve the existing main-actor budget, prevent use-after-free and stale
  task publication, cap memory/cache growth, and measure cold/hot indexing and
  query latency on small and large vault fixtures before claiming improvement.
- Migration/data behavior: preserve note Markdown, historical chat/user bytes,
  installed model assets, and compatible vector generations. A derived index
  may be quarantined/rebuilt only after the version/hash/dimension manifest
  proves incompatibility; never delete all embedding assets or sidecars as a
  lexical-removal shortcut. Migration work is bounded, cancellable, resumes or
  rolls back safely, and does not open forbidden source records.
- Intended proof: use injected deterministic embedding/vector fixtures for
  exhaustive source tests and a pinned local real-model fixture for later
  integration. Prove note insert/update/delete/reopen, paragraph paraphrase
  retrieval, score calibration, deduplication, fallback, corruption recovery,
  network denial, cancellation, vault switching, persistence, memory bounds,
  and zero chat/agent/provider/trace access. The exact Free dependency and
  artifact allowlist must include only the selected embedding model/library/
  manifest hashes plus lexical/vector dependencies, and reject generation,
  provider, credentials, arbitrary download clients, or generic chat-domain
  APIs. Do not claim model relevance, offline delivery, latency, memory, Xcode,
  or artifact proof from Lane R source inspection alone.
- Ownership: Lane R owns the source audit, notes-only search architecture,
  Cargo/build membership, source tests, and scoped ledger after reconciling the
  worker's paused Shadow batch. Settings or model-install UI is an exact
  handoff only. No Lane B, Xcode, app launch, current artifact, or release
  action is authorized.

### `LR-LIVE-2026-07-15-012` — remove paid landing cases and routes; do not relabel them “PAID”

- Evidence: `LandingFeatureButton` still compiles `.arxiv`, `.browser`, and
  `.agent` in Free, filters them through `visibleCases`, renames the agent tile
  to `paid`, retains a `PAID` badge, and ships “reserved for a future edition”
  copy plus unavailable actions. `LandingView` still compiles their action
  switch and route mutations. `UIState.HomeContent` likewise contains
  `.arxiv`, `.browser`, and `.agent`; its own documentation says this router is
  session-only and always resets at launch, so those cases have no persisted-
  decode justification. Current Free policy tests assert the hidden agent case,
  paid label, future-edition copy, and fail-closed route normalization. That is
  explicit hidden-placeholder behavior superseded by the owner's removal
  steer.
- Required action: remove paid/canceled landing cases, tile glyph/brand/haptic/
  action branches, badges, unavailable sheets, copy, debug launch routes, and
  `HomeContent` executable cases from the Free compilation surface. The Free
  landing registry must contain only reviewed working Free actions such as PDF
  import and Meeting; do not compile future-agent/browser/source-discovery
  placeholders and then filter `allCases`. Split future-paid route definitions
  outside Free membership or behind a boundary that prevents those cases and
  switch branches from compiling.
- Compatibility boundary: if a genuinely persisted deep link/default outside
  `HomeContent` can name an old paid route, decode the raw identifier in a
  small inert normalizer and map it to `.greeting` before constructing an
  executable route. Do not retain full paid view/action enums for that purpose.
  Browser/arXiv/agent source and user data remain separately preserved outside
  Free target reachability as already required.
- Intended proof: replace tests that instantiate `.agent` or assert `PAID`/
  future-edition copy with source/membership tests proving those cases, labels,
  descriptions, action branches, environment launch key, and paid glyph/brand
  routes do not compile into Free. Verify the actual Free case set exactly and
  add raw legacy-route normalization fixtures that cannot open or schedule a
  paid surface. Later exact artifact scans must find no placeholder copy or
  paid landing identity.
- Ownership: P0-C/P0-E own Free landing/root/UI route removal and focused tests.
  Do not use this item to alter Lane B graph hosts or Settings; record protected
  route/test seams for integration.

### `LR-LIVE-2026-07-15-013` — deterministic search must not emit synthetic agent runs

- Evidence: each normal `SearchIndexService` sync/async page, block, and fused
  search creates a synthetic `runID`, tool-call sequence/ID, arguments JSON,
  metadata dictionaries, and `AgentProvenanceActor.agent(id:
  "search-index-service", modelID: nil)`. It records requested, started, and
  completed/failed `AgentProvenanceEvent`s through default
  `AgentToolProvenanceRecorder`/`AgentToolProvenanceSyncRecorder` instances,
  whose default persistence calls `EventStore.shared?.saveAgentEvent`. Thus a
  deterministic Free note search performs UUID/JSON/metadata allocation,
  actor hops, sequence bookkeeping, and event-store writes while manufacturing
  paid run/tool-trace ontology. This can also feed the hidden graph records
  covered by `LR-LIVE-2026-07-15-006`.
- Required action: remove all agent provenance actors, run/tool-call lifecycle
  construction, recorder storage/default construction, event persistence, and
  helper/failure methods from the Free search implementation and target
  dependency closure. Retain FTS5/BM25 search, cancellation, integrity,
  mutation receipts, query invalidation, and genuinely useful deterministic
  performance/error telemetry through a small non-agent metric/log boundary.
  Do not replace the recorders with no-op agent services whose types still
  compile into Free.
- Compatibility boundary: preserve existing historical agent-event bytes and
  their smallest bounded decoder/migration receipt if required; stop producing
  new events from Free searches. If `AgentProvenanceEvent` and recorder files
  have no remaining reviewed Free caller after composition reconciliation,
  exclude them from Free membership. Never purge user or audit history merely
  to make a source scan green.
- Intended proof: focused sync/async page, block, fused, cancellation, and
  failure fixtures prove identical search results/errors and zero
  `saveAgentEvent` calls, agent run IDs, tool events, or graph projection.
  Source/membership guards reject `AgentProvenance`, `AgentTool`, synthetic
  search run prefixes, recorder construction, and event-store writes from the
  Free search closure. Record removed per-query allocations/hops/writes and
  later measure latency/allocation improvement without claiming it from source
  alone.
- Ownership: Lane R owns retained deterministic search, composition,
  membership, and focused removal tests. Preserve protected graph UI/tests and
  Settings; record exact handoffs for any separately owned historical decoder
  or EventStore migration seam.

### `LR-LIVE-2026-07-15-014` — remove paid graph producers, not only their projected output

- Evidence: `Epistemos/Graph/EntityExtractor.swift` is still included by the
  Free synced-folder target. Its own contract describes an AI-powered vault
  scan; `scanVault` reads note bodies, invokes `LLMClientProtocol`, performs
  ontology/AFM sidecar generation, fetches every `SDChat`, copies message text
  into prompts, invokes the LLM again, and persists chat-derived `.idea`
  records with `originChatId`. `GraphState.scanVault` still constructs that
  extractor and exposes the LLM-dependent task API. A repository-wide caller
  search currently finds no other production caller of either `scanVault`
  overload, so hiding a scan control or filtering the resulting records would
  leave an unneeded paid producer compiled into Free. It also leaves the exact
  source of the tainted records covered by `LR-LIVE-2026-07-15-006` intact.
- Required action: remove `EntityExtractor`, its LLM extraction/prompt/schema
  dependency closure, processed-hash defaults, ontology/AFM generation route,
  and the `GraphState` scan task/API/status state from Free membership when no
  reviewed deterministic caller requires them. Do not retain a no-op or
  guarded `LLMClientProtocol` scan. Keep the independent deterministic
  `GraphBuilder` note graph and its ordinary load/rebuild path reachable; do
  not delete or weaken deterministic graph construction merely because the
  paid extractor called it as its first step.
- Data boundary: preserve source notes and historical chats unchanged. Existing
  chat-origin graph rows are derived state, not permission to keep producing
  them; use the record-level projection policy immediately and, if needed, a
  bounded versioned rebuild/migration that removes or quarantines only derived
  paid-origin nodes and induced edges without opening chat contents. Preserve
  compatibility-only extraction data shapes only if a real persisted decoder
  needs them, isolated from executable LLM services.
- Intended proof: the reviewed Free membership and semantic source guard reject
  `EntityExtractor`, `scanVault(...llmService:)`, its prompts/hash key, chat
  fetch, and extraction-sidecar service reachability. Focused fixtures prove a
  deterministic note-only `GraphBuilder` rebuild still works, Free graph
  startup schedules zero LLM/model/sidecar/chat scan, and stale chat-origin
  derived rows cannot project or connect allowed endpoints while original chat
  bytes remain untouched. Exact app symbols and zero runtime requests remain
  serial-integration debt.
- Ownership: Lane R owns Free target membership, the paid producer removal,
  deterministic graph composition, policy, and focused removal tests. Do not
  edit Lane B graph hosts, containers, renderers, routes, or tests; if removing
  shared `GraphState` scan state would cross a current owner seam, record the
  exact symbols and compile-tested removal order as an integration handoff.

### `LR-LIVE-2026-07-15-015` — remove the dead Daily Brief subsystem from Free composition and landing

- Evidence: Free still constructs `DailyBriefState` eagerly in `AppBootstrap`,
  injects it through `AppEnvironment`, and compiles its landing environment
  dependency, overlay, accessibility text, GenUI payload, loading copy, prompt
  builder, and recent-page query. `DailyBriefState` itself retains generative
  callbacks, task lifecycle, auto-save, and a prompt schema that accepts
  `[SDChat]`. Its only generation wiring is inside the non-Free coordinator
  branch, and repository-wide search finds no production caller of
  `requestDailyBrief` outside the state definition. The capability guard that
  clears the state is therefore dead hidden-placeholder behavior, not removal.
- Required action: remove `DailyBriefState` and its prompt/generative/task
  dependency closure from Free target membership; remove the Free bootstrap
  property/construction and environment injection; and remove the Daily Brief
  overlay, prompt/query-only data fetch, strings, accessibility branch, payload,
  and dismissal routing from the Free landing compilation surface. Reconcile
  the paid `AppCoordinator`/triage wiring under P0-C rather than leaving a
  no-op state or optional callback API in Free. If any landing page query has a
  separate deterministic caller, retain only that caller and smallest query.
- Data boundary: ordinary user-authored Markdown notes, folders, and titles—
  including a note or folder literally named “Daily Brief” or “Daily Briefs”—
  remain normal Free note data. Do not search for or delete generated-looking
  notes. No executable Daily Brief route/state enum should be retained for
  compatibility unless a concrete persisted wire value is first demonstrated;
  current state is in-memory and has no such justification.
- Intended proof: Free composition/source membership rejects
  `DailyBriefState`, generation/save callbacks, brief prompt/chat context,
  overlay/payload/loading copy, and environment injection. A cold-bootstrap
  fixture constructs zero brief state/tasks; landing source tests prove no
  brief route or generative prompt remains; deterministic note create/open/
  search fixtures still accept user content with the same words. Exact artifact
  strings and runtime task absence remain serial-integration debt.
- Ownership: Lane R owns Free composition, environment, landing cleanup, target
  membership, and focused removal tests. Do not alter Settings or Lane B graph/
  Epdoc files for this item.

### `LR-LIVE-2026-07-15-016` — retained note history must not keep active chat ontology behind guards

- Evidence: Free eagerly constructs `ActivityTracker` and
  `TimeMachineService`. The latter still compiles `ChatSnapshot`, `SDChat` and
  `SDMessage` fetches, chat counts/deltas, and log output behind
  `allowsChatPresentation`; its current `TimeMachineView` has no consumer of
  those chat fields. `ActivityTracker.recordChatMessage` has no production
  caller but its active `ActivityEventKind`, digests, seven-day profile, and AI
  prompt formatter retain chat cases/counters. `EventStore.saveActivityEvent`
  can still write `chat_message`, while `WorkspaceService` retains chat-count/
  diff presentation and queries those rows. A false capability branch removes
  runtime presentation but leaves canceled chat behavior and vocabulary in the
  compiled deterministic-history closure.
- Required action: retain reviewed deterministic note open/edit/close activity,
  note/version Time Machine reconstruction/diff/restore, graph counts, bounded
  persistence, and crash recovery. Remove active chat producers, writers,
  fetches, snapshots, counters, diffs, prompt formatting, and presentation
  fields from that Free execution closure. Do not solve this by sprinkling more
  `allowsChatPresentation` guards or by removing the useful note-only service.
  Remove `formatForPrompt`/global profile machinery entirely if it has no
  reviewed deterministic caller after P0-C removes summary/AI consumers.
- Compatibility boundary: preserve existing activity cache/snapshot/EventStore
  bytes. If old encoded `chatMessageSent`, chat-count, or chat snapshot fields
  must still decode, isolate them in a size/record/count-bounded legacy wire DTO
  that discards them before constructing current note-only runtime state and
  never fetches `SDChat`/`SDMessage`, writes a chat event, or re-encodes the paid
  field. Do not delete historical database rows or user chat records to make a
  semantic scan pass; unknown fields remain tolerated according to the existing
  versioned compatibility contract.
- Intended proof: focused fixtures decode a small legacy cache/snapshot with
  chat fields into the same note-only state, reject oversized/malformed inputs
  without partial activation, preserve the original bytes, and show current
  encode/record paths emit no chat kind/snippet/count. Source/membership tests
  reject active `recordChatMessage`, chat fetch descriptors, chat Time Machine
  fields/diffs, `chat_message` insertion, and activity prompt formatting while
  note activity, note restore, graph counts, and ordinary notes mentioning
  “chat” remain functional. Runtime I/O/task and artifact proof stays deferred.
- Ownership: Lane R owns these retained state/composition/history boundaries,
  landing Time Machine cleanup, and focused tests. Record a precise handoff for
  any separately owned legacy EventStore decoder; do not edit Settings or Lane
  B graph/Epdoc files.

### `LR-LIVE-2026-07-15-017` — graph inspection must not invoke Apple Intelligence or paid triage

- Evidence: both `Views/Graph/NodeInspectorState.swift` and
  `Views/Graph/PinnedInspector.swift` are current Free target members and carry
  complete summarization tasks, caches, prompts, and fallbacks. Opening the
  Summary accordion calls `ensureSummary`; pinning a node calls the second
  `ensureSummary` automatically. Both paths send note/folder/tag/quote content
  to `AppleIntelligenceService.shared.generate` first and then to
  `AppBootstrap.shared?.triageService.generateGeneral`. There is no Free
  capability check. Even if the triage accessor becomes nil, Apple
  Intelligence remains an active model call and the paid prompt/task/UI closure
  remains compiled.
- Required action: remove the generative Summary section, model/provider calls,
  prompts, summary tasks/caches/reveal state, loading/error copy, and automatic
  pin-time summary trigger from the Free graph-inspector closure. Preserve the
  useful deterministic inspector behavior—node selection, pin/unpin, bounded
  note preview, neutral profile, relationships, and graph navigation—without
  silently relabeling a fixed content prefix as an AI summary. Do not retain a
  no-op `ensureSummary`, optional triage reference, or unavailable summary
  control.
- Dependency split: the neutral profile currently consumes
  `ContentPersonalitySignals`/`Dialogue*` types from
  `Models/AgentTransparencyModels.swift`. After auditing callers, move only the
  small deterministic graph-profile data/derivation actually required by Free
  into neutrally named graph source, or simplify the profile so the paid agent-
  transparency model file and its NaturalLanguage branch can leave Free
  membership. A deterministic fallback embedded in a paid source file is not a
  sufficient target boundary.
- Intended proof: focused inspector tests select, expand, preview, relate, pin,
  update, and close allowed note nodes while recording zero Apple Intelligence,
  triage, provider, model, prompt, or summary task activity. Source/membership
  guards reject the two summarization implementations, Summary UI/copy, and
  `AgentTransparencyModels` from the reviewed Free closure while deterministic
  profile/preview/relationship behavior remains. Later manual graph inspection
  and exact artifact scans remain serial-integration debt.
- Ownership: Lane R owns paid dependency/membership removal and focused boundary
  tests. Reconcile ownership before changing graph inspector UI/state. If
  `HologramNodeInspector`, `NodeInspectorState`, `PinnedInspector`, or their
  tests are in Lane B's active graph host/container/renderer scope, do not edit
  them; record each exact symbol, minimal removal seam, expected test, and
  compile-tested order as a required serial integration handoff.

### `LR-LIVE-2026-07-15-018` — remove native note/code AI bodies; false flags and capability guards are not pruning

- Evidence: `Views/Notes/CodeEditorView.swift` still compiles
  `CodeCompanionService`, `CodeContextBridge`, `CodeSemanticSidebar`,
  `CodeInsightGenerator`, and the Apple Intelligence Insights panel, including
  `AppleIntelligenceService`, `EmbeddingService`, triage, prompt, cache, and
  task dependencies. `CodeEditorReleasePolicy.semanticSidebarEnabled` and
  `.aiPartnerEnabled` are constant `false`, so the product hides this large
  closure rather than removing it. Separately, protected
  `NoteDetailWorkspaceView.swift` retains `integrateWithAI` and `formatWithAI`,
  sends note/selection/idea text to Apple Intelligence, and compiles AI buttons,
  accessibility/help copy, errors, and conditional “AI formatted” labeling
  behind the false Free capability.
- Required action: surgically remove the hidden AI/semantic companion types,
  state, branches, flags, prompts, tasks, models, and UI from the Free native
  code-editor compilation surface while preserving plain code editing, syntax,
  outline, search, file save, shortcuts, native input, and deterministic note
  linking. Remove editor-only generation/insight consumers of
  `EmbeddingService`; do not remove or disable the shared addition 011/030/031
  search-embedding closure. Do not exclude the whole editor or replace its
  paid bodies with `false` flags/no-op types. After all owned callers are
  removed, exclude `AppleIntelligenceService` and its AFM/pool dependency
  closure from Free membership rather than keeping a service whose first line
  rejects Free.
- Protected note-workspace seam: Lane R may not edit
  `NoteDetailWorkspaceView.swift` for this purpose under the current ownership
  rules. Record a serial integration handoff to delete the two generation
  functions, callback plumbing, busy-state branches used only by them, AI
  buttons/copy, and Apple Intelligence dependency. Preserve deterministic idea
  capture, go-to-line, raw insertion, deletion, and display/toggle of already
  stored `formattedBody` content. The historical field in `NoteIdea` is user
  data compatibility; label it neutrally as “Formatted” and never erase or
  regenerate it merely because the producer is removed.
- Intended proof: focused code-editor source tests reject the false release
  flags and every generation companion/insight/prompt symbol while exercising
  deterministic edit/search/outline/save behavior. They must not reject the
  separately allowlisted paragraph-search embedding symbols. The handoff must
  name tests proving note ideas insert/toggle preserved raw/formatted bytes
  with no AI control or request. Update the existing shared source assertion
  that requires graph Apple Intelligence only through its owner; do not edit a
  protected shared test in Lane R. A cold Free interaction matrix later
  records zero Foundation Models availability/session/generation calls and the
  exact artifact contains no Apple Intelligence service/prompt identity.
- Ownership: Lane R owns `CodeEditorView` paid-closure removal, composition,
  target membership, and new focused tests after confirming no concurrent
  owner. `NoteDetailWorkspaceView` and any protected shared graph/Epdoc test are
  mandatory named integration handoffs only. No Settings or Lane B edit is
  authorized by this addition.

### `LR-LIVE-2026-07-15-019` — Free capture must create notes, not paid raw-thought/quarantine records

- Evidence: Free currently advertises `CaptureBrainDumpIntent` as one of four
  automatic shortcuts and uses it from the Control Center widget. Despite its
  Free description promising capture in the local notes workspace, a nonempty
  invocation writes a new `QuarantineArchive` entry with kind `.rawThought` and
  a paid context anchor; only an empty invocation opens Quick Capture. The
  mixed `CognitiveIntents.swift` also contains context/chat/thesis/sandbox/
  delegate agent intents behind `#if !EPISTEMOS_FREE_V1`. To compile that one
  Free action, the `EpistemosWidgets` target explicitly includes the whole
  mixed file plus `QuarantineArchive`, speech, conversation/session
  classifiers, AFM session/model infrastructure, sidecars, and capability
  policy. This is an active paid data producer and paid source closure, not
  deterministic note capture.
- Required action: make Free shortcut/control capture use one ordinary,
  deterministic note-capture implementation and persistence route. A supplied
  body must create or enqueue a normal note through the reviewed capture
  pipeline; an empty body may open the same neutral Quick Capture surface. It
  must never create a quarantine entry, `.rawThought`, agent/chat/session
  anchor, sidecar, embedding, prompt, model, or donation whose identity claims
  a paid cognitive operation. Remove the duplicate Brain Dump shortcut/control
  identity if it is only an alias for Quick Capture; do not relabel the paid
  producer while preserving its storage behavior.
- Source/target split: separate the retained note create/open/move/search/
  capture intents and widget action from paid summarize/cognitive/sandbox
  declarations. Exclude the paid intent files from both the Free app and widget
  source memberships rather than treating compile guards as pruning. Shrink
  the widget target to the minimal deterministic capture closure and remove
  its `QuarantineArchive`, speech, conversation/session classifier, AFM,
  model/pool, agent capability, and sidecar dependencies after proving no
  other retained widget behavior needs them. Apply the same split to the paid
  `SummarizeNoteIntent` body currently embedded in `NoteActionIntents.swift`.
  Future-paid source may remain outside Free membership.
- Focus metadata closure: `EpistemosFocusFilters.swift` remains a Free source
  member even though its intent is compile-guarded, and its unguarded defaults
  bridge preserves agent-interrupt, provider/model-isolation, and Halo paid
  axes consumed by paid runtime/UI bodies. Once those consumers are removed,
  exclude or split that paid closure and retain only genuinely deterministic
  Focus behavior, if any, in a neutrally named Free file. A minimal bounded
  stale-key cleanup may remove obsolete defaults, but must not keep paid
  runtime types or erase unrelated preferences.
- Data boundary: do not delete, rewrite, migrate, index, or expose existing
  quarantine/raw-thought bytes to satisfy this removal. They are historical
  user data and remain byte-preserved for a future paid build. Free simply
  stops loading or producing that operational ontology; any indispensable
  compatibility inspection must be data-only, size/count bounded, and outside
  the live capture, query, graph, widget, and model closures.
- Intended proof: focused tests invoke every retained Free shortcut/control
  body with empty and nonempty input, prove an ordinary note is created exactly
  once, and record zero quarantine/raw-thought/anchor/sidecar/model writes while
  preseeded archive bytes remain unchanged. Source/membership tests assert the
  exact minimal widget closure and reject mixed paid intent declarations,
  `QuarantineArchive`, classifier/AFM/model dependencies, paid Focus axes, and
  hidden `SummarizeNoteIntent` from both Free targets. Generated App Intents,
  widget, strings, and exact-artifact scans must contain only the reviewed
  deterministic whitelist and no Brain Dump/raw-thought/agent/provider/model
  identity. Runtime and artifact proof remains deferred to serial integration.
- Ownership: Lane R owns intent splitting, deterministic capture routing,
  widget/app target membership, non-Settings defaults cleanup, generated-
  metadata policy, and focused tests. Preserve protected/shared test ownership:
  add removal-specific tests and record an exact handoff instead of editing the
  shared giant lane test or any Lane B/Settings file.

### `LR-LIVE-2026-07-15-020` — deterministic note capture must not retain or write the agent Harness corpus

- Evidence: `TextCapturePipeline` injects `TraceCollector.shared` and emits six
  fire-and-forget `TraceEvent`s for every capture. `TraceCollector.swift`
  describes the files as a full agent-interaction corpus and writes them under
  `traces/production` for the Harness Lab flywheel; its schema embeds bootstrap
  packet, provider, model, tool input/output, tokens, completion checker, and
  session concepts. This one retained caller keeps unguarded
  `BootstrapPacketBuilder`, `HarnessPromptBuilder`, `ProgressStore`, and
  `TraceCollector` source in the synced Free target even though the primary
  agent Harness integration is only compile-guarded for App Store. A DEBUG-only
  `TraceInspectorView` and Quick Capture overlay also read/present the corpus.
- Required action: detach deterministic note/meeting/shortcut capture from
  `TraceCollector`, `TraceEvent`, Harness session IDs/versions, the six capture
  trace factories/writes, and the trace inspector UI. Exclude `Harness/**` and
  the agent trace inspector from Free source membership after auditing all
  callers; do not retain them as `#if`, DEBUG-only UI, injected no-op writers,
  or provider/model fields set to nil. Future-paid Harness source may remain
  outside Free membership.
- Deterministic boundary: preserve the actual capture behavior—bounded text
  cleaning, title/summary derivation, task checkbox parsing, vault-backed note
  creation, block mirror, ordinary note graph node, source metadata, meeting
  recovery, and explicit success/failure. Preserve the current deterministic
  `MutationEnvelope`/EventStore transaction only if its independently reviewed
  note audit/outbox consumers require it; split that minimal user-mutation
  contract from agent-event/provider/model/tool schemas and never treat an
  agent JSONL trace write as required proof that a note saved.
- Data boundary: never delete, rewrite, enumerate, ingest, index, migrate, or
  expose existing `traces/production` files as part of Free removal. Preserve
  those historical bytes in place for a future paid build. Removal means the
  Free process no longer creates, opens, or displays that directory; it does
  not mean erasing the user's prior corpus.
- Intended proof: capture/meeting/shortcut tests prove the same note contents,
  metadata, task parsing, graph note, recovery, and failure semantics with zero
  Harness task, file, directory, prompt, provider/model/tool event, or detached
  trace-writer activity. A preseeded trace directory remains byte-identical and
  unopened. Source/membership guards reject `Harness/**`, `TraceCollector`,
  `TraceEvent`, `capture-v1`, `traces/production`, `TraceInspectorView`, and the
  Quick Capture debug overlay from the reviewed Free closure. Exact-artifact
  and runtime I/O proof remains deferred to serial integration.
- Ownership: Lane R owns this capture dependency split, Free target exclusions,
  Quick Capture debug-only seam, and focused tests after checking for an active
  owner. Do not edit the shared graph-event/runtime validation suites; replace
  obsolete positive trace-inspector expectations through an exact handoff or
  new removal-specific tests under the current ownership rules.

### `LR-LIVE-2026-07-15-021` — empty Free NLP results are hidden paid analysis, not a retained feature

- Evidence: `TextCapturePipeline.swift` is a mixed source file: Free returns an
  empty array from `extractEntities`, while the paid branch retains
  `NLTagger`, person/place/organization ontology, entity-derived tags and graph
  nodes/edges, and entity-count UI/result plumbing. `NLAnalysisService.swift`
  similarly keeps paid entity, language, and sentiment analysis bodies behind
  Free compile branches only because retained callers use its small
  deterministic word counter. The Free target therefore carries misleading
  NaturalLanguage analysis source/types whose runtime result is permanently
  empty rather than a deliberately absent capability.
- Required action: split the reviewed deterministic capture transforms—bounded
  cleaning, first-line/sentence title, clearly neutral first-paragraph excerpt,
  checkbox/task parsing, word count, and source spans—into neutral Free source.
  Remove entity extraction types/calls/result fields, entity tag derivation,
  entity graph writes/counts/copy, paid NaturalLanguage analysis branches, and
  `NLAnalysisService` from Free membership. A NaturalLanguage import may remain
  only inside the selected addition 011/030 search-embedding implementation,
  never in capture/entity/sentiment/language analysis. Move the minimal word-
  count helper to a neutral deterministic text-metrics utility used by capture,
  vault indexing, and the protected note workspace; do not preserve an
  analysis service whose Free methods return `[]`, `nil`, or `0`.
- Presentation/data boundary: a deterministic first-paragraph excerpt may
  remain for note preview/search and may continue filling a compatible stored
  summary field, but it must never be labeled or presented as generated/AI
  analysis. Preserve existing note bodies, tags, summaries, graph rows, and
  metadata bytes; removal stops future paid entity analysis and derived writes
  and does not bulk-clear historical user or derived fields. Ordinary manual
  tags and deterministic note/task graph behavior remain supported.
- Intended proof: multilingual and punctuation fixtures establish bounded,
  stable Free title/excerpt/word/task behavior without loading NaturalLanguage
  models. Capture creates the note and allowed note/task provenance but emits
  no entity type/tag/node/edge/count. Source/membership guards reject
  `NLAnalysisService`, `NLTagger`, `.nameType`, `.sentimentScore`, language
  recognition, `ExtractedEntity`, and empty-analysis stubs from the reviewed
  Free closure while existing stored tags/summaries remain byte-identical.
  Later runtime/model-load and exact-artifact proof remains serial debt.
- Ownership: Lane R owns the capture/text-metrics split, app target membership,
  non-protected capture UI, and focused tests. The word-count caller inside
  protected `NoteDetailWorkspaceView.swift` is a named serial handoff only;
  Settings parity UI remains out of scope and receives an exact caller/test
  handoff rather than an edit.

### `LR-LIVE-2026-07-15-022` — remove the residual agent runtime/schema graph and its Free no-op consent facade

- Evidence: current P0-F exclusions remove June/Goose and three legacy
  `AgentWorkspace` files, but the synced Free target still admits
  `Engine/AgentHarness/**` with provider/backend registry, prompt/history,
  streaming model/tool events, budget/token ledger, permissions, handoffs, and
  chat capability. It also admits the 1,000+ line `OverseerProtocol.swift`
  planner/router/schema (its Free steering method merely returns nil), paid
  prompt/tree/rendering and `StructureRegistry` metadata that advertises AFM,
  session/chat/quarantine/sidecar/LLM schemas as MAS, and
  `AgentWorkspace/AgentCloudConsent.swift`. The latter compiles a Free facade
  whose descriptors say “Unavailable” and whose consent store always returns
  false/no-ops; an existing positive source test explicitly requires that stub
  to remain in Free membership.
- Required action: after removing/reconciling all owned callers, exclude the
  complete agent backend/query/authority/handoff/chat-capability closure, agent
  Overseer/planner/router and prompt/tree/cache/rendering closure, paid
  structure/self-introspection registry, and agent cloud-consent types from
  Free membership. Remove Free no-op descriptors, registries, methods returning
  nil/false/empty, guarded backend accessors, provider/model/tool schemas,
  observers/tasks, and default-key readers rather than keeping them as compile
  compatibility. Future-paid source may remain outside the Free target.
- Closure proof: do not stop at directory-name exclusions. Map semantic
  dependencies through `CommandCenterRequestCompiler`, `ProductRuntimeState`,
  `AppCoordinator`, `PipelineService`, `Prompt*`, `ToolTierBridge`,
  `CapabilityBridge`, Settings bindings, generated metadata, tests, and target
  bindings. Retain a neutrally named deterministic parser/security primitive
  only if an allowed note/edit/search/capture caller and focused behavior test
  prove it is independent of agents, prompts, providers, models, chat, tool
  execution, or paid route selection.
- State/data boundary: preserve historical consent-default bytes, serialized
  agent plans/prompts/traces, authority records, receipts, chat/tool events,
  and unknown records. Free must not enumerate, re-encode, display, or act on
  them. A bounded data-only legacy decoder or stale-key cleanup is allowed only
  where a real current container requires it; never delete prior consent or
  authority state merely to pass a source scan.
- Intended proof: source/membership tests use an exact reviewed deny closure
  and reject `Engine/AgentHarness/**`, `AgentCloudConsent`, `AgentBackend`,
  `AgentQueryEngine`, `ChatCapability`, `Overseer*`, `PromptTree`, paid
  `PromptRenderer`/cache/registry, provider/model/tool schemas, no-op Free
  facades, and their generated strings/metadata. A cold Free bootstrap records
  zero registry singleton construction, defaults reads, prompt build/render,
  backend resolution, stream/tool task, network/model request, or paid metadata
  discovery while allowed note/edit/search/capture/security behavior remains.
  Historical fixtures remain byte-identical. Runtime/artifact proof is serial
  integration debt.
- Ownership: Lane R owns source/composition/target pruning and focused tests.
  Reverse obsolete positive “paid-guarded/AgentCloudConsent retained”
  expectations through new removal-specific tests and an exact shared-test
  handoff. Settings source is not authorized; name each binding/default/control
  removal and its compile order for the Settings owner.

### `LR-LIVE-2026-07-15-023` — removing `omega_mcp` linkage does not remove the Omega/MCP product

- Evidence: P0-F has stopped building/linking `omega_mcp`, but nearly the whole
  `Omega/` Swift tree still enters the synced Free target. It contains the
  model reasoning loop and fine-tuning trace writer, multi-format LLM tool-call
  parser, constrained-decoding tool grammar, MCP tool catalog/dispatcher,
  remote MCP registry/network client, URL-server config discovery/writes, and
  Best Of tool/skill/server installer. `AppBootstrap` still eagerly constructs
  `MCPBridge`; `AgentCommandCenterState`, `CoworkConnectorDirectory`, and
  `EpistemosBestOfPreset` retain its agent/tool/connectors ontology. The
  currently included Settings `ExtensionsDetailView` actively searches the
  remote registry and discovers/installs/uninstalls MCP servers and presets.
- Required action: remove the complete Omega reasoning/tool/MCP/registry/
  server/preset closure from Free composition, source membership, resources,
  Settings reachability, generated strings, and release requirements. Exclude
  `Omega/**` rather than depending on absent FFI imports, capability returns,
  empty tool catalogs, feature flags, or a nil dispatcher. Remove the eager
  `MCPBridge`, command-center/connectors/preset callers and any background,
  network, config-read/write, tool registration/execution, reasoning trace, or
  installation task. Future-paid Omega/MCP source may remain outside Free.
- Data boundary: preserve existing MCP server JSON/config, remote-registry
  cache, tool/skill receipts, Best Of state, reasoning traces, and unknown
  extension records byte-for-byte. Free must neither discover nor mutate those
  files. If a shared extension/settings container must decode them to avoid
  corruption, use a bounded data-only compatibility shape that produces no
  current Free route, row, catalog, connector, or executable tool.
- Intended proof: exact source/target/resource guards reject `Omega/**`,
  `MCPBridge`, `MCPRegistryClient`, `MCPUrlServerDirectory`, reasoning/tool
  parser/grammar/trace types, Best Of presets, cowork connectors,
  `AgentCommandCenterState`, `omega_mcp` bindings/linkage, MCP/skill/connector
  UI strings, and config writer/network endpoints from the reviewed Free
  closure. Seeded config/cache/receipt/trace files remain byte-identical and
  unopened; cold bootstrap and every retained Settings route record zero MCP
  singleton, registry request, discovery, install/uninstall, tool, or model
  activity. Exact artifact/runtime proof remains serial debt.
- Ownership: Lane R owns non-Settings callers, composition, target/resources,
  release guards, and focused tests. `ExtensionsDetailView` and any other
  Settings router/row are mandatory exact handoffs: list the whole MCP Servers,
  Connectors, Best Of, registry search/install, and related route removal plus
  compile-tested order; do not edit Settings in Lane R.

### `LR-LIVE-2026-07-15-024` — remove the parked HTML regeneration product, not the HTML editor

- Evidence: the retained HTML Workspace target still compiles roughly 300
  regeneration references across `HTMLWorkspaceEditorRegeneration`,
  `HTMLWorkspaceRegenerateSupport`, Preview, Surface, and Context Presentation,
  plus regeneration state/control plumbing in `HTMLWorkspaceEditorView`.
  Free/App Store calls `parkRegenerateForUnavailableEdition`, cancels/hides the
  sheet, and displays “reserved for a future paid edition,” while the same
  closure retains prompts, context attachment/search, model streaming,
  patch-response synthesis/apply, agent provenance, tasks, previews, presets,
  and restore coupling. `HTMLWorkspaceDataFeed` also still routes
  `recent_chat` and agent provenance-claim context behind policy guards.
- Required action: remove the regeneration-only source files, prompt/context/
  model/patch-response types, editor state/tasks/nonces/sheets/controls/status
  copy, paid presets, provider/triage calls, chat/provenance context sources,
  and unavailable-edition parking branch from Free membership. Remove, do not
  leave `allowsHTMLWorkspaceRegeneration` checks, disabled controls, empty
  sources, or future-paid copy. Split any genuinely shared deterministic HTML
  parser/patch safety helper into neutral source only after a retained caller
  and focused test prove the dependency.
- Retained product boundary: preserve normal HTML/CSS/JS/JSON source editing,
  syntax/selection/search, sanitized preview, console/DOM inspection, manual
  routes/assets, save/export, content hashes, deterministic note/search data
  feeds, snapshots, undo/restore, and existing packages. Note/meeting/web-clip
  or graph-related feeds may remain only where their current implementation is
  deterministic and passes record-level projection policy; no chat, run,
  raw-thought, tool-trace, model, or provider record may enter a feed.
- Data compatibility: retain `generation_provenance`, prior agent producer/run/
  tool IDs, reversible snapshot names, and previously generated package bytes
  in the bounded package decoder. Free must not erase or regenerate them.
  Present historical provenance/snapshot state neutrally as read-only history
  when needed for safe restore; never interpret it as permission to expose an
  agent route or keep a generation producer. Manual restore must record a human
  deterministic mutation without starting regeneration.
- Intended proof: focused tests open/edit/preview/save/export/reopen and restore
  seeded old generated packages with byte-preserved manifest/source/snapshots,
  then exercise deterministic feeds with zero chat/provenance/model access.
  Source/membership guards reject all `HTMLWorkspaceRegenerate*` files/symbols,
  regeneration state/copy/capability branches, recent-chat/provenance context
  sources, prompt/stream/triage calls, and agent producer writes while retained
  HTML editor behavior and historical decode/restore pass. Later interaction
  and exact-artifact scans remain serial debt.
- Ownership: Lane R owns HTML regeneration/source removal, editor state/control
  cleanup, feed projection, target membership, and focused tests after checking
  current ownership. Do not cross into Lane B Epdoc files. Shared package
  model/decoder edits must be surgical and compatibility-preserving; record an
  exact handoff if another owner currently holds them.

### `LR-LIVE-2026-07-15-025` — stop the note-personality insight producer and relatedness jobs

- Evidence: `AppCoordinator` responds to vault/page mutations by obtaining the
  lazy `AppBootstrap.noteInsightService` and calling full reindex or per-page
  reanalysis. `NoteInsightService` reads note bodies, runs
  `ContentPersonalitySignals`, writes sentiment/formality/vocabulary/question/
  entity/topic fields into `SDNoteInsight`, and schedules coalesced O(n²)
  cross-note relatedness. The source retains NaturalLanguage paid analysis
  behind Free branches and background tasks even though the useful Free note
  editor/search/index does not consume these insight records for core behavior.
- Required action: remove `NoteInsightService`, its bootstrap accessor/storage,
  coordinator event calls, body scans, reindex/reanalysis/debounce/relatedness
  tasks, personality/NLP dependency, and any UI/prompt/graph consumers from the
  Free runtime and target closure. Do not replace the service with empty
  signals, neutral sentiment, a never-used lazy, or capability guards. Preserve
  ordinary vault indexing, lexical search, note graph construction, manual
  tags, word count, editor metrics, page mutation events, and file lifecycle.
- Compatibility boundary: `SDNoteInsight` is a derived local-cache model already
  present in the SwiftData schema and referenced by note-deletion/vault-reset
  cleanup. First prove whether removing it from the current model schema would
  prevent an existing store from opening. Retain the smallest data-only model/
  migration shape if required for store compatibility, with no producer,
  fetch-for-presentation, analysis, relatedness, or re-encode path. Do not
  delete all historical insight rows merely to satisfy semantic scans; a
  bounded, versioned derived-cache cleanup is allowed only with migration and
  store-open proof. Normal deletion of a user-deleted note may continue to
  remove its orphaned derived row.
- Intended proof: a seeded store containing notes plus legacy
  `SDNoteInsight` rows opens with note bodies/tags/metrics unchanged, performs
  ordinary create/edit/move/delete/search/graph work, and records zero insight
  model construction, note-body analysis, sentiment/entity/topic write,
  reindex, debounce, or O(n²) relatedness task. Source/membership tests reject
  `NoteInsightService`, its coordinator/bootstrap seams, paid
  `ContentPersonalitySignals` dependency, and analysis jobs while exact
  compatibility fixtures demonstrate the chosen legacy model/migration
  boundary. Runtime/store migration proof remains serial debt.
- Ownership: Lane R owns composition, coordinator, service/membership pruning,
  and focused source tests. Confirm ownership before modifying the shared
  schema, note-deletion, or vault-index files; if protected or concurrently
  owned, record the exact compatibility seam and compile-tested handoff rather
  than editing them.

### `LR-LIVE-2026-07-15-026` — keep local hybrid note recall; remove the agent-core VaultRecall trace substrate

- Evidence: `VaultRecall/` is not the retained Shadow search itself. Its wiring
  explicitly mirrors `agent_core` retrieval traces with lexical/semantic/graph/
  recency/MMR signals, session/message/answer provenance, feature flags,
  synthetic stub detection, metrics, candidate previews, and a Settings health
  panel. `ContextualShadowsState`, `QueryRuntime`, `SearchIndexService`, and
  `VaultSyncService` currently produce/install/record these traces; EventStore
  writes them as chat/session events. The flag may default off and FFI may be
  absent, but the full trace/provider/metrics/UI source still enters Free and
  some Contextual Shadows paths record a production trace without consulting
  that flag.
- Required action: detach retained local note search/Shadow ranking from
  `VaultRecallContract`, `VaultRecallBridge`, flags, metrics, providers,
  candidate previews, Eidos and agent-core RRF/semantic signal envelopes, and
  EventStore chat trace writes. This removes trace/provider ontology, not the
  audited local dense index or deterministic RRF/hybrid ranker in addition
  011/030. Exclude `VaultRecall/**` and its health/diagnostic surface from Free
  membership; remove trace construction/install/reset/record calls and
  SearchIndex trace adapters rather than returning empty traces or claiming a
  local result has agent-core semantic/graph/MMR provenance. Preserve the
  note-only hit/result data actually consumed by Contextual Shadows and Halo.
- Historical boundary: preserve existing vault-recall JSON, message fields,
  EventStore rows, and diagnostic files/flags as historical bytes. If current
  chat/message/store decoding requires the old wire shape, isolate a bounded
  legacy DTO that never opens note/chat bodies, registers a provider, records
  a metric/event, displays candidates, or re-encodes the trace. Stale flag
  cleanup may remove only the exact obsolete preference; it must not scan or
  erase stored trace content.
- Intended proof: note-only lexical, semantic, and hybrid fixtures return the
  required allowed note IDs, snippets, ordering, cancellation, and diagnostics
  while recording zero VaultRecall/Eidos/agent-core semantic/graph/MMR
  provider, metric, notification, or EventStore trace activity. Local
  embedding and RRF execution remains covered by addition 011/030. Seeded
  legacy trace bytes decode or remain untouched according to the compatibility
  decision. Source/membership tests reject `VaultRecall/**`, trace flags/
  bridges/metrics/providers, `vaultRecallTrace` producers, Settings health
  rows/copy, and active `appendVaultRecallTrace` from the reviewed Free
  closure. Runtime and exact-artifact proof remains serial debt.
- Ownership: Lane R owns Contextual Shadows, QueryRuntime, SearchIndex/VaultSync
  trace detachment, target membership, and focused tests after reconciling the
  worker's active Shadow files. EventStore/SDMessage compatibility changes need
  ownership confirmation; Settings health rows are exact handoffs only. Do not
  edit a concurrently owned Shadow file until its current batch is complete.

### `LR-LIVE-2026-07-15-027` — unlink the unused MCP/agent hot-event `substrate_rt` from Free

- Evidence: the Free App Store target still runs `build-substrate-rt.sh`, links
  `-lsubstrate_rt`, defines `EPISTEMOS_LINK_SUBSTRATE_RT`, and admits
  `Engine/EventDrain.swift` plus `Engine/RustEventRingClient.swift`. The Rust
  crate and Swift mirror declare a hot event ring for cursor/edit/layout events
  together with MCP token chunks and agent frame ticks, and document possible
  raw-thought logging. Current Swift source has no production construction of
  `RustEventRingClient` or `EventDrain` and no producer outside their own type
  declarations; Free therefore builds and links an unused future-agent
  substrate rather than a dependency of retained deterministic editing.
- Required action: remove the `substrate-rt` build invocation, linker input,
  active compilation condition, Swift bridge/event-ring membership, and any
  Free test/build helper that requires those symbols. Do not keep an in-memory
  fallback, an unused protocol, dead-stripped static archive, no-producer ring,
  or editor-only subset merely to preserve future paid architecture. The crate
  and build script may remain outside Free target/build reachability for a
  future paid edition; this lane does not need to delete future-paid source.
- Boundary: do not confuse the 64-byte `GraphEvent` transport with the separate
  `DurableGraphEvent` model derived from committed deterministic graph
  mutations in `MutationEnvelope`/`EventStore`. Preserve that durable note/
  graph projection only where it passes the record-level policy and other live
  additions. Preserve historical raw-thought, agent-frame, MCP-token, or ring
  bytes untouched; Free must neither scan nor migrate them to prove removal.
- Intended proof: source/build-membership tests reject `-lsubstrate_rt`,
  `EPISTEMOS_LINK_SUBSTRATE_RT`, the Free prebuild invocation,
  `RustEventRingClient`, `EventDrain`, MCP/agent ring discriminants, and
  `ering_*` reachability while ordinary note editing and retained durable graph
  mutation fixtures remain source-reachable. The later serial artifact scan
  must find no `libsubstrate_rt`, `ering_*`, MCP-token, agent-frame, or raw-
  thought ring identity in the exact Free app. Do not run that artifact proof
  in Lane R.
- Ownership: Lane R owns `project.yml`, removal-specific source guards, and
  Free target/build membership after checking current ownership. Do not edit
  the generated `.xcodeproj` directly. Settings substrate/health files remain
  exact handoffs under the existing no-Settings rule; addition 022 owns their
  agent-core-facing composition closure.

### `LR-LIVE-2026-07-15-028` — stop Free from creating and heartbeating the Paperclip agent store

- Evidence: Free `AppBootstrap` unconditionally constructs
  `PaperclipStateStore` at launch and, outside tests, starts
  `PaperclipHeartbeatClock` in a utility task. Construction creates/opens
  `Application Support/Epistemos/paperclip_state.db` in WAL mode and creates
  `agent_ticks`, `cron_heartbeats`, and `agent_budgets` tables for session
  tokens, tool names, model-era cost accounting, agent budgets, and scheduled
  liveness. The clock immediately writes an agent heartbeat and repeats every
  two minutes. No retained deterministic Free note/edit/search path consumes
  this store; existing positive tests instead assert that the agent heartbeat
  is bootstrapped.
- Required action: remove Paperclip store/heartbeat construction, accessors,
  startup task, shutdown seams, source membership, and Free-positive tests.
  Exclude `State/PaperclipStateStore.swift` and
  `State/PaperclipHeartbeatClock.swift` from the Free target rather than
  renaming the agent ID, lengthening the cadence, skipping only the first
  write, retaining test-only construction, or replacing the loop with an idle
  task. Future-paid source and tests may remain outside Free membership.
- Historical boundary: preserve an existing `paperclip_state.db` plus `-wal`/
  `-shm` companions exactly where they are. Free must not open, checkpoint,
  migrate, query, vacuum, truncate, delete, or inspect their agent/tokens/tool/
  cost/heartbeat content. Normal application-support directory access for
  unrelated retained features remains allowed but must not touch the exact
  Paperclip paths.
- Intended proof: a cold-start source harness with an absent Paperclip database
  records no directory/file/table creation and no task; a sentinel legacy
  database and sidecars retain exact bytes and timestamps across all scoped
  Free source operations. Membership/contradiction tests reject Paperclip
  types, accessors, startup/shutdown calls, positive heartbeat expectations,
  `paperclip_state.db`, `agent_ticks`, `cron_heartbeats`, `agent_budgets`, and
  the heartbeat agent ID from the reviewed Free closure. Actual launch and
  filesystem observation remain serial integration debt.
- Ownership: Lane R owns bootstrap detachment, exact source exclusions, and
  removal-specific tests after checking current ownership. Do not edit broad
  shared runtime-test suites merely to turn a positive Paperclip assertion
  green; record their exact contradictory cases as test-owner handoffs unless
  they are explicitly assigned to Lane R.

### `LR-LIVE-2026-07-15-029` — local Shadow search is not an agent tool run

- Evidence: independent of addition 013's `SearchIndexService` path,
  `ShadowSearchService.search` constructs a UUID run, sequential tool-call ID,
  `AgentProvenanceActor.agent(id: "shadow-search-service")`, arguments/result
  JSON, and metadata for every ordinary note query. Its default
  `AgentToolProvenanceRecorder` persists requested, started, and completed or
  failed `shadow_search.search` events through `EventStore.saveAgentEvent`.
  The simpler `searchReportingErrors` path proves search result/error metrics
  do not require this paid run/tool ontology.
- Required action: remove the recorder field/initializers, synthetic run/tool
  construction, JSON/metadata helpers, sequence state, record/failure calls,
  EventStore writes, and agent provenance dependency from the retained Shadow
  service. Preserve note-only lexical, semantic, and hybrid search results,
  cancellation, latency/failure diagnostics, logging, stats, Halo error
  reporting, and the FFI boundary already constrained by P0-A and addition
  011/030. Do not inject a no-op recorder or relabel the actor/tool as
  deterministic telemetry.
- Historical boundary: preserve existing `agent_events` rows and their bounded
  compatibility model as required by addition 013; do not read, purge, rewrite,
  or project historical Shadow tool runs during normal Free search. Exclude
  `AgentToolProvenanceRecorder.swift` and active agent-event producer/model
  source from Free membership when reconciliation proves no reviewed retained
  caller remains.
- Intended proof: identical note fixtures through both Shadow search entry
  points preserve allowed hit IDs/snippets/order, errors, cancellation, and
  diagnostics while recording zero run IDs, tool-call IDs, JSON envelopes, or
  `saveAgentEvent` calls. Source/membership tests reject
  `shadow-search-service`, `shadow_search.search`, recorder injection, and
  agent-event APIs from the Free Shadow closure. Historical decoder/store-open
  and runtime observation remain serial debt.
- Ownership: reconcile this requirement with the worker's active P0-A Shadow
  batch before editing `ShadowSearchService`; do not overlap an in-progress
  file. Lane R owns the producer detachment and focused tests once that batch
  boundary is recorded. EventStore compatibility changes require the existing
  ownership check.

### `LR-LIVE-2026-07-15-030` — resume checkpoint for the embedding owner override

- Boundary resolved: the desired embedding-backed paragraph semantic search is
  part of Free V1. It is not deferred to a paid/future edition. This directly
  resolves the ambiguity recorded in the scoped ledger after the owner said
  paragraph semantic search matters. Re-read this complete prompt, record the
  newest owner wording verbatim, replace the ledger's lexical-only decision,
  and reconcile additions 004, 005, 011, 018, 021, 026, and 029 before another
  implementation edit.
- In-progress diff rule: do not use `git checkout`, reset, whole-file restore,
  or broad reverse patches. First inventory every hunk already made for the
  lexical-only transaction. Preserve notes-only vault crawling, chat-byte
  non-access, notes-only query API/ABI, paid-provenance filtering, agent-event
  detachment, cancellation/error honesty, cache bounds, and focused tests.
  Rework only hunks that make `free-lexical` the exclusive Free Cargo feature,
  gate all semantic code away from Free, remove the approved local model/vector
  path, force `NoModelTextEmbeddingLookup`, or assert that embedding identities
  are forbidden merely because they are embeddings. Inspect and re-read every
  changed region and the complete resulting diff.
- Allowlist rule: replace broad `AI`/`model`/`semantic`/`embedding` string bans
  with structural membership checks. The exact selected local embedding
  library, model identity/version/hash/license manifest, vector index, hybrid
  ranker, search-only diagnostics, and note-only ABI are positive Free members.
  They are not permission for June/Goose, generation/chat models, providers,
  credentials, prompts, tools, agent schemas/traces, remote inference, entity/
  sentiment analysis, or arbitrary model/download registries to return.
- Fail-first order: before restoring a real-model call path, add deterministic
  injected-vector tests that expose the current RRF/`0.2` threshold mismatch,
  whole-note-versus-paragraph dilution, duplicate-chunk results, stale chunks,
  missing/corrupt model fallback, chat-domain rejection, origin-note exclusion,
  and ranking determinism. Then implement the smallest coherent model-delivery,
  chunk/index, score-calibration, persistence, cancellation, and fallback
  transaction from addition 011. A compile-only presence test is not search-
  quality proof.
- Verification debt: Lane R may run only its authorized source/static checks.
  Record as serial debt the pinned real-model relevance evaluation, denied-
  network cold start, license/model receipt inspection, Cargo/Xcode build/tests,
  memory and hot/cold latency profiles, index-corruption/vault-switch runtime
  matrix, exact dylib/app dependency/export/hash scan, and manual search UX.
  `READY_FOR_SERIAL_INTEGRATION_VERIFICATION` remains forbidden until the
  source transaction is stable and all other owned removal additions are
  reconciled.
- Unchanged owner intent: the embedding override changes no other removal.
  June, Goose, `agent_core`, Omega/MCP, paid chat/generation/analysis, raw-
  thought/Harness, Paperclip, HTML regeneration, note insights, and all other
  canceled Free surfaces remain remove-not-hide work with historical user bytes
  preserved. Lane B and Settings remain out of scope.

### `LR-LIVE-2026-07-15-031` — select the search embedder by evidence, not by the current type name

- Owner-language clarification: the direct wording “it should remain in free
  build est embeddignservice thi maybe even look up better helper models etc.”
  preserves a Free local semantic-search capability and authorizes a current-
  model investigation. It does not preselect the Swift class named
  `EmbeddingService`, require a model replacement, or authorize every graph,
  clustering, editor-AI, prepared-model-registry, or generation caller that
  happens to share that class. Conversely, it does not authorize deleting the
  Rust Model2Vec/vector/RRF path before comparison merely because the owner
  mentioned `EmbeddingService`. Record this distinction in the ledger and
  correct any earlier entry that describes Model2Vec/usearch/RRF removal as an
  already-resolved owner decision.
- Current-source split: `Epistemos/Graph/EmbeddingService.swift` is a mixed
  graph/runtime facility. It can compute whole-node embeddings, push them to
  graph-engine, serve graph semantic search/clustering, and participate in a
  prepared-retrieval path; editor/meaning/AI consumers also call it. It is not
  presently the paragraph index behind the Halo/Contextual Shadows search.
  That search currently enters `epistemos-shadow`, where the original path
  embeds a `ShadowDocument` and uses usearch plus BM25/RRF. The worker's dirty
  diff disables NaturalLanguage in Free with `NoModelTextEmbeddingLookup` and
  separately makes Rust `free-lexical` exclusive. Reconcile both sides; do not
  mistake preserving the class for preserving search, or preserving search for
  keeping the class's unrelated consumers.
- Apple primary-source checkpoint: Apple documents
  `NLEmbedding.sentenceEmbedding(for:)` for sentence/phrase semantic
  similarity, including text retrieval and paraphrase-like matching, and says
  it can produce vectors for arbitrary sentences. Apple describes
  `NLContextualEmbedding` as token-sequence contextual vectors and explicitly
  directs semantic-similarity users to consider `NLEmbedding`; its
  `requestAssets` path downloads assets over the air. Therefore the Apple
  candidate must include the direct sentence-embedding API, not only the
  current averaged word lookup or hand-pooled contextual-token path. Never call
  `requestAssets` from bootstrap, indexing, typing, query, or a hidden warmup.
  Pin and test language, supported revision, dimension, availability, maximum
  input behavior, concurrency, and OS-version differences; unavailable or
  unsupported text stays lexical.
- Model2Vec primary-source checkpoint: the official MinishLab model card labels
  `potion-base-8M` an English, MIT-licensed, 7.56M-parameter general static
  model distilled from `bge-base-en-v1.5`; its F32 safetensors file is about
  30.2 MB and the current Rust code expects 256 dimensions. The official Rust
  implementation supports loading from a local path, so `from_pretrained` and
  Hub/cache resolution are not necessary for a bundled runtime. Test that an
  empty sandbox home, denied network, and poisoned Hugging Face environment
  cannot change the selected local path or cause credential/cache access.
- Better-helper candidates: the official `potion-retrieval-32M` card describes
  an English MIT-licensed retrieval-tuned static model, 32.3M parameters and
  512 dimensions, with a 129 MB F32 weights file. Its reported MTEB retrieval
  score is 35.06 versus 42.92 for `all-MiniLM-L6-v2`; treat those upstream
  figures as screening evidence, not Epistemos quality proof.
  `all-MiniLM-L6-v2` is an English Apache-2.0 384-dimensional contextual model
  intended for semantic search, with roughly 90.9 MB safetensors and truncation
  beyond 256 word pieces, but it would add a transformer/tokenizer runtime not
  currently justified by the Free closure. Do not add either model/runtime
  merely because its generic benchmark is higher. Also do not compare the
  repository's aggregate tree size when only a pinned minimal runtime file set
  would ship; record exact candidate files and uncompressed/compressed app
  impact instead.
- Mandatory bake-off: compare at least (A) Apple
  `NLEmbedding.sentenceEmbedding`, (B) bundled-local `potion-base-8M`, and (C)
  bundled-local `potion-retrieval-32M`. Include MiniLM only if a concrete,
  App-Store-compatible local runtime and dependency closure is mapped first.
  Use the same versioned paragraph chunks, labeled queries, negative notes,
  candidate pool, deduplication, and lexical baseline. Record per-candidate
  Recall@k, MRR/nDCG, exact-title regressions, false-positive rate, cold/hot
  encode and query latency, peak/resident memory, index bytes per paragraph,
  bundled bytes, first-use availability, supported languages, cancellation,
  concurrency, license/notice obligations, and maintenance surface. Use only
  checked-in synthetic/releasable fixtures for repository tests; private note
  text must never be uploaded to a model hub, benchmark service, or telemetry.
- Selection rule: among candidates that are locally reliable and clear the
  addition-011 safety, offline, App Store, resource, and release gates, choose
  the candidate with the strongest material and reproducible Epistemos
  retrieval effectiveness. Prioritize labeled paragraph paraphrases, Recall@k,
  MRR/nDCG, exact-title preservation, negative cases, and false-positive
  behavior; use model/bundle size only as a tie-breaker between candidates with
  effectively equivalent retrieval results. A larger candidate is not a defect
  and may win when its measured search improvement justifies its still-bounded
  runtime/artifact cost. Generic MTEB rank cannot override a failure on the
  Epistemos corpus, offline availability, or bounded resource use. If no
  candidate clears all hard gates, ship honest lexical fallback and retain the
  experiment as verification debt; do not claim hardened semantic search,
  silently download a model, or weaken the gates. Record the decision, rejected
  candidates, raw result table, effect sizes and repeatability, pinned source
  URL/commit or Apple revision, exact files/hashes, dimension, normalization/
  pooling, chunker version, and migration cost before changing target
  membership.
- Canonical-path rule: after selection, one note-search coordinator owns chunk
  generation, embed/query calls, vector persistence, lexical fusion, score
  calibration, cancellation, and diagnostics. Reuse or split the smallest
  neutral vectorizer from `EmbeddingService` if Apple wins; remove unrelated
  graph clustering/editor-AI/prepared-registry callers per the other additions.
  If Model2Vec wins, make its model loader local-path-only and remove the
  redundant Apple search implementation without removing independently allowed
  non-embedding deterministic graph behavior. Do not maintain two live
  paragraph indexes, two incompatible vector dimensions, or a graph-side
  semantic reranker plus Shadow-side hybrid ranker whose results are fused
  again without one measured contract. Preserve compatible old derived vectors
  until a bounded manifest-checked migration/rebuild makes them obsolete.
- Fail-first and proof order: the injected-vector chunk/rank/fallback tests in
  addition 030 still precede any real candidate integration. Then add adapter-
  contract tests that run identical paragraph/query vectors through the chosen
  Swift/Rust boundary and prove one-note deduplication, stable snippets and
  ordering, calibrated Halo visibility, lexical-only availability, typed model
  unavailability, cancellation, stale-publication prevention, and zero
  chat/provider/agent/graph-analysis access. Real-model, denied-network,
  resource, memory, latency, license, Xcode, and exact-artifact evidence remains
  serial integration debt; Lane R must name it precisely and cannot manufacture
  it with mocks.
- Research receipts to preserve in the ledger: Apple `NLEmbedding`, Apple's
  “Finding similarities between pieces of text,” Apple
  `NLContextualEmbedding`/`AssetsResult`, the official MinishLab Model2Vec and
  model2vec-rs repositories, official `potion-base-8M` and
  `potion-retrieval-32M` model cards/files, and the official
  `sentence-transformers/all-MiniLM-L6-v2` model card/files. Pin retrieval date,
  exact URL/revision, claim used, and whether it is upstream or project-local
  evidence. Lane R may research and source-test this closure; Settings/model-
  install UI, Xcode, app launch, artifact, and release actions remain forbidden.

### `LR-LIVE-2026-07-15-032` — the pre-bake-off Rust selection is a hypothesis, not a decision

- Newly observed ledger evidence: after reading the 1,518-line/hash
  `011172...` prompt but before receiving addition 031, the worker recorded
  “Selected canonical path” as Rust `epistemos-shadow` plus
  `model2vec-rs 0.2.1`, initially using bundled `potion-base-8M`, and rejected
  the Swift/Apple path. No common Epistemos relevance table, Apple sentence-
  embedding result, 8M-versus-retrieval-32M result, memory/latency profile, or
  exact Free artifact comparison preceded that declaration. It therefore does
  not satisfy addition 011/031 and is not an approved architecture decision.
- Immediate correction: before any architecture-specific source edit, re-read
  this revision and amend that ledger heading/status to “provisional Rust
  hypothesis.” Preserve its useful source map and candidate facts, but withdraw
  claims that the canonical path, initial model, or competing runtime has been
  selected/rejected. Do not delete the Apple candidate, remove
  Model2Vec/usearch/RRF as redundant, upgrade the crate, change target/resource
  membership, or add model files on the strength of that entry. The owner asked
  to audit and improve search, not to lock the first locally plausible design.
- Verified but insufficient crate fact: the official `model2vec-rs 0.2.1`
  package defines defaults `onig,hf-hub`; `hf-hub` enables optional `hf-hub`
  and `ureq`, while `local-only` is an empty marker and the official invocation
  is `--no-default-features --features onig,local-only`. It also supports local
  paths and byte-backed loading. This makes 0.2.1 eligible for the Rust
  candidate and materially safer than the current 0.1.4 default closure, but it
  is not search-relevance, App Store, binary-size, tokenizer/onig, migration,
  or repository-build proof. If the candidate advances, source/Cargo metadata
  must prove `hf-hub`, `ureq`, tokenizer HTTP features, credentials, and remote
  APIs are absent from the exact Free feature graph; serial artifact proof must
  confirm the same for the built dylib/app.
- Lane-R-safe next work: implement only model-neutral fail-first contracts that
  every candidate needs—versioned Unicode paragraph chunks, injected vectorizer
  adapter, bounded dimension/count validation, calibrated hybrid rank result,
  one-note deduplication, origin/provenance filtering, atomic manifest model,
  cancellation/stale-publication guards, and typed lexical fallback. Keep the
  real embedder behind a candidate boundary. These tests may demonstrate the
  current score/chunk/persistence defects and harden shared infrastructure; they
  may not be presented as evidence that a real model works or that one candidate
  wins.
- Decision-blocking debt: because Lane R cannot run/download/package candidate
  models, build Xcode/Cargo artifacts, profile memory/latency, or perform the
  manual relevance UX, it may be unable to complete the mandatory bake-off in
  this lane. If so, record the exact serial experiment inputs/commands/metrics
  and continue independent removal work, but keep canonical-model selection and
  final Free embedding membership explicitly unresolved. Do not resolve the
  uncertainty by compiling embeddings out of Free, silently shipping the 8M
  model, or marking `READY_FOR_SERIAL_INTEGRATION_VERIFICATION` while the source
  transaction falsely claims semantic-search completion.
- Delivery/ownership: this correction changes only the active search batch and
  its ledger; all other removal additions and the no-Settings/no-Lane-B/no-
  artifact boundary remain in force. A later evidence-backed choice may select
  the Rust hypothesis, Apple sentence embeddings, or another already-scoped
  candidate, but must record the addition-031 comparison first.

### `LR-LIVE-2026-07-15-033` — harden the mounted recall path, identity, and update lifecycle

- Mounted-path correction: the note workspace currently requests recall through
  `ContextualShadowsState`, `ContextualShadowsButton`, and
  `ContextualShadowsPanel`; the older `HaloController`/`HaloEditorBridge` score-
  threshold path is not the only relevant consumer and has no observed
  production bridge construction in the current source search. Preserve the
  addition-011 `2/61` versus `0.2` regression test because that contract still
  exists, but audit and fix the mounted state's independent ranking defects.
  Search quality proof must exercise the actual note-workspace request, panel,
  open, insert, edit, delete, relaunch, and fallback flow, not only the legacy
  Halo controller or Rust unit ranker.
- Heterogeneous-score evidence: mounted recall concatenates Shadow hits with
  `SearchIndexService`/`InstantRecallService` fallback hits and
  `rankedUniqueHits` keeps the largest raw `similarity` per note. Shadow may
  emit raw RRF sums around `0.03`; the vault fallback synthesizes scores in
  `[0.05, 1]`; Instant Recall emits term-match ratios; title intent then adds
  boosts as large as four. Those values are not comparable confidence units,
  so current dedupe can discard the better passage or reorder channels by
  numeric scale rather than evidence. Define a typed per-channel result with
  original rank/score and fuse normalized ranks or calibrated confidence once.
  Do not feed a raw RRF sum into `RecallHit.similarity` and then compare it to
  fallback cosine-like/position scores. Prove exact title, lexical, semantic-
  only, shared-channel, and false-positive fixtures through the mounted merger.
- Degradation evidence: fallback currently runs when the count of converted
  Shadow hits is below `defaultTopK`, not when lexical or semantic channel
  health says it is needed. A degraded backend can return enough weak rows to
  suppress fallback; a healthy backend with fewer excellent rows triggers a
  second search and heterogeneous rerank. Return explicit lexical status,
  semantic status, generation/model identity, and bounded candidate counts.
  A semantic failure plus successful Shadow BM25 is a degraded success, not a
  fatal empty result; a total backend failure may use the canonical lexical
  fallback without hiding the recorded failure class.
- Query-shape evidence: `ContextualShadowsState.recallQuery` combines natural
  sentence/paragraph text, extracted title intent, and repeated ranked keywords
  into one string that is sent to both lexical and dense search. Keyword/title
  expansion can help BM25 while distorting a paragraph embedding. Introduce one
  bounded `NoteRecallQuery` carrying the natural focus text, normalized lexical
  terms, optional explicit title intent, origin page ID, vault identity, limit,
  and request generation. The dense adapter embeds only the natural semantic
  field (plus a measured model-specific prefix if its pinned contract requires
  one); lexical/title channels consume their own fields. Tests must prove that
  title/keyword expansion cannot change the dense vector input.
- Origin-filter evidence: the mounted state knows `originDocId`, but
  `ShadowSearchServicing` and the notes-only FFI search call accept only text and
  limit. The current note is removed only after the backend spends one of its
  top-16 slots and completes fusion. Carry origin page identity to the backend,
  filter it before candidate truncation/final rank, and reject mismatched or
  empty identity rather than infer from title/body. Still apply a caller-side
  defensive filter and test that 16 high-scoring chunks from the origin cannot
  starve every other result.
- Document-identity evidence: bootstrap uses a vault-relative Markdown path as
  `ShadowDocument.doc_id`, while `NoteDetailWorkspaceView` opens a Shadow hit by
  passing `hit.id` to `NoteWindowManager.open(pageId:)`, which fetches
  `SDPage.id`. Treat cache/chunk identity, stable page ID, and relative source
  path as separate fields. Resolve and persist an unambiguous page ID during
  indexing, return that page ID for open/dedupe/origin filtering, retain the
  relative path only as bounded non-presented source identity, and reject a hit
  whose current allowed page cannot be resolved. Add a fixture where filename,
  relative path, title, and page UUID are all different; clicking the result
  must open the correct current note.
- Bootstrap/update parity evidence: bootstrap reads only the first 200,000
  bytes of Markdown and derives the vault key from the vault folder; the
  incremental `AppBootstrap` reindex path loads a different body representation
  and currently constructs `ShadowDocumentDTO` without `originVaultKey`.
  Therefore an edit can change both searchable coverage and provenance for the
  same note, while a relaunch can change it back. Route bootstrap, import,
  create, edit, rename/move, and rebuild through one bounded note-to-chunks
  projector. It must be Unicode-safe at byte boundaries, declare deterministic
  behavior for over-limit notes, and produce identical chunk IDs/hashes/vault
  identity from the same canonical note revision. Test a unique paragraph
  beyond the old 200 KB prefix and identical pre/post-relaunch results; never
  silently cut a UTF-8 scalar or claim a fully indexed note when truncated.
- Stale-deletion evidence: production source constructs `enqueueInsert`, but no
  current production caller of `ShadowIndexingService.enqueueRemove` was found.
  A deleted page makes `shadowPageIndexStage` return nil, and a bootstrap pass
  inserts current files without reconciling old note IDs, so stale deleted or
  renamed documents/chunks can survive in derived search. Add an explicit
  stable-identity remove/replace event and a bounded bootstrap reconciliation
  generation. Atomically replace all chunks for one note, remove chunks absent
  from the new revision, remove deleted/renamed old identities, and never let a
  failed semantic vector update roll back or suppress a valid lexical update.
  Test insert-edit-rename-move-delete-recreate plus crash/cancel at each publish
  boundary and prove the original Markdown remains untouched.
- Duplicate fallback evidence: `InstantRecallService` is a MainActor-owned full-
  text dictionary; its `searchAsync` directly calls synchronous search, which
  lowercases/scans every stored note on the actor despite comments claiming a
  detached utility path. Bootstrap also schedules a 1.6-second delayed prewarm,
  duplicating note bodies already held by the durable lexical indexes. Map all
  callers, then retain at most one bounded canonical lexical fallback. Prefer
  the existing app FTS/Shadow BM25 path after it passes lifecycle tests; remove
  the duplicate Instant Recall prewarm/index and misleading async facade rather
  than keeping an unbounded typing-time scan. If temporarily retained, move an
  immutable bounded snapshot off MainActor with real cancellation and memory/
  latency tests; do not call a synchronous MainActor scan `async`.
- Active-diff compile guard: the current dirty
  `ContextualShadowsState.recallRankingScore` removed the local
  `noteFirstBoost` declaration/function but still references
  `noteFirstBoost` in several title-intent branches. Re-read the active diff and
  add Swift parse/source tests before further semantic work; remove all stale
  note-versus-chat boost logic consistently rather than leaving an undefined
  identifier or reintroducing chat. This is a transient owned-diff defect, not
  permission to edit protected UI or Settings.
- Proof/ownership: Lane R owns these search state/service/DTO/FFI/indexing and
  focused-test seams after reconciling current file ownership. Preserve the
  note-workspace UI and exact Lane B boundary; `NoteDetailWorkspaceView` may be
  inspected for the existing recall/open seam but edited only within the narrow
  authorization already stated. Xcode, app launch, model execution, artifact,
  and manual-click proof remain serial debt, with precise fixtures and expected
  result identities recorded now.

### `LR-LIVE-2026-07-15-034` — correct the first candidate-neutral semantic contract before it ossifies

- Newly observed source: the worker added untracked
  `epistemos-shadow/src/backend/free_semantic.rs` and
  `epistemos-shadow/tests/free_semantic_contract.rs` as model-neutral injected-
  vector work after reading addition 032. Keeping this work model-neutral is
  allowed, but its current contracts and tests are not yet sufficient proof.
  Re-read additions 033–034 before extending or wiring it, inspect every current
  hunk, and treat the following as fail-first corrections rather than reasons
  to discard the module or select a model.
- No invented calibration: the module maps cosine from `[-1,1]` to `[0,1]`,
  calls a per-result RRF normalization “confidence,” and hard-codes
  `0.45 lexical + 0.45 semantic + 0.10 RRF`. No Epistemos relevance evidence
  justifies those transforms or weights; an orthogonal vector becomes `0.5`,
  and a rank-one singleton can receive the same normalized RRF value as a
  rank-one hit supported by both channels. Keep raw channel score and rank
  typed separately. Use a deterministic rank-fusion policy whose parameters
  are injected/versioned and whose display score is not labeled probability or
  calibrated confidence until the addition-031 corpus actually calibrates it.
  Cross-channel agreement must remain observable and must not normalize away.
- Adversarial exact-match proof: the current “exact lexical title does not
  regress” fixture can tie the exact lexical-only note with the semantic-only
  note at `1.0`, then pass because ID `exact` sorts before ID `related`. Reverse
  the IDs/titles and vary insertion order; a pinned exact-title/rare-token rule
  must win independent of lexicographic identity. Add near-title negatives and
  a semantic hit with higher raw cosine so the assertion proves policy rather
  than tie-breaking. Deterministic ID ordering is only the final tie-breaker,
  never relevance evidence.
- Numeric validation: reject empty, wrong-dimension, zero-norm, NaN, positive/
  negative infinity, overflowed norm/dot product, and non-finite input channel
  scores before sorting or persistence. `f32::clamp` and `partial_cmp(None)` do
  not make NaN a valid deterministic score. Bound dimension, vector count,
  values, norms, accumulated weights, and output score; return a typed semantic
  degradation while preserving valid lexical hits. Add adversarial vectors and
  ensure no non-finite value crosses Rust/JSON/Swift.
- Stable chunk identity: current IDs include the whole-note hash and ordinal,
  so editing one paragraph changes every chunk ID and forces a full-note vector
  rebuild. Define separately (1) stable note/page identity, (2) stable logical
  chunk identity or source anchor, and (3) content revision hash. An unchanged
  paragraph should retain its vector across an unrelated edit when occurrence/
  source disambiguation is safe; a changed paragraph must never reuse the old
  vector. Duplicate identical paragraphs need distinct deterministic occurrence
  identities without result duplication. Test edit-before/edit-after, inserted
  earlier paragraph, reordered headings, duplicates, rename/move, and unchanged
  tail reuse rather than only proving that every old ID disappeared.
- Range/kind correctness: the synthetic title chunk currently uses body byte
  range `0..<0`, while body blocks are trimmed after their source ranges are
  captured. Add explicit chunk kind (`title`, heading, paragraph/code as
  supported), optional range for non-body chunks, and exact trimmed UTF-8 body
  range/hash for insert/preview. Never use a zero body range to represent the
  title or return whitespace/newline bytes outside the displayed snippet. Split
  preferably at paragraph/sentence/word/grapheme boundaries with a hard byte
  fallback; test emoji, combining marks, CJK, RTL, CRLF, fenced code, a single
  overlong token, headings, empty blocks, and overlap progress.
- Bound consistency: the module accepts roughly 1 MiB of title+body but defaults
  to at most 128 chunks of 2,048 bytes, so a valid input can fail around one
  quarter of the declared note bound even before overlap. Make byte/chunk/
  overlap limits mathematically consistent and return an explicit coverage
  report (`complete` or bounded partial with omitted ranges/reason), not a false
  fully-indexed claim. The addition-033 unique paragraph beyond 200 KB must
  either be found under the declared bound or produce a truthful, surfaced
  partial-index status; bootstrap and incremental paths must agree.
- Atomic catalog/generation: current `ChunkCatalog.upsert` removes old chunks,
  silently filters mismatched replacement chunks, and then mutates maps one by
  one; it is not atomic if validation/allocation/persistence fails. Standalone
  `remove_note` also changes visible state without incrementing generation.
  Validate note ID, vault ID, unique chunk IDs, bounds, ranges, hashes, and full
  replacement first; stage a new per-note map; then swap one generation or
  return an error with the prior generation unchanged. Every successful insert,
  replace, delete, rebuild, and vault reset advances a monotonic generation;
  canceled/stale work cannot publish against a newer generation.
- Strict vault/note boundary: candidate-neutral `NoteInput` still accepts a
  caller-provided domain string and optional vault key. The Free constructor
  should be note-only by construction and require the current canonical vault
  identity; keep any old string domain or nil metadata only in a bounded legacy
  projection that cannot enter chunking. The catalog and query must be bound to
  one vault manifest, and a mismatched/missing-vault chunk must error rather than
  be silently filtered or pass every vault. Test two vaults with identical page
  IDs/content and prove zero cross-vault hit or mutation.
- Digest/source-of-truth: the local FNV-style 64-bit `stable_hash` is not the
  exact SHA-256 content/model/manifest digest required by additions 011/030.
  Use one reviewed canonical digest representation with domain separation and
  collision-safe equality checks; record algorithm/version in the manifest.
  Do not create a second `RRF_K` source of truth divergent from the existing
  ranker—centralize or inject the versioned rank policy and test parity.
- Proof honesty: the ledger says the fail-first fixture covers manifest
  mismatch and cancellation, but the currently observed test file has no
  manifest or cancellation case. Amend the ledger to distinguish intended from
  implemented tests. Add actual manifest schema/version/vault/model/dimension/
  chunker/generation mismatch fixtures, cancellation and stale-publication
  fixtures, delete generation, numeric adversaries, vault isolation, and the
  active mounted-path DTO/score contract. Run only authorized source/static
  checks and do not turn a pure module test into a real-model/search-quality or
  persistence claim.
- Integration boundary: do not yet expose this module as proof that the
  `free-lexical` production backend is semantic. Keep the real vectorizer,
  persistent ANN, FFI, mounted Swift merger, model resources, and candidate
  dependencies outside until their respective contract and evidence gates
  pass. Preserve valid worker changes; correct surgically with no reset,
  Settings, Lane B, Xcode, app, artifact, or model execution.

### `LR-LIVE-2026-07-15-035` — make mounted search readiness, mutation durability, preview, and FFI bounds honest

- Debounce defect: `ShadowIndexingService.scheduleFlush` treats any non-canceled
  `flushTask` as still scheduled, but the delayed task is not cleared when it
  finishes. A completed Swift `Task` can therefore remain non-canceled and make
  a later ordinary enqueue return without scheduling another drain. Do not
  paper over this by relying on the current incremental caller's immediate
  `flushNow`. Give the queue an explicit idle/scheduled/draining lifecycle,
  clear the exact task by identity, and test enqueue → automatic flush → wait →
  enqueue → automatic flush, cancellation during the delay, max-batch pressure,
  and concurrent enqueue while a drain completes.
- Mutation-loss defect: `drain` snapshots and clears `pending`, logs each insert/
  remove failure, continues, and then can report a successful flush; failed
  mutations are neither retried nor returned to the caller. Bootstrap and page
  reindex progress report completion without a typed insert/remove/flush
  receipt. Define bounded retry/backoff or an explicit dirty/rebuild-required
  state, merge newer same-page mutations without resurrecting an older one,
  and return a generation-scoped receipt with attempted/applied/failed IDs and
  durable-flush status. Never call a note revision searchable or complete after
  an insert/vector/persist failure. Tests must inject failure before, during,
  and after replacement and prove the valid lexical generation remains usable.
- Readiness defect: `AppBootstrap` configures `ShadowSearchService` immediately
  after opening the handle, before the bootstrap crawl, absent-page
  reconciliation, manifest validation, or final flush. It even records the
  service as operational without a stats/readiness receipt. Keep the canonical
  lexical fallback available during validation/rebuild, but publish a new
  search generation only after its vault manifest and note set are internally
  consistent. Model search readiness as typed states such as unavailable,
  validating, lexical-ready/semantic-degraded, rebuilding-partial, and hybrid-
  ready; do not infer health from handle existence, hit count, or a nil error.
  A corrupt/stale semantic generation must not prevent a valid BM25 generation
  from becoming ready.
- Free ETL closure: after the Shadow bootstrap, `AppBootstrap` still calls
  `RustEtlQueueStatsClient`, `RustEtlQueueDispatchClient.enqueueVaultWalk`, and
  `RustEtlQueueWorkerClient`; `RustShadowFFIClient.swift` retains the
  `agent_coreFFI` ETL symbol declarations and Free no-op fallbacks. This second
  whole-vault walker/validation queue does not build the retained paragraph
  search index, broadens file discovery beyond `notes/**/*.md`, and belongs to
  the canceled `agent_core` closure. Remove the AppBootstrap ETL scheduling and
  the Free ETL wrapper/type/symbol reachability rather than calling nil stubs.
  Do not edit the Settings-owned health row; record its exact serial handoff so
  it stops consuming the removed snapshot type. Prove cold Free search makes
  no ETL queue/database, whole-vault walk, worker, or `agent_coreFFI` call.
- Vault-file containment: bootstrap currently trusts a standardized lexical
  path prefix and then opens discovered Markdown. Define one canonical vault/
  notes-root identity, reject traversal, symlink/alias escape, non-regular
  input, and root changes between discovery and open, and obtain metadata plus
  content through a bounded race-aware read. A path under `notes/` that resolves
  outside the canonical notes root must never be read or indexed. Test symlink
  file/directory escape, similarly prefixed sibling roots, rename between walk
  and read, invalid UTF-8 at the byte limit, and a vault moved or switched
  during bootstrap. This is local privacy hardening, not permission to crawl
  other file kinds.
- FFI output/input bounds: `RustShadowFFIClient.search` currently accepts any
  positive `Int` limit, turns a raw NUL-terminated C pointer into an unbounded
  Swift `String`, decodes an unbounded JSON array, and trusts hit strings and
  scores. Put hard query-byte/result-count/title/snippet/source/JSON-byte limits
  and finite-score validation on both sides of the ABI. Prefer an ABI that
  carries an explicit byte length or writes into a caller-bounded buffer so a
  corrupt backend cannot force an unbounded `String(cString:)` scan. Reject
  embedded-NUL input before `withCString`, integer conversion/size overflow,
  extra results, invalid UTF-8/JSON, invalid page/vault identity, and NaN/Inf;
  free exactly once on every return path and degrade to the valid lexical path
  when possible. Add malformed mock-ABI fixtures; source inspection alone is
  not memory-safety or panic-containment proof.
- Mounted display/preview truth: `ContextualShadowsPanel` formats every raw
  `RecallHit.similarity` as a percent even though the active sources carry RRF,
  BM25-derived, term-ratio, and guessed position values. Until the pinned corpus
  calibrates one display metric, show neutral source/support/rank information or
  no number; never label a clamped ordering score as similarity/confidence
  percent. The expanded preview also starts an `@MainActor` task that calls
  `NoteWindowManager.currentBody(mapped: true)`, synchronously fetches/reads the
  entire note, and then parses all paragraphs and headings. Load a bounded
  current-revision preview asynchronously by stable page ID and matching chunk
  range, keep live-editor access narrowly on MainActor, cap body/paragraph/
  outline work, and reject a stale/deleted/moved result. Cancellation must stop
  publication; copy/insert/open must use the exact current allowed page and
  source text, not stale index bytes or a relative-path ID.
- Proof and sequencing: addition 034's candidate-neutral corrections remain the
  active batch. Re-read 035 before the next mounted lifecycle/FFI/composition
  batch, amend the ledger with this exact observed evidence, and add fail-first
  source/unit fixtures before production changes. These requirements do not
  authorize a real model, Cargo build/test, Xcode, app launch, Settings edit,
  Lane B work, artifact scan, broad UI redesign, or release/readiness claim.

### `LR-LIVE-2026-07-15-036` — preserve compatible vectors and make the lexical store/query a real hybrid foundation

- Destructive-open contradiction: current `free_backend::open_at` can delete
  `vectors/`, rebuild/remove Tantivy rows in place, and write a
  `.free-lexical-v1` marker merely because the lexical build opened or
  `docs.json` exceeded 32 MiB. That was part of the superseded remove-
  embeddings transaction. Stop deleting compatible vector/model assets or
  labeling the canonical Free cache lexical-only. Read and validate a bounded
  manifest first; open the last complete generation read-only while staging a
  replacement; quarantine only the exact derived generation proven corrupt or
  incompatible; and atomically switch the manifest after lexical, chunk-map,
  and vector artifacts agree. A missing/old semantic generation degrades to
  lexical without destroying evidence needed for migration or the bake-off.
- Split-store atomicity: `insert_document` currently commits Tantivy before
  inserting the document into the `RwLock<HashMap>`; remove does the reverse;
  `flush` later renames a separate `docs.json`. A lock poison, allocation,
  encode/write/rename, commit, reload, or process crash can leave these stores
  at different revisions. Do not mutate the published generation piecemeal.
  Stage/validate one note replacement and its lexical/chunk/vector metadata,
  commit it under a generation receipt, then publish once; or preserve the
  previous visible revision. Startup must detect and recover incomplete
  generations without pairing a new lexical row with an old/missing body or
  vector. Replace every lock `expect` with typed degradation and prove crash
  points and poisoned-lock behavior without claiming Rust `catch_unwind` makes
  partial state safe.
- Input/storage bounds: the backend itself accepts unbounded `doc_id`, title,
  body, document count, and cumulative stored bytes, even though bootstrap's
  prefix and startup's 32-MiB/10,000-document limits differ. Incremental reindex
  can therefore create a cache that the next launch deletes or refuses. Define
  one mathematically consistent policy at the notes-only DTO boundary and use
  checked arithmetic before allocation/serialization/indexing. Return explicit
  complete/partial coverage as addition 034 requires; do not silently index a
  prefix. Reconcile the 10,000-document `docs.json` cap with Tantivy's
  1,000,000-row enumeration cap, and bound startup reconciliation work/time so
  a large or corrupt cache cannot cause one commit/reload per stale row on cold
  launch. Preserve the prior healthy generation or lexical fallback throughout.
- Canonical content/source: Tantivy stores title/body while `docs.json` and the
  in-memory map store them again; search fetches stored title/body into
  `LexicalHit` and then ignores those fields in favor of the map. Map the actual
  memory/disk duplication and designate one versioned metadata/snippet source
  for the published generation. Do not keep multiple full note-body copies
  merely to join a hit. The durable Markdown remains source of truth; derived
  storage must be bounded, locally rebuildable, revision-checked, and unable to
  overwrite user content.
- Lexical-query correctness: natural editor prose currently enters Tantivy's
  `QueryParser`, so punctuation, quotes, `+`/`-`, `AND`/`OR`, and other syntax
  can change meaning as query language. When parsing fails, the fallback ANDs
  every alphanumeric token against the body field only, so an explicit title or
  rare title token can disappear precisely on hostile/Unicode input. Build a
  typed, escaped lexical query from `NoteRecallQuery` with separate exact/
  normalized title, phrase, and bounded body-token clauses; user prose is data,
  never raw query syntax. Define token/phrase/operator/Boolean-clause caps,
  language/diacritic/case normalization, stop-word and empty-query behavior,
  deterministic tie-breaking, and a pinned exact-title rule that hybrid search
  cannot regress. Test quotes, field-like text, leading minus/plus, Boolean
  words, punctuation-only, emoji, combining marks, CJK/RTL, diacritics, very
  long terms, repeated terms, and titles absent from the body.
- Snippet correctness/performance: the lexical backend lowercases the complete
  body per hit, finds an offset in the lowercased string, and applies that byte
  offset back to the original string. Unicode case mapping may change byte
  length, and full-body lowercasing/allocation for each top hit violates the
  bounded typing path. Use the indexed matching chunk or an analyzer-consistent
  original-source range, validate it against the current content revision, and
  build a bounded Unicode-safe snippet without rescanning every full note.
  Highlight/preview ranges must never split a scalar/grapheme or point into a
  different revision; fall back to a bounded note head with an honest reason.
- Proof/ownership: addition 034 remains the only current Rust implementation
  batch. Treat 036 as the required fail-first backend/persistence/query batch
  after rereading the final prompt hash; do not restore the old semantic
  backend, choose a model, run Cargo/Xcode/app/model code, or touch Settings/
  Lane B. Source-only tests can expose these defects and specify adapters, but
  real crash durability, mmap safety, performance, relevance, and artifact
  closure remain serial integration evidence.

### `LR-LIVE-2026-07-15-037` — audit the rewritten candidate-neutral contract before accepting its proof

- Current saved revision: the worker rewrote `free_semantic.rs` and its fixture
  under addition 034. Preserve the useful direction—note-only constructor,
  explicit chunk kinds/ranges/coverage, raw channel evidence, injected rank
  policy, finite-vector checks, SHA-256 framing, vault-bound publication token,
  and staged map swap—but do not record this batch as passing until the exact
  source/test defects below are corrected and re-read.
- Immediate compile closure: the module imports `sha2::{Digest, Sha256}`, but
  `epistemos-shadow/Cargo.toml` currently has no direct `sha2` dependency.
  Transitive copies in other crates do not make the import available. Either
  use one already-reviewed in-crate canonical SHA-256 implementation or add the
  smallest pinned direct checksum dependency with version/license/lock and Free
  artifact accounting. A checksum-only dependency is candidate-neutral and
  does not select an embedder, but it must be an explicit reviewed source-
  manifest change; Cargo execution remains forbidden in this lane. Add a source
  guard so an undeclared import cannot be called verified.
- Fixture contradiction: in
  `stable_chunk_identity_reuses_unchanged_tail_but_not_changed_text...`, the
  changed-text assertion compares `after_edit` against `before.chunks[0]`.
  Current projection order makes that first chunk the unchanged title
  `Project`, so a correct stable-title implementation fails the test while a
  whole-note-invalidating title ID passes it. Select the original and changed
  `Alpha ... paragraph` chunks by explicit kind/text, assert their logical IDs
  and content revisions differ, and separately assert the unchanged title and
  tail retain identity/reusable vectors. Run the same cases with a leading
  paragraph insertion, heading insertion/reorder, and duplicate identical
  paragraph inserted before/between duplicates; occurrence identity may not
  silently attach an old vector to the wrong duplicate.
- Projection integrity: `validate_projection` presently checks content-digest
  shape, but does not recompute `logical_id`/`chunk_id`, cannot verify that a
  body range slices to `chunk.text`, accepts different arbitrary valid-looking
  `note_revision_digest` values among chunks, and does not tie that revision to
  the projection. Carry the canonical note revision and sufficient source/
  occurrence evidence in the staged projection. Recompute every domain-
  separated ID/digest, require all chunks to share the projection revision,
  validate exact ranges against the bounded canonical body (or an equally
  strong trusted-projector receipt), and reject swapped text/range, forged ID,
  mixed revision, wrong kind, wrong occurrence, wrong vault/note, and altered
  coverage fixtures without mutating the prior catalog.
- Manifest integrity: the manifest currently proves field shape only; it is not
  bound to a chunk-map/note-set digest, chunking-policy digest, rank-policy
  version, normalization contract, semantic availability, or staged vector/
  lexical receipt. `remove_note` and `reset` then increment and rewrite its
  generation fields without accepting/revalidating a new manifest, which can
  claim synchronized vector and lexical generations that were never published.
  Make every publish/replace/delete/reset accept or produce one validated
  generation receipt tied to the exact staged state; keep the previous manifest
  unchanged on failure. Clear or replace—never fabricate—semantic readiness on
  reset/delete. Test tampering of each manifest field/digest and prove `digest()`
  changes exactly when governed state changes.
- Overflow and boundary honesty: generation uses `saturating_add`, so at
  `u64::MAX` a successful-looking mutation can stop being monotonic. Return a
  typed overflow/rebuild-required error with state unchanged. Bound/canonicalize
  vault ID, note ID, chunk ID, exact title, origin ID, request limit, lexical/
  semantic hit counts, rank, rank-policy version, and aggregate candidate work;
  trimming a string is not canonical identity. Reject controls, embedded NUL,
  path-like ambiguity as applicable, overlong UTF-8, duplicate channel IDs, and
  origin/vault mismatch before ranking. Upstream origin exclusion before
  candidate truncation remains required; the catalog's final defensive filter
  alone does not prove starvation resistance.
- Numeric/proof completion: extend fixtures beyond NaN query, one infinity
  vector, wrong dimension, and invalid channel rank. Include both signs of
  infinity, NaN/Inf channel scores, near-zero/negative/orthogonal vectors,
  maximum finite magnitude, accumulated dot/norm/rank bounds, vector/hit/count/
  dimension/limit caps, duplicated ranks, singleton-versus-two-channel support,
  and semantic degradation with hostile ignored inputs. Prove no output or
  manifest field is labeled probability/confidence and no non-finite value can
  reach JSON/Swift later. Do not claim real relevance, persistence, FFI, or
  mounted-search behavior from these injected fixtures.
- Sequence: correct addition 037 surgically inside the existing 034 module and
  fixture, amend the ledger's actual-versus-intended proof, perform authorized
  source/static checks, then reread the latest prompt before beginning 035 or
  036. Do not wire this module, choose/download/run a model, restore semantic
  Cargo features, run Cargo/Xcode/app code, or touch Settings/Lane B.

### `LR-LIVE-2026-07-15-038` — give retained search assets their own fail-closed manifest and artifact boundary

- Manifest identity correction: the Free release gate currently requires
  `Contents/Resources/model_manifest.json` to be absent. Preserve that negative
  rule because the existing manifest and registry describe general prepared
  retriever/generator models, runtime routing, download paths, adapters, and
  `trustRemoteCode`; retaining paragraph search does not restore that product.
  If the bake-off selects a bundled model, create a distinct search-only
  resource namespace such as `Contents/Resources/SearchEmbedding/manifest.json`
  with an exact allowlist. Do not rename, copy, conditionally hide, or subset the
  general manifest into Free. If the Apple sentence-embedding candidate wins,
  record that no bundled search-model payload is expected and prove its exact
  OS/language availability and degradation contract instead of fabricating an
  empty asset manifest.
- Do not reuse `PreparedModelRegistry` wholesale. Current
  `LocalModelInfrastructure.swift` accepts an environment-selected manifest,
  a source-checkout fallback, tilde-expanded/download paths, generator roles,
  runtime kinds, adapters, and `trustRemoteCode`; it uses unbounded
  `Data(contentsOf:)`, treats `fileExists` as asset validity, derives sibling
  index paths from an arbitrary source root, multiplies dimension/count/float
  size without checked overflow, can retain an unbounded JSONL remainder when
  no newline occurs, and declares freshness from mtimes. Those are not an
  App-Store-bundled, notes-only embedding trust boundary. Remove the general
  registry/bootstrap consumers from Free as already required. Define the
  bounded candidate-neutral receipt/parser envelope now, but instantiate its
  minimal immutable candidate-specific descriptor only after a candidate wins.
- Search-asset receipt: the bundled-candidate manifest must be versioned and
  canonical, have a hard byte/depth/entry bound and reject unknown or duplicate
  fields, and bind the exact model/repository revision, every required asset
  relative path/size/SHA-256, tokenizer/config/license/notice digests, runtime
  adapter/version, vector dimension/type/normalization, query/document prefix
  contract, maximum input tokens/bytes, supported languages, minimum OS/arch,
  chunker compatibility, and total package bytes. Paths must be relative
  regular files canonically contained below the read-only app resource root;
  reject absolute/traversal paths, symlinks/aliases, special files, case or
  Unicode-normalization collisions, missing/extra files, size/digest mismatch,
  and a resource that changes between validation and open. No environment,
  home/cache, source-tree, network, credential, or user-writable fallback may
  satisfy production readiness.
- Keep asset truth separate from derived-index truth. The search-asset receipt
  identifies immutable executable/model inputs; the addition-034/037
  generation manifest identifies one vault's rebuildable chunk/lexical/vector
  outputs. Bind each published derived generation to the exact asset-receipt
  digest, candidate adapter, dimension/normalization, chunker/rank-policy
  versions, vault/note-set digest, and staged file receipts. A corrupt, absent,
  or incompatible asset/index must yield typed semantic unavailability while
  the last valid lexical generation remains usable. Never delete user notes,
  general installed-model bytes, compatible historical vectors, or an old good
  generation merely because the selected search receipt fails validation.
- Swift boundary evidence: the current Free `EmbeddingService` aliases Apple
  lookup to `NoModelTextEmbeddingLookup`, while the non-Free class also owns
  graph-node embeddings, O(n-squared) semantic-neighbor recomputation,
  clustering/prepared-index state, and graph-engine FFI. Preserve the owner's
  search capability, not those mixed responsibilities. If Apple wins, implement
  the measured `NLEmbedding.sentenceEmbedding` note-search adapter rather than
  silently restoring current word averaging or device-asset-dependent
  `NLContextualEmbedding`. If a bundled candidate wins, expose only its bounded
  note-search adapter. In either case, remove graph/editor/AI-partner/prepared-
  registry callers and prove the retained adapter cannot construct a general
  semantic graph product.
- Swift numeric/concurrency bounds: current `averageEmbedding` accepts
  unbounded text/token work and returns contextual or averaged vectors without
  finite/norm validation; batch construction uses unchecked
  `ids.count * dimension`, unbounded flattening, and unchecked `UInt32`
  conversions; `computeTask` is `nonisolated(unsafe)` across cancellation and
  replacement. The canonical search adapter must cap query/paragraph bytes,
  tokens, dimension, batch/vector count, memory, concurrency, and time; use
  checked allocation/FFI conversions; validate every component and required
  normalization; and publish through an actor/generation token so a canceled or
  superseded task cannot install results. Do not retain graph-engine batch APIs
  merely as the easiest route to note search.
- Release and fixture proof: make the edition-aware gate positively require the
  exact chosen search resource/manifest and allowlisted dependency closure when
  a bundled candidate is selected, while still rejecting
  `model_manifest.json`, June, generation/provider assets, Hub/HTTP/download
  symbols, credentials, agent runtimes, and unlisted model files. Add positive
  and adversarial fixtures for manifest truncation/oversize, duplicate keys,
  unknown fields, integer overflow, symlink/alias/traversal, Unicode/case path
  collision, swapped tokenizer/config, file mutation, digest mismatch,
  missing/extra payload, hostile environment variables, denied network, and
  lexical degradation. Legacy release scripts that positively require
  `model_manifest.json`, `agent_core`, or Omega are not Free proof and must not
  be invoked or cited as such. Exact built-app resources, binary symbols,
  dependency graph, offline launch, memory/latency, license notice, and model
  quality remain serial integration evidence.
- Sequence: finish and ledger addition 037 first. Then use addition 038 to
  define candidate-neutral manifest parser/fixture and release-gate expectations
  without adding a model file or selecting A/B/C. Candidate-specific manifest
  population, target/resource membership, and runtime adapter work must wait
  for the addition-031 bake-off decision. Do not run Cargo/Xcode/app/model code,
  edit Settings/Lane B, or claim an artifact/release result in this lane.

## File ownership and forbidden overlap

You own the policy, Contextual Shadows, query-runtime, notebook-removal,
composition-root, Free editor AI-removal, target membership, and release-gate
files required above. You may edit `NoteDetailWorkspaceView.swift` only for
Contextual Shadows/notebook removal.

Do not edit:

- `Epistemos/Views/Epdoc/**`
- `Epistemos/Models/EpdocContentEnvelope.swift`
- `Epistemos/Models/EpdocContentCompatibilityProjection.swift`
- non-AI Epdoc document/projection/theme/font files owned by Lane B
- `Epistemos/Graph/Workspace/GraphWorkspaceRoute.swift`
- Multitask/Home graph host/container/renderer files owned by Lane B
- any Settings file
- canon 00-16, central handoff/ledgers/evidence, or the manifest

If your change genuinely requires a Lane B file, record the exact file, caller,
minimal requested seam, and test in your scoped ledger; do not make the
overlapping edit.

Prefer new removal-specific tests such as
`EpistemosAppStoreKeelstoneTests/FreeV1RemovalBoundaryTests.swift`. Do not edit
the shared giant App Store lane test file or Lane B's Epdoc/graph test files.

## Fail-first acceptance tests

At minimum cover:

- seeded note+chat Contextual Shadows across search, fallback, empty notes,
  copy/drag/insert, restoration, deep links, graph, Time Machine, export, and
  accessibility;
- natural-language, structured, direct type filter, neighbor, path, and edge
  queries containing hidden nodes and allowed note/idea nodes;
- legacy workspace/chat/sheet manifests including invalid/oversized input,
  stale restored tabs, save/reopen, byte preservation, and a guard that the
  canonical JSON Epdoc document/block route remains available for a future
  deterministic Epdoc-native notebook;
- exact Free capability partition without Reckoner;
- Free JS/native target/artifact symbol and dependency absence while load
  epochs, minimal UTF-8 writeback, large edits, lens leases, undo, and conflict
  behavior remain;
- cold Free bootstrap constructs zero canceled services/tasks/sheets and makes
  zero permission, provider, generation-model, implicit embedding-download,
  or unrelated background request; any eventually approved embedding candidate
  runs only for bounded search/index work under additions 011 and 030–033;
- stale defaults/routes/snapshots fail closed without erasing records;
- deterministic HTML, note search/graph, editing, Sync seams, native input, and
  Kokoro remain reachable as authorized;
- release-gate positive and adversarial fixtures, including transformed or
  compressed forbidden identities.

## Verification protocol

Implement and inspect the complete owned diff. Run source-only guards that do
not launch Xcode or Epistemos, and record everything deferred.

Do not run `xcodebuild`, launch Epistemos, delete/replace an app or archive, or
claim runtime behavior in this removal source session. Lane B is deferred and
must not be started by this task. Finish with a source checkpoint in your
scoped ledger containing:

- every owned file changed;
- tests added and their intended proof;
- source/static commands actually run;
- exact remaining Xcode, artifact, restoration, Settings, manual/runtime, and
  compatibility debt;
- any requested cross-lane seam;
- `READY_FOR_SERIAL_INTEGRATION_VERIFICATION` only if your owned diff is stable.

The later integration owner—not this source lane—must perform the mandatory
below-16-GiB preflight, one-current-build cleanup, single serial App Store
build/test, exact artifact scans, and finite runtime matrix. Do not start a new
execution key or claim KEELSTONE/release completion.

### `LR-LIVE-2026-07-15-040` — close compile and state-authority gaps in the receipt rewrite

- Current receipt-rewrite checkpoint: preserve the useful new direction—typed
  pending/bound lexical/vector receipts, optional vector generation during
  semantic degradation, artifact/state digests included in the manifest digest,
  bounded vault-scoped requests, and duplicate channel/rank rejection—but do
  not accept addition 037 yet. The exact current source still has compile- and
  authority-level gaps below; formatter success is not type-check or behavior
  proof, and Cargo execution remains forbidden in this lane.
- Compile closure by source reasoning: `publish` currently consumes
  `projection.chunks` in `for chunk in projection.chunks` and then borrows
  `&projection` for `with_staged_state`; that is a partial-move use unless the
  API is restructured. `with_staged_state` also assigns
  `self.lexical_receipt = self.bind_staged_receipt(self.lexical_receipt, ...)`,
  moving a non-`Copy` field while borrowing `self`. Stage the needed projection
  metadata before moving chunks and bind receipts from validated digests without
  partially moving/borrowing the same value. Add narrow source guards for the
  corrected ownership shape and record compile/type-check proof as deferred;
  `rustfmt --check` cannot justify a compilable claim.
- One state authority: `rank_note_hits` still accepts an independent
  `semantic_availability` and rank policy even when the published catalog
  manifest records different availability/policy/normalization/generation. The
  current fixtures publish `MissingAsset` and then request
  `SemanticAvailability::Available`, which lets a caller resurrect semantic
  ranking without a validated vector receipt. Derive usable channel health from
  one validated published generation receipt (or require an exact matching
  generation/receipt token); require policy version, dimension, normalization,
  vault, and generation parity; and reject stale/contradictory caller claims.
  When no valid manifest remains, only the independently valid bounded lexical
  channel may run—never caller-asserted semantics.
- Mutation receipt integrity: `remove_note` and `reset` currently advance the
  catalog and set `manifest = None`. Clearing semantic readiness is more honest
  than fabricating synchronized generations, but addition 037 requires every
  replace/delete/reset to accept or produce a generation-scoped exact-state
  receipt. Stage delete/reset like publish, bind the new chunk/note-set digest
  and lexical mutation receipt, clear vector readiness explicitly, and swap
  once; or return one typed unready mutation receipt that prevents all semantic
  use until a validated republish. Test failure/cancel/stale/overflow at each
  mutation with prior chunks, generation, and receipt unchanged.
- Projection completeness authority: validation now checks revision, IDs,
  occurrences, ranges, kinds, source slices, and covered-byte count, but it does
  not reconstruct the declared chunking policy from its digest or prove that a
  `ProjectionStatus::Complete` chunk list is the exact deterministic projection.
  A caller can omit a valid body chunk, adjust covered bytes, retain `Complete`,
  or supply a different in-block segmentation without proving the canonical
  projector produced it. Carry the bounded canonical policy or a trusted
  projector-output digest/receipt and compare the full ordered projection,
  coverage/status, omitted boundary, chunk IDs, and source ranges. Add fixtures
  for missing/reordered/overlapping/extra chunks and a forged complete-versus-
  partial status; prior catalog state must remain unchanged.
- Finish the numeric/overflow matrix rather than replacing it with source-string
  checks. The current fixture still lacks behavior cases for `u64::MAX`
  generation overflow, both signs of infinity across query/document/channel,
  near-zero/negative/orthogonal/maximum-finite vectors, dot/norm accumulation,
  vector/count/dimension/hit/request boundaries, noncontiguous or out-of-count
  ranks, singleton versus two-channel support, manifest-receipt field tampering,
  and hostile ignored semantic inputs. Add a bounded internal/test constructor
  where needed to reach overflow without billions of mutations; prove typed
  error plus byte-for-byte equivalent prior in-memory state. Do not call the
  contract hardened merely because a source guard finds `checked_add(1)`.
- Receipt honesty: a caller-supplied artifact SHA is an asserted external
  receipt, not proof that a lexical/vector file was durably staged. Name and
  document that distinction in the pure module. Bind the asserted receipt to
  exact candidate-neutral state here, then require the later persistence/asset
  adapter to verify bounded file bytes, digest, generation, fsync/rename/crash
  boundary, and reopen before publishing readiness. No mock digest may be cited
  as persistence, ANN, model, crash-durability, or artifact evidence.
- Sequence: complete addition 040 inside the isolated 037 module/fixture, amend
  the ledger's actual-versus-intended proof, and perform only authorized source/
  static checks. Then reread the live prompt before any addition-038 parser or
  additions-035/036 lifecycle/backend work. Do not select or run a model, wire
  persistence/ANN/FFI/mounted Swift, run Cargo/Xcode/app code, change resources,
  edit Settings/Lane B, create the addition-039 checkpoint commit, or begin the
  whole-app counterfactual rebuild.

### `LR-LIVE-2026-07-15-041` — bind ranked channel evidence to one exact request and generation

- Newly observed authority gap after addition 040: `rank_note_hits` still takes
  two untyped raw hit slices, while `ChannelHit` carries only chunk ID, score,
  and rank. Validating the catalog manifest does not prove that either slice was
  produced for this vault, published generation, manifest, query, origin, limit,
  or channel. A caller can replay an old result list whose still-stable chunk IDs
  remain in the catalog, swap or relabel semantic and lexical arrays, or combine
  batches from different requests. Replace the loose slices with bounded typed
  lexical/semantic batch evidence, or an equally strong tokenized API, before
  treating fusion as generation-safe.
- Exact batch binding: bind every accepted channel batch to channel kind, vault
  ID, catalog generation, exact published-manifest digest, the matching bound
  lexical/vector state receipt, canonical query/request digest and version,
  origin-note exclusion, requested pre- and post-filter limits, and completion/
  truncation status. The ranker must reject stale, cross-vault, cross-request,
  wrong-channel, missing-receipt, mismatched-limit, mixed-generation, replayed,
  or duplicated batches before any candidate can affect work or ordering. A
  semantic batch is usable only when the same manifest proves its vector channel
  ready; independently validated lexical evidence must remain usable when the
  vector channel is absent or degraded.
- Full policy authority: the current manifest records `rank_policy_version` but
  not `rrf_k` or a digest of all ordering parameters. A caller can therefore
  reuse the same version number with different parameters and change scores or
  ordering while still appearing manifest-compatible. Bind the complete
  canonical rank-policy parameters/digest to the manifest and request receipt,
  or resolve one immutable policy from the version and reject any caller-supplied
  divergence. Do the same for every normalization or score-interpretation field;
  a version label alone is not proof of identical behavior.
- Exact-title provenance: `HybridRequest::with_exact_title` plus the mere
  presence of any lexical hit currently lets a caller promote a note whose title
  equals caller-supplied text, without proving that the escaped lexical query for
  this request actually produced an exact title-field match. Carry typed exact-
  title/rare-token match evidence from the same bounded lexical execution, tied
  to its query digest and field/analyzer policy, or compute it inside one trusted
  query contract. Do not accept a free-form priority flag. Test fabricated title
  intent, swapped lexical/semantic batches, near-title negatives, normalization
  changes, query punctuation/operators, Unicode case/diacritic variants, and a
  genuine exact-title match independent of IDs and insertion order.
- Rank-list truth and starvation: require ranks to describe the declared bounded
  channel batch (unique, positive, in range, and contiguous unless a typed
  filtered-rank contract explains gaps). Apply vault/current-revision/origin and
  paid-provenance exclusion before each channel's top-k truncation so excluded
  rows cannot consume the candidate budget. Add fixtures where stale/deleted,
  origin, cross-vault, or otherwise ineligible rows occupy the leading upstream
  ranks; valid later notes must not disappear, and dishonest completeness or
  truncation metadata must fail closed.
- Proof boundary and sequence: addition 041 is still a pure candidate-neutral
  contract correction inside the current isolated 037 transaction. It does not
  prove that Tantivy, an ANN, a model, or Swift already emits these receipts.
  Record those adapters as later additions-035/036 and serial-integration debt.
  Complete 040–041 with fail-first fixtures and authorized source/static checks,
  update the ledger, and reread the latest prompt before proceeding. Do not run
  Cargo/Xcode/app/model code, add an asset or model, wire persistence/ANN/FFI,
  edit Settings/Lane B, commit, or begin the owner-gated rebuild.

### `LR-LIVE-2026-07-15-042` — keep absent semantic metadata honest and catalog policies coherent

- Newly observed manifest-shape contradiction: a `MissingAsset`/degraded
  lexical-only generation still requires a nonempty `model_descriptor_digest`,
  vector dimension, and vector normalization, so current fixtures insert a fake
  model SHA and `256` dimensions even though no vector asset or selected model
  exists. Do not manufacture semantic metadata to satisfy one monolithic shape.
  Split the published receipt into an always-required lexical contract and an
  optional cohesive vector contract. The vector descriptor, exact dimension,
  normalization, vector generation, and bound vector artifact/state receipt
  must all be present and mutually valid only when semantics are ready; they
  must all be absent when no candidate has been selected or the vector channel
  has been deliberately cleared. A degraded reason/status may remain without
  pretending an absent asset's identity is known.
- Catalog-wide chunking truth: the current manifest carries one
  `chunking_policy_digest`, and each note publication replaces it with that
  projection's policy while retaining all other notes. Publishing note A under
  one valid policy and note B under another can therefore leave a mixed catalog
  whose manifest names only B's policy. Either enforce one immutable canonical
  chunking policy for the complete catalog generation and reject a different
  policy until a full staged rebuild, or bind a deterministic per-note policy/
  projection-receipt map into the manifest and channel state digests. One digest
  for the last mutation is not proof of every retained chunk. Test mixed-policy
  insert/replace/delete, reopen/rebuild lineage, and unchanged prior state after
  rejection.
- Mutation lineage: `remove_note`/`reset` currently accept a fresh manifest
  shape from the caller. Even after binding the new chunk map, that lets a
  deletion silently change model descriptor, dimension, normalization, rank
  policy, or unrelated artifact identity. Derive the mutation receipt from the
  validated previous generation plus the exact new lexical staging receipt;
  inherit immutable schema/query/chunker/rank contracts, clear the complete
  vector contract, and advance once. A contract/policy/model migration requires
  its own explicit full-generation rebuild receipt, never a delete/reset side
  effect. Empty reset still needs an exact bounded lexical empty-state receipt
  and must not retain or invent vector readiness.
- Channel-specific failure truth: distinguish “no model selected,” “selected
  model asset missing/corrupt,” “vector generation rebuilding/cancelled,” and
  “vector contract incompatible.” Only states with an actual selected candidate
  may name that candidate's verified descriptor. Every degraded state must keep
  exact lexical readiness independently visible and must prevent stale vector
  metadata or caller assertions from becoming usable. Do not conflate the
  candidate-neutral injected-vector fixture with a selected production model.
- Fail-first proof: add fixtures for a valid lexical-only manifest with no fake
  vector fields; every partial vector-contract combination; Available without a
  complete bound vector contract; mixed chunking policies across two retained
  notes; delete/reset attempts that alter rank/chunker/model/normalization
  lineage; and an explicit full rebuild that legitimately changes a governed
  contract. Assert prior generation/chunks/manifest remain exactly unchanged on
  every failure and that manifest/state digests change for every accepted
  governed mutation.
- Sequence: reconcile 042 with 040–041 inside the isolated candidate-neutral
  transaction and ledger before calling addition 037 complete. This does not
  authorize choosing or downloading a model, creating the addition-038 asset,
  wiring real lexical/vector persistence, ANN/FFI/Swift, running Cargo/Xcode/app
  code, changing resources, editing Settings/Lane B, committing, or beginning
  the future whole-app rebuild.

### `LR-LIVE-2026-07-15-043` — split neutral first-run vault setup from the retired model catalogs

- Newly observed Free source membership: `Epistemos/Vault/FirstRunBootstrap.swift`
  is included by the Free target and still describes itself as mirroring
  `agent_core` with background model download. The same file publicly compiles
  three Qwen router candidates and three BGE/Nomic embedding candidates with
  Hugging Face IDs, memory/dimension metadata, and force-unwrapped default
  selectors. `EpistemosTests/FirstRunBootstrapTests.swift` positively requires
  all of those model rows/defaults. Nil fresh-vault pins and the absence of an
  immediate download call do not make those compiled registries part of the
  Free vault-scaffolding capability.
- Required split: retain one neutral Free first-run coordinator for choosing the
  vault directory, creating the reviewed folder scaffold, and atomically writing
  minimal versioned vault metadata. Remove the Qwen/router generation catalog,
  BGE/Nomic download catalog, default selectors, agent-core/background-model
  doctrine, and their positive Free tests from the Free compile/source/artifact
  closure. A separately owned future-paid catalog may remain in a source file or
  target that the positive Free membership graph cannot compile, discover, or
  invoke; do not leave it hidden behind a Free runtime condition in the shared
  bootstrap type.
- Historical metadata safety: existing `.epistemos/vault.json` may contain
  `embedding_model_pin` or `router_model_pin`. Do not delete the file, erase or
  reinterpret those values, rewrite an existing receipt merely to remove a
  field, or use a historical pin to open a cache, resolve a Hub ID, or start a
  model task. Preserve old bytes and tolerate the bounded legacy keys through
  the smallest data-only compatibility decoder/unknown-field policy. Fresh Free
  metadata must not advertise or emit generation/download-model pins; prove a
  read/reopen path preserves a seeded historical receipt byte-for-byte.
- Embedding override does not rescue this catalog: the retained product is one
  local notes-only paragraph-search capability selected by additions 030–031.
  The current BGE/Nomic MLX list has not passed that bake-off, and it combines a
  general Hugging Face download identity with the same bootstrap that names
  generation routers. Do not silently add those candidates to the bake-off,
  reuse the historical pin as search-asset readiness, or allow environment/
  home/cache/Hub resolution. If a bundled candidate later wins, its sole
  immutable descriptor belongs under addition 038's search-only receipt; if
  Apple wins, no bundled model pin is created.
- Fail-first proof: add a focused Free removal fixture that requires the neutral
  bootstrap/scaffold/atomic-write API and historical-byte preservation while
  rejecting `RouterCandidate`, `EmbeddingCandidate`, `routerCandidates`,
  `embeddingCandidates`, `defaultRouter`, `defaultEmbedding`, Qwen/BGE/Nomic/
  MLX/Hub IDs, model-download wording, and an `agent_core` bootstrap dependency
  from Free membership and the later exact binary strings. Update or hand off
  older positive model-catalog tests without editing the protected shared giant
  App Store/Lane-B test files; record exact stale-test debt where ownership
  forbids the edit.
- Sequence/ownership: queue addition 043 after the isolated 037/040–042
  transaction reaches its honest source checkpoint; it does not expand that
  transaction. Lane R may edit the neutral bootstrap/model-catalog split and its
  focused tests after mapping callers and target membership. Do not edit
  Settings/Lane B, choose/download/run a model, read user model caches, run
  Xcode/app/artifact work, commit, or begin the final rebuild.

### `LR-LIVE-2026-07-15-044` — audit the first batch/vector split before accepting 041–042

- Immediate compile-shape defect in the exact current source: `pub fn limit`
  and `pub fn origin_note_id` were inserted inside `impl GenerationManifest`,
  but that type has no `limit` or `origin_note_id` fields. They are request
  accessors and belong on `HybridRequest` or a narrower request receipt. Move
  them to the owning type, add a narrow ownership/source guard, and inspect all
  moved braces/impl boundaries. `rustfmt --check` passing this syntax is not a
  type-check and cannot close addition 040's compile debt.
- Vector-shape boundary: the new optional tuple correctly stops requiring fake
  model metadata for lexical-only state, but its Available arm currently accepts
  `dimension == 0` because it checks only `dimension <= MAX_VECTOR_DIMENSION`.
  Require the exact bounded nonzero dimension and validate every cohesive-field
  permutation in both pending and bound receipts. Keep the production candidate
  descriptor distinct from the injected-vector fixture and do not call a set of
  parallel `Option` fields cohesive unless one validator exhaustively governs
  all combinations and every published-state path invokes it.
- Semantic-ready mutation contradiction: `stage_degraded_mutation_receipt`
  rejects an Available next manifest, but also requires the next optional model/
  dimension/normalization fields to equal the previous generation. A legitimate
  delete/reset from a semantic-ready generation must clear those fields, so
  `None != Some(...)` currently makes the required degradation impossible.
  Derive the next manifest internally from the validated prior immutable lexical/
  schema/chunker/rank lineage plus one exact new lexical staging assertion; clear
  the whole vector contract by construction. Do not accept a caller-built full
  manifest for a routine mutation. Add semantic-ready delete and reset fixtures,
  including stale/cancel/failure paths with the complete prior state unchanged.
- Batch attestation versus copied assertions: `ChannelBatch::new` is public and
  accepts caller-provided channel kind, manifest/request digests, state receipt,
  completion truth, and `exact_title_chunk_ids`. A caller that can read the
  manifest/request can copy every expected value, relabel arbitrary hits, and
  mark any matching title ID as “exact”; equality with self-asserted fields does
  not prove that the lexical/vector executor produced the batch. Use an opaque
  catalog-issued request/generation lease plus a channel-specific completion
  path whose trusted adapter binds the ordered result digest and typed lexical
  match evidence, or explicitly label this pure object an untrusted assertion
  and refuse to cite it as adapter/query proof. Exact-title priority may not be
  a public free-form set or Boolean. Add fabricated-current-digest, swapped-
  channel, copied-receipt, result mutation, and exact-title forgery fixtures.
- Origin/limit/completeness truth remains open: matching
  `batch.origin_note_id` to the request does not reject an origin-note hit; the
  ranker still filters that hit after the already-bounded batch. Likewise
  `pre_filter_limit` is not tied to a request policy, and Complete/Truncated has
  no admitted/excluded/total accounting that proves valid later rows were not
  starved. Validate every hit against current vault/revision/origin/paid-
  provenance eligibility before channel truncation, bind the channel work/top-k
  limits to the request lease, and make completion metadata falsifiable. Test an
  origin or stale row at every leading rank, all-invalid prefixes, honest fewer-
  than-limit completion, dishonest Complete, and truncated batches with valid
  eligible rows just beyond the prefix.
- Sequence: addition 044 is a mandatory acceptance pass within the current
  isolated transaction, before additions 041–042 or 037 are marked complete.
  Reconcile and ledger it with source/static evidence only, then reread the live
  prompt before the later queued addition 043 or any 035/036/038 work. Do not
  run Cargo/Xcode/app/model code, wire real persistence/ANN/FFI/Swift, change
  resources, edit Settings/Lane B, commit, or begin the final rebuild.

### `LR-LIVE-2026-07-16-045` — bind the actual search query and quarantine untrusted ranking claims

- Newly observed cross-query replay defect in the exact checkpoint source:
  `HybridRequest` currently contains only `vault_id`, `limit`,
  `origin_note_id`, and optional caller-supplied `exact_title`. Its
  `note-recall-request-v1` digest therefore does not contain the user's actual
  search text or a digest of the exact lexical/vector inputs. Two different
  paragraph queries with the same envelope receive the same request digest,
  deterministic `SearchLease`, and acceptable batch identity. This does not
  satisfy addition 041's “canonical query/request digest” requirement. Do not
  mark 037/041/044 complete, call the current lease query-bound, or use it as
  production search evidence until the exact query is part of the contract.
- Define one bounded, versioned query envelope before execution. Bind the exact
  nonempty UTF-8 user-query bytes (or a canonical privacy-preserving digest over
  those exact length-framed bytes), the lexical escape/analyzer policy and
  version, and the semantic input-normalization policy and version to the
  request and lease. If lexical and vector channels receive intentionally
  different derived inputs, bind both derived-input digests and the derivation
  policy; do not let a caller reuse one generic digest while changing either
  channel's text. State whitespace, Unicode normalization/case/diacritic,
  punctuation/operator escaping, maximum-byte, empty/control input, and query-
  privacy/logging behavior explicitly. Normalization used for matching may not
  silently replace the original-byte identity used to detect cross-query reuse.
- Deterministic SHA equality is an integrity fingerprint, not authorization or
  proof of execution. The current `SearchLease` has no nonce, issuance sequence,
  channel-consumption state, expiry, or adapter signature and can be completed
  repeatedly while the generation is current. The later real adapter boundary
  must either issue a one-use request/channel receipt with replay-resistant
  consumption or define a narrow immutable cache-reuse contract that is
  idempotent only for the exact query bytes, policies, vault, generation,
  manifest, origin, limits, and channel state. Addition 041 currently requires
  replay rejection; do not silently weaken it because re-ranking is pure. Keep
  the isolated lease explicitly structural/untrusted until that stateful
  boundary exists.
- Exact-title authority remains caller-controlled in the current checkpoint.
  `complete_untrusted_channel_assertion` publicly accepts
  `exact_title_chunk_ids`; validation proves only that each asserted ID names a
  returned chunk whose catalog title equals the caller's normalized optional
  title. The caller can omit a genuine title match, choose a matching ID, or
  vary the set and thereby change `exact_lexical_title` priority. Likewise its
  upstream/excluded counts and Complete/Truncated label remain assertions, not
  evidence that later eligible rows were considered. The untrusted fixture path
  may exercise shape/fusion, but it must not activate an authoritative title
  boost or be cited as completeness/pre-truncation proof. Only a real escaped
  lexical title-field executor may emit typed, same-query match evidence and
  truthful candidate accounting; the authoritative rank path must reject or
  quarantine public free-form title/count assertions.
- Provenance remains an adapter obligation: `NoteInput`/`ParagraphChunk` being
  named “note” does not prove that production bytes came from a current Free
  note revision rather than a retired chat/agent/graph/paid record. Keep the pure
  injected fixture candidate-neutral, but require the later mounted ingestion
  and channel adapters to bind the source-kind/current-revision eligibility
  receipt before indexing and before top-k. An origin, stale revision, deleted
  row, cross-vault row, or paid/canceled provenance row may not consume the
  bounded candidate budget.
- Fail-first proof: add two distinct body queries whose vault/limit/origin/title
  envelope is otherwise identical and require different request/lease/channel
  identities plus cross-query rejection. Cover empty and maximum-plus-one-byte
  queries, Unicode composed/decomposed forms, case/diacritic behavior,
  punctuation and lexical operators, exact-title near misses, changed analyzer/
  normalization versions, a batch replayed after one channel completion, and a
  second completion of the same channel. Prove that adding or omitting asserted
  title IDs cannot change authoritative ranking through the untrusted path and
  that fabricated counts cannot claim pre-truncation completeness. Preserve the
  exact prior catalog/lease state on every rejection.
- Sequence: reconcile 045 as a mandatory correction before accepting the
  isolated 037/041/044 ranking contract. The honest source-only checkpoint may
  remain recorded and addition 043's caller/membership mapping may proceed, but
  neither the checkpoint nor the untrusted fixture closes query binding,
  adapter execution, provenance, replay, or completeness debt. Do not run Cargo/
  Xcode/app/model code, choose or wire a model, add persistence/ANN/FFI/Swift,
  alter resources, edit Settings/Lane B, commit, or begin the owner-gated final
  rebuild under this addition.

### `LR-LIVE-2026-07-16-046` — make mounted SQLite retrieval bounded, top-k-correct, and note-fair

- Newly observed mounted limit defect: the sync/async page and block entry
  points in `SearchIndexService` accept any caller-supplied `Int` and pass it
  directly to SQLite `LIMIT`. SQLite's official SELECT documentation states
  that a negative LIMIT means there is no upper bound:
  <https://www.sqlite.org/lang_select.html#limitoffset>. Zero, negative,
  maximum-plus-one, integer-extreme, and unreasonably large limits must be
  rejected at one typed request boundary before telemetry, queue dispatch, SQL,
  fallback work, or allocation. Use the same checked maximum for direct,
  block, fused, async, Shadow, and later FFI paths; a surface must not be able to
  bypass the bound by choosing a different search method.
- The current character cap is not a byte/work cap. `normalizedSearchTerms`
  first evaluates `raw.count > 500`, which can traverse the complete input,
  then caps by extended grapheme count; a small grapheme count can still contain
  very large combining sequences and UTF-8 bytes. Bind the exact query envelope
  required by addition 045 at ingress with checked UTF-8 bytes, scalar/grapheme
  and derived-token/clause bounds before lowercase/normalization/splitting or
  JSON/metadata construction. Do not record the query or its normalized terms
  in retired agent traces. Explicitly test code/scientific single-character
  queries rather than silently treating every ASCII singleton as noise.
- Per-source top-k is not presently guaranteed. Each `page_hits`, `block_hits`,
  and `readable_hits` CTE computes `ROW_NUMBER() OVER (ORDER BY bm25(...) ASC)`
  and then applies `LIMIT :per_source_limit`, but the containing SELECT has no
  `ORDER BY`. SQLite documents that a window's ORDER BY does not govern final
  row order (<https://www.sqlite.org/windowfunctions.html>) and that SELECT row
  order is undefined without its own ORDER BY; FTS5's documented relevance form
  is `ORDER BY rank`/`ORDER BY bm25(...)` before LIMIT
  (<https://www.sqlite.org/fts5.html#the_bm25_function>). Make each bounded
  source select the actual best matches with an explicit deterministic order
  and stable tie-break before truncation. Vary insertion order, rowid, index
  rebuild, equal BM25 values, and more-than-limit adversarial matches; the same
  best eligible identities must survive.
- Repeated-block vote inflation: `unioned` retains every matching block/readable
  row and `ranked` sums every row in `PARTITION BY entity_id`. A long or
  repetitive note can therefore receive multiple votes from one channel while
  another note receives one, even though both are later presented as one
  entity. Deduplicate to the best eligible chunk per note/entity *within each
  source* before cross-source fusion, retain the chosen chunk/rank/snippet as
  evidence, and permit at most one contribution per source unless a separately
  measured length-normalized policy proves otherwise. Test one strong concise
  note against a note with 2, 20, and maximum repeated matching chunks and prove
  verbosity cannot manufacture consensus.
- Typed identity and allowed-source policy: the final windows group only by the
  unnamespaced string `entity_id`. A page and readable artifact with the same
  raw ID can be merged, while `readable_blocks.artifact_kind` is admitted
  without a positive Free/source-kind filter. Use one canonical typed entity
  identity or prove a global namespace; apply current-revision, vault, origin,
  and allowed Free provenance before per-source top-k. The retained semantic
  exception is notes-only. If a separately reviewed deterministic document/code
  search remains useful, keep its source policy and surface explicit rather than
  letting raw-thought/source/output or canceled records become paragraph-search
  candidates. Add cross-kind ID collision and forbidden-leading-row fixtures.
- Fusion policy is currently caller-mutable and numerically unchecked.
  `FusionWeights` accepts negative, NaN, or infinite source weights and
  half-life, arbitrary `maxResults`/`perSourceLimit`, and a non-finite clock;
  SQL clamps a nonpositive half-life instead of rejecting an invalid policy,
  while the Swift fallback performs the same arithmetic through a different
  implementation. Replace this with one immutable/versioned, manifest-bound
  production rank policy or a validating constructor with finite nonnegative
  fields and strict work bounds. Exact title/rare-token relevance may not be
  defeated merely by freshness, repeated chunks, or a stale UserDefaults/
  environment fusion flag. The current test that requires a recent note to
  dominate an equally matched 90-day-old note by at least 2× is a chosen
  behavior, not relevance evidence; retain, retune, or remove recency only from
  the addition-031 labeled-corpus measurements. Record a Settings-owner handoff
  for any obsolete health/toggle UI; do not edit Settings in Lane R.
- Snippet and fallback truth: FTS5 returns strings containing literal `<b>`
  markers while fallback returns an unhighlighted note head ordered by recency/
  rowid, yet both flow through similar result DTOs. Define typed escaped
  highlight segments or current-revision source ranges and a bounded plain-text
  fallback reason; never treat stored note markup as trusted HTML or let a stale
  block ID scroll into a new revision. Surface degraded fallback ordering
  honestly and test Unicode, literal `<b>` note text, deleted/replaced blocks,
  missing FTS5, cancellation, and direct/fused/Shadow parity.
- Fail-first proof: cover every invalid query/result/weight/clock/limit boundary,
  per-source top-k correctness beyond the cap, same-source duplicate votes,
  typed-ID collisions, forbidden source kinds, old exact-title versus fresh
  generic text, finite output, deterministic ties, and unchanged database/
  readiness state after rejection. Capture query-plan evidence and real mounted
  latency/allocation only in the permitted serial leg; a source fixture or
  in-memory SQLite test is not artifact, mounted UI, or search-quality proof.
- Sequence: queue 046 for the mounted Swift/SQLite search batch after the active
  isolated 045 correction and the currently authorized 043 mapping/checkpoint.
  Reconcile it with additions 013, 026, 030–031, and 035–036 so agent/VaultRecall
  telemetry is removed without discarding the valid lexical fallback. Do not
  interrupt the isolated Rust transaction, run Xcode/app/model/artifact work,
  select or wire an embedder, edit Settings/Lane B, commit, or begin the final
  whole-app rebuild under this addition.

### `LR-LIVE-2026-07-16-047` — prevent query and note plaintext from leaking through diagnostics

- Immediate contradiction in the exact 045 checkpoint: the new
  `HybridRequest` stores the complete raw query and optional exact title while
  deriving `Debug`; `SearchLease` also derives `Debug` and contains that request.
  Therefore `format!("{request:?}")`, assertion failure output, panic/error
  context, or later debug logging can expose the text even though
  `query_digest` is documented as avoiding logs. Amend the worker's “query bytes
  are bounded and never exposed” statement: bounds are present, but plaintext-
  diagnostic non-exposure is not yet proven.
- Remove derived plaintext `Debug` from query/lease types or implement one
  reviewed redacted representation containing only nonsensitive bounded shape
  such as format version, query byte length, limit, and presence flags. Do not
  print the raw query, exact title, snippets, note title/body, vault path, model
  input, or a reversible serialization. Treat the query digest itself as
  pseudonymous sensitive data that can be dictionary-guessed for short/common
  searches; keep it internal to equality/receipt binding and do not emit it to
  logs, metrics, crash breadcrumbs, UI, filenames, or agent/VaultRecall traces.
- Apply the same audit to every content-bearing public contract introduced by
  the isolated module: `NoteInput`, `ParagraphChunk`, `ChunkProjection`,
  `HybridRequest`, `SearchLease`, and `RankedNoteHit` currently derive or expose
  debug-printable user title/body/chunk/snippet text. Retain `Debug` only for
  content-free enums/receipts or use an explicit redacted implementation. Test
  and assertion ergonomics do not justify a production plaintext formatter;
  compare typed fields/digests or use test-only sanitized helpers instead.
- Lifetime/zeroization honesty: minimize raw query/note cloning and retain it
  only for the bounded execution lifetime, but do not claim Swift/Rust heap
  strings are reliably zeroized without an actually audited mechanism. A
  consumed lease is replay-shape hardening, not memory erasure. Later lexical/
  embedding adapters must preserve the same rule for task captures, error
  objects, cancellation state, FFI buffers, allocator diagnostics, and model
  runtime logging.
- Fail-first proof: format each public request/lease/content-bearing DTO with
  every permitted diagnostic path and seed unique query/title/body/snippet
  canaries; no canary or digest may appear. Add source guards rejecting derived
  `Debug` on raw-text-bearing structs, exercise validation/assertion errors with
  hostile Unicode and maximum-size inputs, and prove redaction remains bounded
  and deterministic. Record this as source-level privacy contract evidence only;
  crash-report, allocator, FFI, model-runtime, and mounted log inspection remain
  serial integration proof.
- Sequence: correct 047 inside the current isolated 045 checkpoint before
  describing query plaintext as non-exposed or moving to the 043 source split.
  Then reread the live prompt and preserve 046 as the later mounted batch. Do
  not run Cargo/Xcode/app/model/artifact work, select/wire an embedder, edit
  Settings/Lane B, commit, or begin the final rebuild under this addition.

### `LR-LIVE-2026-07-16-048` — make the neutral first-run vault bootstrap a bounded fail-closed transaction

- Newly observed reachability contradiction: production Swift references
  `FirstRunBootstrap.defaultVaultURL`, but the repository-wide current-source
  search finds `FirstRunBootstrap.bootstrap` and `readMetadata` only in their
  definition and tests. `SetupAssistantView` nevertheless documents a
  “connect → bootstrap → persist” path while `useDefaultVault` merely performs
  `try? FileManager.createDirectory` and then starts the vault connection even
  when creation failed. Do not preserve dead bootstrap tests as product proof.
  Map the actual `VaultConnectionActions`/`switchToVaultAsync` lifecycle and
  either route fresh default/manual vault setup through one neutral hardened
  bootstrap owner or remove the duplicate bootstrap API in favor of the proven
  production owner. There must be one truthful creation/scaffold/metadata
  transaction and no success UI, selection persistence, watcher/index start,
  or setup completion after it fails.
- Preserve the addition-043 split: remove the Qwen/BGE/Nomic/MLX/Hub router and
  embedding candidate structs, defaults, comments, and tests from Free. Fresh
  Free metadata emits no model pin. A bounded compatibility decoder may retain
  the two historical optional pin fields only as inert data needed to re-emit
  already-existing metadata byte-for-byte; it may not interpret them as model
  selection/readiness, contact a registry/Hub, or make them newly writable.
  Validate and preserve an existing supported receipt before any scaffold or
  metadata mutation; corrupt/unsupported metadata must fail closed without
  creating folders or rewriting/quarantining user bytes.
- Path/type boundary: `isFresh` currently equates `fileExists == false` with a
  safe absent metadata target and directory creation treats every existing path
  as a valid directory. Establish one canonical/bookmark-approved vault root,
  prove every metadata/scaffold child remains beneath it, and inspect path
  components without following an attacker-controlled link. Reject or safely
  resolve by explicit policy symlinks/aliases and reject dangling links,
  directories at `vault.json`, regular files at scaffold-directory paths,
  devices/FIFOs/sockets, hard-link ambiguity where relevant, and replacement
  races. Never overwrite, traverse, delete, or chmod an unexpected existing
  object. Do not assume `AtomicVaultWriter` alone proves these no-follow and
  containment properties; any shared-writer change requires a caller/blast-
  radius audit and preservation of all unrelated dirty work.
- Bounded metadata envelope: replace unbounded `Data(contentsOf:)` with a
  regular-file/no-follow, preflight-and-stream bounded read that revalidates the
  opened descriptor. Define an explicit small byte limit, supported schema
  version set, required/optional field set, duplicate/unknown-field policy,
  valid ISO-8601/date bounds, and maximum historical-pin byte/scalar lengths.
  Reject empty/truncated/oversize/non-UTF-8/non-object/nested-hostile inputs,
  unsupported versions, duplicate keys, and invalid dates with bounded
  content-neutral errors. Never include metadata bytes, full vault paths,
  historical pins, or decoder payloads in logs, assertions, toast text, crash
  breadcrumbs, or diagnostics.
- Fresh-write concurrency: `wasFresh` is currently sampled before filesystem
  mutation and the metadata write does not use the available
  `VaultFileBaseline.absent` compare-and-swap. Two simultaneous bootstraps can
  both claim fresh and replace each other's `createdAt`. Bind fresh publication
  to `.absent` inside the coordinated write after the no-follow checks. Exactly
  one contender may create the receipt; a baseline-race loser must re-open and
  validate the winner, report `wasFresh = false`, and never overwrite it. Make
  folder receipt accounting invocation-specific. On injected failure, leave
  either a valid published metadata receipt plus complete scaffold or an
  explicitly safe, retryable partial state; rollback only exact empty
  directories created by that invocation and never pre-existing/user content.
- Default-path and privacy correction: `defaultVaultURL` must not fall back to
  a relative `Epistemos` path whose meaning depends on process working
  directory. The intermediate fallback is also wrong: `.userDirectory` means
  the directory containing user homes (for example `/Users`), and
  `.localDomainMask` is the machine-wide domain, so the current combination can
  yield a shared `/Users/Epistemos`-style target rather than the current user's
  home. Apple's documented current-user primitive is
  `FileManager.homeDirectoryForCurrentUser`; prefer a valid Documents URL in
  `.userDomainMask`, then an explicitly validated child of the current user's
  absolute home only if that is the reviewed fallback policy. Reject `/`, the
  users container itself, a machine/network/system-domain location, non-file or
  relative URLs, wrong-type/unwritable parents, and invalid audit-isolation
  configuration. Return a typed failure that the setup UI surfaces while
  remaining incomplete; `preconditionFailure` for a malformed runtime-audit
  environment is not an acceptable user/release failure path.
  Replace the `.public` full-path bootstrap log with a bounded content-neutral
  event; even the last path component must be treated as user-controlled unless
  explicitly redacted. `try?` is forbidden on the default-vault creation path.
- Fail-first proof: replace the model-catalog assertions and current happy-path-
  only source guards with tests for production reachability; fresh metadata with
  no pins; byte-identical reopen of supported historical metadata containing
  inert pins/unknown compatibility data according to the chosen policy;
  unsupported schema and corrupt/oversize/duplicate/unknown JSON; symlink/
  alias/traversal, wrong-type, hard-link, and target-swap fixtures at every path
  component; read/write fault injection; two concurrent first-run contenders;
  partial-scaffold retry without deleting a user canary; unavailable absolute
  default location; and setup UI failure/no-persist/no-index/no-success behavior.
  Seed path/pin/JSON canaries and prove diagnostic/log/assertion redaction.
- Evidence and sequence: addition 047's isolated redaction checkpoint completes
  first. Then implement 043 and 048 as one neutral FirstRun source/test slice,
  reconcile the stale `AppStoreHardeningTests` exact-string writer assertion,
  and preserve primary-source receipts for Apple's
  [`homeDirectoryForCurrentUser`](https://developer.apple.com/documentation/foundation/filemanager/homedirectoryforcurrentuser),
  [`userDirectory`](https://developer.apple.com/documentation/foundation/filemanager/searchpathdirectory/userdirectory),
  and [`localDomainMask`](https://developer.apple.com/documentation/foundation/filemanager/searchpathdomainmask/localdomainmask)
  semantics; record source/static proof plus all Xcode/UI/concurrency/log
  verification debt honestly. Addition 046 remains the later mounted search
  batch. Do not run
  Xcode/app/model/artifact work, select/wire/download an embedder, edit Settings
  or Lane B, commit, or start the owner-gated final rebuild under this addition.

### `LR-LIVE-2026-07-16-049` — stage candidate vault admission before replacing current state

- Newly mapped three-path contradiction: interactive selection enters
  `VaultConnectionActions.connectSelectedVaultAsync` and
  `switchToVaultAsync`; launch restore resolves a bookmark and calls
  `startWatching` directly; recovery commits its prepared selection and then
  calls `startWatching` directly. None currently invokes the neutral bootstrap.
  `startWatching` also discards `beginWatching`'s Boolean result. Build one
  candidate-admission coordinator used by interactive connect, bookmark restore,
  recovery, same-vault reconnect, and any direct test/helper route. No public or
  internal entry point may bypass root/metadata/scaffold validation by calling
  `startWatching`/`beginWatching` directly.
- Preserve the current vault until candidate admission is proven. Today an
  active-vault switch acquires candidate scope and then stops the current
  watcher/clears its derived local state before `beginWatching` discovers later
  failures; a disconnected switch clears stale derived state before candidate
  bootstrap exists. Candidate admission must first, while the current vault is
  still operational, balance security-scoped access, validate the canonical
  root and metadata, run the fail-closed neutral bootstrap, and obtain a typed
  admission receipt. Only then may the old lifecycle quiesce. Preconstruct or
  preflight every fallible candidate dependency practical before teardown; if a
  later watcher/index start still fails, restore the previous lifecycle from a
  retained rollback receipt or remain explicitly disconnected with a durable
  recoverable error—never silently strand the user between vaults.
- Do not classify “missing/unreadable” as “empty.”
  `VaultIndexActor.vaultFolderSelectionAssessment` currently returns the same
  zero-count value for a nonexistent/unreadable root and for a valid empty
  vault, while `SetupAssistantView` masks default-directory creation errors with
  `try?`. Return a typed assessment/admission failure for absent, unreadable,
  wrong-type, unsafe-link, scope-denied, scan-failed, and valid-empty states.
  Ask for suspicious-folder confirmation only after a successful bounded scan;
  a scan failure must not be treated as consent to initialize or switch.
- Separate admitted, mounted, importing, ready, and failed states.
  `beginWatching` currently assigns `self.vaultURL`, activates lifecycle/crash
  state, sets `isWatching`, writes `lastVaultPathKey`, constructs indexes, starts
  import/watch/autosave/manifest work, and returns `true` immediately. The
  caller then commits bookmark/default selection and resets note windows before
  the import task proves readiness; `SearchIndexService` construction failure
  is merely logged and startup continues. Define a typed asynchronous outcome
  and one source of truth. Bootstrap admission must precede every state/default
  mutation. Decide explicitly whether durable bookmark commit occurs at a
  successfully mounted or fully ready boundary, and prove that policy; either
  way, only the completed import/derived-index/recovery gate may emit “ready” or
  success UI. A persisted-but-not-ready vault must carry an explicit durable
  recovery state rather than look successful.
- Eliminate competing persistence writes. `beginWatching` directly writes
  `lastVaultPathKey` before `commitPreparedVaultSelection`, while restore and
  recovery refresh/commit bookmark/default state on different schedules. Route
  bookmark data, last path, trusted-suspicious path, has-ever-connected, crash
  recorder, active URL, and lifecycle epoch through one staged commit/rollback
  owner. A failure/cancellation/stale task may not partially update those keys,
  stop the wrong security scope, reset windows, publish a manifest, or let an
  old import task mark the new vault ready.
- Apply the same privacy rule across this adjacent transaction. Current
  selection, switch, restore, and bookmark error paths log full vault paths as
  `.public`, and multiple messages interpolate user-controlled last components.
  Use bounded typed reason codes and private/redacted diagnostics; user-facing
  labels may identify the chosen vault only through an explicitly reviewed,
  escaped, length-bounded presentation value. Never include raw path, bookmark,
  metadata/pin data, or decoder text in logs, tests, or error transport.
- Fail-first state-machine proof: with an operational vault A, attempt candidate
  B as nonexistent, unreadable, wrong type, unsafe link, corrupt/unsupported
  metadata, bootstrap write failure, denied scope, index-construction failure,
  import failure, cancellation, and target swap; A must remain operational until
  B has an admission receipt, and every post-admission failure must follow the
  declared rollback/disconnected policy without split defaults. Exercise valid
  empty B, same-vault revalidation, cold bookmark restore, stale bookmark,
  recovery, two rapid selections, late completion from A/B, security-scope
  start/stop balance, and relaunch after each failure boundary. Assert exact
  state/default/window/reset/toast/watcher/index/import outcomes and diagnostic
  canary absence. Source guards must show every production path invokes the same
  coordinator; mounted UI and real filesystem/bookmark evidence remain serial.
- Sequence/ownership: finish 049 inside the 043/048 FirstRun transaction before
  proceeding to 046. Lane R may edit the non-Settings onboarding, vault sync/
  index, focused bootstrap/connection tests, and exact related source guards
  only after ownership/diff checks; protected shared-test conflicts become
  explicit handoffs. Do not run Xcode/app/model/artifact work, touch Settings or
  Lane B, select/wire a model, commit, or begin the final rebuild.

### `LR-LIVE-2026-07-16-050` — make the embedder bake-off effectiveness-first in candidate breadth as well as scoring

- Owner correction, verbatim: “i do not care about the embedding model being
  larger i wat effectiveness”. Addition 031 already makes measured Epistemos
  retrieval effectiveness the primary selection objective, but its mandatory
  A/B/C set is still anchored to Apple and two small static Model2Vec models.
  That is an internal contradiction: a bake-off cannot establish that a larger
  model is materially better if no credible larger retrieval model is allowed
  into screening. Supersede only addition 031's minimum candidate breadth as
  described here. Preserve every removal, local-only/offline/privacy gate,
  canonical-path rule, and evidence requirement in 031; do not restore the
  removed FirstRun Qwen/BGE/Nomic/MLX catalogs or make metadata select a model.
- Primary-source screening facts, not project-quality conclusions: Qwen's
  official Apache-2.0 Qwen3 Embedding family contains 0.6B, 4B, and 8B
  instruction-aware/MRL variants with 32K advertised context and maximum output
  dimensions of 1,024, 2,560, and 4,096. Its card reports materially higher
  generic English and multilingual retrieval results as size increases and
  says query-side task instructions commonly improve retrieval, but those are
  upstream results rather than Epistemos proof. Snowflake's Apache-2.0
  `snowflake-arctic-embed-m-v2.0` is a retrieval-focused 768-dimensional model
  with 305M total/113M non-embedding parameters, advertised 8,192-token context,
  256-dimensional MRL support, and ONNX/Transformers.js artifacts; its card also
  requires a custom-code path for some runtimes. BGE-M3 is a 1,024-dimensional,
  8,192-token multilingual model able to emit dense, learned-sparse, and
  multi-vector representations. These capabilities justify investigation only;
  they do not prove a safe macOS runtime, App Store compatibility, acceptable
  resources, or superior Epistemos search.
- Expanded minimum screen: retain the lexical-only control, Apple
  `NLEmbedding.sentenceEmbedding`, `potion-base-8M`, and
  `potion-retrieval-32M`; add (D) `Qwen3-Embedding-0.6B` as the minimum
  effectiveness-first contextual candidate and (E)
  `snowflake-arctic-embed-m-v2.0` as a retrieval-focused medium baseline. Screen
  Qwen3 4B and 8B as explicit large-tier candidates and do not reject them
  merely because their weights, vectors, or runtime are larger. They may advance
  to the full Epistemos bake-off if an exact local macOS/App Store runtime and
  bounded artifact/resource plan can be mapped. Treat BGE-M3 dense mode and
  MiniLM as optional screening candidates when their exact runtime closure adds
  useful evidence. Record why every screened candidate advanced or stopped;
  “too large” alone is not a sufficient rejection reason.
- Feasibility remains a hard gate, not a size preference disguised as one. For
  each advancing model pin the upstream revision, original license and notices,
  exact tokenizer/config/weight/runtime files and SHA-256 hashes, compressed and
  installed bytes, architecture/quantization, input prefix/instruction,
  truncation and paragraph policy, pooling, normalization, output dimension,
  index format, and migration identifier. Prove local-path-only loading in an
  empty sandbox with network denied and poisoned cache/Hub/proxy environment;
  no installer, `trust_remote_code`, Python, Node, server, dynamic executable,
  mutable cache, or first-use download may be assumed present in the shipped
  app. Map arm64/x86_64 and supported macOS behavior, code signing, entitlements,
  dependency licenses, reproducible build/provenance, cancellation,
  concurrency, deterministic failure, peak/resident memory, memory pressure,
  cold/hot indexing and query latency, energy, launch impact, and worst-case
  vault index bytes. A model that crashes, swaps pathologically, violates the
  sandbox/release boundary, or makes interactive search unusable fails even if
  its relevance is best; record the measured failure instead of quietly
  replacing effectiveness with a small-bundle proxy.
- Compare like with like on an expanded versioned Epistemos corpus. Use the same
  canonical paragraph chunks, lexical candidate pool, deduplication, exact-title
  policy, hybrid weights, limits, and release-safe labeled queries for every
  embedder. Cover direct terms, title/body matches, paraphrases, synonyms,
  abbreviations, mild misspellings, reordered concepts, long notes, short
  fragments, near-duplicates, ambiguous queries, unrelated hard negatives,
  adversarial Unicode, and multilingual cases actually supported by product
  intent. Record per-query ranks and Recall@1/3/5/10, MRR, nDCG, false-positive/
  irrelevant-Halo rate, exact-title regressions, no-result honesty, variance
  across repeated runs, effect size, and the quality/resource Pareto table.
  Keep the lexical-only result visible; a semantic candidate must improve the
  owner-valued difficult searches without materially degrading obvious exact
  searches or manufacturing confident-looking irrelevant results.
- Effectiveness decision rule: among candidates clearing all hard gates, select
  the one with the strongest material, reproducible, user-visible Epistemos
  paragraph-retrieval result. Do not average away a serious query class failure
  behind one global score, and do not select a small model because it is easier
  to package when a larger feasible candidate produces a meaningful quality
  gain. Size, index bytes, latency, and energy remain reported constraints and
  become tie-breakers/trade-off evidence only after correctness, release, and
  bounded-operation gates. If 4B or 8B wins relevance but cannot clear a hard
  gate, retain its result as an explicit upper-bound/reference and choose the
  best feasible candidate without claiming the smaller model is more effective.
- Do not smuggle a second rank architecture in through a model feature. Qwen
  rerankers and BGE-M3 learned-sparse/multi-vector output are separate candidate
  generation/ranking stages, not free improvements to the canonical dense plus
  lexical contract. Keep them disabled during the embedder comparison unless a
  separate fail-first experiment proves material end-to-end Epistemos gain,
  bounded top-N work, stable score calibration, privacy/offline/runtime closure,
  cancellation, and one final authoritative ordering. If such a reranker wins,
  amend the architecture/migration contract explicitly before implementation;
  never leave BM25, learned sparse, dense ANN, ColBERT, and a reranker as
  independently live truths whose scores are fused opportunistically.
- Research receipts to add to the ledger with retrieval date and exact claim:
  official [Qwen3 Embedding repository](https://github.com/QwenLM/Qwen3-Embedding),
  [Qwen3-Embedding-0.6B card](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B),
  [Qwen3-Embedding-8B card](https://huggingface.co/Qwen/Qwen3-Embedding-8B),
  [Snowflake Arctic Embed m v2.0 card](https://huggingface.co/Snowflake/snowflake-arctic-embed-m-v2.0),
  and [BGE-M3 card](https://huggingface.co/BAAI/bge-m3). Clearly label upstream
  benchmark claims versus reproduced local screening and project-corpus
  evidence. Sequence remains unchanged: finish 043/048/049 and then 046 before
  model execution. Under 050, Lane R may document/research the candidate closure
  and add release-safe evaluation fixtures, but must not download, wire, select,
  ship, or claim any model; run Xcode/app/artifact work; touch Settings/Lane B;
  commit; or begin the owner-gated final rebuild.

### `LR-LIVE-2026-07-16-051` — prove first publication against filesystem identity, not an `.absent` source string

- Newly observed false-proof hazard in the active 048 tests: the fail-first
  source guard currently asks only for the substring
  `ifCurrentMatches: .absent`. The shared `AtomicVaultWriter` implementation of
  that case calls path-based `FileManager.fileExists`, then later chooses
  `replaceItemAt` or `moveItem`; it also recursively creates the target parent
  before verification. That is a useful cooperating-writer baseline check, but
  it does not bind the inspected parent/target inode through publication, reject
  every dangling/intermediate symlink, or make an attacker-controlled
  check/move race impossible. `NSFileCoordinator` coordinates participating
  file presenters; do not treat it as an adversarial filesystem security
  primitive. A source string, one final-component symlink fixture, and an
  in-process concurrency test are insufficient proof of addition 048.
- Choose one explicit implementation boundary after the required caller/blast-
  radius map. Either harden `AtomicVaultWriter` for all existing callers without
  weakening their current atomic/durability/baseline contracts, or add a narrow
  vault-metadata/scaffold transaction whose handles and receipts cannot be
  misused as a generic writer. Do not partially change the shared writer just
  to make FirstRun tests pass. Protected or unrelated dirty callers remain
  preserved; any shared-writer edit must enumerate each call site, old baseline
  semantics, target type, fault behavior, and test/handoff impact first.
- Identity-bound transaction requirement: component-walk the approved
  canonical vault root and `.epistemos` parent without following links; keep
  verified directory handles or equivalent file identities through child
  inspection and publication; require the expected directory/regular-file
  types and reviewed link-count policy; create scratch and new directories only
  beneath the held parent; durably sync the file and parent; and use a verified
  atomic no-replace publication for the fresh receipt. Revalidate the held root,
  parent, and published target identities after the operation. A baseline-race
  loser must boundedly open and validate the winner without following a link.
  If the chosen Foundation/POSIX primitive cannot provide these properties on
  every supported macOS version, record the exact gap and fail closed or defer
  the fresh creation rather than claim compare-and-swap safety.
- Apply the same identity discipline to scaffold creation and rollback.
  `createDirectory(withIntermediateDirectories: true)` plus a prior
  `fileExists` is not a safe type check. For each `_inbox`, `_inbox/review`,
  `daily`, and `notes` component, distinguish absent, expected directory,
  symlink/alias, regular file, and special object under the held parent. Record
  invocation-created identities, not only URLs, and on failure remove only an
  exact still-empty object whose identity is unchanged; never follow or delete a
  replacement/user canary. Metadata validation still precedes any scaffold
  mutation for an existing receipt.
- Adjacent diagnostic correction: `AtomicVaultWriter.closeFileHandle` currently
  emits `error.localizedDescription` with `.public`; an underlying filesystem
  error may contain a user path. FirstRun cannot claim canary-safe diagnostics
  while that shared path remains reachable. Use a bounded typed/content-neutral
  reason or private/redacted transport, and audit every newly reachable writer,
  coordination, decoder, rollback, and lifecycle error before showing/logging
  it. Do not copy arbitrary `localizedDescription` into a toast or recovery
  issue.
- Fail-first proof must exercise symlinks/dangling links and wrong types at the
  vault root, `.epistemos`, metadata target, every scaffold parent/leaf, and the
  scratch/publication boundary; root/parent/target replacement between every
  check and use; hard links where supported; two processes or an equivalently
  independent race actor in addition to tasks; winner corruption/oversize;
  fsync/publish/parent-sync failures; and rollback after replacement. Seed
  outside and in-vault canaries, assert identities/link counts/bytes rather than
  only paths, and prove no canary reaches logs/errors. Keep the narrow source
  guard only as an architecture cue; it is not runtime evidence. Record which
  adversarial races remain serial/macOS integration debt.
- Sequence: 051 is not a later optional hardening pass. Reconcile it inside the
  active 043/048/049 FirstRun transaction before changing the publication or
  lifecycle implementation. It changes no ownership boundary and does not
  authorize Xcode/app/artifact execution, Settings/Lane B edits, a model action,
  a shared-writer rewrite without its audit, a commit, or the final rebuild.

### `LR-LIVE-2026-07-16-052` — quarantine the first 048 implementation until its path races and lifecycle gaps are corrected

- Immediate observed-diff checkpoint: the worker replaced the complete
  `FirstRunBootstrap.swift` file in one delete/add patch before seeing additions
  050–051. Preserve its useful catalog removal, bounded final-file read,
  duplicate/unknown envelope checks, inert historical-pin limits, content-
  neutral bootstrap errors, and fresh no-pin encoding, but do not integrate or
  describe this draft as hardened. A parse-only `swiftc -parse` result is not a
  typecheck, test, filesystem-race, mounted lifecycle, or App Store receipt.
  Before further source mutation, reread the current full prompt, record its
  hash and additions 050–052 in the ledger, inspect the full replacement diff,
  reconstruct the removed-symbol/caller/test map, and supply the retroactive
  whole-file ownership/blast-radius/rollback analysis required by the project
  instructions. Continue with surgical hunks; do not repeat whole-file
  replacement.
- Concrete containment defect: `canonicalVaultURL` checks only whether the
  final supplied URL is a symlink, then calls `resolvingSymlinksInPath` and
  accepts the resolved result. `pathEntry`, `attributesOfItem`, and later URL-
  path operations likewise do not hold or validate every intermediate
  component. A symlinked/replaced parent can redirect an apparently missing
  root, `.epistemos`, scaffold, read, write, or rollback outside the admitted
  vault. Textual `standardizedFileURL` plus `child.path.hasPrefix(rootPath)`
  proves string shape, not filesystem identity or bookmark/scope containment.
  Reject or deliberately resolve links under one uniform policy before
  mutation, and bind the chosen root and every parent through the transaction as
  required by 051; never silently resolve intermediate links while rejecting
  only the leaf.
- Concrete check/use and rollback defects: `createDirectoryIfMissing` runs a
  path inspection, calls `createDirectory`, and inspects the path again without
  proving it is still the directory this invocation created. Concurrent normal
  creation becomes a generic unsafe-object failure, while adversarial
  replacement remains possible. `rollbackEmptyDirectories` records only URLs,
  reopens each current path, checks current emptiness, then calls `removeItem`;
  a replacement between those steps can delete a different empty object or an
  object reached through a swapped parent. Replace URL receipts with held/
  revalidated file identities and an atomic/identity-safe cleanup strategy.
  Add race-loser success behavior for an independently valid simultaneous
  scaffold, but never accept or delete an unproven replacement.
- Concrete publication defect: the draft still delegates fresh receipt writing
  to `AtomicVaultWriter.writeSynchronously(... ifCurrentMatches: .absent)`.
  That shared helper uses the exact path-level `fileExists` plus later
  `moveItem`/`replaceItemAt` sequence identified in 051 and recursively creates
  the target parent. Reading the winner after `baselineMismatch` does not repair
  the unbound parent/target publication window. Implement and test an actual
  identity-bound atomic no-replace publication or fail closed/defer; do not make
  the new source-string assertion the acceptance gate. Also handle a valid race
  winner surfaced as an already-exists publication error only after opening and
  validating that exact winner safely; all other writer failures remain typed
  failures.
- Concrete read/revalidation limit: `open(... O_NOFOLLOW)` plus `fstat` improves
  the final metadata-file boundary, but the draft opens by a full path under
  unheld parents, so an intermediate swap can redirect the read. Its before/
  after checks bind device/inode/size but do not prove immutable bytes if an
  existing inode is rewritten in place without a size change. Open relative to
  the held metadata-directory identity, define the supported concurrent-
  modification policy, and obtain one stable bounded byte receipt (for example
  by a verified coordination/locking or repeatable identity/content strategy)
  before decoding. Preserve existing supported bytes without rewriting them,
  but do not claim byte identity or race safety from size equality alone.
- Concrete default-path miss: the draft correctly replaces the machine-wide
  `.userDirectory` fallback with `homeDirectoryForCurrentUser`, but it retains
  nonthrowing `defaultVaultURL` and `preconditionFailure` for invalid runtime-
  audit configuration. It also returns candidate URLs without the typed parent/
  root safety and writable-location validation required by 048. Make default
  resolution throwing/result-typed, propagate failure through onboarding
  without setup completion, and add injected invalid-audit/unavailable-
  Documents/unusable-home tests. No crash, relative/shared/root fallback,
  implicit directory creation, or swallowed error is allowed.
- Concrete transaction-order gap: the draft validates existing metadata before
  scaffold mutation, which is correct, but for a fresh vault it creates the
  whole scaffold before securely publishing the admission receipt and lacks a
  durable transaction phase/identity receipt. Define the recoverable partial-
  state policy precisely: after every injected boundary, the next attempt must
  either validate one receipt and finish the exact scaffold or safely create it;
  it may never call a partially initialized vault admitted/ready. Bind
  `createdFolders` to invocation identities, not URLs, and do not report folders
  created by another contender as this invocation's work.
- Test correction before production routing: keep the current corrupt,
  oversize, leaf-symlink, wrong-type, and source-shape tests as initial
  regression cases, but mark them incomplete. Add intermediate-parent and
  root-swap races, metadata same-size rewrite, special files, hard links,
  no-replace winner variants, concurrent scaffold creation, identity-safe
  rollback canaries, invalid typed default resolution, supported historical-
  byte preservation, and diagnostic canaries. Tests must assert typed errors
  and post-state/identity, not broad `Error.self`, path existence, or source
  substrings alone. Typecheck and execute focused tests only in the authorized
  serial/Xcode leg; until then record them as unexecuted source fixtures.
- Lifecycle quarantine: do not now thread this draft into
  `VaultSyncService`, onboarding, restore, or recovery simply to satisfy the
  reachability source guard. First make the neutral transaction meet 048,
  051, and this checkpoint. Then implement 049's single staged admission owner
  with vault A preserved through candidate-B admission and explicit mounted/
  importing/ready truth. If ownership or platform primitives prevent that
  safely in the current source-only leg, keep the production routes unchanged,
  record an exact protected handoff/serial blocker, and do not manufacture
  reachability or readiness evidence.
- Sequence/ownership: 052 is the immediate continuation of 043/048/049/051 and
  precedes 046 and all model work. It authorizes only the already mapped Lane R
  bootstrap/non-Settings connection seam after prompt/ownership reconciliation.
  It does not authorize a shared-writer change without its caller audit,
  Xcode/app/artifact execution, Settings/Lane B edits, model download/wiring,
  commit, or final rebuild.

### `LR-LIVE-2026-07-16-053` — replace Boolean scope/admission plumbing and fire-and-forget mount with one awaited state machine

- Newly observed lifecycle draft remains quarantined under 052. It adds
  `VaultCandidateAdmission`, a typed assessment result, restore/recovery calls,
  and an admission overload, but it was written before the worker reconciled the
  current prompt and inherits the unsafe bootstrap. Do not treat the presence of
  those names, a parse result, or an admission-before-`beginWatching` call as
  049 proof. Re-read and ledger additions 050–053 before another source edit,
  then audit/rework these exact hunks rather than layering more compatibility
  wrappers on them.
- Security-scope ownership is currently inverted. `admitVaultCandidate` assigns
  `admissionOwnsScope = scopeAlreadyAcquired`; an already-acquired scope is
  borrowed from the caller/current lifecycle and admission does not own the
  matching start/stop balance. Failure can consequently stop a borrowed scope.
  Other branches start access on `requestedURL` but later stop
  `bootstrapReceipt.vaultURL`, which may differ after standardization/resolution,
  and they call `stopAccessingSecurityScopedResource` directly rather than the
  injectable/audited stop owner. Replace the two Booleans
  `scopeAlreadyAcquired`/`releasesSecurityScopeOnFailure` with one linear scoped-
  access lease recording exact start URL/identity, owner, transfer state, and
  exactly-once release. Borrowed, newly owned, current-vault reused, transferred
  to mounted lifecycle, abandoned, and already-released states must be
  unrepresentable or explicitly checked; canonicalization may not switch the
  resource that receives the balancing stop.
- The typed folder result is immediately weakened by the retained compatibility
  `vaultFolderSelectionAssessment`, which maps every `missing`, `unreadable`,
  `wrongType`, `unsafeLink`, and `scanFailed` result back to a zero-count valid-
  looking assessment. Restore and interactive connection still call that old
  wrapper. Remove the lossy production API or restrict an explicitly named
  fixture helper to tests; every production caller must exhaustively handle the
  typed result. The typed implementation itself still uses path-based
  `fileExists`/resource values and a directory enumerator without an error
  handler, so traversal failures can be skipped and returned as `.valid`.
  Validate a positive bounded `scanLimit`, bind assessment to the admitted root
  identity/scope, capture every enumeration error and target replacement, and
  return `.scanFailed` rather than a partial count unless an explicitly
  documented conservative partial-scan policy can prove safety.
- `startWatching` silently changed from synchronous `Void` mutation to a
  `Task { @MainActor ... }` wrapper that returns before admission or mount and
  discards both failures. Existing caller sequencing and tests can observe old
  state, clear pending restore, proceed with UI, or report success without a
  result. Delete the fire-and-forget compatibility path from production. Make
  every interactive, restore, recovery, same-vault, and helper caller await one
  typed admission/mount/readiness operation; return distinct cancelled,
  admission-failed, mount-failed, importing/persisted-for-recovery, ready, and
  stale-epoch outcomes. A legacy wrapper may exist only when its caller contract
  truly does not depend on completion and it still surfaces failure—none is
  presently proven.
- Preconstructed search is not yet candidate readiness. Admission creates a
  second `SearchIndexService` using the shared `searchDatabaseURLOverride`
  while the current service/vault remains live, then installs it immediately at
  mount. Prove whether construction opens, migrates, locks, reads, or mutates the
  same global database; whether two instances are safe; and how rows/generation
  are bound to candidate versus current vault. A service containing vault-A or
  stale rows may not become query-visible for candidate B during import. Stage
  candidate search/index state in an isolated generation/transaction or keep the
  old service authoritative until the candidate's diff/import receipt commits;
  preflight construction alone cannot satisfy index readiness. Gate every query,
  observer notification, manifest, and Halo publication on the mounted ready
  generation.
- The draft still tears down vault A after admission but before B is proven
  mounted/ready, and no retained rollback receipt restarts A. A failed
  `beginWatching`, index install, import, derived work, watcher start, or
  cancellation can leave the app disconnected after `stopWatchingAsync` cleared
  A. Implement the 049 policy: retain sufficient A scope/lifecycle/index/default
  state to restore it on every pre-commit B failure, or transition to one
  explicit durable disconnected-recovery state whose UI/defaults/bookmark/
  crash-recorder/search/window truth all agree. A plain `false`, cleared
  activity string, or generic `recoveryIssue` after partial teardown is not a
  rollback policy.
- Persistence is still split around admission. Restore refreshes/creates and
  stores bookmark bytes before the candidate is admitted; interactive selection
  prepares a bookmark/assessment for the requested URL, mounts a separately
  canonicalized receipt, then commits the earlier selection; recovery commits
  prepared defaults immediately after `beginWatching` returns but before import
  readiness. No branch records an explicit persisted-but-importing recovery
  phase. Candidate admission must bind one prepared selection to the exact
  canonical root and scope lease, then one commit owner must atomically apply or
  roll back bookmark, last path, trusted-suspicious path, has-ever-connected,
  crash URL, lifecycle epoch, search generation, and durable recovery phase at
  the declared mounted/ready boundary. Stale-bookmark refresh may be staged in
  memory before admission but not written as success state.
- `beginWatching` still sets `vaultURL`, lifecycle `.operational`, crash URL,
  `isWatching`, and the new search service before import; starts timers/watcher;
  and returns `true` immediately. The existing lifecycle enum has only
  disconnected/operational/draining, so importing is mislabeled operational even
  though `initialImportCompleted` is false. Introduce admitted, mounting,
  importing, ready, draining, rollback, and failed/disconnected truth (or an
  equally explicit typed design), bind all tasks to its epoch, and prevent user
  search/mutation/success/UI-reset behavior until the appropriate gate. The
  later import task's success toast is closer to ready truth, but the interactive
  caller still resets windows on the earlier Boolean mount and uses an
  unbounded user-controlled vault name; recovery commits defaults at that same
  early point. Move each effect to its proven boundary and use reviewed bounded
  presentation labels.
- Fail-first lifecycle proof: use injected scope start/stop counters and distinct
  requested/canonical URLs to catch borrowed-scope stop, wrong-URL stop, double
  stop, leak, no-op leak, and transfer/abandon races. Exercise every typed
  assessment outcome through every caller, enumerator mid-scan error, two rapid
  candidates, A→bad-B at each teardown/mount/import/watcher boundary, same-vault
  revalidation, stale restore, recovery, task cancellation/deallocation, and
  relaunch from persisted-importing/failed state. Assert authoritative lifecycle
  phase, defaults/bookmark/crash URL, security lease, active search generation,
  windows, toasts, watchers, old/new task publication, and diagnostic canaries.
  Source guards must prove the lossy wrapper and fire-and-forget production path
  are absent; mounted/UI/security-scope evidence remains honest serial debt.
- Sequence/ownership: 053 extends the immediate 043/048/049/051/052 correction
  and precedes 046/model work. Do not continue onboarding/connection integration
  until the bootstrap quarantine and linear admission design are resolved. It
  grants no shared-database/writer rewrite without caller audit, no Settings/
  Lane B, Xcode/app/artifact/model action, commit, or final rebuild.

### `LR-LIVE-2026-07-16-054` — batch code and build/test verification checkpoints

- Owner override: the exact build/test wording in the intent section supersedes
  every earlier blanket `source-only`, `no Xcode`, `do not build`, or `do not
  test` restriction in this prompt, but only for scoped Lane R verification.
  The worker may use `swiftc` parse/typecheck, focused Swift and Rust unit tests,
  relevant Cargo check/test commands, affected Xcode target compile/tests, and a
  broader Free app scheme build/test when the current batch is stable. It may
  not edit Lane B/Settings to make a check pass, fetch or execute an embedding
  model, manually launch/use the product, sign, notarize, archive, deploy, or
  publish a release unless a later explicit owner steer authorizes that action.
- Work in coherent code batches, not one unverified mega-batch and not a full
  rebuild after every micro-edit. Before coding each batch, write its owner-intent
  checkpoint, owned files/seams, expected behavior, risk boundary, fail-first
  tests, and verification plan. Maintain a verification-debt entry containing
  every touched file, deferred command, reason for deferral, expected proof,
  risk, and the exact trigger that ends the deferral. A narrow high-risk check
  must run before crossing the boundary it protects; batching is never license
  to accumulate unbounded or safety-critical verification debt.
- At each batch checkpoint, run the smallest useful evidence ladder in order:
  inspect the changed region and complete diff; run format/static/source guards;
  run focused parse/type/unit/adversarial tests; compile/test the affected target;
  then build/test the broader Free scheme when the slice is stable. Record the
  exact command, configuration, destination, exit status, salient output, and
  attribution for every failure or skip. Fix Lane R regressions; preserve and
  explicitly hand off unrelated Lane B/Settings or pre-existing failures rather
  than modifying out-of-scope files to manufacture green output.
- Mandatory checkpoints are: (1) after the premature lifecycle integration is
  surgically reverted and the source is stable; (2) after the identity-bound
  FirstRun transaction is implemented; (3) after the awaited typed vault
  lifecycle/state-machine slice is implemented; (4) after the mounted SQLite
  retrieval slice in addition 046; (5) after any selected embedding/runtime
  integration batch; and (6) immediately before
  `READY_FOR_SERIAL_INTEGRATION_VERIFICATION`. Add intermediate checkpoints when
  blast radius or failure evidence warrants them.
- Put DerivedData, build products, caches, and other generated outputs outside
  the repository where the tools permit. Remove only known worker-created
  transient output; never use destructive cleanup or erase an unknown dirty
  file. A passing source check, focused test, or Debug build proves only the
  named layer. Preserve separate Release/App Store/resource/artifact/runtime/UI
  debt until the corresponding evidence actually runs.
- Before the next source edit, record this addition and the new prompt hash in
  the scoped ledger and reconcile the existing verification-debt plan. The first
  authorized batch checkpoint is the completed 053 lifecycle-reversion slice;
  verify that the premature routing is absent and the stabilized owned source
  parses/tests/builds at the narrowest relevant levels before proceeding.

### `LR-LIVE-2026-07-16-055` — save the verified checkpoint and start the rebuild automatically

- Owner override: once Lane R, Lane B, and required serial-integration handoffs
  have produced the honest, build/test-verified baseline described below, do not
  stop to ask the owner whether to commit or begin the rebuild. Addition 055 is
  that authorization. The coordinator must save the attributed checkpoint,
  record its receipt, transition the completed scoped goal, and immediately
  activate the successor whole-app simulated-rebuild goal/execution phase.
- Readiness is semantic, not ceremonial: every intended baseline file is
  attributed; no other agent is mid-edit; protected-lane handoffs are reconciled;
  required checks have run or bounded debt is explicit; the full diff and staged
  diff are inspected; generated output is excluded; and rollback is proven. If
  those conditions are not true, continue the relevant reconciliation and
  hardening work without requesting a redundant approval. If a real external or
  ownership blocker remains after safe alternatives are exhausted, fail closed
  and report the exact blocker; never manufacture a mass checkpoint.
- Stage explicit reviewed paths—never blind `git add -A`—and create the single
  pre-rebuild integration checkpoint commit with a descriptive message. Record
  branch, parent, tree and commit SHA, included and excluded workstreams, exact
  verification receipt, remaining debt, and rollback procedure. Do not push,
  open a PR, tag, publish, sign, notarize, deploy, or release unless separately
  authorized.
- Automatic activation broadens implementation ownership only after that commit.
  Until its SHA is recorded, all Lane R/Lane B/Settings boundaries remain. After
  it is recorded, re-read repository instructions, create a fresh app-wide
  owner-intent checkpoint and rebuild ledger, load the skills required by 039,
  build the atlas before mutation, and begin the highest-risk/highest-leverage
  vertical V2-quality rebuild slice. Do not stop at a plan, audit, or mock-up.

### `LR-LIVE-2026-07-16-056` — make the 455-file dormant Swift test corpus honest and executable by slice

- Newly measured verification contradiction: current `project.yml`, the generated
  `Epistemos.xcodeproj`, and `xcodebuild -list` expose only the app, widget, and
  eight-file `EpistemosAppStoreKeelstoneTests` test target. The repository has 455
  Swift files under `EpistemosTests`, including the current
  `FirstRunBootstrapTests.swift`, but no `EpistemosTests` target. `Makefile`, CI,
  and numerous runner/audit scripts still pass `-only-testing:EpistemosTests`.
  A parsed dormant file, a command naming a nonexistent test target, or a green
  session that executed zero matching tests is not test evidence.
- Do not solve this by blindly adding all 455 files to the Free test bundle.
  Much of that corpus predates the current product boundary and may positively
  require canceled paid types, stale files, duplicate helpers, generated stress
  suites, unsupported resources, or obsolete behavior. First produce a machine-
  readable test-membership inventory classifying every file as executable Free
  behavior test, executable Free source/artifact guard, helper/fixture, paid or
  future-edition test, stale/deleted-product test, generated/performance/manual
  suite, or unresolved. Record target, imports/dependencies, owner, current
  compile status, last credible execution receipt, and disposition; no file may
  be counted merely because it is under a directory named `Tests`.
- Make each active Lane R slice's fail-first tests genuinely executable before
  claiming its batch checkpoint. For FirstRun and the vault lifecycle, include
  the reviewed focused tests plus only their required helpers/fixtures in a real
  Free test target, or migrate them surgically into the existing active target.
  Do not duplicate the same suite into competing targets or convert runtime
  behavior proof into source-substring assertions. Any `project.yml`/generated
  project change requires a target-membership ownership map, complete generated
  diff inspection, rollback path, and preservation of protected Settings/Lane B
  files and unrelated project changes.
- Reconcile `Makefile`, CI, and owned verification wrappers with the real target
  graph. A wrapper must fail when an `-only-testing` selector matches no bundle,
  suite, or test. For every focused run, preserve the result bundle and record
  the requested identifiers, discovered identifiers, executed/passed/failed/
  skipped counts, configuration and destination, and exit status. Assert the
  expected named fail-first cases actually executed; `** TEST SUCCEEDED **` or
  exit zero alone is insufficient. Do not rewrite protected CI or other-owner
  scripts without ownership; record an exact handoff where necessary.
- Immediate checkpoint consequence: finish addition 054(1) using real active
  Keelstone tests/source guards and an affected app-target build as available,
  but label every dormant `EpistemosTests` assertion unexecuted. Before the
  identity-bound FirstRun implementation can close addition 054(2), establish a
  real executable path for its focused behavioral tests and prove nonzero named
  execution. The full 455-file classification may continue as bounded P0-E/
  rebuild-atlas debt; it cannot be used to delay the current focused truth fix.

### `LR-LIVE-2026-07-16-057` — seal inert legacy metadata and make rollback/bookmark work bounded

- Newly observed FirstRun API contradiction: `FirstRunBootstrap.Metadata`
  exposes `embeddingModelPin` and `routerModelPin` as public mutable properties,
  returns them through every runtime `Receipt`, and the dormant focused test
  positively asserts their decoded string values. Additions 043/048 permit those
  keys only as bounded inert compatibility data needed to preserve existing
  bytes and explicitly forbid making them newly writable or using them as model
  authority. Do not turn retired download identities into a convenient public
  runtime API merely because no current caller was found.
- Separate the fresh canonical receipt from the legacy compatibility envelope.
  Fresh/runtime metadata exposes only fields the Free app may act on. Decode and
  validate historical pins in the smallest non-public compatibility shape, keep
  the original bounded bytes as the preservation authority, and expose no pin
  accessor, mutator, model/cache/Hub lookup, log/debug text, or synthesized fresh
  encoding route. Tests assert byte-identical preservation, bound rejection, and
  absence of executable/runtime reachability—not the recovered pin strings.
- `rollbackEmptyDirectories` currently reopens a URL, observes a directory and
  emptiness, then removes the current name. Holding or rechecking an inode before
  a name-based `removeItem`/`unlinkat` does not make deletion conditional on that
  inode; a replacement can still be deleted after the final check. If the chosen
  macOS primitives cannot atomically remove only an exact recorded identity,
  prefer a safe idempotent partial scaffold/scratch receipt and leave it for a
  bounded retry over an unsafe cleanup claim. Never delete, move, chmod, or
  overwrite a replacement to make rollback appear clean. Inject replacement at
  every cleanup boundary and prove all user/outside canaries survive.
- Newly mapped bookmark work is also unbounded and duplicated.
  `startupBookmarkValidation` resolves arbitrary `UserDefaults` data
  synchronously; `resolveVaultBookmarkWithTimeout` races an uncancellable
  synchronous resolver in one detached task against a timer in another, so a
  timeout does not stop the resolver and repeated attempts can accumulate late
  work. Restore also copies legacy-domain bookmark bytes into current defaults
  and deletes the old value before candidate admission/readiness, while other
  branches refresh persisted bookmark bytes before the same gate.
- Define a measured maximum bookmark byte envelope for current, legacy, prepared,
  cached, and refreshed data before resolution or persistence. Converge startup
  validation, restore, recovery, and interactive selection on one typed,
  lifecycle-epoch-bound resolver/admission path. Because Foundation bookmark
  resolution is synchronous, enforce a bounded single-flight policy: after a
  timeout, ignore late results and do not spawn unbounded replacement resolvers;
  cancellation/deallocation/relaunch behavior must be explicit. Stage legacy
  migration in memory, preserve the old value until the new admitted selection
  and declared durable boundary commit, and delete it only after a verified
  migration receipt. Corrupt/oversize/stale/timeout/scope-denied data must leave
  old defaults, current vault, scope count, crash URL, search generation, and UI
  truth unchanged or enter the one declared durable recovery state.
- Fail-first proof: executable tests must cover minimum/maximum/oversize and
  corrupt current/legacy bookmark data, synchronous and async resolver parity,
  timeout followed by repeated restore attempts, late resolver completion after
  cancellation/new epoch, migration failure at every defaults mutation, and
  rollback name replacement. Assert bounded task count, exact defaults bytes,
  migration source retention/deletion boundary, lease balance, no canary logs,
  and post-state identities. This remains inside the active FirstRun/lifecycle
  sequence and does not authorize model action, Settings/Lane B edits, or an
  early checkpoint commit/rebuild.

### `LR-LIVE-2026-07-16-058` — repair the build-exposed query failure without preserving the provenance bug

- New batch evidence: addition 054(1)'s unsigned focused Xcode test reached app
  Swift compilation and executed zero tests because the current
  `QueryRuntime.swift` P0-A/A2 diff does not compile. The edge `compactMap`
  closure constructs but does not return `QueryResultEdge`; label resolution
  treats `GraphStore.SearchHit` as though it directly had a node `type`, leading
  the compiler to diagnose `.first(where:)` as a call on `SearchHit?`. These are
  real current Lane R regressions. `QueryRuntime`, `ProductCapabilityPolicy`, and
  eligible focused query tests are explicitly Lane R-owned by additions 006 and
  054 even if this FirstRun sub-batch did not author their dirty hunks. Record
  their prior ownership/diff, then repair them in a bounded prerequisite batch;
  do not classify them as an external blocker or advance to a test-dependent
  FirstRun checkpoint while the owned Free target cannot compile.
- Do not stop at adding `return` and changing the member access. The same hunk
  still calls only `allowsGraphProjection(of: GraphNodeType)`, and
  `sanitizeForCurrentProduct` filters already-converted `QueryResultNode` values
  after `GraphNodeMetadata` has been discarded. Current label resolution asks
  `fuzzySearch` for its top 50 and only then filters, so hidden records can consume
  the limit and change or erase the selected visible node. Edge/traversal code
  likewise lacks addition 006's authoritative record-level paid-provenance gate.
  A compiling type-only filter would preserve the security/product defect.
- Implement one authoritative record predicate that rejects forbidden types and
  allowed-looking records carrying typed paid provenance such as
  `originChatId`, while preserving genuinely user-authored records whose text
  merely mentions paid terms. Apply it to actual `GraphNodeRecord` values before
  fuzzy candidate ranking/limit, direct/label/type resolution, conversion,
  ordering/paging/aggregation, edge label construction, connection counts, and
  neighbor/path traversal. Hidden nodes and edges form no bridge in the allowed
  induced subgraph. Any cached search key/result must not mix filtered and
  unfiltered candidate universes. Keep the final result sanitizer only as defense
  in depth; it cannot be the first provenance-aware gate.
- Make the existing fail-first matrix described in addition 006 executable under
  addition 056. It must seed a visible user-authored idea, an allowed-type idea
  with `originChatId`, forbidden types, more hidden high-rank label hits than the
  previous fuzzy limit, a lower-ranked visible match, and an allowed-hidden-
  allowed path. Prove exact ID/label/fuzzy/filter/edge/neighbor/path/aggregation/
  paging behavior, no hidden labels or endpoints, no false rejection of ordinary
  paid-term text, cache separation, and deterministic limits. First run a narrow
  compile/type/test receipt, then repeat the isolated affected-target test and
  assert a nonzero named test count. Preserve unrelated dirty work and do not
  edit protected graph UI/Settings/Lane B seams.
- Sequence: 058 is the immediate prerequisite exposed by checkpoint 054(1).
  Reconcile and verify it before source mutation in 057/FirstRun, then refresh the
  live prompt and resume additions 051–057. This does not authorize a model
  action, release/signing work, commit, or early successor rebuild.

### `LR-LIVE-2026-07-16-059` — enforce the live-refresh barrier and quarantine the post-hash FirstRun fixture

- Immediate coordinator evidence: the prompt changed to the revision containing
  additions 056–058 at 2026-07-16 01:09 CDT, but the worker had not recorded
  that revision or its hash before adding
  `EpistemosAppStoreKeelstoneTests/FirstRunBootstrapSecurityTests.swift` at
  approximately 01:14 CDT. The fixture is isolated, fail-first, and
  non-destructive as source, but it crossed the explicit “before the next
  source edit” refresh barrier. Quarantine it as unverified post-hash work. Do
  not delete, expand, execute, count, or integrate it until the complete live
  prompt is reread and this addition is reconciled in the ledger.
- Correct the newly written `FR-IDENTITY-001` checkpoint before any further
  source mutation. It calls a QueryRuntime repair a non-goal and says not to run
  the target while the QueryRuntime error remains; additions 056 and 058 make
  the opposite sequence controlling. The active prerequisite is to repair the
  Lane R-owned QueryRuntime/ProductCapabilityPolicy record-projection slice,
  make its focused fail-first matrix executable, and prove nonzero named test
  execution. Only after that verified compile/test boundary may the worker
  resume the FirstRun transaction. Preserve the useful FirstRun analysis as
  pending work rather than using it to bypass the prerequisite.
- Correct the owner-intent history in the same ledger entry. The quoted earlier
  wording about retaining June is not the active Free V1 directive. The later
  owner correction—“i forgot that i was telling agetns to hide june and stuff
  but it should be removed because this is the free version”—supersedes it for
  this product. Free V1 removes June, other agents, chat/generative/provider
  behavior, and paid execution surfaces; Kokoro read-aloud and the separately
  retained/audited search embedding are the explicit model boundaries. Do not
  cite an obsolete excerpt as current intent without the later superseding
  steer and its disposition beside it.
- Refresh enforcement is a mutation gate, not a documentation ritual. Before
  every subsequent source/test/project/build-wrapper edit, compute the live
  prompt hash and compare it with the last ledgered hash. On mismatch: stop,
  read the complete file in bounded ranges through EOF, recompute the hash,
  record every new addition and any changed sequence/ownership/non-goal, update
  the active plan and verification-debt ledger, then recheck the hash
  immediately before editing. Read-only inspection may continue while stale;
  no source, test, project, build wrapper, or worker-owned checkpoint claim may
  change. A partial read, remembered summary, line-count check, or later
  acknowledgment does not retroactively authorize a crossed barrier.
- Immediate next action: finish the full refresh, record the post-hash fixture
  violation and corrected owner/sequence checkpoint, inspect the quarantined
  fixture without changing it, then begin addition 058's bounded query-policy
  prerequisite. No FirstRun transaction implementation, F_FULLFSYNC helper,
  lifecycle mutation, model action, Settings/Lane B edit, commit, or successor
  rebuild may proceed under 059.

### `LR-LIVE-2026-07-16-060` — stop and quarantine the unreviewed whole-file FirstRun transaction

- New crossed-barrier evidence: after the prompt contained additions 056–059
  and before acknowledging any of them, the worker added the large new
  `Epistemos/Vault/FirstRunVaultTransaction.swift`, immediately patched it, and
  invoked a Swift typecheck against it. This is a second refresh-gate violation
  and also violates the explicit no-whole-file/subsystem-replacement boundary:
  the file introduces hundreds of lines of new filesystem transaction code
  without the controlling query prerequisite, executable fail-first matrix,
  complete review, or rollback checkpoint. Its presence and any parse/typecheck
  output are non-proof. Stop this FirstRun implementation branch now.
- Quarantine the entire new transaction file and the post-hash FirstRun test as
  unaccepted draft work. Do not patch around its compiler errors, wire it into
  `FirstRunBootstrap`, add more tests for it, run it, or let it influence a
  checkpoint. After the full refresh and ledger correction, inspect the complete
  added file and current status/diff; then remove only these worker-created,
  untracked post-hash draft files with an explicit path-scoped deletion patch,
  after proving they did not pre-exist and contain no other-owner work. Record
  their exact paths, hashes, authorship/evidence timestamps, deletion diff, and
  rollback source (the session patch/ledger). Do not reset, checkout, clean, or
  touch any tracked/unrelated dirty file.
- The draft also has concrete reasons it cannot be retained as a hidden head
  start: it exposes a raw descriptor accessor after first attempting reflective
  access to private state; creates a root before existing metadata can be
  validated; leaves scratch files intentionally without a bounded receipt or
  retry cleanup policy; equates mtime/ctime/size and two reads under a shared
  lock with immutable bytes; and has not proved descriptor lifetime, race-
  winner attribution, directory sync portability, File Provider behavior,
  rollback, cancellation, or diagnostic safety. These are examples, not an
  exhaustive review. Reuse no code from it until the later FirstRun batch is
  independently redesigned from the controlling contract with executable
  fail-first proof.
- Before the cleanup patch, perform the addition-059 full prompt reread and
  record the new hash plus additions 056–060. Correct `FR-IDENTITY-001` and the
  stale June owner-intent excerpt; update the active plan so addition 058 is in
  progress and FirstRun is pending. After the two path-scoped draft deletions,
  recheck the live prompt hash and inspect `git status`/diff to prove no other
  work changed. Then begin only the bounded QueryRuntime/ProductCapabilityPolicy
  prerequisite and its active Keelstone fail-first matrix.
- No further FirstRun, lifecycle, bookmark, model, Settings/Lane B, commit,
  build/release, or successor-rebuild work is authorized under 060. A typecheck
  failure or success from the quarantined file does not change this sequence.

### `LR-LIVE-2026-07-16-061` — surgically unwind every post-refresh FirstRun integration hunk

- Additional crossed-barrier evidence: the worker continued after creating the
  quarantined transaction and, between approximately 01:20 and 01:22 CDT,
  integrated it into tracked source/tests. The session records exact
  `apply_patch` hunks in `FirstRunBootstrap.swift`,
  `SetupAssistantView.swift`, `AppStoreKeelstoneLaneTests.swift`,
  dormant `EpistemosTests/FirstRunBootstrapTests.swift`, and
  `AtomicVaultWriter.swift`; it then ran parse/source scans and announced that
  the transaction was “in place.” None of this is accepted. Parse/typecheck and
  source-string absence do not override additions 056–060 or make the skipped
  query prerequisite disappear.
- After the mandatory full refresh, surgically reverse only the exact
  post-refresh session hunks, in reverse order, using `apply_patch`. Restore the
  immediately pre-01:09 content of each tracked region—do not restore from HEAD,
  replace a whole file, or erase earlier dirty work. Specifically unwind: the
  content-neutral writer log edit (it remains a later justified 051 task but was
  made out of sequence); dormant source-guard/default signature edits; the
  Keelstone `try` call-site edit; onboarding's throwing-default/toast wiring;
  `FirstRunBootstrap`'s added error case, throwing default resolver, transaction
  delegation, removed path/read/scaffold helpers, decoder/encoder reshaping, and
  no-replace comment; and all other exact hunks from the 01:20–01:22 session
  patch records. Then path-delete only the two proven worker-created untracked
  draft files named in 060.
- Before unwinding, record a path/hunk ownership table and hash each current
  file so the operation is auditable. After every reverse hunk, reread the
  changed region. At the end, run `git diff --check`, compare the affected
  tracked regions against their exact pre-breach text captured in the session,
  confirm both untracked draft paths are absent, and inspect full `git status`
  so all unrelated/earlier changes remain. Record a rollback receipt in the
  ledger; do not call the restored pre-breach FirstRun draft hardened or green.
- Do not add adversarial FirstRun fixtures while unwinding. The worker's current
  follow-up inspection has already noticed the path-walk tension around macOS
  temporary-directory aliases/symlinks; do not repair that symptom or adapt the
  draft to `/private/var`. It is one more reason the large implementation needs
  independent redesign later, not a reason to preserve or patch it now.
- Once the exact pre-breach source state is restored, recompute and reconcile
  the live prompt hash, update the plan to `058 in progress / FirstRun pending`,
  and start only the bounded record-level query-policy batch. The already-active
  `FreeV1RemovalBoundaryTests.swift` is the fail-first base; extend it surgically
  for the missing >50 hidden-rank, cache, paging/aggregation, forbidden-type and
  induced-subgraph cases rather than creating a duplicate suite. Do not touch
  protected graph UI/Settings/Lane B files; use an exact handoff where addition
  006 requires a protected consumer change.
- No FirstRun/lifecycle/bookmark/model work, broad build, commit, release, or
  successor phase may resume until addition 058 has nonzero named executable
  test proof and the live prompt permits the next batch.

### `LR-LIVE-2026-07-16-062` — include the alias workarounds and standalone harness in the unwind

- Continuing stale-turn evidence: after additions 060–061 were already present,
  the worker patched temporary-directory helpers in the new security test,
  `AppStoreKeelstoneLaneTests.swift`, and dormant
  `EpistemosTests/FirstRunBootstrapTests.swift` to call
  `resolvingSymlinksInPath`; added a new `resolveDefaultVaultURL` seam and
  fallback-catching branch to `FirstRunBootstrap.swift`; created
  `/tmp/epistemos-codex-laner-identity-stub.swift` and
  `/tmp/epistemos-codex-laner-identity-harness.swift`; compiled a standalone
  `/tmp/epistemos-codex-laner-identity-harness`; and executed it. These actions
  are also out of sequence and quarantined. A custom harness compiled beside
  stubs is not the real Free target, real test discovery, App Sandbox,
  security-scoped bookmark, File Provider, or mounted lifecycle evidence.
- Extend 061's reverse-order unwind to the exact alias/helper/default-resolver
  hunks recorded by the session. Do not retain the test `resolvingSymlinksInPath`
  adaptations or the new resolver seam as opportunistic improvements. They may
  be reconsidered later from a fresh fail-first design, but currently depend on
  the unaccepted transaction and alter pre-breach test/source behavior.
- After proving ownership/path identity, remove the three known worker-created
  `/tmp` harness artifacts above, including the compiled binary, and record
  their absence. Remove no other `/tmp`, DerivedData, app, archive, cache, or
  unknown artifact. The existing `/tmp/epistemos-codex-laner-054` Xcode result
  root remains the separately recorded checkpoint artifact until its evidence
  disposition is reconciled; do not conflate or delete it under 062.
- Do not patch or rerun the standalone harness, add more FirstRun tests, or use
  its output as a reason to continue. The immediate order remains: full prompt
  reread and ledger correction; exact post-hash unwind/cleanup receipt; live
  hash recheck; then addition 058 only.

### `LR-LIVE-2026-07-16-063` — remove the continuing standalone POSIX probe as non-proof

- The same stale turn additionally created and executed
  `/tmp/epistemos-codex-laner-posix-probe.swift` and the compiled
  `/tmp/epistemos-codex-laner-posix-probe`, after using ad hoc Python/readlink
  inspection to resolve the temporary directory and component aliases. Treat
  the probe source, binary, output, and inference as quarantined diagnostic
  work only. It is not app code, a Free target, an XCTest/Swift Testing bundle,
  an independent adversarial actor, a sandbox/bookmark/File Provider run, or a
  durability receipt.
- Add those two exact worker-created paths to 062's path-scoped `/tmp` cleanup
  after ownership verification. Delete no surrounding temp directory or unknown
  file. Record the probe command/output only as the reason the draft was stopped;
  do not preserve it as acceptance evidence or adapt production/test code to
  make the probe green.
- The next mutation remains the exact unwind required by 060–062 after a full
  reread through this addition. No more exploratory FirstRun source, test,
  harness, probe, or build action may precede it.

### `LR-LIVE-2026-07-16-064` — correct the over-broad FirstRun rollback before any query edit

- New rollback-breach evidence: at approximately 01:35:28 CDT, after correctly
  deleting the two quarantined untracked files and reversing the small tracked
  call-site/test/writer hunks, the worker applied a large hand-reconstructed
  patch to `Epistemos/Vault/FirstRunBootstrap.swift`. That patch did **not**
  restore the exact pre-01:09 tracked state required by 061. It rolled past the
  breach boundary and discarded earlier dirty hardening, while introducing a
  different weak implementation. Stop before accepting the unwind, writing its
  rollback receipt, editing QueryRuntime/policy/tests, or running any build.
- The current wrong state is concretely distinguishable from the pre-breach
  state recorded by the worker's own session patches: it removed the pre-breach
  `Darwin` import, `PathEntry`, `metadataRace`,
  `metadataPublicationFailed`, canonical-root/contained-child/path-entry/
  bounded-descriptor-read/preflight/create-directory helpers, absent-baseline
  atomic publication, and sanitized rollback; it instead uses raw
  `fileExists`, broad `withIntermediateDirectories`, `Data(contentsOf:)`, and a
  public vault-path log. It also substituted a different default-vault fallback
  and alias resolution rather than merely reversing the post-breach throwing
  resolver. These are neither an exact unwind nor accepted hardening.
- Use the timestamped session patch records—not memory, HEAD, a backup search,
  tests that never execute, or an older weak implementation—as the rollback
  authority. The controlling JSONL is
  `/Users/jojo/.codex/sessions/2026/07/15/rollout-2026-07-15T20-41-38-019f6896-23b3-74b1-8ffd-88be95adc4be.jsonl`.
  Extract and inspect the complete `apply_patch` inputs at
  `2026-07-16T06:20:33.063Z`, `2026-07-16T06:21:00.863Z`, and
  `2026-07-16T06:24:16.870Z`; their removed sides plus reverse chronology define
  the immediately pre-breach text. Also inspect and reverse only the mistaken
  `2026-07-16T06:35:28.831Z` reconstruction. A bounded `jq`/`rg` read of this
  known session file is authorized read-only recovery evidence.
- Restore `FirstRunBootstrap.swift` surgically with `apply_patch`: undo the
  mistaken 01:35 reconstruction, then inverse the 01:24 resolver-seam patch,
  the 01:21 encoder/error/comment patch, and the 01:20 transaction-delegation/
  path-helper patch in reverse order, or apply equivalent exact hunks whose
  final text is proven identical to the recorded pre-breach sides. Do not
  replace the whole file. Preserve all edits that predated the refresh breach,
  even though that restored FirstRun draft remains unsafe and pending later
  redesign.
- Re-read every restored region and prove the final file contains the exact
  pre-breach `PathEntry`, bounded regular-file read, containment/preflight,
  absent-baseline `AtomicVaultWriter` publication, rollback/sanitize, original
  nonthrowing default-vault behavior, and prior error cases—and contains no
  `FirstRunVaultTransaction` or `resolveDefaultVaultURL`. Re-run
  `git diff --check`, inspect the complete affected diff/status, reconfirm the
  two repo draft paths and five named `/tmp` artifacts remain absent, and
  recheck the live prompt hash. Amend the ledger rollback receipt to disclose
  both the over-broad attempt and its exact correction.
- Only after this evidence is recorded may the plan move to addition 058. The
  sequence remains `exact unwind corrected -> record-level query-policy batch
  with nonzero named active Keelstone proof -> FirstRun pending`. Do not retain
  any part of the mistaken weak reconstruction as an opportunistic change.

### `LR-LIVE-2026-07-16-065` — make the FirstRun metadata slice prove no-follow roots and failure-preserved scaffolds

- Current evidence after the completed 058 proof exposes a FirstRun gap that
  cannot be carried into the bookmark/lifecycle phase. The active
  `FirstRunBootstrap.canonicalVaultURL` first inspects only the final candidate
  path and then calls `resolvingSymlinksInPath()`. An intermediate component
  such as `redirect/Epistemos` can therefore redirect the canonical root after
  the final-component inspection. The current active metadata test proves
  legacy-pin opacity and one successful partial scaffold, but it neither plants
  an intermediate-root symlink with an outside canary nor forces metadata
  publication to fail after scaffold creation. A one-test `Passed` result is
  valid evidence only for the behavior it actually exercised.
- Before declaring `FR-METADATA-057A` complete, starting bookmark
  resolver/migration/lifecycle edits, or relying on its 01:36 result as a
  FirstRun security claim, add executable active-Keelstone fail-first coverage
  for: (1) an intermediate root symlink/alias directed outside the intended
  vault tree, requiring a typed fail-closed result with no outside root/canary
  creation or modification; (2) an existing legacy receipt with a symlinked
  `.epistemos` or `vault.json` path, likewise with no outside mutation; and
  (3) deterministic metadata-publication failure after at least one scaffold
  component exists, proving the partial scaffold is retained/retryable and no
  replacement/canary is deleted, moved, overwritten, chmodded, or logged.
  Use disposable paths whose ownership is proven and cleanup only after the
  assertions; test the real App Store/Keelstone target with nonzero named
  execution and inspect its result bundle.
- The implementation must make every admitted root and metadata/scaffold
  component obey the exact no-follow/containment policy required by the test,
  before creation, read, publication, and cleanup. Do not treat URL string
  prefix checks, `resolvingSymlinksInPath()`, `fileExists`, a final-component
  `lstat`, or a best-effort post-hoc recheck as proof of component-safe
  admission. If a narrow in-process seam is needed to inject the deterministic
  write failure, keep it non-public, reset it unconditionally, scope it to this
  bootstrap owner, and show that production callers retain the normal writer;
  do not add another whole-file transaction, standalone harness, or broad test
  hook.
- Preserve the achieved 057A behavior while repairing this boundary: legacy
  bounded bytes remain the preservation authority; fresh/runtime receipts expose
  no pins; no pin string reaches logs/defaults/model or search authority; a
  failed post-create attempt leaves a bounded retryable partial scaffold rather
  than unsafe name-based cleanup; and the shared `AtomicVaultWriter` semantics
  are not relabeled identity-safe or changed out of scope. File Provider,
  cross-process replacement, durable sync, and bookmark single-flight remain
  explicit later proof/debt unless this narrow batch actually proves them.
- Required sequence: re-read the full live prompt and record the new hash;
  update the intent/debt checkpoint to mark the current one-test receipt as
  partial; map exact root/metadata/create/write/cleanup call paths and the
  active target; add the fail-first cases; implement the smallest surgical
  component-safe repair; run source/diff checks and the selected active tests
  under the existing resource/signing gates; inspect nonzero test identifiers
  and result counts; then conduct one scoped deep-hardening pass. Do not move
  into bookmark/lifecycle work, claim FirstRun security completion, commit, or
  start the successor rebuild until this receipt and remaining named debt are
  recorded.

### `LR-LIVE-2026-07-16-066` — do not route a no-follow FirstRun receipt through the path-based shared writer

- The required 065 call-path map must account for the actual current writer,
  not merely FirstRun's preflight. `AtomicVaultWriter.replace` obtains its
  replacement directory and then calls path-based `FileManager`
  `createDirectory`, `fileExists`, `replaceItemAt`, and `moveItem` on the
  supplied target. Its `.absent` baseline therefore does not bind the
  metadata's parent or final leaf to the component identities admitted by a
  preceding FirstRun check; a rename/symlink race after that check can make the
  fresh receipt escape. This is neither a criticism of the shared writer's
  existing callers nor permission to modify or relabel it.
- For the fresh, one-time FirstRun receipt branch, do not call the shared
  `AtomicVaultWriter` (directly or via `writeAtomicJSON`) after a no-follow
  precheck. Publish from the already admitted `.epistemos` directory descriptor
  using a narrow FirstRun-owned, descriptor-relative primitive: exclusive
  no-follow creation of the literal `vault.json` leaf, bounded write and sync,
  descriptor identity/type/link-count verification, and parent-directory sync.
  Treat an exclusive-create collision as a concurrent winner only after a
  component-anchored no-follow reread; map every other publication error to the
  existing fail-closed publication error while preserving the created partial
  scaffold. Use the smallest Darwin/POSIX surface needed for this single
  absent-baseline receipt; do not introduce a general replacement framework,
  change `AtomicVaultWriter`, expose file descriptors in public API, or weaken
  the existing metadata byte/shape limits.
- The active 065 tests must make a post-admission adversarial replacement or
  symlink attack unable to cause an outside write, and the deterministic
  failure test must fire after a real scaffold component is created but before
  receipt publication. A static/source assertion that FirstRun's fresh
  publication path has no `AtomicVaultWriter`/path-replacement dependency may
  supplement those behavioral tests, but never substitute for them. Any
  failure hook must be private to this owner, reset with `defer` even on a
  thrown assertion, and cannot become a global mutable production escape hatch
  or make parallel test execution order-dependent.
- Reconcile the stale dormant-fixture bookkeeping honestly: preserve unrelated
  pre-existing dirty hunks, but identify the exact worker-authored lines that
  crossed the prior prompt-refresh barrier and either restore only those lines
  when they are no longer required or record why the changed production contract
  makes them a necessary, separately unexecuted compatibility update. Do not
  count that dormant suite as the active proof. Re-read and hash the complete
  live prompt before any source mutation, then retain the 065 ordering and
  checkpoint restrictions in full.

### `LR-LIVE-2026-07-16-067` — make descriptor-relative metadata admission nonblocking for every leaf type

- Review the new descriptor-oriented FirstRun draft before accepting its
  no-follow claim. A leaf helper that directly calls `openat(..., O_RDONLY |
  O_NOFOLLOW, ...)` and checks `fstat` only after it opens still has a
  fail-closed availability boundary: an attacker-controlled FIFO can block the
  bootstrap forever, while a device/socket/non-regular object may be opened
  before its type is rejected. `O_NOFOLLOW` rejects links; it does not establish
  regular-file type nor prevent a FIFO open from waiting.
- For literal `vault.json` reads and a collision winner reread, first inspect
  the leaf descriptor-relatively with no symlink following (`fstatat` with
  `AT_SYMLINK_NOFOLLOW`, or an equally strong Darwin primitive) and admit only
  a single-link regular file within the metadata byte bound. Then open with
  no-follow **and nonblocking** flags, immediately `fstat` it, and require the
  device/inode/type/link-count identity to match the pre-open snapshot before
  reading; retain the existing after-read identity/size validation. A
  replacement during this interval must fail closed, never block, read an
  attacker-controlled special object, or be treated as a concurrent metadata
  winner. Keep the exclusive fresh-create path narrow and retain its own
  post-create identity checks.
- Extend the active Keelstone FirstRun adversarial test to install a FIFO (and,
  where the supported test filesystem can do so without elevated privileges,
  at least one other non-regular leaf) at `.epistemos/vault.json`. Invoke the
  real bootstrap under a short bounded expectation; it must return the typed
  fail-closed error, create no scaffold after an existing invalid receipt is
  detected, and leave outside/fixture canaries unchanged. This is a behavior
  test, not a source-string substitute. Do not add a thread that may outlive
  the test, a timed polling loop, a generic filesystem framework, or a global
  bypass hook merely to test it.
- Re-read the complete live prompt and record its hash before this correction;
  treat all current no-follow results as partial until the root/metadata
  symlink, post-admission replacement, publication-failure, and special-leaf
  cases have real active-target evidence. Preserve the shared writer boundary,
  private reset-safe failure hook, legacy-byte opacity, partial-scaffold policy,
  and all 065/066 commit/bookmark/rebuild gates.

### `LR-LIVE-2026-07-16-068` — make the deterministic post-scaffold failure receipt real, isolated, and typed

- New active-target evidence supersedes the source-shape assumption about the
  private fresh-metadata publication hook. The named real
  `EpistemosAppStoreKeelstoneTests` FirstRun execution completed with one
  executed test and failed: a hook that throws
  `FirstRunBootstrap.BootstrapError.metadataPublicationFailed` was observed by
  the test as `.unsafeFilesystemObject`. The result is
  `/tmp/epistemos-codex-laner-067/Results/FirstRunNoFollowSpecialLeaves-final.xcresult`;
  it is a valid fail-first receipt, not an incomplete-host or FIFO-blocking
  result. Do not claim that the current `catch let error as BootstrapError`,
  `TaskLocal`, or outer sanitizer text proves correct runtime propagation.
- Before another broad FirstRun claim, map the exact thrown value and path from
  `withFreshMetadataPublicationHook` through `publishFreshMetadata`, bootstrap
  cleanup/defer behavior, and the outer catch/sanitizer. Establish whether the
  hook was reached, whether the value lost its concrete type, or an earlier
  descriptor admission failed; use a minimal private, reset-safe test seam or
  test-local fixture distinction only as needed to make that origin observable.
  Do not add production logging of vault paths/metadata, a global mutable
  witness, a public test API, a task/thread that outlives the test, or a second
  generic filesystem abstraction merely to diagnose the error.
- Split the current aggregate active FirstRun adversarial case into independently
  runnable named active tests at the existing behavior seam: one may retain the
  root/metadata-symlink and FIFO/directory-leaf rejection matrix, while the
  deterministic publication-failure test must start from its own disposable
  fixture and prove only its own ordering. The latter must execute a fresh
  absent-receipt bootstrap under the private hook, receive exactly
  `.metadataPublicationFailed`, retain `_inbox`, `daily`, `notes`, and
  `.epistemos`, leave no `vault.json`, preserve every outside/fixture canary,
  and prove a subsequent unhooked retry either publishes normally or returns a
  descriptor-anchored concurrent winner without outside mutation. Keep the
  post-admission symlink replacement test distinct enough that an
  `.unsafeFilesystemObject` result cannot mask the deterministic-failure path.
- Implement the smallest surgical correction demonstrated by that isolated
  fail-first test. Typed expected bootstrap failures must remain typed through
  the outer boundary; unexpected/unsafe operating-system failures must still
  fail closed. Do not weaken `sanitize` into a catch-all pass-through, treat a
  metadata race as a publication failure, delete the retained scaffold, relax
  descriptor checks, change the shared writer, or advance bookmark/lifecycle,
  commit, Lane B, model, or successor work.
- Re-read and hash the complete live prompt before the correction, record the
  isolated root-cause and exact changed boundary in the evidence/debt ledger,
  then run the two named active Keelstone tests separately under the existing
  resource/signing gates and inspect each result's nonzero identifier/count.
  Only a real pass for both the special-leaf/adversarial matrix and the
  deterministic typed-failure/retry matrix can replace the 067/068 partial
  receipts; then perform a scoped deep-hardening pass and keep all prior
  commit/rebuild gates in force.

### `LR-LIVE-2026-07-16-069` — make the isolated retry fixture actually unique and rerunnable

- Review of the just-split active retry test found its purported UUID fixture
  path was emitted as the literal text `(UUID().uuidString)` rather than Swift
  string interpolation. It can collide with a stale directory from a prior
  interrupted run and therefore cannot serve as isolated retry evidence. This
  is a test-fixture correctness defect, not a production behavior failure and
  not permission to delete unknown `/tmp` paths.
- Correct only the test's path construction so each invocation uses real unique
  interpolation, retain its owned-fixture `defer` cleanup, and preserve the
  `createDirectory(..., withIntermediateDirectories: false)` fail-fast
  precondition. Do not substitute a timestamp, a predictable fixed name, a
  broad `/tmp` cleanup, or a retry loop. If a prior literal fixture exists, do
  not remove it unless its ownership and exact creation by this worker are
  proven; otherwise choose the corrected unique fixture and record the stale
  artifact as non-evidence.
- Re-run parse/diff/static guards and then the two separately named active
  Keelstone tests required by 068. Each result must show its own nonzero named
  identifier/count; a combined run, a compile-only result, or a result reached
  through an old literal fixture does not satisfy the deterministic
  typed-failure/retry checkpoint. All FirstRun, commit, lifecycle, and
  successor gates remain unchanged.

### `LR-LIVE-2026-07-16-070` — preserve typed expected bootstrap failures at the outer fail-closed boundary

- The 069 special-leaf matrix is now a valid real active-target pass, but the
  separately named publication-failure/retry execution is a second valid
  fail-first receipt. In
  `/tmp/epistemos-codex-laner-067/Results/FirstRunPublicationFailureRetry-069.xcresult`,
  exactly one `firstRunMetadataPublicationFailureIsTypedRetryableAndCanRetry()`
  test executed and failed because the private in-publication scope again
  surfaced `.unsafeFilesystemObject` instead of `.metadataPublicationFailed`.
  Therefore neither the prior throwing-hook mapping nor the replacement
  task-local boolean seam proves typed propagation; do not call the typed
  publication path fixed, completed, or ready for lifecycle work.
- Diagnose and repair the actual `bootstrap` outer error classification before
  adding any third fault hook, global/test witness, public API, logging, or
  filesystem mechanism. The current production path must distinguish a
  `BootstrapError` emitted by `publishFreshMetadata` (including the direct
  post-scaffold test fault) from an unexpected thrown error: rethrow the former
  as the same concrete typed error at the outer bootstrap boundary and map only
  the latter fail closed to `.unsafeFilesystemObject`. A direct typed catch at
  that boundary, or an equally narrow type-preserving correction proven by the
  active test, is preferred over passing an erased existential through a helper
  that loses the type. Preserve the no-follow descriptor policy, partial
  scaffold, all metadata race distinctions, and fail-closed treatment of
  unexpected OS/decode errors; do not broadly pass through arbitrary errors or
  reclassify a race as publication failure.
- Keep the existing isolated named test and private dynamically reset scope;
  do not add a replacement mechanism merely to make the test green. Its next
  real run must prove exact `.metadataPublicationFailed`, retained scaffold,
  absent leaf, unchanged canaries, and a successful unhooked fresh retry (or a
  proven descriptor-anchored winner). Re-run the already-passing special-leaf
  matrix after the outer-boundary correction as a regression check, and record
  each named active result separately. Until both pass after this correction,
  all FirstRun claims remain partial and bookmark/lifecycle, Settings, Lane B,
  model, commit, and successor work remain blocked.

### `LR-LIVE-2026-07-16-071` — localize the remaining typed-failure red result before changing behavior again

- The 070 direct typed-catch correction is itself now a valid active fail-first
  result: the rebuilt, separately named
  `FirstRunPublicationFailureRetry-070.xcresult` again executed one test and
  again reported `.unsafeFilesystemObject`. Do not infer that the direct
  post-scaffold fault was reached, that `TaskLocal` propagated to the
  synchronous bootstrap call, or that a further catch rewrite is warranted.
  The special-leaf matrix pass remains valid but does not prove this path.
- Before another production behavior change, use the already-existing private
  pre-publication timing hook only as a **test-local reachability probe**: while
  the existing failure scope is active, let that hook set a bounded
  synchronization-safe in-memory flag owned by the individual test, return
  normally, and assert after the captured bootstrap error that the hook ran.
  The witness must be local to that test invocation, have no filesystem side
  effect, logging, public/internal production accessor, process-global mutable
  state, background task, polling, or persistence, and must be removed once
  the origin is classified. This is diagnostic evidence, not a substitute for
  the required exact error, scaffold, canary, and retry assertions.
- Use the resulting fork honestly. If the hook was not reached, map the earlier
  descriptor/scaffold failure from current source and repair only that real
  cause. If it was reached but the failure scope is not observed, repair the
  smallest private scope-propagation seam rather than adding a third hook. If
  both were reached yet a concrete `BootstrapError` is still erased, re-map the
  exact throwing/catch boundary with an active proof before changing it. Do not
  weaken the special-leaf policy, create a receipt to bypass the failure,
  broaden error pass-through, or claim FirstRun readiness. Re-run the isolated
  named test after the mapped correction, remove the temporary probe, then
  rerun the special-leaf regression before any hardening/lifecycle transition.

### `LR-LIVE-2026-07-16-072` — do not hide missing-root admission behind a precreated test vault

- The red isolated test was subsequently changed to pre-create its
  `failureVault` before invoking bootstrap. That is not an acceptable
  resolution: it can conceal an earlier error in the required final-root
  `mkdirat`/descriptor admission path, and the typed-failure contract requires
  a fresh absent-receipt bootstrap, not merely publication into a caller-created
  directory. No pass reached through the precreated-root fixture may replace
  the 070/071 fail-first receipts.
- Restore the typed publication-failure/retry test so its final vault root is
  absent immediately before the scoped bootstrap call. It must prove that the
  bootstrap itself created the root and partial scaffold before the injected
  post-scaffold publication fault; do not pre-create the root, receipt
  directory, scaffold folders, or a replacement success receipt. If the prior
  `.unsafeFilesystemObject` occurs before the timing hook, map the exact
  `admittedVault`/final-root `ensureDirectory`/identity verification failure
  from current source and repair that narrow production defect with a
  fail-first active proof. Do not change the test to avoid the branch.
- The existing root-symlink matrix proves rejection of an unsafe root alias;
  it does not prove ordinary safe creation of a missing root. Retain both
  properties in active coverage: an untrusted intermediate/final root must
  fail without outside mutation, while a missing direct child of an admitted
  parent must be created descriptor-relatively and then preserve typed
  post-scaffold failure/retry semantics. Re-run the special-leaf matrix after
  any root-admission production change and keep all lifecycle/commit/rebuild
  gates blocked until both named tests pass without a fixture workaround.

### `LR-LIVE-2026-07-16-073` — proven pre-publication missing-root failure: repair the admission path, not the fault seam

- The owned active result
  `/tmp/epistemos-codex-laner-067/Results/FirstRunPublicationProbe-072.xcresult`
  provides the required classification: one named test executed and failed its
  synchronization-safe local `reachabilityProbe.wasReached()` assertion. The
  pre-publication hook did **not** execute, so the failure is conclusively
  earlier than `publishFreshMetadata`, the boolean failure scope, and the outer
  typed-error boundary. The probe must not be retained after the root cause is
  fixed, and the result does not count as a publication test pass.
- Map the current missing-root path in order from `absolutePathComponents` and
  parent component admission through final `existingDirectory`/`mkdirat`/
  reopen, `AdmittedVault` identity verification, `existingMetadata`, and
  scaffold preflight. Add or refine the smallest active fail-first assertion
  that a direct missing final vault child under the owned fixture parent is
  created descriptor-relatively, remains the admitted inode, and reaches the
  pre-publication hook before the controlled failure. Diagnose from the real
  error site; do not reintroduce path-string creation, URL-resolution checks,
  pre-create the root, or move the failure hook earlier merely to satisfy the
  test.
- After the narrow root-admission repair, the single typed-failure/retry test
  must run with the root absent, prove the probe once only if still necessary,
  then remove the probe and rerun a clean final version that proves exact
  `.metadataPublicationFailed`, self-created root/partial scaffold, no receipt,
  canary preservation, and unhooked retry. Then rerun the special-leaf matrix
  against the repaired source. Do not make lifecycle, commit, V2, Settings,
  Lane B, or model progress on the basis of a precreated-root or diagnostic
  result.

### `LR-LIVE-2026-07-16-074` — prove the post-admission replacement hook, not merely its expected error

- Reassess the prior special-leaf matrix receipt in light of the 073 probe. Its
  post-admission replacement subcase asserted only the final
  `.unsafeFilesystemObject` and untouched outside canary; it did not assert
  that its private pre-publication replacement hook ran. The same earlier
  missing-root admission error can satisfy those assertions without exercising
  the symlink replacement boundary. Thus the FIFO/directory/root-symlink
  portions remain valid where independently reached, but the post-admission
  replacement claim is partial until hook reachability is proven after the
  root repair.
- In the final active special-leaf/replacement test, add a synchronization-safe
  **test-local** in-memory reachability assertion for the existing replacement
  hook, alongside the typed unsafe error and outside-canary/no-receipt checks.
  This is permanent behavior coverage for the adversarial replacement ordering,
  not the temporary 071/073 diagnostic probe; it must be local to the test,
  introduce no production API/state, filesystem marker, logging, background
  task, or polling. The result must demonstrate that the root was admitted,
  scaffold/metadata directory were actually reached, the hook replaced the
  directory, descriptor identity verification rejected the replacement, and
  no external `vault.json` was created.
- Do not retain a broad reusable global probe helper. Once the missing-root
  issue is fixed, remove the temporary typed-failure diagnostic type/state and
  retain only the minimal local replacement ordering proof. Re-run all named
  FirstRun tests from clean, absent-root fixtures; revise the ledger so the
  earlier special-matrix pass is not overstated. No FirstRun-ready, lifecycle,
  commit, or successor transition may rely on its previous partial replacement
  coverage.

### `LR-LIVE-2026-07-16-075` — isolate and repair the post-fault unhooked retry only

- The owned active result
  `/tmp/epistemos-codex-laner-067/Results/FirstRunPublicationProbe-074b.xcresult`
  has build status `succeeded`, `errorCount: 0`, and exactly one executed
  `firstRunMetadataPublicationFailureIsTypedRetryableAndCanRetry()` test. Its
  sole failure is the **unhooked retry** at the test's `bootstrap(at:
  failureVault)` call, which throws `.unsafeFilesystemObject`. Treat this as a
  valid red behavior receipt, not a host/compile failure and not evidence that
  the fault injection itself is wrong.
- The preceding assertions in that same serialized test established the narrow
  positive boundary: the final root was absent on entry beneath physical
  `/private/tmp`; the first bootstrap created/admitted it and reached the
  private pre-publication hook; the scoped direct fault emerged exactly as
  `.metadataPublicationFailed`; `_inbox`, `daily`, `notes`, and `.epistemos`
  remained; no receipt leaf was published; and the external canary was
  unchanged. The temporary 071/073 typed-failure reachability probe has thereby
  completed its classification purpose. Remove its type/state/assertion before
  the final clean retry proof; keep 074's independent, permanent local
  replacement-ordering proof.
- Before any production edit, map the retry-only path from a new
  `bootstrap(at:)` through admitted-root identity, `existingMetadata`,
  scaffold preflight/re-open, existing `.epistemos` admission, unhooked fresh
  publication, post-publication verification, and descriptor-anchored reread.
  Inspect the actual descriptor/errno and state transition using bounded
  read-only or test-local evidence if source mapping alone cannot classify it.
  Do not add product logging, a public diagnostic API, global mutable state,
  background worker, retry loop, pre-created root/receipt, path-string fallback,
  or a broad error reclassification merely to make the retry green.
- Repair only the demonstrated retry-path defect, preserving no-follow
  component admission, file identity/link/byte limits, retained partial
  scaffolding, concrete typed errors, and fail-closed treatment of unexpected
  errors. Then run a clean named test with no temporary typed-failure probe to
  prove: absent final root, typed controlled first failure, retained scaffold,
  no receipt/outside mutation, and an unhooked successful retry with a valid
  descriptor-read receipt. Re-run the separately named special-leaf/replacement
  matrix afterward and inspect exact nonzero identities/counts. Until both
  active proofs pass, FirstRun hardening, lifecycle/bookmark work, commits,
  Lane B, model work, serial integration, and the successor rebuild remain
  blocked.

### `LR-LIVE-2026-07-16-076` — retry receipt is absent; locate the exact fail-closed operation

- The owned one-test classification result
  `/tmp/epistemos-codex-laner-067/Results/FirstRunPublicationRetryClassification-074c.xcresult`
  confirms the retry diagnosis, with a successful build action and `errorCount:
  0`: `retryFailure` is `.unsafeFilesystemObject`, the expected
  `.epistemos/vault.json` leaf is absent, and no retry receipt exists. The
  earlier first-attempt assertions in the same test remained satisfied. The
  result does **not** identify the exact descriptor operation; do not guess that
  a publication write, `fsync`, metadata decoder, or test hook is responsible.
- Map the retry from source and, only if necessary, use the smallest temporary
  test-local observation to distinguish the existing-root admission,
  preflight/scaffold re-open, `.epistemos` descriptor identity verification,
  fresh-leaf exclusive creation, bounded write/sync, post-publication verify,
  and readback stages. A temporary observation must be synchronization-safe,
  private to this named test, nonpersistent, unlogged, and removed immediately
  after it identifies the operation. Inspect the exact POSIX failure/descriptor
  state without converting it into product-visible diagnostic behavior.
- In particular, preserve the distinction between an expected
  `metadataPublicationFailed` from the receipt-creation/write/sync contract and
  an actual no-follow/identity admission failure. Do not relabel one as the
  other, suppress the failure, create an empty/synthetic receipt, add a retry
  policy, or alter failure cleanup merely because `vault.json` remains absent.
  The next source change, if evidence warrants one, must be the smallest repair
  of the identified operation and retain all first-attempt, symlink, FIFO,
  directory-leaf, outside-canary, and replacement-ordering guarantees.

### `LR-LIVE-2026-07-16-077` — retry fails before publication; inspect the retained scaffold path

- The owned result
  `/tmp/epistemos-codex-laner-067/Results/FirstRunRetryPrepublicationProbe-076.xcresult`
  is a valid one-test red receipt with successful build action and `errorCount:
  0`. The retry-local pre-publication probe is **false**, while the retry still
  produces `.unsafeFilesystemObject`, no `vault.json`, and no receipt. It
  therefore conclusively fails before `publishFreshMetadata` invokes its hook;
  encoded metadata, exclusive leaf creation, write/sync, post-publication
  verification, and descriptor reread are not implicated by this receipt.
- Constrain the remaining source map to exactly: re-admission of the existing
  final root in `admittedVault`; `existingMetadata` (root identity,
  `.epistemos` admission, absent-leaf inspection); `preflightScaffold`; each
  descriptor-relative existing scaffold re-open; and reopening/ensuring the
  retained `.epistemos` directory. The first fault's retained root/scaffold
  assertions remain evidence of path state, but do not prove that each retry
  descriptor operation succeeds.
- Do not add a new production hook, logger, public API, global state, or
  generic diagnostic framework. First exhaust a bounded test-only behavioral
  split using existing public/read-only behavior (for example the existing
  `isFresh` boundary) and source-level errno mapping; if still ambiguous, use
  an out-of-process, read-only debugger/syscall observation that preserves the
  exact test fixture and reports only the failing descriptor operation/errno.
  Remove the current retry-local probe once this classification is complete.
- Any production correction must repair only that observed retained-scaffold
  admission/preflight operation. It must not resolve symlinks, recreate/erase
  the scaffold, skip identity verification, convert unsafe objects into absent
  state, pass an untyped error through, or unblock lifecycle, Lane B, models,
  commits, integration, or the successor rebuild before clean retry plus
  special-leaf/replacement proof.

### `LR-LIVE-2026-07-16-078` — freshness fails; distinguish root re-admission from metadata inspection

- The owned result
  `/tmp/epistemos-codex-laner-067/Results/FirstRunRetryFreshnessSplit-077.xcresult`
  is another valid one-test red receipt with a successful build action and
  `errorCount: 0`. After the correct controlled first failure and retained
  scaffold assertions, public `FirstRunBootstrap.isFresh(at: failureVault)`
  is `false`; the retry remains `.unsafeFilesystemObject` with no receipt.
  This excludes scaffold preflight/re-open and retained `.epistemos`
  `ensureDirectory` as the first failing retry step. The remaining boundary is
  exactly existing-final-root re-admission in `admittedVault` or
  `existingMetadata` (root identity, `.epistemos` admission, or absent literal
  `vault.json` inspection).
- Remove the temporary freshness assertion after this classification. Before a
  production edit, use a disposable exact-fixture, out-of-process **read-only**
  descriptor/errno trace (or an equivalently bounded debugger observation) to
  walk `/` → admitted parent components → existing final root, verify the
  parent/root identities, open retained `.epistemos` with the same no-follow
  flags, and inspect literal absent `vault.json` with the same `fstatat` flags.
  Compare each operation's return/errno to the production helper path. This is
  diagnostic evidence only: no production source/test seam, public surface,
  log, persistent marker, filesystem mutation, symlink resolution, or retry
  workaround is authorized.
- If every external descriptor operation succeeds, map the exact Swift
  lifetime/ownership boundary (including descriptor reassignment/deinit and
  identity comparison) before changing source. If one fails, repair only that
  demonstrated source operation while retaining fail-closed behavior for all
  other error codes. Do not treat the existence of a FileManager-visible
  directory as proof that descriptor admission is valid, and do not infer a
  safe absence from an unclassified error.

### `LR-LIVE-2026-07-16-079` — descriptor primitives pass; audit Swift descriptor ownership before repair

- The bounded disposable descriptor trace has passed the corresponding
  no-follow root walk, parent/root identity comparison, retained `.epistemos`
  identity comparison, and literal absent-leaf `fstatat(...,
  AT_SYMLINK_NOFOLLOW)` with `errno == ENOENT`. It is a useful syscall mapping
  receipt, but not a substitute for the actual Xcode behavioral result. It
  rules out changing path policy, relaxing no-follow flags, or treating an
  absent receipt as an unsafe object on the basis of conjecture.
- Remove the temporary test pause and `isFresh` split now that they have done
  their classification work; retain the clean controlled-failure/retry test
  contract and 074's permanent replacement-ordering proof. Before any source
  edit, audit the actual Swift ownership/lifetime path: descriptor
  reassignment/deinitialization in root admission and component walks; tuple or
  temporary descriptor lifetimes; `AdmittedVault` parent/root retention;
  observed-versus-expected descriptor identity lifetimes; and `FileHandle`
  descriptor ownership in metadata inspection. Map every close and identity
  check against the one-test receipt.
- Do not add `withExtendedLifetime`, retain descriptors globally, suppress a
  close, alter error types, or restructure the transaction simply because a
  lifetime theory sounds plausible. A production change requires an identified
  invalid ownership/close/identity behavior with a smallest repair and an
  active test that fails before and passes after it. If the audit finds no such
  behavior, record that result and use a different bounded actual-host
  observation rather than guessing.

### `LR-LIVE-2026-07-16-080` — complete the errno-classification audit after the retry proof

- The narrowed retry repair may capture `errno` inside the affected `openat` and
  `fstatat` closures, then must first be proven by the clean active retry test.
  Do not call the repair or FirstRun scope complete on parse/static evidence.
- After that proof, perform one bounded same-helper audit for every remaining
  branch whose semantic outcome depends on `errno` after a C syscall inside a
  Swift `withCString` closure—currently the `mkdirat` `EEXIST` collision path
  and fresh-leaf `openat` `EEXIST` collision path. If a branch reads `errno`
  after the closure, preserve it in the closure result using the same narrow
  technique, retain the exact existing typed outcomes, reparse/diff-inspect,
  and rerun the named tests. Do not alter operations whose error class is not
  inspected, change no-follow flags/modes/identity policy, or turn this into a
  filesystem abstraction rewrite.
- The purpose is to remove the demonstrated Swift/POSIX error-lifetime class
  consistently within this single descriptor helper, not to preemptively modify
  unrelated filesystem code. Existing symlink/FIFO/directory-leaf/replacement
  and publication-failure/retry behavior must remain active proof gates.

### `LR-LIVE-2026-07-16-081` — retain the separately evidenced immediate-errno repair for active proof

- Clarification of 079: its retraction rule applies to speculative
  descriptor-ownership/lifetime repairs. It does **not** require a premature
  close to justify preserving a separate, narrow POSIX error-classification
  correction. The observed retry failure is exactly an absent-leaf path whose
  behavior depends on distinguishing `ENOENT`; the pre-repair helper read
  `errno` only after returning from a Swift `withCString` closure. The
  descriptor trace confirms the intended leaf result is `ENOENT`, and the
  source audit confirms no competing descriptor-lifetime defect. This is a
  sufficiently identified error-lifetime boundary to capture the syscall
  result and `errno` together **inside** the closure.
- Restore/retain only that immediate-errno capture for
  `existingDirectory` and `openRegularFile`, with the already removed temporary
  pause/freshness diagnostic kept removed. Run the clean named retry test next.
  If that test passes, it is the required causal behavior proof; if it fails or
  changes another typed outcome, retract the capture and return to actual-host
  observation. Do not merge this errno correction with any descriptor ownership
  change, policy relaxation, transaction rewrite, or test workaround.
- After a clean retry proof, apply 080's tightly scoped audit to the two
  remaining `errno`-classified collision paths, then rerun both named FirstRun
  tests. The lane remains blocked on those active receipts and later hardening;
  this clarification authorizes no lifecycle, Lane B, model, commit,
  integration, or rebuild step.

### `LR-LIVE-2026-07-16-082` — stop repeated red host runs; return to the single repair/proof loop

- The attempted high-iteration actual-host observation is not an acceptance
  receipt: it repeated the same known red retry assertion and did not yield a
  breakpoint/errno observation. Preserve the artifact only as a noisy failed
  diagnostic record; do not count its repetitions as coverage, reliability, or
  progress.
- Do not run further multi-iteration, soak, polling, or repeated-red test
  commands for this issue. They add verification noise and resource cost without
  narrowing the fault. The valid evidence remains the individually named red
  retry result, the bounded descriptor trace, the source audit, and the clean
  temporary-diagnostic cleanup.
- Apply 081 now: retain the two immediate-errno captures, run **one** clean
  named retry test, inspect its exact identity/count/result, then follow 080
  only if it passes. If that single repaired execution is red, record its
  distinct observation and reassess; do not retry it in bulk. No cleanup/reset
  of unrelated artifacts, no unowned-process termination, and no lane/scope
  expansion is authorized.

### `LR-LIVE-2026-07-16-083` — errno experiment disproven; authorize one private stage marker

- The clean, individually named repaired result
  `/tmp/epistemos-codex-laner-067/Results/FirstRunPublicationFailureRetry-081.xcresult`
  has a successful build action and one executed test, but remains red with the
  same `.unsafeFilesystemObject`, absent receipt leaf, and nil retry receipt.
  Per 081, retract the immediate-errno capture hunk and do not apply 080's
  adjacent-path audit. The source/static POSIX theory is disproven by this
  active behavior result; do not retain it as “hardening.”
- The existing external and actual-host observations have not identified which
  pre-publication helper fails. Therefore, and only for this diagnosis,
  authorize one **private, dynamically scoped TaskLocal diagnostic callback**
  inside `FirstRunBootstrap`, available only to the `@testable` active test.
  It may report a small closed enum of completed bootstrap checkpoints (after
  admitted root, existing-metadata inspection, scaffold preflight, scaffold
  ensure, and metadata-directory admission). Its default is nil; it has no
  public API, filesystem effect, logging, persistence, task/thread, global
  mutable state, retry policy, or behavior branch. The test owns a local
  lock-protected latest-checkpoint probe and asserts the highest completed stage
  after the captured retry error.
- Do not add a callback inside every syscall or use it to make a test pass. Its
  sole purpose is to reduce the real failure to one adjacent source operation.
  Remove the TaskLocal, enum, helper, callback calls, and local probe immediately
  after the next nonzero named result records the stage; then repair only the
  demonstrated operation and rerun clean retry plus special-leaf proof. All
  FirstRun/lifecycle/Lane B/model/commit/integration/rebuild gates remain
  blocked.

### `LR-LIVE-2026-07-16-084` — real host identifies the failing syscall branch; inspect its errno once

- The actual-host LLDB observation resolved the production source and recorded
  `existingDirectory` at its failure branch 13 times and the
  `openRegularFile` `fstatat`-failure branch exactly once during the named
  retry. This identifies the retry failure as the retained metadata
  directory's literal missing-leaf inspection, not root identity, scaffold,
  publication, or a descriptor lifetime theory. The prior immediate-errno
  experiment remained behaviorally red and stays retracted.
- Supersede 083's proposed TaskLocal stage-marker implementation: do **not** add
  it, because LLDB has already narrowed the operation. Run at most one further
  actual-host debugger-only observation of the same named test, stopping at
  that resolved `fstatat` failure branch *without auto-continue*, and record
  the syscall result plus the raw errno before detaching/ending the diagnostic
  run. It is an incomplete diagnostic run, not a test receipt; no source/test
  change or fixture workaround is allowed for it.
- Then repair only the demonstrated errno/type/path handling of that single
  missing-leaf operation, preserving safe `ENOENT` absence and fail-closed
  behavior for every other result. Rerun one clean named retry test with no
  debugger/test marker. If the observed errno is `ENOENT`, reconcile why the
  Swift helper does not take its absence branch before changing semantics; if
  it is another errno, preserve its fail-closed classification unless exact
  platform evidence proves a safe mapping. No bulk retry, new test hook, or
  expansion beyond FirstRun is authorized.

### `LR-LIVE-2026-07-16-085` — reject the redundant checkpoint probe; obtain the resolved branch errno

- Do **not** retain or run the just-proposed `BootstrapCheckpoint` TaskLocal
  enum/helper/callback/test probe. The real-host breakpoint already establishes
  that root admission completed and the actual retry enters the
  `openRegularFile` `fstatat` failure branch once; an `.admittedRoot` assertion
  would merely repeat that information without revealing the raw error. Remove
  all of that unexecuted diagnostic code surgically before the next build/test.
- Continue from 084 with the existing resolved actual-host breakpoint only.
  In one debugger-only invocation, stop after the `fstatat` call and before its
  branch is evaluated; inspect the operation result and `errno` using the frame
  or expression evaluator, then detach/end the incomplete diagnostic run. Do
  not auto-continue that breakpoint, add a new source hook, pause/sleep,
  repeat/soak tests, or turn the debugger observation into a behavioral pass.
- The next source edit must follow the raw errno, not merely the fact that an
  absent-leaf branch is entered. Reparse/diff-inspect after removing the probe,
  then make only the demonstrated handling repair and prove it with one clean
  named retry test. All normal gates remain blocked.

### `LR-LIVE-2026-07-16-086` — first fstat error was expected; inspect the retry's second hit exactly once

- The first halted real-host `fstatat` observation recorded
  `component == "vault.json"`, `inspected == -1`, and raw errno `2` (`ENOENT`).
  Its backtrace is the controlled **first** bootstrap's post-scaffold
  `readMetadata` check before the injected publication fault, where absence is
  expected. It validates that the helper can take the normal absent-leaf route;
  it is not the retry failure and must not drive a repair.
- The process was ended without continuing to the retry's corresponding check,
  so one replacement debugger-only observation is authorized. Keep the same
  single named test and no source/test mutation. At the resolved breakpoint,
  inspect/record the first `ENOENT`, issue `continue`, then halt at the **second**
  hit, record `component`, syscall result, raw errno, and a short backtrace,
  then detach/end the incomplete diagnostic run. Do not run a third hit,
  repeated iterations, source marker, sleep, or test workaround.
- Repair only after comparing the two concrete observations. If the second hit
  is not `ENOENT`, preserve fail-closed treatment unless the exact operation
  establishes a safe platform-specific mapping. If it is `ENOENT`, inspect the
  immediate Swift control/lifetime difference between the first and second
  calls before changing any classification. Then use one clean named test as
  the behavior proof.

### `LR-LIVE-2026-07-16-087` — retry never reaches fstatat; inspect root verification failure branches

- The two-hit attempt completed the controlled first `fstatat` check with
  `inspected == -1` and `errno == ENOENT`, then the test process completed
  without a second `openRegularFile` breakpoint hit. The retry therefore fails
  **before** the missing-leaf inspection; 084's previous inference that the
  leaf operation itself failed is retracted. Do not alter `openRegularFile`,
  missing-leaf policy, errno capture, or publication code on this basis.
- One final debugger-only, single-test observation is authorized with no source
  or test mutation. Set resolved stops only at (a) `existingDirectory`'s
  non-`ENOENT` fail-closed throw and (b) `verifyDirectory`'s guard/identity
  fail-closed throw. Continue through the expected first-bootstrap path; when
  the retry stops at either branch, record the component, relevant descriptor
  values/identity comparison where available, raw errno if a syscall failed,
  and a short backtrace, then end the diagnostic. Do not use hit-count-only
  inference, add markers, or run any repeated test.
- The resulting branch selects the repair: an explicit non-`ENOENT` syscall
  error remains fail closed absent exact contrary evidence; an unexpected
  descriptor identity mismatch requires a minimal descriptor ownership or
  verification repair proved by the clean named retry. Nothing else may change
  before that proof.

### `LR-LIVE-2026-07-16-088` — established cause: standardized path collapses the physical parent to `/tmp`

- The actual-host root-branch stop supplies the missing cause. The retry
  `vaultURL` still displays the physical `/private/tmp/...` fixture, but
  `absolutePathComponents` passes `components == ["tmp", fixture, vault]` to
  descriptor admission. At the `tmp` component, `openat` returns `-1` with raw
  errno `ENOTDIR` (20): it is the root-level `/tmp` symlink, correctly rejected
  by `O_DIRECTORY | O_NOFOLLOW`. This occurs before metadata inspection or
  publication. The `private` component was lost by `standardizedFileURL`, not
  by a descriptor close or identity mismatch.
- Make the smallest demonstrated source repair in `absolutePathComponents`:
  preserve the file URL's **lexical absolute path** for URL/substring component
  extraction instead of calling `standardizedFileURL`. Keep the file-URL,
  absolute-path, non-root, and safe-component validation; reject `.` and `..`
  rather than resolving them; retain every descriptor-relative no-follow open
  and all identity checks. Do not use `resolvingSymlinksInPath`, `realpath`,
  string containment, a `/tmp` exception, or any path fallback.
- This is a narrowly demonstrated alias-normalization repair. Reparse/diff
  inspect it, then run exactly one clean named publication-failure/retry test
  from an absent physical `/private/tmp` child. It must prove controlled first
  failure, retained scaffold/no receipt/canary, and successful unhooked retry.
  Then perform 080's remaining errno audit only if the clean retry passes, and
  rerun the named special-leaf/replacement matrix. The debugger artifact is
  diagnostic only; it does not itself advance any gate.

### `LR-LIVE-2026-07-16-089` — lexical-path repair is behaviorally proven; proceed only to the already-bounded errno audit

- The required clean artifact
  `FirstRunPublicationFailureRetry-088.xcresult` is complete and reports
  exactly one executed test, zero failures, and `Passed` for
  `FreeV1RemovalBoundaryTests/firstRunMetadataPublicationFailureIsTypedRetryableAndCanRetry()`.
  That test proves the controlled publication failure remains typed, retains
  its scaffold, preserves the no-receipt/outside-canary invariants, and then
  succeeds unhooked from the physical `/private/tmp` fixture. This validates
  the lexical-component repair; it does not make a broader Lane R, integration,
  checkpoint-commit, embedding, or rebuild claim.
- The sole next source-inspection target remains 080's two `errno` collision
  branches within this descriptor helper. Retain its narrow scope and evidence
  bar: identify the exact syscall/result and closure lifetime before deciding
  whether errno capture needs a surgical correction; do not widen behavior,
  reduce no-follow/identity checks, add special filesystem paths, or treat an
  existing successful retry as a substitute for the separate special-leaf and
  replacement-hook matrix proof. Reparse and inspect the diff after any change,
  then run that separately named matrix once. No later phase may start yet.

### `LR-LIVE-2026-07-16-090` — both FirstRun acceptance receipts now pass; enter the required scoped hardening pass, not the next product phase

- The two closure-local collision captures are limited to `mkdirat` creation
  and exclusive fresh-receipt `openat` creation; focused production/test parsing
  and `git diff --check` pass. The required fresh result artifact
  `FirstRunSpecialLeafMatrix-089.xcresult` reports one executed test, zero
  failures, and `Passed` for
  `FreeV1RemovalBoundaryTests/firstRunMetadataAdmissionRejectsUnsafeLeavesAndRetainsRetryableScaffolds()`.
  Together with the clean 088 typed-failure/retry receipt, this replaces the
  earlier partial FirstRun proof receipts. It is evidence for this bounded
  FirstRun transaction only, not a claim that Lane R, the Free target, serial
  integration, Settings, embeddings, or the future rebuild is ready.
- Perform the already-required **scoped FirstRun deep-hardening pass** before
  bookmark/lifecycle work. Re-read the helper, all call sites, and both active
  tests; semantically search for stale canonicalization/resolution APIs,
  path-string admission, no-follow gaps, publication races, receipt reads,
  descriptor/errno boundary use, stale model-pin behavior, missing cleanup, and
  conflicting assertions. Classify each finding as proven, fixed-and-retested,
  bounded later debt, or contradiction; make only a demonstrated surgical fix
  with an appropriately named proof. Do not invent more probes, repeat tests,
  relabel existing passes, cross into Lane B/Settings, or start lifecycle/
  bookmark/model/rebuild work merely because this matrix passed. Record the
  results and remaining debt in the Lane R ledger before selecting the next
  owned slice.

### `LR-LIVE-2026-07-16-091` — reconcile all remaining FirstRun errno boundaries; never restore the retired path-based writer

- The scoped audit established that `existingDirectory` still reads `errno`
  after its `openat` `withCString` closure and `openRegularFile` still reads it
  after its `fstatat` closure. Earlier retries disproved closure-local capture
  as the *cause* of the `/tmp` alias failure; they did not establish that a
  thread-local error value may safely cross a Swift closure boundary. For this
  defensive consistency pass, supersede any narrower historical wording that
  would leave those two branches untreated: capture each syscall result and
  `errno` together inside its existing closure, preserving precisely the
  existing `ENOENT`-is-absence rule and every other fail-closed/error mapping.
  Do not change flags, descriptor identity policy, file admission, publication
  ordering, public error types, or add another diagnostic seam.
- The descriptor-exclusive FirstRun publication path is the deliberately
  selected design. `AtomicVaultWriter`/path-based publication must not be
  restored to satisfy an old static test. First determine the stale assertion's
  current target membership and executable reachability. If it is active, make
  only the smallest behavior-accurate test-contract correction after source
  evidence; if it is inactive, record it as stale test debt for its owning
  target rather than mutating it opportunistically. Either way, do not use a
  static source assertion as a reason to weaken descriptor-relative security.
- Re-read the four closure-local branches and the focused callers after the
  surgical edit, inspect the hunk and `git diff --check`, then run exactly one
  fresh named retry proof because the source has changed; prior 088/089 passes
  are not proof for the new hunk. Record the exact target, selected test, and
  result artifact. Resume the scoped hardening loop only after that receipt;
  no lifecycle, Settings, Lane B, model, commit, integration, or rebuild work
  is authorized.

### `LR-LIVE-2026-07-16-092` — FirstRun’s bounded transaction is now evidence-complete; begin only lifecycle-slice intake

- The fresh `FirstRunPublicationFailureRetry-091.xcresult` is a clean result:
  one selected
  `firstRunMetadataPublicationFailureIsTypedRetryableAndCanRetry()` test,
  one pass, zero failures. The two newly corrected `openat`/`fstatat` branches
  join the previously corrected `mkdirat`/exclusive receipt-create branches in
  returning syscall result and `errno` from within their C-string closures.
  The typed `ENOENT` absence/fail-closed policy, descriptor-relative identity
  defenses, lexical-path admission, special-leaf/replacement receipt, and
  retained-scaffold retry receipts are all current evidence. This closes the
  bounded FirstRun hardening transaction—not Lane R, full Free artifact truth,
  lifecycle safety, or the successor rebuild. Retain the inactive stale
  `AtomicVaultWriter` assertion as owned membership/reconciliation debt; never
  reintroduce path-based publication for it.
- The next permitted Lane R slice is **read-first lifecycle/admission intake**
  for the existing `VaultConnectionActions`, `VaultSync`/watching, onboarding
  default-vault path, bookmark restore/recovery, and their active Free test
  target. Before any source edit or build, create a new intent/debt checkpoint;
  map every production entry point, state/default/bookmark/security-scope
  mutation, current-vault teardown/rollback boundary, task/epoch boundary, and
  test-target membership. Reconcile the quarantined historical 048–053 draft
  directives against the present source rather than trusting their names or
  layering wrappers. Select the smallest fail-first lifecycle contradiction only
  after that map is recorded.
- This is intake, not permission to modify lifecycle behavior yet. Do not touch
  Settings or Lane B, select/download/wire an embedding model, alter FirstRun
  publication, run a broad build/app/artifact scan, commit, or start the
  rebuild. Keep current-vault preservation, scope-balance, bookmark integrity,
  cancellation/late-task behavior, readiness truth, and redacted diagnostics as
  explicit acceptance targets for the next bounded mutation.

### `LR-LIVE-2026-07-16-093` — current Free-V1 product correction: remove June; preserve only Kokoro read-aloud

- A newer direct owner correction supersedes every older prompt/ledger excerpt
  that says, implies, or could be read as “keep June,” including the historical
  phrase that paired June with Kokoro. The current Free-V1 requirement is:
  **remove June completely**—do not preserve it, hide it behind a flag, defer
  its removal, retain a dormant provider/route/setting/asset, or use an old
  ledger quotation as authority to do so. The only named exception in this
  product decision is the local **Kokoro read-aloud** capability; it remains in
  scope subject to the existing Free boundary and later app-wide audit.
- This clarification changes product intent, not the immediate lifecycle intake
  boundary. On the next checkpoint/re-read, correct the lifecycle ledger’s
  stale intent quotation and continue mapping; do not pivot into June removal,
  Kokoro changes, Settings, Lane B, model/embedding selection, FirstRun work,
  commit, or rebuild before the live contract explicitly opens the appropriate
  bounded slice. Later removal/integration/rebuild work must treat this newer
  direct instruction as the controlling source of truth.

### `LR-LIVE-2026-07-16-094` — prove candidate-B failure cannot evict a working vault A, before any lifecycle repair

- The completed 092 source map establishes the first actionable lifecycle
  contradiction: `switchToVaultAsync` may tear down current vault A before the
  candidate B watcher/mount is known to have installed a usable session; the
  later `beginWatching` success only means that asynchronous import was
  launched. This violates the active acceptance targets for current-vault
  preservation and readiness truth. Treat the map—not historical 048–053 draft
  type names—as the source of truth.
- The sole currently permitted next step is **read-only fail-first seam and
  rollback design**. Map the exact active MAS test, existing controllable
  candidate-B post-teardown failure boundary, lifecycle epoch/task behavior,
  B-scope release owner, and all A authority to snapshot: mounted URL/watcher,
  persisted bookmark/path/defaults, crash-recovery state, search/index owner,
  and active security scope. Re-read the full live prompt, including 093, and
  correct the ledger’s stale June quotation before recording that design.
- Do not write the test, add a test override, alter `switchToVaultAsync`,
  `beginWatching`, persistence, scope handling, readiness visibility, or run a
  build yet. If no existing precise test seam can model a post-teardown B mount
  failure without a general-purpose production fault hook, record that fact and
  wait for the next live directive; do not manufacture an arbitrary failure
  mechanism. A later narrowly authorized failing test must prove that a B
  failure leaves A authoritative and usable, releases only B’s acquired scope,
  preserves A’s persisted selection and public state, and suppresses every
  stale B task/callback. It must not use an early-import race as a stand-in for
  mount failure. All other lifecycle findings remain recorded debt until this
  one rollback boundary is evidenced.

### `LR-LIVE-2026-07-16-095` — first executable lifecycle repair: reject a vanished/unreadable B before A teardown

- Addition 094 has produced a decisive source fact: the current switch path has
  no honest, controllable *post-teardown* B mount-failure result—after A is
  cleared, watcher start reports success once it launches asynchronous import.
  Do not add a general fault hook or pretend an import failure is a mount
  failure. Instead, authorize the smallest real preflight boundary exposed by
  current source: when switching from active A and this service has just
  acquired B’s security scope, validate that B is still an accessible **vault
  directory** before any A teardown, disconnected-state clear, bookmark/path
  write, crash-recorder change, lifecycle epoch change, search/index replacement,
  or import task creation.
- First add exactly one active MAS fail-first regression using only existing
  scope-operation/test infrastructure and a real nonexistent or unreadable B
  path—not a new generic readability/fault override and not an import race. It
  must establish A, arrange successful service-owned B scope acquisition, call
  the real async switch, and initially fail because current code evicts A. Its
  acceptance assertions are: a false switch result; A remains the mounted,
  watching public vault with its preexisting bookmark/path/default state and
  search/index owner; no B import/task becomes authoritative; A’s scope is not
  stopped; and the acquired B scope is stopped exactly once through the
  injectable `securityScopeStopOperation` (never a direct URL stop). Name and
  record the red receipt before implementation.
- Then make only the surgical preflight/release correction in the interactive,
  service-owned-scope route of `switchToVaultAsync`. The preflight must require
  existence, directory identity, and readable access after B scope acquisition;
  on failure it must release B exactly once while leaving A state intact. Do not
  change the ownership semantics of `scopeAlreadyAcquired`, restore/recovery,
  `beginWatching`, initial-import readiness, bookmark commit ordering, or the
  global scope model in this slice. Re-read the hunk/callers, parse/diff-check,
  then rerun only the named regression for a new green receipt. Record the
  remaining post-preflight/whole-transaction rollback and readiness defects as
  debt before any broader lifecycle work.

### `LR-LIVE-2026-07-16-096` — lifecycle continuation: map the next real authority-loss boundary before editing again

- Receipt 095 is now a bounded completed repair: its named active MAS regression
  was red before the correction and green after it. It proves only that a
  service-owned candidate B which is absent/not a readable directory is rejected
  before working A is touched. It does **not** establish whole-transaction
  rollback, B mount/readiness truth, restore safety, borrowed-scope semantics,
  or stale-task suppression. Do not overstate it.
- The sole next action is a **read-only lifecycle continuation map**. Re-read
  the full coordinator prompt and current source, then trace all remaining
  interactive switch outcomes from the first A/B authority change through
  `stopWatchingAsync`, `beginWatching`, epoch/task assignment, persistence,
  crash-recovery publication, search/index replacement, scope release, and
  observer/UI visibility. Separately map the inactive initial-connect route,
  `scopeAlreadyAcquired` callers, bookmark restore/recovery, onboarding, and
  cancellation/late-task behavior; identify which are direct shared mechanisms
  versus distinct later routes. Read the active MAS test infrastructure and
  identify whether an honest existing post-teardown/mount-failure result is now
  controllable without a generic production fault seam.
- Record an updated intent/authority/debt checkpoint: exact owner wording;
  A/B state and ownership table; every mutation before and after the 095 guard;
  existing failure returns; each scope owner/release; task/epoch and readiness
  signals; persistence/public-state snapshots; exact test seams; and a ranked
  next contradiction. Classify each concern as proven, disproven, direct next
  candidate, or bounded later debt. If the current source still has no honest
  post-teardown failure return, say so precisely and propose a narrowly
  testable production contract only as design—do not create a fault hook,
  test, build, or source change.
- Hard boundaries remain: no Settings or Lane B; no June/Kokoro work; no
  embedding/model selection or tuning; no FirstRun change; no broad build,
  commit, integration, artifact sweep, or rebuild work. Do not modify
  `switchToVaultAsync`, `beginWatching`, `stopWatchingAsync`, persistence,
  scopes, tasks, or tests under this addition. Wait for a later live directive
  after the map records a smallest fail-first candidate.

### `LR-LIVE-2026-07-16-097` — resume Free-V1 removal intake: map the positive membership boundary before deleting June

- Additions 095–096 complete their narrow lifecycle work and leave the
  whole-transaction admission/rollback redesign as named later debt. It does
  not block the independent, owner-required Free-V1 membership work. The next
  sole action is a **read-only removal intake** for the canceled paid product
  closure, led by the current order: June is to be removed completely from the
  Free product; Kokoro local read-aloud remains an allowed retained capability;
  local embedding-backed note search remains an allowed capability that must be
  audited and hardened later for retrieval effectiveness. Do not equate any of
  those three boundaries or preserve a paid closure because it shares a file,
  resource, name, or historical build script with one of the retained paths.
- Re-read the full live coordinator prompt and record a new owner-intent
  checkpoint. Then map, without editing, the **actual current Free build and
  runtime closure**: `project.yml`/generated project target membership;
  pre/post-build scripts and their transitive calls; source/resource/framework/
  package/product/plist/entitlement membership; target-condition branches;
  bootstrap/composition/router/menu/command/deep-link/widget/Intents reachability;
  persisted/default/migration/compatibility identities; tests and release-gate
  assertions; and executable strings/metadata. Search semantically for June,
  Goose, `agent_core`, AgentWorkspace/Harness, paid generation/provider/chat/
  prompt/approval/MCP/Omega terminology, including indirect aliases rather than
  only directory names. Contrast every found path with the active App Store
  target and record whether it is included, excluded but still built/copied,
  merely historical/test/docs, a separately owned Settings or Lane B handoff,
  or an exact deterministic compatibility need.
- Produce a positive Free allow/deny and dependency/ownership table. It must
  show the smallest coherent **first removable vertical slice**, all callers
  that would break, the data-only compatibility/migration behavior required for
  old bytes, test seams, and prospective red/green evidence. Call out every
  ambiguous shared file and every conflict with the retained Kokoro or
  embedding-search closures. Inspect the existing dirty worktree and attribute
  overlap; do not claim ownership of another worker’s change.
- This is discovery and contract selection only: do not delete/exclude/rename
  source; change project/scripts/tests; run a build, app, or artifact scan;
  install/download/select a model; start Settings or Lane B; commit/integrate;
  or begin the rebuild. After recording the map and ranking one fail-first
  removal candidate, wait for the next live directive.

### `LR-LIVE-2026-07-16-098` — first executable Free-removal repair: make the App Store build/release contract positive and paid-free

- Addition 097 has established the first isolated contradiction. The active
  Free target already excludes June/Goose/`agent_core` compilation and skips
  their prebuilds, but its checked-in project/build/release contract still
  requires their source/staging identities. That contract blocks safe later
  deletion and is not a valid Free boundary. This addition authorizes exactly
  one fail-first red/green **build-contract** slice before any June source-tree
  deletion or broader paid-closure work.
- First re-read the full prompt, ledger 097, current hunks, and the dedicated
  Free-test target membership. Add one narrowly named active source-contract
  regression in a test file that is genuinely a current App Store test member.
  If the existing untracked removal test overlaps another owner, do not modify
  it: prove automatic membership and add a separate focused test file instead.
  Its initial red assertions must use repository text—not a generic mock—and
  prove all of the following: the App Store target’s invoked prebuild path does
  not dispatch `build-june-web.sh`, `build-agent-core.sh`, or `build-omega-mcp.sh`;
  its runtime-asset path does not stage/copy JuneWeb, agent skills, agent-core,
  or paid model material for subsequent cleanup; and the Free release gate does
  not require June/Goose/`agent_core` checkout files or positive paid routing.
  The test may still require Free artifact **absence** checks for paid runtimes/
  resources and explicit retained Kokoro/read-aloud and deterministic
  note-search prerequisites. It must not select, wire, or assert a model.
- Record the named red receipt before implementation. Then make the smallest
  coherent contract correction, limited to the App Store target declaration,
  its directly invoked runtime-asset/release scripts, and the new focused test.
  Replace paid staging/scrub logic with positive Free-only inputs and reviewed
  absence checks; remove the stale source-checkout requirements and all
  Free-target calls to paid prebuilds. Do not delete the future-edition June,
  Goose, or Rust source trees in this slice; do not alter the compiled
  MCP/Omega/Harness closure; do not touch Settings/Lane B; do not modify
  lifecycle/FirstRun; and do not change embedding implementation, model
  selection, model assets, or the current zero-model test policy. If a
  candidate hunk overlaps unexplained dirty work, isolate a non-overlapping
  correction or record the precise overlap rather than overwriting it.
- Re-read every changed caller/hunk, run `git diff --check` and the smallest
  applicable parse/static check, then rerun only the same named regression for
  a green receipt. Run no broad build or artifact scan in this slice. Record
  the remaining source deletion, Settings, compiled paid closure, artifact,
  integration, and embedding-retrieval debts; wait for another live directive
  after that receipt. Commit and rebuild remain prohibited.

### `LR-LIVE-2026-07-16-099` — delete the now-unreachable JuneAgent source tree and seal its Free project membership

- Owner intent remains controlling: “remove completely because this is the
  free version.” Addition 098 has removed the Free build/release dependency on
  the June checkout and has supplied a current active test receipt. The next
  smallest coherent removal batch is **only** the physical
  `Epistemos/JuneAgent/**` source tree and its stale Free project membership.
  This is not permission to preserve June merely because it occurs behind a
  `!EPISTEMOS_FREE_V1` branch, nor permission to delete every historical June
  string in one sweep.
- First re-read this full prompt through EOF, additions 097–098, the current
  ledger, the complete `JuneAgent` tree, all project/generated-project
  membership edges, the release gate, and the current dirty hunks. Update the
  owner-intent/debt checkpoint with the exact root files that still name the
  tree. Confirm that `FreeV1BuildContractTests.swift` remains an active App
  Store test member and does not overlap the untracked removal suite. Preserve
  every unrelated dirty hunk. Never regenerate the whole Xcode project or use
  a broad rewrite to make the tree disappear.
- Extend **only the owned focused Free build-contract test** with a fail-first
  source-membership contract: the Free target declaration and its generated
  App Store membership must not carry a `JuneAgent` exclusion/exception or
  path; the Free source gate must explicitly require the `Epistemos/JuneAgent`
  tree to be absent; and the existing retained Kokoro/read-aloud, lexical-note
  search, and paid-artifact absence assertions must remain. The new test must
  use staged repository text, not a mock or an attempt to open an absent file.
  Run this exact named active regression once red before deletion and record
  its nonzero identifier/count. The red result may demonstrate missing positive
  absence policy and stale project membership; do not claim it proves an app
  artifact state.
- After the red receipt, make only this coherent correction: add the Free
  source-gate absence assertion; remove the stale `JuneAgent` target exclusion
  and the exact mirrored generated-project exceptions/paths; and delete only
  `Epistemos/JuneAgent/**` using the approved surgical edit mechanism. Re-read
  every deleted file's direct project/reference edge first. Do **not** delete
  `build-june-web.sh`, `.june-web-stage`, JuneWeb resource-cleanup guards,
  `Epistemos/Goose/**`, `agent_core/**`, MCP/Omega/Harness, shared data keys,
  non-Settings guarded root identities, or any Settings file in this slice.
  Do not change lifecycle/FirstRun, model/embedding behavior or assets, the
  zero-model test policy, Lane B, integration, commit, or rebuild work.
- Run `bash -n` for the changed gate, the relevant project/test parse checks,
  the no-artifact Free source gate, `git diff --check`, and then exactly the
  same active regression once for green. Use a fresh owned
  `/tmp/epistemos-codex-laner-099` directory; never remove an earlier
  receipt directory to make room. No broad build, archive, app launch, exact
  artifact scan, model execution, model selection/download, project-wide
  formatting, staging, commit, or rebuild. Record the green receipt, all
  retained stale guarded identities and later June producer cleanup, then wait
  for a later live directive.

### `LR-LIVE-2026-07-16-100` — continuous Lane R progression; checkpoints are handoffs, not pauses

- Owner clarification controls every unfinished Free-removal batch: “finish
  whatever work [you] were doing then move to the next until [you] get to the
  rebuild and finish that.” A green scoped receipt, an updated ledger, or a
  prompt-hash refresh is **not** a reason to ask the owner to reactivate, wait
  idly, or stop the program. It is the required evidence handoff into the next
  bounded batch. This amends each earlier “wait for the next directive” phrase
  in the Lane R removal sequence, including the final sentence of 099.
- Preserve the existing safety shape: do not blend unrelated removals, bypass
  fail-first proof, write over multi-owner work, skip required build/test
  checkpoints, start Lane B or Settings, make a mass commit, or activate the
  app-wide rebuild early. Finish the active batch honestly first. If evidence
  is incomplete or a real ownership/technical blocker exists, exhaust the
  authorized read-only checks, record the exact blocker and safe next action,
  and continue with an independent Lane R slice where possible; do not convert
  ordinary uncertainty or an expected test failure into a user-wait state.
- After 099's same-test green receipt, the coordinator must immediately use its
  recorded source/reference/debt map to append the next narrowly numbered
  `LR-LIVE` directive to this live prompt and resume the Lane R worker against
  that hash. Each successor must state exact in/out scope, ownership, red/green
  proof, retained compatibility boundary, verification checkpoint, and the
  following discovery/handoff condition. The worker must re-read through EOF,
  reconcile the changed hash, and execute that successor without a new owner
  prompt. Repeat this autonomous sequence through the complete permitted Lane
  R removal/hardening program.
- Queue by the evidence already found, not by cosmetic convenience: first
  reconcile the remaining guarded June producers/references and their
  compatibility/testing seams in small fail-closed slices; then continue the
  established Free-closure maps for other disallowed paid/runtime residue,
  always preserving the expressly retained Kokoro read-aloud and improving—not
  deleting—the separately queued embedding-backed retrieval path. Do not touch
  an item merely because it shares terminology; prove its actual Free target,
  runtime, data, and artifact relationship before selecting it.
- The transition to the pre-rebuild checkpoint and the counterfactual V2 phase
  remains automatic only after the currently authorized Lane R program and all
  required serial handoffs are genuinely reconciled. At that point do not seek
  approval again: create the attributed checkpoint exactly as the successor
  phase requires and begin the atlas/first rebuild slice. Continue through the
  rebuild and its deep-hardening loop until the owner explicitly redirects or a
  real blocker prevents useful progress.

### `LR-LIVE-2026-07-16-101` — accept the finalized 099 fail-first receipt; do not duplicate the red run

- The existing 099 red invocation has now finalized at
  `/tmp/epistemos-codex-laner-099/Results/FreeV1BuildContractRed-099.xcresult`.
  `xcresulttool` reports exactly one selected test,
  `FreeV1BuildContractTests/freeV1BuildAndReleaseContractUsesOnlyAllowedInputs()`,
  with `passedTests: 0`, `failedTests: 1`, and result `Failed`. The recorded
  assertion is that the App Store target text still contains `JuneAgent/**`.
  This is the intended stale-membership red witness.
- An earlier attempt to open the bundle while Xcode was still finalizing it saw
  no `Info.plist`; that transient read is not a test outcome. Do not rerun the
  red test, delete its receipt, or treat the transient inspection as a second
  execution. Preserve the owned 099 directory. The finalized one-test result
  above is the sole required red proof for addition 099.
- Reconcile this prompt hash and record the finalized receipt in the ledger,
  then continue directly with only 099's authorized correction: add the source
  gate absence assertion, remove the one `project.yml` exclusion and 20 exact
  generated project exceptions, delete only `Epistemos/JuneAgent/**` surgically,
  perform the named static checks, and run the same test once for green. All
  prior exclusions and the automatic-continuation rule remain unchanged.

### `LR-LIVE-2026-07-16-102` — recover the zero-test green attempt without reopening the deletion slice

- The first post-deletion green invocation finalized at
  `/tmp/epistemos-codex-laner-099/Results/FreeV1BuildContractGreen-099.xcresult`
  with `totalTestCount: 0`, `passedTests: 0`, `failedTests: 0`, and result
  `unknown`. It is neither a green receipt nor a counterexample to the source
  correction. Preserve that bundle and its build log as diagnostic evidence;
  do not describe it as a successful test and do not change source to satisfy
  it.
- After full-prompt/hash reconciliation, first inspect only the retained green
  attempt's build log, result metadata, test-discovery/scheduling diagnostics,
  and the current focused-test target membership to identify why it selected
  zero tests. No source, project, gate, or deletion change is authorized by
  this investigation. Keep the already-finalized red witness and every 099
  result directory intact.
- Then, if the host is clear and resource preflight remains inside the recorded
  limits, run **one** recovery green invocation with a new distinct result path
  such as `FreeV1BuildContractGreenRetry-099.xcresult`. Select the exact active
  identifier—not merely a broad target—
  `EpistemosAppStoreKeelstoneTests/FreeV1BuildContractTests/freeV1BuildAndReleaseContractUsesOnlyAllowedInputs()`.
  Capture a verbose build log inside the same owned 099 directory and wait for
  result-bundle finalization before reading it. A valid receipt must show total
  test count `1`, passed `1`, failed `0`, skipped `0`, and that exact test
  identifier. If it does not, record the structured result and diagnose the
  test-selection failure; do not infer a pass, delete receipts, or resume a
  broader removal.
- This is a verification-recovery exception only. It does not authorize a
  second red test, any source edit, a broad build, artifact claim, Settings or
  Lane B work, model/retrieval work, commit, or rebuild. Once the one-test
  green receipt is valid, record it and immediately continue under addition
  100's automatic-successor rule.

### `LR-LIVE-2026-07-16-103` — repair only the stale test-fixture staging blocker exposed by 102

- Current diagnostic evidence identifies the zero-test cause precisely: the
  retained rerun log records `error: missing repository source guard input:
  Epistemos/JuneAgent/JuneAgentApprovalRegistry.swift`, followed by build
  failure and cancelled testing. The generic App Store test-fixture staging
  phase discovers `loadRepoTextFile` literals across the target and aborts on
  this now-intentionally-absent path from an unselected, stale June test. This
  is a fixture-staging build blocker, not a failed current source contract and
  not a reason to restore the deleted tree.
- Before editing, map the exact staging implementation in both `project.yml`
  and the generated project build phase, the focused test's fixture mechanism,
  and the stale literal's owning test. Preserve the untracked/stale test; do
  not make it pass by inventing, copying, or restoring a June fixture, and do
  not modify the test merely to remove its historical expectation. Record it as
  later test-cleanup debt.
- Authorize the smallest coherent test-build correction only: in the existing
  App Store repository-fixture staging phase, retain fail-closed behavior for
  every ordinary missing fixture but explicitly skip staging a path only when
  it is under the confirmed removed root `Epistemos/JuneAgent/`. Emit a clear
  build note naming the intentionally absent root. Do not stage a placeholder
  or empty file, broaden this exception to Goose/agent_core/any other prefix,
  loosen test discovery generally, or change production source, release-gate
  policy, Settings, Lane B, embeddings, or project topology. Mirror the exact
  surgical staging hunk between source project declaration and generated
  project; do not regenerate the project.
- Re-read both changed staging hunks and prove all non-June missing fixture
  paths still fail the script's source inspection. Then run the prescribed
  102 recovery exactly once with the exact selected current test and a fresh
  distinct `GreenRetry` result bundle. Require a finalized 1/1 pass before
  accepting 099. Record the retained stale June test and later comprehensive
  test cleanup as debt, then continue automatically under addition 100.

### `LR-LIVE-2026-07-16-104` — recover the valid one-test receipt using the registered Swift Testing suite selector

- Addition 103's source correction is complete and its controlled fixture
  proof is valid: the mirrored staging phase skips only
  `Epistemos/JuneAgent/*` with a clear note and preserves the ordinary
  missing-fixture error branch. Its initial function-level Xcode selector is
  not a green receipt: the finalized result records zero discovered tests even
  though the runner loads the `Free V1 build and release contract` suite.
  Do not mislabel that exit-zero/zero-test result as a pass or reopen the
  staging/source correction.
- Before the one permitted recovery, read the failed 099 result's registered
  test identifier and its suite URL, then re-read
  `FreeV1BuildContractTests.swift`. Record that its registered suite
  `FreeV1BuildContractTests` contains exactly one `@Test`, named
  `freeV1BuildAndReleaseContractUsesOnlyAllowedInputs()`. This is a
  selector-grammar correction, not a broader suite authorization.
- Run exactly one fresh recovery into a distinct owned result bundle using
  `-only-testing:EpistemosAppStoreKeelstoneTests/FreeV1BuildContractTests`
  (the registered suite identifier, deliberately **without** the unregistered
  function suffix). The test target may compile its normal members, but
  acceptance requires its finalized result to report precisely total 1, passed
  1, failed 0, skipped 0, and the named method identifier above. Preserve all
  earlier zero-test bundles and logs. If this recovery is not 1/1, record its
  structured result and stop the build loop; do not try selector variants,
  broaden to the target/full suite, change source, or silently accept it.
- Scope remains verification only: no production, test, project, fixture,
  release-gate, Settings, Lane B, Goose/agent_core, embedding/retrieval,
  lifecycle, integration, commit, or rebuild change. On a valid receipt,
  update the Lane R ledger with the selector distinction and automatically
  continue under addition 100 with the next narrow source/reference intake.

### `LR-LIVE-2026-07-16-105` — reconcile the Free-V1 membership contract with the required fixture-stage exception

- The finalized addition-104 result is the fail-first receipt for this exact
  correction. It proved that the registered suite selector executes exactly one
  real test, and that the only failing condition is the focused test's blanket
  `generatedProject.contains("JuneAgent/")` check. The literal it sees is the
  deliberately retained `Epistemos/JuneAgent/*` fixture-stage skip from
  addition 103; it is not an App Store target membership exception, a restored
  source file, or a release-gate regression. Preserve every prior 099–104
  bundle and log. Do **not** run another red test.
- This is a test-contract precision repair, with one permitted source file:
  `EpistemosAppStoreKeelstoneTests/FreeV1BuildContractTests.swift`. Before
  editing, re-read the active App Store filesystem-synchronized
  `membershipExceptions` set in the generated project, its matching semantic
  App Store target, the staging phase, and the failing test. Replace only the
  blanket generated-project absence assertion with a semantic assertion that
  isolates that App Store target's `membershipExceptions` block and proves it
  contains no `JuneAgent/` member path. Do not identify the block by a volatile
  object UUID alone; bind it to the current App Store target semantics and fail
  closed if the expected block cannot be found.
- Keep the physical-tree and release-gate absence assertions. Add/retain a
  positive assertion that the generated staging phase has exactly the intended
  `Epistemos/JuneAgent/*` skip and its explicit "intentionally absent Free V1
  source root" note, so the focused contract distinguishes a prohibited source
  membership from the required narrowly fail-closed fixture behavior. The test
  must not weaken the ordinary missing-fixture failure rule, accept any broad
  absence exception, or merely suppress a string match. Re-read the changed
  test region and inspect its diff; `swiftc -parse` and `git diff --check` are
  required before the one green run.
- Do not alter `project.yml`, `project.pbxproj`, any staging/release/build
  script, production source, the deleted tree, shared stale tests, fixtures,
  Settings, Lane B, Goose/agent_core, embeddings/retrieval, lifecycle,
  integration, commit, or rebuild in this slice. If the evidence points beyond
  the focused assertion, stop and record the blocker rather than expanding it.
- After fresh resource/no-host preflight, run exactly one new suite-level
  recovery using
  `-only-testing:EpistemosAppStoreKeelstoneTests/FreeV1BuildContractTests`, in
  a distinct owned 105 result bundle and verbose log. A valid green receipt is
  precisely total 1, passed 1, failed 0, skipped 0, with
  `FreeV1BuildContractTests/freeV1BuildAndReleaseContractUsesOnlyAllowedInputs()`
  named in the structured result. Do not try selector variants or a broad
  target run. On success, record the corrected membership-vs-fixture distinction
  and verification receipt in the Lane R ledger, then automatically continue
  under addition 100 with the next narrowly scoped non-Settings guarded-June
  producer/reference intake; do not pause for a prompt hash change.

### `LR-LIVE-2026-07-16-106` — repair the focused Swift Testing macro name collision and recover the membership receipt

- Addition 105's one permitted suite recovery is finalized and is **not** a
  green receipt. Preserve
  `/tmp/epistemos-codex-laner-099/Results/FreeV1BuildContractGreenMembershipRetry-105.xcresult`
  and its verbose log. It compiled the target until the focused test hit three
  `Cannot call value of non-function type` diagnostics: each new local binding
  used the same identifier as the helper it invokes inside a `#require` macro.
  The result reports zero executed tests because the build failed. Do not call
  this a selector failure, a membership regression, or a passing result.
- This addition permits only
  `EpistemosAppStoreKeelstoneTests/FreeV1BuildContractTests.swift`. Re-read the
  full focused test and 105's finalized error receipt before editing. Rename
  only the three local result bindings that collide with their helper names
  (the App Store membership list, fixture staging phase, and fixture skip
  patterns) to unambiguous value names. Update their immediate assertions to
  use those renamed values. Do not rename helpers, alter their semantic
  target→synchronized-root→exception-set traversal, change assertions,
  introduce a fallback, change the fixture-stage contract, or alter any other
  source/test/project/script/file.
- Re-read the modified region and inspect the exact diff. `swiftc -parse` and
  `git diff --check` are required, but acknowledge that this particular
  macro-expansion error is only conclusively exercised by the authorized Xcode
  receipt. No additional red run, selector variation, broad target selection,
  app launch, artifact scan, Settings, Lane B, embeddings/retrieval, Goose/
  agent_core, integration, commit, or rebuild action is authorized.
- After fresh resource/no-host preflight, run exactly one new suite-level
  recovery using
  `-only-testing:EpistemosAppStoreKeelstoneTests/FreeV1BuildContractTests` into
  a distinct owned 106 result bundle and verbose log. Acceptance is exactly
  total 1, passed 1, failed 0, skipped 0, naming
  `FreeV1BuildContractTests/freeV1BuildAndReleaseContractUsesOnlyAllowedInputs()`.
  Preserve 105 as the failed compile receipt. If 106 is not 1/1, record its
  structured outcome and stop the build loop; do not retry or widen scope. On a
  valid receipt, record the membership-versus-fixture and macro-collision
  reconciliation in the Lane R ledger, then automatically continue under
  addition 100 with the next narrow non-Settings guarded-June producer/reference
  intake.

### `LR-LIVE-2026-07-16-107` — map remaining guarded June producers before the next Free-V1 removal slice

- Addition 106's focused contract is now green only when its finalized bundle
  reports total 1, passed 1, failed 0, skipped 0, and names
  `FreeV1BuildContractTests/freeV1BuildAndReleaseContractUsesOnlyAllowedInputs()`.
  Preserve every 099–106 result/log directory. This addition is the next
  automatic Lane R action under addition 100: a **read-only** source/reference
  intake. It does not authorize a June removal mutation yet.
- Re-read the full live prompt and the 097/099/103/104/105/106 ledger evidence,
  then map every remaining current-source occurrence that produces, routes to,
  renders, registers, persists, restores, or otherwise makes a June identity
  reachable. Use semantic caller/callee and compiler-condition inspection, not
  text-counts alone. For each result, record: file/symbol, owning route/surface
  or subsystem, calling/ownership edge, exact Free compilation condition and
  project membership, whether it is Free-reachable, Free-inactive only because
  of a compile guard, data-only compatibility, a stale test/documentation
  expectation, or an unrelated historical word, and its required disposition.
- The map must specifically reconcile the non-Settings producer seams in
  `RootView`, `LandingView`, and adjacent landing/feature-route composition;
  app bootstrap/window/surface routing; every `#if EPISTEMOS_FREE_V1` or
  inverse June branch; direct type/enum/default/route references; and relevant
  user-visible terminology. Confirm the physical `Epistemos/JuneAgent` tree
  remains absent and distinguish its deletion from any current guarded caller.
  It must also identify—but not modify—the protected handoffs: Epdoc
  chrome/dock/markdown surface under `Epistemos/Views/Epdoc/**` (Lane B), all
  Settings files, and Goose's separate `JuneMASToolPolicy` dependency. Do not
  turn the latter two into excuses to leave an otherwise removable Free route.
- Separately classify persisted/default/restore and document content references
  as active product behavior versus a minimal data-only compatibility/migration
  boundary. Preserve user-authored data compatibility where evidence requires
  it, but reject hidden/no-op June product access as a disposition. Keep the
  previously retained Kokoro read-aloud and embedding-backed retrieval seams in
  scope only as non-goals; do not change, select, download, or test models or
  retrieval here.
- Deliver the map and a ranked smallest next removal candidate to the Lane R
  ledger, including exact files, test seam, blast radius, rollback condition,
  and verification debt. This addition permits no production/test/project/
  script/gate/source-tree edit, build/test/app launch, artifact scan, Settings,
  Lane B, Goose/agent_core, embedding/retrieval, lifecycle, integration,
  commit, or rebuild action. Once the ledger map is complete, automatically
  append the next bounded implementation directive under addition 100; do not
  wait for an unchanged prompt hash or owner re-prompt.

### `LR-LIVE-2026-07-16-108` — remove the isolated RootView June-toolbar no-op and prove its Free boundary

- Addition 107's completed map identifies the first bounded implementation
  slice: the included `Epistemos/App/RootView.swift` June-toolbar producer is
  not Free-reachable, but it is a retained no-op/guarded product identity. The
  Free-visible Landing `.agent → .greeting` sanitizer is a distinct,
  multi-file session-route cleanup and must remain intact in this slice. The
  physical `Epistemos/JuneAgent` tree remains required to be absent; its
  deletion is not permission to collapse generic Home routing.
- Before mutation, reread the full live prompt through EOF, addition 107's
  map, the finalized 106 receipt, the whole current `RootView` toolbar seam,
  and the whole current `FreeV1BuildContractTests.swift`. Record the prompt
  SHA-256 and an intent checkpoint in the Lane R ledger. The owner intent here
  is precise: remove the complete `RootView`-only June toolbar producer,
  including the `showJuneAgentToolbarControls` computed property, its
  principal-toolbar visibility predicate term, and the guarded
  `JuneAgentNavBar`/return-home render block. Keep the existing landing and
  embedded-graph toolbar controls and all other root behavior unchanged.
- This addition permits exactly two edits:
  `Epistemos/App/RootView.swift` and
  `EpistemosAppStoreKeelstoneTests/FreeV1BuildContractTests.swift`. First add
  the focused, fail-first source contract to the latter: load the current root
  view fixture and require that it contains neither
  `showJuneAgentToolbarControls` nor `JuneAgentNavBar`. The contract must
  retain all current project-membership, one exact fixture-stage skip,
  physical-tree release-gate, Kokoro, and lexical-shadow assertions. This is
  a source-boundary regression contract; do not run an unproductive red Xcode
  loop merely to observe its pre-edit failure.
- Then make the surgical RootView deletion described above. Do not alter the
  principal toolbar item's remaining landing/graph/chat condition, its
  placement/background behavior, `rootToolbarControls`' remaining control
  group, `UIState.HomeContent.agent`, Landing/LandingFeatureButtons, any
  model/default/runtime state, Epdoc/Markdown, Settings, Goose, agent_core,
  QuickChat, embeddings/retrieval, Kokoro, scripts, project/YAML, fixture
  staging, release gate, lifecycle, integration, commits, or rebuild.
  `AppStoreKeelstoneLaneTests.swift` is known stale test debt that still names
  removed June files and this RootView symbol. Do not hide, delete, or rewrite
  it in this small source seam; record its exact mismatch as retained
  verification debt for a separate test-reconciliation slice.
- Re-read the changed source and test regions and inspect the exact diff.
  Require `swiftc -parse -swift-version 6` for each changed Swift file and
  whitespace checks that include the untracked contract test as well as tracked
  diffs. Semantically prove from current source that the RootView no longer
  contains either removed identifier, that no `JuneAgentNavBar` reference
  remains outside protected/stale-test contexts, and that the Landing Free
  sanitizer still maps unavailable `.agent` content to `.greeting`. These are
  static proofs, not authority to modify the larger route.
- After a fresh resource/no-host preflight, run exactly one new suite-level
  receipt using
  `-only-testing:EpistemosAppStoreKeelstoneTests/FreeV1BuildContractTests` into
  a distinct owned 108 result bundle and verbose log. Accept only total 1,
  passed 1, failed 0, skipped 0, naming
  `FreeV1BuildContractTests/freeV1BuildAndReleaseContractUsesOnlyAllowedInputs()`.
  Preserve every prior receipt. If the result is anything else, record its
  finalized structured outcome and stop the build loop without a retry,
  selector variant, broader target run, or scope expansion.
- On a valid 108 receipt, record the exact RootView removal, static route
  evidence, retained stale-test debt, result paths, and rollback condition in
  the Lane R ledger. Under addition 100, continue automatically with the next
  read-only, non-Settings Lane R intake; do not wait for another owner prompt
  or an unchanged prompt hash. The next implementation directive remains
  coordinator-owned and must be separately grounded before any mutation.

### `LR-LIVE-2026-07-16-109` — diagnose duplicate Home-window launch/reopen behavior before further mutation

- New owner report, exact wording: “my app opens two apps whe veve i start it
  has two home pages for some reason the main one and then a small hom window
  that is like wierdly there on reopens etc.” This is a user-visible
  launch/window-lifecycle defect, separate from the Free-V1 June removal.
  It temporarily pauses the 108 source edit until this diagnosis is recorded;
  no 108-authorized file may be changed while this addition is active.
- Perform a **read-only** causal map covering `EpistemosApp`'s `WindowGroup`,
  `HomeWindowFallbackPresenter`, `AppStoreFirstWindowPresenter`,
  `EpistemosAppDelegate.applicationDidFinishLaunching`,
  `applicationShouldHandleReopen`, `HomeWindowIdentity`, and every call site
  that schedules, ensures, creates, surfaces, or restores a Home window. Map
  launch and reopen event ordering, `didSchedule` resets, all independent
  `NSWindow` creators, scene identity/viability predicates, and the behavior
  when the SwiftUI scene is slow versus absent. Distinguish a real fallback
  recovery path from a duplicate normal-start path; do not infer correctness
  from comments or a single time delay.
- Initial source evidence is a strong causal candidate, not yet a runtime
  proof: `EpistemosApp.init` schedules `HomeWindowFallbackPresenter` and, for
  the App Store build, `AppStoreFirstWindowPresenter`, while the app also
  declares the normal `WindowGroup("Epistemos")`. The App Store presenter can
  construct an `NSWindow` with the same Home identity if it does not observe a
  viable SwiftUI window at its timer boundary. Validate whether that overlap,
  any after-launch reschedule, or reopen path can leave both the scene window
  and fallback window visible. Do not claim a final root cause without a
  caller/order evidence chain.
- Record an owner-intent checkpoint and full diagnostic map in the Lane R
  ledger: exact owner report; observed source evidence; confirmed versus
  unconfirmed causal paths; affected build edition; current user impact;
  reproduction/observation plan; smallest safe repair candidate; test/UI
  evidence needed; data/window-state rollback implications; and any
  interaction with the paused RootView 108 slice. Use existing diagnostics and
  tests only read-only; no app launch, state purge, build/test, source/test/
  project/script/gate edit, Settings/Lane B/Goose/embedding/retrieval,
  lifecycle change, integration, commit, or rebuild action is permitted by
  this diagnosis addition.
- After the ledger entry, do not implement a repair under this addition.
  If the two narrow 108 hunks were already present when this addition was
  observed, preserve them as an **unverified, paused 108 partial**: do not
  revert, extend, validate with Xcode, or use them to justify further work.
  Record their exact state and unchanged unrelated RootView diff context in
  the ledger. Preserve 108 as the next unrelated bounded source slice, report
  the evidence-backed diagnosis, and wait for an explicit repair authorization
  or later coordinator directive that separately names the allowed files,
  duplicate-window regression test/observation, and a rollback path.

### `LR-LIVE-2026-07-16-110` — resume and close only the paused RootView removal verification

- Addition 109's read-only diagnostic ledger is complete. It records a
  source-proven duplicate-window candidate and an explicit evidence gap; it
  does **not** authorize a window-lifecycle repair. `Epistemos/App/EpistemosApp.swift`,
  `HomeWindowIdentity`, all window presenters/delegates, window tests,
  diagnostics, saved-state behavior, and any UI/runtime observation remain
  prohibited until an owner-authorized, separately bounded repair directive.
- Resume only the previously authorized 108 slice, which was paused after its
  two intended hunks appeared: `Epistemos/App/RootView.swift` removes the
  isolated June-toolbar no-op and
  `EpistemosAppStoreKeelstoneTests/FreeV1BuildContractTests.swift` loads
  RootView and rejects `showJuneAgentToolbarControls` and `JuneAgentNavBar`.
  Before validating, reread the full live prompt through EOF, the completed
  109 ledger map, the complete current two files, and their exact diffs.
  Record a new intent reconciliation with the live SHA-256.
- Do not make any new source or test edit in this resumption. Attribute the
  unrelated dirty RootView hunks (document-toolbar visibility, safe-defaults,
  and Quick Capture routing) as other-owner context and prove that the 108
  hunk is limited to the three named toolbar removals. Preserve the focused
  contract's existing membership, fixture-stage, physical-tree release-gate,
  Kokoro, and lexical-shadow assertions intact. Do not alter the shared stale
  `AppStoreKeelstoneLaneTests.swift` debt.
- Re-read the changed regions and inspect the exact diffs. Run
  `swiftc -parse -swift-version 6` on both 108 files and whitespace checks
  covering tracked diffs and the untracked contract test. Statically prove:
  RootView contains neither removed identifier; no non-protected/non-stale
  production `JuneAgentNavBar` reference survives; the principal toolbar still
  uses its landing/graph/chat condition and remaining control group; and
  Landing's unavailable `.agent` sanitizer still maps to `.greeting`. These
  checks must not enter any prohibited window-lifecycle file.
- After a fresh resource/no-host preflight, run exactly one suite-level 108
  receipt with
  `-only-testing:EpistemosAppStoreKeelstoneTests/FreeV1BuildContractTests`, a
  distinct owned result bundle, and a verbose log. Accept only total 1,
  passed 1, failed 0, skipped 0, naming
  `FreeV1BuildContractTests/freeV1BuildAndReleaseContractUsesOnlyAllowedInputs()`.
  Preserve all earlier results. Any other result is final for this attempt:
  record the structured outcome and stop the build loop without a retry,
  selector variant, broader build, app launch, or scope expansion.
- On a green receipt, record the exact 108 verification plus the separate
  unresolved duplicate-window repair requirement/debt in the Lane R ledger.
  Then automatically proceed under addition 100 only to the next **read-only**
  Lane R intake; do not edit a window-lifecycle file, start Lane B, perform an
  integration/commit/rebuild, or await an unchanged prompt hash.

### `LR-LIVE-2026-07-16-111` — freeze the 108 test loop and reconcile overlapping receipt artifacts

- During the one-receipt window under addition 110, overlapping external
  continuation turns attempted to coordinate the same suite/result root. This
  invalidates any assumption of a clean single exclusive-host launch. Do not
  start, resume, retry, vary, or broaden an `xcodebuild`/test command for 108.
  Do not delete result bundles/logs, terminate a currently running build, or
  alter source/test/project/script/gate/window-lifecycle files.
- Once all current Xcode/compiler/test-host processes have exited, perform
  read-only artifact reconciliation for every existing distinct 110 result
  bundle and verbose log under `/tmp/epistemos-codex-laner-110`, including the
  attempted `FreeV1BuildContractRootViewRetry-110`, `FreeV1BuildContractRootView-108`,
  and `FreeV1BuildContractGreen-108` paths if present. For each, record the
  exact command evidence, timestamps, final structured summary, named tests,
  build diagnostics, and whether it was a real execution, a shell/setup
  failure, or no retained result. Do not infer status from bundle-directory
  presence. Preserve any malformed/partial artifact as evidence.
- Reconcile the static 110 checks separately from test evidence. The parses,
  whitespace checks, RootView identifier absence, remaining principal-toolbar
  condition/control group, and Landing fail-closed sanitizer may be recorded as
  static proof. They are not a substitute for the distinct one-run receipt.
  Do not call 108 green, clean, exclusive, or fully verified unless an existing
  artifact independently proves the exact expected 1/1 result and its launch
  provenance is not contradicted by the overlap.
- Write a precise receipt/debt entry to the Lane R ledger. If artifacts show
  overlapping executions or an ambiguous provenance, preserve all evidence and
  mark the **108 test receipt as verification debt, with no retry authorized**.
  The already-present RootView/test hunks remain frozen; the duplicate-window
  repair remains separate unresolved debt. After recording, continue only with
  a new read-only Lane R intake under addition 100; no source mutation, test,
  app launch, integration, commit, rebuild, Lane B, Settings, or
  window-lifecycle repair is authorized by this addition.

### `LR-LIVE-2026-07-16-112` — map the retained paid-Agent Home route before its next Free removal slice

- This is the required next coordinator-owned, **read-only** Lane R intake
  under additions 100 and 111. The owner’s Free intent remains removal, not
  merely hiding, of the canceled June/paid-Agent product surface; the owner’s
  separate instruction to retain and harden notes-only embedding/hybrid search
  remains unchanged. Do not conflate the paid Agent Home route with semantic
  retrieval, embeddings, ordinary user text, the note editor, graph, or the
  separately diagnosed duplicate Home-window lifecycle defect.
- Current source evidence establishes a potentially removable but wider route
  seam: `Epistemos/State/UIState.swift` retains
  `UIState.HomeContent.agent`; `Epistemos/Views/Landing/LandingView.swift`
  sanitizes that state to `.greeting` when `.paidAgent` is unavailable, renders
  `EmptyView()` for the Free `case .agent`, retains the non-Free
  `JuneAgentSurfaceView()` producer, has a debug-only paid-Agent launch path,
  and retains a `performLandingFeatureButton(.agent)` assignment;
  `Epistemos/Views/Landing/LandingFeatureButtons.swift` still declares the
  `.agent` case, its future-paid capability, glyph/haptic/brand, unavailable
  copy, and `CaseIterable`/visible-case filtering. These facts do not yet
  authorize deleting any state case, switch branch, copy, policy, or test.
- Re-read this full prompt and the 107–111 ledger evidence, then map the exact
  complete route closure: every constructor, assignment, switch/exhaustiveness
  branch, command/shortcut/deep-link/debug path, restoration/serialization or
  migration path, UI accessibility/read-aloud path, App Store target-membership
  edge, and source or test assertion that names `HomeContent.agent`,
  `homeContent = .agent`, `case .agent`, `LandingFeatureButton.agent`,
  `JuneAgentSurfaceView`, or the corresponding Free guards. Classify each hit
  as active Free behavior, non-Free/future-edition-only code retained in the
  source root, protected Lane B/Settings/Goose code, stale test/fixture debt,
  generic unrelated `agent` terminology, or ordinary user content. Search
  semantically as well as lexically, including persisted/default/restore
  records; do not assume the currently session-only default proves every
  legacy ingress impossible.
- Treat the present `AppStoreKeelstoneLaneTests.swift` expectations for the
  old Landing/June guard and the removed June source tree as visible stale-test
  debt, not approval to weaken, delete, or satisfy them by restoring paid
  source. Identify their owner, target membership, and required later
  reconciliation. Likewise preserve every existing Free safety behavior for
  notes, document/graph/meeting paths and the `.agent -> .greeting` fail-closed
  behavior until a later implementation directive supplies a compatible
  replacement and proof.
- Record a route-closure map in the Lane R ledger: exact file and symbol,
  current Free/non-Free behavior, target membership/owner, mutation candidate,
  blast radius, compatibility and rollback condition, required fail-first
  regression proof, and verification debt. Explicitly determine whether a
  future narrow implementation can be limited to Lane R-owned `UIState`,
  Landing, its feature-button producer, and an appropriate focused test, or
  whether any necessary caller/test is protected and must be a handoff.
- This addition authorizes no source/test/project/script/gate/fixture edit,
  Xcode/test command, app launch, artifact scan, Settings or Lane B edit,
  lifecycle/window repair, model download/execution, embedding/retrieval
  change, integration, commit, or rebuild. Do not retry 108. After recording
  the map, continue under addition 100 only by requesting/awaiting a new
  coordinator-owned bounded implementation addition; do not mutate based on
  this map alone.

### `LR-LIVE-2026-07-16-113` — remove the complete dead paid-Agent Home route and retain Free Home invariants

- Addition 112’s completed closure map authorizes one coherent Lane R source
  batch. The owner’s intent is to remove—not hide—the canceled paid-Agent/June
  Home route from the Free source root. This is not an embedding, semantic
  search, Kokoro, note/editor, graph, meeting, browser, Settings, Lane B,
  Goose, lifecycle/window, project, fixture, or capability-policy rewrite.
  In particular, retain `ProductCapability.paidAgent` because other policy
  boundaries still use it, retain `HomeCommandHapticStyle.agent` because the
  Browser landing feature uses it, and preserve all ordinary user data.
- Before editing, re-read in full the five permitted files and their current
  diffs, the full addition 112 closure map, the full live prompt/hash, and the
  complete focused policy test. Attribute unrelated dirty hunks—especially
  document workspace, graph, Quick Capture, visual/layout, defaults, and
  future-edition changes—and do not move, format, discard, or absorb them.
  Write the intent checkpoint before the first mutation.
- **Only these files may change:**
  `Epistemos/State/UIState.swift`,
  `Epistemos/Views/Landing/LandingView.swift`,
  `Epistemos/Views/Landing/LandingFeatureButtons.swift`,
  `Epistemos/Views/Landing/PixelSurfaceComponents.swift`, and
  `EpistemosAppStoreKeelstoneTests/FreeV1ProductCapabilityPolicyTests.swift`.
  No other production, test, project, script, resource, fixture, gate, or
  documentation file is authorized by this batch. The existing untracked
  `FreeV1BuildContractTests.swift` and its frozen 108 receipt/debt are not a
  change target here.
- Make the complete removal atomically across that allowlist:
  1. Remove `UIState.HomeContent.agent` and only its paid-Agent-specific
     documentation; preserve every remaining Home case, the `.greeting`
     default, document selection, and Browser URL behavior.
  2. In `LandingView`, remove the `.agent` sanitizer/render/read-aloud branches,
     the non-Free `agentPageTitle`/`agentSurface` producer, the debug
     `EPISTEMOS_OPEN_AGENT_ON_LAUNCH` ingress, and the
     `performLandingFeatureButton(.agent)` action. Do not alter the remaining
     sanitizer behavior for arXiv/browser, Home document/graph/meeting/greeting
     rendering, landing read-aloud registration, keyboard behavior, or normal
     Free landing interactions.
  3. Remove `LandingFeatureButton.agent` and every exhaustive arm solely
     required by it—capability mapping, title/copy, glyph/haptic/accent,
     availability, and action-facing metadata—without altering the remaining
     feature cases or the retained `ProductCapability` enumeration.
  4. Remove `PixelGlyphKind.agent` and only its matching renderer branch after
     confirming it has no remaining qualified caller. Do not touch shared
     `HomeCommandHapticStyle.agent` or generic integration-brand behavior.
  5. Update only the focused policy assertions so they no longer require a
     hidden Agent tile or `.agent -> .greeting` state. Replace them with
     fail-closed, precise assertions that the Landing feature enum has only
     the retained cases and visible Free cases remain the intended Free set;
     retain policy coverage that `.paidAgent` itself remains unavailable and
     retain all unrelated capability, routing, graph, privacy, and embedding
     assertions. This test change must not weaken the independent stale
     `AppStoreKeelstoneLaneTests.swift` debt or conceal its expectations.
- Use fail-first order: first change the focused policy test so the pre-change
  route fails its new absence/retained-cases contract; do **not** run a red
  build. Then make the surgical source removal. Re-read every changed region
  and inspect the exact five-file diff. Required static proof: parse each
  changed Swift file; run whitespace checks including untracked files; show no
  remaining paid-Agent Home route symbol in the four production files
  (`HomeContent.agent`, `case .agent` for this route,
  `homeContent = .agent`, `agentPageTitle`, `agentSurface`,
  `JuneAgentSurfaceView`, or `EPISTEMOS_OPEN_AGENT_ON_LAUNCH`); prove all
  remaining Home cases and Free feature cases are intact; prove
  `ProductCapability.paidAgent` and the Browser haptic remain; and classify
  any other generic `agent` hit rather than deleting by text alone.
- Do **not** run Xcode, xctest, an app, artifact scan, a test selector, or a
  retry in this batch. Addition 111 permanently freezes the 108 test loop;
  nothing here reopens or reinterprets its ambiguous receipt. This batch’s
  later verification needs a separately authorized, fresh, exclusive-host
  checkpoint after the static receipt and any intervening batched work are
  reconciled.
- Record the changed-symbol map, exact diff attribution, static commands and
  outcomes, retained capabilities/behaviors, rollback condition, and deferred
  test proof in the Lane R ledger. Roll back this batch if any compile/static
  evidence reveals a live Agent Home producer, a Free dead/empty Agent page,
  changed Free document/graph/meeting/greeting/read-aloud behavior, loss of
  Browser haptics, or a broadened non-allowlisted change. After recording,
  automatically continue under addition 100 only with the next **read-only**
  Lane R intake; do not begin another source mutation without a new numbered
  coordinator addition.

### `LR-LIVE-2026-07-16-114` — map stale App Store lane-test expectations after Agent-route removal

- Addition 113 is complete as static-only evidence: the paid-Agent/June Home
  route is removed from its five-file source boundary, while the later 108
  Xcode receipt is permanently frozen as ambiguous verification debt. The
  next safe action is **read-only reconciliation**, not an attempt to make a
  stale test pass by restoring a paid route or by running a build. Owner
  intent remains Free V1 removal, retained and hardened local embedding/hybrid
  search, and eventual serial Lane R → Lane B → checkpoint → V2 rebuild.
- Before inspection, write an intent checkpoint that quotes the owner’s
  removal-over-hiding intent and the exact addition-113 retained invariants:
  ordinary Free Home/document/graph/meeting/read-aloud behavior, Browser's
  shared `HomeCommandHapticStyle.agent`, and unavailable
  `ProductCapability.paidAgent`. Re-read the complete live prompt/hash, the
  complete additions 111–113 ledger receipts, the full current
  `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`, its
  current diff/status, all direct suite/target/project membership references,
  and the current declarations/callers required to interpret each expectation.
  Attribute concurrent dirty hunks and do not normalize, format, or adopt
  them.
- Build a precise stale-test reconciliation map for every expectation in that
  test file that refers to a removed or intentionally unavailable paid-Agent/
  June Home path: raw lexical probes, fixture trees, compiled references,
  `#if` guard expectations, product/target/resource assumptions, source-string
  assertions, and any indirect helpers. For each, record the exact test and
  line/symbol, whether it is a current compiler/typecheck risk versus a
  semantic false expectation, its target membership/owner, the production
  boundary it observes, and whether a later correction belongs only in the
  stale test, needs a Lane R focused-test companion, or must be handed to
  serial integration. Search semantically for duplicate stale expectations
  outside this one file, but report them only; do not widen the target.
- Explicitly prove the negative: do not reintroduce `HomeContent.agent`, a
  Landing Agent branch/producer, `LandingFeatureButton.agent`,
  `PixelGlyphKind.agent`, `JuneAgentSurfaceView`, an old guarded June source
  tree, or a hidden/empty Free Agent tile to satisfy the test. Preserve the
  current non-route generic `agent` haptic and all embedding/retrieval code.
  Do not investigate or alter the independently diagnosed duplicate-window
  lifecycle path in this intake.
- **No source, test, project, fixture, resource, script, build setting, gate,
  or prompt edit is authorized by this addition.** The sole permitted write is
  an evidence entry in the existing Lane R ledger recording this map, commands
  and outcomes, candidate future allowlist, dependencies, rollback conditions,
  and deferred behavioral proof. Do not run Xcode, `xctest`, an app, an
  artifact scan, a test selector, or a retry; do not reopen 108. Do not start
  Lane B, integration, a commit, or the V2 rebuild.
- Completion of this intake is an honest source/test-debt map, not a claim that
  the stale suite compiles or passes. After the ledger entry, continue only by
  requesting/awaiting a separate coordinator-owned bounded implementation
  addition. That later addition must first reconcile all intervening Lane R
  work, name an exact file allowlist and fail-first contract, preserve the
  Free/embedding/window invariants above, and schedule no test execution until
  fresh exclusive-host authority is explicitly supplied.

### `LR-LIVE-2026-07-16-115` — repair the mapped Free App Store stale-lane test, then freeze prompt churn

- Addition 114 is complete. Its source-backed map establishes that the active
  App Store lane test is stale because it loads deliberately unstaged,
  physically absent `Epistemos/JuneAgent` fixtures and asserts the removed
  guarded Agent Home route and JuneWeb release contract. The owner has now
  directed the team to prioritize actual coding and batched verification over
  further prompt-driven audit loops. This is the final coordinator prompt
  addition until the owner explicitly says **“unfreeze prompt.”** Do not wait
  for another prompt hash to begin this repair or later already-mapped Lane R
  implementation batches.
- **First implementation batch — exactly one source/test file may change:**
  `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`.
  The Lane R ledger may receive a receipt. No production source, fixture,
  project, release gate, build script, resource, Settings, lifecycle/window,
  embedding/retrieval, Lane B, integration, commit, or prompt file may change
  in this first batch. This test file has a very large other-owner dirty diff;
  reread it in full and inspect its exact current diff before mutation. Do not
  reformat, move, replace wholesale, discard, or absorb unrelated hunks.
- Write the intent checkpoint and make the test correction surgically. Remove
  or replace only active-Free assertions whose premise is the absent June tree
  or the retired paid-Agent Home route: the active June gateway/Prompt Forge
  fixture probes; stale JuneWeb/local-GGUF release-gate strings; the twenty
  June loads, retained-paid-source count/presence premise, `JuneAgent/**`
  membership/presence premise, RootView/Landing guarded-presence probes, and
  Landing `case .agent`/`EmptyView` expectation; and June-only read-aloud
  fixture/string probes. Preserve every unrelated Free target exclusion,
  QuickChat/Goose/AgentWorkspace boundary, ordinary Free note/search/Kokoro
  assertion, fixture-stage exception, current `.paidAgent` unavailability,
  Browser haptic, and Landing/read-aloud coverage. The inactive
  `#if !EPISTEMOS_FREE_V1` direct `JuneAgentGateway()` test is non-Free
  ownership and must remain untouched in this batch.
- The replacement contract must assert removal rather than concealment:
  the App Store Free source tree has no June Home producer or hidden/empty
  Agent tile; no `HomeContent.agent`, Landing Agent branch/producer,
  `LandingFeatureButton.agent`, `PixelGlyphKind.agent`,
  `JuneAgentSurfaceView`, `JuneAgentNavBar`, `agentPageTitle`, `agentSurface`,
  or `EPISTEMOS_OPEN_AGENT_ON_LAUNCH` can be required by the active Free lane;
  the fixture stage intentionally skips the absent June tree; and retained
  ordinary Free read-aloud/landing behavior remains covered. Never make this
  test pass by restoring paid source, weakening target exclusion, or treating
  a generic shared `agent` haptic as an Agent product surface.
- Use fail-first discipline without a red build: first introduce the precise
  new absence/retained-behavior assertions, inspect how the pre-repair stale
  test contradicts them, then remove only its obsolete expectations. Re-read
  all changed regions and inspect the one-file diff. Required static evidence:
  Swift parse of the changed test, tracked and untracked whitespace checks,
  a direct scan proving no active-Free `loadRepoTextFile` June path or stale
  guarded-route/JuneWeb expectation remains, and positive scans proving the
  protected Free assertions and fixture skip remain. Do **not** run Xcode,
  `xctest`, an app, artifact scan, selector, retry, or 108 test during this
  batch. The first later test checkpoint must be fresh and exclusive-host,
  with no more than one selected suite command and no retry loop.
- Record the exact symbol/test disposition, diff attribution, static outcome,
  retained contracts, deferred test proof, and rollback conditions in the Lane
  R ledger. Roll back/stop if any change broadens beyond the allowlist,
  reintroduces paid-Agent/June Home source, alters Free Home/document/graph/
  meeting/read-aloud behavior, removes Browser haptics or `.paidAgent` policy,
  weakens target/fixture safeguards, or hides a dead Agent tile instead of
  proving its absence.
- **Frozen execution rail after this batch.** The coordinator prompt now stays
  frozen; reread and honor it at continuation boundaries, but do not pause for
  an unchanged hash and do not ask for another prompt addition. Continue
  Lane R by implementing concrete, already-mapped Lane R debts in source-first
  batches of at most five related source/test files, with an intent checkpoint,
  exact diff attribution, static proof, and one batched build/test/runtime
  checkpoint only when it can provide fresh, exclusive evidence. Prioritize
  removing dead paths, fixing direct compiler/test/runtime failures, correctness,
  responsiveness, and product coherence over new audit-only intake documents.
  Do not cross into Lane B, Settings, embeddings/retrieval, or a lifecycle
  repair without an existing completed map and a bounded owner-authorized
  change; keep those as explicitly logged debt. Do not begin the mass commit
  or V2/rebuild early. Once Lane R, Lane B, and serial reconciliation are
  genuinely complete, the existing automatic checkpoint and rebuild activation
  remain mandatory and require no new owner prompt.

### `LR-LIVE-2026-07-16-116` — final dual-track execution protocol; freeze prompt again

- **Final owner coordination steer.** The owner directs that the coordinator
  and the Lane execution worker work concurrently, with no overlapping issue
  ownership, and that the same arrangement automatically apply to Lane B once
  Lane R is genuinely complete. This addition is the one final prompt change
  for that purpose. Freeze this prompt again after reading it: do not wait for
  a new hash, do not solicit a new split, and do not append another prompt
  amendment unless the owner explicitly says **“unfreeze prompt.”** Lane B is
  already authorized to begin immediately after Lane R's real completion; it
  is not waiting for another approval.
- **Use seams, not an arbitrary half-file split.** Each lane operates as two
  non-overlapping workstreams: (1) the coordinator owns cross-cutting
  lifecycle/launch/reopen/window-recovery correctness, workstream sequencing,
  integration readiness, and the fresh checkpoint design; (2) the execution
  worker owns the lane's mapped product/removal/correctness source seams and
  their immediately coupled lane contracts. A workstream is a bounded behavior
  seam, with at most five related files per implementation batch, rather than
  a percentage of the repository. Neither role may modify a file leased to the
  other role, borrow a nearby assertion or helper "for convenience," or claim
  an unleased latent issue.
- **Current Lane R leases.** Until its current receipt is complete, the
  execution worker exclusively owns
  `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` and its
  Lane R receipt for the stale Free App Store test repair specified in 115.
  The coordinator must not edit that test or receipt. The coordinator
  exclusively owns the bounded duplicate-Home-window lifecycle seam in
  `Epistemos/App/EpistemosApp.swift` and only a future focused lifecycle proof
  explicitly leased with it; the execution worker must not edit either. Its
  existing mandate is to eliminate competing fallback scheduling and duplicate
  delayed probes without changing product routes, then defer the single fresh
  exclusive runtime/test checkpoint to the shared batch boundary. Other
  already-mapped Lane R debts may be claimed only after their file lease is
  written, never by silently expanding either current seam.
- **Lease handshake and handoff.** Before either role changes a new batch, add
  a short record to the existing Lane R ledger: owner, behavior/problem,
  exact file allowlist, protected neighbor files, intended positive and
  negative proof, deferred verification debt, and rollback condition. A lease
  lasts only for that batch and ends with a diff-attributed receipt. If an
  issue crosses both seams, the coordinator first decomposes it into ordered
  sub-seams; if it cannot be decomposed safely, pause that issue and work a
  different mapped debt rather than concurrently touching the same source.
  The coordinator reconciles completed receipts serially and may then assign
  the next non-overlapping pair. This is execution coordination, not renewed
  audit intake or a reason to wait on an unchanged prompt.
- **Verification rhythm.** Both roles prioritize concrete implementation and
  corrective code over repeated builds. Each role performs local parse,
  compile/static boundary, exact-diff, and whitespace evidence for its own
  batch; the coordinator aggregates independent completed batches into one
  fresh, exclusive-host build/test/runtime checkpoint when that checkpoint
  can prove both seams. Never run two competing broad builds, use retries to
  hide an intermittent result, or call a stale checkpoint evidence for a later
  batch. A failed proof returns only the owning seam to implementation.
- **Lane transition.** Do not start Lane B while any Lane R lease, failure,
  unreviewed diff, or stated Lane R acceptance condition remains open. When
  Lane R is genuinely complete, automatically establish the same two-track
  lease table for Lane B from its existing map: coordinator-owned
  cross-cutting/integration seam and worker-owned Lane B product seam, with
  disjoint file allowlists and one serial reconciliation checkpoint. After
  both lanes and their serial reconciliation are genuinely complete, create
  the authorized clean checkpoint and automatically activate the V2 simulated
  rebuild exactly as already directed. Do not ask the owner to reprompt for
  Lane B, the checkpoint, or the rebuild.

### `LR-LIVE-2026-07-16-117` — final Lane B directive: Workspace Palette, embedded Canonical Graph, durable vault provenance, and complete Home-stack retirement

- **Authority and finality.** The owner has explicitly authorized this final
  Lane B amendment: “if its good then finalzie this directive as part of lane
  b now. make sure no nuance is lost please ... all of this happens
  automtically dont wait for me ... we leave with no dead code.” This addition
  incorporates and finalizes the prior Workspace Palette, graph, linking,
  Epdoc, menu-bar, provenance, and Home-removal direction. It is the final
  prompt amendment unless the owner explicitly says **“unfreeze prompt.”**
  It does not start Lane B early: Lane R must still reach genuine serial
  readiness first. Once that is true, begin Lane B automatically under the
  two-track seam protocol in 116; do not ask for another prompt, split,
  checkpoint, rebuild authorization, or approval to continue mapped work.
- **Resolution of the graph contradiction — this supersedes every older
  Hologram-mechanics instruction.** There is one durable Canonical Graph and
  one graph interaction/physics ontology: the current embedded/Home graph's
  immediate, natural behavior, including visible node entrance/fly-in and
  settling motion. The old Hologram panel's blur, transparent/glass material,
  border, depth, and compact floating visual language may be reused as
  *presentation only*. Do not retain, revive, or copy its delayed-open,
  warm-engine, panel-only lifecycle, separate engine ownership, renderer
  reset, or other mechanics merely because they are visually glassy. In
  particular, wording that says the Palette must embed the “actual existing
  Hologram/Metal graph experience” is superseded by this directive: extract
  and share the embedded graph interaction/lifecycle semantics, then render
  them with the Palette's glass visual treatment.
- **Do not mount the two legacy hosts side by side.** Current legacy hosts are
  intentionally mutually exclusive and each creates a `MetalGraphNSView` /
  engine while `GraphState` exposes a single engine handle. Lane B must first
  replace that host coupling with one canonical store plus testable,
  independently mounted Graph View Sessions and per-session renderer handles
  or equivalent safe ownership. The Palette and note/multitask hosts must then
  be two views of the same graph—not two renderer products, two global
  `GraphState` singletons, two node/edge databases, two physics ontologies, or
  a screenshot/minimap/fake mini graph. Do not claim concurrent hosts work
  merely because the old destinations can be toggled between.

#### Workspace Palette — one compact native app-level control surface

- Replace the standalone Home window with exactly one persistent native macOS
  companion window named **Workspace Palette**, separate from document and
  multitask/tabbed workspaces:

  ```text
  WORKSPACE PALETTE
  [ Now | Notes | Graph | Settings ]

  MULTITASK WORKSPACES
  [ Note | Epdoc | Graph View | Editor | Research | … ]
  ```

- It has exactly one instance; can be hide/shown; restores its chosen size,
  position, and selected section honestly; is not always-on-top by default;
  defaults several deliberate notches wider than the present Notes Sidebar
  while remaining much smaller than the former Home window; launches compact;
  and is generously resizable up to practical screen constraints rather than
  artificially capped at a cramped sidebar width. It must never automatically
  launch at Home-window or full-screen-dashboard scale.
- Preserve the existing Notes Sidebar family rather than making a generic
  settings window: audit and extract its actual glass blur/material, layered
  depth, borders, pixel/dither texture where present, header/search chrome,
  hover behavior, and compact native-Mac character into shared primitives.
  Graph, Now, Notes, command results, cards, and Settings must respond
  gracefully at compact and expanded Palette widths. Do not flatten it into a
  split view, white panel, dashboard, or fake liquid-glass effect.
- **Now:** move the greeting animation into a centered, real visual moment
  here; preserve the useful shortcuts, quick actions, and Command Palette
  access that Home provided. Show a truthful live list of actual Epistemos
  workspace/windows—title, surface type, relevant current context, and a
  focus/reveal action—not static cards. Allow durable in-app aliases for
  existing workspace windows through the Command Center. Alias invocation
  focuses/reveals the existing window; collisions, persistence, rename,
  closed/missing targets, and duplicate prevention must be safe. Preserve
  existing shortcuts and Command Palette behavior without Accessibility
  permission or global system hotkeys. Respect Reduce Motion, occlusion, and
  performance; no unbounded decorative animation.
- **Notes:** host the real existing `NotesSidebar` as this section. Reuse its
  vault/folder tree, search, note actions, deletion safeguards, performance
  protections, and context menus—never a second notes-browser
  implementation. Opening a note or graph must not hide the Palette unless
  the user explicitly hides it. Add Folder Graph creation to the existing
  folder context menu.
- **Graph:** default to All Graph/Canonical Graph and host the real shared
  graph product with the embedded mechanics above and Palette glass
  presentation. It must include real controls, search, selection, inspector,
  and movement actions; no separate visual-system fork.
- **Settings:** place global appearance, vault, privacy, integration, and
  other app-wide settings here. Settings are not document tabs. Contextual
  note/graph controls remain with the active workspace or inspector.

#### One Canonical Graph, many explicit view sessions

- Separate these concepts in code, persistence, tests, and UI:
  1. **Canonical Graph:** real vault notes, entities, tags, relationships, and
     canonical metadata.
  2. **Saved Graph Definition:** a durable named recipe for viewing that
     canonical graph.
  3. **Graph View Session:** one mounted Palette/tab/window instance with
     local visual state.
- A definition may include title; graph-view labels/categories distinct from
  note tags; whole-vault/folder/directory scope; include-descendants choice;
  note-tag filters; keyword/query rules; manually pinned nodes; connection or
  boundary rules; and an optional saved layout. Session-local state includes
  camera, zoom, selection, filters, query, visible projection, and local
  layout/pins. It must never leak unexpectedly into another session.
- Canonical edits—creating a node/entity, editing a real relationship,
  applying a real note tag, or editing canonical metadata—propagate to every
  relevant session. View-only actions—hide from this view, filter, selection,
  zoom, local layout/pins—remain local until explicitly saved. “Hide from this
  graph” never deletes or hides data from the vault.
- The Palette exposes All Graph, New Graph, Saved Graphs, and Recent/Open
  Graph Views. Support explicit **Open in Multitask**, **Return/Move to
  Palette**, **Reveal Existing View**, **New Graph View**, and **Duplicate
  View** actions. Moving preserves a session's local state; if a view is
  already open elsewhere, show that truthfully rather than silently creating a
  conflicting copy.
- Right-click folder → **Open Folder Graph**. It scopes to the stable folder
  identity and descendants, begins temporary, can open as a real graph
  workspace/tab or detached graph window, can be explicitly saved to Palette,
  handles deleted source folders honestly, and offers **Folder only** versus
  **Include connected context**. Connected context reveals boundary
  connections without pretending the scoped set has no external relations.

#### Live graph behavior and performance

- Ordinary mutations—node, relationship, tag, Epdoc child, or equivalent
  canonical change—must update the Canonical Graph via minimal diffs at a safe
  render boundary, animate new visible nodes naturally into the existing
  motion, preserve camera/selection/physics, and persist without blocking the
  frame loop. Reduce Motion changes animation, not correctness or timely
  state propagation.
- Do not route ordinary mutation through `requestGraphRebuild()`, full
  structural rebuild, engine clear, renderer recreation, global recommit,
  flash, freeze, or camera reset. Full rebuild is for initial load, explicit
  recovery, or demonstrated structurally incompatible fallback only. Every
  such fallback requires an honest reason and state recovery path.
- Audit and improve the existing incremental `GraphStore` / graph-state
  mutation queues. Avoid per-frame allocations, hidden polling, and expensive
  render/main-thread work. Pause only an individual occluded/hidden graph
  surface, never every mounted graph because another view changes state.
  Add instrumentation and tests for repeated node/edge creation proving no
  ordinary full-rebuild path or visual reset, plus manual runtime evidence at
  normal and expanded Palette widths, light/dark, Reduce Motion, and
  occlusion.

#### Direct linking plus contextual Shadow quick links

- Retain Shadow IR, contextual Shadow, and semantic suggestions; do not
  replace, hide, or make them graph authority. Add one shared native
  Link/Relationship Composer used by canonical wikilinks, editors, note
  picker, backlinks, graph, inspector, and Epdoc. Never copy/paste separate
  linking logic per editor.
- Preserve and harden the direct, in-process local embedding/hybrid retrieval
  spine that makes Free search genuinely effective. Do not delete, fake, or
  silently degrade semantic retrieval while removing paid generation/agent
  routes; effectiveness is more important than choosing a smaller model, but
  any retained embedding activation must remain MAS-safe, local/private,
  cancellable, privacy-preserving, and explicitly readiness-proven rather than
  a provider, cloud, server, subprocess, or hidden generation backdoor.
- On `[[` or an explicit Link action, users can search/select notes, folders,
  entities, and eligible targets; create normal wikilinks or new linked notes;
  create/edit a real typed graph relationship; inspect links/backlinks/related
  items; apply real tags; and reveal relevant graph context. Type-ahead must
  be responsive, debounced, cancellable, privacy-safe, and must not rebuild
  the graph on every keystroke. Audit all real editor surfaces before claiming
  coverage.
- Add a calm **Quick Link Suggestions** layer to contextual Shadow. Ground
  every suggestion in a real candidate note/entity/tag and identify both
  target and proposed action (for example link, typed relationship, tag,
  linked note, or graph reveal). It complements `[[` and the shared composer;
  it is bounded, deduplicated, debounced, cancellable, inexpensive, readily
  dismissed, and never nags repeatedly after rejection. Acceptance is always
  explicit: it must never silently create links, tags, nodes, edges, or graph
  views. Accepted changes use the same canonical mutation path as manual
  linking and update graph sessions incrementally without reset.
- Upgrade selected-node inspector controls to open source, inspect
  connections, create/manage links, choose relationship type, manage real
  tags, pin/hide locally, and reveal context, retaining confirmations for
  destructive actions.

#### Epdoc is a real durable notebook workspace

- Audit Epdoc package/content envelope, manifest, editor bridge, document,
  graph projector, capability policy, source-of-truth modes, fidelity
  disclosures, and tests before changing it. Implement a real parent
  workspace—not a display-only tab strip, placeholder manifest, or missing
  Sheet/Chat reference—with:

  ```text
  [ Epdoc header + Epdoc controls ]
  [ Pinned Cards ]
  [ Main Document or active child-document content ]
  [ Main Document | Child Note | Child Notebook | + ]
  ```

- Main Document is always first, never closable while its root is open,
  restored after reopen, and retains editor state while children are selected.
  Child Documents and Child Notebooks are persistent content with stable IDs,
  titles/content, real parent/child ownership, safe save/reopen, rename,
  deletion, move/reparent, source-of-truth/compatibility preservation, and no
  lost unsaved parent/child edits on tab change. Ownership is a safe acyclic
  tree: one real owner per child, breadcrumbs/return navigation, safe cascade
  behavior, and a clear distinction between ownership and external alias.
- Use a restrained native material/glass bottom tab strip; do not fake an
  expensive liquid-glass effect or mount full editors for inactive child tabs.
- Pinned Cards are live durable handles to direct child documents, not copies.
  Pinning controls presentation/order only. Show truthful bounded information
  (title, kind, icon/status/tag, bounded preview, open state) without mounting
  a full editor in every card. Provide compact card/inspector controls for
  open embedded/dedicated workspace, pin/unpin, rename/reorder, new child
  document/notebook, link existing document, relationship/tag actions,
  safe move/reparent, remove-from-parent where supported, and confirmed
  permanent deletion.
- Header controls include New Child Document, New Child Notebook, Link
  Existing Document, Pinned Card management, Canonical Graph access,
  relationships/tags, and hierarchy search/navigation. Reuse the shared
  relationship composer.
- A root Epdoc is a first-class Canonical Graph node: larger than ordinary
  note nodes, gold/yellow rather than red, recognizable by symbol/shape as
  well as color, accessible in light/dark and non-color-only contexts, and
  actionable in the graph inspector. Use durable semantic metadata—not a
  title heuristic or local overlay. All Graph shows one prominent root by
  default; children are revealed explicitly through hierarchy/Graph View, not
  automatically duplicated as top-level clutter. All Epdoc mutation uses the
  incremental graph path.

#### Durable, user-owned vault provenance

- Every durable user-created or user-edited artifact is the user's file, not
  an account-bound or opaque app-private record. This includes Markdown and
  JSON plus saved graph definitions, aliases, relationships, canonical
  metadata, Epdoc manifests/content/child ownership, pinned-card data, and
  every other persisted artifact that affects user-visible canonical behavior.
  Each must have a dedicated, inspectable, stable-identity file in the selected
  vault; safe atomic write/rename/delete behavior; honest migration and
  compatibility disclosure; portable reopen behavior; and no sign-in
  dependency.
- Before implementation, map every current JSON, defaults, database, cache,
  manifest, and file path. Distinguish canonical/provenance-bearing vault
  records (which survive app reinstall and are user-readable/portable) from
  genuinely ephemeral unsaved per-view runtime state such as an in-progress
  camera drag. App-local machine presentation preferences may not become a
  hidden canonical data authority or a sign-in requirement. Do not silently
  keep any durable user graph/Epdoc/alias/metadata JSON inside the app simply
  because a native UI happens to own its editor.

#### Total Home-stack retirement and useful menu-bar identity

- Do not merely hide, gate, or leave a compatibility shell for Home. First
  create a semantic removal/rehome map for every Home-owned route, identity,
  window, presenter, fallback/reopen path, landing/editor stack, Home document
  router, Home graph command, status-bar action, `RootView`, `EpistemosApp`,
  `HomeWindowIdentity`, menu item, restoration key, asset, test/fixture, and
  documentation reference. Rehome each real capability to Palette or a true
  multitask workspace; then delete every genuinely obsolete producer,
  consumer, resource, branch, test premise, and dead/decorative code. Normal
  user flows must never surface a standalone Home window. The greeting belongs
  in Palette Now. Semantic caller/callee/target/resource scans—not absence of
  a visible button—prove no dead Home stack remains.
- Audit StatusBar, startup wiring, utility panels, assets, and tests. Replace
  obsolete Home/book-oriented menu actions with useful real actions: Show
  Workspace Palette; show a Palette section; New Note; Open Command Center;
  Show Canonical Graph; focus/reveal supported active workspace; New Embedded
  Note only for an active Epdoc parent; Quick Capture only if real; Settings;
  and Quit. Actions must have real implementations and truthful dynamic
  enabled state. Do not make a menu-bar-only app or remove ordinary Dock/window
  behavior.
- Create a proper Epistemos **E** identity: full app icon and monochrome,
  template-safe MenuBarIcon are distinct contexts. Use the existing asset
  pipeline, not a fragile text glyph, and preserve unrelated dirty asset work.

#### Required engineering process, acceptance, and automatic continuation

- Before a Lane B mutation, create/update its intent ledger; read target
  source/callers/tests/fixtures/build scripts/local canon; inspect the dirty
  worktree; write focused failing tests; and use official Apple documentation
  for current AppKit/windowing/App Store choices. At minimum inspect Notes
  Sidebar, UtilityWindowManager, RootView, EpistemosApp, Home routing,
  StatusBar, NoteWindowManager, CommandRegistry, both graph hosts,
  GraphState/Store/Builder/Metal renderer/tests, Epdoc surfaces, linking and
  editor/backlink tests, and every persistence route named above.
- Use small, behavior-seam batches of at most five related files. Prioritize
  careful coding over repeated broad builds, but keep a verification-debt
  ledger with touched files, risks, expected proof, and checkpoint trigger.
  Each batch gets exact diff attribution, focused static/parse tests, and
  narrow behavioral evidence; serially run broader build/test/runtime and UI
  evidence at a clean shared checkpoint. Never use retries or a stale result
  to mask a failure, and never run competing Xcode builds.
- Completion evidence must prove: one Palette and honest restoration; Notes
  parity and non-disappearance; no standalone Home route or dead stack; live
  workspace/alias behavior; one canonical graph with independent session
  state, Folder/Saved Graph semantics, no-delete hiding, and live incremental
  updates; shared composer/Quick Link coverage; Epdoc persistence, hierarchy,
  cards, and graph identity; vault-file provenance; E asset/menu action
  resolution; and visual/runtime behavior across widths, themes, motion, and
  occlusion. Inspect all diffs, run focused then broader proof, manually
  exercise complete flows, and invoke `deep-hardening-loop`; report changed
  files, test/manual/runtime evidence, remaining limitations, and unproven
  areas without converting absent evidence into a claim.
- The coordinator and execution worker use the same disjoint seam leases for
  Lane B as required by 116. Complete every Lane R lease, acceptance condition,
  receipt reconciliation, and serial verification first. Then execute Lane B
  automatically, save the clean attributable checkpoint automatically once
  both lanes and serial reconciliation genuinely pass, and automatically begin
  the whole-app V2 simulated rebuild. Neither agent waits for an unchanged
  prompt or another owner message. The automatic transition never authorizes
  a fake completion, a broad unexplained commit, a build/test bypass, or
  preservation of dead code.

## Automatic successor phase — whole-app counterfactual rebuild

### `LR-LIVE-2026-07-15-039`, as amended by addition 055 — reconcile and deeply rebuild the complete app after the verified checkpoint

- New owner steer, exact excerpts: “as if i was completely rebuilding the app,”
  “every part of the app should be deeply upgraded perfected and fixed,” “the
  final phase should be a mass commit before this phase,” and “the purpose is
  fixig things that otherwise would never be fixed or aduitted becase agents
  never go as deep.” Interpret this as a counterfactual/simulated rebuild: once
  the current scoped removal, Lane B, and serial integration work is complete,
  reassess the entire product from first principles as though Epistemos were
  being designed and built again with its present owner intent and accumulated
  evidence. This is not permission for shallow polish, a wrapper, a token pass,
  or a report that leaves known defects in place.
- Activation boundary: this phase intentionally crosses Lane R, Lane B,
  Settings, UI, storage, packages, build/release, extensions, and every other
  current ownership boundary. The active Lane R worker must not cross those
  boundaries early or use the future phase to weaken current fail-closed work.
  Lane R finishes its owned transaction and ledger first; all current lanes and
  serial-integration handoffs must be reconciled into an honest baseline. Once
  addition 055's checkpoint SHA is recorded, the owner has already authorized
  automatic activation of the new app-wide goal/execution phase: do not wait for
  another prompt, approval, or manual reactivation before beginning the atlas
  and first vertical rebuild slice.
- Pre-rebuild checkpoint (“mass commit”): preserve the owner's requested clean
  rollback point, but never run `git add -A` or commit an unexplained dirty
  multi-owner worktree. First attribute every changed/untracked file, resolve
  overlaps, remove generated/transient outputs, reconcile protected-lane
  handoffs, inspect the complete diff, and attach the exact build/test/runtime/
  artifact/debt receipt. Only then create the integration checkpoint commit now
  explicitly authorized by addition 055 containing the intended complete baseline;
  record branch, parent, tree/commit SHA, included workstreams, remaining debt,
  and rollback procedure. If unrelated or unverified changes cannot be safely
  separated, keep reconciling or record a real blocker rather than manufacturing
  the snapshot or requesting the already-granted transition approval again.
- Rebuild atlas before mutation: inventory every app target, extension, package,
  executable/library, source/resource directory, route/window/sheet/menu,
  user journey, UI component and design token, command/shortcut/intent,
  composition root/service/background task, data model/schema/store/cache/index,
  import/export/sync/migration/compatibility path, FFI/ABI, dependency/build
  script, entitlement/permission/network boundary, test/release/diagnostic seam,
  and persisted defaults/restoration key. Produce a navigable system map linking
  product capability → route/UI → state/owner → service/task → storage/index →
  dependency/artifact → tests/observability. There may be no “miscellaneous,”
  unowned, or unreviewed bucket.
- Visualized rebuild: capture the current route/window/state inventory with
  screenshots and reproducible flows, plus component hierarchy, navigation,
  state/dataflow, lifecycle/concurrency, storage/migration, and build/dependency
  diagrams where they materially clarify the system. For every surface and
  subsystem, write the counterfactual design that would be chosen today, then
  classify the current implementation as retain, simplify, split, consolidate,
  replace, or remove. Connect duplicated/disconnected maps and sources of truth
  rather than documenting their fragmentation as permanent architecture.
- Question everything with evidence: re-read owner/product canon and current
  implementation before deciding; search semantically for callers, duplicate
  truths, dead facades, hidden branches, stale terminology, and contradictory
  tests; research current official framework/platform guidance and primary
  sources; and use measured product/runtime evidence. Package presence,
  compilation, an old comment, or a single happy-path test is not justification
  to retain a design. Conversely, do not replace a mature subsystem because a
  rewrite sounds cleaner without migration, parity, risk, and rollback proof.
- Quality bar for every mapped slice: explicitly audit and then improve product
  coherence, information architecture, visual hierarchy, interaction quality,
  accessibility, localization, keyboard/focus/input behavior, correctness,
  boundary/adversarial cases, failure/recovery/offline behavior, data
  integrity/migrations, concurrency/cancellation/lifecycle, memory/CPU/energy/
  launch/typing latency, privacy/security/permissions/networking, observability,
  diagnostics, testability, dependency hygiene, and release/artifact truth.
  “Perfected” means the highest practical, measurable acceptance bar with known
  debt named; never claim literal perfection or zero defects without evidence.
- Deep rework, not audit-only output: score every slice by user harm, defect and
  glitch density, architectural fragmentation, state duplication, performance,
  privacy/security, accessibility, maintainability, and evidence weakness.
  The worst-scoring/highest-leverage slices must receive real route/component/
  state/service/storage behavior redesign and implementation—not just findings,
  TODOs, renamed wrappers, styling, or more guards around a broken structure.
  Retained strong slices still receive adversarial proof and integration checks.
- V2-quality product outcome: the rebuilt app must feel deliberately redesigned
  as one coherent product, not like patched V1 surfaces sharing a binary. Routes,
  terminology, visual system, interaction patterns, state transitions, errors,
  recovery, search, storage, background work, and performance budgets must agree
  across journeys. Make material route/component/state/service/storage changes
  wherever evidence shows the current design is low quality or fragmented. A
  build-number/version-string bump is neither required nor proof of this outcome.
- Execute as vertical rebuild slices, not a blind big-bang rewrite. Each slice
  must begin with its owner-intent checkpoint and current/replacement maps, then
  add fail-first behavior and migration fixtures, implement surgically or behind
  an explicit replacement boundary, exercise real mounted user flows, inspect
  UI evidence where applicable, measure declared budgets, reconcile adjacent
  maps, and remove the superseded path only after parity/data safety. Keep an
  integration/verification-debt ledger and a rollback point for every slice;
  no whole-file or whole-subsystem replacement without ownership, blast radius,
  tests, data migration, and rollback proof.
- Minimum cross-app journeys: exercise clean install and upgrade with historical
  data; launch/relaunch/window restoration; vault create/open/switch/move;
  import/capture/create/edit/save/undo/redo/search/open/insert/copy/export/delete/
  recover; large and corrupt input; offline/denied permission/low memory/cancel/
  crash/retry; multiple windows and rapid navigation; keyboard, VoiceOver,
  reduced motion, contrast, localization, and native input; sync/conflict and
  stale derived-state recovery; extension/widget/shortcut/intents; and exact
  Debug/Release/App Store resource and dependency boundaries. Add product-
  specific flows discovered by the atlas rather than treating this as exhaustive.
- Required skills/evidence for the later goal: use the read-first engineering
  protocol for every slice; browser/Playwright/computer-use/screenshot evidence
  for mounted UI flows; strict maintainability review for giant files,
  abstraction and condition growth; security/threat/release skills where risk
  warrants them; and the deep-hardening loop after each apparent completion.
  Research receipts must cite exact current primary sources and clearly separate
  source/static, mocked, built, runtime, visual, manual, and artifact evidence.
- Completion is app-wide reconciliation, not the end of an audit document. Every
  atlas node must have an explicit disposition, owner/source of truth, quality
  bar, implementation/evidence receipt, and remaining debt; every disconnected
  or duplicate map must be unified or deliberately isolated with a proven
  boundary; all highest-priority slices must be rebuilt and revalidated in the
  mounted app. Continue discovering, implementing, retesting, and hardening
  until the owner explicitly stops/redirects or a real blocker prevents useful
  progress. Do not mark this final phase complete merely because a plan exists,
  one global build passes, or the most visible screens look improved.

### `OWNER-OVERRIDE-2026-07-16-UNBLOCKED` — autonomous cross-lane continuation

- **Superseding authority.** The owner has now said: “its unblocked
  indefinitaely please do not stop again to ask for anythign jusdt continue yes
  u can do what u need to do. /goal resume”. This supersedes every earlier
  freeze, pause-for-direction, and Lane R-before-Lane B sequencing instruction
  in this prompt **only where that instruction prevents necessary, evidence-led
  work from continuing now.** Do not wait for another prompt hash, a lane
  transition approval, an ownership split, a checkpoint approval, or a
  reactivation request. Continue autonomously until the owner explicitly stops
  or redirects the work, or a real blocker prevents useful progress.
- **Concurrent lanes without overlap.** Lane B is authorized to begin now,
  even while Lane R verification debt remains, whenever it can take a separate
  source/test/project seam or resolve a documented cross-lane blocker. Preserve
  disjoint leases, file allowlists, exact diff attribution, rollback conditions,
  and serial receipt reconciliation. Never have two workers modify the same
  file or unilaterally borrow a protected neighbor. A verified cross-lane
  compiler/runtime blocker is a reason to map and sequence the smallest repair,
  not a reason to restore retired capability or to pause all work.
- **Unchanged product and removal boundaries.** This override does not retain
  or reintroduce paid Agent/June, MCP/remote-tool/provider/runtime surfaces,
  Home-window routes, second graph databases, compatibility shims, silent
  data-loss paths, or other previously removed Free-incompatible behavior. Keep
  the owner’s vault-first provenance requirement: durable user-authored and
  user-meaningful JSON/metadata/artifacts are inspectable files in the selected
  user vault; derived indexes/caches remain rebuildable, vault-bound, and never
  masquerade as the sole source of truth.
- **Required Palette/graph interpretation.** The old complete Home-window
  stack is to be rehomed or removed with no normal-user dead routes. The one
  Canonical Graph keeps the existing embedded graph’s interaction ontology and
  live incremental behavior in both its note-workspace embedding and Workspace
  Palette mounting; the Palette may retain the old Hologram’s glass/material
  presentation, but not its separate lifecycle, engine, data model, or weaker
  mechanics. No graph mutation may fall back to refresh/freeze/recreate merely
  to simplify the migration. The authoritative nuance is preserved in
  `docs/handoffs/WORKSPACE_PALETTE_EPDOC_OWNER_CONVERSATION_TRANSCRIPT_2026_07_15.md`
  (SHA-256 `1fb7dd3bce9d7d56f8f362bb317b6615d30b21807d6c8c12c2397ecb45000285`).
- **Execution discipline remains.** Work in bounded implementation batches
  with an intent checkpoint, focused fail-first proof where behavior changes,
  preserved unrelated dirty work, source/static proof before batched
  build/test/runtime evidence, and an explicit verification-debt receipt. Favor
  coding and fixing over audit-only churn, but never substitute speed for
  evidence, user-data safety, MAS constraints, or a truthful handoff. The
  authorized mass checkpoint and simulated rebuild still activate
  automatically after the required attributable evidence is genuinely ready;
  do not manufacture a commit from an unexplained multi-owner worktree.
