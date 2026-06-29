# CANON CONSISTENCY LEDGER (the "check doc") — 2026-06-29

> **THE single doc to open to confirm the canon is still consistent during implementation.** The Auditor agent
> (`docs/prompts/PROMPT_AUDITOR_LOOP.md`, cron) re-runs every check below each cycle, updates the STATUS column,
> reconciles confident drift (adds a SUPERSEDED banner / inline `[DELETED]` marker — NEVER deletes a doc, NEVER
> touches code or another agent's uncommitted work), and flags anything ambiguous under "OWNER REVIEW." Owner: scan
> the STATUS column — all ✅ = canon coherent; any ⚠️ = drift the Auditor caught (read its note).

**Last auditor pass:** 2026-06-29 16:26 CDT (loop cycle 3) — **10/10 ✅**, 0 new drift, 0 new OWNER REVIEW. No canon/prompt docs changed since cycle 2; build agents now editing CODE (Plan-1 AgentSurface, Plan-2 MarkEdit, Plan-3 Arxiv WIP) — auditor observes, never touches code. Honest #6/#8 greps confirm doctrine+prompts. HEAD at pass: `3e6384c1b`.
<br>_(cycle 2, 16:17: made #6/#8 greps case/phrasing-honest — doctrine match was always real, old grep too narrow.)_

## INVARIANTS (the locked truths — each agent's docs must agree with these)
Run each `Check` from repo root; the Pass condition is what a consistent canon returns.

| # | Invariant (locked) | Check (grep) | Pass | STATUS 2026-06-29 |
|---|---|---|---|---|
| 1 | **NO native chat** (Option 1) — chat stays WebView, reskinned; native = frame + Models picker only | `grep -rniE "useNativeChatPath *= *true\|build native (chat\|transcript)\|chat-primary flip" docs/ \| grep -viE "DELETED\|SUPERSEDED\|HISTORICAL\|NOT\|no native\|do not\|ignore\|audit\|flag\|reskinned"` | empty (all residuals now HISTORICAL-marked or are correct "NO …" negations) | ✅ (FOLLOWON Step-9 struck; MASTER:129 HISTORICAL-marked; MASTER:4 = correct banner negation, excluded) |
| 2 | **§7 GREEN-LIT** — no live sign-off gate; Plan 1 on Phase 1 | `grep -rniE "DO NOT start.*Agent.*until.*§7\|Phase 0 (is )?NOT signed\|wait for.*§7 sign-off" docs/ \| grep -viE "SUPERSEDED\|HISTORICAL\|green-lit\|does not wait\|do not wait\|do NOT treat\|stale\|audit"` | empty (5 Phase-0 docs bannered; stale lines HISTORICAL-marked) | ✅ (CONTINUATION:25 HISTORICAL-marked; EDITOR_CANONICAL:290 = correct "does not wait" negation, excluded) |
| 3 | **Models picker = the ONE native route** (carve-out present) | `grep -rniE "no native picker\|pickers = WEB" docs/ \| grep -viE "EXCEPT\|carve\|Models picker IS\|one native route\|audit"` | empty | ✅ |
| 4 | **Spring values = the 4 canonical** (identical everywhere) | `grep -rohE "\.smooth \{[0-9.,]+\}" docs/ \| sort -u` | exactly `.smooth {0.5,0}` | ✅ (1 unique set) |
| 5 | **Two token sources only** — `EpistemosTheme.swift` (Swift) + Goose `theme-tokens.ts` (web); no third | grep the doctrine "Two token SOURCES" rule is intact + no rival source named | rule present | ✅ |
| 6 | **Graph = DO NOT TOUCH** (already full AppKit/Metal) | `grep -liE "graph.{0,60}do not touch" docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md docs/prompts/PROMPT_PLAN_1_GOOSE.md docs/prompts/PROMPT_PLAN_2_EDITOR.md docs/prompts/PROMPT_PLAN_3_CAPABILITIES.md` | all 4 files (doctrine + 3 prompts) listed | ✅ (cycle 2: doctrine carries it at lines 22 + 95; switched to case-insensitive grep — the old case-sensitive `GRAPH`/`graph` pattern false-negatived the doctrine's "Graph =", though the rule was present all along) |
| 7 | **Lens model** Note(Epdoc)/Source(MarkEdit)/Prose(TK2); **old code editor KEPT as v1 legacy** (no deletion); MD-nav = Note default→Prose→Source-button→full-MarkEdit | `grep -rniE "delete the 3 old\|old code-editor files were deleted" docs/research/EDITOR_CANONICAL*.md docs/research/MARKEDIT_EMBED*.md \| grep -viE "SUPERSEDES\|PRESERVED\|KEEP\|legacy"` | empty (the only hit is the line ENFORCING "v1 PRESERVED", excluded) | ✅ |
| 8 | **Retheme-not-replace** (Goose's existing shadcn/Radix/Tailwind/framer-motion) | `grep -liE -e 'retheme' -e "don'?t replace" -e 'do not replace' docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md docs/research/GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md docs/prompts/PROMPT_PLAN_1_GOOSE.md` | all 3 files (doctrine + reskin + Plan-1) listed | ✅ (cycle 2: doctrine carries it at line 82 "retheme … + tune" + line 85 "blend, don't replace"; replaced the prose check with a concrete grep that surfaces all 3) |
| 9 | **Only paste = `PROMPT_PLAN_1/2/3`**; every other "prompt"-named doc is bannered/not-the-paste | `for f in docs/handoffs/*PROMPT*.md; do grep -qiE "SUPERSEDED\|DO NOT PASTE\|HISTORICAL" "$f" \|\| echo "UNBANNERED: $f"; done` → empty | empty (every handoff *PROMPT* doc carries a banner) | ✅ ledger-scope green (CLONE_INFUSION + PRACTICAL_FULL_PORT_06-24 bannered). Broadened corpus-wide paste-prompt scan → ~50 archival/different-purpose hits parked in OWNER REVIEW (not a fleet-launch risk) |
| 10 | **Accent #0066cc · SF Pro · radius 11** consistent | `grep -rohE "#0066cc" docs/ \| wc -l` (>0, no rival accent) | consistent | ✅ |

## Stale docs that are BANNERED (mitigated, kept for nuance — do NOT delete)
GOOSE_AGENT_APPKIT_FOLLOWON_PLAN · GOOSE_MASTER_BUILD_PROMPT · GOOSE_PHASE_0_STATUS_AUDIT · GOOSE_PHASE_0_VERIFICATION ·
GOOSE_PHASE_0_OWNER_SIGNOFF_CHECKLIST · GOOSE_PHASE_0_CONTINUATION_PROMPT · GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND1/2 ·
GOOSE_APPKIT_SURFACE_MAPPING · CLAUDE_IMPLEMENTATION_PROMPT_FULL_CLONE_INFUSION_2026_06_24 (stale 06-24 full-clone/Osaurus
paste-prompt; bannered 2026-06-29) — each has a top SUPERSEDED-2026-06-29 banner; their bodies are HISTORICAL.

## OWNER REVIEW (Auditor parks ambiguous drift here — owner decides; empty = nothing pending)
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
