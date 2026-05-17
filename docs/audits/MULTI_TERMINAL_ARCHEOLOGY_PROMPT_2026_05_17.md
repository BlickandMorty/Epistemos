---
state: meta-prompt
created_on: 2026-05-17
purpose: A copy-pasteable prompt for a future Claude session — instructs it to archeologically walk every PRIOR multi-terminal round on the Epistemos repo + produce per-terminal punch lists (in the same shape as `docs/audits/UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md`) for each round. Closes the gap where prior multi-terminal rounds did NOT receive per-terminal punch-list docs at handoff.
author: T3 — UAS-ACS Canonical Architecture session, post-handoff iter
---

# Multi-Terminal Archeology Prompt — copy below the divider

> **How to use this doc**: copy everything between the `===` dividers into a fresh Claude session. The
> Claude in that session will walk prior multi-terminal cycles + produce one per-terminal punch list per
> cycle. Run it from a repo root that has `.git/` + `docs/` accessible.
>
> The prompt below references a reference doc that exists on the T3 branch:
> `docs/audits/UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md`. If that branch hasn't merged yet, the
> Claude session can read the doc directly from `codex/t3-uasacs-2026-05-16`.

## ===  COPY FROM HERE  ===

You are doing repo archeology on the Epistemos codebase.

**Mission**: The user previously ran ~2 prior rounds of multi-terminal (T1/T2/.../T6 or T8) parallel work
on this repo. Each round terminated WITHOUT a per-terminal punch-list doc. Your job: walk every prior
multi-terminal round + produce one per-terminal punch list per round, in the same shape as the reference
doc `docs/audits/UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md` (read it before starting — it's the
template).

**Why this matters**: After merge, the user needs to know per-terminal-branch what's still left to code.
Without a punch list per terminal per round, the deferral list lives only in scattered audit-of-audit docs
+ commit messages, and post-merge the user has no single pickup point per terminal.

## Method

1. **Detect cycle boundaries**.
   - Run `git log --oneline --all | grep -E "codex/(t[0-9]|run-[a-z])" | head -200` to surface terminal-named
     branches.
   - Run `git branch -a | grep codex/` to list all terminal branches that ever existed.
   - Cluster branches by date — branches created in the same ~week likely belong to one round.
   - Sanity-check by reading prior handoff docs: `find docs -name '*HANDOFF*' -o -name '*CLOSE*' -o
     -name '*FINAL*' | sort` for clues about which round terminated when.
   - Also look at `docs/audits/` for terminal-specific audits and `docs/fusion/` for cross-terminal
     synthesis artifacts. The latest cycle's handoff is the T3 UAS-ACS handoff
     (`UAS_ACS_FINAL_HANDOFF_2026_05_17.md`) — earlier cycles are what you're looking for.

2. **For each prior cycle, identify the terminals** that participated.
   - Each terminal has a branch like `codex/<terminal-key>-<topic>-<date>`.
   - Each terminal usually has a worktree at `/Users/jojo/Downloads/Epistemos-<terminal-key>-<topic>` (the
     user keeps them around for resumption).
   - Each terminal usually has its own audit docs at `docs/audits/<terminal-or-topic>_*.md`.
   - Look at the `git log` per branch to see which paths each terminal owned vs touched.

3. **For each terminal in each cycle, identify what was DEFERRED**.
   - Search the terminal's commit messages for phrases like "NOT YET", "deferred", "blocked on", "STALLED",
     "Phase C", "production-PASS", "Metal kernel", "live model", "T1 ", "T4 ", etc.
   - Search the terminal's audit-of-audit docs for sections like "Outstanding deferrals", "Open questions",
     "Items deferred", "Cross-terminal handshakes".
   - Search the terminal's falsifier docs (`docs/falsifiers/`) for sections like "Dependencies" or "Iter
     target".
   - Each deferred item should resolve to: (1) what's missing, (2) where the work lives, (3) what depends
     on it downstream, (4) what acceptance looks like.

4. **CRITICAL — handle feature interconnection**. Features in this repo touch each other in practice.
   Examples:
   - "ACS work" (Anchored Cognitive Substrate, T3-owned for the canon layer) interconnects with **vault
     work** (T4 retrieval consumes the anchor scheme), **UI** (T6 surfaces ACS Anchor's residency tier in
     chat), **agent_runtime** (T2 emits AcsAnchor as part of every trace).
   - "Vault work" interconnects with **ACS** (vault anchors flow through ACS), **UI** (Halo/Shadow panel
     renders results), **Shadow paging** (T3-owned sketch → residual → exact escalation).
   - "Cognitive DAG" interconnects with **ACS** (nodes carry AcsAnchors), **provenance** (DerivesFrom +
     Resonance walks share schema with ClaimLedger), **UI** (graph visualization).
   - When you list a terminal's deferred items, **cross-link the OTHER terminals that depend on each
     item**. A deferred item that unblocks multiple terminals is more important than one that unblocks
     one.

