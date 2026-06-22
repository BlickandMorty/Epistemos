# STRICT RE-CERTIFICATION LOOP PROMPT (2026-06-22) — paste this as the NEW loop driver

> Owner (verbatim, 2026-06-22): *"it needs to be super strict … it has to UNCHECK EVERYTHING. It said it did
> already and must re-verify that it all is coded correctly and then resume — this includes the Osa work and
> even things before that, cause I just can't trust that it is complete. So it truly truly needs to restart
> everything — NOT undo everything, but it needs to re-read, start from the beginning and go through it … truly
> start from the very beginning of the plan and recertify/reverify, and then continue — but it shouldn't be a
> lazy continue or a lazy verification. It should be truly robust."*

You are the Epistemos build loop (cwd /Users/jojo/Downloads/Epistemos), running in **STRICT RE-CERTIFICATION
MODE**. The prior loop's "done" marks are NOT trusted — context may have drifted, build-green was mistaken for
runtime-done, and approaches diverged from the plan. Your job this phase: **re-certify the ENTIRE addendum plan
top-to-bottom with robust grounded evidence, fix what's actually wrong, and only then continue new work.** Act/D1–D5
is P0 blocking for owner pain — it is NOT the sole certification scope.

## FULL PLAN CERTIFICATION (owner 2026-06-22 — supersedes act-only tunnel vision)

**The loop certifies the ENTIRE multi-feature plan**, not just the act surface. Every iteration MUST attempt a
full queue walk unless the sole remaining open items are honestly `[~]` with reason.

### What "full plan" means (non-exhaustive — queue is authoritative)
- **All clones:** Epistemos (main) | act (Osaurus) | work (OpenCode) | beyond (future clones tab)
- **All chat surfaces:** main, mini, graph, note (act); mini+graph also work where plan says; per-surface PNG
- **Substrate + salvage:** AnswerPacket, Helios/GUS salvage, unification, EML, Eidos, agent-stack convergence,
  BUILD-IT-HARDENED gates
- **Orchestrator layer:** TRINITY, Fugu, System G / RuntimeRouter honesty
- **Owner-facing pillars:** per-clone settings, system-prompts library, vault-deep-integration, Epdoc MD-V2,
  motion language, UI chrome (picker/palette/38-tool panel), Talaria/beyond scope, MAS boundaries
- **Distribution:** dual-build MAS+Pro, deep-optimization cycles, MAS-safe OsaurusCore split
- **Data + deletion sequence:** carry-over, chat surface delete gates, UI-hide quarantine
- **Health rows + provider wiring:** honest witnesses, Epistemos Picks, no silent Codex/Qwen
- **OFF-LIMITS vs IN-SCOPE:** Companion-backend clones OFF-LIMITS; work + beyond future clones IN SCOPE

### Per-clone certification matrix (screencapture/settings/inference where plan requires)

| Clone | Settings tab | Inference lane | Surfaces to screenshot | Queue anchors |
|-------|--------------|----------------|------------------------|---------------|
| **Epistemos (main)** | Epistemos-native settings | TriageService / vault / graph paths | Main settings, graph, notes sidebar | 0.27, 0.21 |
| **act** | Osaurus/act full settings | Osaurus in-process act path | Main act, mini, graph, note (act) | 0.1–0.26, D1–D5 |
| **work** | OpenCode/work full settings | OpenCode/Goose fused engine | Work landing, TUI, act/work toggle | 0.28, 1.1–1.7 |
| **beyond** | Tab per future clone (honest stub OK) | Per-clone when wired | Beyond tab + any wired clone | 0.30, 4.14 |

### Tier walk order — NO EARLY EXIT
1. **TIER 0:** 0.1 → 0.32 (act + clone baseline + reverse audit + iteration witness)
2. **TIER 1:** 1.1 → 1.7 (OpenCode/work — do NOT skip because act is broken)
3. **TIER 2:** 2.1 → 2.8 (substrate, salvage, BUILD-IT-HARDENED)
4. **TIER 3:** 3.1 → 3.2 (TRINITY, Fugu)
5. **TIER 4:** 4.1 → 4.15 (settings polish, pillars, beyond clones)
6. **TIER 5:** 5.1 → 5.3 (distribution)

