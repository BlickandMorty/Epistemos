# WORK QUEUE (2026-06-22) — the loop's per-iteration source of truth

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
  If you cannot runtime-verify a UI item headlessly, mark it [~] "built, NEEDS owner/computer-use runtime-verify"
  — never [x]. Do NOT move past a broken/unverified TIER-0 item to lower tiers.
- Update this queue each loop (status + a one-line result). Commit + push. No fake-done. No red on main.
- Never delete chat IP. main-only. Co-Authored-By Claude.

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
- [~] 0.6 (done, keep verified) duplicate-toggle deleted · friendly errors · clean titles · scroll-blur graft ·
  side-panel graft · white-bar/search fix · model-default seed — RUNTIME-VERIFY they hold after 0.1-0.4.
- [ ] **0.7 message-bar graft** = reskin of Osaurus composer (owner-verify feel) →plan: "⚠️ MESSAGE-BAR graft".

## TIER 1 — WORK MODE (OpenCode)
- [ ] 1.1 OpenCode launcher binary vendored (build-opencode-runtime.sh; owner may drop at Resources/opencode-runtime/bin/opencode). →plan: "🆕 BUN RUNTIME = VENDORED/BUNDLED" + Architecture C.
- [ ] 1.2 WORK = OpenCode real TUI, palette-matched, in mini/graph chat (not note), search→work transition, dual landing + blur. →plan: "✅ RESOLVED OPENCODE UI" + "✅ WORK LOOK = real TUI".
- [ ] 1.3 Goose/Hermes/OpenClaw fuse beneath OpenCode (unique bits only; drop Goose-permissions if OpenCode covers). →plan: "✅ DECISION WORK ENGINE = ARCH C" + refinements.

## TIER 2 — SUBSTRATE + SALVAGE (certain, lower-but-not-dropped)
- [~] 2.1 SUBSTRATE Phase 2 AnswerPacket load-on-launch (4e7a49199 done) → continue Phase 2 (history surface, primary witness) + P5/P6. →plan: SUBSTRATE_BUILD_SEQUENCE.
- [ ] 2.2 Helios salvage (7 items): real eidos.query wiring, provenance ledger live, confidence_floor resurrect, AnswerPacket/wbo6 harden, L1 memory, InterruptScore, HW tier. →plan: "✅ HELIOS-ERA IP ... salvage list".
- [ ] 2.3 GUS salvage 1-18 (genuinely-absent only; GUS-6..13 mostly already-live — verify): GUS-7 Ed25519, GUS-8 undo runtime-wire, GUS-10 skill-promote-wire, GUS-1..5/14..18. →plan: GRAND SWEEP cycles 1-3.
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

## TIER 5 — DISTRIBUTION + OPTIMIZATION (standing/late)
- [ ] 5.1 Dual-build: MAS (no VM, WASM/cloud sandbox substitute) + Pro (full); capability schema; CI both. →plan: "🔒 DUAL-BUILD DISTRIBUTION MODEL".
- [ ] 5.2 Deep-optimization cycles (actor/Task.detached/memory/Metal/120fps no-regress/etc.) — recurring standing track. →plan: "🆕 DEEP OPTIMIZATION CYCLES".

## STANDING (apply on EVERY item, every loop)
No fake-done · RUNTIME-VERIFY UI (build-green ≠ done) · no red on main · code-more-build-less (fast gate per
increment, heavy xcodebuild at checkpoints, never idle-block) · never delete chat IP (preserve+port, surface
deletable only after IP ported) · NO-ADDED-TERMS · NO-QUEUE-JUMPING (finish TIER 0 before lower tiers) ·
latest-owner-directive-wins · 70B/new-model EXCLUDED · OFF-LIMITS (Companion clones/companions.rs) · main-only ·
Co-Authored-By Claude · P0 owner runtime reports preempt everything.
