# RESUME DEFERRED WORK — handoff prompt for a fresh session

**Purpose:** the master loop often defers nuanced work to "fresh context" (it re-arms
its heartbeat instead of rushing a risky change at the tail of a long session). This
doc is the single thing to hand a NEW session so ALL of that deferred work actually
gets done. Nothing is lost: every deferral is an open checkbox + a "HONEST REMAINING /
follow-on slice" note in the authority ledger, committed and pushed.

---

## What to paste into a new session (one line)

> Read `docs/RESUME_DEFERRED_WORK_2026_06_19.md` and resume all deferred work to completion.

That's it. The rest of this file tells that session exactly what to do.

---

## Instructions for the resuming session

1. **Authority docs, read first (in order):**
   - `docs/EPISTEMOS_MASTER_LOOP_PROMPT_2026_06_17.md` — how to operate (constraints,
     cadence, auto-commit+push, build-verify discipline).
   - `docs/OWNER_REQUESTS_LEDGER_2026_06_18.md` — THE single source of truth for what
     the owner wants. Every task lives here.
   - The research maps under `docs/research/` (Hermes/Osaurus/OpenClaw) for the agent/
     engine work.

2. **Build the deferred work-list from the ledger.** Enumerate, in this priority order:
   - Every **`- [ ]`** (open) and **`- [~]`** (in-progress) item.
   - Inside ALREADY-TICKED items, every inline **"HONEST REMAINING"**, **"follow-on
     slice"**, **"next iteration"**, **"SEPARATE follow-on"**, or **"(A)/(B) follow-on
     audit"** note — these are the nuanced bits the loop deliberately deferred. They
     carry the precise entry points / suspect files the loop already documented; use
     them — do not re-discover from scratch.
   - To find them fast:
     ```
     grep -nE '^- \[( |~)\]' docs/OWNER_REQUESTS_LEDGER_2026_06_18.md
     grep -niE 'HONEST REMAINING|follow-on|next iteration|separate (follow-on|slice)' docs/OWNER_REQUESTS_LEDGER_2026_06_18.md
     ```

3. **Work it down, highest-priority first.** Current HIGH-PRIORITY clusters (2026-06-19):
   - **Model system** (the owner's testing unblocker): MODEL DOWNLOAD/INSTALL
     (pipeline-robustness reqs 8/9/10 mostly landed; verify named models LFM2/
     VibeThinker/Gemma visible — acceptance req 11), MODEL SELECTION (Qwen-3-4B pinning
     — fix landed `020db2a17`, verify), Settings "stack" advertise-toggles + persistence
     (reqs 6/7).
   - **TOOLS/SKILLS BROKEN** deep repair: fix 1/1b landed; remaining parts (2) auto-route,
     (3) restore tool UI boxes, (4) vault retrieval, (5) per-tool/skill PASS/FAIL audit.
   - **Agent/engine architecture**: Act=Osaurus foundation + LocalAgent brain + Hermes
     fusion (R-HERMES), OpenClaw lane (WebKit-host), engine-isolation doctrine, MiniChat
     ontology + session-as-native-tab.

4. **Constraints (NON-NEGOTIABLE — from the master prompt + ledger):**
   - Everything must actually WORK in-app, not just compile. Local-first, honest, no
     fake, no silent cloud/Qwen fallback. **Never delete owner-wanted features** (Pro/
     dev-gate or hide instead). App-native by embedding. Pixel-art minimal.
   - **Nothing breaks:** Chat untouched, Work flag-isolated, Act additive + gated.
   - Build-verify every claim (`cargo test --lib` is the primary gate; the owner runs
     the in-app "build+run verify" step — note it, don't block on it).
   - Auto-commit + push every slice (path-scoped). Keep the ledger ticks honest:
     mark `[x]` only when truly done; otherwise leave a "HONEST REMAINING" note.

5. **Don't drop deferrals.** When you defer something to a later pass, you MUST leave
   it as an open `[ ]`/`[~]` item or an explicit "HONEST REMAINING" note in the ledger
   before ending the turn — so the next session can pick it up from this same doc. The
   ledger is the memory; an un-recorded deferral is a lost deferral.

6. **Optional — run as a loop:** to make it autonomous, start it the same way as the
   master loop (`/loop` in a detached screen session with the master prompt). See the
   project memory note "Epistemos master loop" for the exact screen/relaunch runbook.

---

## Snapshot at handoff (2026-06-19)

- Open items: ~97 `[ ]`, ~26 `[~]`, ~24 inline deferral notes.
- Latest model-system commits (pushed): `47fff0bc6` (install visibility), `9bbc2a3a2`
  (progress bar), `9502d2441` (resume downloads), `020db2a17` (selection honored).
- The loop deferred TOOLS/SKILLS part 2 to fresh context (entry points documented in
  the TOOLS/SKILLS item).
