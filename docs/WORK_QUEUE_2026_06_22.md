# WORK QUEUE (2026-06-22) — the loop's per-iteration source of truth

> ## 🔴 STRICT RE-CERTIFICATION MODE (owner 2026-06-22, agent STOPPED & restarting)
> Owner: *"it has to UNCHECK EVERYTHING … re-verify that it all is coded correctly … I just can't trust that
> it is complete … truly start from the very beginning of the plan and recertify/reverify, and then continue
> … NOT a lazy continue or lazy verification — truly robust."*
>
> **EVERY box below is UNCERTIFIED — treat as `[ ]` regardless of any prior `[x]`/`[~]`.** Do NOT trust any
> past "done"/"PASS" (incl. the Osaurus work AND everything before it). Walk **from item 0.1 top-to-bottom**;
> for each, RE-CERTIFY against its →plan section with grounded evidence (file:line + real-state test + runtime
> for UI) BEFORE re-checking it. `[x]` only when CERTIFIED to the full strict bar (see RULES). **Do NOT undo or
> delete working code** — re-verify in place; fix only what is actually broken/drifted/fake. Loop driver =
> docs/AGENT_LOOP_PROMPT_STRICT_RECERT_2026_06_22.md.
>
> KNOWN OPEN FLAG (re-cert target): **0.1 reskin — commit ba2f8952f used runtime `applyCustomTheme` in host
> init (NOT the vendored Theme.swift source edit the plan mandates); vendored default theme is still DARK
> (#0c0c0b). Must runtime-verify it renders cream; if not, edit the vendored Theme.swift defaults per plan.**

THIS file is SMALL and the loop RE-READS IT IN FULL EVERY ITERATION (cheap + reliable). It does NOT replace the
plan — each item POINTS to its plan section (read ONLY that section's specifics for the current item, not the
whole addendum). The loop UPDATES this file every loop (mark [x] only when RUNTIME-VERIFIED, append findings).
Authority/detail = docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md (do NOT shorten it).

RULES (every loop, non-negotiable):
- **THIS QUEUE IS AN INDEX, NOT THE SPEC.** The one-line item text is ONLY a pointer. For the current item you
  MUST open its `→plan:` section in the addendum and IMPLEMENT EVERY SPECIFIC / NUANCE written there — the
  no-compromise-nuance initiative: do ALL of it, exactly, not a summarized version. The queue guarantees nothing
  is FORGOTTEN; the per-item plan-read guarantees the SPECIFICS are DONE. (Before, the loop skipped specifics —
  this is the fix: always read + do the full plan section for the item, never just the queue line.)
- **KEEP THE QUEUE COMPLETE:** it must index EVERY open directive in the plan. If you find a plan directive not
  represented here, ADD it as an item with its →plan ref. New owner directives go into the plan AND here.
- Re-read THIS queue fully. Pick the FIRST unchecked item in order. Read its FULL →plan section + implement ALL
  its specifics. Do it for REAL.
- RUNTIME-VERIFY before [x] (build-green is NOT done; the reskin/act bugs all passed build but failed at runtime).
  YOU verify it: build → open the app → `screencapture` → `Read` the PNG → confirm with your own eyes. `[~]` is a
  TRUE LAST RESORT only (state why no screencapture/snapshot could observe it) — NOT the default. NEVER mark UI
  done on build-green. Do NOT move past a broken/unverified TIER-0 item to lower tiers.
- Update this queue each loop (status + a one-line result). Commit + push. No fake-done. No red on main.
- Never delete chat IP. main-only. Co-Authored-By Claude.

STRICT CERTIFICATION BAR (re-cert mode — an item earns `[x]` ONLY when ALL hold; else it stays `[ ]`):
  (a) CODE EXISTS — cite file:line; (b) CODE IS CORRECT — read it, it does what the plan section's SPECIFICS
  say (not a near-miss / drift / different approach than the plan mandates — e.g. 0.1 must hit the SOURCE the
  plan names); (c) WIRED + REACHABLE — actually on the live path, not dead/flagged-off; (d) REAL-STATE TESTED —
  a test exercises real behavior (not a stub/always-true); (e) RUNTIME — for ANY UI/visual item it RENDERS/WORKS
  at runtime — YOU prove it by screencapture+Read, not by deferring to the owner. `[~]` only as a TRUE last
  resort with a stated reason no automated path could observe it; never as the default, never `[x]` on build-green. If (a)-(d) fail →
  it's BROKEN/DRIFTED: fix it for real, then re-certify. NO box is trusted from a prior "done" — re-prove it.
  Do NOT delete/revert working code to "restart" — re-certify in place; only change what's actually wrong.

## TIER 0 — ACT SURFACE (BROKEN at runtime — fix + RUNTIME-VERIFY before anything else)
- [ ] **0.1 Reskin Osaurus at the VENDORED THEME SOURCE** — edit LocalPackages/osaurus/.../Models/Theme/Theme.swift
  (+ its color/font defaults) so Osaurus's views NATIVELY render the Epistemos cream/monospace palette
  (#fbfaf5/#f4f3ee surfaces, #1c1c1e text, ink accent, SF Mono/app fonts). NOT runtime applyCustomTheme (it does
  NOT cascade — proven). Verify the act surface RENDERS cream/monospace, not Osaurus default light theme.
  →plan: "🎯 RESKIN FIX — edit the VENDORED Osaurus theme at SOURCE" + "🔴🔴🔴 P0 ...RESKIN NOT RENDERING".
- [ ] **0.2 ALL chat surfaces use the SAME Osaurus act host** — main ✅(mounted), but MINI chat still Epistemos-
  native, GRAPH chat still triageService.streamGeneral, NOTE chat unverified. Route mini + graph + note through
  the Osaurus act host (act). WORK in all but NOTE. Currently only MAIN got it → fix the rest.
  →plan: "🆕 ALL CHAT SURFACES GET THE CHAT→ACT/OSAURUS UPGRADE" + "✅ CONSENSUS — KEEP TriageService".
- [ ] **0.3 LANDING → BLUR → ACT flow** — show the Epistemos LANDING page first; click → BLUR-reveal → act
  (Osaurus host). Currently mounts Osaurus directly, skipping the Epistemos landing + blur. →plan: "🔴🔴🔴 P0
  (11:30am) ...LANDING FLOW" + "landing BLUR transitions".
- [ ] **0.4 SEND actually works (runtime)** — owner's model generates a reply end-to-end (in-process, no HTTP
  requestFailed). Verify a real reply. →plan: "🎯 PINPOINTED ActOsaurusError error 2" + "P0-A".
