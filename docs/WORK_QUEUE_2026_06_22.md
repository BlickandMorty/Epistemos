# WORK QUEUE (2026-06-22) — the loop's per-iteration source of truth

> ## 🔴 STRICT RE-CERTIFICATION MODE (owner 2026-06-22, agent STOPPED & restarting)
> Owner: *"it has to UNCHECK EVERYTHING … re-verify that it all is coded correctly … I just can't trust that
> it is complete … truly start from the very beginning of the plan and recertify/reverify, and then continue
> … NOT a lazy continue or lazy verification — truly robust."*
>
> **EVERY box below is UNCERTIFIED — treat as `[ ]` regardless of any prior `[x]`/`[~]`.** Walk the **ENTIRE
> queue in numeric order:** **0.1 → 0.32** (TIER 0 full plan + clones), then **TIER 1 → TIER 5** — no early
> exit at act/D1–D5. For each item RE-CERTIFY against its →plan section with grounded evidence (file:line +
> real-state test + screencapture for UI) BEFORE marking `[x]`. Loop driver =
> docs/AGENT_LOOP_PROMPT_STRICT_RECERT_2026_06_22.md. Paste block =
> docs/AGENT_LOOP_PASTE_READY_2026_06_22.md.
>
> **ACT IS P0 BLOCKING (owner pain) — NOT THE ONLY CERTIFICATION SCOPE.** D1–D5 / 0.8 gate the act surface;
> they do NOT mean the iteration is done. **Act certified ≠ loop done. Build-green ≠ any tier done.**
>
> **D1–D5 (item 0.8) are RUNTIME ACCEPTANCE TESTS for 0.1–0.7** — do NOT mark 0.1–0.7 `[x]` until the
> matching D-item passes YOUR screencapture (e.g. 0.1 isn't `[x]` until D5 shows the active Epistemos
> custom/preset theme and owner chrome, not a hardcoded palette).
>
> **D4 / Configuration is TIER-0 blocking — queue 0.21 is the SOLE owner** (per-clone settings matrix for
> Epistemos|act|work|beyond). Items 0.11/0.22/4.1 reference 0.21 — do NOT duplicate the D4 obligation elsewhere;
> do NOT defer D4 to queue 4.1 while leaving TIER 0.
>
> **LATEST ACT UI CORRECTION (2026-06-23, owner-confirmed):** the bundle split is the bug. Act must be one
> Epistemos app surface: Epistemos landing/search/chat chrome, message bar, toolbar, recent-chat/sidebar,
> mini/graph/note variants, settings, and native Apple/Epistemos prompts. Osaurus is unbundled underneath as
> the engine/capability layer: streaming, model routing, tools, MCP, commands, permissions, provider config,
> sandbox/VM/dependency controls, and credential flows. Do NOT mount vendored Osaurus `ChatView` /
> `EpistemosOsaurusChatHost` as the visible act surface, do NOT restore old Epistemos backend behavior, and
> do NOT build skeletal approximation views. Rebuild/refactor the owner's Epistemos UI so it is engine-swapped
> to the real OsaurusCore seams.

THIS file is SMALL and the loop RE-READS IT IN FULL EVERY ITERATION — it is the INDEX, NOT the plan.

**THE PLAN = the FULL multi-feature spec (4000+ lines of raw implementation, the owner's VERBATIM intent — work
+ Osaurus/act + ALL clones + MD-V2/Epdoc + substrate + IP + orchestrator + graph + everything; act/Osaurus is
ONE part, NOT the whole).** It is too long to re-read every loop — THAT is why this queue exists (it indexes the
plan). Authority chain (highest→lowest), all CURRENT (not stale):
1. `docs/architecture/PLAN_V2.md` — architectural authority
2. `docs/OWNER_REQUESTS_LEDGER_2026_06_18.md` (~4500 lines) — the owner's VERBATIM intent / raw multi-feature plan
3. `docs/EPISTEMOS_FUSED_v3.md` — full build spec
4. `docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md` — recent act/clone directives (newest 🔴 wins on conflict)
For the CURRENT item: read its `→plan:` section AND grep the feature's VERBATIM spec in PLAN_V2 / the LEDGER (do
NOT re-read all 4000+ lines — read the item's slice). **IMPLEMENT EVERYTHING in the plan (all tiers 0–5, all
features), not just act.** The owner's landing/act/work-chat look is ALREADY verbatim in the plan — build to it.

RULES (every loop, non-negotiable):
- **STEP-0 RESET (pass49 — enforced):** On first iteration of each recert phase AND whenever any `[x]`/`[~]`
  appears in this file, revert **ALL** queue checkboxes to `[ ]` before walking. **STRICT_RECERT_LOG** is the
  sole certification record — never treat a queue `[x]` as proof. "Pick first unchecked" only works if boxes
  stay physically `[ ]` until you append a cert line to the log.
- **`[~]` CAP (pass49 — enforced):** Maximum **2** `[~] NEEDS-OWNER-RUNTIME` items for the **entire recert
  phase**. A 3rd `[~]` **HALTS** the loop pending owner decision. Each `[~]` MUST log in STRICT_RECERT_LOG:
  exact screencapture / osascript / send-text command run + failure output (not "couldn't verify").
- **TIER ADVANCE FLOOR (pass49 — enforced):** Every **3** loop iterations, 0.32 witness `highest attempted
  item ID` MUST reach **≥1.1** OR you file a stall report in STRICT_RECERT_LOG (all T0 still `[ ]` + evidence +
  proof you attempted T1+ same iteration). Act/P0 fixes run **in parallel** with lower-tier certification —
  T1+ attempt is NOT blocked waiting for full T0 `[x]`.
- **QUEUE = INDEX, NOT SPEC.** Open the item's full `→plan:` section; implement EVERY nuance there.
- **KEEP QUEUE COMPLETE:** any plan directive not indexed → ADD it here + point to plan section.
- **WALK ORDER:** first unchecked item, **numeric order** (0.1, 0.2, … 0.32, then 1.1, 2.1, … 5.4). **No early
  exit** after act/TIER 0 — continue through TIER 1–5 every iteration until full walk attempted or true `[~]`.
- **FULL-PLAN-NO-ACT-TUNNEL:** do NOT declare an iteration done, stop certifying, or narrow scope to act-only
  until you have attempted the full queue walk (0.1→0.32, then TIER 1→5) OR marked the sole remaining item(s)
  `[~]` with explicit reason. Per-clone matrix (Epistemos|act|work|beyond) applies where the plan requires.
- **RUNTIME:** YOU verify — build → open → `screencapture` → `Read` PNG. Owner is NOT checking.
  **PNG freshness (pass50 P1-c):** each iteration uses **unique capture paths** (e.g.
  `/tmp/epi_iter<N>_<surface>_YYYYMMDD-HHMM.png`); log capture timestamp in STRICT_RECERT_LOG; **Read PNG this
  iteration** — stale fixed-path PNG without Read does NOT satisfy (e). Ground-truth alias
  `docs/research/osa_runtime_2026_06_22.png` must be re-captured when cited, not reused unread.
  `[~]` = TRUE last resort only (state why screencapture + send-text both failed). Never `[x]` on build-green.
