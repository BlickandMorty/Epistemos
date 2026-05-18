---
state: universal-terminal-prompt
created_on: 2026-05-18
purpose: ONE pasteable prompt the user drops into every terminal. Each agent auto-detects which terminal it is from `pwd` and routes to its own T-prompt.
---

# Universal Terminal Prompt — 2026-05-18

Paste the block below into EVERY terminal (all 8 Cohort A terminals, mixed Claude and Codex). Each agent reads its own working directory, looks itself up in the routing table, and begins its assigned T-prompt's forever loop.

The user does not need to vary the prompt per terminal. Variation is the agent's job, not the user's.

---

```text
You are working inside a git worktree of /Users/jojo/Downloads/Epistemos. Before
you do anything else, identify which terminal you are. Then read the canon. Then
begin the forever loop for your assigned T-prompt. Never exit.

================================================================================
STEP 1 — Identify yourself (mandatory, do this first)
================================================================================

Run `pwd`. Match the result against the routing table below. The suffix of your
working directory uniquely identifies which T-prompt you own.

Routing table (worktree path suffix → T-ID → tool → branch):

  Epistemos-t09-product-ledger              → T09  → Claude → codex/t09-product-ledger-2026-05-18
  Epistemos-t10-eidos                       → T10  → Claude → codex/t10-eidos-v0-2026-05-18
  Epistemos-t11-agent-runtime-v2            → T11  → Claude → codex/t11-agent-runtime-v2-2026-05-18
  Epistemos-t12-f-ulp                       → T12  → Codex  → codex/t12-f-ulp-oracle-2026-05-18
  Epistemos-t17b-lattice-wbo-register       → T17B → Codex  → codex/t17b-lattice-wbo-register-2026-05-18
  Epistemos-t18b-acs-admission-field        → T18B → Codex  → codex/t18b-acs-admission-field-2026-05-18
  Epistemos-t21-vault                       → T21  → Claude → codex/t21-vault-recall-contract-2026-05-18
  Epistemos-t23b-m2pro-falsifier-handbook   → T23B → Codex  → codex/t23b-m2pro-falsifier-handbook-2026-05-18

If `pwd` does not match any row above, STOP. Tell Jojo: "I'm in <path> and I'm
not in any of the 8 Cohort A worktrees — please move me or reassign me." Do not
guess. Do not pick a T-prompt because it sounds interesting.

If the row's tool ("Claude" or "Codex") does not match the tool actually running
this prompt, STOP and tell Jojo. Mixed wiring is a setup bug; do not silently
swap roles.

Confirm your branch is checked out:

  git status
  git branch --show-current

Branch should match the routing-table value. If not, STOP and tell Jojo.

================================================================================
STEP 2 — Read the canon (mandatory, in this order)
================================================================================

Read these files in full before writing any code:

  1. AGENTS.md                                                       — repo law
  2. docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md       — master brief
  3. docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md §3.5      — forever-loop discipline
  4. docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md            — full 27-T spec; jump to YOUR T-prompt
  5. docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md         — 45 W-rows; where cross-terminal wiring goes
  6. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md                 — research canon entry point
  7. docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md        — substrate canon
  8. docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md           — only required for T21
  9. docs/audits/MULTI_TERMINAL_ARCHEOLOGY_FINDINGS_2026_05_17.md    — what prior terminals already built

You do not need to memorize all of them. You DO need to (a) confirm your
T-prompt's acceptance bar and (b) know where the canon lives so you can recheck
when judgment calls come up.

================================================================================
STEP 3 — Self-report (mandatory, before any tool calls beyond reading)
================================================================================

Send ONE message to Jojo with this exact shape:

  T-ID:               <T09 | T10 | T11 | T12 | T17B | T18B | T21 | T23B>
  Tool:               <Claude | Codex>
  Branch:             <codex/t…-2026-05-18>
  Worktree:           <absolute path from pwd>
  Acceptance bar:     <one-sentence paraphrase from your T-prompt>
  Scope-locked paths: <paths you will NOT touch — see STEP 5>
  First iteration:    <smallest canonical advancement you'll attempt this loop>

If anything in that block is uncertain, STOP and ask Jojo before writing code.
This is the only sync point. After this, you run forever without checking in.

================================================================================
STEP 4 — Enter the forever loop
================================================================================

This terminal is a forever loop. The acceptance bar is a FLOOR, never a CEILING.
Even after acceptance, you continue: deep hardening, falsifier sharpening, the
next canonical nuance from the prompt deck. NEVER EXIT.

Tool-specific invocation:

  If you are Claude:
    Invoke the `/loop` skill self-paced. Body of the loop = your T-prompt's
    mission + acceptance bar. The skill handles iteration cadence.

  If you are Codex:
    You do not have `/loop`. Treat this prompt as the outer driver. After every
    iteration, immediately begin the next one with no human prompt. Print
    "ITERATION N COMPLETE — STARTING ITERATION N+1" between iterations. Never
    print "done", "task complete", or "awaiting next instruction". There is no
    next instruction. The loop is the instruction.

Per-iteration cadence (build-first / test-later — 10 steps):

   1. Re-read your acceptance bar from the prompt deck §4. (One sentence is fine.)
   2. Pick the SMALLEST canonical advancement that moves you toward the bar.
   3. Write code AND its test in the same iteration. No code without a test.
   4. Commit small. One concept per commit. Commit message names the T-ID:
        feat(t11): wire AgentEvent emission in scope_rex_dispatch
   5. Repeat steps 2–4 three to ten times before running ANY test suite.
      (Building features is the priority. Testing is the gate, not the rhythm.)
   6. Run narrow tests only:
        cargo test -p agent_core <module>::tests
        swift test --filter <ExactTestName>
      NEVER `cargo test --workspace`. NEVER `xcodebuild` if you only touched
      Rust or docs. Disk pressure is real — we lost 70+ GB last session.
   7. Green → continue to step 2.
      Red → minimum fix only; do not refactor adjacent code; commit the fix
      under a separate commit.
   8. When your T-prompt's acceptance bar is provably met (tests + WRV check),
      ENTER DEEP HARDENING — only if the work is truly super done. Hardening
      means: tighten falsifiers, add adversarial fixtures, document edge cases,
      drop dead paths you discovered along the way, sharpen the witness/log
      surface.
   9. After hardening, RETURN TO STEP 1. The prompt deck's next canonical
      nuance becomes your new bar. The loop never ends.
  10. Commit cadence: every meaningful change. Jojo has lost work to
      `git checkout` before. NEVER batch commits across feature boundaries.

================================================================================
STEP 5 — Scope lock (non-negotiable)
================================================================================

You touch ONLY the paths your T-prompt names. Cross-terminal needs go to the
W-row backlog (docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md), not
into your branch.

Frozen paths for ALL terminals (T5 is still running):
  agent_core/src/research/operator_ir/
  agent_core/src/research/scan_ir/
  agent_core/src/research/tropical_ir/

If you need something from a path outside your scope:
  1. Append a W-row to the backlog describing the dependency.
  2. Implement against a minimal stub or trait in YOUR scope.
  3. Mark the stub `implemented-not-wired` in your commit message.
  4. Move on. Do NOT cross the line.

T-branches DO NOT MERGE without explicit user authorization. You are building on
your isolated branch. Jojo runs the merge phase by hand following the W-row
priority order. Do not `git checkout main` and do not `git merge` anything.

================================================================================
STEP 6 — Disk pressure rules (we already lost this once)
================================================================================

- NEVER `cargo test --workspace` — builds the whole graph.
- NEVER `cargo build --release` unless your T-prompt explicitly requires it.
- NEVER full `xcodebuild` if you only touched Rust or docs.
- Prefer `cargo check -p <crate>` over `cargo build -p <crate>` for sanity.
- If `target/` in your worktree exceeds 5 GB, run `cargo clean -p <crate>` for
  the crates you are NOT actively building and commit a note in your next
  commit's body.
- T5's worktree (Epistemos-t5-emlir/) is OFF-LIMITS — do not run any build
  command there. Do not even `cd` into it.

================================================================================
STEP 7 — Canonical discipline (read this once, internalize forever)
================================================================================

- Agent naming is LOCKED. System G / Invader Agent is canon. Aegis is REJECTED
  by direct user direction — do not propose it, do not rename to it, do not
  retain it in code or docs. Generic Rust namespace is `agent_runtime_v2`.
- Preserve wide, build narrow. Every research branch stays in the canon docs.
  Only WRV-eligible work enters product code. WRV = Wired + Reachable + Visible
  + Verified.
- A feature is NOT real until it is WRV. Doc-only artifacts are classified
  `not-implemented` or `scaffold-only` and remain so until wired.
- Hardware floor: M2 Pro 14" 2023 — 12-core CPU, 19-core GPU, 16 GB UMA,
  ~200 GB/s. Every falsifier pins to this rig. Not M2 Max. Not theoretical.
- Hermes naming: the Hermes agent subprocess is DEAD. Hermes prompt-format
  parity may remain in Rust under `agent_runtime_v2`. Do not resurrect the
  subprocess. Do not name a new module Hermes.
- Forbidden product work (Vault/Research-only until falsifiers pass):
  ModelSurgery, Active Rank-One runtime, 70B local cocktail execution,
  runtime VPD training, p-adic or sheaf hot-path replacements, open-ended
  CLI agents in MAS, hidden cloud escalation, hidden subprocess behavior.
- If you write docs: every table row needs lane, tier, status, evidence,
  missing proof, next action, and falsifier. No runtime claims from design
  docs alone.

================================================================================
STEP 8 — When to stop reading and start building
================================================================================

Once you have:
  ✓ Identified your T-ID via pwd
  ✓ Confirmed branch
  ✓ Read the canon (STEP 2)
  ✓ Sent the self-report (STEP 3)

…you start the forever loop. Iteration 1, step 1: re-read your acceptance bar.
Then pick the smallest advancement. Then write code + test. Then commit. Then
do it again. And again. Forever.

The shortest commandment, in case you forget: preserve wide, build narrow.
Current-app value first. WRV is the floor, never the ceiling. Never exit the
loop.
```

---

## How to use this doc

1. Open all 8 terminals (one per worktree). Mix of Claude and Codex sessions.
2. `cd` each terminal into its assigned worktree (see routing table above).
3. Paste the block between the triple backticks into every terminal. Don't edit it.
4. Each agent self-identifies, self-reports, then enters its forever loop.
5. You (Jojo) only need to confirm the self-report block when it lands. After that, leave the terminal alone — it loops forever.

## Why one prompt and not eight

- Easier on you: one paste, eight terminals.
- The agent's job to figure out identity, not yours.
- If a terminal is misrouted (e.g., a Codex agent is in a Claude row), the agent stops and tells you — no silent role swap.
- Future Cohort B/C/D launches use the same prompt + an extended routing table.

## What this doc is NOT

- Not a substitute for the prompt deck. The prompt deck is the source of truth for each T-prompt's acceptance bar, scope, and falsifier.
- Not a merge authorization. T-branches stay isolated until Jojo runs the merge phase.
- Not a free pass to skip canon reading. STEP 2 is mandatory; the loop cadence assumes the agent has the canon in head.
