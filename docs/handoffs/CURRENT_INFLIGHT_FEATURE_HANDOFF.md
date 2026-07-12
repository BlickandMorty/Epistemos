# Current In-Flight Feature Handoff

Updated: 2026-07-12

This file is the durable GitHub anchor for moving an unfinished Epistemos task
between Codex sessions or machines. A prompt alone does not transfer hidden
model context. The previous task must write its exact implementation state into
this file, commit the relevant work, push it, and report the remote commit SHA.

Authority boundary: this handoff reports state and evidence only. The owner's
full external July 8 master-canon folder controls execution order, and its
numbered `03_MINIMAL_PROMPT_PACK.md` is the sole prompt authority. This handoff,
the repository mirror, status documents, and the preparation packet must never
be used as replacement prompts.

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

Newest continuity steer:

> "teh main canon is that one folder - is the canon folder i attached that is
> the soruce of truth for my work."

> "the most important thing is that i make sure that i can cotninue working in
> order."

The attached executive-planner correction is controlling:

> "The external master-canon folder controls the plan. Repository handoffs and
> the preparation packet may help us understand evidence, but they must never
> become replacement prompts."

Interpreted intent:

- Preserve the exact unfinished feature state outside one Codex task.
- Give the previous task a precise protocol for publishing its context and
  code without staging unrelated work.
- Give the new laptop a deterministic read order and exact resume command.
- Preserve the current MAS master canon and low-RAM preparation packet that
  previously lived outside the repository.
- Resume the canon's exact Prompt 2 only. Do not create or use a custom Prompt
  A/B/C/D chain and do not let a handoff or status document reorder the canon.
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
3. `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/00_READ_FIRST.md`
4. `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/01_OWNER_LOCK_AND_CANONICAL_THESIS.md`
5. `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md`
6. `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/03_MINIMAL_PROMPT_PACK.md`
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

Before using the repository read order, verify the full external canon at
`/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/` and read its
numbered `03_MINIMAL_PROMPT_PACK.md`. The imported repository copy is a recovery
mirror, not higher authority.

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

## Canon-First Reset Continuity Checkpoint — 2026-07-12

This checkpoint is newer than the publication checkpoint above. It updates
recovery truth and the exact resumption boundary; it does not replace or
rewrite canonical Prompt 2.

Canonical authority and current position:

- Sole prompt authority:
  `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/03_MINIMAL_PROMPT_PACK.md`.
- Active numbered prompt: `Prompt 2 - KEELSTONE Storage and MAS Release Gate`.
- Active execution key:
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.
- Do not begin Prompt 3 or recommend another execution key.
- Evidence continuation document:
  `docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`.

Recovery state now proven:

- The full external canon was restored to its original Downloads path from the
  verified flash-drive copy. Recursive comparison passed; it contains 36
  content files and all 18 original source ZIPs.
- The corrected low-RAM preparation folder was restored to its original
  Downloads path. Recursive comparison passed for all nine files.
- The flash drive has two verified complete Git bundles at publication SHA
  `f73b3244c09a76a14961050964969bcb5ac9fa70`, a verified Codex-state backup,
  and the full external plan-assets copy. A new Git bundle must be created
  after this checkpoint's commit is pushed so offline and GitHub tips agree.
- `scripts/resume-keelstone-after-reset.zsh` is the one safe canon-first entry
  point. It restores the two external folders when the flash drive is present,
  verifies canon identity, checks local/origin/live-GitHub/handoff identity,
  reports build prerequisites, applies the owner's resource thresholds, and
  points to canonical Prompt 2 without embedding a replacement prompt.

In-flight source correction preserved by this checkpoint:

- `scripts/keelstone-release-gate.sh` now fails closed on missing or stale
  staged/built JuneWeb and checks that the built MAS app embeds and links
  June's in-process `llama.framework`.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` pins those
  built-artifact checks.
- Shell syntax, Swift parsing, diff checks, and the focused static gate contract
  pass. With the stage absent, the gate is correctly red on exactly the missing
  staged index and shim. This is source/static evidence only.

Files owned by this continuity checkpoint:

- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`
- `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
- `docs/handoffs/EXTERNAL_PLAN_ASSETS_RECOVERY_2026_07_12.md`
- `docs/plans/keelstone/INTENT_LEDGER.md`
- `docs/plans/keelstone/VERIFICATION_LEDGER_2026_07_07.md`
- `scripts/create-epistemos-codex-restore-backup.zsh`
- `scripts/keelstone-release-gate.sh`
- `scripts/restore-epistemos-codex-on-new-mac.command`
- `scripts/resume-keelstone-after-reset.zsh`

Current environment blockers and verification debt:

- Rust (`cargo`/`rustc`) is absent. The focused Xcode test cannot reach its
  assertion until the Rust build phase can run.
- Bun is absent.
- The App Store signing identity/profile is absent. The signed focused test
  stopped at provisioning; the unsigned retry stopped at Rust.
- `.june-web-stage` is absent.
- The owner-modified June donor checkout is absent. Its durable public base is
  `https://github.com/BlickandMorty/os-june.git`, branch
  `epistemos-vendor`, but the recorded local commit
  `7105c43c8622cc546075f7ff1e20680e2009f8bb` and its 92-file dirty overlay
  were never pushed and must not be invented. The private Codex-state backup
  retains the exact recorded patch evidence.
- The last reviewed July 10 stage is recoverable only when reconstruction
  matches all three hash oracles: main asset
  `9d38c92dea2a70bf15e88741c47ea9833da3fee8ecfc053fd593f4befc8a1144`,
  index `30790bb4f65afaf93dd9db5bd4fc9ec396708d4f22f7cb881a24c0cbeec2c00e`,
  and shim `7440986d70a044689fea50f8a181441dfc05c5b8736421691db8b2980979e77a`.
  A source tree or stage that does not match must be reviewed as new evidence.
- No fresh current-tip test, Release archive, app launch, model load, provider
  request, Keychain secret read, owner-vault mutation, audio operation, or
  runtime matrix was completed in this continuity pass.

Exact next action after reset:

1. Run `scripts/resume-keelstone-after-reset.zsh` from the verified branch.
2. If it reports a fatal identity mismatch, stop without resetting or
   overwriting anything.
3. Restore Rust, Bun, Apple signing, and an exact reviewed JuneWeb stage/donor.
4. Re-run the script. The owner's mandatory threshold is swap below 4 GB, at
   least 25% free memory, zero pages throttled, and no competing
   Xcode/compiler/model/Epistemos process.
5. Only when identity, prerequisites, and safety are green: run the narrow
   serial compile/regression batch, produce exactly one
   `Epistemos-AppStore` Release archive, run every artifact gate, then run the
   finite correlated runtime matrix. Update the existing exact-runtime evidence
   document and stop after the final KEELSTONE verdict.

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
and verified the external canon and remote state. This is a bootstrap prompt,
not a replacement execution prompt.

1. Clone or open https://github.com/BlickandMorty/Epistemos.
2. Fetch origin and switch to the branch recorded in
   docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md. Pull with --ff-only.
3. Connect the flash drive if available and run
   scripts/resume-keelstone-after-reset.zsh. It must restore/verify
   /Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08 and the corrected
   preparation folder. If it reports a fatal identity mismatch, stop without
   resetting or overwriting anything.
4. Read the external canon's 00_READ_FIRST.md, 01, 02, and numbered
   03_MINIMAL_PROMPT_PACK.md first. The external numbered prompt pack is the
   sole prompt authority. Then read AGENTS.md,
   docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md, the low-RAM correction
   log, current KEELSTONE prompt/plan and intent/evidence ledgers, and this
   handoff in its entirety. Handoffs and preparation are evidence only; do not
   create a custom Prompt A/B/C/D chain or replace canonical Prompt 2.
5. Run the following and verify its result equals local `HEAD`,
   `origin/feat/goose-surface`, and the publication SHA supplied with this
   handoff. If any differ, stop and explain the mismatch without resetting or
   overwriting anything:

   `git log -1 --format=%H -- docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`
6. Inspect git status, the recorded feature files, nearby contracts/call sites,
   tests, retained logs/artifacts, and the diff from the handoff baseline.
7. Restate the exact owner intent, canonical execution key, hard constraints,
   done bar, proven state, verification debt, and exact next action before
   editing.
8. Continue only canonical Prompt 2,
   EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08, from the recorded resource
   preflight boundary. Restore every reported prerequisite first. Preserve
   MAS-only June boundaries, use surgical edits, and do not claim runtime
   behavior without current exact evidence. Do not begin Prompt 3.

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
