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
> matching D-item passes YOUR screencapture (e.g. 0.1 isn't `[x]` until D5 shows cream/monospace).
>
> **D4 / Configuration is TIER-0 blocking** — wire act/Osaurus config + settings in 0.11/0.22; do NOT defer
> to queue 4.1 while leaving TIER 0.

THIS file is SMALL and the loop RE-READS IT IN FULL EVERY ITERATION. Each item POINTS to its plan section
(read ONLY that section for the current item). Authority =
docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md (do NOT shorten).

RULES (every loop, non-negotiable):
- **QUEUE = INDEX, NOT SPEC.** Open the item's full `→plan:` section; implement EVERY nuance there.
- **KEEP QUEUE COMPLETE:** any plan directive not indexed → ADD it here + point to plan section.
- **WALK ORDER:** first unchecked item, **numeric order** (0.1, 0.2, … 0.32, then 1.1, 2.1, … 5.3). **No early
  exit** after act/TIER 0 — continue through TIER 1–5 every iteration until full walk attempted or true `[~]`.
- **FULL-PLAN-NO-ACT-TUNNEL:** do NOT declare an iteration done, stop certifying, or narrow scope to act-only
  until you have attempted the full queue walk (0.1→0.32, then TIER 1→5) OR marked the sole remaining item(s)
  `[~]` with explicit reason. Per-clone matrix (Epistemos|act|work|beyond) applies where the plan requires.
- **RUNTIME:** YOU verify — build → open → `screencapture` → `Read` PNG. Owner is NOT checking.
  `[~]` = TRUE last resort only (state why screencapture + send-text both failed). Never `[x]` on build-green.
- Update queue + `docs/research/STRICT_RECERT_LOG_2026_06_22.md` each loop. Commit + push. No fake-done.
- Never delete chat IP. main-only. Co-Authored-By Claude.

STRICT CERTIFICATION BAR — `[x]` only when ALL hold:
  (a) EXISTS file:line · (b) CORRECT & ON-PLAN (mandated approach, not near-miss/drift) · (c) WIRED &
  REACHABLE · (d) REAL-STATE TESTED · (e) RUNTIME proven by YOU (screencapture and/or send-text harness).

## TIER 0 — ACT SURFACE + FULL-PLAN CLONE BASELINE (P0 act blocking; NOT the whole plan)

> TIER 0 finishes the broken act surface AND indexes clone/substrate prerequisites. **Certifying TIER 0 does
> NOT close the loop** — you MUST continue TIER 1 (work/OpenCode), TIER 2 (substrate/salvage), TIER 3–5 in
> the same strict walk. Do not stop after D1–D5 pass.

- [ ] **0.1 Reskin at VENDORED THEME SOURCE** — edit `LocalPackages/osaurus/.../Models/Theme/Theme.swift`
  defaults so Osaurus views NATIVELY render cream/monospace (#fbfaf5/#f4f3ee, #1c1c1e, SF Mono). NOT runtime
  `applyCustomTheme` alone (proven not to cascade; ba2f8952f drift). Screenshot: cream/monospace on act.
  →plan: "🎯 RESKIN FIX — edit the VENDORED Osaurus theme at SOURCE" + "🔴🔴🔴 P0 ...RESKIN NOT RENDERING".

- [ ] **0.2 ALL chat surfaces → same Osaurus act host** — main mounted; mini still Epistemos-native; graph
  still `triageService.streamGeneral`; note unverified. Route mini+graph+note through Osaurus act host. WORK
  mode in all but note. Screenshot EACH surface separately (main ≠ enough).
  →plan: "🆕 ALL CHAT SURFACES GET THE CHAT→ACT/OSAURUS UPGRADE" + "✅ CONSENSUS — KEEP TriageService".

- [ ] **0.3 LANDING → BLUR → ACT** — Epistemos `LandingView` FIRST; click → blur → Osaurus host. NOT
  Osaurus default landing ("Good morning" + download/provider buttons). Screenshot landing, then post-blur act.
  →plan: "🔴🔴🔴 P0 (11:30am) ...LANDING FLOW" + "landing BLUR transitions".

- [ ] **0.4 SEND works (runtime)** — in-process reply, owner's model, no HTTP requestFailed, no silent
  Codex/Qwen. Send-text harness every iteration; log prompt + ~80 chars of reply.
  →plan: "🎯 PINPOINTED ActOsaurusError error 2" + "P0-A".

- [ ] **0.5 Mini-chat + grab-chat reachable** — wired, discoverable. **Screenshot EACH surface separately**
  (main act, mini, grab-chat if present) — one PNG per surface; main-only does NOT satisfy 0.5.
  →plan: addendum mini-chat section + "🔴🔴🔴 P0 ...RESKIN NOT RENDERING" §mini-chat + PER-SURFACE mandate.

- [ ] **0.6 RE-CERTIFY claimed-done** — duplicate-toggle gone · friendly errors · scroll-blur graft ·
  side-panel graft · white-bar/search fix · model-default seed · clean titles — file:line + runtime each.
  →plan: pass-30/31 audit items + "ACT SURFACE — UI BUGS to fix".

- [ ] **0.7 Message-bar graft** — reskin Osaurus composer to Epistemos feel (owner-verify); not literal swap
  if it breaks send path. Screenshot composer.
  →plan: "⚠️ MESSAGE-BAR graft" + "🔒🔒 DEFINITIVE ACT-UI DIRECTION" graft #1.

- [ ] **0.8 D1–D5 RUNTIME DEFECTS (acceptance gate for 0.1–0.7)** — screenshot-verify ALL before act certified:
  D1 curved window+shadow · D2 owner landing not Osaurus default · D3 pill back · D4 config/settings work ·
  D5 full reskin + model picker/palette/38-tool panel. Ground truth PNG:
  `docs/research/osa_runtime_2026_06_22.png` (re-capture after fixes).
  →plan: "🔴 OWNER-REPORTED RUNTIME DEFECTS" + strict prompt D-section.

- [ ] **0.9 ACT FIDELITY** — stream every token; preserve thinking blocks+signatures; real tool-call parsing;
  no `<think>` leak in titles/output; **CLASSIFY shared-vs-chat-only** before fixing regressions
  (shared pipeline bugs ≠ chat-only). Real-state test + screenshot reasoning reply.
  →plan: "🔴🔴 P0 REGRESSION — reasoning-model output broken in LIVE chat" + "🔴 P0 REGRESSION — CLASSIFY
  shared-vs-chat-only" + CHAT_BACKEND_QUARANTINE fidelity.

- [ ] **0.10 DATA CARRY-OVER** — saved chats/sessions/prefs migrate to act; no lost history.
  →plan: CHAT_BACKEND_QUARANTINE "Data/persistence carry-over".

- [ ] **0.11 Provider wiring + Epistemos Picks** — owner GGUF/QAT selectable AND used on send; "Add a
  provider"/Configuration opens REAL settings; NO silent Codex default. Send must use selected model.
  →plan: "OWNER'S MODELS IN CHAT" + "DEEP CHECK §2" + "DESIGN DECISION — Epistemos Picks".

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

- [ ] **0.17 LOCKED ACT direction** — Osaurus OWN UI reskinned + 3 grafts; SUPERSEDES option-(b) old ChatView.
  Do NOT mount `Epistemos/Views/Chat/ChatView.swift` for act. Latest 🔒/DEFINITIVE wins over older addendum.
  →plan: "🔒🔒 DEFINITIVE ACT-UI DIRECTION" + "🔴🔴 ACT = OSAURUS IS THE CHAT".

- [ ] **0.18 Model provider registration** — `EpistemosOsaurusModelProvider` registered at bootstrap; yields
  usable model on send path (P0-A).
  →plan: "🎯 PINPOINTED ActOsaurusError" + "ACT = OSAURUS IS THE CHAT" §FIX act errors.

- [ ] **0.19 Chat surface deletion sequence** — mount Osaurus host → verify send/receive → port IP → delete old
  chat SURFACE (owner authorized); preserve IP per quarantine doc; no toggle limbo.
  →plan: "ACT = OSAURUS IS THE CHAT" §THE BUILD steps 1–4 + QUARANTINE doc.

- [ ] **0.20 Collapse act/chat duality** — remove CoworkChatMode depth axis + depth toggle; act/work only.
  →plan: "ACT = OSAURUS IS THE CHAT" step 3.

- [ ] **0.21 Per-clone SETTINGS matrix (D4 blocking)** — **Epistemos (main) | act | work | beyond** tabs each
  open that clone's REAL settings (not flattened/dropped). Configuration on act opens act/Osaurus settings;
  work tab opens OpenCode/work settings when wired; beyond tab reserved for future clones (Talaria, Epdoc-fuse,
  etc.) per plan. Screenshot **each tab** separately. Queue 4.1 extends polish — D4 must pass in TIER 0.
  →plan: "🆕 PER-CLONE SETTINGS" + D4 in OWNER-REPORTED DEFECTS + per-clone MAS-fit research.

- [ ] **0.22 ONE inference chokepoint (act path)** — single in-process path for act send; no stray HTTP server
  `requestFailed`. Pairs with 0.4/0.18.
  →plan: "🎯 DIRECTIVE — ONE INFERENCE CHOKEPOINT" + "🎯 PINPOINTED ActOsaurusError".

- [ ] **0.23 Send-text harness (EVERY iteration — standing)** — build/maintain headless harness driving real
  act inference; log prompt + ~80 chars of reply each loop. If missing, BUILD before other work.
  →plan: strict prompt MANDATORY FUNCTIONAL PROOF + "🎯 PINPOINTED ActOsaurusError".

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
  main settings + one non-act surface (graph or notes). Distinct from act/Osaurus host.
  →plan: "🆕 PER-CLONE SETTINGS" (Epistemos tab) + "🆕 MORE LOVED ASSETS TO PRESERVE" + DESIGN SOUL.

- [ ] **0.28 WORK clone surface reachable (TIER-0 index; build in TIER 1)** — work mode discoverable via
  act/work toggle + search→work landing; OpenCode/work shell reachable (even if stubbed — certify honesty).
  Screenshot work landing/TUI separately from act. Note chat = act only (no work).
  →plan: "✅ RESOLVED OPENCODE UI" + "Where WORK goes" + dual landing+blur + mode-entry animations.

- [ ] **0.29 Per-clone inference routing** — act send → Osaurus/in-process act path; work send → OpenCode/work
  engine path; main/Epistemos triage paths unchanged where plan says; NO cross-clone silent fallback (Codex/Qwen).
  Real-state test + send-text per lane where harness exists.
  →plan: "🎯 DIRECTIVE — ONE INFERENCE CHOKEPOINT" + "✅ CONSENSUS — KEEP TriageService" + WORK ENGINE = ARCH C.

- [ ] **0.30 BEYOND clone tab + scope honesty (in-scope vs OFF-LIMITS)** — beyond settings tab exists or is
  honestly stubbed with plan ref; **Companion-backend clones OFF-LIMITS** (companions.rs, CompanionCreationFlow,
  new-model interrupt internals) — do NOT cert beyond as Companion. **Work + beyond future clones IN SCOPE**
  (Talaria reference, Epdoc-fuse, Tamagotchi render-fix). Document what's stub vs wired.
  →plan: "🆕 PER-CLONE SETTINGS" beyond tab + Tamagotchi + Talaria/Tolaria reference + OFF-LIMITS guard.

- [ ] **0.31 Reverse addendum audit (EVERY iteration — standing)** — after forward queue walk: grep addendum for
  🔒, DEFINITIVE, P0, MUST, BUILD-IT-HARDENED, ALL CHAT SURFACES; verify EACH is indexed in this queue or
  STANDING with →plan ref. Missing directive → ADD queue row same iteration. Log in STRICT_RECERT_LOG.
  →plan: THREE STANDING DIRECTIVES §1 + COMPLETENESS / DISCOVERY-SWEEP MANDATE.

- [ ] **0.32 Full-plan iteration witness (EVERY iteration — standing)** — before declaring iteration done: state
  highest item attempted (e.g. "walked through 2.3"), count `[x]`/`[~]`/`[ ]` per tier, confirm
  FULL-PLAN-NO-ACT-TUNNEL honored (not act-only). If stopped at TIER 0, state why next tier blocked with evidence.
  →plan: strict prompt FULL PLAN CERTIFICATION + NEVER-IDLE.

## TIER 1 — WORK MODE (OpenCode)
- [ ] **1.1** OpenCode launcher binary vendored. →plan: "🆕 BUN RUNTIME = VENDORED/BUNDLED".
- [ ] **1.2** WORK = OpenCode real TUI; mini/graph (not note); search→work; dual landing+blur.
  →plan: "✅ RESOLVED OPENCODE UI" + "✅ WORK LOOK = real TUI".
- [ ] **1.3** Goose/Hermes/OpenClaw fuse beneath OpenCode. →plan: "✅ DECISION WORK ENGINE = ARCH C".
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
  act/Osaurus; headless harness or real-state test when available. No silent act fallback.
  →plan: "✅ DECISION WORK ENGINE = ARCH C" + 0.29 routing + Bun runtime vendored.

## TIER 2 — SUBSTRATE + SALVAGE
- [ ] **2.1** SUBSTRATE Phase 2 AnswerPacket — re-cert load-on-launch; history surface + primary witness.
  →plan: `docs/research/SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md`.
- [ ] **2.2** Helios salvage (7 items): eidos.query, provenance ledger, confidence_floor, AnswerPacket/wbo6,
  L1 memory, InterruptScore, HW tier. →plan: "✅ HELIOS-ERA IP ... salvage list".
- [ ] **2.3** GUS salvage 1–18 (verify absent vs live). →plan: GRAND SWEEP cycles 1–3.
- [ ] **2.4** UNIFICATION: one orchestrator+TRINITY+router+chokepoint; fix eidos fake-green; dead code cleanup.
  →plan: "✅ UNIFICATION VERDICT".
- [ ] **2.5** EML honesty gate (GUS-2) — EML/Belnap → AnswerPacket abstain gate.
  →plan: GRAND SWEEP GUS-2.
- [ ] **2.6** Eidos recall/rerank — real wiring, NOT fake-green. →plan: GUS-5 + Helios salvage.
- [ ] **2.7** Agent-stack convergence + dual MLX clash — ONE agent-loop/runtime of record; dedup cloned
  capabilities; fix vmlx-swift vs mlx-swift-lm clash; all cloned logic deeply serves the app (no dead clones).
  →plan: "🆕 AGENT-STACK CONVERGENCE" + docs/research/AGENT_STACK_CONVERGENCE_RESEARCH_2026_06_21.md.
- [ ] **2.8** BUILD-IT-HARDENED gates — finish salvage/unification with real-state tests; go-back-and-unify
  in-flight TRINITY/System G with unification verdict; harden BEFORE integrating into live/clone paths.
  →plan: "🔨 BUILD-IT-HARDENED + GO-BACK-AND-UNIFY".

## TIER 3 — ORCHESTRATOR / FUGU / TRINITY
- [ ] **3.1** TRINITY native orchestrator on System G/RuntimeRouter. →plan: "🌟🌟 TRINITY" + port spec.
- [ ] **3.2** Fugu optional guest provider (never the brain). →plan: "🌟 FUGU FOUNDATIONAL".

## TIER 4 — OWNER-FACING / CLONES / PILLARS
- [ ] **4.1** Per-clone SETTINGS polish (extends 0.21). →plan: "🆕 PER-CLONE SETTINGS".
- [ ] **4.2** System-prompts library + Epistemos Picks per-model prompts. →plan: "🆕 SYSTEM-PROMPTS LIBRARY".
- [ ] **4.3** VAULT-DEEP-INTEGRATION pillar. →plan: "🌟 PILLAR — VAULT-DEEP-INTEGRATION".
- [ ] **4.4** EPDOC MD-V2. →plan: "🆕 EPDOC MD-V2".
- [ ] **4.5** Tamagotchi agent-creation render fix. →plan: "🆕 OSAURUS AGENT CREATION = KEEP TAMAGOTCHI".
- [ ] **4.6** MOTION LANGUAGE triad + mode-entry animations. →plan: "✅ MOTION LANGUAGE = TRIAD".
- [ ] **4.7** UI chrome: model picker, command palette, 38-tool panel — NOT `[x]` until D5 screenshot proves it.
  →plan: "ACT reskin — PRESERVE the model picker...".
- [ ] **4.8** Talaria + other clones; MAS non-restrictive. →plan: "🔒 SET IN STONE — MAS NON-RESTRICTIVE".
- [ ] **4.9** ACT wiring: skills+MCP+tools; Keychain for API keys. →plan: CHAT_BACKEND_QUARANTINE.
- [ ] **4.10** Per-model Epistemos Picks profiles — research profile + use-case blurb in picker.
  →plan: CHAT_BACKEND_QUARANTINE per-model profiles + "DESIGN DECISION — Epistemos Picks".
- [ ] **4.11** Test-parity gate before chat surface deletion — act coverage ≥ quarantined chat.
  →plan: CHAT_BACKEND_QUARANTINE test-parity before retire.
- [ ] **4.12** Prose editor + MD-V2 coexist — both first-class; Prose = Apple-Notes-grade native bar;
  loved notes sidebar preserved; MD-V2 does NOT replace Prose.
  →plan: "🆕 PROSE EDITOR + MD-V2 COEXIST".
- [ ] **4.13** Loved assets preserve — real tabs (system + code editor), palette+font customization core
  differentiator; minimal landing-workspace ontology.
  →plan: "🆕 MORE LOVED ASSETS TO PRESERVE" + "🌟 DESIGN SOUL + PROTECTED ASSETS".

- [ ] **4.14** BEYOND clone surfaces (future integrations) — beyond tab hosts honest stubs or wired clones
  (Talaria reference lane, Epdoc-fuse, other non-agent integrations per plan); NOT Companion-backend. MAS-fit
  research per clone before claiming green.
  →plan: per-clone MAS-fit + Talaria/Tolaria reference + "AND non-agent" clones scope.

- [ ] **4.15** Multi-clone settings polish + data carry-over per clone — prefs/sessions where plan requires
  per-clone persistence; extends 0.21/4.1; screenshot all four tabs after changes.
  →plan: "🆕 PER-CLONE SETTINGS" + CHAT_BACKEND data carry-over + NEVER-IDLE beyond tabs.

- [ ] **4.16** Graph-deep-integration pillar — graph chat surfaces on act/work paths; graph as first-class agent
  context (not sidebar-only); hologram/Metal graph preserved; per-surface cert pairs with 0.2/1.6.
  →plan: DESIGN SOUL "deep graph integration" + ALL CHAT SURFACES graph half.

## TIER 5 — DISTRIBUTION + OPTIMIZATION
- [ ] **5.1** Dual-build MAS+Pro. →plan: "🔒 DUAL-BUILD DISTRIBUTION MODEL".
- [ ] **5.2** Deep-optimization cycles (standing). →plan: "🆕 DEEP OPTIMIZATION CYCLES".
- [ ] **5.3** MAS-safe OsaurusCore split — Pro full; MAS package without VM/Sparkle/Containerization so act=Osaurus on MAS.
  →plan: "🔒 SET IN STONE — MAS NON-RESTRICTIVE" + DEFINITIVE ACT-UI MAS NOTE.

## STANDING (every item, every loop)
No fake-done · screencapture+send-text every iteration · build-green ≠ done · **act certified ≠ loop done** ·
no red on main · code-more-build-less · never delete chat IP · NO-ADDED-TERMS · NO-QUEUE-JUMPING ·
latest-owner-directive-wins (🔒/DEFINITIVE beats older sections) · 70B/new-model EXCLUDED ·
**FULL-PLAN-NO-ACT-TUNNEL:** certify ENTIRE addendum queue (0.1→0.32, TIER 1→5), not act/D1–D5 only ·
**Companion-backend OFF-LIMITS** (companions.rs, CompanionCreationFlow, new-model interrupt) — **work + beyond
future clones IN SCOPE** · main-only · Co-Authored-By Claude · P0 owner reports preempt · **NEVER-IDLE:** heavy
work = incremental slices, not defer (→plan: "🔁 NEVER-IDLE") · **FAVOR OSAURUS on clash:** Osaurus wins
engine/structure; cherry-pick owner IP that works WITH Osaurus; front-end stays minimal Epistemos pixel-art
(→plan: "🆕 CONFLICT-RESOLUTION: FAVOR OSAURUS") · **OWNER MESSAGES → PLAN+QUEUE:** every owner directive
captured in addendum AND indexed here same iteration (→plan: THREE STANDING DIRECTIVES §1) · **EXTERNAL RESEARCH
CORPUS:** read-only `~/Downloads` Helios/source docs when unification/salvage needs them; copy-in only, never
modify outside repo (→plan: "🆕 EXTERNAL RESEARCH CORPUS") · **COMPLETENESS CRITIC / DISCOVERY SWEEP each loop:**
grep InferenceState/model picker/chat send consumers; add missed surfaces to queue (→plan: DISCOVERY-SWEEP
MANDATE) · **REVERSE ADDENDUM AUDIT each loop:** item 0.31 — grep 🔒/DEFINITIVE/P0/MUST; index or add queue row.
· **FULL-CLONE PROCESS:** every adopted engine (Osaurus, OpenCode, future beyond clones) follows vendored-clone
method per plan — not one-off shims (→plan: "🔒 STANDING — THE FULL-CLONE PROCESS").
