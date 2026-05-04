# Task Prompt — Phase 0: Ship Blockers (A+_RELEASE_ROADMAP.md)

> Generated for Phase 0 from `prompts/_TEMPLATE.md`, scoped to a single multi-task
> session because the 7 ship-blocker fixes are individually trivial (~50 LOC total)
> but coupled (they collectively unblock shipping). Copy-paste this entire file
> into a fresh Claude Code session as the first message.

---

You are a Claude Code session executing **Phase 0 — Ship Blockers** for the
Epistemos repo at `/Users/jojo/Downloads/Epistemos/`. Source of truth:
`/Users/jojo/Downloads/Epistemos/A+_RELEASE_ROADMAP.md`. You operate under the
strict anti-drift contract in `docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md`. Read it.
Obey it.

Today's date: **2026-04-27** (verify if resumed later).

---

## Phase 1 — Pre-flight reads (MANDATORY, in this exact order)

Before writing or editing any code, you must `Read` each of the following files in
full. Output a one-paragraph summary of the load-bearing constraints from each
before doing anything else.

**Required reads (in order):**

1. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md` — architectural authority.
2. `/Users/jojo/Downloads/Epistemos/CLAUDE.md` — code standards.
3. `/Users/jojo/Downloads/Epistemos/A+_RELEASE_ROADMAP.md` — **the entire document.** This is your task source.
4. `/Users/jojo/Downloads/Epistemos/docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md` — the contract.
5. `/Users/jojo/Downloads/Epistemos/docs/plan/04_PHASES.md` — Phase 0 entry/exit gates.
6. `/Users/jojo/Downloads/Epistemos/docs/AGENT_PROGRESS.md` — current state.
7. `/Users/jojo/Downloads/Epistemos/docs/APP_ISSUES_AUTO_FIX.md` — open auto-fix issues (do NOT touch unrelated ones in this PR).

**Item-specific research reads:**

- The dossier's reconciliation table in `docs/plan/01_DOCTRINE.md §8` — Phase 0 ships before any other dossier item.
- `/Users/jojo/Downloads/Fixing Epistemos Build-and-Ship Issues.md` (auxiliary research, may have additional ship gotchas).

---

## Phase 2 — Verify the codebase (auto-research mandate)

The `A+_RELEASE_ROADMAP.md` cites specific file paths and line numbers. Re-verify
each one before treating it as canonical. The roadmap is dated; the code may have
drifted. Specifically:

```
Read /Users/jojo/Downloads/Epistemos/Epistemos/App/AppBootstrap.swift around line 22 — confirm enum ShipGate with agentsEnabled flag
Read /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/StreamingDelegate.swift around lines 64-73 — confirm runAgentSession is still a stub returning AgentRuntimeBridgeError.bindingsUnavailable
Read /Users/jojo/Downloads/Epistemos/Epistemos/Engine/EmbeddingService.swift around lines 218-225 — confirm sendEmbeddingBatch wrapped in await MainActor.run { ... }
Read /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MetalGraphView.swift around line 692 — confirm CADisplayLink handler runs renderFrame on main thread
Read /Users/jojo/Downloads/Epistemos/Cargo.toml — confirm tree-sitter dependencies enumerated
Read /Users/jojo/Downloads/Epistemos/build-rust.sh — confirm SHIP_MODE handling (or its absence)
Find Epistemos/Epistemos/KnowledgeFusion -type d — confirm MOHAWK directory exists and size
Find Epistemos/Epistemos/Omega -type f -name "*.swift" | wc -l — confirm 43 files / ~7,874 LOC of stubs
Read /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj/project.pbxproj — confirm Copy Bundle Resources phase
```

If any path or line number has drifted: STOP and surface. Do NOT silently rebase.

---

## Phase 3 — Restate the task back

Output:

```
TASK CONTRACT — Phase 0 Ship Blockers
=====================================
Source: A+_RELEASE_ROADMAP.md
Phase: 0 (must ship before Phase 1 starts)
Targets: Both (MAS + Pro — but A+_RELEASE_ROADMAP is currently shaped around the
         legacy single-target build; verify project.yml has both targets defined
         before assuming dual-target applicability)