**Rules:**
- **Act certified ≠ loop done.** D1–D5 passing does NOT permit stopping the iteration.
- **Build-green ≠ any tier done.** Compile success is floor only.
- **FULL-PLAN-NO-ACT-TUNNEL:** do NOT declare iteration complete after certifying act only. Continue into TIER 1+
  every iteration until full walk attempted or true last-resort `[~]`.
- P0 act defects preempt *within* TIER 0 — they do not cancel the obligation to attempt lower tiers same iteration
  when TIER 0 items are certified or honestly blocked with evidence.

### Reverse addendum audit (EVERY iteration — queue 0.31)
After the forward queue walk, grep the addendum for: `🔒`, `DEFINITIVE`, `P0`, `MUST`, `BUILD-IT-HARDENED`,
`ALL CHAT SURFACES`, `PER-CLONE`. Verify each hit is indexed in WORK_QUEUE or STANDING with →plan ref. Any miss →
ADD queue row + log in STRICT_RECERT_LOG same iteration.

## THE PRIME RULE
- **EVERYTHING STARTS UNCERTIFIED.** Treat every checkbox in docs/WORK_QUEUE_2026_06_22.md (and every "done"/
  "PASS" claim in docs/OSAURUS_BUILD_PROGRESS_2026_06_21.md) as `[ ]` — including the Osaurus/act work AND
  everything built before it. Re-prove each from scratch.
- **DO NOT UNDO. DO NOT DELETE.** This is re-verification, not a revert. Working code stays. You only change
  what you can prove is broken/drifted/fake. (Never delete the chat IP — preserve+port; surface deletes only
  after the four-part bar in CHAT_BACKEND_QUARANTINE doc.)
- **NOT LAZY.** "Looks done" is not certification. Every `[x]` needs cited evidence at the strict bar below.
  A glance, a grep that a symbol exists, or trusting a commit message is NOT enough.

## 🔒 LOCKED RULES (do not reinterpret)
- **LOCKED UI DIRECTION:** ACT UI = Osaurus's OWN UI, reskinned to the Epistemos look + 3 grafts (message bar,
  side panel, scroll-blur). This SUPERSEDES option-(b) "drive the old ChatView." Do NOT revert to the old
  ChatView and do NOT leave raw Osaurus default. Fixing 0.1 alone does NOT close act.
- **D1–D5 ARE GATEKEEPERS:** the act surface is NOT certifiable until D1–D5 all pass YOUR screencapture proof.
- **PLAN WINS OVER CODE:** if code and plan disagree, fix the CODE; never edit the plan to match wrong code
  (e.g. 0.1 must edit the vendored Theme.swift defaults, not only a runtime `applyCustomTheme` shim — ba2f8952f drift).
- **P0 OWNER REPORTS PREEMPT:** any new owner runtime report → append it to the addendum + queue + this prompt's
  D-section the SAME iteration, then fix it before anything else.
- **VOID stale plan sections (do not build these):** option-(b) "drive old ChatView" (§1507), "FULLY RESTORE OLD
  UI" as mount-old-ChatView (§1485), WORK-ENGINE ON HOLD (§607). Authority = §1651 DEFINITIVE + §624 C FINALIZED
  + LOCKED RULES above. Landing = Epistemos `LandingView` FIRST (D2/0.3), NOT Osaurus default landing.

## 🔴 OWNER-REPORTED RUNTIME DEFECTS (2026-06-22, grounded by screenshot docs/research/osa_runtime_2026_06_22.png)
These are CONFIRMED broken on the running act surface RIGHT NOW. Each is a REQUIRED TIER-0 item; you may NOT
mark the act surface certified until ALL are fixed AND re-proven by your own screencapture. Do NOT trust any
"done" on these — the owner is looking at them broken.
- **D1 — Window is BOXY, must be CURVED.** The act window top corners are square. Plan mandates rounded window
  + soft shadow. Epistemos already has the chrome (`Epistemos/App/RootView.swift` uses RoundedRectangle
  cornerRadius 12–22); the Osaurus `ChatView` host renders boxy. Apply the rounded/curved window + soft shadow
  to the act host. Screenshot-verify the top is curved.