- Update queue + `docs/research/STRICT_RECERT_LOG_2026_06_22.md` each loop (**certification lines under
  `## Certification log` only**; gap-fill/docs edits under `## Docs-maintenance` — excluded from cert counts).
  Commit + push. No fake-done.
- Never delete chat IP. main-only. Co-Authored-By Claude.

STRICT CERTIFICATION BAR — `[x]` only when ALL hold:
  (a) EXISTS file:line · (b) CORRECT & ON-PLAN (mandated approach, not near-miss/drift) · (c) WIRED &
  REACHABLE — **distinct from (a):** cite a **consumer/mount/route** file:line where the code is **invoked,
  mounted, or routed** on the live path (NOT the same definition site as (a); definition-only ≠ wired) ·
  (d) REAL-STATE TESTED — test exercises the **same live entry point** that (c) cites; cite test name +
  **"0 skipped/ignored for this item"** (fail on new xfail/ignored/weakened asserts touching certified code) ·
  (e) RUNTIME proven by YOU (screencapture and/or send-text harness for UI/inference; **headless substrate/
  orchestrator:** live-path integration test citing a **runtime artifact** — log line / health-row value /
  AnswerPacket field — NOT cargo-test-only; see `docs/fusion/ARCHITECTURE_TIER_PROMOTION_CANON_2026_06_06.md` T4).

## TIER 0 — ACT SURFACE + FULL-PLAN CLONE BASELINE (P0 act blocking; NOT the whole plan)

> TIER 0 finishes the broken act surface AND indexes clone/substrate prerequisites. **Certifying TIER 0 does
> NOT close the loop** — you MUST continue TIER 1 (work/OpenCode), TIER 2 (substrate/salvage), TIER 3–5 in
> the same strict walk. Do not stop after D1–D5 pass.

- [ ] **0.1 Live Epistemos theme at ACT source** — the act surface must inherit the app's real `UIState` /
  `EpistemosTheme` selected `ThemePair`, custom slots (including `Chat Surface` for chat), and preset theme
  settings at the live Epistemos Act UI source, with owner home/pill chrome preserved. OsaurusCore supplies
  engine/capability state underneath through native seams; do not mount vendored Osaurus `ChatView` /
  `EpistemosOsaurusChatHost` to get functionality, do not restore old Epistemos backend behavior, and do not
  hardcode cream/dark/white as the target. Screenshot: active Epistemos theme on act plus the selected
  `ThemePair`/custom-slot defaults used for that capture.
  →plan: "🎯 RESKIN FIX — edit the VENDORED Osaurus theme at SOURCE" + "🔴🔴🔴 P0 ...RESKIN NOT RENDERING" +
  "🆕 ACT RESKIN — GO DEEPER" + "🆕 ACT RESKIN = RESPECT THE CURRENT CHAT UI".
  · iter1: legacy fixed-palette attempt applied at TRUE live source `CustomTheme.lightDefault` (NOT vestigial LightTheme struct) +
  `currentBuiltInThemeSchema` 5→6 cascade (prior edits never cascaded due to disk-install cache); pending active-theme
  screencapture; stays `[ ]` (D-gate on D5). See STRICT_RECERT_LOG Iteration 1.

- [ ] **0.2 ALL chat surfaces → same native Epistemos Act surface family with Osaurus underneath** —
  main/mini/graph/note ALL get ACT through the same Epistemos-native Act route and shared owner model/tool seams.
  Osaurus supplies the engine/capabilities underneath; the visible surface is not vendored Osaurus UI and not an
  old-backend restoration. ALL BUT NOTE also get WORK.
  mini/graph currently `triageService.streamGeneral`. SEQUENCE: after the main act surface passes its
  fresh-launch acceptance (do NOT tunnel on mini/graph before act works). Screenshot EACH surface separately
  (main ≠ enough).
  →plan: "🆕 ALL CHAT SURFACES GET THE CHAT→ACT/OSAURUS UPGRADE" + "✅ CONSENSUS — KEEP TriageService".

- [ ] **0.3 LANDING → SEARCH/BLUR → ACT (owner Epistemos ontology, not Osaurus home)** — the real Epistemos
  `LandingView` / home shell shows FIRST (active Epistemos theme + toolbar + pill). Entering Act uses the
  owner's search/message-bar transition, then opens the native Epistemos Act chat on the Osaurus engine. NOT a
  vendored Osaurus default home, NOT a second recent-chat button, NOT skeletal native clone, NOT old-backend
  restoration.
  Screenshot landing, then post-tap act.
  · **iter10 (per P0 §1886 BUILD-NOW): first build-step landed** — RootView Osaurus branch now gates the host
  behind `actEntered`: shows Epistemos `LandingView` FIRST + "Enter act" press → blur → host (host always reachable
  on press, 0.4 send untouched). Pending build (bvi4lbj91) + screencapture-verify landing-first + harness re-run.
  Follow-on: first-message state-bridging + drop Osaurus landing-blocks fully (SYNTHESIS §2). Stays `[ ]` (D-gated).
  →plan: "🔴🔴🔴 P0 (11:30am) ...LANDING FLOW" + "landing BLUR transitions" + "🔴 AUDITOR CORRECTION §1886 BUILD-NOW".

- [ ] **0.4 SEND works (runtime)** — CERTIFIED iter5 (all 5 gates; auditor P0 satisfied). (a) ActOsaurusBridge.swift:196
  runTurnStreamingInProcess · (b) in-process CoreModelService, no loopback · (c) AppBootstrap.swift:3155 register +
  ActOsaurusStreamingHandler/SharedActInference · (d) **NOW MET** — `ActOsaurusSendHarnessTests.actSend_servedEqualsSelected`
  drives the SAME entry point, asserts non-empty reply + served==selected, **0 skipped** (test run: 2/2 passed,
  b46w5uphy 13:34) · (e) live GUI send "CERTIFY"/"PROVEN" gemma-4-e2b, no requestFailed (PNGs Read iter2/3).
  →plan: "🎯 PINPOINTED ActOsaurusError error 2" + "P0-A" + "🔴 AUDITOR CORRECTION (P0) 2026-06-22".

- [ ] **0.5 Mini-chat + grab-chat reachable** — wired, discoverable. **Screenshot EACH surface separately**
  (main act, mini, grab-chat if present) — one PNG per surface; main-only does NOT satisfy 0.5.
  →plan: addendum mini-chat section + "🔴🔴🔴 P0 ...RESKIN NOT RENDERING" §mini-chat + PER-SURFACE mandate.