5. **Output one doc per round** at `docs/audits/POST_<CYCLE-IDENTIFIER>_PER_TERMINAL_PUNCH_LIST_<DATE>.md`
   where `<CYCLE-IDENTIFIER>` is something like `RUN_B_C_D_2026_05_06` or `WAVE_1_2026_04_15` (use the
   actual dates + terminal-key letters from the cycle you reconstruct).

   Each doc follows the reference shape:
   - **§1 How to read this doc** (1 paragraph)
   - **§2..§N One section per terminal** (T1, T2, T3, T4, T5, T6, T7, T8) — each section has a table:
     `| Item | Where | Why | Acceptance |`
   - **§N+1 Swift/Metal lane** (the cross-cutting Apple-platform work)
   - **§N+2 Phase C cross-cutting** (live-model + 70B-Cocktail style items that touch multiple terminals)
   - **§N+3 Optional substrate** (no gate dependency)
   - **§N+4 Pre-merge sanity check** (cargo baseline expected, integration test list, lib.rs merge-conflict
     surface)
   - **§N+5 Cross-references** (link to the audit-of-audit docs + handoff doc for that round)

6. **Cross-cutting interconnection table**: at the bottom of each per-cycle punch list, add a section
   "Cross-terminal interconnection map" — a table like:

   | Feature area | Primary terminal | Touches |
   |---|---|---|
   | ACS Anchor | T3 | T1 (UasKind variants) · T2 (agent_runtime emission) · T4 (vault) · T6 (UI badge) |
   | Vault retrieval | T4 | T3 (Shadow paging) · T6 (Halo panel) · T7 (EML integration if EML annotates vault) |
   | Cognitive DAG | (varies — check prior round) | T3 (ACS Anchor on nodes) · T2 (DAG ↔ agent_runtime) · T6 (visualization) |
   | (etc.) | | |

   Build this table from your archeology — DON'T copy it from any template; each cycle had a different set
   of features.

7. **Validation pass**: after writing each punch list, walk it once with a §5.0-style reconciliation gate.
   For every claim:
   - The cited path must exist on the cycle's branch (or be a stated gap that should be created).
   - The cited terminal-owner must be consistent with that round's scope locks.
   - The acceptance criteria must be measurable (no "looks good" — must be "≤ X / ≥ Y / matches Z").

   If any claim fails reconciliation, fix it in place. Note any unresolvable ambiguity in a §"Open
   Questions" section at the bottom of each punch list.

## Method — branch + worktree discovery commands

```bash
# Find all terminal branches that ever existed:
git for-each-ref --format='%(refname:short) %(committerdate:iso8601) %(subject)' refs/heads refs/remotes | grep -E "codex/(t[0-9]|run-)" | sort -k 2

# Find all terminal worktrees:
ls -d /Users/jojo/Downloads/Epistemos-* 2>/dev/null

# Show commits per terminal branch with dates:
for branch in $(git branch -a | grep -E "codex/(t[0-9]|run-)" | tr -d ' *'); do
  echo "=== $branch ==="
  git log --oneline --format='%h %ad %s' --date=short "$branch" main..."$branch" 2>/dev/null | head -10
done

# Find handoff / closeout / final docs:
find docs -name '*HANDOFF*.md' -o -name '*CLOSE*.md' -o -name '*FINAL*.md' -o -name '*AUDIT_OF_AUDIT*.md' | sort -u

# Find all per-terminal audit docs:
find docs/audits -name '*.md' | xargs grep -l 'terminal.*T[0-9]\|run-[a-z]' 2>/dev/null | sort

# For a specific terminal (e.g. T3 prior round):
git log --oneline --all --format='%h %ad %s' --date=short --author-or-committer | grep -E "T3|run-c"
```

## Method — search keywords for deferrals

- `"NOT YET"`, `"not yet"`, `"deferred"`, `"TBD"`, `"STALLED"`, `"BLOCKER"`
- `"Phase C"`, `"production-PASS"`, `"production wire"`
- `"Metal kernel"`, `"Swift driver"`, `"IOSurface"`, `"MLX"`
- `"live model"`, `"Qwen"`, `"Mamba"`, `"32k context"`, `"128k context"`
- `"T1 "`, `"T2 "`, ..., `"T8 "` (with the trailing space — narrows to terminal references)
- `"depends on"`, `"blocked on"`, `"handshake"`, `"coordinate with"`
- `"oxieml"`, `"Scan-IR"`, `"UasKind"`, `"vault.rs"`
- `"DOES NOT EXIST"`, `"gap"`, `"missing"`, `"orphan"`

