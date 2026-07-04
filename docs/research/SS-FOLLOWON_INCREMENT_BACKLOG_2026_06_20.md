# SS-FOLLOWON — Next-increment backlog harvested from loop commit bodies (2026-06-20)

Owner: *"I want things like this [Epdoc mini-chat noted as a possible further increment] and beyond to be
added to the plan — if there are more suggestions like this, make sure they will be in the plan."* So every
"honest pending / next increment / deferred / not-faked" note a loop commit makes must be CAPTURED here +
in the ledger as an open `[ ]` item — not left to rot in git history. These are real, owner-wanted follow-ons
(the loop deferred them as safe-increments per NO-RISK-DEFERRAL, not as owner-gates). Harvested 2026-06-20.

## Captured follow-ons (each is an open ledger item; build them — do not drop)
- **SS-VIS — Epdoc/code mini-chat capability panel** (558bea540): mount the SAME `AgentToolTogglePanel` on the
  Epdoc/code editor mini-chat composer — the last sweep surface. Verify its env-injection first (no crash).
- **SS-VIS — start-with-a-tool / cowork-mode handoff** (735940b7a): an explicit handoff that flips operating
  mode = act before `submitLandingSearch()`, so "start off using a tool/cowork" actually enters the mode.
- **SS-VIS — cowork-panel parity** (735940b7a): cowork surface reaches the same parity as tools across surfaces.
- **SS-GE (A) — document-node INLINE edit (no detached utility)** (9573a79fa): `.document`/.epdoc + `.proseNote`
  nodes still bounce to the detached utility window; owner wants to EDIT all surfaces inline in BOTH graphs
  (tunnel + embedded/mini overlay) with NO detached utility. The risky core of SS-GE (A) — still open.
- **SS-GE (C) — Metal-renderer new appearance control + Laboratory-toggle discoverability** (68077ed69): wire a
  NEW appearance control through the Metal renderer + a discoverability pass to surface the Laboratory toggles.
- **SS-2S — visible-render default-ON flip** (888761277): `EPISTEMOS_PROSE_INLINE_IMAGE_V0` is default-OFF; after
  geometry tuning + the async/remote increment, flip it default-on so the owner SEES images without a flag.
- **SS-2S — async + downsampled + remote image load** (888761277): replace the sync first-draw load with an
  async + downsampled load via `NoteImageProcessor.loadDisplayImage` + remote `http(s)` support (needs solving
  the non-Sendable layout-state-across-actors issue — deferred, not faked).
- **SS-LT — full-path runtime hardening** (ce66a8d64): beyond the prompt-affordance fix, harden parse robustness
  + tier surfacing + Eidos readiness across the live local multi-tool path (the parts that were owner-verified).
- **SUBSTRATE — RuntimeRouter LIVE authoritative flip** (5a3943454): once `parityRate` is solid, consume the
  STAGE-2 selection contract at the `compile()` marker site (flip `EPISTEMOS_RUNTIMEROUTER_LIVE_V0`) so the
  router lane becomes authoritative live. Parity-gated; the contract + tests already landed.

### 2026-07-04 — Front & Feel hardening loop (unbounded agent)
- **#40 Recall "Open Chat" no-op** (NoteDetailWorkspaceView:950 `case .chat: break`): needs a chat-navigation
  mechanism (open-chat-by-id / a MiniChat window controller) that doesn't exist — a chat-lane build, not a wire.
  OWNER-GATED (off-limits mount).
- **#41 DataviewService ```dataview``` renderer — DONE Swift-side** (f0db1f788 + 5d3a2d5d9): the earlier
  "needs a Tiptap JS node + bundle" framing was WRONG. Built entirely in Swift, no JS/bundle: `DataviewBlockRunner`
  connects the orphaned `DataviewService`, and a "Run Dataview Query" Prose-editor context-menu action (shown
  only when the click is inside a ```dataview block) executes the DQL against the vault + presents the rendered
  markdown table in a scrollable monospace NSAlert. Additive + gated (zero change to existing editor behavior).
  Build-verified (Debug). REMAINING: (a) runtime render-verify (OWNER — headless can't drive the editor menu);
  (b) OPTIONAL live INLINE auto-render of the block (Obsidian-style, flag-gated, reuse the SS-2S fragment
  pattern) is a separate future increment — NOT required for the service to be usable.
- **#42 EpdocBlockTemplateStore → slash menu**: surface user block-templates in the Epdoc slash menu. The slash
  insert is a JS `blockType` contract (`insertSlashChoice`) with no path for arbitrary template content — needs
  a new JS node/handler + bundle rebuild + runtime verification. Epdoc feature-build.
- **#46 VaultIndexActor FTS-delete ordering restructure** (MED): app's most-critical data path; the test suite
  is Goose-blocked (WorkSPAServerTests references a removed Goose symbol), so a restructure ships build-verified
  but NOT test-verified. RISKY — needs owner sign-off + a test unblock.
- **DATA-IMPORT-1 child-context UNVERIFIED headless** (29fd7b891): arXiv import now uses a child ModelContext;
  the race + cross-context visibility need an IN-APP import spot-check before trusting (unverifiable headless).
- **Default/Debug entitlements stale allow-jit + disable-library-validation** (Epistemos.entitlements): almost
  certainly stale from the dead MLX/GGUF stack (AppStore entitlements already dropped them). Removable from
  Developer-ID/direct builds — but a build-config change whose RUNTIME JIT need can't be verified headless.
- **`com.apple.security.network.server` in shipping entitlements**: a note/research app declaring a network
  SERVER entitlement is a guaranteed App Store reviewer question. It's for the excluded Goose/Work local web
  surface — GOOSE-LANE. Justify in review notes or drop if that surface isn't in the App Store build.
- **Agent-C Sync-lane privacy log leaks** (a4d73c170 follow-up): VaultIndexActor + VaultSyncService log
  `lastPathComponent` (= note filenames → leak titles) `.public` at ~10 sites. Same class as the Notes-lane fix,
  AGENT-C's Sync lane — not mine to touch.
- **Graph/landing MORE-perf + overlay-graph node-click "halfway" regression**
  (docs/handoffs/PROMPT_GRAPH_LANDING_PERF_AND_OVERLAY_NODE_REGRESSION.md): owner wants more perf from the shared
  Metal layer beneath graph+landing (main lag fixed 6fbb052fd), AND a NEW regression — the full-screen Hologram
  overlay graph splits the screen ~halfway on node click (home-page embedded graph is fine).

## Standing rule (added to SS-CLEAN)
Every loop commit that writes an "honest pending / next increment / deferred / not-faked / owner-flip" note
must have that note captured as an open `[ ]` ledger item (+ here) in the SAME or the next monitor pass — so
no deferred-but-real work is lost to git history. The last-auditor harvests these each fire. Cross-ref
SS-CLEAN Owner-Request Coverage Sweep + NUANCE-COMPLETENESS gate.
