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

> "one executive note is that i want this to be on my github and my flash drive so please save it to my donwalods and put it on my github please that i can easily resuem our conversation and entire thread.
> Publish the exact Epistemos feature currently in flight so another Codex task on my other laptop can resume it without losing context.
>
> Repository: `/Users/jojo/Downloads/Epistemos`
> Branch: `feat/goose-surface`
>
> First read these files completely:
>
> 1. `AGENTS.md`
> 2. `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
> 3. `docs/handoffs/EXTERNAL_PLAN_ASSETS_RECOVERY_2026_07_12.md`
> 4. The current feature plan, intent ledger, verification ledger, source files, tests, logs, and existing diff.
>
> Do not summarize from memory. Inspect the actual repository state first.
>
> Update the `Previous-Task Checkpoint` in `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md` with:
>
> - exact feature and canonical execution key;
> - my latest owner steer verbatim;
> - intended behavior and done bar;
> - every modified file;
> - completed and incomplete work;
> - tests, builds, and manual checks actually performed;
> - retained logs and artifacts;
> - known failures and verification debt;
> - exact next action and commands;
> - commit, branch, and verified remote SHA.
>
> Preserve MAS-only June boundaries. Do not revive parked Goose, Pro, Experimental, 1Code, OpenChamber, sidecar, subprocess, local-server, Node, terminal, stdio-MCP, or browser-use product lanes.
>
> Stage only files that genuinely belong to the in-flight feature and the handoff. Never use `git add .` or `git add -A`. Do not revert, overwrite, or absorb unrelated changes.
>
> Commit the actual in-flight work, push `feat/goose-surface` to origin, fetch it again, and verify the local and remote SHAs match. If mixed ownership prevents a safe feature commit, push the updated handoff alone and explicitly list every file that remains local.
>
> Finish by giving me the exact New-Laptop Resume Prompt from the handoff, the verified remote SHA, committed files, uncommitted files, completed verification, and remaining debt."

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
Pre-publication branch tip: 38f5dd6a3b022f659c6e5a5b240b6f1b2af200ef
Pre-publication upstream state on 2026-07-12: 0 ahead / 0 behind
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

Status: `PUBLISHED_AND_REMOTE_VERIFIED`

Exact feature name:

`KEELSTONE MAS-only base-app and release-gate convergence, owner-steer closeout,
and exact-current-source runtime evidence continuation`

Canonical execution key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Verbatim latest owner steer: preserved in full in the Owner Intent Checkpoint
above.

Interpreted behavior and done bar:

- Publish the exact current branch and a truthful, self-contained checkpoint so
  a new Codex task can resume without hidden task memory.
- Keep MAS-only June as the only active product/agent lane. The historical
  branch name is not authority for Goose or any parked runtime.
- KEELSTONE is complete only after one current-source `Epistemos-AppStore`
  Release archive passes its artifact gates and the finite owner-visible matrix
  proves: vault select/save/relaunch/save; Epdoc rich-content preservation
  through lens switches; writable/responsive Source, Prose, Epdoc, embedded-
  graph, and hologram routes; audible English Kokoro; June local GGUF or an
  exact visible failure; June cloud consent/output or an exact visible failure;
  current distribution/privacy truth; and repeated zero-fail closeout.
- Source parsing, source guards, old archives, and old runtime logs remain
  supporting evidence only. They cannot satisfy current runtime claims.

Why the work remains in flight:

- Source work and the owner-steer closeout are committed, but the exact-current-
  source build/archive/runtime evidence chain has never completed.
- The 2026-07-10 evidence pass stopped before launching any heavyweight work
  because swap was 95.1% occupied.
- `KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md` records SHA
  `0c7123ba442c959b23b87528d3fdff1560320498`, which is not an ancestor of this
  branch. It belongs to a divergent worktree/history and must not be treated as
  current-branch proof. Its methods and failure taxonomy may be reused, but all
  build, artifact, and runtime claims must be regenerated from the verified
  remote branch tip.

Files intentionally modified by this publication task:

- `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`

Files modified but uncommitted at the start of this publication task:

- None. `git status --porcelain=v1 -uall` was empty at
  `38f5dd6a3b022f659c6e5a5b240b6f1b2af200ef`.

Files deliberately not owned by this publication task:

- Every source, test, project, generated-asset, plan, and ledger path outside
  this handoff. No source correction was needed to publish the checkpoint.
- The committed feature surface is broad. Its exact history is authoritative;
  enumerate it with the commands below instead of relying on a lossy prose
  list. High-value current paths include `Epistemos/App/AppBootstrap.swift`,
  `Epistemos/Sync/VaultSyncService.swift`, JuneAgent and QuickChat/GGUF source,
  Kokoro and speech source, graph/editor source, App Store Keelstone tests,
  June substrate tests, and `scripts/keelstone-release-gate.sh`.

Implementation completed and committed before this publication:

- MAS-only surface consolidation and parked-lane removal/quarantine are
  represented by commit `8c46e2b6c` and its descendants on this branch.
- Owner-steer source patches cover editor/graph quiescence and worker bounds,
  Epdoc blank-snapshot and cross-lens reconciliation, clean editor-lease
  transfer, bounded vault-bookmark startup/restore, cancellable English Kokoro,
  bounded June/WebKit/model paths, exact model selection/error propagation,
  and current-source GGUF embedding/linkage gates.
- The July 8 master canon and corrected low-RAM preparation packet are committed
  under `docs/canon/` and `docs/plans/` by
  `38f5dd6a3b022f659c6e5a5b240b6f1b2af200ef`.
- This publication task changed no product source and launched no app, archive,
  model, provider, audio, or owner-vault operation.

Implementation incomplete / verification debt:

- Fresh compilation of the exact remote tip.
- One fresh serial `Epistemos-AppStore` Release archive and artifact gate.
- Vault selection, save, quit/reopen restore, and subsequent save.
- Persisted Epdoc -> Source -> Prose -> Epdoc content/table/formatting fidelity.
- Writable editor lease and typing/load latency for ordinary, embedded-graph,
  and hologram editor routes, including dirty-owner conflict behavior.
- Fresh current-source Kokoro Settings preview/read-aloud, audible English, and
  cancellation/memory reclamation.
- June local GGUF receipt/link/load/token/cancellation/visible-reply evidence.
- June OpenAI/Anthropic consent and either visible output or precise visible
  provider/model error, without reading secrets during preparation.
- Fresh distribution/privacy scan and repeated zero-fail closeout.

Tests, builds, and manual evidence actually performed:

- Earlier owner-steer closeout: focused Swift source/test parsing, shell syntax,
  and the expanded KEELSTONE source gate; the closeout reports 827 passing
  checks and zero swap.
- Earlier retained-artifact scan: finite and red with 12 findings (two GGUF
  embed/link, one parked account/backend marker, seven stale JuneWeb, and two
  privacy-manifest findings). This diagnoses the retained archive only.
- Earlier runtime reconciliation found a retained Kokoro package with 75
  declared files at declared sizes and an older exact-archive playback-
  completion log. No fresh current-source audible check ran.
- This publication pass: repository status/history/ancestry, local and remote
  branch tips, current source/test seams, retained logs, handoff diff,
  `git diff --check`, credential/private-data pattern review, and Git
  connectivity. No Xcode test/build/archive or manual app check ran.

Retained logs and artifacts:

- `docs/plans/keelstone/HANDOFF_OWNER_STEERS_CLOSEOUT_2026_07_10.md`
- `docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`
- `docs/plans/keelstone/INTENT_LEDGER.md`
- `docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md`
- `/tmp/keelstone-source-gate-20260710-*.log` on the original laptop only;
  `/tmp` logs are not durable GitHub assets.
- `/tmp/keelstone-retained-archive-gguf-link-20260710.log` and
  `/tmp/keelstone-retained-app-gate-20260710.log` on the original laptop only.
- `build/visible-mas-proof-2026-07-09-kokoro-responsive-duration-0730/runtime-logs/exact-archive-runtime-kokoro-completed.log`
  if still locally retained; it is historical evidence, not current-tip proof.
- Imported canonical and preparation artifacts listed in the read order above.
- External archival receipts and flash-drive locations are recorded in
  `docs/handoffs/EXTERNAL_PLAN_ASSETS_RECOVERY_2026_07_12.md`.

Known failures / blockers:

- Current KEELSTONE verdict is `INCOMPLETE`.
- The latest retained MAS archive is red and physically lacks executable GGUF
  linkage; it is not a valid proxy for current source.
- Owner-observed graph/editor hanging, prior Epdoc loss/formatting risk, local
  June non-output, and voice uncertainty remain open until fresh evidence.
- Heavy verification must wait for a safe memory/swap window. Never run
  competing `xcodebuild` jobs or concurrent model loads.

External or owner-gated requirements:

- A safe resource window and explicit owner permission before any app launch,
  archive, model load, provider request, audio check, or owner-vault mutation.
- Provider/runtime checks must preserve Keychain secrecy and cloud consent.
- Manual evidence must use the exact `Epistemos-AppStore` / `MAS_SANDBOX`
  product, never a legacy or developer target.

Exact next action:

Verify the remote branch tip and a clean worktree, run the mandatory resource
preflight, and--only in a safe/authorized window--resume the finite KEELSTONE
evidence chain from current source. Do not open another source-hardening batch
unless a focused current-tip failure requires a surgical correction. Do not
advance to `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08` until the
KEELSTONE evidence bar is closed.

Exact next commands:

```bash
git fetch origin feat/goose-surface
git switch feat/goose-surface
git pull --ff-only origin feat/goose-surface
git status --short --branch
git rev-parse HEAD
git rev-parse origin/feat/goose-surface
git log -1 --format='%H %s' -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md
git diff --name-only f0f72a21c7c1e405081357154edddaafecd6545b..HEAD
memory_pressure
sysctl vm.swapusage
df -h .
bash -n scripts/keelstone-release-gate.sh
bash scripts/keelstone-release-gate.sh
```

Stop after the resource preflight if pressure/swap is unsafe. The release-gate
script's help/current plan must be consulted before supplying any archive or
runtime arguments; do not invent a target or launch the app merely because the
source-only gate is green.

Commit, branch, and remote verification:

- Branch: `feat/goose-surface`
- Pre-publication remote SHA verified with both the fetched tracking ref and
  `git ls-remote`:
  `38f5dd6a3b022f659c6e5a5b240b6f1b2af200ef`.
- Publication commit: the commit containing this completed checkpoint. Resolve
  it without a self-referential hard-coded hash using
  `git log -1 --format=%H -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`.
- Verified publication remote SHA: the post-push
  `origin/feat/goose-surface` tip. The publishing task must report its literal
  value alongside this handoff after push/fetch verification; local `HEAD`, the
  fetched tracking ref, and `git ls-remote` must all match it.

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
4. Run the following and verify its result equals local `HEAD`,
   `origin/feat/goose-surface`, and the publication SHA supplied with this
   handoff. If any differ, stop and explain the mismatch without resetting or
   overwriting anything:

   `git log -1 --format=%H -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
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

- [x] Previous-Task Checkpoint no longer says `AWAITING_PREVIOUS_TASK_UPDATE`.
- [x] Exact feature files are committed, or every local-only path is listed.
- [x] No unrelated files were staged or reverted.
- [x] No credential, personal, Columbia, VA, or financial data was committed.
- [x] Narrow checks and verification debt are recorded.
- [x] Local commit is pushed and remote SHA is verified by the publishing task;
      the literal SHA accompanies this self-referential handoff.
- [x] New-laptop prompt names the actual remote branch and gives a deterministic
      publication-SHA verification command.
