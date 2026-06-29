# CANON CONSISTENCY LEDGER (the "check doc") — 2026-06-29

> **THE single doc to open to confirm the canon is still consistent during implementation.** The Auditor agent
> (`docs/prompts/PROMPT_AUDITOR_LOOP.md`, cron) re-runs every check below each cycle, updates the STATUS column,
> reconciles confident drift (adds a SUPERSEDED banner / inline `[DELETED]` marker — NEVER deletes a doc, NEVER
> touches code or another agent's uncommitted work), and flags anything ambiguous under "OWNER REVIEW." Owner: scan
> the STATUS column — all ✅ = canon coherent; any ⚠️ = drift the Auditor caught (read its note).

## INVARIANTS (the locked truths — each agent's docs must agree with these)
Run each `Check` from repo root; the Pass condition is what a consistent canon returns.

| # | Invariant (locked) | Check (grep) | Pass | STATUS 2026-06-29 |
|---|---|---|---|---|
| 1 | **NO native chat** (Option 1) — chat stays WebView, reskinned; native = frame + Models picker only | `grep -rniE "useNativeChatPath *= *true\|build native (chat\|transcript)\|chat-primary flip" docs/ \| grep -viE "DELETED\|SUPERSEDED\|HISTORICAL\|NOT\|no native\|do not\|ignore\|audit\|flag"` | only lines inside SUPERSEDED-bannered docs | ✅ (all residual lines bannered + FOLLOWON Step-9 struck) |
| 2 | **§7 GREEN-LIT** — no live sign-off gate; Plan 1 on Phase 1 | `grep -rniE "DO NOT start.*Agent.*until.*§7\|Phase 0 (is )?NOT signed\|wait for.*§7 sign-off" docs/ \| grep -viE "SUPERSEDED\|HISTORICAL\|green-lit\|do not wait\|do NOT treat\|stale\|audit"` | only lines inside bannered docs | ✅ (5 Phase-0 docs bannered) |
| 3 | **Models picker = the ONE native route** (carve-out present) | `grep -rniE "no native picker\|pickers = WEB" docs/ \| grep -viE "EXCEPT\|carve\|Models picker IS\|one native route\|audit"` | empty | ✅ |
| 4 | **Spring values = the 4 canonical** (identical everywhere) | `grep -rohE "\.smooth \{[0-9.,]+\}" docs/ \| sort -u` | exactly `.smooth {0.5,0}` | ✅ (1 unique set) |
| 5 | **Two token sources only** — `EpistemosTheme.swift` (Swift) + Goose `theme-tokens.ts` (web); no third | grep the doctrine "Two token SOURCES" rule is intact + no rival source named | rule present | ✅ |
| 6 | **Graph = DO NOT TOUCH** (already full AppKit/Metal) | `grep -rc "GRAPH = .*DO NOT TOUCH\|graph.*DO NOT TOUCH" docs/` | present in doctrine + 3 prompts | ✅ |
| 7 | **Lens model** Note(Epdoc)/Source(MarkEdit)/Prose(TK2); **old code editor KEPT as v1 legacy** (no deletion); MD-nav = Note default→Prose→Source-button→full-MarkEdit | `grep -rniE "delete the 3 old\|old code-editor files were deleted" docs/research/EDITOR_CANONICAL*.md docs/research/MARKEDIT_EMBED*.md` | empty (only "KEEP/v1 legacy") | ✅ |
| 8 | **Retheme-not-replace** (Goose's existing shadcn/Radix/Tailwind/framer-motion) | doctrine + reskin + Plan-1 prompt say "retheme … do NOT replace" | present | ✅ |
| 9 | **Only paste = `PROMPT_PLAN_1/2/3`**; every other "prompt"-named doc is bannered/not-the-paste | `grep -rl "prompt" docs/handoffs/*PROMPT*.md` → each must have a banner or "DO NOT PASTE" | bannered | ✅ |
| 10 | **Accent #0066cc · SF Pro · radius 11** consistent | `grep -rohE "#0066cc" docs/ \| wc -l` (>0, no rival accent) | consistent | ✅ |

## Stale docs that are BANNERED (mitigated, kept for nuance — do NOT delete)
GOOSE_AGENT_APPKIT_FOLLOWON_PLAN · GOOSE_MASTER_BUILD_PROMPT · GOOSE_PHASE_0_STATUS_AUDIT · GOOSE_PHASE_0_VERIFICATION ·
GOOSE_PHASE_0_OWNER_SIGNOFF_CHECKLIST · GOOSE_PHASE_0_CONTINUATION_PROMPT · GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND1/2 ·
GOOSE_APPKIT_SURFACE_MAPPING — each has a top SUPERSEDED-2026-06-29 banner; their bodies are HISTORICAL.

## OWNER REVIEW (Auditor parks ambiguous drift here — owner decides; empty = nothing pending)
- _(none as of 2026-06-29)_

## How to use
- **Owner:** open this file; scan STATUS. Any ⚠️ → read the Auditor's note + the OWNER REVIEW section.
- **Auditor:** each cycle, re-run all 10 checks; update STATUS; for a FAIL you're CONFIDENT about → add a banner /
  `[DELETED]` marker at the SOURCE (never delete the doc); for an AMBIGUOUS FAIL → add a row to OWNER REVIEW; commit.
- **Build agents:** when a doc you read disagrees with an invariant here, the LEDGER + the canon (GOOSE_NATIVE_UI_DECISION
  + EPISTEMOS_NATIVENESS_DOCTRINE) WIN; treat the disagreeing text as stale and flag it.
