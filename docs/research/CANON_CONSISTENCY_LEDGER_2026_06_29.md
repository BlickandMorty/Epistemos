# CANON CONSISTENCY LEDGER (the "check doc") — 2026-06-29

> **THE single doc to open to confirm the canon is still consistent during implementation.** The Auditor agent
> (`docs/prompts/PROMPT_AUDITOR_LOOP.md`, cron) re-runs every check below each cycle, updates the STATUS column,
> reconciles confident drift (adds a SUPERSEDED banner / inline `[DELETED]` marker — NEVER deletes a doc, NEVER
> touches code or another agent's uncommitted work), and flags anything ambiguous under "OWNER REVIEW." Owner: scan
> the STATUS column — all ✅ = canon coherent; any ⚠️ = drift the Auditor caught (read its note).

**Last auditor pass:** 2026-06-29 18:25 CDT (loop cycle 16) — **10/10 ✅**, 0 locked-canon drift, 0 new OWNER REVIEW (1 still open from cycle 12). Steady-state: no new plans (still 1–7). Plan-1 marked "round two fixes complete" in `GOOSE_PHASE_0_VERIFICATION` (`4cad15ac9`) — verified: SUPERSEDED banner intact, no native-chat/canon terms added. Plan-3 docs (ARXIV/CAPABILITIES/EDGEPARSE) refined, drift-scanned clean. HEAD at pass: `573111b72`.
<br>_Recent: cycle 13 (17:59) tracked Plans 6/7 + Plan-4 §11 animation, widened #9 to [4-9]. cycle 12 (17:51) parked Companion-v1.6 vs Plan-5 doctrine tension. cycle 8 (17:06) STRENGTHENED check #4 to all 4 springs._
<br>_Recent: cycle 4 (16:37) verified Plan-1's Phase-1/Option-1 section = canon-reinforcing. cycle 2 (16:17) made #6/#8 greps case/phrasing-honest._
<br>_Recent: cycle 4 (16:37) verified Plan-1's Phase-1/Option-1 section appended to GOOSE_PHASE_0_VERIFICATION = canon-reinforcing, no drift. cycle 2 (16:17) made #6/#8 greps case/phrasing-honest (doctrine match was always real)._

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
| 10 | **Accent #0066cc · SF Pro · radius 11** consistent | `grep -rohE "#0066cc" docs/ \| wc -l` (>0, no rival accent) | consistent | ✅ |

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