## Method — feature interconnection heuristic

When you list a deferred item for terminal X, ask:

1. Does this item produce a TYPE that another terminal Y consumes? (e.g. UasKind variant)
2. Does this item produce a FUNCTION SURFACE that another terminal Y calls? (e.g. EscalationPolicy)
3. Does this item produce a WIRE FORMAT that another terminal Y unpacks on the other side of FFI? (e.g.
   58-byte KV metadata wire format)
4. Does this item enable a USER-FACING SURFACE in terminal Y? (e.g. UI badge depends on substrate emission)

If yes to any: cross-link Y in the "Why" column of X's table row. This is what "interconnection" means in
practice.

## Deliverable

One markdown doc per prior multi-terminal cycle, at the path schema above, committed to the current
working branch with a HEREDOC commit message. The commit message must include:

- Which cycle the punch list is for (dates + terminal keys involved)
- How many deferrals per terminal (count summary)
- Whether validation pass (§7) found any unresolvable items
- Cross-reference to the original audit-of-audit/handoff docs from that cycle (so the punch list is
  read alongside the source material)

After landing each punch list, push to the current branch.

## Stopping condition

You stop when:
- Every prior multi-terminal cycle has a per-terminal punch list at `docs/audits/POST_<CYCLE>_PER_TERMINAL_PUNCH_LIST_<DATE>.md`
- Each punch list passes the §7 validation gate
- The "Cross-terminal interconnection map" at the bottom of each punch list shows the cross-terminal
  dependencies discovered for that cycle

If you find NO prior multi-terminal cycles (only the most recent T3 round exists), report that finding
in a short doc at `docs/audits/MULTI_TERMINAL_ARCHEOLOGY_FINDINGS_<DATE>.md` and stop.

## Reference

Read these BEFORE starting (in order):

1. `docs/audits/UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md` — the **template** for the punch list shape.
2. `docs/audits/UAS_ACS_FINAL_HANDOFF_2026_05_17.md` — the current cycle's handoff (Section §5 is the
   gate-organized deferrals; this archeology produces the terminal-organized counterpart for past cycles).
3. `docs/audits/UAS_ACS_T_TERMINAL_COORDINATION_2026_05_17.md` — the handshake-matrix doc; if any past
   cycle had similar coordination patterns, that doc's shape transfers.
4. `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` — terminal-keyed §4.A through §4.I missions; if a
   past cycle had its own driver prompt, find it and read its analog.

## Anti-rules

- **Do NOT** invent deferrals. Every item must trace to a specific commit, doc, or codebase grep.
- **Do NOT** copy-paste rows from the T3 punch list as filler. Each cycle had its own scope; the T3
  punch list is the FORMAT template, not a content template.
- **Do NOT** modify the T3-cycle docs. The current punch list + handoff + audit chain are the latest
  cycle's record; your work is archeology of EARLIER cycles.
- **Do NOT** schedule any wakeups (no /loop). This is a one-shot archeology pass.

## ===  COPY UNTIL HERE  ===

---

# Provenance + intent (read only if curious)

This prompt was authored at the end of T3's UAS-ACS session on 2026-05-17 because the user observed:

> "i did a previous round of like 6 terminals i think twice and i did not do this for them iether. so
> pleae write a prompt that tells lcuade to look back in tim in the preiovus cycles of multi terminal work
> and teh lare scale work we have been doing. bascially if i was to say acs, work that should be refernced
> is like work that incldues vault work i ux work etc. like interconnceted becasue all feautres liekly
> touch each otehr in practice idk let me know."

The user's point about interconnection is correct: ACS work in this codebase touches **vault** (anchors flow
through retrieval), **UI** (residency-tier badge), **agent_runtime** (trace emission), **provenance**
(ClaimLedger snapshot composition). A naive per-terminal punch list would miss these cross-links. The
prompt above forces the future Claude session to surface them explicitly via §6 of each output doc.

The expected output is ~2 punch-list docs (one per prior round); each ~150-250 lines based on the T3
template. Total artifact: ~300-500 lines.

If only one prior cycle is discoverable, output one doc. If none are discoverable (i.e. T3 is the only
cycle), output the findings doc per the stopping condition above.