Risk: Low individually, Medium collectively (7 coupled changes)

Tasks I will execute (verified above):
1. Exclude Epistemos/KnowledgeFusion/MOHAWK/ from Copy Bundle Resources (saves ~47 MB)
2. AppBootstrap.swift:22 — set ShipGate.agentsEnabled = false for release
3. build-rust.sh — verify SHIP_MODE=release Cargo build path; add to Xcode Build
   Scheme Pre-actions
4. StreamingDelegate.swift:72 — wire runAgentSession to AgentViewModel.runCloudAgent
   OR remove the call site if cloud is not in v1 release scope (PER USER DECISION
   below)
5. EmbeddingService.swift:218-225 — replace MainActor.run wrapper with serial
   DispatchQueue
6. MetalGraphView.swift:692 — handleDisplayLinkTick offloads renderFrame to
   background DispatchQueue
7. NoteChatState.swift — add @Query debouncer for AI streaming

Files I will modify:
- Epistemos.xcodeproj/project.pbxproj (exclude MOHAWK/Omega from Copy Bundle)
- Epistemos/App/AppBootstrap.swift (line 22, 1 line)
- build-rust.sh (verify and adjust)
- Epistemos/Bridge/StreamingDelegate.swift (lines 64-73, ~6 lines)
- Epistemos/Engine/EmbeddingService.swift (lines 218-225, ~8 lines)
- Epistemos/Engine/MetalGraphView.swift (line 692, ~10 lines)
- Epistemos/State/NoteChatState.swift (~15 lines)
- Cargo.toml — feature-flag tree-sitter parsers (~12 lines)

Total estimated diff: ~50 LOC across 7 files

Tests that must stay green:
- Entire 2,679-test floor
- Smoke build of Pro AND MAS targets
- Visual smoke test: open large vault, pan graph, see 60 fps

Telemetry surface I will create:
- None (Phase 0 is shipping discipline, not new functionality)

WRV plan (per 00_AUTHORITY_AND_ANTI_DRIFT.md §4.7):
- WIRED — N/A (Phase 0 modifies existing wired code paths; no new symbols introduced)
- REACHABLE — N/A (existing user gestures continue to work; the test is that they
              stop misbehaving — graph stutter gone, AI streaming smooth, etc.)
- VISIBLE — User-facing changes ARE observable: smaller bundle (visible in Finder
            after archive), graph runs at 60 fps (visible during normal use), no
            agent crash on operatingMode=.agent (visible when user picks agent mode)

Phase 0 is borderline WRV_EXEMPT (it modifies existing wired code, not new
features) but to be safe: each fix MUST have a manual smoke test demonstrating the
user-visible improvement (graph 60 fps, no UI freeze, bundle under 200 MB). If a
fix lands but the user can't verify the improvement, the fix is suspect.

Definition of done:
- [ ] All 7 tasks complete with verification greps passing
- [ ] App bundle <200 MB (run `xcodebuild archive` and check Show in Finder)
- [ ] Smoke test: graph pans at 60 fps, AI streaming does not stutter
- [ ] AGENT_PROGRESS.md updated with date + per-task completion
- [ ] All verification gates from 00_AUTHORITY_AND_ANTI_DRIFT.md §4 pass
- [ ] Local tag created: v1.0.0-pre-phase1 (do NOT push)

USER DECISIONS REQUIRED (if not pre-answered):
- Q1: For task 4 (runAgentSession stub), is cloud agent in v1 release scope? If
  yes: wire to AgentViewModel.runCloudAgent. If no: remove the call site in
  ChatCoordinator.swift.
- Q2: For task 8 (Cargo.toml tree-sitter feature flags), which languages does v1
  need? Default suggestion: swift + json only.

Pre-flight reads complete: yes / no
[UNVERIFIED] markers found: <count>
STOP-triggers encountered: none / list

