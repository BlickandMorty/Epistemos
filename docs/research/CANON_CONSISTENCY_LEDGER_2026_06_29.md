# CANON CONSISTENCY LEDGER (the "check doc") — 2026-06-29

> **THE single doc to open to confirm the canon is still consistent during implementation.** The Auditor agent
> (`docs/prompts/PROMPT_AUDITOR_LOOP.md`, cron) re-runs every check below each cycle, updates the STATUS column,
> reconciles confident drift (adds a SUPERSEDED banner / inline `[DELETED]` marker — NEVER deletes a doc, NEVER
> touches code or another agent's uncommitted work), and flags anything ambiguous under "OWNER REVIEW." Owner: scan
> the STATUS column — all ✅ = canon coherent; any ⚠️ = drift the Auditor caught (read its note).

**Last auditor pass:** 2026-06-29 23:35 CDT (loop cycle 52) — **10/10 ✅**, 0 drift. Kill-list audit workflow `wf_22a0bafe` still running (authoritative REMOVED_FEATURES doc pending its result). Still not-safe-to-rebuild (10 dirty Goose/HTMLWS, no new commits). Guardrails from cyc51 holding. _(cyc51 below)_
<br>**cyc51:** 🛑 **PREVENTED RECURRENCE (owner: "why was Plan 2 working on removed stuff — make sure it doesn't happen again"):** mechanism = the `LOST_ITEMS_RECON` *salvage* workstream ROUTES salvaged items INTO plans (Plan-2 prompt has a "[salvaged from LOST_ITEMS_RECON]" item; a salvage commit "route crash fix to Plan 2") — that's the vector that polluted Plan 2. FIX: (a) top banner on `LOST_ITEMS_RECON` = "salvage ≠ resurrect owner-removed; never route triage/raw-thoughts/old-agent/chat-transcript into ANY plan"; (b) HARD STAY-IN-LANE + reject-resurrected guardrail added to `PROMPT_PLAN_2`. (Can't attribute commits to terminals — all one git identity — but the salvage *mechanism* is fixed.) Kill-list workflow `wf_22a0bafe` running for the comprehensive list. Resurrection markers holding (no NEW triage/raw-thoughts in fresh code). ⛔ **STILL NOT-SAFE-TO-REBUILD:** 27 dirty code files (10 Goose/HTMLWorkspace), no new commits — agents deep in real WIP but no clean checkpoint yet; regenerate still `isLive:false`. Auditor will signal "rebuild now" when tree goes clean + regenerate flips live. **4 OWNER REVIEW** (Companion-v1.6; white-screen [blocked on clean rebuild]; systemic pattern [RESOLVED cyc43]; resurrection [owner: confirm full kill-list + task a build agent to delete residual RawThoughts/triage code]). HEAD at pass: `6ff9311db`.
<br>_Recent: cyc43 (owner-directed) baked the REAL-WORK-FIRST/HARDENING-CAPPED WORK-ORDER directive into PROMPT_PLAN_1/2/3 + added AGENT_LOOP_WRAPPERS_REAL_FIRST (canon-safe, 10/10). cyc32 vetted the white-screen P0 + MAS-in-process-backend canon edit (Option-1-reinforcing). cyc8 strengthened check #4 to all 4 springs. cyc2 made #6/#8 greps honest._

## INVARIANTS (the locked truths — each agent's docs must agree with these)
Run each `Check` from repo root; the Pass condition is what a consistent canon returns.

