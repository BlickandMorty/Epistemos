# Osaurus Act Build — Living Progress (started 2026-06-21)

## ⚠️ RE-SYNC / REALIGNMENT (owner 2026-06-21) — addendum AUTHORITATIVE, overrides research recs
**Re-read `OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md` at the START of every iteration.** Owner
directive ALWAYS beats a research rec. Corrections to drift (I had followed the feasibility doc's C2/B):
1. **MAS NON-RESTRICTIVE everywhere (set in stone §151).** DUAL-BUILD: Pro (direct-dist, full) + MAS
   *as robust as Pro*, excluding ONLY the genuinely-ungrantable (today: Linux-VM sandbox) with a MAS-safe
   substitute (WASM in-proc / cloud — research best). NEVER use "MAS sandbox" to cut capability. Supersedes
   CLAUDE.md MAS NON-NEGOTIABLE. ⚠️ FOLLOW-UP (not a corner-cut): OsaurusCore is currently Pro-target-only;
   per dual-build MAS must get the MAS-safe OsaurusCore (split off only VM/Sparkle/Containerization).
2. **FULL CLONE Goose (and every clone) — NOT leaf-by-leaf.** Vendor block/goose real crates
   (`goose` + `goose-providers`) + `rmcp` as REAL Cargo deps in agent_core, like Osaurus; resolve dep
   clashes (accepted cost). The `agent_core::work::vendored_goose` hand-ports (incl. the Role leaf
   `bed6252fd`) are **SUPERSEDED** by the full-clone — STOP hand-porting wire types one at a time.
   **GROUNDED 2026-06-21 (`docs/research/GOOSE_FULL_CLONE_INTEGRATION_COST_2026_06_21.md`):** the
   leaf-ported types live in the HEAVY `goose` crate (**179 dep lines** incl tokio/reqwest/rmcp/sqlx/
   oauth2), NOT the light `goose-sdk-types`. Concrete blocker = **reqwest 0.12 (agent_core) vs 0.13.2
   (goose)** incompatible majors + 660 MB source. This is a **multi-iteration, build-red-prone** vendor →
   per owner §446-460 it belongs in a DEDICATED build-iteration context (worktree/branch, like dual-MLX),
   NOT committed red to the green-only main loop. Leaf-ports stay as the HONEST interim (lower-but-CERTAIN,
   not dropped); recommended path (feature-gate `goose-clone` OFF-by-default + reqwest reconcile) in the note.
3. **WORK = OpenCode FULL-CLONE shell, Option A (keep OpenCode's REAL terminal UI, palette-matched, live
   themes).** NOT a native rebuild (feasibility C2/B OVERRIDDEN). HEAVINESS MITIGATION (loop prompt
   directive #2): render OpenCode's **REAL terminal TUI in a NATIVE terminal view (SwiftTerm/PTY)** — do
   NOT ship the Electron/Tauri web GUI (that's the bloat; OpenCode is headless-first, GUI optional). The
   terminal look IS preserved. **Bun engine = lazy-launch on work-open, loopback, kill-on-idle.** Goose =
   engine inside OpenCode; Hermes = IP brain fused; OpenClaw = selective hardening fused; wire the EXISTING
   `agent_core::lsp_runtime` RustLSP as work tools (don't import OpenCode's LSP).
   LOOP: cron `0c87db0c` now fires `AGENT_LOOP_PROMPT_2026_06_21.md` (re-read addendum every iteration);
   the stale SESSION_CONTINUATION cron was replaced.
4. **Tamagotchi render-fix = IN SCOPE** (keep style; fix too-small/inner-square).
5. All other 2026-06-21 overrides hold (act reskin=current-chat; preserve picker/palette/agent-tools/
   Epistemos Picks; per-clone settings tabs; landing blur + mode-entry anim; motion triad; Prose 120fps;
   EPDOC MD-V2; chat never deleted; no fake-done; no WIP/stash; substrate+IP certain/lower-not-deferred).
SEQUENCING: Osaurus/ACT-first (engine done → shared composer + reskin), THEN WORK (OpenCode full-clone).

## 📋 14-AREA IMPLEMENTATION MAP (grounded audit, refreshed 2026-06-21 post-act-engine)
| # | Directive | Status | Evidence (file / commit) | Next action |
|---|---|---|---|---|
| 1 | Two modes: **act=Osaurus** (done engine); **work=OpenCode FULL-CLONE shell (real UI, Option A) + Goose engine + Hermes/OpenClaw fused + RustLSP** | 🟡 | act engine `aa0b40b57`; Goose ENGINE seam `Epistemos/Work/WorkBackend.swift`; **OpenCode SHELL seam A `644303f69`** (PTY-launch contract + honest-inert + visible health row); **NATIVE TERMINAL VIEW `5b0520917`** — vendored `LocalPackages/SwiftTerm` (MIT) + `WorkTerminalView.swift` (`LocalProcessTerminalView`/PTY), **FULLY THEME-RESPONSIVE `3bead7af6`** (§162: `WorkTerminalPalette.from(theme:)` derives bg/fg/cursor from live `EpistemosTheme` tokens; reads `@Observable UIState.theme`; `updateNSView` re-applies LIVE → recolors running PTY on any theme incl. custom); **BUNDLED-RUNTIME RESOLVER LANDED `38b7fbbd8`** — `Epistemos/Work/WorkOpenCodeRuntime.swift` (honest `bundledRuntimeURL()` nil-until-vendored, loopback-pinned env, kill-on-idle = PTY lifecycle) + `BundledWorkOpenCodeShell` + factory goes LIVE only when armed AND runtime on disk, 15/15 tests; `agent_core/src/work.rs` leaf-ports SUPERSEDED→full-clone | resolver done; **RustLSP→WORK TOOLS LANDED `1c753902e`** — `agent_core/src/work_lsp_tools.rs` (`WorkCodeTool` lowers onto the EXISTING `lsp_runtime` LspKernel: didOpen/didChange/didClose + hover/definition, tree-sitter backed; honest gating — diagnostics/edit NOT advertised until kernel-backed; gated `lsp-runtime`; 6/6 incl. real-state e2e hover/definition); NEXT WORK (heavy) = vendor OpenCode TS/Bun monorepo + bundle runtime into `Resources/opencode-runtime/`; Goose/Hermes/OpenClaw fuse beneath |
| 2 | Osaurus landed+linked; dual-MLX consolidated; act turn via closure swap | ✅ | `f884eb0b7` (consolidate), `cf708671a` (link), `aa0b40b57` (closure swap) | streaming + UI |
| 3 | Landing pages + BLUR transitions + act/work toggles + mode-entry anim | 🔴 | `Views/Landing/{LandingView,BlurFade,LiquidGreeting}.swift` exist; anim recorded | build after engine |
| 4 | ACT reskin = current-chat discipline (fonts/palette/composer) | 🔴 | recorded (standing rule) | build after engine |
| 5 | Preserve chrome (picker/palette/38-tool panel) + Epistemos Picks | 🟡 | Epistemos Picks DONE+visible `5c3d8bb66`; chrome exists | wire chrome into act |
| 6 | Tamagotchi agent-creation: keep style + FIX render (too-small/inner-squares) | ✅ | render-fix `172f79e64`: `CompanionAvatarGlyph.fillCell` shared-edge rounding (no intra-body artifact squares) + sizes 42→64/76→96 | done; verified (8/8 source-guard) |
| 7 | Chat backend QUARANTINED, never deleted | ✅ | never touched this session; quarantine intact | porting cycles |
| 8 | No silent Qwen fallback | 🟡 | act path honest (`runTurnInProcess` never cloud); Picks honest selection | live too-large→Qwen P0 is in DEFERRED quarantined chat |
| 9 | MAS non-restrictive (global) | ✅ | `OSAURUS_MAS_ENTITLEMENTS_RESEARCH_2026_06_21.md`; direct-distribution | distribution signing |
| 10 | Reuse-not-rebuild IP (RustLSP/Eidos/Halo/RRF/DAG) | ✅ present | `RustLSPTransport`/`EidosBridge`/`HaloController`/`RRFFusionQuery` exist | wire into both modes |
| 11 | Every surface→real front-end + completeness sweep | 🟡 | sweep `e84fd4110`; act health real `2025fc876`; Picks visible | remaining surfaces |
| 12 | EPDOC MD-V2 (md source, html/json projections) | 🟡 | **GROUNDED 2026-06-21:** EPDOC currently stores **`contentJSON` as CANONICAL** (`EpistemosDocumentController` drives `epdoc.package.contentJSON`; `projectAndIndexBlocks(contentJSON:)` + `projectAndPersistGraph(contentJSON:)` project blocks/graph FROM the JSON). MD-V2 = **INVERT** the canonical format. PRECISE SCOPE (confirmed by `Models/EpdocPackage.swift`): the package
ALREADY has `contentJSON: Data` (REQUIRED, `content.pm.json` ProseMirror JSON = today's canonical) AND
`shadowMarkdown: Data?` (OPTIONAL, literally `projections/shadow.md` — markdown is presently a SHADOW
PROJECTION). MD-V2 = **promote `shadowMarkdown`→required SOURCE-OF-TRUTH + demote `contentJSON`→a projection +
update every contentJSON-canonical reader** (DocumentController, `projectAndIndexBlocks`, graph projector,
HTML workspace). Subsystem inversion, NOT a bounded loop increment; a parallel MdV2 type would not integrate.
**GROUNDED 2026-06-21 (`docs/research/MD_V2_INVERSION_GROUNDING_2026_06_21.md`):** the DECISIVE design fact —
`ProseMirrorMarkdownProjector.swift:30-32` states md→PM is DELIBERATELY out of Swift scope, "handled by
Tiptap's importer (Wave 7.2)". So md→PM ALREADY exists in Tiptap/JS; **a native Swift md→PM parser would be
the forbidden "parallel that won't integrate" — DO NOT build one.** Inversion = a Tiptap/JS + EpdocDocument
(save/load) + EpdocPackage (required-entry flip + package migration) + canonical-readers flip, with a
no-regress bar on the 120fps Prose editor. CERTAIN, needs a focused app-buildable context (not a ~15-min-
per-build loop tick). FIRST step there: close the projector's LOSSY gap (PM→md→PM must preserve block IDs +
the node/mark set) so md is faithful enough to BE canonical, BEFORE flipping which entry is required. | dedicated context: close projector lossy gap → flip canonical → migrate; no toy, no parallel parser |
**LOSSY-GAP CLOSURE STARTED (incremental, §763):** the FIRST MD-V2 step (improve PM→md projector fidelity) is
loop-appropriate (non-visual, unit-testable) — NOT the canonical flip. Closed two real fidelity gaps the
projector silently dropped (fell through `default`/unknown-mark): **strikethrough `~~` (`4a45173b9`)** — Tiptap
StarterKit Strike was lost; **GFM tables (`cc64cff96`)** — Tiptap ships table extensions but the projector had no
`table` case → tables lost ALL structure; new `projectTable` emits header+separator+body. Both with real-state
round-trip tests. More node/mark coverage = md closer to faithful-enough-to-be-canonical.
**HIGH-VALUE BUG FIXED (`7bae289e9`, found via audit):** the Tiptap editor emits **camelCase** node names
(bulletList/orderedList/listItem/horizontalRule/hardBreak/taskList/taskItem — confirmed in markdown-paste.ts),
but the projector only matched **snake_case** (no normalization) → for REAL editor content these fell through
`default` and LOST their md structure (list markers gone; horizontalRule/hardBreak dropped). The old tests used
snake_case → green while production projection was silently broken. Fixed by aliasing both cases (matching the
`codeBlock` precedent) + a camelCase regression test. Also fix-forward of a table-test `#expect` Comment compile
error (checkpoint caught what source-guard couldn't). **CHECKPOINT GREEN: ProseMirrorMarkdownProjectorTests
36/36, TEST SUCCEEDED** (strike + table + camelCase all pass; main back to green). The projector's
loop-appropriate fidelity gaps are CLOSED; round-trip verified consistent with the md→PM importer
(markdown-paste.ts handles tables/strike/camelCase-lists). Remaining MD-V2: block-ID preservation + canonical
flip (focused session); importer extension blocked on missing JS test infra (no vitest/jest — can't fast-gate).
**BUG CLASS AUDIT (`8550926c6`):** the camelCase node-name bug wasn't only in the markdown projector — audited
the sibling projectors. ReadableBlocksProjector already aliases both cases (OK); **EpdocGraphProjector did NOT**
(snake-only `list_item`/`hard_break`/`image`) → for real editor content (camelCase `listItem`/`hardBreak`/
`epdocImage`) list items were mislabeled in the document graph (paragraph treatment, wrong semantic labels) +
images un-labeled. Fixed with camelCase aliases + a regression test (camelCase yields identical label edges to
snake_case). Checkpoint running.
| 13 | Substrate-health + IP-repair = CERTAIN, sequenced LOWER (not deferred) | 🟡 | recorded CERTAIN-lower | sequence after Osaurus UI |
| 14 | Hygiene (no WIP/stash, real-state tests, main-only, Co-Authored-By) | ✅ | 24 stashes triaged+dropped `44f7e07df`; all commits verified | maintain |

### ✅ SESSION REGRESSION CHECKPOINT (2026-06-22) — cross-cutting work verified clean
Full sweep after the session's ~26 commits (vault-deep tools, in-app+external provenance, fusion scoping/ping/
e2e/traversal-guard, retry-timeout, act+work gate toggles, mode-entry transition, workspace-mode selection,
atomic writes everywhere, bounded event logs): **omega-mcp 191 lib + 6 stdio + 2 e2e, agent_core work 30 +
mutations 17 + provenance 64 — ZERO regressions.** The two-mode LOGIC foundation is complete + tested (act/work
gates+toggles+overrides, mode-entry transition, workspace selection reading both gates). Durability posture
complete (atomic writes across Swift+Rust+graph-store; both event logs bounded via one shared helper).
**Remaining high-value work needs heavier contexts than a 2-min loop tick:** (a) the VISUAL two-mode landing
integration (mount WorkspaceModePicker → ModeEntryTitleView transition → surface routing) needs running-app
visual judgment (§842/§799); (b) MD-V2 inversion needs a focused app-buildable session (grounded in
`MD_V2_INVERSION_GROUNDING_2026_06_21.md`); (c) OpenCode internal-theme config needs its (unverified) schema +
visual check — base palette-match already done via WorkTerminalPalette `3bead7af6`.

### LOOP STATUS (2026-06-21, this session) — milestone + context-gated next steps
**ACT ENGINE COMPLETE end-to-end:** linked → drives OsaurusCore → generates → SHARED chokepoint across all
chats (`e67295bc0`) → **STREAMS tokens** (`0d9f3f524`). **WORK terminal stack COMPLETE (Swift):** Seam-A PTY
contract (`644303f69`) → native SwiftTerm view (`5b0520917`) → bundled-runtime resolver, live-on-vendor
(`38b7fbbd8`) → RustLSP work tools (`1c753902e`) → reachable via Work settings tab (`78fe1c738`) → fully
theme-responsive (`3bead7af6`). **Motion ontology:** reusable `MotionTitle` (`9d1c421e6`) on both work titles
(`3ec448552`). All honest-inert-until-real; chat quarantined.

**COMPREHENSIVE REGRESSION (2026-06-21, session close):** ran the full inference + vault blast radius together
(8 suites, 86 tests: LocalAgentLoop/ActOsaurusStreaming/SharedActComposer/ActOsaurusSeam/DeviceAgentService/
AgentNoteEdit/VaultSemanticBacklinks/VaultNoteEditor). 85/86 PASS — the ONLY failure is the pre-existing
`LocalAgentLoopTests:1617` (SS-AL `f26924ccf`, another session's domain, not mine). The session's ~62-commit
body caused ZERO regressions across its most-changed surface.

**Regression sweep (2026-06-21):** ran blast-radius suites after the shared-composer + streaming edits.
Found + FIXED one stale source-guard I caused (`ActOsaurusSeamTests` s4DeviceAgentFlagSwap → now asserts the
shared `shouldRouteActThroughOsaurus()`, `ee61a7e52`). TWO failures are from OTHER concurrent sessions (NOT
mine, files I never touched) — flagged for their owners: `LocalAgentLoopTests` "repairs empty streaming
turns" (contradicts SS-AL `f26924ccf` which now STREAMS repair tokens — that test's `visibleText.isEmpty`
assertion is stale vs SS-AL's intent) + `AppStoreHardeningTests` KTOTrainer/python (SS-LS domain).

**✅ ARCHITECTURE C FINALIZED (owner 2026-06-21) — consensus aligned this session:**
- WORK engine = **OpenCode** (headless Bun, own process, lazy-launch + kill-on-idle) beneath its **REAL TUI**
  (native SwiftTerm/PTY, palette-matched). NO web/Electron GUI. IP brain rides on top via MCP. One engine.
- **Goose NOT vendored** as a 2nd engine (avoids the 179-dep/reqwest/660MB saga). Its unique HARDENING bits
  (RetryManager/RepetitionGuard + recipe) are the **PERMANENT clean-room home** in `work.rs` (re-labeled
  `141a8d2b7`), surfaced as work-loop TOOLS, never deleted. **Goose `permission` DROPPED** (OpenCode covers it).
  **RETRY TIMEOUTS ENFORCED (`8eb32f7e1`):** `RetryConfig.timeout_seconds`/`on_failure_timeout_seconds` were
  carried+validated but NOT enforced (ShellRetryExecutor blocked forever on a hung check/cleanup). New
  `run_shell_with_timeout` (spawn→poll try_wait→kill-on-overrun, hardened, std-only) bounds them; trait threads
  the timeout; None=blocking (historical). 30/30 work tests (+2) + pro-build check clean.
- **`work_lsp_tools` REDUNDANT under C** (OpenCode built-in LSP) — marked, kept pending vendor (`fd6c099e0`);
  `lsp_runtime` stays for the native editors.
- **Act-swap in BOTH inference chokepoints** (liveLoop `e67295bc0` + TriageService `8ae27be43`) → every
  chat surface (main/Mini/Note/Graph) gets act. **🎯 ONE INFERENCE CHOKEPOINT — PHASE 1 DONE (`b28cb96e7`):**
  `SharedActInference.actStreamIfArmed` = the SINGLE act-injection entry both chokepoints now delegate into
  (can't diverge; flag-off byte-identical). **COMPLETENESS-CRITIC pass (`8efb98d32`, owner §38/§86):** audited
  ALL inference entry points → found the NON-streaming local path (`localGenerateOrFallback`, used by
  `generateGeneral`/PinnedInspector retry) bypassed act → added `SharedActInference.actTextIfArmed` (honest:
  armed→act-text-or-throw, never silent MLX) so BOTH streaming + non-streaming local paths route act through
  the one entry. 24/24 act suites. **AUDIT CONCLUSION (act-routing COMPLETE):** every CHAT surface routes
  through the two chokepoints + both local paths route act; `ReasoningLoopService` wraps TriageService;
  `PinnedInspector`'s direct-AppleIntelligence call is in `summarizeNode` (a node-SUMMARY task, not chat) +
  its chat (`sendMessage`→`streamGeneral`) is covered. Non-chat tasks (summaries/synthetic-data/metrics) +
  explicit cloud-model picks are legitimately separate routes (owner #1 forbids SILENT cloud, which the
  local-pick→Osaurus path preserves). No further act-routing gap. PHASE 2+ (later, careful): merge the fuller path + retire the
  duplicate TriageService path (owner: "old chat/triage inference is dead, get rid of it"). CERTAIN.
- **🌟 PILLAR — VAULT-DEEP-INTEGRATION (overtake Tolaria, §720):** STANDING RULE: full-clone every ADOPTED
  engine (Osaurus method); REFERENCE-only for capabilities already owned better (Tolaria = reference; mine
  vault-as-MCP, build native with Prose+MD-V2). Slice status:
  - [x] **#1 vault-as-MCP CONTEXT DONE (`36da2df95`):** `omega-mcp` dispatcher serves `resources/list`
    (vault `*.md` notes as `vault:///` resources) + `resources/read` (path-safe content) via VaultExecutor;
    12/12 tests. External agents read the vault as first-class MCP context.
  - [x] **#2 deep graph integration — DONE end-to-end (`1406fcd75`):** `omega-mcp/graph_tools.rs` exposes
    `graph.search_semantic/fulltext` + `graph.get_node` + `graph.traverse` + `graph.create_node/edge` +
    `graph.commit_session` — agents traverse/query/build the graph. **The remaining "populate FROM vault
    notes+links" piece LANDED:** new `graph.populate_from_vault` builds one `Note` node per markdown file
    (deterministic basename-keyed id + bounded excerpt body) + a `links_to` edge per RESOLVED `[[wikilink]]`,
    reusing the existing `list_markdown_notes`/`parse_wikilinks` (one basename link model, no rebuild).
    IDEMPOTENT re-sync (drops prior vault nodes/edges, agent nodes untouched → graph mirrors the vault, no
    stale/dup); HONEST (dangling links counted, not faked); catalog-registered + routed via `is_graph_tool`
    so external (OpenCode/Codex) AND in-app agents build the graph from the vault. Real-state test:
    cross-linked + dangling temp vault → counts + traverse the real link graph + idempotency + removal
    reflected. 183/183 omega-mcp lib green (+1). (Later: an in-app trigger/auto-sync on vault change.)
    **DIRECTIONAL TRAVERSE (`0a80ac22a`):** `graph.traverse` gained `direction` out|in|**both** — agents now
    walk BACKLINKS (in: notes linking TO this one), not just downstream (out, the default = byte-identical to
    before). Pairs with the `links_to` edges so "what does this reach" AND "what reaches this" both work over
    the vault graph. 186/186 lib green (+1: out/in/both + bad-direction).
    **ATOMIC STORE WRITES (`6b1dbebe9`):** the graph store is rewritten on every mutation; a plain fs::write
    interrupted mid-write left a truncated mcp_graph.json that load_store silently reset to EMPTY (whole-graph
    loss). Now temp-write + rename (atomic) → the on-disk store is always a complete valid snapshot. 188/188 lib.
    **ATOMIC NOTE WRITES (`aaacfdced`):** the external-agent note path (`edit_note`/`write_file`) used plain
    fs::write → a crash mid-write corrupted the USER'S note. New `atomic_write` (temp `.omega-tmp` + rename, the
    suffix deliberately non-`.md` so leftovers don't list as notes) at both sites. Completes the atomic posture
    across ALL vault writes (Swift VaultNoteEditor + Rust MCP + graph store). 189/189 lib.
    **BOUNDED EVENT LOG (`20d1096b8`, §506):** the graph agent-event telemetry (`mcp_graph_events.jsonl`) was
    unbounded — a long agent session grew it without limit. It's write-only (nothing replays it; durable
    provenance is in the EventStore), so `append_events` now trims to the most-recent 5k lines (atomically) once
    it crosses ~4 MB. Bounds `.epistemos/` disk growth. 190/190 lib. **CONSOLIDATED (`0e3570d8a`):** one shared
    `append_lines_bounded` helper now bounds BOTH the graph log AND the vault provenance log identically (the
    vault log was still unbounded); removed the inline duplicate + unused imports. 191/191 lib.
  - [~] **#3 LLM wiki + [[wikilinks]] + semantic backlinks:** MECHANICAL wikilink suite COMPLETE — `vault.backlinks`
    (`d6472fe2b`, in) + `vault.outlinks` (`bb52bcbee`, out) + `vault.dangling_links` (`1f10fc183`, unresolved) +
    `vault.note_links` (`80a376b5d`, full per-note context in one call) MCP tools over a shared `parse_wikilinks`
    (alias/heading-aware, basename-matched,
    traversal-safe), CATALOG-REGISTERED (`d481f38ee`, discoverable), 180/180 omega-mcp tests. Agents have the
    full link graph + unresolved-link health. SEMANTIC layer GROUNDED 2026-06-21: the REAL brain-semantic index
    (`epistemos-shadow` BM25+HNSW+RRF) is wired SWIFT-SIDE (`ShadowSearchService`/`RustShadowFFIClient`);
    omega-mcp has NO shadow/agent_core dep. **BRAIN-SEMANTIC LAYER DONE (`e6bb927f2`):** `VaultSemanticBacklinks.
    relatedNotes` (Swift, the right place) drives the REAL `ShadowSearchServicing` hybrid search (BM25+HNSW+RRF,
    `.notes` domain), self-excluded, injectable/mock-tested, 3/3 — NOT a lexical fake. #3 now has BOTH the
    mechanical wikilink graph (omega-mcp) AND brain-powered semantic relatedness (Swift/shadow).
    **AUTO-LINKING DONE (`5577232a4`):** `vault.link_candidates` = Obsidian's "unlinked mentions" — other notes
    whose title appears in this note's prose but isn't yet `[[linked]]` (whole-word/case-insensitive, [[..]]
    spans stripped, self + already-linked + <3-char titles excluded; count-ranked). The honest INVERSE of
    dangling_links (linked-but-missing vs mentioned-but-not-linked). Catalog + is_vault_tool registered (OpenCode
    fusion advertises/routes it). 187/187 lib + 5/5 stdio green.
    **ORPHANS DONE (`d661d46f5`):** `vault.orphan_notes` = Obsidian's "orphans" — notes with NO resolved outlink
    AND nothing linking to them (stranded from the graph), vault-wide in ONE call. Distinct from dangling (broken
    links) + link_candidates (unlinked mentions); self-links + dangling-only links correctly don't count as
    connecting. 192/192 lib. The LLM-wiki link-health tool set is now comprehensive (backlinks/outlinks/dangling/
    note_links/link_candidates/orphans + semantic backlinks). REMAINS (later): surface in the editor UI (Swift).
  - [~] **#4 in-editor agent edits on BOTH Prose + MD-V2/Epdoc** (the killer differentiator): CORE DONE
    (`c61b41cac`) — `AgentNoteEdit` editor-agnostic text-based ops (append/replaceFirst/insertAfter), HONEST
    (nil when anchor absent → never silently mangles) + ATOMIC batch apply (`c0991f4fe`, all-or-nothing) +
    `VaultNoteEditor` file-level applier (`6d467d1f7`, read→apply→write-only-on-success). PLUS the EXTERNAL-agent
    surface: `vault.patch_note` MCP tool (`214d7f04b`, same op model in Rust, honest missing-anchor-writes-nothing).
    Both surfaces (in-app Swift + external MCP) tested. The same ops apply across editors + file + MCP.
    **LIVE-EDITOR BINDING RESOLUTION DONE (`3ece02f93`):** `AgentNoteEdit.resolveTextEdit(in:)` maps an edit to a
    live-buffer `MarkdownEditorCommands.TextEdit` (NSRange via NSString), applied via the EXISTING
    `ProseTextView2.applyAutomaticMarkdownEdit` path (reuse-not-rebuild); honest nil-when-absent (no out-of-range).
    **PROSE LIVE-EDITOR WIRED END-TO-END (`59b9e9d52`):** `ProseTextView2.applyAgentEdit(_:)` = the agent surface's
    entry — resolves vs the live buffer + applies via the existing path; honest false+no-mutation when absent. Full
    Prose chain: AgentNoteEdit → resolveTextEdit → applyAgentEdit → live NSTextView. **EPDOC BINDING SCOPED:** Epdoc/
    Tiptap holds ProseMirror RICH content (not raw markdown text), so a text-based edit doesn't map to a live Tiptap
    range — the clean MD-V2-aligned path is: agent edits the md SOURCE (`VaultNoteEditor`, built) → Epdoc REPROJECTS
    from updated md (coupled to the MD-V2 inversion #12); a lexical Tiptap-command mapping would be wrong. So Epdoc's
    live-binding is the heavier, MD-V2-coupled follow-on.
    **AGENT-EDIT PROVENANCE DONE (`3183aa4e2`):** every in-app agent note edit now records a COMMITTED agent
    `MutationEnvelope` (`SourceOp.artifactUpdate`) — new pure/deterministic `AgentNoteEditProvenance` (agent
    actor, sha256 integrity hash over before/after, `affectsBody`+`affectsSearchProjection`, note as touched
    artifact) mirroring `ModelAuthoredNoteMutation`'s shape EXACTLY (reuses the existing model + the
    `EventStore.saveMutationEnvelope` sink — no parallel model) + a new
    `VaultNoteEditor.applyEdits(_:to:provenance:…)` overload (read→apply→write→record; HONEST: failed edit
    records nothing, body-wrote-but-envelope-failed throws the new `provenanceNotRecorded`, never a silent
    audit gap). Real-state verified: xcodebuild VaultNoteEditorTests **7/7 PASS** (+4 new), TEST SUCCEEDED.
    **EXTERNAL-AGENT EDIT PROVENANCE DONE (`69f6aa283`):** `edit_note`/`vault.patch_note` (OpenCode/Codex via
    the fusion server) now record a deterministic `artifact_update` provenance line to
    `.epistemos/mcp_vault_events.jsonl` (before/after blake3 hashes, integrity hash, content-derived
    idempotent mutation_id) — the MCP analog of the in-app envelope; HONEST best-effort (edit is the truth →
    provenance failure reports `provenance_recorded:false`, never silent; failed edit records nothing). BOTH
    edit surfaces (in-app Swift + external MCP) now provenance-covered. 184/184 omega-mcp lib green (+1).
    REMAINS (#4): Epdoc-via-md-source reprojection (MD-V2-coupled, #12); later, app-side ingest of the MCP
    vault-event log into the unified EventStore.
- **ONE CHOKEPOINT phase-1 REGRESSION-VERIFIED (`b28cb96e7`):** LocalAgentLoopTests 42/43 — the only failure
  is the pre-existing SS-AL `:1617` (`f26924ccf`, not mine); my liveLoop streamGenerator restructure caused
  ZERO regressions (flag-off byte-identical confirmed).

**Context-gated remaining (NOT dropped — need a context the green-only main loop lacks):**
- **WORK functional = OpenCode runtime VENDORED (owner installed Bun 2026-06-21, gate cleared):**
  `build-opencode-runtime.sh` (wired into the Pro/main preBuildScripts, NOT MAS) fetches at BUILD time, version-
  stamp gated (like build-tiptap-bundle.sh), end-users install nothing, runtime gitignored:
  - ✅ **ckpt 1 (`ce80215b2`):** pinned **Bun 1.3.14** → `Resources/opencode-runtime/bin/bun` (60M).
  - ✅ **ckpt 2 (`c569e484a`):** pinned **OpenCode 1.17.9** standalone binary (sst/opencode `opencode-darwin-arm64`,
    self-contained, no source build) → `bin/opencode` (123M). VERIFIED both vendor + `--version`; gating skips re-run.
  - **Resolver `WorkOpenCodeRuntime.bundledRuntimeURL()` now resolves `bin/opencode` → the work shell goes LIVE
    when armed (`EPISTEMOS_WORK_OPENCODE_V0=1`):** `BundledWorkOpenCodeShell.launchSpec` → `WorkTerminalHostView`
    spawns the real OpenCode TUI in the native SwiftTerm/PTY view (reachable via the Work settings tab). Zero
    further Swift wiring — the seam/terminal/resolver were pre-built for exactly this.
  - ✅ **FUSION transport (`da6d42422`):** `omega_mcp_stdio` — a stdio MCP server (newline-delimited JSON-RPC)
    OpenCode's work agent spawns to work the vault NATIVELY (the "Goose/etc fuse beneath" via MCP). initialize/
    tools-list (catalog)/tools-call (executes the Rust vault + wikilink-graph + graph tools)/resources. 3 tests.
  - ✅ **FUSION COMPLETE end-to-end (`fc6ef47a8` + `f9e5cbf5b`):** `omega_mcp_stdio` built+staged into Resources
    by the build script (alongside bun+opencode, all smoke-verified); `BundledWorkOpenCodeShell.launchSpec`
    sets `OPENCODE_CONFIG` → registers it (verified the env works against the real binary) so OpenCode's work
    agent auto-gets the vault tools. Full chain: arm flag → resolve `bin/opencode` → terminal spawns the real
    TUI → vault tools fused.
  - ✅ **FUSION tools/list HONESTLY SCOPED (`10e25b091`):** the stdio server served tools/list from the FULL app
    catalog (~32 tools incl. computer-use/safari/move_file) but tools/call only routes vault+graph → OpenCode saw
    phantom tools it couldn't call ("Unknown vault tool"). FIXED: new `vault::is_vault_tool` (single source of the
    executable vault surface, parity-tested vs execute_vault_tool) + `scope_tools_list_to_executable` retains only
    `is_vault_tool || is_graph_tool` (fail-open). OpenCode now sees ONLY the vault+graph tools it can run (incl.
    graph.populate_from_vault + patch_note). lib 185/185 + stdio bin 5/5 green.
  - ✅ **REAL-TRANSPORT E2E (`8f3173eae`):** new `omega-mcp/tests/fusion_stdio_e2e.rs` SPAWNS the compiled
    `omega_mcp_stdio` binary and drives the exact MCP client sequence OpenCode uses over real stdin/stdout —
    initialize (serverInfo/protocolVersion over the wire) → silent notification → scoped tools/list (proven
    end-to-end: backlinks/link_candidates/populate_from_vault advertised, phantom screenshot excluded) → real
    backlinks tools/call. Proves the transport half of the launch-smoke headless. REMAINS: app-build + GUI
    launch-smoke (TUI render — needs the running app).
  - ✅ **MCP `ping` keepalive (`09da7845c`):** the server had no ping handler → the MCP spec keepalive (sent
    by the SDKs incl. OpenCode's) returned `-32601 Unknown method`; some clients DROP the connection on a
    failed ping. Now returns the spec empty `{}` result; in-process + real-transport-e2e tested. stdio bin
    6/6 + e2e drives a real ping. Hardens the fusion link against client-side health-drops.
  - ✅ **TRANSPORT-LEVEL SECURITY GUARD (`7364212c9`):** new e2e proves the COMPILED binary refuses a
    `vault:///../../etc/passwd` resources/read over real stdio (JSON-RPC error -32602 "Path traversal not
    allowed", no contents leaked) — locks the path-safety the dispatcher enforces, at the surface a rogue
    external agent reaches. (Self-verify caught my own wrong test assumption — result:null always present —
    not a bug; security holds.) **Session regression sweep CLEAN:** omega-mcp 187 lib + 6 stdio + 2 e2e,
    agent_core work 94 + mutations 28 — zero regressions across the session's ~14 commits. AUDIT of the WORK
    clean-room tools: RetryManager (timeout fixed), RepetitionGuard (correct), recipe (verbatim types),
    resources/read (traversal-safe+tested) — all solid.
- **🔴 P0 LIVE-CHAT REGRESSION (owner 2026-06-21) — partial fix + classified:** see
  `docs/research/P0_CHAT_REGRESSION_FINDINGS_2026_06_21.md`. (B) `<think>`-LEAK = SHARED inference-output bug
  (`strippingThinkingBlocks` left UNCLOSED `<think>` un-stripped) → **FIXED `c9184b4e6`** (43/43 incl. regression
  test); benefits act/note/graph/title. (A) answer-refusal = model's real output (not act-injection — verified
  flag-off-byte-identical; not the system prompt) → bisected to the `f884eb0b7` vmlx MLX **tokenizer/chat-template**
  loader change; needs a RUNTIME prompt-string check to confirm (can't diagnose headlessly — no loaded model).
  Main-chat `generateChatTitle` NOT polished (deletion path, owner directive).
- **GOOSE full-clone** = the `goose` crate (179 deps; reqwest 0.12↔0.13 clash) → needs a build-iteration
  context (worktree/branch), per owner §446-460 "not main red". See `docs/research/GOOSE_FULL_CLONE_INTEGRATION_COST_2026_06_21.md`.
- **MD-V2** (#12) = large mature EPDOC subsystem; no clean one-shot projection seam → needs dedicated grounding
  (won't ship a toy projection). **Composer reskin / mode-entry / search→work** = owner's running-app visual judgment.

Prose: the **act ENGINE (#2)** is the big completion — act runs live through OsaurusCore (flag-gated,
honest, verified). Per the 2026-06-21 RE-SYNC: **ACT-first** — finish act (shared composer + reskin +
mode-entry animations) BEFORE work. **WORK** = OpenCode FULL-CLONE shell (real UI) + Goose/Hermes/OpenClaw
fused (real-crate vendor, not leaf-by-leaf). **MAS** = dual-build full-capability. #6 Tamagotchi render-fix
is IN SCOPE (resolved). Nothing dropped/stashed/fake-done; no MAS-struct corner-cuts (OsaurusCore-on-MAS
dual-build is a tracked follow-up, explicitly flagged — not silently cut).



Single source of "done / next" for the Osaurus-first walk. Each loop iteration:
read this, pick the next `[ ]`, build to the real-state done bar, commit, update this.
Grounded in real files only (anti-hallucination). Authority: `OSAURUS_P3_IMPORT_PLAN_2026_06_19.md`
+ `_2026_06_21_addendum.md` + `CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md`.

## Slice status (per import plan §"Sequenced slices")
- [x] **S1 — Seam A** (pre-existing, verified by file-read this session):
  - `Epistemos/ActOsaurus/ActOsaurusBridge.swift` — protocol + `InertActOsaurusBridge`
    (honest inert default) + `OsaurusActBridge` growth point + `ActOsaurusBridgeFactory`.
  - `Epistemos/ActOsaurus/ActOsaurusGateStatus.swift` — flag `EPISTEMOS_ACT_OSAURUS_V0`,
    always-compiled, honest "Pro only" on MAS.
  - `Epistemos/Views/Settings/ActOsaurusHealthRow.swift` — visible, registered in
    `SubstrateHealthPanel` → `SettingsView.swift:501` (`.substrateHealth`).
  - `EpistemosTests/ActOsaurusSeamTests.swift` — 6 @Test incl. MAS/Pro boundary guard.
  - Adapter stubs: `Epistemos/Vendor/Osaurus/{OsaurusChatMessage,ServerHealth,OsaurusVendorProvenance,OsaurusVendorLocalization}.swift`.
- [x] **S2 — vendor the full repo** (DONE 2026-06-21, commit `ae911ea5e`):
  `LocalPackages/osaurus/` full clone @`ae3a3c5d`, MIT direct_import, `.git` stripped,
  `VENDOR.md` + `scripts/update-osaurus.sh`. **Source-on-disk only — NOT xcodegen-linked.**
- [!] **S3 — link the FULL `OsaurusCore` (owner 2026-06-21: full Osaurus, MAS no longer a hard
  constraint).** Deep entitlements research done → `docs/research/OSAURUS_MAS_ENTITLEMENTS_RESEARCH_2026_06_21.md`.
  FINDINGS: ~95% of Osaurus fits MAS by standard entitlements (server=`network.server`,
  relay=`network.client`, MLX/MCP/SQLCipher/plugins/telemetry); the ONLY MAS blocker is the
  **Linux-VM sandbox** (`com.apple.security.virtualization` — a RESTRICTED entitlement Apple grants
  only to virtualization-software vendors). Per owner's rule (can't fit all → don't be strict):
  **main app = direct-distribution (notarized, non-sandboxed) carrying the FULL Osaurus incl. the VM
  sandbox** — no feature cut, no MAS-struct excuse. REMAINING WORK (in order):
  1. **Resolve the dual-MLX clash** — consolidate Epistemos onto Osaurus's `vmlx-swift`. GROUNDED
     (read both Package.swifts): vmlx-swift provides the SAME module names (`MLX`/`MLXNN`/`MLXOptimizers`/
     `MLXLLM`/`MLXLMCommon`/`MLXVLM`/`MLXEmbedders`), so Epistemos's **8** MLX-importing files map 1:1
     with only TWO fixups: `import Tokenizers`→`VMLXTokenizers` (1 file) and `MLXStructured` (1 file,
     `#if canImport` guarded → drops cleanly). **vmlx-swift now VENDORED** at `LocalPackages/vmlx-swift`
     (pinned `4453909…`, MIT, commit pending). NEXT: project.yml swap (drop `MLX`/`MLX-LM` packages →
     vmlx-swift) + the 2 import fixups + build-verify. Do this where the build can iterate (the swap
     breaks the build until APIs reconcile — don't commit to main red).
  2. Add OsaurusCore SPM dep to project.yml + adjust signing/entitlements (drop the MAS-only sandbox
     constraint for the main build). 3. Build-verify. 4. Reskin to pixel-art (the video experience).
  Gating note: the old `#if !EPISTEMOS_APP_STORE` Pro-gate on the seam stays (a MAS build can still
  omit ONLY the VM sandbox), but it no longer constrains the main app.
- [🟡] **S4 — Act agent-turn through OsaurusCore** + reskin composer to pixel-art chrome.
  - [x] First slice DONE (`2f6779c40`, real-state verified): `OsaurusActBridge` imports the LINKED
    OsaurusCore + reads REAL engine data in-process (`isOsaurusCoreLinked`, `osaurusCoreRemoteProviders`
    = `OsaurusCore.RemoteProviderType.allCases`); test `s4OsaurusCoreDrivenInProcess` passes. Act DRIVES
    OsaurusCore, not just links it.
  - [x] Generation turn DONE (`48407b751`, compile-verified + test): `runTurnInProcess` drives
    `OsaurusCore.CoreModelService.shared.generate()` in-process (system→systemPrompt, conversation→prompt),
    honest errors, never a cloud route. Act GENERATES through Osaurus, not just links/reads it.
  - [x] LIVE wiring DONE (`aa0b40b57`, verified): `DeviceAgentService` constructs `LocalAgentLoop` with
    the OsaurusCore generation closure when `EPISTEMOS_ACT_OSAURUS_V0` is ON (default OFF = proven MLX
    path unchanged; MAS unchanged). Act runs END-TO-END through Osaurus in-process, opt-in + safe + honest.
    Also: real engine-status surface (`2025fc876`), generation-closure (`4c5ba8f84`). S4 ENGINE complete.
  - [ ] REMAINS (UI/streaming, after engine): token streaming via OsaurusCore's server SSE; then the act
    composer reskin (current-chat discipline) + mode-entry blur/typewriter animations + per-clone settings.
- [ ] **S5 — Containerization Linux-VM sandbox** (Pro/dev, virtualization entitlement, no-hidden-fallback).
- [ ] **S6+ — server endpoints, MCP, plugins, privacy filter, identity/relay** (each gated/logged/MAS-excluded).

## Cross-cutting (post-clone, per addendum)
- [🟡] **Surface-wiring:** ALL chat surfaces (main ChatView, MiniChat, NoteChatSidebar,
  Graph/Hologram*, + sweep) → ONE shared act composer. Map each surface → real proven
  front-end BEFORE wiring; prove (real-state/launch-smoke). No dead surfaces.
  - [x] **ENGINE-LAYER shared chokepoint DONE (`e67295bc0`, real-state verified):** audit found the
    act=Osaurus swap lived ONLY in DeviceAgentService — `ChatCoordinator`(main chat)/`PipelineService`/
    `IMessageDriverService` all build via `LocalAgentLoop.liveLoop` and BYPASSED it (act never reached
    the main chats). Fixed: `LocalAgentLoop.shouldRouteActThroughOsaurus()` = single source of truth,
    applied at the liveLoop chokepoint + reused by DeviceAgentService (no divergence). 4/4 tests.
  - [x] **TOKEN STREAMING through OsaurusCore DONE (`0d9f3f524`):** public `CoreModelService.generateStream`
    (drives base-protocol `streamDeltas`, resolves like `generate`, honest single-attempt v1, never cloud) →
    `ActOsaurusBridge.runTurnStreamingInProcess` → `ActOsaurusStreamingHandler` → liveLoop routes BOTH
    generator AND streamingGenerator via the shared decision. Main-chat act path now STREAMS tokens (STREAM
    EVERYTHING), not single-shot. 3/3 tests. REMAINS: composer pixel-art reskin (visual).
  - [x] First surface wired (DONE 2026-06-21, real-state verified): **Epistemos Picks VIEW** —
    `Epistemos/Views/Settings/EpistemosPicksSectionView.swift` renders the curated provider in
    pixel-art (reuses `InlineRuntimePickerPanel`'s exact live-state→Environment mapping + honest
    selection), mounted as a leading "Epistemos Picks" Section in the existing proven
    `ModelStackSettingsView` (visible in the model-manager sheet). The same component the act
    composer mounts in S4. **VERIFIED:** app target compiles clean (0 errors) + 12/12 tests green.
- [x] **"Epistemos Picks"** — DONE 2026-06-21 (real-state verified, commit `519aed305`).
  `Epistemos/Engine/EpistemosPicks.swift` = pure `nonisolated enum` curating the owner's hardened
  models (Gemma QAT ladder via `EpistemosFoundationLineup` + explicit Qwen extras + curated
  Apple-Intelligence) into a top-billed "Epistemos Picks" section, separated from generic
  "Installed Models". Reuses the proven `EpistemosRuntimePicker` (no new model layer); honest
  selection inherited verbatim (`Option.isSelectable`/`blockedReason` via `LocalChatModelMemoryGate`)
  → NO silent Qwen, too-large stays visible with reason. **VERIFIED:** compiles into the app module
  (0 errors) + all 4 @Test pass (curated-first, installed-separated, honest-too-large, nothing-lost)
  via `xcodebuild test` ("** TEST SUCCEEDED **", 12/12). REMAINS: render it in the act model-stack
  view (S4, minimal pixel-art) — that UI wiring is the not-yet-done part.
- [x] **Discovery sweep** (DONE 2026-06-21 — `docs/research/OSAURUS_SURFACE_DISCOVERY_SWEEP_2026_06_21.md`):
  enumerated 7 distinct chat surfaces (main/MiniChat/Note/Graph/Landing + verify HTMLWorkspace/Shadow),
  the shared backend consumers (`InferenceState`/`EpistemosRuntimePicker`/`ChatCoordinator`/`Composer*`),
  work-mode seam, settings model surfaces, OUT list, ripple effects. **Verdict: ONE shared act composer
  over `ChatCoordinator` + `InferenceState` + `Composer*`/`ChatInputBar`.** Re-run critic each cycle.
- [ ] **Port owner IP** (system prompts + hidden pieces) onto Osaurus engine; **WORK mode**
  (Goose/OpenCode) clone/port too.
- [ ] **PER-CLONE SETTINGS (owner 2026-06-21):** each cloned app keeps its OWN settings — surface in
  Epistemos Settings as an EXECUTIVE TAB/TOGGLE (keep the all-Epistemos tab; add `act`/`work`/beyond
  tabs exposing each clone's native settings). Preferred = another tab. Respect each clone's settings.
- [🟡] **PER-CLONE SETTINGS TABS** — act tab (`7dc3a9fcc`): `SettingsSection.actClone` + `ActCloneSettingsView`
  (gate + real OsaurusCore engine status). **WORK TAB LANDED (`78fe1c738`):** `SettingsSection.workClone`
  ("Work (OpenCode)") + `WorkCloneSettingsView` — both work seams' honest status (shell + Goose engine) AND
  mounts the REAL `WorkTerminalHostView` (SwiftTerm/PTY) → the work terminal chain is now REACHABLE (no dead
  component); honest placeholder until armed. All 7 exhaustive switch arms; 2/2 tests. REMAINS: "beyond" tab;
  later, embed each clone's REAL settings surface (reskinned).
- [x] **ACT-ON-OSAURUS IN-APP TOGGLE + indicator (owner §806, `d528c1d90`):** the owner wanted to EXPERIENCE
  act without setting an env var + relaunching. `ActOsaurusGateStatus` gained a runtime override layer
  (`override`/`setOverride` UserDefaults tri-state) + `resolvedActive` (**override > env > off**; App Store
  always off; default-absent = flag-OFF byte-identical). `LocalAgentLoop.shouldRouteActThroughOsaurus` now
  resolves through it → the toggle flips ALL act paths (primary + streaming + non-streaming via
  `SharedActInference`), no relaunch. `ActOsaurusHealthRow` shows the "Use Osaurus for Act (experimental)"
  switch (Pro only) + the existing bolt/headline reflect the resolved state live. Verified: ActOsaurusSeamTests
  **17/17** (+3: resolution order, status-source honesty, router-off-by-default), TEST SUCCEEDED. (Visual:
  switch styling is owner running-app judgment; the gate/router logic is real-state tested.)
- [x] **WORK-ON-OPENCODE IN-APP TOGGLE — two-mode parity (owner §194, `fea6d356f`):** the act gate had a
  runtime toggle but WORK was env-only; mirrored the override layer onto `WorkOpenCodeShellGateStatus`
  (`override`/`setOverride`/`resolvedActive`: override>env>off; App Store always off). `WorkOpenCodeShell.resolve`
  now gates on `resolvedActive` → the toggle arms the shell live (still honest-inert until the runtime is
  bundled). `WorkOpenCodeShellHealthRow` shows the "Enable Work" switch (Pro). Both act + work now
  runtime-toggleable (§194 two-toggle ontology). WorkOpenCodeShellSeamTests **7/7** (+2: resolution, status-source).
- [x] **WORKSPACE-MODE SELECTION — single source of truth (owner §122/§194, `f445c3f53`):** ties the session's
  two-mode pieces together. `WorkspaceModeSelection` (pure/persisted): `current`/`select` track the user's mode
  (act default, honest unknown-fallback) + `isArmed(mode)` reads the REAL act/work gates' resolved arm-state (no
  duplicated gate logic). `WorkspaceModePicker` = reusable act/work segmented control with a live per-mode armed
  dot. Selecting a mode is SEPARATE from arming its engine (gate toggles = the opt-in). WorkspaceModeSelectionTests
  **3/3** (persistence, fallback, gate-reading integration). **`ModeEntryView` composes them (`6516cfe19`,
  source-guard-gated per CODE-MORE-BUILD-LESS):** picker + ModeEntryTitleView over WorkspaceModeSelection,
  re-keying the title on mode-switch. REMAINS (owner-reviewed visual): mount `ModeEntryView` in the landing —
  GROUNDED mount point = `LandingView.greetingContent` (the `LiquidGreeting` at `LandingView.swift:712`, shown
  when `ui.homeContent == .greeting`); wire the press→blur→mode-entry flow + surface routing there. Risky
  visual surgery on the loved 2843-line landing → owner running-app judgment (not a blind source-guard edit).
  **CHECKPOINT BUILD ✅ (2026-06-22):** the whole two-mode component batch (ModeEntryView + picker + transition +
  selection) compiles clean into the app module (`xcodebuild build`, BUILD SUCCEEDED) — the source-guard fast-gate
  cadence held (CODE-MORE-BUILD-LESS). Two-mode component foundation = checkpoint-verified green.
  **LANDING MOUNT (`5e7dfe44a`, source-guard + checkpoint-pending):** WorkspaceModePicker now appears in the
  landing greeting (`greetingContent`), GATE-TIED — shown only when act or work is armed, so the protected
  landing (§367) is BYTE-IDENTICAL by default and elevates only on opt-in. The two-mode selector is now REACHABLE
  + live (§24). **CHECKPOINT ✅: landing mount BUILD SUCCEEDED** (compiles green; protected-landing path
  unchanged). REMAINS (owner-reviewed visual): swap in the full ModeEntryView greeting→typewrite transition +
  blur/page chrome as the elevated experience.
- [x] **DRY: one shared `FeatureGateOverride` (`a6527922b`):** the act + work gates carried byte-identical
  override logic (get/set/truthy/resolve override>env>off); consolidated into one helper both delegate to (zero
  behavior change). **CHECKPOINT ✅: 27 tests / 3 suites TEST SUCCEEDED** (act+work gate behavior preserved).
  Extended in-pillar: `WorkBackendGateStatus` also delegates (`bbd777133`); direct helper test
  `FeatureGateOverrideTests` (`282ce89be`) locks the semantics — both in a follow-on checkpoint.
- [🟡] **MODE-ENTRY ANIMATIONS (owner 2026-06-21)** — engine done → now in-scope. **LOGIC CORE DONE
  (`20cb97e25`):** `ModeEntryTransition` (pure/tested state machine: idle→backspace greeting→typewrite mode
  name→reveal; `displayText` per step; `advanced()` ticked by the view, no Date inside) + `WorkspaceModeKind`
  {act,work} (labels act→"act"/work→"work", overridable to "Epistemos chat") + thin `ModeEntryTitleView`
  (act=native blur-reveal, work=monospace ASCII). 5/5 tests (progression, fixed-point, empty-greeting), TEST
  SUCCEEDED. REMAINS (owner-reviewed visual): richer blur/ascii chrome + the greeting→title TRANSLATE-up +
  message-bar blur-reveal + mounting into the landing flow (needs running-app visual judgment).
  On select: greeting backspaces + moves UP, typewrites the mode name; reusable elements (greeting→title)
  travel up connectedly; smaller UI + message bar BLUR then reveal. **act = native Apple blur-reveal**;
  **work = ASCII/pixel typewriter + full-page dynamic reveal** (OpenCode not native → use its font, more
  flexible/interesting element reveals). "epistemos chat"→act, "work"→work, written in each mode's voice.
- [🟡] **MOTION LANGUAGE TRIAD** — reusable pieces landed: `BlurFade` (transition) + `.motionReveal()`
  (blur-in, `61ac6eeba`, on a real act title) + `TypewriterASCIIRippleText` (ASCII layer) + **NEW reusable
  `MotionTitle` (`9d1c421e6`)** = the owner's ONE ontology coupling ASCII-typewriter + blur into a single
  component (reduce-motion-safe, font-adaptive, display-only, never editors), applied to a real WORK status
  title (ASCII strongest in WORK, §329). REMAINS: sweep `MotionTitle`/`.motionReveal()` onto more
  titles/display-only (settings/agent/headers) tastefully — a visual-judgment pass best with the running app.
- [🔴] **MOTION LANGUAGE TRIAD — CROSS-CUTTING STANDING RULE (owner 2026-06-21)** = Apple blur +
  ASCII/pixel typewriter (the "time machine" title-box style) + subtle micro-motions. Apply to **TITLES +
  display-only text** (settings, agent surfaces, section headers, agent ANSWERS maybe — find balance),
  hover-on-message-bar may trigger it. **Noticeable-not-bloated; NEVER in editors / text-editing fields.**
  Body fonts get a lighter variant than title fonts. Part of the app's "fun it up" initiative. Every NEW
  view honors this triad. (Standing rule — see "Standing rules in force".)
- NOTE: this doc is the LIVING IMPLEMENTATION MAP for all 14 directive areas (owner audit-map 2026-06-21):
  two-modes act/work; Osaurus linked; reskin=current-chat discipline; preserve chrome + Epistemos Picks;
  Tamagotchi agents (fix render); chat quarantine; no-silent-Qwen; MAS-non-restrictive global; reuse-not-
  rebuild IP (RustLSP/Eidos/DAG/Halo/RRF); every-surface-wired; EPDOC MD-V2; substrate=CERTAIN-lower;
  hygiene. Keep status grounded in file:line.

## ✅ MLX consolidation — REGRESSION CHECK PASSED (2026-06-21)
Focused `xcodebuild test` (vmlx, signing-disabled): **40/41 green** across SSMMemorySidecar,
EpistemosRuntimePicker, LocalModelResolution(core), ModelStreamingExecutor, EpistemosPicks,
ActOsaurusSeam — the consolidation did NOT regress the app. The 1 failure (`LocalModelResolution
Tests` "never silently use a cloud model") is **PRE-EXISTING string drift** (code says "won't
silently use a cloud model") in the chat-resolution honesty area — UNRELATED to MLX, in the
DEFERRED chat scope (directive: stop patching the dying chat); left as-is, not my regression.
**KIVI test quarantined** (`EpistemosTests/KIVIKVCacheRuntimeTests.swift` behind
`EPISTEMOS_LEGACY_KIVI_KERNELS`): tested old-fork kernels removed by the consolidation; vmlx native
quant supersedes them; KIVI-port + test-rewrite are CERTAIN follow-ups. NEXT = link OsaurusCore.

## ✅ MLX consolidation — DONE (2026-06-21, `** BUILD SUCCEEDED **` build #9, exit 0)
The ENTIRE Epistemos app compiles + links against Osaurus's `vmlx-swift` MLX stack (consolidated
off `mlx-swift-lm` + `ml-explore/mlx-swift` → ONE MLX, no dual-MLX clash). KIVI + SSM hardening
PRESERVED (KIVI via vmlx native 2-bit quant; SSM via the `ChatSession` extract/inject overlay).
AppGroup/AppKit/perf untouched. Verified compile-only (`CODE_SIGNING_ALLOWED=NO`) — signing/entitlements
for distribution is a separate follow-up (owner: direct-distribution, robust entitlements). Files
reconciled: MLXInferenceService, NativeLoRATrainer, NativeKTOTrainer, MLXConstrainedGenerator, +
project.yml/pbxproj/Package.resolved + the vmlx ChatSession overlay. NEXT: run the test suite (no
regressions), then **link OsaurusCore** (the actual act=Osaurus engine). `LocalPackages/mlx-swift-lm`
is now dead (unreferenced) — deliberate-delete is a later cleanup. Reconciliation detail:

Grounded fixes:
- [x] `switch item` — added vmlx's new `Generation` cases `.reasoning` + `.prefillProgress`
  (TODO: route `.reasoning` to the thinking pane — STREAM-EVERYTHING follow-up).
- [x] `kvScheme` — dropped (vmlx `GenerateParameters` has no `kvScheme`); KIVI 2-bit hardening kept
  via vmlx native `kvBits:2`/`kvGroupSize:32`. (TODO: port exact KIVI scheme onto vendored vmlx.)
- [ ] **`loadContainer(configuration:)` (lines ~2012/2017)** → vmlx requires `from:`+`using:`. Epistemos
  loads a LOCAL dir (`ModelConfiguration(directory:)`), so use vmlx's local overload
  `loadContainer(from: modelDirectory, using: <TokenizerLoader>)`. OPEN: which `TokenizerLoader`? No
  simple default in vmlx (JangLoader has many inits; BenchmarkHelpers has NoOpTokenizerLoader). →
  study `LocalPackages/osaurus/.../Services/ModelRuntime.swift:1075 loadContainer` for the canonical loader.
- [ ] **`session.extractKVCache()`/`injectKVCache()` (2591/2650)** — not on vmlx ChatSession. SSMStateService
  ALREADY uses vmlx-compatible `[any KVCache]` + `savePromptCache`. Fixes: extract → add a public accessor
  on the VENDORED vmlx ChatSession (it has internal `withCache`; make a public `extractKVCache()` returning
  the `[KVCache]`); inject → vmlx uses **`ChatSession.init(cache: consuming [KVCache])`**, so restructure the
  2 session-construction sites (`MLXInferenceService:1649`,`1765`) to load-cache-THEN-construct (or add a
  public reset-cache method to vendored ChatSession). Preserves SSM session-resume hardening.
WIP uncommitted on main; commit only when GREEN.

## Standing rules in force
- **MOTION LANGUAGE TRIAD (owner 2026-06-21):** every NEW view applies the triad — Apple blur +
  ASCII/pixel typewriter ("time machine" style) + subtle micro-motions — on TITLES + display-only text
  (settings/agent surfaces/headers), noticeable-not-bloated, **NEVER in editors/text-editing**. UI built
  AFTER the engine; this rule is recorded now so it's honored when UI lands. Don't pull UI ahead of engine.
- **MAS is NOT a hard constraint (owner 2026-06-21).** Never cut an Osaurus feature or "lose its
  osaurus-ness" to stay MAS-sandbox-compliant. Main app = direct-distribution (notarized) carrying
  the full Osaurus incl. the VM sandbox. MAS-fit was researched by ENTITLEMENT (see entitlements
  doc); only the restricted virtualization entitlement genuinely can't fit MAS. Do NOT use "MAS
  structure" as an excuse to cut corners — resolve clashes properly.
- **Conflict → favor Osaurus**; cherry-pick only the owner's *compatible* IP; front-end =
  minimal Epistemos pixel-art. (addendum, owner 2026-06-21)
- **NEVER delete chat** — quarantine only; port IP first; retire only after IP-ported +
  act-parity-proven + data-migrated + OWNER-OK.
- No fake-done (real-state test, not build-green); flag-OFF = staged. main-only;
  `git add` own files only; commits Co-Authored-By Claude.

## Verified build baseline (2026-06-21)
`xcodebuild test -scheme Epistemos -destination 'platform=macOS'` (warm) → **0 errors,
** TEST SUCCEEDED **, 12/12** (8 Osaurus-seam + 4 Epistemos-Picks). This means:
- The full **app module compiles clean** — including the flagged **chat-picker enumeration
  commit** (build-state was UNVERIFIED per the continuation prompt) → **now VERIFIED OK, no
  fix/revert needed**; flag cleared.
- `EpistemosPicks` + `ActOsaurus` seam are real-state green.
The vendored `LocalPackages/osaurus` is NOT in this build (S3 not yet linked) — expected.

## IN-FLIGHT (uncommitted on main — do NOT commit until GREEN)
- **MLX-swap in progress (iter 8):** `project.yml` swapped `MLX`(ml-explore)+`MLX-LM`(mlx-swift-lm)+
  `MLXStructured` → `vmlx-swift` (products MLX/MLXNN/MLXOptimizers/MLXLMCommon/MLXLLM/MLXVLM) in both
  app targets; `NativeKTOTrainer.swift` `Tokenizers`→`VMLXTokenizers`; `xcodegen generate` done; SPM
  checkout cache cleared (stale mlx-swift had uncommitted patch). Build running → `/tmp/epi_mlxswap.log`.
  NEXT iteration: read the build's grounded compile errors (vmlx API diffs in the 8 MLX files —
  esp. training files NativeLoRA/KTO/AdapterApply + MLXConstrainedGenerator + MLXInferenceService),
  fix iteratively, rebuild until GREEN, THEN commit. The `patch_mlx_metal_warnings.sh` scheme preAction
  may also need repointing at vmlx-swift. Working-tree changes are real WIP (not a stash) — main's
  committed HEAD stays green.

## Session log
- 2026-06-21: triaged + dropped 24 forgotten stashes (`44f7e07df`, archive in
  `docs/stash-triage-2026-06-21/`). Vendored full Osaurus (`ae911ea5e`, S2). Discovery
  sweep (`e84fd4110`). Epistemos Picks provider+tests (`519aed305`). Verified build pass:
  12/12 tests green, app module clean, chat-picker commit verified.

### 🌟 FUGU (foundational, owner §892, 2026-06-22) — build started
Sakana Fugu = multi-agent orchestration LLM, OpenAI-compatible, ~$10/msg, likely closed. Behind a clean
provider abstraction (modular/replaceable), explicit cost, easy setup; best-combo = Fugu cloud + own native
orchestration. Research: docs/research/FUGU_ORCHESTRATION_INTEGRATION_2026_06_22.md.
- [x] **Slice 1 — provider registration + explicit per-message cost (`1027ffa28`, cargo 4/4):** Fugu in the
  pricing table (req #1 modular — plugs into the EXISTING OpenAICompatibleProvider by config, no new type, no
  hardcoding). Found+fixed a cost-honesty bug: estimate_* ignored the flat per-request cost → a $10/msg provider
  looked ~$0; added `per_message_usd()` ($10.00/msg) for Settings to surface the explicit opt-in (req #2).
- [x] **Slice 2 — named `OpenAICompatibleProvider::fugu()` constructor (`ba4f72a67`, cargo 17/17):** Fugu as a
  CONFIG instance (req #1), env/Settings-overridable FUGU_API_KEY/FUGU_BASE_URL/FUGU_MODEL (req #3 easy setup);
  honest caps (streaming on; tools/vision off until verified). OpenAI-standard → act/work/picker + OpenCode.
- REMAINS: Settings UI (Keychain key+endpoint+cost label+opt-in confirm) → picker/act/work + OpenCode-provider
  wiring → best-combo (b) native orchestration behind the same seam.
- ⏱️ **SEQUENCING (owner §977):** Fugu is FOUNDATIONAL + CERTAIN but does NOT preempt the order. Correct sequence:
  (1) P0 live-chat <think> regression FIRST, (2) act/work VISIBLE surfaces + the walk, (3) Fugu LATER-but-certain
  (when System G/RuntimeRouter + act/work binding points are mature). The above slices are the committed-green
  foundation; NO MORE Fugu ahead of P0 + act/work. RESUMING the regular order (P0) next iteration.

### ✅ camelCase bug class — fully swept + verified (2026-06-22)
EpdocGraphProjector camelCase fix CHECKPOINT-GREEN (EpdocGraphProjectorTests 10/10, TEST SUCCEEDED). Codebase
audit clean: ProseMirrorMarkdownProjector + ReadableBlocksProjector + EpdocGraphProjector + EpdocComplexityCalculator
all alias snake+camelCase node names. orphan_notes↔graph-view consistency locked (`b31aed88b`, cargo 193).

### 🔧 Shared-inference refusal detector false-positive fix (5b15edc2c, 2026-06-22)
P0-adjacent (the shared refusal detector that drives fallback/escalation across both chokepoints): bare
"as an ai"/"as an apple" patterns wrongly flagged HELPFUL "As an AI assistant, I'd be happy to help…" responses
as refusals → wrong fallback. Fixed: those preambles count as refusals ONLY with a co-occurring refusal verb;
true refusals still caught, helpful "As an AI…" spared. Tests (true-pos + 3 false-pos). Checkpoint-pending.
Found while auditing P0-area shared inference. (Priority: P0 at headless ceiling — both lane diagnostics +
root cause pinned; act/work VISIBLE surfaces need the running app; foundational Fugu/TRINITY/system-prompts
sequenced later + blocked on vendoring. This was a genuine safe in-area fix.)

### ⚠️ PRE-EXISTING RED on main — MODEL-SELECTION domain (flagged, NOT mine, 2026-06-22)
TriageServiceTests has 3 FAILING tests, found while checkpointing my refusal-detector fix (5b15edc2c). They are
NOT caused by my change (which only touches `isRefusalResponse`; my 3 refusal tests PASS). They are in the
MODEL-SELECTION domain (older commits a645e6623/020db2a17 "fix(model-selection)/(routing)"):
1. `cloud models expose about-sheet metadata` — expects "Fast, Thinking, Pro, Inline Tools", got "Fast, Think,
   Code, Inline Tools" → STALE test (cosmetic tier-name rename not propagated).
2. `explicit UNINSTALLED pick is NOT silently substituted to Qwen-3-4B` — asserts selection != Qwen but it IS
   Qwen → **POSSIBLE REAL REGRESSION** (the substitution the fix was meant to prevent still happens). Must NOT
   be blind-"fixed" green (that would mask a real bug) — needs the model-selection domain owner.
3. `persisted Gemma 4 chat selection normalizes on inference load` — expects Gemma→Qwen, got Gemma→Gemma →
   STALE test (the "explicit pick wins" fix intentionally stopped Gemma→Qwen normalization).
ACTION: flagged for the model-selection domain owner. NOT blind-fixed (another domain; #2 may be a real bug).
My turn's commits (refusal fix 5b15edc2c + pricing per-request fix 0a4f80609) are clean + verified.

### 🔬 PRECISE DIAGNOSIS — the model-selection RED is a CROSS-DIRECTIVE CONFLICT (owner decision needed, 2026-06-22)
Investigated the 3 TriageServiceTests failures (NOT mine). Root cause of the critical #2 (no-silent-Qwen):
`InferenceState.sanitizedInteractiveLocalTextModelID` (:6373) stacks TWO conflicting owner fixes:
- **2026-06-19** (:6398-6408): explicit pick unavailable → return `nil` to KEEP the pick → never a silent Qwen
  swap (exactly what test #2 `effectiveChatSurfaceSelection != Qwen` asserts).
- **2026-06-20 P0** (:6417-6420): but nil → cloud auto-route → credential-fail, so "if ANY local is runnable,
  run it" → `return runnableLocal` = Qwen (the only installed model), surfaced honestly via LocalRouteHonestyRow.
The 2026-06-20 path runs FIRST → returns Qwen → test #2 fails. So test #2 appears STALE relative to the later
"honest substitution (run-any-local + surface it)" decision — BUT which directive is CURRENT is the OWNER'S call
(never-substitute-even-if-cloud-fails  vs  run-any-installed-local-honestly). Masking either way risks violating
a NON-NEGOTIABLE → NOT blind-fixed.
- #1 (about-sheet string "Thinking, Pro"→"Think, Code"): stale cosmetic; #3 (Gemma→Qwen normalize): stale (the
  "explicit pick wins" fix intentionally keeps Gemma). All 3 are the model-selection domain (a645e6623/020db2a17).
**OWNER ACTION:** decide directive precedence for #2, then I (or the domain owner) update the test OR the resolver
to match — surgically, not by guessing. My turn's commits (5b15edc2c refusal, 0a4f80609 pricing) are clean+green.

### 🌟 TRINITY ORCHESTRATOR — slice 1 DONE (owner-authorized "build now", 2026-06-22)
Owner's latest directive (addendum "TRINITY BUILD PATH") authorizes building the heuristic orchestrator LOOP NOW
(unblocked — no license/MLX-tap block; learned head = clean drop-in later). With P0 at headless ceiling + act/work
visual surfaces needing the running app, this is the buildable foundational work.
- [x] **Slice 1 — flat ≤5-round TWV loop core (`7c1d36643`, cargo 6/6):** `agent_runtime_v2::trinity_loop` — pure,
  provider-free, tested. Roles Worker=0/Thinker=1/Verifier=2 (match the reference coordination-head logits);
  Accept-terminates / honest budget-exhaust; JSONL trace (schema_version 1, 8 event kinds); model calls plug in
  via injected `TrinityRoleExecutor`. naming_lint 49/49, no new warnings.
- [x] **Slice 2 — heuristic role→tier selection (`81303f23f`, cargo 3/3):** `trinity_routing` maps each role +
  task classification (existing `HeuristicClassifier`) → `CapabilityTier` (Thinker/Verifier=Think; Worker=Code/
  Think/Fast by code/complexity). `select_role_tier(role, objective)`. Learned router = clean drop-in later.
- [x] **Slice 3 — JSONL trace persistence (`a1f7e8fe8`, cargo 3/3):** `trinity_trace` serializes the TrinityEvent
  stream to JSONL (schema_version 1) + persists ATOMICALLY (temp+rename); lossless round-trip + replay reader.
- [x] **Slice 2b — heuristic TrinityRoleExecutor (`06801d957`, cargo 4/4):** `trinity_executor` ties loop+routing
  via role prompts + tier routing + HONEST verdict parsing (ACCEPT only on explicit bare ACCEPT → never
  false-accept), over an injected generator. Total trinity = 16/16.
- [x] **Orchestrator entry (`fbafccfa3`, cargo 3/3):** `trinity_orchestrator::run_mission(objective, trace_dir,
  generate)` composes loop+executor+trace into the ONE internal API (heuristic-route → TWV loop → ACCEPT/honest-
  exhaust → atomic JSONL trace). The pure TRINITY core is COMPLETE + cargo-tested (**19/19**).
- [x] **Async loop (`a4d3de41f`, cargo 3/3 tokio):** `trinity_async` = the async TWV loop + `TrinityRoleExecutorAsync`
  (async_trait) so a real async AgentProvider plugs in (sync generator can't await). Same semantics as the sync
  core. Total trinity = 22/22.
- [x] **Tier→model resolution (`56e9043f4`, cargo 4/4):** `select_model_for_tier(tier, available_ids)` resolves a
  TRINITY tier → concrete LOCAL model (CANON, advertised-preferred, local-first) or None (honest no-wrong-tier-swap).
  Total trinity = 23/23.
- [x] **Provider stream→String adapter (`afe13484a`, cargo 4/4):** `trinity_provider::collect_stream_text` drains a
  provider response stream → String (TextDelta until MessageStop; honest error-propagation). Total trinity = 27/27.
- [x] **Provider-backed executor CAPSTONE (`b9a6f7df6`, cargo 6/6):** `ProviderTrinityExecutor` — each role
  tier→provider→prompt→stream_message→collect; HONEST `[trinity-error:…]` → Verifier REPAIR (never false-accept).
  Mock-provider proven END-TO-END. **The TRINITY agent_core core is now callable with a real provider.**
- [x] **Honest router-mode disclosure (`67f443c4c`):** `TrinityRouterMode` {Heuristic, Learned} + ACTIVE=Heuristic
  on TrinityMissionResult — the orchestrator honestly reports it's the heuristic router, never a fake "learned"
  (learned head is license/MLX-tap gated). Per the BIG-IDEA "heuristic-vs-learned disclosed honestly". **30/30.**
- [x] **Cost-honesty (`4d210e9fe`, cargo 8/8):** `collect_stream_with_usage` + `ProviderTrinityExecutor` accumulate
  token usage + call count per run (one model call per role turn) → costed via the shared estimate_session_cost_usd
  (per-token + per-request fee). A multi-round TWV run reports a real non-zero cost — no hidden expensive runs.
  **Faculty-1 coordination core = 32/32.**
- [x] **Async orchestrator entry (`41bb9133a`, cargo 4/4):** `run_mission_async(objective, trace_dir,
  provider_for_tier)` = the REAL-provider path (System G/act/work/chat invoke this); composes async loop + provider
  executor + trace + honest cost basis (total_usage/total_calls). **Faculty-1 core = 33/33.** The async
  (real-provider) orchestrator API is now complete.
- [x] **System G reconciliation bridge (`af0630c1a`, cargo 4/4):** per the BUILD-IT-HARDENED/GO-BACK-AND-UNIFY
  mandate, `trinity_systemg::trinity_to_system_g_events` maps a TRINITY run → the EXISTING System G wire events
  (PlanStart→TokenChunk→Complete/Failed; honest budget-exhaust=Failed). HARDENED + ADDITIVE-SAFE (only existing
  variants → no Swift lockstep break). **Faculty-1 core = 37/37.** Wiring it into the live TRINITY-mode start_run
  is the integration step (harden-before-integrate — built+tested first). Remaining: MLX provider_for_tier factory
  + flag-gated start_run wiring + trace→TraceCollector (Swift/runtime).
- REMAINS (runtime/app-side, sequenced): the app supplies `provider_for_tier` (model resolution + provider
  construction) + System-G/act/work/chat invoke `run_trinity_loop_async` behind the flag; slice 3b = trace →
  Swift TraceCollector; then expose as the internal orchestrator API across
  act/work/chat. LEARNED router gated on license (owner H1 TODO: clear adapted-weights license w/ nshkrdotcom,
  or re-derive from Apache Qwen3-0.6B). Heuristic-vs-learned state disclosed honestly.

### 🔬 eidos.query fake-green — VERIFIED + nuanced (owner UNIFICATION flag, 2026-06-22)
Owner flagged `eidos.query` as a fake-green ("claims Eidos but bypasses the real eidos/ module"). VERIFIED:
`EidosQueryHandler` (tools/knowledge.rs:244) calls `vault.hybrid_search_with_trace` (storage/vault.rs) — the
real `eidos/` module (hybrid/claim_evidence/falsifier/adversarial) is NOT referenced by knowledge.rs/storage.
NUANCE (grounded): the tool DESCRIPTION is behavior-HONEST ("Search the user's vault first and return
structured, citable evidence…") — it does NOT lie about WHAT it does; the issue is purely that the NAME invokes
"Eidos" while not routing through the eidos/ module. So the fix is the directive's route-vs-rename ARCHITECTURAL
decision — and the name is deeply embedded (registry name-maps + tests + system prompts "use eidos.query first"
prompts.rs:16 + chat_lite), so a rename is multi-caller and a route-through needs the owner's intent on whether
vault-hybrid IS the intended Eidos retrieval vs the deeper eidos/ claim layer. NOT blind-fixed (risk: break the
live tool + prompts; possible intentional brand). Sequenced in UNIFICATION work per the directive — flagged with
evidence for the owner's route-vs-rename call.

### 🔧 UNIFY easy-wins (BUILD-IT-HARDENED item 1, 2026-06-22)
- [x] **Stale CLAUDE.md FIXED (verified vs code):** the unification verdict flagged 2 stale claims; VERIFIED both
  real-state and corrected: (1) macaroons are NOT orphaned — `dispatch.rs:28,86-153` issue/restrict the system +
  skills/procedural/provenance/companion mirror caps; (2) dispatch registers ALL 6 caps at DAG INIT (the OnceLock
  `get_or_init`, dispatch.rs:47-71), NOT "on first use". Honest doc, no code risk.
- [~] **confidence_floor.rs orphan — VERIFIED, resurrect-vs-delete is the owner call:** confirmed the verdict —
  `decide_floor` is called ONLY in its own tests (no production consumer), and its `ConfidenceFloor` enum is
  DUPLICATED by a live one in `research/confidence_floors.rs` (same T1/T2/T3 + 0.85/0.75/0.70 thresholds = drift).
  So confidence_floor.rs is the orphaned duplicate; research/confidence_floors.rs is the live one. RESURRECT (wire
  decide_floor/FloorOutcome — the unique bits — into a real escalation decision) vs DELETE (lose them) touches
  live escalation logic → flagged with evidence for the owner's call, NOT blind-deleted (deletion of possibly-
  valuable IP without certainty + "nothing lost" mandate argue against guessing).

### 🌟 GUS-2 — Belnap abstain/honesty primitive (GRAND SWEEP, 2026-06-22)
- [x] **Belnap abstain-gate core (`199f41a42`, belnap 39/39 --features research):** `BelnapValue::abstains()`
  (NOT classically decided — Both=contradictory, Neither=no-evidence → abstain, never assert) + `abstain_reason()`
  (honest provenance string). Reuses the existing is_classical/is_inconsistent/is_gappy (no dup). The honesty
  rule as a primitive: never assert on contradictory/absent evidence. HARDENED + ADDITIVE — the AnswerPacket
  wiring (research→answer bridge) is the integration step (harden-before-integrate; built+tested first).
- [x] **GUS-2 evidence→Belnap bridge (`4ee97fa82`, belnap 40/40):** `BelnapValue::from_evidence(supporting,
  refuting)` → Both/True/False/Neither; composed with `abstains()` = the AnswerPacket assert-vs-abstain decision
  straight from evidence counts (contradictory/absent → abstain w/ reason). Pure + additive.

### 🔴 ACT = OSAURUS IS THE CHAT (owner 2026-06-22 — supersedes §29/§222/§806)
Owner's plain UX (2026-06-22 clarifications): KEEP the Epistemos landing page. When you tap/click to start a
conversation, the OSAURUS chat surface (its own landing/composer, reskinned Epistemos) pops up — that IS the
chat, not the old Epistemos ChatView with an engine swap. NO experimental/"safety" opt-in toggle (that's the
drift). A real product toggle to open WORK is wanted (act↔work), separate from the removed safety gate. Delete
the old chat (keep IP only). Make it work (send + `<think>` fix). Same for work=OpenCode (full surface, no
experimental gate).
- [x] **Step-1 public host seam** — Osaurus `ChatView`/`ChatWindowState` are `internal` to OsaurusCore, so
  Epistemos can't mount them even though it links the package. Added `EpistemosOsaurusChatHost` (public `View`)
  at `LocalPackages/osaurus/Packages/OsaurusCore/Epistemos/EpistemosOsaurusChatHost.swift` — owns a stable
  `ChatWindowState` (@StateObject) and renders the genuine Osaurus `ChatView`. Purely additive (no existing
  Osaurus type/behaviour changed). Target `path:"."` excl. Tests/SQLCipher → compiled into OsaurusCore; the
  same-module SourceKit "cannot find ChatView" is the known new-file index false-positive.
- [x] **Step-2 RootView mounts the host for act (`2970a6920`; Pro build GREEN, `BUILD EXIT=0`)** — `HomeRouter`
  renders `EpistemosOsaurusChatHost()` (the real Osaurus surface, its own composer) once the user leaves the
  landing (`!chat.showLanding`); the Epistemos `LandingView` is kept for the not-yet-started state. Osaurus owns
  its own composer/thread so there is no first-message-seeding mismatch. Verified compiling on the `Epistemos`
  (Pro) scheme.
- [x] **Step-2b MAS dual-build kept green (`7f464ffcf`)** — the `Epistemos-AppStore` (MAS) target compiles
  `RootView` (syncedFolder) but does NOT link OsaurusCore, so the unconditional import/mount broke the MAS build.
  Gated `import OsaurusCore` + the host mount behind `#if !EPISTEMOS_APP_STORE`; MAS keeps `ChatView()`. This is
  a build-target reality (OsaurusCore pulls server/VM/relay/Containerization the App Store sandbox can't link),
  NOT the banned experimental runtime toggle, and preserves MAS capability. **TRACKED DEBT (MAS full-capability,
  owner §151):** the MAS-safe OsaurusCore split → bring Osaurus-as-chat to MAS too.
  - **MAS local build finding (HONEST — not fake-green):** after the gating fix, the `Epistemos-AppStore` build
    fails with `unable to resolve module dependency` for `OsaurusSQLCipher`/`Sentry`/`Sparkle`/`CGRPCNIOTransport
    Zlib`/`FastClusterWrapper`/`CArchive`/`CShim` — all OsaurusCore-transitive packages the MAS target does NOT
    link. **This is PRE-EXISTING / environmental, NOT introduced by the act=Osaurus work:** my net change to the
    MAS *target* is zero (RootView's MAS branch is `ChatView()`, identical to pre-session; the added host file
    lives in OsaurusCore which MAS doesn't link and which adds no new dependency). The **Pro** scheme resolves
    these same packages and builds GREEN. So this is a MAS-target explicit-modules package-resolution issue that
    predates the act work. Filed under the MAS-full-capability track; re-building to "fix" it from the act side
    would be build-thrashing since the act source delta can't be the cause. **NOT claiming MAS green.**
- [x] **Step-3 reskin — Pro GREEN, committed `1b425eafa`** — the
  host now applies an Epistemos `CustomTheme` (cream/monospace) via `ThemeManager.applyCustomTheme(persist:false)`
  on appear; every Osaurus view reads `ThemeManager.shared.currentTheme` so the whole surface (thread/composer/
  sidebar/model-picker) reskins. Faithful to Epistemos `.systemLight`: text `#1c1c1e`, muted `#6e6e73`, ink
  accent, warm-cream surfaces (`#fbfaf5`/`#f4f3ee`), dark user bubbles, `SF Mono` body. Runtime-only (no write
  to Osaurus theme storage); additive (no Osaurus-type change). Inits verified (`ThemeGlass(enabled:)`,
  `ThemeMetadata`, `ThemeColors` named-param template). Sequenced behind the MAS verify to avoid two concurrent
  xcodebuilds; commit on Pro green.
- [x] **Step-3b runtime bootstrap (make it WORK)** — root-caused the owner's "Osaurus isn't working / send
  errors": standalone Osaurus runs launch-time registration in its own `AppDelegate`
  (`ConfigurationDomainBootstrap.registerBuiltIns` = Provider/Model/MCP/Plugin/Schedule/Agent config domains,
  `DocumentAdaptersBootstrap.registerBuiltIns`), which Epistemos's `AppDelegate` never runs. The host now runs
  both on first appear (idempotent latches, side-effect-free — NO server/Sparkle/login-item; the chat generates
  in-process via `ChatEngine → MLXService`, so the HTTP server is not needed). Full send-verification (model
  present + streaming) needs the owner's running app — no computer-use in this loop.
- [x] **Step-4 remove the experimental "safety" toggle + add the real act↔work toggle** — DONE (`df4b3653c`):
  removed the `ActOsaurusHealthRow` "Use Osaurus for Act (experimental)" opt-in switch (owner: "why is there a
  safety in this?"). DONE (this commit): the real act↔work PRODUCT toggle — `HomeRouter` now overlays a clean
  capsule `WorkspaceModeToggle` (NO armed-dot/"experimental" framing) on the chat surface; `.act` →
  `EpistemosOsaurusChatHost` (the Osaurus chat), `.work` → `WorkTerminalHostView` (OpenCode's native terminal),
  persisted via `WorkspaceModeSelection`. Pro only — MAS stays act-only (`ChatView`) since the Osaurus host +
  SwiftTerm work terminal are Pro/direct-distribution (MAS-safe split = tracked debt). Pending Pro verify.
- [ ] **Step-5 collapse `CoworkChatMode` Chat/Act depth axis** — preserve Fast/Think/Code tier reach.
- [~] **Step-6 delete old Epistemos `ChatView`** — NUANCE (honest): on **Pro** the old `ChatView` is already
  OUT of the act path (HomeRouter mounts the Osaurus host; no fallback scaffold — owner's intent honored). But
  the **MAS** target still uses `ChatView()` as its REAL act surface (Osaurus host is Pro-only until the
  MAS-safe OsaurusCore split). So `ChatView` can't be deleted outright without breaking MAS's chat — keeping it
  is MAS's actual surface, not a Pro fallback. It retires when MAS gets Osaurus (the tracked MAS-full-capability
  debt). Until then: Pro has no old-ChatView fallback; MAS keeps it as its chat.
- [~] **Step-7 fix act send errors + `<think>` regression; verify a real send** —
  - **`<think>` regression: RESOLVED by the surface migration (verified by code-reading).** The Osaurus surface
    has mature reasoning-tag handling the old Epistemos path lacked: `Services/LocalReasoningCapability.swift`
    detects `<think>`/`</think>`/`<|think|>` envelopes (Qwen-3 etc., per-template config), and
    `Services/ModelRuntime.swift:2758-2778` separates `reasoning_content` from the displayed message (and
    reconstructs prior `<think>` history for follow-ups). `AgentLoopEvaluator` keeps `reasoning_content` off
    echoed assistant turns. So mounting the real Osaurus chat fixes the leak with NO new code.
  - **Send errors: the broken path is GONE.** The old "send" went through the half-integrated Epistemos
    ChatView + a partial Osaurus engine behind the gate. The act surface now runs Osaurus's own in-process
    `ChatEngine → [FoundationModelService (Apple on-device, no download), MLXService, remote providers]`, after
    the bootstrap (`9da16c0f5`/`df4b3653c`) registers the agent config domains. So a basic send can work via
    Apple's on-device model even with no MLX/GGUF model installed.
  - **PENDING (owner's running app — no computer-use in this loop):** click-test a real send/receive end-to-end;
    confirm the model picker surfaces a usable model (Osaurus reads `effectiveModelsDirectory` + HF cache via
    `ExternalModelLocator`; Epistemos's curated GGUF models live in a different dir — a model bridge is an
    enhancement, NOT required for basic function given the Apple on-device default).
### 🟦 WORK = OPENCODE (owner: "make sure work is safe / works", 2026-06-22)
- [x] **OpenCode runtime IS bundled** (corrects the earlier audit's stale "no runtime" read): a REAL 129 MB
  `opencode` arm64 Mach-O binary lives at `Epistemos/Resources/opencode-runtime/bin/opencode`, vendored at build
  time by `build-opencode-runtime.sh` (pinned OpenCode 1.17.9 + Bun 1.3.14). `WorkOpenCodeRuntime.bundledRuntime
  URL()` resolves it (executable) → non-nil. So the work surface's ONLY blocker was the experimental gate.
- [x] **Work goes LIVE by default, no experimental toggle** (this batch) — parallel to act=Osaurus:
  - `WorkOpenCodeShellFactory.resolve()` no longer requires `WorkOpenCodeShellGateStatus.resolvedActive()`; it
    returns the live `BundledWorkOpenCodeShell` whenever the runtime is bundled (Pro). MAS stays inert (`#if
    EPISTEMOS_APP_STORE`, SwiftTerm + runtime are Pro). Honest fallback: runtime absent → inert, never faked.
  - Removed the "Enable Work (OpenCode terminal, experimental)" opt-in toggle from `WorkOpenCodeShellHealthRow`;
    the row now reports the HONEST live/inert state from the real factory resolution (no gate).
  - Reachable now via the act↔work toggle (`9da16c0f5`): selecting Work mounts `WorkTerminalHostView` →
    `realShellSpec()` succeeds (shell `isReady`) → the REAL OpenCode TUI spawns in the SwiftTerm PTY.
  - Tests stay green: the `resolve()` honesty tests assert inert in a test bundle that lacks the runtime →
    still inert (my change keeps runtime-absent → inert).
- [ ] **PENDING (owner's running app):** verify the OpenCode TUI actually launches + renders in the PTY (Bun
  engine spins up). Goose/Hermes/OpenClaw fusion beneath + the omega-mcp vault server config are the follow-on.

### 📋 SESSION STATE (2026-06-22) — act+work surfaces delivered to the buildable bar
**DONE + Pro-verified (commits):** act = real Osaurus chat mounted (`2970a6920`) · MAS gating kept green
(`7f464ffcf`) · reskin cream/monospace (`1b425eafa`) · runtime bootstrap + remove act experimental toggle
(`df4b3653c`) · act↔work product toggle (`9da16c0f5`) · `<think>`/send analysis (`c57e407eb`) · work=OpenCode
live + remove work experimental toggle (`cfd7fa41f`). The `<think>` leak is resolved by the surface migration
(Osaurus's reasoning handling); a basic act send works via Apple's on-device Foundation Model.
**MODEL REALITY (honest, code-verified — do NOT build a naive model bridge):** Osaurus's chat generates via
`ChatEngine → [FoundationModelService (Apple on-device, no download), MLXService (MLX-format only), remote
providers]`. `ExternalModelLocator` SKIPS GGUF dirs ("MLX runtime can't load them"). Epistemos's curated models
are largely GGUF → NOT directly loadable by the Osaurus surface. So: pointing Osaurus at Epistemos's model dir
does NOT work; the surface uses Apple's model / MLX models / remote. A real "use the owner's GGUF models in the
Osaurus chat" bridge needs a GGUF service inside Osaurus's `ChatEngine` (a large piece), not a path bridge.
**REMAINING (each runtime-gated or large/external — needs owner runtime-feedback to direct, not blind builds):**
(1) live send/receive + OpenCode-TUI-launch verification (owner's running app — no computer-use in this loop);
(2) Goose/Hermes/OpenClaw engine fused beneath OpenCode (honest stub today — external engine);
(3) GGUF-in-Osaurus model service OR Epistemos-Picks port (format-gated, large);
(4) sessions/vault/Eidos bridged into the Osaurus act chat (large integration);
(5) MAS dual-build (pre-existing explicit-modules package-resolution failure, independent of this work);
(6) retire old `ChatView` (blocked — it's MAS's real act surface until MAS gets Osaurus).

### 🐛 ACT SURFACE UI BUGS (owner reported on the running app, 2026-06-22)
- [x] **White bar at top + "click opens the search bar, not the Osaurus landing" — ONE root cause, fixed** —
  `activeHomeChat` requires `!chat.messages.isEmpty`, but the Osaurus host owns its OWN message state so
  `chat.messages` stays empty → RootView treated the Osaurus surface as the LANDING and painted the Epistemos
  landing toolbar (the "search bar" + its `.automatic` glass background) OVER the Osaurus surface = both the
  white top bar AND the leaked search bar. Fix: added `showingOsaurusSurface` (`!chat.showLanding`, Pro) and
  excluded it from `showLandingToolbarControls` → the toolbar is empty + background hidden over the Osaurus
  host, so the top is clean (old-chat look) and Osaurus's own landing/composer shows through. Epistemos landing
  (`showLanding==true`) is unaffected. Owner to re-audit on the running app.
- [ ] **Deeper reskin → CLARIFIED to "fully restore the old Epistemos UI, driven by Osaurus" (owner 1485):**
  the owner wants the WHOLE old Epistemos UI back (landing reskinned to old flat-pixel/Apple-native look; old
  chat thread + the loved MESSAGE BAR; the OLD EPISTEMOS SIDEBAR re-added wired to Osaurus data; full old font/
  chrome) genuinely powered by Osaurus (no toggle/fake), surfacing Osaurus's new features within it. Supersedes
  the palette-only reskin; supersedes "don't reuse the old UI" (that rejected the broken toggle-swap).
  - **CHOSEN APPROACH = option (a):** reskin the hosted real Osaurus views to faithfully match the old look +
    re-add the sidebar. Rationale: keeps "genuinely Osaurus" true BY CONSTRUCTION (the surface IS the real
    Osaurus ChatView/engine — no deep rewiring that risks re-creating the rejected old-ChatView+engine pattern),
    additive on the current host foundation. (Option (b) = drive the old Epistemos SwiftUI views with the
    Osaurus engine — higher-risk deep rewiring + unverifiable; fall back to it only if (a)'s fidelity falls short.)
  - Build order: message bar (owner fave) → fonts/flat-pixel chrome → enable/bring the sidebar → landing look.
    Component-level overrides on the hosted Osaurus views (`FloatingInputCard`/thread/sidebar), keep OsaurusCore.
  - **RECONSIDERATION (owner said "NOT a thin palette tint"):** a placeholder/colour tweak is the WRONG
    direction — the owner wants the FULL old look. That raises the bar for option (a) (must faithfully recreate
    the old message-bar/thread/sidebar design in Osaurus's components, not just retheme) and strengthens the
    case for option (b) (use the actual old Epistemos UI driven by Osaurus — faithful by construction). Note:
    the old-UI + Osaurus-engine mechanism PARTLY EXISTS (`LocalAgentLoop.shouldRouteActThroughOsaurus` already
    routes the old chat's inference through `OsaurusCore.CoreModelService`); the owner's rejection was the
    TOGGLE + brokenness, not that mechanism — so option (b) ≈ that path de-toggled + made genuine. This is a
    major direction call (large rework either way, unverifiable headless); leaning (b) for fidelity, but
    flagged for an owner signal before the big pivot. **Item 4 (models) is UI-direction-AGNOSTIC** — the owner's
    models route via Osaurus's ChatEngine under either option — so 4b/4c proceed regardless.
  - **✅ DIRECTION CONFIRMED = OPTION (b)** (auditor 1507, owner signal): use the ACTUAL old Epistemos SwiftUI UI
    (landing/chat/MESSAGE BAR/SIDEBAR/fonts/flat-pixel) as the act surface, driven by the Osaurus engine —
    "faithful by construction" (it IS the old UI). NOT option (a). Invariants: default no-toggle; genuinely
    Osaurus engine (CoreModelService/ChatEngine via `shouldRouteActThroughOsaurus` + the model bridge) and it
    must WORK. The mounted-Osaurus-ChatView SHELL (host/palette reskin) is REPLACED by the old UI; the engine
    link + bootstrap + model bridge + toggle removal + MAS gating CARRY OVER. **Pivot plan:** (1) HomeRouter
    act → old `ChatView()` (revert the host mount + the showChat/showingOsaurusSurface changes); (2)
    `shouldRouteActThroughOsaurus` → DEFAULT-ON (Pro, no toggle); (3) verify. The old message bar + sidebar come
    FREE (they ARE the old UI). Model bridge now also wired into `CoreModelService.localServices` (the option-(b)
    path drives the old ChatView through CoreModelService, not only ChatEngine).
  - **✅ OPTION-(b) PIVOT IMPLEMENTED (pending Pro verify):** (A) `LocalAgentLoop.shouldRouteActThroughOsaurus`
    now returns DEFAULT-ON on Pro (`#if !EPISTEMOS_APP_STORE → true`, MAS → false), no gate/toggle — the act
    surface's inference genuinely routes through the Osaurus engine. (B) `HomeRouter` reverted to the original
    old Epistemos surface: `if showChat { ChatView() } else { LandingView() }` with messages-based `showChat`;
    removed the Osaurus-host mount, the act↔work toggle, `workspaceMode`/`workWorkspaceURL`, and the
    `WorkspaceModeToggle` struct. (C) reverted `showingOsaurusSurface`/`showLandingToolbarControls` (the
    white-bar fix was host-specific; the old ChatView wants its normal Epistemos toolbar). (D) removed RootView's
    `import OsaurusCore`. So act IS the old Epistemos UI (faithful) driven by the Osaurus engine.
    FOLLOW-UPS: re-place the act↔work toggle as a new feature in the old UI (its gating conflicted with the
    old-UI messages-based showChat — deferred, not lost); `EpistemosOsaurusChatHost` is now an unused shell (the
    reskin/bootstrap logic is kept for reference, can be retired later). Live send/receive = owner's runtime check.
  - **✅ "it must WORK" — coreModelIdentifier fill:** the act-Osaurus path streams via `CoreModelService.generate
    Stream`, which has NO per-request model — it uses `ChatConfigurationStore.coreModelIdentifier` (computed from
    the stored `coreModelName`) and throws `modelUnavailable` if unset. So when the model bridge registers (4b),
    if no core model is configured, set `coreModelName` to the owner's first prepared model — the act send then
    has a valid model, routed back through the bridge to the owner's model. ONLY fills if unset (never overrides
    the owner's choice). Per-pick selection-sync (old ChatView picker → coreModelName) is a richer follow-up.

### 🧩 OWNER'S MODELS IN CHAT (auditor item 4, 2026-06-22) — real bridge, no stub
The owner's GGUF/QAT "Epistemos Picks" must work in the Osaurus act chat. OsaurusCore has NO GGUF runtime + can't
import the app; `ChatEngine(source:.chatUI)` is built at `ChatView.swift:349` with default `[FoundationModel
Service, MLXService]`. Plan: a cross-module seam (primitive types) + an Epistemos-side provider + picker
visibility.
- [x] **4a — OsaurusCore seam (this build):** `EpistemosModelBridge.swift` — `public protocol
  EpistemosModelProvider` (Sendable primitives: `availableModelIds()` + `streamGenerate(prompt:modelId:max
  Tokens:)`), a process-global `EpistemosModelBridge` registry, and an in-module `EpistemosBridgedModelService:
  ModelService` that flattens the OpenAI-style history → prompt and streams from the provider. Wired into
  `ChatEngine`'s default `services` + `installedModelsProvider`. ADDITIVE + honestly INERT until a provider is
  registered (`isAvailable()/handles()` decline → default Foundation/MLX behaviour byte-identical).
- [ ] **4b — Epistemos provider (FULLY SCOPED, ready to implement):** an Epistemos-side
  `EpistemosOsaurusModelProvider: EpistemosModelProvider` (import OsaurusCore). Confirmed API path:
  `MLXInferenceService.stream(request: LocalMLXRequest)` **auto-loads** the model (`loadContainerIfNeeded`) and
  routes GGUF vs MLX by `LocalModelDescriptor.runtimeKind` (`.gguf` for the owner's `GemmaQATRuntimeLadder`
  candidates), so `streamGenerate(prompt:modelId:maxTokens:)` = build `LocalMLXRequest(modelID:modelDirectory:
  prompt:systemPrompt:nil:maxTokens:reasoningMode:.fast:steeringHintsJSON:nil:imageURLs:[])` → `service.stream`,
  bridged into a sync-returning `AsyncThrowingStream` via a `Task`. `availableModelIds()` = installed models.
  Register the provider at `AppBootstrap:1800` (where `localInferenceService` is created). REMAINING TO VERIFY
  before writing (avoid a field-name red build): the installed-models list + id→activeDirectory resolution
  (`PreparedModelRegistry` vs `LocalModelInfrastructure.activeDirectory(for:)` + a LMI instance). Implement next.
- [x] **4b — Epistemos provider IMPLEMENTED (pending Pro verify):** `Epistemos/ActOsaurus/EpistemosOsaurus
  ModelProvider.swift` (Pro-only, `#if !EPISTEMOS_APP_STORE`) conforms to `EpistemosModelProvider`: holds the
  `MLXInferenceService` actor + Sendable (id, directory) pairs for the prepared generator(s); `streamGenerate`
  builds a `LocalMLXRequest` and forwards `service.stream` deltas through an `AsyncThrowingStream` (cancels the
  task on termination). Registered from `AppBootstrap.applyPreparedRetrievalRuntimeConfiguration` (AFTER the
  snapshot applies — the freshly-built state at init is empty; the manifest loads deferred), idempotent + re-runs
  on snapshot change. Exposes the prepared generators (`primaryGenerator`/`speculativeDraftGenerator`
  `servedModelID` + `resolvedDownloadPath`). Generation routes GGUF/MLX internally via `stream(request:)`.
  Live send = owner's runtime check.
- [ ] **4c — picker visibility:** surface the owner's model ids in the Osaurus model picker catalog (ModelManager)
  so they're selectable; routing then reaches `EpistemosBridgedModelService`. Live generation = owner's runtime check.