- **D2 — Old Epistemos LANDING is missing; it shows Osaurus's DEFAULT landing.** Running surface shows "Good
  morning / How can I help you today?" + Osaurus buttons ("What's configured?", "Download a model", "Add a
  provider", "Install a plugin") + the Osaurus dino greeting. The owner's landing page + landing→blur→act flow
  (queue 0.3) is NOT there. Restore the owner's Epistemos landing (`Epistemos/Views/Landing/LandingView.swift`)
  → press → blur → act (Osaurus host). Screenshot-verify the owner's landing shows first, not Osaurus's.
- **D3 — The PILL is missing.** Owner's old pill chrome is gone (only a tiny "Act/Work" segmented toggle shows).
  The pill exists in code: `ChatCapabilityPill` (Epistemos/Views/Landing/LandingView.swift:1178) +
  `NativePillButtonStyle` (Epistemos/Views/Chat/ChatSidebarView.swift:76) + composer activity pill
  (Epistemos/Views/Chat/ToolActivityNarrator.swift). Bring the owner's pill back onto the act surface.
  Screenshot-verify the pill renders.
- **D4 — Configuration / Settings doesn't work / not visible.** "Configuration" is in the bottom bar but does
  not open real settings. Wire act/Osaurus configuration + per-clone SETTINGS in **queue 0.21 (TIER-0
  blocking)** — do NOT defer to queue 4.1 while leaving TIER 0. Screenshot-verify settings open and work.
- **D5 — Reskin only partial.** Background is lighter but the surface is still Osaurus chrome, not the owner's
  cream/monospace discipline + preserved chrome (model picker w/ real logos + Epistemos Picks, command palette,
  38-tool agent panel — queue 4.7). Finish the reskin so it's the owner's UI with Osaurus logic underneath.
- **GENERAL:** the owner said "there's so many issues" — D1–D5 are the named ones; while certifying the act
  surface, screenshot EVERY part and fix any other divergence from the owner's UI you observe. Do not stop at
  this list if the screenshot shows more wrong.

## EVERY ITERATION
1. **Re-read docs/WORK_QUEUE_2026_06_22.md IN FULL** (it's small; it's the index). Re-read the STRICT banner.
2. **Pick the FIRST unchecked item in NUMERIC order** (0.1 → 0.32, then 1.1 → 1.7, 2.1, … 5.3). No queue-jumping.
   FIRST ITERATION bootstrap order below is one-time only — standing rule is strict numeric queue order through
   ALL tiers. Don't stop after act/D1–D5; don't stop after TIER 0 unless attempting TIER 1+ same iteration.
3. **Read that item's `→plan:` section IN FULL** in docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md. The
   queue line is only a pointer; the plan section is the spec, including every SPECIFIC/nuance.
4. **RE-CERTIFY against the STRICT BAR (all five must hold):**
   - **(a) EXISTS** — the code is present; cite `file:line`.
   - **(b) CORRECT & ON-PLAN** — read it; it does what the plan section's specifics say, via the approach the
     plan mandates (not a near-miss or a different approach the plan already rejected). Example: 0.1 reskin must
     make Osaurus views NATIVELY render cream/monospace at the SOURCE the plan names — a runtime
     `applyCustomTheme` shim that the plan calls "proven not to cascade" does NOT satisfy (b) unless you prove
     at runtime it actually renders cream.
   - **(c) WIRED & REACHABLE** — it's on the live path / discoverable in the running app, not dead-coded or
     flagged off.
   - **(d) REAL-STATE TESTED** — a test exercises real behavior (not a stub / always-true / mocked-away core).
     Run the fast gate (`cargo test --lib` / targeted compile) where cheap; heavy `xcodebuild` only at
     checkpoints; never idle-block.
   - **(e) RUNTIME — YOU verify it; the owner is NOT checking the app.** You are the Claude Code CLI loop: you
     do NOT have a "computer use" button (that flag belongs to the Claude *desktop app*, a different surface —
     do not claim you have it). What you DO have and MUST use, with zero setup:
       • **SEE the app:** `xcodebuild -scheme Epistemos … build` → `open` the .app → `screencapture -x /tmp/epi_<surface>.png`
         → `Read` that PNG and look at it. Confirm with your own eyes: cream/monospace actually renders, the
         landing→blur→act transition actually happens, the surface is actually present. Capture a specific window
         with `screencapture -x -o -l$(window id)` when you need one surface.
       • **DRIVE the app if you must click/type:** `osascript` (AppleScript) for menu/clicks/keystrokes.
       • Prefer a **snapshot/XCUITest** that asserts rendered colors/state where a GUI launch is flaky — still
         YOU proving it. Only mark `[~] NEEDS-OWNER-RUNTIME` as a TRUE last resort (state exactly why no
         screencapture/snapshot path could observe it). Do NOT fake this and do NOT call build-green "rendered."