- [ ] **0.6 RE-CERTIFY claimed-done** — duplicate act/work toggle gone (ONE toggle only) · **VISIBLE engine
  indicator** on act UI (Osaurus/MLX/Apple live — P0-B ESCALATION) · **VISIBLE send-path errors** (no silent
  dead air — P0-A ESCALATION) · scroll-blur graft · side-panel graft · white-bar/click-to-search → Osaurus
  landing not old search · model-default seed · clean titles — file:line + runtime each.
  →plan: pass-30/31 audit items + "ACT SURFACE — UI BUGS to fix" + "🔴🔴 ESCALATION" P0-A/P0-B +
  "🔴🔴🔴 P0 — RUNTIME STILL BROKEN" (duplicate toggle, click-to-search).

- [ ] **0.7 Message-bar graft** — reskin Osaurus composer to Epistemos feel (owner-verify); not literal swap
  if it breaks send path. Screenshot composer.
  →plan: "⚠️ MESSAGE-BAR graft" + "🔒🔒 DEFINITIVE ACT-UI DIRECTION" graft #1.

- [ ] **0.8 D1–D6 RUNTIME DEFECTS (acceptance gate for 0.1–0.7)** — screenshot-verify ALL before act certified:
  D1 curved window+shadow · D2 owner landing not Osaurus default · D3 pill back · D4 config/settings work ·
  D5 full reskin + model picker/palette/38-tool panel. Ground truth PNG:
  `docs/research/osa_runtime_2026_06_22.png` (re-capture after fixes).
  · **REFINED (owner P0 §pass58b, commit 2e1d95938): NEW D6 = back-navigation from act/work (currently none —
  add a back affordance); D3 pill on BOTH act+work (tied to curved chrome); the NATIVE AppKit SHELL
  (toolbar+sidebar+recent-chats popover+pill) is the SOURCE of curved edges → D1 follows from the §1 native shell,
  NOT a window hack.** D2 first-step landed iter10 (LandingView-first + Enter-act press; build green).
  →plan: "🔴 OWNER-REPORTED RUNTIME DEFECTS" + strict prompt D-section + "🔴 OWNER RUNTIME REPORT D6/native-shell (pass58b)".

- [ ] **0.9 ACT FIDELITY** — stream every token; preserve thinking blocks+signatures; real tool-call parsing;
  no `<think>` leak in titles/output; **CLASSIFY shared-vs-chat-only** before fixing regressions
  (shared pipeline bugs ≠ chat-only). Real-state test + screenshot reasoning reply.
  →plan: "🔴🔴 P0 REGRESSION — reasoning-model output broken in LIVE chat" + "🔴 P0 REGRESSION — CLASSIFY
  shared-vs-chat-only" + `docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md` fidelity.

- [ ] **0.10 DATA CARRY-OVER** — saved chats/sessions/prefs migrate to act; no lost history.
  →plan: `docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md` "Data/persistence carry-over".

- [ ] **0.11 Provider wiring + Epistemos Picks** — CERTIFIED iter8/9 (scope: selectable + used-on-send + no silent
  Codex; "Configuration opens settings" = 0.21/D4's obligation, NOT here). (a) Epistemos/Engine/EpistemosPicks.swift:21
  curated grouping · (c) ModelStackSettingsView.swift:56 consumes Picks groups + EpistemosModelBridge.providedModelIds
  surfaces owner models; send routes via bridge (AppBootstrap:3155) · (d) EpistemosPicksTests 4/4 passed 0 skipped
  (curatedFirst/installedSeparated/honest-selection/partition, bqgw1i2gr) + EpistemosModelBridgeTests + send harness ·
  (e) live send used SELECTED owner model gemma-4-e2b (not Codex); picker showed it (iter2/3 PNGs).
  →plan: "OWNER'S MODELS IN CHAT" + "DEEP CHECK §2" + "DESIGN DECISION — \"Epistemos Picks\"".

- [ ] **0.12 Surface-wiring rule** — every Osaurus surface (settings, model stack, tools, transcript, config)
  mapped to proven Epistemos front-end; no dead surfaces; real-state/launch-smoke each.
  →plan: "🆕 SURFACE-WIRING RULE".

- [ ] **0.13 Shared act component** — ONE composer/capability component for main+mini+graph+note (no drift).
  →plan: "🆕 ALL CHAT SURFACES …" implementation intent (shared component).

- [ ] **0.14 Health-row witnesses honest** — `ActOsaurusHealthRow`, `AnswerPacketHealthRow`,
  `LocalRouteHonestyHealthRow`, etc.: `wiredToday`/`stillStub` match REAL code after every change; re-cert.
  →plan: substrate progress + "DEEP CHECK" + settings health rows.

- [ ] **0.15 DEEP CHECK** — trace LIVE act path; prove no silent Codex; honest `OSAURUS_BUILD_PROGRESS`.
  →plan: "🆕 DEEP CHECK — PROVE THE REALITY, NOT THE CLAIM".

- [ ] **0.16 Reasoning + title-gen** — `<think>` parsing; CLEAN short titles (no model
  self-description garbage); all models; extends 0.9.
  →plan: "🎯 CONFIRMED reproduction + TITLE bug" + P0 regression sections.

- [ ] **0.17 LOCKED ACT direction (FINAL, corrected 2026-06-23)** — ACT is Epistemos's visible app UI with
  Osaurus unbundled underneath. The owner's Epistemos app contributes the first-run/home shell (`LandingView`,
  back/home, top pill controls, settings, greeting animation, recent/history), old/new chat chrome, message bar,
  sidebar/recent-chat popover, model picker, command/tool/skills surfaces, and mini/graph/note variants. Osaurus
  contributes the engine/capability layer through native seams: streaming, model routing, providers, tools, MCP,
  commands, permissions, sandbox/VM/dependency controls, and credential prompts. Do not mount vendored Osaurus
  `ChatView`/`EpistemosOsaurusChatHost`; do not restore old Epistemos backend behavior; do not use skeletal
  approximation views. Fresh-launch acceptance: landing/search/chats look like Epistemos and a real Act send
  streams through the certified Osaurus path with settings/prompts/tools reachable natively.

- [ ] **0.18 Model provider registration** — CERTIFIED iter6 (NOT D-gated). (a) EpistemosOsaurusModelProvider.swift:28 ·
  (b) bridges owner's MLX models via EpistemosModelBridge primitive seam · (c) AppBootstrap.swift:3155 register over live
  MLXInferenceService + seeds coreModelName · (d) `EpistemosModelBridgeTests.registeredOwnerModelsRouteThroughBridge`
  (success-path routing, 4/4 passed 0 skipped, bseglu4pp) · (e) live send routed to registered owner model gemma-4-e2b (P0-A).
  →plan: "🎯 PINPOINTED ActOsaurusError" + "ACT = OSAURUS IS THE CHAT" §FIX act errors.

- [ ] **0.19 Chat surface quarantine/deletion sequence** — after Osaurus-host act is certified, quarantine or hide
  stale old-chat/skeletal clone surfaces from user routing, port/preserve any useful IP, and keep no toggle limbo.
  →plan: "ACT = OSAURUS IS THE CHAT" §THE BUILD steps 1–4 + QUARANTINE doc.

