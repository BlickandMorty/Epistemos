# Current In-Flight Feature Handoff

Updated: 2026-07-12

This file is the durable GitHub anchor for moving an unfinished Epistemos task
between Codex sessions or machines. A prompt alone does not transfer hidden
model context. The previous task must write its exact implementation state into
this file, commit the relevant work, push it, and report the remote commit SHA.

## Owner Intent Checkpoint

Owner wording:

> "in case things dont go as planned ... send something to my github that the
> new codex can pull or reference that has an understanding ... i do not lose
> the present work it is an in flight feature set im working on"

Latest owner steer:

> "remember these three were outside of my epistemos folder so i want to make
> sure these are there as well these are my main plan docs and files along with
> all the stuff from epistemos dir that you should have already backed up"

Interpreted intent:

- Preserve the exact unfinished feature state outside one Codex task.
- Give the previous task a precise protocol for publishing its context and
  code without staging unrelated work.
- Give the new laptop a deterministic read order and exact resume command.
- Preserve the current MAS master canon and low-RAM preparation packet that
  previously lived outside the repository.
- Keep private Columbia, VA, financial, credential, and personal data out of
  GitHub.

Hard constraints:

- Active product target is MAS-only June.
- The current execution key is
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` until its evidence bar is
  honestly closed.
- The historical branch name `feat/goose-surface` does not authorize Goose,
  Pro, Experimental, OpenChamber, 1Code, a subprocess, local server, or Node
  backend as an active product lane.
- Never use `git add -A`, `git add .`, broad cleanup, reset, checkout-overwrite,
  or deletion to prepare the handoff.
- Do not claim runtime behavior from source parsing, static gates, or an old
  archive.

Non-goals:

- This file is not a substitute for committing the actual in-flight code.
- It does not declare KEELSTONE complete.
- It does not reopen parked product lanes or authorize unrelated refactors.
- It does not copy Codex databases, browser state, credentials, or private
  funding documents into the repository.
- It does not publish the older 42 MB before-autonomy-fix archive or its nested
  source ZIPs to this public repository.

## Verified Repository Baseline

```text
Repository: https://github.com/BlickandMorty/Epistemos
Branch: feat/goose-surface
Baseline commit: f0f72a21c7c1e405081357154edddaafecd6545b
Baseline upstream state on 2026-07-12: 0 ahead / 0 behind
Product lock: MAS_ONLY_SHIP_LOCK_2026_07_07
Current execution key: EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08
Imported canon: docs/canon/epistemos_mas_master_canon_2026_07_08/
Imported preparation: docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/
```

Read first:

1. `AGENTS.md`
2. `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
3. `docs/canon/epistemos_mas_master_canon_2026_07_08/00_READ_FIRST.md`
4. `docs/canon/epistemos_mas_master_canon_2026_07_08/01_OWNER_LOCK_AND_CANONICAL_THESIS.md`
5. `docs/canon/epistemos_mas_master_canon_2026_07_08/02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md`
6. `docs/canon/epistemos_mas_master_canon_2026_07_08/03_MINIMAL_PROMPT_PACK.md`
7. `docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/PREPARATION_PACKET_CORRECTION_LOG.md`
8. `docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/00_READ_FIRST_PREPARATION_ONLY.md`
9. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
10. `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
11. `docs/plans/keelstone/HANDOFF_MAS_BASE_APP_COMPLETION_2026_07_10.md`
12. `docs/plans/keelstone/HANDOFF_OWNER_STEERS_CLOSEOUT_2026_07_10.md`
13. `docs/plans/keelstone/INTENT_LEDGER.md`
14. `docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md`
15. `docs/handoffs/EXTERNAL_PLAN_ASSETS_RECOVERY_2026_07_12.md`
16. This file, including the previous-task checkpoint below.

## Current Program Truth Before Previous-Task Update

The last durable program handoff says KEELSTONE source work is substantially
converged, but exact current-source MAS runtime evidence remains open. The
high-value evidence matrix includes:

- exact MAS/June base-product identity;
- security-scoped vault select, save, quit/reopen restore, and no-loss proof;
- Epdoc open/switch/reopen rich-content fidelity;
- responsive editing and correct graph-to-editor routing;
- audible English Kokoro preview and read-aloud surface proof;
- June native-gateway output or a precise provider/model error;
- current MAS GGUF framework embedding/linkage, receipt, load, cancellation,
  and visible reply proof;
- current archive, release scan, and repeated zero-fail closeout after relevant
  source changes.

The previous task must replace uncertainty with its newer evidence. It must not
silently inherit these as completed.

## Previous-Task Checkpoint

Status: `AWAITING_PREVIOUS_TASK_UPDATE`

The previous Codex task must update this section before it claims the handoff is
published. It must record:

```text
Exact feature name / canonical execution key:
Verbatim latest owner steer:
Interpreted behavior and done bar:
Why the work is in flight:
Files intentionally modified:
Files deliberately not owned:
Implementation completed:
Implementation incomplete:
Tests / builds / manual evidence actually run:
Exact retained logs or artifacts:
Verification debt and unproven claims:
Known failures / blockers:
External or owner-gated requirements:
Exact next action:
Exact next command(s):
Commit created for the in-flight feature:
Remote branch and verified remote SHA:
```

If code is uncommitted, the previous task must stage only the files it can prove
belong to this feature. If unrelated changes share a file, it must preserve them
and document the mixed ownership instead of discarding or blindly committing
them.

## Prompt To Paste Into The Previous Codex Task

```text
Publish a durable cross-laptop handoff for the exact Epistemos feature you are
currently implementing. Do not start a new feature and do not summarize from
memory alone.