5. **VERDICT:**
   - All five hold → `[x] CERTIFIED` + one-line evidence (file:line / test name / what renders).
   - (e) unprovable EVEN by screencapture/snapshot (TRUE last resort, (a)-(d) hold) → `[~] NEEDS-OWNER-RUNTIME`
     + exactly what to verify and why no automated path could observe it. This is rare, not the default.
   - Any of (a)-(d) fails → it's **BROKEN/DRIFTED**: FIX IT FOR REAL now (implement the plan's specifics the
     right way), then re-run the bar. Log the gap. Do not check it until it passes.
6. **UPDATE docs/WORK_QUEUE_2026_06_22.md** (status + one-line result/evidence) and append a per-item line to
   docs/research/STRICT_RECERT_LOG_2026_06_22.md (create if missing): item · verdict · evidence · any fix
   commit SHA. Commit + push (git add ONLY the files you changed; never `-A`; Co-Authored-By Claude).
7. **If you find a plan directive not represented in the queue, ADD it** (keep the queue a complete index). New
   owner directives go into the plan AND the queue.

## QUEUE ITEMS 0.11–0.32 (mirror — read queue for full →plan: refs)
- **0.11** Provider wiring + Epistemos Picks (no silent Codex/Qwen) · **0.12** Surface-wiring rule
- **0.13** Shared act component · **0.14** Health-row witnesses honest (wiredToday/stillStub match code)
- **0.15** DEEP CHECK (honest OSAURUS_BUILD_PROGRESS) · **0.16** Reasoning + title-gen (extends 0.9;
  `<think>` parse; CLEAN short titles — no model self-description garbage)
- **0.17** LOCKED direction (Osaurus OWN UI reskinned + 3 grafts; SUPERSEDES option-b) · **0.18** Model provider registration
- **0.19** Chat surface deletion sequence (IP preserved) · **0.20** Collapse act/chat duality
- **0.21** Per-clone settings matrix — Epistemos|act|work|beyond (D4 blocking) · **0.22** ONE inference chokepoint
- **0.23** Send-text harness EVERY iteration · **0.24** Act UI bug bundle · **0.25** Delete old ChatView (GATED)
- **0.26** UI-hide quarantined chat (GATED) · **0.27** Epistemos (main) clone baseline
- **0.28** WORK clone surface reachable · **0.29** Per-clone inference routing
- **0.30** BEYOND tab + OFF-LIMITS vs in-scope honesty · **0.31** Reverse addendum audit (standing)
- **0.32** Full-plan iteration witness (standing)
- **TIER 1:** 1.1–1.7 work/OpenCode · **TIER 2:** 2.1–2.8 substrate/salvage · **TIER 3:** 3.1–3.2 · **TIER 4:**
  4.1–4.15 · **TIER 5:** 5.1–5.3

## MANDATORY BEHAVIOR A–H (from gap audit — non-negotiable every loop)
- **(A) D-GATE RULE:** D1–D5 (item 0.8) are RUNTIME ACCEPTANCE TESTS for 0.1–0.7. Do NOT mark 0.1–0.7 `[x]`
  until the matching D-item passes YOUR screencapture. Queue 4.7 is likewise gated on D5.
- **(B) PER-SURFACE SCREENSHOT MANDATE:** Certify **each** chat surface with its **own** PNG: main act, mini
  chat, graph chat, note chat (act), work (where applicable). A single main-act screenshot does NOT satisfy
  0.2, 0.5, or 0.24.
- **(C) TITLE-GEN EXPLICIT:** Item 0.16 extends 0.9 — parse `<think>`, extract real answer, produce
  CLEAN short titles (no meta-prompt leak, no model self-description as title). Real-state test + screenshot.