- [ ] **0.20 Collapse act/chat duality** — remove CoworkChatMode depth axis + depth toggle; act/work only.
  →plan: "ACT = OSAURUS IS THE CHAT" step 3.

- [ ] **0.21 Per-clone SETTINGS matrix (D4 blocking — SOLE OWNER)** — **Epistemos (main) | act | work | beyond**
  tabs each open that clone's REAL settings (not flattened/dropped). Configuration on act opens act/Osaurus settings;
  work tab opens OpenCode/work settings when wired; beyond tab reserved for future clones (Tolaria, Epdoc-fuse,
  etc.) per plan. Screenshot **each tab** separately. Queue 4.1 extends polish only — **D4 must pass here in TIER 0**.
  →plan: "🆕 PER-CLONE SETTINGS" + D4 in OWNER-REPORTED DEFECTS + per-clone MAS-fit research.

- [ ] **0.22 ONE inference chokepoint (act path)** — CERTIFIED iter7 (NOT D-gated). (a) ActOsaurusBridge.swift:196
  in-process `runTurnStreamingInProcess`→CoreModelService; loopback HTTP is fallback-only (:243-278) · (b) on-plan
  single in-process path · (c) SharedActInference.actStreamIfArmed = single act-injection entry; LocalAgentLoop
  streamingGenerator delegates to it · (d) **real-state** ActOsaurusSendHarnessTests: actSend_servedEqualsSelected
  (exercises the in-process entry) + actSend_unknownModelFailsHonestly (no silent alternate path), 0 skipped; single-
  entry architecture additionally source-guarded by ActOsaurusStreamingTests delegation contracts · (e) live send NO
  requestFailed (loopback not hit), in-process reply (iter2/3 PNGs). Pairs 0.4/0.18.
  →plan: "🎯 DIRECTIVE — ONE INFERENCE CHOKEPOINT" + "🎯 PINPOINTED ActOsaurusError".

- [ ] **0.23 Send-text harness (EVERY iteration — standing)** — CERTIFIED iter5: BUILT
  `EpistemosTests/ActOsaurusSendHarnessTests.swift` — headless, drives real act entry point (OsaurusActBridge →
  CoreModelService.generateStream(requestedModel:) → EpistemosBridgedModelService → provider); asserts non-empty
  reply + **served-model == selected-model** (pass50 P1-a) + no silent substitution; **0 skipped** (2/2 passed,
  b46w5uphy 13:34). Deterministic (fake provider) so it's the repeatable per-iteration proof; gate (e) real-model =
  loop's live GUI send. Re-run each iteration (or cite latest green when no send-path change).
  →plan: strict prompt MANDATORY FUNCTIONAL PROOF + "🎯 PINPOINTED ActOsaurusError" + "🔴 AUDITOR CORRECTION (P0)".

- [ ] **0.24 Act UI bug bundle (explicit)** — remove top white bar; fix click→search (must match D2: Epistemos
  landing first); clean title-gen (no model self-description as title). Screenshot each fix.
  →plan: "🆕 ACT SURFACE — UI BUGS" + "🎯 CONFIRMED reproduction + TITLE bug".

- [ ] **0.25 Delete old main ChatView surface (GATED)** — ONLY after 0.4+0.8+0.10+CHAT_BACKEND four-part bar:
  remove old chat from routing; delete surface code; IP preserved in quarantine. NOT before act certified.
  →plan: "🔴🔴 ACT = OSAURUS IS THE CHAT" §THE BUILD #4 + THREE STANDING DIRECTIVES #3 + CHAT_BACKEND.

- [ ] **0.26 UI-hide quarantined chat (GATED)** — once act certified: hide old chat from user UI; act+work only.
  →plan: "🆕 QUARANTINE = CODE-PRESERVED + UI-HIDDEN".

- [ ] **0.27 Epistemos (main) clone baseline** — main app shell/settings/inference NOT conflated with act:
  Epistemos-native settings tab, theme/palette, vault, graph, notes, health rows honest for main path. Screenshot
  main settings + one non-act surface (graph or notes). Distinct from act's Osaurus-backed capability layer.
  →plan: "🆕 PER-CLONE SETTINGS" (Epistemos tab) + "🆕 MORE LOVED ASSETS TO PRESERVE" + DESIGN SOUL.

- [ ] **0.28 WORK clone surface reachable (TIER-0 index; build in TIER 1)** — work mode discoverable via
  act/work toggle + search→work landing; OpenCode/work shell reachable. **Stub = `[ ] STUBBED(plan ref)` — never
  `[x]`** until W-gate passes (see ACCEPTANCE GATES below). Screenshot work landing/TUI separately from act.
  Note chat = act only (no work).
  →plan: "✅ RESOLVED OPENCODE UI" + "Where WORK goes" + dual landing+blur + mode-entry animations.

- [ ] **0.29 Per-clone inference routing** — act send → Osaurus/in-process act path; work send → OpenCode/work
  engine path; main/Epistemos triage paths unchanged where plan says; NO cross-clone silent fallback (Codex/Qwen).
  **REQUIRED** work-lane send-text harness when certifying work routing (pairs W4 + 1.7 — build if missing; same
  bar as act 0.23; "when available" forbidden — pass50 P0-C).
  →plan: "🎯 DIRECTIVE — ONE INFERENCE CHOKEPOINT" + "✅ CONSENSUS — KEEP TriageService" + WORK ENGINE = ARCH C.

- [ ] **0.30 BEYOND clone tab + scope honesty (in-scope vs OFF-LIMITS)** — beyond settings tab exists or is
  honestly stubbed with plan ref; **Stub = `[ ] STUBBED(plan ref)` — never `[x]`** until B-gate passes. **Companion-
  backend clones OFF-LIMITS** (companions.rs, CompanionCreationFlow, new-model interrupt internals) — do NOT cert
  beyond as Companion. **Work + beyond future clones IN SCOPE** (Tolaria reference lane, Epdoc-fuse, Tamagotchi
  render-fix). Document what's stub vs wired.
  →plan: "🆕 PER-CLONE SETTINGS" beyond tab + Tamagotchi + Tolaria reference + OFF-LIMITS guard.

- [ ] **0.31 Reverse addendum audit (EVERY iteration — standing)** — after forward queue walk: **diff the FULL
  addendum heading list (`^#{1,3} ` lines in the addendum) against this queue index** — NOT token-grep alone.
  Supplement with grep for 🔒/DEFINITIVE/P0/MUST/BUILD-IT-HARDENED/PER-CLONE/WORK/BEYOND/ALL CHAT SURFACES/
  ESCALATION/🆕/🌟/RESEARCH; verify EACH hit is indexed here or STANDING with →plan ref. Missing directive → ADD
  queue row same iteration. Paste **heading-diff output + grep hit count + unindexed list (if any)** into
  STRICT_RECERT_LOG under `## Certification log` — empty audit does NOT satisfy 0.31.
  →plan: THREE STANDING DIRECTIVES §1 + COMPLETENESS / DISCOVERY-SWEEP MANDATE.