Repository: /Users/jojo/Downloads/Epistemos
Durable handoff:
docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md

First read AGENTS.md, the current feature prompt/plan and its intent/evidence
ledgers, docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md, and the entire
existing durable handoff. Also read the imported master canon at
docs/canon/epistemos_mas_master_canon_2026_07_08/00_READ_FIRST.md and the
low-RAM correction log at
docs/plans/epistemos_mas_low_ram_preparation_2026_07_11/PREPARATION_PACKET_CORRECTION_LOG.md.
Inspect the current source, git status, diff, recent commits, tests, logs, and
artifacts before writing.

Update only the Previous-Task Checkpoint and any immediately necessary read
order/status text in the durable handoff. Preserve my latest owner wording
verbatim. Record the exact feature/canonical execution key, interpreted done
bar, modified files, completed and incomplete behavior, tests actually run,
retained evidence, failures, verification debt, owner/external gates, and the
exact next commands. Distinguish source-patched, build-proven, and manually
witnessed behavior. Do not mark untested behavior complete.

The active product is MAS-only June. The current canonical execution sequence
uses the full July 8 IDs. Do not revive Goose, Pro, Experimental, 1Code,
OpenChamber, subprocess, local-server, Node, terminal, stdio-MCP, or browser-use
lanes. The historical branch name feat/goose-surface is not product authority.

Before committing, inspect the diff and search for contradictions, stale
directives, credentials, personal data, Columbia/VA/financial data, absolute
secret paths, tokens, and generated/build output. Never use git add -A or git
add . Stage only the handoff plus exact feature files that you own and that are
needed to preserve the in-flight implementation. Do not revert or absorb
unrelated user/agent changes. Run the narrowest relevant checks, then any safe
broader source guards required by the feature. Record every deferred runtime or
heavy verification item honestly.

Commit the handoff and the exact in-flight feature work to the current branch,
push that branch to origin, fetch the remote, and verify the remote SHA equals
the local SHA. If a safe commit is impossible because ownership is mixed,
commit and push the handoff alone, list every uncommitted feature path and why
it remains local, and do not claim the code is protected by GitHub.

Finish by reporting:
1. local commit SHA;
2. remote branch and remote SHA;
3. exact files committed;
4. exact files still uncommitted;
5. verification run and remaining debt;
6. the exact New-Laptop Resume Prompt from the durable handoff.
```

## New-Laptop Resume Prompt

```text
Resume the exact in-flight Epistemos feature from its durable GitHub handoff.
Do not begin implementation until you have grounded yourself in current source
and verified the remote state.

1. Clone or open https://github.com/BlickandMorty/Epistemos.
2. Fetch origin and switch to the branch recorded in
   docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md. Pull with --ff-only.
3. Read AGENTS.md, docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md, the
   imported MAS master canon, the low-RAM preparation correction log, the
   current feature prompt/plan and intent/evidence ledgers, and
   docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md in its entirety.
4. Verify local HEAD equals the Remote SHA recorded in the Previous-Task
   Checkpoint. If it does not, stop and explain the mismatch without resetting
   or overwriting anything.
5. Inspect git status, the recorded feature files, nearby contracts/call sites,
   tests, retained logs/artifacts, and the diff from the handoff baseline.
6. Restate the exact owner intent, canonical execution key, hard constraints,
   done bar, proven state, verification debt, and exact next action before
   editing.
7. Continue from the recorded next action. Preserve MAS-only June boundaries,
   use surgical edits, and do not claim runtime behavior without current exact
   evidence.

Private Columbia/VA/funding work is not stored in this repository and must not
be inferred from this handoff.
```

## Handoff Acceptance Checks

- [ ] Previous-Task Checkpoint no longer says `AWAITING_PREVIOUS_TASK_UPDATE`.
- [ ] Exact feature files are committed, or every local-only path is listed.
- [ ] No unrelated files were staged or reverted.
- [ ] No credential, personal, Columbia, VA, or financial data was committed.
- [ ] Narrow checks and verification debt are recorded.
- [ ] Local commit is pushed and remote SHA is verified.
- [ ] New-laptop prompt names the actual remote branch and SHA.