If both Q1 and Q2 are answered (or pre-answered in the user's prompt): proceed.
Otherwise: stop here and ask.
```

---

## Phase 4 — Implement

Execute the 7 tasks **in order**. Each task is a separate logical unit; commit
each as its own commit on a single branch (e.g., `phase-0-ship-blockers`). Verify
after each commit that the build is still green before moving to the next.

**Hard rules:**

- No scope creep. The roadmap lists 7 tasks. Execute exactly 7. If you find an
  8th issue, file it in `docs/APP_ISSUES_AUTO_FIX.md`, do NOT fix it here.
- No forbidden actions per `00_AUTHORITY_AND_ANTI_DRIFT.md §6`.
- The roadmap was authored before `02_BUILD_MATRIX.md`. If a task is target-specific
  (e.g., MOHAWK exclusion may need to apply only to one target), surface to the
  user before guessing.
- For task 5 (EmbeddingService): the new serial queue must use QoS `.utility`,
  NOT the global default queue. The roadmap specifies the exact pattern.

**Auto-research:** if a roadmap-cited line number drifts, STOP. Do not silently
rebase to the new line — confirm the rebase target is the right code.

---

## Phase 5 — Verify

Run all six verification gates:

1. **Build green** for BOTH targets (Pro and MAS, if dual-target is configured;
   otherwise the single legacy target).
2. **Test floor preserved** — the entire 2,679-test suite green.
3. **Lint clean** — swiftlint, cargo clippy.
4. **No-silent-behavior audit** — Phase 0 should NOT introduce any new behavior;
   confirm no new code paths that activate without telemetry.
5. **Definition of done** — every checkbox from the contract checked.
6. **Update `docs/AGENT_PROGRESS.md`** AND tag the commit:
   ```bash
   git tag -a v1.0.0-pre-phase1 -m "Phase 0 ship blockers complete; ready for Phase 1 vertical slice."
   ```
   **Do NOT push the tag** unless the user explicitly approves.

**Bundle-size verification:**
```bash
xcodebuild -scheme Epistemos -configuration Release archive -archivePath /tmp/Epistemos.xcarchive
du -sh /tmp/Epistemos.xcarchive/Products/Applications/Epistemos.app
# Expected: < 200 MB
```

If the archive is > 200 MB: STOP. Surface what's still bloating it.

---

## Phase 6 — Output

PR description format per `_TEMPLATE.md` Phase 6. The PR is structured as 7 separate
commits on a single branch — keep that structure when pushing later. End with:

> Phase 0 complete. Verification gates passed. App bundle: <NNN> MB. Tag v1.0.0-pre-phase1 created locally. Awaiting user approval to push branch + tag.

Do not push. Do not `gh pr create`. Wait for user.

---

## Item-specific notes

- This is the **prerequisite for everything in `04_PHASES.md` Phase 1+**. Do not
  skip it.
- The legacy `A+_RELEASE_ROADMAP.md` was authored before the doctrine in
  `docs/plan/`; if a roadmap rule contradicts the doctrine, the doctrine wins.
  Specifically: the doctrine forbids `try!`, force unwraps, `print()`,
  `DispatchQueue.main.sync` in callbacks. If a roadmap fix would introduce one of
  those: STOP and surface. The doctrine wins.
- The `runAgentSession` stub at `StreamingDelegate.swift:64-73` is currently a
  permanent throw of `AgentRuntimeBridgeError.bindingsUnavailable`. The roadmap
  offers two options: (A) wire to `AgentViewModel.shared.runCloudAgent(...)`, or
  (B) remove the call site entirely from `ChatCoordinator.swift` if cloud is not
  in v1 scope. **Ask the user which** before implementing — this is a product
  decision, not a refactor decision.

---

When complete:

> Phase 0 complete. Verification gates passed. App bundle: <NNN> MB. Tag v1.0.0-pre-phase1 created locally. Awaiting user approval to push branch + tag.

If you stop:

> STOPPED at Phase <N>: <reason>. Awaiting user guidance.