- [ ] **0.32 Full-plan iteration witness (EVERY iteration — standing, HARD GATE)** — before declaring iteration
  done, append this block to STRICT_RECERT_LOG (all fields required):
  `Highest attempted item ID:` (e.g. `2.3`, not just "T2") · **`Lowest still-[ ] item ID:`** (first unchecked in
  numeric walk order at iteration end, e.g. `0.4` — pass50 P0-A; prevents ATTEMPTED-vs-CERTIFIED gaming) ·
  `T0/T1/T2/T3/T4/T5 [x]/[~]/[ ] counts` · `TIER 1+ attempted: YES|NO` · `If NO: evidence` ·
  `Act-only tunnel: DENIED (explicit)` · `Forbidden end-claims avoided: YES`.
  **FORBIDDEN** without full walk attempted: "act certified = iteration done", "D1–D5 pass = done",
  "stopping at TIER 0", "build-green = tier done", "defer TIER 1+ to next iteration", "act is blocking so
  skipping work/substrate", "full-plan walk complete after TIER 0", "will continue with lower tiers later",
  **"STRICT RE-CERT COMPLETE" while ANY queue box is still `[ ]`**, or while any in-scope clone lacks ≥1 real
  runtime proof (stubs excluded).
  **INCOMPLETE iteration** if **lowest still-[ ] item ID** did not advance vs the prior iteration's witness
  (unless the sole change is an honest new `[~]` with cmd+output evidence). Also INCOMPLETE if highest attempted
  is before **1.1** unless every TIER 0 item is `[~]` with screencapture+send-text evidence AND you still
  attempted TIER 1+ same iteration before ending. Act P0 blocking does NOT cancel TIER 1+ attempt when TIER 0 is
  certified or honestly `[~]`. If stopped at TIER 0 only, cite screencapture/send-text evidence why TIER 1+ could
  not be attempted — not convenience.
  →plan: strict prompt FULL PLAN CERTIFICATION + NEVER-IDLE + FULL-PLAN-NO-ACT-TUNNEL + META-ESCALATION
  (build-green ≠ works).

- [ ] **0.33 EXHAUSTIVE ACT SURFACE COVERAGE (owner 2026-06-23, P0)** — EVERY Osaurus surface must be expressed
  NATIVELY in the act chat (not the vendored Osaurus view). Authority = `docs/ACT_SURFACE_COVERAGE_MATRIX_2026_06_23.md`
  (full per-surface COVERED/PARTIAL/MISSING map + punch-list). COVERED today: chat-thread rendering (thinking/tool-call/
  artifact/clarify/secret/redaction/prompt-queue/attachments), sandbox/VM controls, privacy filter, pairing/credential/
  tool-permission/computer-use prompts. **OPEN GAPS (close in priority order; each is a sub-item):**
  · **0.33a Prefill/stats/billing telemetry (OWNER NAMED "prefill") — START HERE:** stripped by `ActOsaurusVisibleStreamFilter`,
    never surfaced; original Osaurus showed "TTFT 7.36s · 39 tokens" — render a native stats chip from the `stats:`/`prefill:`/
    `billing:` sentinels instead of discarding.
  · 0.33b Server settings (~16 ServerSettings sections) — MISSING (largest gap; `server` tab = index row).
  · 0.33c Plugins beyond counts (install/marketplace/GitHub-import/config/sandbox-plugin-editor).
  · 0.33d Agents / Schedules / Watchers (list, capability manager).
  · 0.33e Voice settings (VAD/TTS/transcription/hotkey/overlay) — only composer mic exists.
  · 0.33f Model detail / download / cache inspector / external-model add (only selection native).
  · 0.33g Skills view/editor + slash-command catalog editor (invocation works; no catalog UI).
  · 0.33h Tool secrets (ToolSecretsSheet) — no native expression.
  · 0.33i Chart renderer, terminal-in-chat, in-chat LaTeX, transcript minimap.
  · 0.33j Identity / Credits / Themes / Insights / Storage (index-only).
  · 0.33k ComputerUseFeedView live action feed.
  · **Cross-cutting:** the 14 non-native `ManagementTab` cases render a generic "N surfaces indexed" row
    (ActCloneSettingsView default branch :1347) — landing each replaces the index row with a real native surface.
  →plan: addendum "🔴🔴🔴 OWNER DIRECTIVE 2026-06-23 — EXHAUSTIVE ACT SURFACE COVERAGE" + the matrix doc.

## TIER 1 — WORK MODE (OpenCode)
- [ ] **1.1** OpenCode launcher binary vendored. →plan: "🆕 BUN RUNTIME = VENDORED/BUNDLED".
- [ ] **1.2** WORK = OpenCode real TUI; mini/graph (not note); search→work; dual landing+blur.
  →plan: "✅ RESOLVED OPENCODE UI" + "✅ WORK LOOK = real TUI".
- [ ] **1.3 Goose/Hermes/OpenClaw fuse beneath OpenCode — FULL vendored clone** — Goose is a **FULL vendored
  clone beneath OpenCode**, NOT a leaf-by-leaf port; follow 🔒 FULL-CLONE PROCESS. Hermes/OpenClaw fuse per ARCH C.
  →plan: "✅ DECISION WORK ENGINE = ARCH C" + "‼️ CORRECTIONS" + "🆕 GOOSE FULL-VENDOR COST".
- [ ] **1.4** OpenCode/work terminal fully theme-responsive (palette from live EpistemosTheme).
  →plan: "🆕 OPENCODE MUST BE FULLY THEME-RESPONSIVE".

- [ ] **1.5** WORK clone surface certification — WorkTerminalView/WorkOpenCodeShell wired on live path;
  real TUI visible; palette-matched; labeled "work" never "OpenCode"; screenshot work composer + landing blur.
  Pairs with 0.28.
  →plan: "✅ WORK LOOK = OpenCode's REAL TUI" + "Where WORK goes" + PRIORITIZE WORK UI live.

- [ ] **1.6** WORK per-surface routing — mini + graph get work mode (NOT note); search→work transition;
  dual landing act↔work with blur; act/work toggle on all applicable surfaces. Screenshot EACH.
  →plan: "✅ RESOLVED OPENCODE UI" + ALL CHAT SURFACES (work half) + mode-entry animations.

- [ ] **1.7** WORK inference + send path — work lane send reaches OpenCode/Goose fused engine; distinct from
  act/Osaurus; **REQUIRED** headless work-lane send-text harness (build if missing per W4 — pass50 P0-C); log
  prompt + ~80 chars + engine-lane identity; real-state test alone insufficient without harness proof. No silent
  act fallback.
  →plan: "✅ DECISION WORK ENGINE = ARCH C" + 0.29 routing + Bun runtime vendored.

- [ ] **1.8** OpenCode heaviness mitigation — no Electron/Tauri GUI shipped; headless Bun only; **lazy-launch when
  WORK opens**, **loopback-only**, **kill-on-idle**; real TUI in SwiftTerm/PTY (palette-matched); measure disk/RAM;
  Pro-only footprint honest. Screenshot work TUI + verify no Chromium bundled.
  →plan: "🆕 OPENCODE \"HEAVINESS\" — MITIGATION" + Bun runtime vendored (1.1).