- [ ] **0.5 Confirm mini-chat + grab-chat reachable** (mini chat exists+reskinned per screenshot — verify wired/discoverable).
- [ ] 0.6 (CLAIMED-done — RE-CERTIFY each) duplicate-toggle deleted · friendly errors · clean titles · scroll-blur
  graft · side-panel graft · white-bar/search fix · model-default seed — re-verify file:line + runtime they hold.
- [ ] **0.7 message-bar graft** = reskin of Osaurus composer (owner-verify feel) →plan: "⚠️ MESSAGE-BAR graft".
- [ ] **0.8 OWNER-REPORTED RUNTIME DEFECTS (2026-06-22, screenshot-grounded)** — must screenshot-verify each fix:
  D1 window BOXY→CURVED+soft-shadow (RootView has the chrome; Osaurus ChatView host renders boxy);
  D2 old Epistemos LANDING missing (shows Osaurus default "Good morning"+download/provider/plugin buttons) →
  restore LandingView→blur→act; D3 the PILL is gone (ChatCapabilityPill LandingView.swift:1178 /
  NativePillButtonStyle ChatSidebarView.swift:76) → bring it back; D4 Configuration/Settings doesn't open/work →
  wire act config + per-clone settings; D5 reskin only partial (still Osaurus chrome, not owner cream/mono +
  model picker/palette/38-tool panel). →plan: "🔴 OWNER-REPORTED RUNTIME DEFECTS" in strict prompt + addendum.
  NOTE: D1–D5 are the RUNTIME ACCEPTANCE TESTS for 0.1–0.7 — do NOT mark 0.1–0.7 `[x]` until the matching
  D-item passes YOUR screenshot (e.g. 0.1 reskin isn't `[x]` until D5 screenshot shows cream/monospace).
- [ ] **0.11 Provider wiring + Epistemos Picks** — owner's GGUF/QAT models actually selectable AND used in act;
  "Add a provider" / Configuration opens REAL provider+model settings; NO silent Codex/Qwen swap. Verify a send
  uses the owner's selected model. →plan: "OWNER'S MODELS IN CHAT" + "DEEP CHECK §2" + D4.
- [ ] **0.12 Surface-wiring rule** — every Osaurus surface (settings, model stack, tools, transcript, config)
  mapped to a proven Epistemos front-end; NO dead surfaces. →plan: "SURFACE-WIRING RULE".
- [ ] **0.13 Shared act component** — ONE shared composer/capability component reused by main+mini+graph+note
  (no per-surface drift). →plan: "🆕 ALL CHAT SURFACES GET THE CHAT→ACT/OSAURUS UPGRADE" (impl intent).
- [ ] **0.14 Health-row witnesses honest** — ActOsaurusHealthRow / AnswerPacketHealthRow / etc.: wiredToday vs
  stillStub must MATCH real code state after every change; re-cert each row. →plan: substrate + act progress docs.
- [ ] **0.15 DEEP CHECK (prove reality, not claim)** — trace the LIVE act path end-to-end; prove no silent Codex
  default; write honest status in OSAURUS_BUILD_PROGRESS. →plan: "DEEP CHECK — PROVE THE REALITY".
- [ ] **0.16 Reasoning/thinking fidelity** (if not fully covered by 0.9) — `<think>` parsing, clean titles,
  streaming, no refusals across ALL models. →plan: P0 regression sections.

- [ ] **0.9 ACT FIDELITY non-negotiables** — act MUST: stream every token (no buffering); PRESERVE thinking
  blocks + signatures (don't strip reasoning); REAL tool-call parsing. The prior "reasoning-model output broken
  in LIVE chat" regression must NOT recur in act. Real-state test + screenshot a reasoning reply. →plan: "🔴🔴 P0
  REGRESSION — reasoning-model output broken in LIVE chat" + CHAT_BACKEND_QUARANTINE "Streaming/thinking/tool fidelity".
- [ ] **0.10 DATA CARRY-OVER** — existing saved chats/sessions + user prefs migrate to act (no lost history),
  not just models/IP. →plan: CHAT_BACKEND_QUARANTINE "Data/persistence carry-over".

## TIER 1 — WORK MODE (OpenCode)
- [ ] 1.1 OpenCode launcher binary vendored (build-opencode-runtime.sh; owner may drop at Resources/opencode-runtime/bin/opencode). →plan: "🆕 BUN RUNTIME = VENDORED/BUNDLED" + Architecture C.
- [ ] 1.2 WORK = OpenCode real TUI, palette-matched, in mini/graph chat (not note), search→work transition, dual landing + blur. →plan: "✅ RESOLVED OPENCODE UI" + "✅ WORK LOOK = real TUI".
- [ ] 1.3 Goose/Hermes/OpenClaw fuse beneath OpenCode (unique bits only; drop Goose-permissions if OpenCode covers). →plan: "✅ DECISION WORK ENGINE = ARCH C" + refinements.

## TIER 2 — SUBSTRATE + SALVAGE (certain, lower-but-not-dropped)
- [ ] 2.1 SUBSTRATE Phase 2 AnswerPacket load-on-launch (4e7a49199 CLAIMED — re-certify real-state) → continue Phase 2 (history surface, primary witness) + P5/P6. →plan: SUBSTRATE_BUILD_SEQUENCE.
- [ ] 2.2 Helios salvage (7 items): real eidos.query wiring, provenance ledger live, confidence_floor resurrect, AnswerPacket/wbo6 harden, L1 memory, InterruptScore, HW tier. →plan: "✅ HELIOS-ERA IP ... salvage list".
- [ ] 2.3 GUS salvage 1-18 (genuinely-absent only; GUS-6..13 mostly already-live — verify): GUS-7 Ed25519, GUS-8 undo runtime-wire, GUS-10 skill-promote-wire, GUS-1..5/14..18. →plan: GRAND SWEEP cycles 1-3.
- [ ] 2.5 EML honesty gate (GUS-2) — wire EML/Belnap as the AnswerPacket honesty/abstain gate. →plan: GRAND SWEEP GUS-2.
- [ ] 2.6 Eidos recall/rerank — real eidos.query wiring + rerank, NOT fake-green (pairs with 2.2 Helios + GUS-5). →plan: "✅ HELIOS-ERA IP" + GRAND SWEEP GUS-5.
- [ ] 2.4 UNIFICATION verdict: one orchestrator(System G)+TRINITY+one router+one brain attach+one inference chokepoint; fix eidos.query fake-green; delete confidence_floor/ConfidenceRouter dead; fix stale CLAUDE.md. →plan: "✅ UNIFICATION VERDICT".

## TIER 3 — ORCHESTRATOR / FUGU / TRINITY (foundational, sequenced here)
- [ ] 3.1 TRINITY native orchestrator: port method to Swift/Rust on System G/RuntimeRouter (heuristic-route first; learned router after license); bundle Sakana HF artifacts; expose as internal API across act/work/chat. →plan: "🌟🌟 TRINITY" + "✅ TRINITY BUILD PATH" + port spec. MLX hidden-state tap = prove-first. License = owner-action.
- [ ] 3.2 Fugu = optional premium guest provider (OpenAI-compat, EU-gated, real per-token cost in Settings, modular). NEVER the brain. →plan: "🌟 FUGU FOUNDATIONAL" + "✅ FUGU RESEARCH DONE".

## TIER 4 — OWNER-FACING / CLONES / PILLARS
- [ ] 4.1 Per-clone SETTINGS tabs (Epistemos|act|work|beyond) — actClone+workClone added; respect each clone's real settings. →plan: "🆕 PER-CLONE SETTINGS".
- [ ] 4.2 System-prompts library (asgeirtj, CC0): vendor + per-model prompt engineering (Epistemos Picks), adapt not blind-paste. →plan: "🆕 SYSTEM-PROMPTS LIBRARY".
- [ ] 4.3 VAULT-DEEP-INTEGRATION pillar (overtake Tolaria): act+work agents on vault + vault-as-MCP; graph; LLM-wiki + wikilinks; in-editor agent edits on Prose + MD-V2/Epdoc. →plan: "🌟 PILLAR — VAULT-DEEP-INTEGRATION".
- [ ] 4.4 EPDOC MD-V2 (md=source, html/json=projections; pixel-art native, more dynamic). →plan: "🆕 EPDOC MD-V2".
- [ ] 4.5 Tamagotchi agent-creation: keep style + fix render bug (too-small/inner-squares). →plan: "🆕 OSAURUS AGENT CREATION = KEEP TAMAGOTCHI".
- [ ] 4.6 MOTION LANGUAGE triad (blur + ASCII typewriter + micro-motions) on titles + display-only; mode-entry animations. →plan: "✅ MOTION LANGUAGE = TRIAD".
- [ ] 4.7 Preserve UI chrome: model picker (real logos/tiers/install/Epistemos Picks), command palette, 38-tool agent panel. →plan: "ACT reskin — PRESERVE the model picker...".
- [ ] 4.8 Talaria + Epdoc-fuse + other clones: same full-clone process, MAS-non-restrictive global. →plan: "🔒 SET IN STONE — MAS NON-RESTRICTIVE".
- [ ] 4.9 ACT wiring: skills + MCP + tool-tier bridges wired to act (the 38-tool panel must actually drive them); API keys in macOS Keychain, NEVER UserDefaults. →plan: CHAT_BACKEND_QUARANTINE "Skills / MCP / tool-tier + Keychain".

## TIER 5 — DISTRIBUTION + OPTIMIZATION (standing/late)
- [ ] 5.1 Dual-build: MAS (no VM, WASM/cloud sandbox substitute) + Pro (full); capability schema; CI both. →plan: "🔒 DUAL-BUILD DISTRIBUTION MODEL".
- [ ] 5.2 Deep-optimization cycles (actor/Task.detached/memory/Metal/120fps no-regress/etc.) — recurring standing track. →plan: "🆕 DEEP OPTIMIZATION CYCLES".

## STANDING (apply on EVERY item, every loop)
No fake-done · RUNTIME-VERIFY UI (build-green ≠ done) · no red on main · code-more-build-less (fast gate per
increment, heavy xcodebuild at checkpoints, never idle-block) · never delete chat IP (preserve+port, surface
deletable only after IP ported) · NO-ADDED-TERMS · NO-QUEUE-JUMPING (finish TIER 0 before lower tiers) ·
latest-owner-directive-wins · 70B/new-model EXCLUDED · OFF-LIMITS (Companion clones/companions.rs) · main-only ·
Co-Authored-By Claude · P0 owner runtime reports preempt everything.