- **(D) DISCOVERY SWEEP EACH LOOP:** Completeness critic at end of every iteration — grep InferenceState, model
  picker, chat send paths, capability pills; any surface not in queue → ADD it with →plan ref.
- **(E) NARROW DONE BAR:** `[~]` ONLY if screencapture AND send-text harness BOTH fail (state exactly why).
  Never `[x]` on build-green alone. Never claim "computer use unavailable" — use screencapture + Read + osascript.
- **(F) HEALTH-ROW HONESTY BAR:** Item 0.14 — after every change, re-cert `ActOsaurusHealthRow`,
  `AnswerPacketHealthRow`, `LocalRouteHonestyHealthRow`, etc.: `wiredToday`/`stillStub` must match REAL code.
- **(G) PROVIDER WIRING BAR:** Item 0.11 — owner's GGUF/QAT selectable AND used on send; Configuration opens
  REAL settings; NO silent Codex default; NO silent Qwen substitution. Send must use selected model.
- **(H) FULL-PLAN-NO-ACT-TUNNEL:** Item 0.32 — before iteration ends, confirm you attempted 0.1→0.32 then TIER 1+
  (not act-only). Log highest item reached + per-tier counts. Act certified ≠ loop done.

## PER-SURFACE SCREENSHOT MANDATE
Certify **each** chat surface with its **own** PNG: main act, mini chat, graph chat, note chat (act), work
landing/TUI (where applicable), Epistemos main settings (0.27). A single main-act screenshot does NOT satisfy
0.2, 0.5, 0.28, or 0.21.

## COMPLETENESS CRITIC (every loop, end of iteration)
Grep consumers of `InferenceState`, model picker, chat send paths, capability pills. Any surface not in queue →
ADD it (→plan: "COMPLETENESS / DISCOVERY-SWEEP MANDATE"). Log findings in STRICT_RECERT_LOG.

## MANDATORY EVERY-ITERATION FUNCTIONAL PROOF (owner: do this exhaustively, every loop, no exceptions)
Regardless of which item you're on, EVERY iteration you MUST:
1. **COMPILE / SYNTAX** — `cargo build`/`cargo test --lib` (fast) and `xcodebuild … build` at checkpoints. Red
   never lands on main. This is the floor, not the proof.
2. **EXERCISE THE REAL SEND TEXT, END-TO-END** — actually send a message through the live act/Osaurus inference
   path and assert a REAL non-empty reply streams back (in-process, owner's model, no HTTP requestFailed, no
   silent Qwen substitution). This is HEADLESS and ALWAYS possible — it needs no GUI. If a CLI/test harness that
   drives the real `CoreModelService.generateStream` / bridged-model send path doesn't exist yet, BUILD ONE
   (a tiny test target or CLI) — that harness is itself certifiable work. Run it every iteration. The owner was
   explicit: the send text can and must be checked exhaustively, every single time, by the loop — not audited later.
   Log the prompt sent + the first ~80 chars of the real reply as proof.
3. If either fails, that's the top-priority fix this iteration before anything else.

## DEEP-DEEP RE-CERTIFICATION (owner: "even better than the day I first started")
This is not a rubber-stamp re-read. For each item go DEEPER than the original build: re-derive it from the plan
section, check it's CANONICAL to the plan (exact approach + every nuance, not a near-miss), check edge/error
paths, check it's wired on the live path, and prove it functionally (compile + send-text + screencapture). If
the original was shallow, make it robust now. Stay absolutely canonical with the plan — if code and plan
disagree, the PLAN wins; fix the code (never silently edit the plan to match the code).

## CERTIFY *AND* RESUME (this phase does both)
Re-certification and forward progress are the SAME walk, not two phases. As you re-certify top-to-bottom: items
that pass get `[x]`; items that are broken/drifted/incomplete you FIX and finish to the plan's full spec right
then (that IS resuming). You are not just auditing — you are deeply certifying AND completing every item to a
robust, canonical, functionally-proven state. Keep the queue super-canonical to the plan the whole way.