- [ ] **1.9 RustLSP → work-agent code-intelligence tools** — wire existing `agent_core::lsp_runtime`
  (hover/definition/diagnostics/edit) into the WORK stack via `RustLSPTransport`; do NOT import OpenCode's LSP.
  Real-state test on live work-tool path + consumer cite distinct from definition site.
  →plan: "RustLSP + similar existing logic — what to do" + "🆕 CRYSTALLIZED TWO-MODE ARCHITECTURE".

## TIER 2 — SUBSTRATE + SALVAGE
- [ ] **2.1** SUBSTRATE Phase 2 AnswerPacket — re-cert load-on-launch; history surface + primary witness.
  →plan: `docs/research/SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md`.
- [ ] **2.2** Helios salvage (7 items): eidos.query, provenance ledger, confidence_floor, AnswerPacket/wbo6,
  L1 memory, InterruptScore, HW tier. →plan: "✅ HELIOS-ERA IP ... salvage list".
  · **iter37 AUDIT (PARTIAL salvage):** ① eidos.query/recall = REAL-wired+tested (iter35). ② provenance ledger `ClaimLedger` = REAL-wired (bridge.rs:3446 FFI static + eidos/ledger_backed_claim_evidence.rs consumes it; epistemos_trace CLI + ledger/ReplayBundle tests). ③ `confidence_floor::decide_floor` = **ORPHANED** (in product build lib.rs:26, unit-tested, but ZERO live callers). ④ AnswerPacket REAL (iter34) / `wbo6` referenced only from `research::koopman` (research-gated). ⑤ L1 memory = **ABSENT** (only unrelated L1-norm distance fns in research::geometry_ir). ⑥ `InterruptScore` = falsifier-string-only (falsifier_validator.rs:275), no live struct consumer → orphaned. ⑦ `HardwareTier` = used in uas/exotic_quant_quarantine_route_card (route-card/falsifier logic) — partial. Verdict: 2 real + 1 partial + 1 mixed + 3 orphaned/absent → NOT whole-certifiable; stays `[ ]`. Actionable: wire-or-cull confidence_floor/InterruptScore (2.4 dead-code), confirm wbo6/HW-tier product role.
- [ ] **2.3** GUS salvage 1–18 (verify absent vs live). →plan: GRAND SWEEP cycles 1–3.
- [ ] **2.4** UNIFICATION: one orchestrator+TRINITY+router+chokepoint; fix eidos fake-green; dead code cleanup.
  →plan: "✅ UNIFICATION VERDICT" + "🌟 THE BIG IDEA / GRAND CONVERGENCE" +
  docs/research/THE_BIG_IDEA_GRAND_CONVERGENCE_2026_06_22.md.
- [ ] **2.5** EML honesty gate (GUS-2) — EML/Belnap → AnswerPacket abstain gate.
  →plan: GRAND SWEEP GUS-2.
  · **iter36 AUDIT:** the Belnap abstain primitive (`research::belnap::BelnapValue::{from_evidence,abstains,abstain_reason}`, doc-tied to "the AnswerPacket's honest assert-vs-abstain decision") is SOUND + unit-tested IN ISOLATION, but is **NOT product-wired**: the whole `research` module is `#[cfg(feature="research")]` (lib.rs:68-69) — **default-OFF, "never in the app"**; `from_evidence`/`abstains` have ZERO callers outside belnap.rs; and `AnswerPacket` has **no abstain field**. So "EML/Belnap → AnswerPacket abstain gate" is NOT on any live path. To certify 2.5: promote the primitive out of research-gating + add an AnswerPacket abstain field + wire evidence-count → from_evidence → abstain provenance on the answer path. Stays `[ ]` (research-staged, not product-wired).
- [ ] **2.6** Eidos recall/rerank — real wiring, NOT fake-green. →plan: GUS-5 + Helios salvage.
  · **iter35 AUDIT:** RECALL is genuinely WIRED+tested (QueryRuntime.swift:355→`eidosPacket`→`EidosBridge.retrieve`→FFI `eidos_retrieve_json` bridge.rs:4011→production vault index, no-fixture contract; VaultRecallContract consumes the packet; `agent_core/tests/r1_eidos_production_helper.rs` 7/7 pass). **BUT FAKE-GREEN FOUND:** the closed-citation ENFORCER `ChatCoordinator.runEidosCitationGate` (CC+EidosCitationGate.swift:62; doc: "Call BEFORE committing the chat row") has **ZERO callers** — the closed-citation contract is NOT enforced on the live answer path. ACTIONABLE (deferred, behavior-risk): wire the gate into the answer-commit path with source_id plumbing (proceed/rejectAndDrop/bridgeUnavailable). Stays `[ ]`.
- [ ] **2.7** Agent-stack convergence + dual MLX clash — ONE agent-loop/runtime of record; dedup cloned
  capabilities; fix vmlx-swift vs mlx-swift-lm clash; all cloned logic deeply serves the app (no dead clones).
  →plan: "🆕 AGENT-STACK CONVERGENCE" + docs/research/AGENT_STACK_CONVERGENCE_RESEARCH_2026_06_21.md.
- [ ] **2.8** BUILD-IT-HARDENED gates — finish salvage/unification with real-state tests; go-back-and-unify
  in-flight TRINITY/System G with unification verdict; harden BEFORE integrating into live/clone paths.
  →plan: "🔨 BUILD-IT-HARDENED + GO-BACK-AND-UNIFY".

## TIER 3 — ORCHESTRATOR / FUGU / TRINITY
- [ ] **3.1** TRINITY native orchestrator on System G/RuntimeRouter. →plan: "🌟🌟 TRINITY" + port spec.
  · **iter38 AUDIT (System G run-seam = WIRED, breaks the orphan pattern):** `agent_runtime_v2` is in the product build (lib.rs:5, NOT feature-gated). System G run seam is REAL-wired: AppBootstrap.swift:2504 registers `RealSystemGRunSeam` (FFI `systemGStartRunJson`/`systemGDrainEventsJson`, bridge.rs:4954/4991) into `SystemGRunSeamRegistry` at launch (default is stub; production overrides). ROUTE SELECTED+LOGGED (S3 artifact): `SystemGRunSeamTests.realSystemGRunSeamLabelsGemmaGGUFLocalMission` drives `RealSystemGRunSeam.run` and asserts `log.events[1]` = Rust `.localModelHandoff` with `providerPolicyJSON "kind":"local_gguf"` + model_id, AnswerPacket id linked, and the GGUF model NOT silently promoted in `RuntimeRouter.modelPreferenceTable`. **SystemGRunSeamTests 13/13 PASS** (xcodebuild, fresh). System G portion meets S3 (wired+logged+real-state). REMAINING for full 3.1: the `trinity_orchestrator::run_mission`/`run_mission_async` layer (run seam uses system_g_runtime::start_run V1 runner — confirm TRINITY orchestrator live-wiring separately). Stays `[ ]` pending the orchestrator-layer cert.