| # | Invariant (locked) | Check (grep) | Pass | STATUS 2026-06-29 |
|---|---|---|---|---|
| 1 | **NO native chat** (Option 1) — chat stays WebView, reskinned; native = frame + Models picker only | `grep -rniE "useNativeChatPath *= *true\|build native (chat\|transcript)\|chat-primary flip" docs/ \| grep -viE "DELETED\|SUPERSEDED\|HISTORICAL\|NOT\|no native\|do not\|ignore\|audit\|flag\|reskinned"` | empty (all residuals now HISTORICAL-marked or are correct "NO …" negations) | ✅ (FOLLOWON Step-9 struck; MASTER:129 HISTORICAL-marked; MASTER:4 = correct banner negation, excluded) |
| 2 | **§7 GREEN-LIT** — no live sign-off gate; Plan 1 on Phase 1 | `grep -rniE "DO NOT start.*Agent.*until.*§7\|Phase 0 (is )?NOT signed\|wait for.*§7 sign-off" docs/ \| grep -viE "SUPERSEDED\|HISTORICAL\|green-lit\|does not wait\|do not wait\|do NOT treat\|stale\|audit"` | empty (5 Phase-0 docs bannered; stale lines HISTORICAL-marked) | ✅ (CONTINUATION:25 HISTORICAL-marked; EDITOR_CANONICAL:290 = correct "does not wait" negation, excluded) |
| 3 | **Models picker = the ONE native route** (carve-out present) | `grep -rniE "no native picker\|pickers = WEB" docs/ \| grep -viE "EXCEPT\|carve\|Models picker IS\|one native route\|audit"` | empty | ✅ |
| 4 | **Spring values = the 4 canonical** (identical everywhere) | `grep -rohE "\.(smooth\|snappy\|bouncy\|interactiveSpring) \{[0-9.,]+\}" docs/ \| sort -u` | exactly 4: `.bouncy {0.5,0.3}` `.interactiveSpring {0.15,0.14}` `.smooth {0.5,0}` `.snappy {0.5,0.15}` | ✅ (cycle 8: STRENGTHENED — old grep validated only `.smooth`, leaving 3 springs unguarded/false-green; new grep returns exactly the canonical 4. Doctrine defines them backticked at lines 51-52; bare-form values live in GOOSE_NATIVE_WEB_RESKIN + EDITOR_CANONICAL_PLAN. 0 drift.) |
| 5 | **Two token sources only** — `EpistemosTheme.swift` (Swift) + Goose `theme-tokens.ts` (web); no third | grep the doctrine "Two token SOURCES" rule is intact + no rival source named | rule present | ✅ |
| 6 | **Graph = DO NOT TOUCH** (already full AppKit/Metal) | `grep -liE "graph.{0,60}do not touch" docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md docs/prompts/PROMPT_PLAN_1_GOOSE.md docs/prompts/PROMPT_PLAN_2_EDITOR.md docs/prompts/PROMPT_PLAN_3_CAPABILITIES.md` | all 4 files (doctrine + 3 prompts) listed | ✅ (cycle 2: doctrine carries it at lines 22 + 95; switched to case-insensitive grep — the old case-sensitive `GRAPH`/`graph` pattern false-negatived the doctrine's "Graph =", though the rule was present all along) |
| 7 | **Lens model** Note(Epdoc)/Source(MarkEdit)/Prose(TK2); **old code editor KEPT as v1 legacy** (no deletion); MD-nav = Note default→Prose→Source-button→full-MarkEdit | `grep -rniE "delete the 3 old\|old code-editor files were deleted" docs/research/EDITOR_CANONICAL*.md docs/research/MARKEDIT_EMBED*.md \| grep -viE "SUPERSEDES\|PRESERVED\|KEEP\|legacy"` | empty (the only hit is the line ENFORCING "v1 PRESERVED", excluded) | ✅ |
| 8 | **Retheme-not-replace** (Goose's existing shadcn/Radix/Tailwind/framer-motion) | `grep -liE -e 'retheme' -e "don'?t replace" -e 'do not replace' docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md docs/research/GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md docs/prompts/PROMPT_PLAN_1_GOOSE.md` | all 3 files (doctrine + reskin + Plan-1) listed | ✅ (cycle 2: doctrine carries it at line 82 "retheme … + tune" + line 85 "blend, don't replace"; replaced the prose check with a concrete grep that surfaces all 3) |
| 9 | **Active fleet paste = `PROMPT_PLAN_1/2/3`** (Plan 4/5 SAVED-not-active); every other "prompt"-named doc is bannered/not-the-paste | `for f in docs/handoffs/*PROMPT*.md; do grep -qiE "SUPERSEDED\|DO NOT PASTE\|HISTORICAL" "$f" \|\| echo "UNBANNERED: $f"; done` → empty · AND `for f in docs/prompts/PROMPT_PLAN_[4-9]_*.md; do grep -qiE "SAVED\|NOT YET ACTIVE" "$f" \|\| echo "UNGATED: $f"; done` → empty | both empty (handoff PROMPT docs bannered; new Plan-4/5/6/7 carry SAVED/NOT-ACTIVE gates) | ✅ cycle 11: owner introduced `PROMPT_PLAN_4_ICONS` + `PROMPT_PLAN_5_COMPANION` (docs/prompts/) — both gated SAVED/NOT-ACTIVE, drafted to 1/2/3 strictness, auditor-verified Option-1/two-token/graph/retheme compliant (see "NEW PLANS" §). ACTIVE paste set unchanged = 1/2/3. (Prior: ~50 archival paste-prompt hits parked in OWNER REVIEW, not a fleet risk.) |
| 10 | **Accent #0066cc · SF Pro · radius 11** consistent | `grep -rohE "#0066cc" docs/ \| wc -l` (>0, no rival accent) | consistent | ✅ (cycle 23 DEEP-verified all 3 facets: accent #0066cc consistent, no rival; **radius** base 11 canon + faithful per-component macOS 8px segmented / 9px popup-menu (reskin:218/220) — NOT rivals; `radius 0` = Goose donor sharp-corners being fixed→11 (reskin:155); **font** SF Pro/SF Mono/-apple-system only, no rival — the "Inter" inventory hits were substring noise (interruptible/interactive). No grep added: per-component radii + substring collisions would false-positive.) |

## Stale docs that are BANNERED (mitigated, kept for nuance — do NOT delete)
GOOSE_AGENT_APPKIT_FOLLOWON_PLAN · GOOSE_MASTER_BUILD_PROMPT · GOOSE_PHASE_0_STATUS_AUDIT · GOOSE_PHASE_0_VERIFICATION ·
GOOSE_PHASE_0_OWNER_SIGNOFF_CHECKLIST · GOOSE_PHASE_0_CONTINUATION_PROMPT · GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND1/2 ·
GOOSE_APPKIT_SURFACE_MAPPING · CLAUDE_IMPLEMENTATION_PROMPT_FULL_CLONE_INFUSION_2026_06_24 (stale 06-24 full-clone/Osaurus
paste-prompt; bannered 2026-06-29) — each has a top SUPERSEDED-2026-06-29 banner; their bodies are HISTORICAL.

## NEW PLANS 4–7 (owner-saved 2026-06-29, NOT active — auditor-tracked, canon-compliant)
The owner drafted four further plans to the same strictness as 1/2/3 and **parked them** (commits `a6681941a`,
`e240a6cc9`, `c9a031410`, + expansions). All carry a top "🛑 SAVED / NOT YET ACTIVE — do NOT launch until owner says go"
banner (auditor #9 sub-check covers `PROMPT_PLAN_[4-9]`). **They do NOT change the active fleet (still 1/2/3); paste them
only on owner go.** Auditor read the prompts — they ENFORCE the locked invariants, no relitigation:
- **PROMPT_PLAN_4_ICONS** (theme-canonical monochrome iconography; upgrades Plan-3's brand-logo spine, does not fork it).
  Compliance: two-token-sources EXPLICIT ("icon tokens in EpistemosTheme.swift + Goose theme-tokens.ts, no third source";
  additive-only, coordinate on shared theme files) · color = theme token, never hardcoded #000/#fff (no rival accent) ·
  GRAPH DO-NOT-TOUCH · no fork/restructure of spine or GooseNativeModelsView (retheme-not-replace) · no runtime npm (MAS).
  **+ §11 ANIMATION LAYER** (cycle 13, `163fa2387`; optional/additive): Lottie/animated-SVG/SwiftUI, **never GIF** (GIF
  can't recolor → would break theme-canonical mono); theme-token tinted (mono preserved), SUBTLE/MINIMAL, reduce-motion→
  static, vendored-at-build (no runtime fetch, MAS-safe). Adds no new spring values (check #4 unaffected).
- **PROMPT_PLAN_5_COMPANION** — EXPANDED cycle 12 (`a807e9253`) to **TWO surfaces, one panel core**: (A) note-scoped
  mini-Goose-chat embedded in Epdoc; (B) landing "Farm" companions wired from cosmetic mascots → selectable/chattable
  personas (create/manage/select-and-chat; mascot icon on top, compact chat below). Compliance (re-verified): **Option 1 —
  BOTH surfaces are reskinned Goose WebView panels scoped by context, NOT native chat UIs** (stated explicitly; HARD GATE
  forbids a separate native chat surface) · GRAPH DO-NOT-TOUCH · reskin-not-restyle · unified tokens/springs · STREAM /
  PRESERVE THINKING / no MAS subprocess. **NOTE — flagged doctrine evolution (OUTSIDE the 10 invariants):** surface (B)
  deliberately extends the *CompanionModel v1.6 "cosmetic-only / no authority"* doctrine to allow a **gated chat binding**
  (still no silent tool/MCP/approval/runtime authority; honest MAS gate). Owner-directed + explicitly flagged in the plan;
  does NOT touch the locked canon docs. Cross-doctrine tension parked → OWNER REVIEW.
- **PROMPT_PLAN_6_QUICKCAPTURE** (Swift UX over the already-shipped Rust Quick-Capture substrate). Cycle-13 scan: SAVED-
  gated; domain is capture UX (not chat/editor/graph/token). FORBIDS touching the graph; coordinates with Plan-2
  wikilinks/graph canonicalization + Plan-4 icons. No locked-invariant contradiction. (Full read deferred until owner activates.)
- **PROMPT_PLAN_7_SYNC** (multi-device sync + recurring quality gate; holds 2 non-crash stability items). Cycle-13 scan:
  SAVED-gated; domain is sync/CI (not chat/editor/graph/token). FORBIDS touching the graph + MAS subprocess (Pro git lane is
  Pro/Dev-ID gated). No locked-invariant contradiction. (Full read deferred until owner activates.)

## OWNER REVIEW (Auditor parks ambiguous drift here — owner decides; empty = nothing pending)
- **2026-06-29 cycle 48b (Auditor) — 🛑 RESURRECTION OF OWNER-REMOVED FEATURES (owner-flagged: triage / raw-thoughts /
  chat-transcripts / old local+cloud agent "should just be Goose").** Source = the **`recon:`/`salvage:` workstream** (the
  `LOST_ITEMS_RECON` ledger + "draft Plan 6/7"), NOT Plan 2. It treated DELIBERATE owner-removals as "lost items" and routed
  them back. **Auditor MARKED the 3 confident ones OWNER-REMOVED in the recon:** #4 triage/Review-Queue HUD, #19 provider-
  specific cloud agent (also contradicts Plan-1's own "no separate agent brain"), #33 raw-thoughts (RETIRE not wire). Also
  marked the Plan-6 triage build item.
  - **KEY: these are NOT in fresh code** — `git log -S "RawThought"/"triage"` shows no recent code commits; they're only
    proposals in the recon DOC. **Plan 2 is on its real canon** (editor/HTML-Workspace commits: MarkEdit body-collapse,
    CoreEditor split, HTML-Workspace routes/export) — it is NOT building removed features.
  - **What the owner SEES in the app = OLD RESIDUAL code never fully removed** (`RawThoughtsState` refs in ~5 files; triage
    Rust `route/` substrate). Making it actually disappear needs a BUILD agent to delete the residual code — **auditor is
    docs-only, cannot.** Recommend owner task a build agent: "remove residual RawThoughts/triage/old-agent UI + code."
  - **OWNER CONFIRM THE FULL KILL-LIST** so I mark every resurrection (don't-guess on these): chat-transcripts (legit Goose
    chat transcript from the white-screen fix? vs old removed chat UI?), recon #19 cloud-agent (marked), "cockpit panel"
    (recon line 49 → Plan 1), per-model profile #15, llama.cpp #16, hyperdynamic #25 (local-inference — keep or cut?).
- **2026-06-29 cycle 39 (Auditor) — ⚠️ SYSTEMIC: build agents favor HARDENING over the VISIBLE fixes (owner asked "is
  it a forever loop?"). NOT canon drift — execution-priority observation.** Data:
  - **Plan-1 / white-screen:** 27 goose code commits since the P0 was set (21:05→22:18), **ALL "bound/cap"** (resource-
    bounding), re-touching the SAME files (`GooseACPProtocol` 7×, `GooseWebNativeAffordanceBridge` 6×). White-screen render
    fix = **0 commits.** The agent is NOT honoring its own "fix white-screen BEFORE more peripheral hardening" P0. The
    thermonuclear loop "never declares done" → left alone it keeps finding one-more-thing-to-bound and may never pivot.
  - **Plan-2 / HTML Workspace:** healthier — ~18 REAL capability commits (data feeds, package assets, routes, export
    inlining, live-DOM outline) + ~16 status/honesty commits. BUT the headline cap the owner wants — **"Full-surface
    regenerate" (chat rewrites the whole surface into a live site) — is STILL `isLive:false`** in
    `Epistemos/Engine/HTMLWorkspaceCapabilityStatus.swift`; app-bridge, DOM picker, Python also deferred.
  - **Pattern:** both loops prioritize robustness/honesty-status over the one user-visible feature the owner keeps asking about.
  - **Auditor CANNOT fix this** (docs-only; can't redirect build agents). **OWNER ACTION (only you can):** tell each build
    agent explicitly — *"STOP the hardening sweep; your NEXT commit is the visible fix (Plan-1 = white-screen retry-until-
    ready render; Plan-2 = full-surface regenerate live); do NOT return to bounding until it's PROVEN working in the app."*
    Auditor will keep watching + confirm when each visible fix lands.
  - **↳ cycle 41 — REMAINING REAL WORK per plan (auditor's read; effort map = 142/180 commits are pure hardening
    bound/redact/cap, only ~20 real-feature):**
    - **Plan 1 (Goose):** DONE = Phase-0 router + Slice-1 native Models (view exists/wired) + the WebUI reskin (tokens/CSS).
      LEFT (real, finite): (1) **white-screen render fix** [P0, not started], (2) **MAS in-process backend** [new, not
      started], (3) WebView reskin pixel-parity polish. Everything else it's committing now (bound ACP / redact diag) is the
      infinite-hardening loop running PREMATURELY.
    - **Plan 2 (Editor/HTML-Workspace):** LEFT = 5 deferred caps in `HTMLWorkspaceCapabilityStatus.swift` — **Full-surface
      regenerate** (the headline), App message-bridge, JS console/error capture, DOM picker/style inspector, Python(Pyodide).
      Plus any remaining lens/MarkEdit polish.
    - **Plan 3 (Capabilities):** broadest; many caps live + being hardened. LEFT = browser-use signed-Pro packaging + the
      deferred bits per each capability's gate-status (`ArxivPullGateStatus`, `BrowserCapabilityStatus`, etc.).
  - **ROOT ISSUE = the loop has no "done":** each plan's thermonuclear prompt says *"when complete, DO NOT declare done —
    keep looping: full-app hardening, weakest-path hardening, deepen, re-verify."* So even after the finite real items,
    they loop on hardening forever — and they're doing that loop NOW before finishing the real items. **OWNER FIX:** give
    each agent an explicit ordered punch-list (the LEFT items above) + "do these FIRST, hardening only AFTER, and cap it."
  - **↳ RESOLVED AT SOURCE cycle 43 (owner-directed 2026-06-30):** replaced the baked-in "harden forever / always a next
    hardening pass" LOOP MODE line in **PROMPT_PLAN_1/2/3** with a **WORK-ORDER directive** (REAL/visible work first → prove
    in-app → hardening SECONDARY + capped to one focused pass on touched code, no app-wide sweeps → when reals are done pull
    next REAL work → only a single full hardening pass when nothing real remains, then STOP+REPORT, no infinite loop). Each
    carries its remaining-real punch-list. Also created `docs/prompts/AGENT_LOOP_WRAPPERS_REAL_FIRST_2026_06_30.md` (3 paste
    wrappers). Post-edit invariant re-check: 10/10 still ✅ (canon-safe; Option 1 / graph / retheme / §7 all intact).
- **2026-06-29 cycle 34→35 (Auditor) — white-screen STATUS (owner-flagged "goose still white"; owner cyc35: "fix whenever
  it gets to it, just keep it captured in the plan"). NOT canon drift — docs are correct; this is execution-status tracking.**
  ✅ **CAPTURED:** the fix is **PRIORITY-0** in `PROMPT_PLAN_1_GOOSE` (root cause = startup race; fix = retry-until-ready ACP:
  poll `/health`, backoff-retry `init`, re-init WebUI ACP client on first healthy connect). ⏳ **PENDING in code:** `grep` of
  `Epistemos/Goose/*.swift` finds no implementing commit yet — Plan-1 has been on security/bounds hardening. **Per owner
  (cyc35): acceptable to fix when the agent reaches it in the plan order; the requirement is that it stays captured (it is).**
  Auditor role = keep it visible + confirm when the implementing commit lands (docs-only; edits nothing in code/Plan-1).
  **↳ ✅ FIX LANDED IN CODE cycle 45 (`57da5457a` "fix(goose): wait for acp before web ui render").** Implements exactly
  the canon fix: backoff-retry ACP handshake (`urlHandshakeInitial/MaximumRetryDelayNanoseconds`), production path retries
  `initialize` until the /health-healthy runtime accepts the WebSocket, loads the WebUI on `.connected` (not before backend
  ready) + 65 lines of new tests (ACPClient + RuntimeSupervisor). Pivot happened right after the WORK-ORDER directive (cyc43).
  **REMAINING: owner visual confirm** — cold-launch the new build → Goose chat should render in a few seconds with no manual
  reload (auditor can't run the app). This item closes once owner confirms it renders.
  **↳ cycle 45b — owner "still white": ROOT = STALE BUILD, not a code regression.** Newest `Epistemos.app` on disk built
  22:47 (DerivedData `…ctkiyqxa…`), fix committed 22:48 → no built app contains the fix yet (newest app's binary not even
  present). FIX TO SEE IT: rebuild (Xcode ⌘R or `xcodebuild -scheme Epistemos build`) then launch the freshly-built app.
  CAVEAT: build agents hold live uncommitted WIP (GooseWebSurfaceView/RuntimeSupervisor/HTMLWorkspaceDocument/…) — if the
  rebuild fails to compile, wait for a clean agent commit then retry. The committed fix (57da5457a) is buildable on its own.
  **↳ cycle 47 — owner rebuilt (binary 23:11, AFTER the fix) and STILL white; HTML Workspace also "not showing code".**
  Diagnosis: (a) GOOSE_API_HOST lead RULED OUT — it IS set (`GooseWebBootShim.swift:50` → runtimeBaseURL). (b) ROOT NOW =
  **owner is building MID-EDIT**: Plan-1 holds live uncommitted WIP on the white-screen files (GooseWebSurfaceView/
  RuntimeSupervisor/…) and Plan-2 holds the +357 `HTMLWorkspaceEditorView` regenerate refactor (isLive:false) — so the
  23:11 build = committed fix + half-finished work on top → both surfaces incomplete. **GUIDANCE: rebuild/test only at the
  agents' CLEAN COMMIT points, not while WIP is dirty.** Auditor watches commits each cycle and will signal "rebuild now"
  when Plan-1 lands a clean white-screen checkpoint and Plan-2 flips regenerate isLive→true. (Auditor docs-only; cannot fix
  the rendering code — Plan-1/Plan-2 must finish + commit.)
  **Owner's standing ask (cyc35): every issue that arises must be at least conceptualized + added to a plan/recon, even if
  not fixed immediately** — auditor will spot-check that new owner-raised issues land in a plan or `LOST_ITEMS_RECON`, not lost.
- **2026-06-29 cycle 19 (Auditor) — "graph CHROME" items vs invariant #6 "Graph = DO NOT TOUCH" (boundary question;
  NOT live drift — these are recon proposals, not build instructions; invariant grep still passes).** WAVE-2 of
  `LOST_ITEMS_RECON_2026_06_29.md` (`0daaf6695`) surfaces graph-adjacent items and proposes routing them: **#34** dead
  graph-appearance toggles `MetalGraphView` never reads ("wire or remove" → proposed *graph chrome*), **#35** graph
  code-editor white top-bar + landing pill persisting onto the graph (→ *graph chrome* / Plan 2), **#28** home↔graph
  blur-replace transition (→ Plan 4), grouped under a proposed **"Plan 8 — Theming & Appearance."** Tension: invariant
  #6 says the graph is DO-NOT-TOUCH (already full AppKit/Metal, the feel REFERENCE). #28 (a navigation transition) and
  #35 (chrome drawn *over* the graph) read as graph-ADJACENT, likely outside DO-NOT-TOUCH; **#34 (wiring graph appearance
  toggles) would touch the graph's own appearance path** — closest to the line. **Auditor did NOT banner** (recon is a
  legitimate tentative salvage ledger; preserve-nuance) and did NOT guess. **Owner decision (before any "Plan 8"/graph-chrome
  work starts):** is *graph chrome* (appearance toggles / top-bar / transition) INSIDE the DO-NOT-TOUCH boundary (→ drop/defer
  #34 esp.) or OUTSIDE it (chrome ≠ the Metal graph → allowed, and I'll record the clarified boundary in the doctrine)?
  **↳ UPDATE cycle 24 (`d24316f60`): owner DECLINED "Plan 8" as a dedicated plan; items 27/34/35 stay captured in the
  recon Wave-2 table but are NOT being worked ("later hardening pass only if owner asks").**
  **↳ CLOSED (owner direct, 2026-06-29): "not keeping 8 and 9." Plan 8 is dead, the graph-chrome items are not being
  worked, so the DO-NOT-TOUCH boundary is not at risk and needs no answer now. Would only re-open if the owner later
  asks to fix those specific captured graph bugs (esp. #34, wiring graph appearance toggles) — at which point re-raise.**
- **2026-06-29 cycle 12 (Auditor) — Companion v1.6 "cosmetic-only" doctrine vs Plan-5 chat extension (NOT a locked-canon
  violation; not a fleet blocker — Plan 5 is SAVED/not-active).** Plan-5 surface (B) deliberately evolves the CompanionModel
  v1.6 "cosmetic-only, NO model/prompt/tool/MCP/runtime authority" doctrine to allow a **gated chat binding**. That v1.6
  rule is still asserted (as absolute) in ~10 **archival** docs — e.g. `LEGENDARY_ARCHITECTURE_NO_COMPROMISE_AUDIT_2026_05_23`,
  `CANONICAL_CHRONICLE_2026_05_23`, `MASTER_FUSION_NO_COMPROMISE_2026_05_13`, `fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16`,
  `fusion/V1_SHIP_LEDGER_2026_05_16`, `fusion/AGENT_EVENT_VARIANTS_V16_2026_05_04`. **Auditor did NOT banner them** —
  (a) outside the 10 locked invariants (Companion authority ≠ Option-1/lens/springs/tokens/graph), (b) archival, (c) the
  evolution is owner-directed + explicitly flagged in Plan 5 ("READ the v1.6 doctrine before changing authority; state the
  change in code + model"), and (d) Plan 5 is not active. **Owner decision when Plan-5 activates:** point me at the CANONICAL
  v1.6 source doc and I'll add a "🛑 EVOLVED 2026-06-29 (Plan 5: gated chat)" marker pointing to Plan 5, so agents reading
  the old cosmetic-only rule don't contradict it. Until then: parked, no edit.
- **2026-06-29 (Auditor) — historical paste-prompt corpus (NOT a fleet blocker).** A broadened content-scan
  (`paste this` / `use this prompt`) found ~50 paste-prompt-style docs corpus-wide beyond the current handoff prompts.
  Triage: the vast majority are **archival** (`docs/_consolidated/**` research corpus, `docs/fusion/research/**`,
  `docs/june 1/**`, `docs/audits/**`, `docs/plan/prompts/**`) or legitimate **different-purpose session-startup
  prompts** (`MASTER_SESSION_PROMPT*` — named current by CLAUDE.md, `CLAUDE_CODE_SESSION_PROMPT`,
  `PARALLEL_SESSION_PROMPT`, `IMPLEMENTATION_PROMPTS`, `CODEX_PROMPT_CHAIN`, `ANTI_DRIFT_SYSTEM`,
  `AUDITOR_LOOP_PROMPT_2026_06_22`). **Auditor read: NOT a fleet-launch risk** — the 3 paste prompts + canon name
  PROMPT_PLAN_1/2/3 as the only paste, and the fleet's read-docs never route into the archive. I did NOT banner these
  (52 banners = vandalism; preserve-nuance). **Same rejected 06-24 full-clone family, still unbannered (banner only if
  owner wants):** `AUTHORITATIVE_FULL_CLONE_NATIVE_INFUSION_PLAN`, `OPENWORK_OPENCHAMBER_CODE_STUDY_HANDOFF`,
  `ACT_OSAURUS_SWIFT_AGENT_CODE_STUDY_HANDOFF`, `ACT_IP_PRESERVATION`, `TRANSITION_AND_MODEL_PICKER_IP_LEDGER` (all
  06-24, in `docs/`/`docs/handoffs/`). **Owner decision needed:** leave archival/session prompts as-is (auditor's rec)
  OR direct me to banner the 06-24 full-clone family for extra safety. (Already bannered the 2 that are paste-prompts
  in `docs/handoffs/`: CLONE_INFUSION + PRACTICAL_FULL_PORT.)

## How to use
- **Owner:** open this file; scan STATUS. Any ⚠️ → read the Auditor's note + the OWNER REVIEW section.
- **Auditor:** each cycle, re-run all 10 checks; update STATUS; for a FAIL you're CONFIDENT about → add a banner /
  `[DELETED]` marker at the SOURCE (never delete the doc); for an AMBIGUOUS FAIL → add a row to OWNER REVIEW; commit.
- **Build agents:** when a doc you read disagrees with an invariant here, the LEDGER + the canon (GOOSE_NATIVE_UI_DECISION
  + EPISTEMOS_NATIVENESS_DOCTRINE) WIN; treat the disagreeing text as stale and flag it.