## DONE-WITH-PHASE-1 BAR (when do you stop re-certifying and "continue"?)
Re-certification of the **ENTIRE plan** (all tiers, all clones) is complete when every queue item is either
`[x] CERTIFIED` or `[~] NEEDS-OWNER-RUNTIME` with a clear owner-verify note — and you've written a short
"STRICT RE-CERT COMPLETE" summary at the top of STRICT_RECERT_LOG (count certified / needs-owner / fixed-during-
recert **per tier**). ONLY THEN resume normal forward work on the lowest still-open tier. **Act surface certified
alone does NOT satisfy this bar.** The "continue" the owner wants is *after* the robust full-plan pass, not instead
of it.

## ▶️ FIRST ITERATION — do exactly this, in order
1. Read this driver IN FULL + docs/WORK_QUEUE_2026_06_22.md IN FULL (every box starts UNCERTIFIED).
2. Screencapture the act surface as a BASELINE → `/tmp/epi_act_baseline.png`, `Read` it (ground truth). If
   `docs/research/osa_runtime_2026_06_22.png` is missing, capture and save it there (see
   `docs/research/osa_runtime_PLACEHOLDER.md`).
3. Build/run the send-text harness (or CREATE it if missing — item 0.23) — assert a REAL reply from the
   owner's model; log the prompt + first ~80 chars.
4. Walk **0.1 → 0.32 in strict numeric order**, then **continue into TIER 1+ same iteration** when TIER 0 items
   pass or are honestly `[~]`. One item minimum per loop; do NOT queue-jump. For each item: read full →plan section
   · apply 5-gate bar · screencapture per-surface where UI · send-text every loop · reverse addendum audit (0.31)
   at end · full-plan witness (0.32) before declaring iteration done.
   TIER 0 act blockers remain P0: **0.1** Theme.swift SOURCE · **0.3** Epistemos landing (D2) · **0.8** D1–D5 ·
   **0.21** per-clone settings matrix. These do NOT cancel TIER 1+ attempt once certified or blocked with evidence.
5. Update the queue + STRICT_RECERT_LOG each loop; commit only your changed files; Co-Authored-By Claude.

**Act certified ≠ iteration done. Do not stop at D1–D5 or build-green.**

## STANDING (every item, every loop)
No fake-done · build-green ≠ done · **act certified ≠ loop done** · runtime-verify UI · no red on main ·
code-more-build-less (fast gate per increment, heavy xcodebuild at checkpoints, never idle-block) · never delete
chat IP (preserve+port; surface delete only after the four-part bar + owner authorization) · NO-ADDED-TERMS ·
NO-QUEUE-JUMPING · **FULL-PLAN-NO-ACT-TUNNEL** · latest-owner-directive-wins · FAVOR OSAURUS on clash · owner
messages → plan+queue same iteration · NEVER-IDLE (heavy = incremental slices) · external ~/Downloads corpus
read-only when salvage needs it · 70B / NEW-MODEL brain-1 EXCLUDED · **Companion-backend OFF-LIMITS** (work +
beyond future clones IN SCOPE) · main-only · Co-Authored-By Claude · P0 owner runtime reports preempt everything
· discovery sweep / completeness critic every loop · **reverse addendum audit (0.31) every loop**.

## AUTHORITY DOCS
- Spec/authority: docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md (do NOT shorten).
- Index: docs/WORK_QUEUE_2026_06_22.md. **Paste block:** docs/AGENT_LOOP_PASTE_READY_2026_06_22.md.
- Living map: docs/OSAURUS_BUILD_PROGRESS_2026_06_21.md.
- Guards: docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md.
- Re-cert log: docs/research/STRICT_RECERT_LOG_2026_06_22.md.
- Runtime PNG placeholder: docs/research/osa_runtime_PLACEHOLDER.md.
- Gap audit (docs maintenance): docs/research/LOOP_GAP_AUDIT_2026_06_22.md.
- **SUPERSEDED (do not use):** docs/AGENT_LOOP_PROMPT_2026_06_21.md, docs/AGENT_LOOP_PROMPT_QUEUE_2026_06_22.md,
  docs/SESSION_CONTINUATION_PROMPT_2026_06_21.md, docs/AGENT_DIRECTIVE_CHECK_PROMPT_2026_06_21.md.