- [ ] **3.2** Fugu optional guest provider (never the brain). →plan: "🌟 FUGU = FOUNDATIONAL FEATURE" +
  "🆕 FUGU \"CLONE THE CODE\"".
  · **iter39 AUDIT (honest, NOT orphaned):** Fugu = config-only GUEST provider via `OpenAICompatibleProvider` (providers/pricing.rs:184 "Fugu plugs in via OpenAICompatibleProvider (config only)"; canonical "fugu" + aliases sakana-fugu/fugu-ultra/fugu-orchestrator). "NEVER THE BRAIN" is STRUCTURALLY enforced + TESTED: `trinity_routing::select_model_for_tier` resolves ONLY from the local canon and returns None for non-local/unavailable ("caller escalates HONESTLY — never a silent wrong-tier swap"); guard test `select_model_for_tier_resolves_local_and_prefers_advertised` asserts None for unknown/empty. Pricing VERIFIED+tested (`pricing_includes_fugu_with_verified_per_token_rates`, console.sakana.ai per-token sheet) + flat per-message cost surfaced in Settings for EXPLICIT opt-in (owner req #2). **trinity_routing 5/5 PASS** (cargo --lib, fresh). Remaining for `[x]`: live "add Fugu as OpenAI-compatible provider" UI reachability (provider-config path; GUI-blocked). Stays `[ ]` but NO fake-green — design honest + guarded + tested.

## TIER 4 — OWNER-FACING / CLONES / PILLARS
- [ ] **4.1** Per-clone SETTINGS polish (extends **0.21 sole D4 owner** — do not duplicate D4 obligation).
  →plan: "🆕 PER-CLONE SETTINGS".
- [ ] **4.2** System-prompts library + Epistemos Picks per-model prompts. →plan: "🆕 SYSTEM-PROMPTS LIBRARY".
- [ ] **4.3** VAULT-DEEP-INTEGRATION pillar. →plan: "🌟 PILLAR — VAULT-DEEP-INTEGRATION".
- [ ] **4.4** EPDOC MD-V2. →plan: "🆕 EPDOC MD-V2".
- [ ] **4.5** Tamagotchi agent-creation render fix. →plan: "🆕 OSAURUS AGENT CREATION = KEEP TAMAGOTCHI".
- [ ] **4.6** MOTION LANGUAGE triad + mode-entry animations + APP-WIDE ASCII typewriter/time-machine ontology
  (titles + display-only; never in editors; blur-coupled). →plan: "✅ MOTION LANGUAGE = TRIAD" + "🆕 APP-WIDE
  ANIMATION INITIATIVE" + "🆕 MODE-ENTRY TRANSITION ANIMATIONS".
- [ ] **4.7** UI chrome: model picker, command palette, 38-tool panel — NOT `[x]` until D5 screenshot proves it.
  →plan: "ACT reskin — PRESERVE the model picker...".
- [ ] **4.8** Tolaria + other clones; MAS non-restrictive. →plan: "🔒 SET IN STONE — MAS NON-RESTRICTIVE".
- [ ] **4.9** ACT wiring: skills+MCP+tools; Keychain for API keys.
  →plan: `docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md`.
- [ ] **4.10** Per-model Epistemos Picks profiles — research profile + use-case blurb in picker.
  →plan: `docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md` per-model profiles + "DESIGN DECISION — \"Epistemos Picks\"".
- [ ] **4.11** Test-parity gate before chat surface deletion — act coverage ≥ quarantined chat.
  →plan: `docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md` test-parity before retire.
- [ ] **4.12** Prose editor + MD-V2 coexist — both first-class; Prose = Apple-Notes-grade native bar;
  loved notes sidebar preserved; MD-V2 does NOT replace Prose.
  →plan: "🆕 PROSE EDITOR + MD-V2 COEXIST".
- [ ] **4.13** Loved assets preserve — real tabs (system + code editor), palette+font customization core
  differentiator; minimal landing-workspace ontology.
  →plan: "🆕 MORE LOVED ASSETS TO PRESERVE" + "🌟 DESIGN SOUL + PROTECTED ASSETS".

- [ ] **4.14** BEYOND clone surfaces (future integrations) — beyond tab hosts honest stubs or wired clones
  (Tolaria reference lane, Epdoc-fuse, other non-agent integrations per plan); NOT Companion-backend. MAS-fit
  research per clone before claiming green.
  →plan: per-clone MAS-fit + Tolaria reference + "AND non-agent" clones scope.

- [ ] **4.15** Multi-clone settings polish + data carry-over per clone — prefs/sessions where plan requires
  per-clone persistence; extends 0.21/4.1; screenshot all four tabs after changes.
  →plan: "🆕 PER-CLONE SETTINGS" + CHAT_BACKEND data carry-over + NEVER-IDLE beyond tabs.

- [ ] **4.16** Graph-deep-integration pillar — graph chat surfaces on act/work paths; graph as first-class agent
  context (not sidebar-only); hologram/Metal graph preserved; per-surface cert pairs with 0.2/1.6.
  →plan: DESIGN SOUL "deep graph integration" + ALL CHAT SURFACES graph half.

- [ ] **4.17 Vault→GRAPH population + LLM-wiki UI surfacing** — vault notes/links populate the knowledge graph;
  LLM-wiki / wiki-link UI surfaced natively (extends 4.3 vault pillar — graph population is NOT covered by 4.3 alone).
  →plan: "🌟 PILLAR — VAULT-DEEP-INTEGRATION" (GRAPH + LLM-wiki bullets) + addendum vault→GRAPH directives.

- [ ] **4.18 EPDOC MD-V2 inversion + agent-edit provenance** — md = source of truth; html/json = projections;
  agent edits carry provenance witness (extends generic 4.4 — inversion + provenance nuances must not silently skip).
  →plan: "🆕 EPDOC MD-V2" + vault→GRAPH / agent-edit provenance sections + `docs/research/MD_V2_INVERSION_GROUNDING_2026_06_21.md`.

## TIER 5 — DISTRIBUTION + OPTIMIZATION
- [ ] **5.1** Dual-build MAS+Pro. →plan: "🔒 DUAL-BUILD DISTRIBUTION MODEL".
- [ ] **5.2** Deep-optimization cycles (standing). →plan: "🆕 DEEP OPTIMIZATION CYCLES".
- [ ] **5.3** MAS-safe OsaurusCore split — Pro full; MAS package without VM/Sparkle/Containerization so act=Osaurus on MAS.
  →plan: "🔒 SET IN STONE — MAS NON-RESTRICTIVE" + DEFINITIVE ACT-UI MAS NOTE.
- [ ] **5.4** MAS VM sandbox substitute research — WASM in-process / cloud-backed partial substitutes vs omit on
  MAS; honest reduced-power verdict; full Linux-VM stays Pro/direct-dist only. →plan: "🆕 RESEARCH — MAS-compatible
  substitute for the VM sandbox".

## ACCEPTANCE GATES — W/B/S runtime rubric (pass49 P0-4/P0-6 stubs)

> **Act has D1–D5 (0.8).** Work, beyond, and substrate/orchestrator tiers MUST NOT reach `[x]` on build-green or
> stub PNG alone. Each gate is a **runtime acceptance test** — same 5-gate bar as act; cite test + artifact in
> STRICT_RECERT_LOG. Pairs with queue items noted.

### W-gate — WORK clone (pairs 0.28, 1.2–1.9)
- **W1** OpenCode/work binary vendored + launches on WORK open — pairs **1.1**; screenshot work landing discoverable
  (act/work toggle or search→work) — **separate PNG from act**
- **W2** Real OpenCode TUI visible — screenshot work composer/TUI
- **W3** Work terminal fully theme-responsive (palette from live `EpistemosTheme`) — screenshot proves palette match
- **W4** Work send reaches OpenCode/Goose engine — **REQUIRED** headless work-lane send-text harness; log prompt +
  ~80 chars + engine lane identity + **served-model == selected-model** where applicable; **NO silent act fallback**
- **W5** Act↔work toggle + blur transition — screenshot BOTH landing states + transition; pairs **0.3/1.6/4.6**
  (Electron/Chromium absence verified under **1.8**, not W5)

### B-gate — BEYOND clone (pairs 0.30, 4.14)
- **B1** Beyond tab renders with honest stub/wired label per future clone
- **B2** Companion-backend OFF-LIMITS grep — `companions.rs`, `CompanionCreationFlow`, new-model interrupt **NOT**
  on live beyond path (grep + route cite)
- **B3** In-scope future clones (Tolaria, Epdoc-fuse, Tamagotchi) listed with plan ref; **stub ≠ `[x]`** — use
  `[ ] STUBBED(plan ref)` until wired + B-gate proof

### S-gate — SUBSTRATE + orchestrator (pairs 2.1–2.8, 3.1–3.2)
- **S1** AnswerPacket load-on-launch + history surface primary witness (**2.1**) — real-state test, not stub row
- **S2** Real-state integration test on **LIVE wired path** — NOT cargo-test-only; cite test name + **runtime artifact**
  (log line / health-row value / AnswerPacket field). **Gate (e) for headless = this integration test**, per
  `docs/fusion/ARCHITECTURE_TIER_PROMOTION_CANON_2026_06_06.md` **T4** (compiled-in-scope, reachable, visible,
  logged, AnswerPacket-visible, rollback-bound)
- **S3** TRINITY/System G route selected+logged when certifying **3.1** — integration log/RunEventLog cite, not symbol grep
- **S4** Eidos recall/rerank + EML abstain gate (**2.5/2.6**) — NOT fake-green; conflict → abstain witness
- **S5** BUILD-IT-HARDENED (**2.8**) real-state passes **before** integrating into live/clone paths

## STANDING (every item, every loop)
No fake-done · screencapture+send-text every iteration · build-green ≠ done · **act certified ≠ loop done** ·
no red on main · code-more-build-less · never delete chat IP · NO-ADDED-TERMS · NO-QUEUE-JUMPING ·
latest-owner-directive-wins (🔒/DEFINITIVE beats older sections) · 70B/new-model EXCLUDED ·
**STEP-0 RESET:** revert any queue `[x]`/`[~]`→`[ ]` each phase; STRICT_RECERT_LOG = sole cert record ·
**`[~]` CAP ≤2/phase:** 3rd halts + owner push; each `[~]` logs exact failing cmd+output ·
**TIER ADVANCE FLOOR:** every 3 iterations highest attempted ≥1.1 OR stall report; act fixes IN PARALLEL with
T1+ cert (not precondition) ·
**FULL-PLAN-NO-ACT-TUNNEL:** certify ENTIRE addendum queue (0.1→0.32, TIER 1→5), not act/D1–D5 only ·
**Companion-backend OFF-LIMITS** (companions.rs, CompanionCreationFlow, new-model interrupt) — **work + beyond
future clones IN SCOPE** · main-only · Co-Authored-By Claude · P0 owner reports preempt · **NEVER-IDLE:** heavy
work = incremental slices, not defer (→plan: "🔁 NEVER-IDLE") · **ACT-before-WORK polish WITHIN TIER 0 only:**
finish act surface bugs before WORK polish inside TIER 0 — does NOT permit skipping TIER 1+ full walk (→plan:
"⏫ PRIORITY finish ACT before WORK polish") · **FAVOR OSAURUS on engine/capability clash:** Osaurus wins
runtime/streaming/tool/provider truth; Epistemos wins visible surface/chrome; cherry-pick owner IP that works WITH Osaurus
(→plan: "🆕 CONFLICT-RESOLUTION: FAVOR OSAURUS") · **OWNER MESSAGES → PLAN+QUEUE:** every owner directive
captured in addendum AND indexed here same iteration (→plan: THREE STANDING DIRECTIVES §1) · **EXTERNAL RESEARCH
CORPUS:** read-only `~/Downloads` Helios/source docs when unification/salvage needs them; copy-in only, never
modify outside repo (→plan: "🆕 EXTERNAL RESEARCH CORPUS") · **COMPLETENESS CRITIC / DISCOVERY SWEEP each loop:**
per-tier plan-section→queue reconciliation (TIER 0–5 — substrate/TRINITY/vault/Epdoc/distribution/clones, NOT
chat-only) PLUS grep InferenceState/model picker/chat send consumers; add missed surfaces to queue (→plan:
DISCOVERY-SWEEP MANDATE) · **REVERSE ADDENDUM AUDIT each loop:** item 0.31 — **full addendum heading diff** +
supplemental grep; index or add queue row; paste diff output to log under `## Certification log` ·
· **FULL-CLONE PROCESS:** every adopted engine (Osaurus, OpenCode, future beyond clones) follows vendored-clone
method per plan — not one-off shims (→plan: "🔒 STANDING — THE FULL-CLONE PROCESS" + "🌟 INITIATIVE — ADOPT
PROVEN ENGINES, LAYER MY IP") · **W/B/S ACCEPTANCE GATES:** do NOT mark TIER 1/2/3/4 work/beyond/substrate items
`[x]` until matching W/B/S gate passes (see ACCEPTANCE GATES section; pass49 P0-4/P0-6) · **MARKET POSITION:**
research monitor only — no product claim until owner promotes (→plan: "🌟 MARKET POSITION") · **PHASE COMPLETE
PRECONDITIONS (pass49 P0-5):** **"STRICT RE-CERT COMPLETE" FORBIDDEN** while ANY queue box is still `[ ]` or while
any in-scope clone lacks ≥1 real runtime proof (stubs excluded). When all boxes are `[x]` or honest `[~]`, phase
ends only with green xcodebuild this phase + per-surface PNG Read this phase + send-text real reply this phase —
list all three in summary.
