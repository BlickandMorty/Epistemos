# Builder Execution Prompt - Epistemos Fusion - 2026-04-30

You are Claude Code or another coding agent working inside the existing Epistemos repository.

Repository:

`/Users/jojo/Downloads/Epistemos`

You are the builder for this session. Codex is the auditor. If Kimi is the active builder instead, Kimi must follow `/Users/jojo/Downloads/Epistemos/docs/fusion/KIMI_RESEARCH_AND_FUSION_PROMPT_2026_04_30.md` under Codex oversight.

Your job is to preserve the user's best research and worktree work without raw-merging stale branches or inventing a new architecture.

## Prime Directive

Epistemos is a local-first native macOS verifiable cognition substrate.

The spine is:

```text
TypedArtifact -> MutationEnvelope -> RunEventLog -> AgentEvent -> GraphEvent -> Halo / Graph / Theater / Audit
```

Humans and agents think in Prose and Raw Thoughts.
They produce in Documents and Code.
Everything is linked through typed graph relationships inside one vault.

## Read First

Read these exact files. Do not look for missing overlay filenames unless directed.

Repo authority:

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/CLAUDE.md` if present
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
4. `/Users/jojo/Downloads/Epistemos/docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`
5. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/CODEX_VERIFIED_STATE_2026_04_25.md`
6. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/MASTER_FUSION.md`
7. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/MASTER_BUILD_PLAN.md`
8. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/RESEARCH_INDEX_BY_FEATURE.md`
9. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md`

Fusion packet:

10. `/Users/jojo/Downloads/Epistemos/docs/fusion/README_START_HERE_2026_04_30.md`
11. `/Users/jojo/Downloads/Epistemos/docs/fusion/CANONICAL_SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md`

April 30 source docs:

12. `/Users/jojo/Downloads/EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_2026_04_30.md`
13. `/Users/jojo/Downloads/SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md`
14. `/Users/jojo/Downloads/CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30.md`

If any file is missing, record the miss in the inventory. Do not invent its contents.

## Non-Negotiable Rules

- Do not code before Phase 0 inventory and fusion notes.
- Do not raw-merge any worktree.
- Do not delete or clean dirty work.
- Do not revert unrelated changes.
- Do not touch protected paths unless the slice explicitly requires it and the auditor approves.
- Do not replace Prose.
- Do not flatten Documents, Raw Thoughts, Code, Sources, and Outputs into "notes".
- Do not make Markdown projections canonical.
- Do not spawn user-installed coding CLIs from the Mac App Store target.
- Do not put Hermes, Docker, browser/computer-use, or external CLI tunnels in Core/MAS.
- Do not use private Apple APIs.
- Do not implement neural-kernel/private ANE ideas in Core.
- Do not claim a feature is wired unless user-visible path is proven.
- Do not claim performance without test, benchmark, signpost, or raw log evidence.

Protected until explicitly approved:

- `/Users/jojo/Downloads/Epistemos/Views/Notes/ProseEditor*.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/ProseEditor*.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Graph/MetalGraphView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Graph/HologramController.swift`
- graph physics/rendering files unless the current slice is graph-specific
- generated `.rlib`, DerivedData, build products, `.xcresult` bundles

## Phase 0 - Required First Task

Produce these docs before coding:

1. `/Users/jojo/Downloads/Epistemos/docs/fusion/WORKTREE_INVENTORY_2026_04_30.md`
2. `/Users/jojo/Downloads/Epistemos/docs/fusion/RESEARCH_FUSION_NOTES_2026_04_30.md`
3. `/Users/jojo/Downloads/Epistemos/docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md`

### Phase 0 Commands

Run and capture evidence:

```bash
cd /Users/jojo/Downloads/Epistemos
git rev-parse --short HEAD
git branch --show-current
git status --short -uall
git worktree list
git stash list
git log --oneline --decorate --graph --all --max-count=80
```

Inventory likely donor worktrees:

```bash
git -C /Users/jojo/Downloads/Epistemos-laneA status --short -uall 2>/dev/null || true
git -C /Users/jojo/Downloads/Epistemos-laneA log --oneline --max-count=20 2>/dev/null || true
```

Use `git worktree list` to locate `.claude/worktrees/*`, then inspect each with:

```bash
git -C <worktree-path> rev-parse --short HEAD
git -C <worktree-path> branch --show-current
git -C <worktree-path> status --short -uall
git -C <worktree-path> diff --stat
git -C <worktree-path> log --oneline --max-count=20
```

### Phase 0 Research Scan

For each current slice candidate, search local research:

```bash
rg -n --hidden --glob '!build/**' --glob '!DerivedData/**' --glob '!test_results/**' "<keyword>" \
  /Users/jojo/Downloads/Epistemos/docs \
  /Users/jojo/Downloads/final \
  /Users/jojo/Downloads/'final v2' \
  /Users/jojo/Downloads/'final v3' \
  /Users/jojo/Downloads/ambient \
  /Users/jojo/Downloads/Advice \
  /Users/jojo/Downloads/Pasted\ markdown.md \
  /Users/jojo/Downloads/Epistemos-laneA 2>/dev/null
```

Required keywords at minimum:

- `Quick Capture`
- `Raw Thoughts`
- `TypedArtifact`
- `MutationEnvelope`
- `RunEventLog`
- `Halo`
- `Contextual Shadows`
- `Hermes`
- `CLI`
- `MCP`
- `App Store`
- `Core`
- `Pro`
- `Document`
- `.epdoc`
- `Code editor`
- `Tree-sitter`
- `SourceKit`

## Fused Implementation Queue Rules

Every queue item must include:

- Title
- Source clusters used
- Current code evidence
- Why it belongs now
- Core / Pro / Both
- Files likely touched
- Forbidden files
- Tests/commands
- Runtime/manual verification that does not require the user when possible
- Rollback
- Acceptance criteria
- Stop triggers

Queue order should default to:

1. preserve current dirty main and verify build/test floor
2. close crash/build blockers
3. produce worktree salvage map
4. Core/MAS safety gates
5. typed artifact / provenance substrate
6. Quick Capture fusion if low conflict
7. Halo / Contextual Shadows V1 proof
8. Raw Thoughts persistence/timeline if not already complete
9. search/readable projections
10. code editor performance line count and syntax-fluidity research/patches
11. .epdoc / Document stubs
12. Pro tunnels / Hermes / CLI only after Core gates

## Deliberation Brief Required Before Each Slice

Before coding a slice, create:

`/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/<slice>_deliberation_2026_04_30.md`

Template:

```md
# Deliberation Brief - <slice>

## A. Repo Evidence
- files:
- current behavior:
- tests/logs:

## B. Research Evidence
- repo docs:
- Downloads docs:
- worktree donor evidence:
- current web/API docs if needed:

## C. Decision
- chosen path:
- why:
- Core/Pro/Both:

## D. Alternatives
- do nothing/defer:
- reuse existing:
- donor worktree extraction:
- new code:

## E. Reversal Triggers
- what would make this decision wrong:

## F. Patch Plan
- files:
- tests:
- rollback:
```

Do not code until the deliberation brief is complete.

## Output After Each Patch

Report:

1. what changed
2. files touched
3. source clusters preserved
4. tests/commands run
5. raw log paths
6. remaining risk
7. rollback
8. next recommended slice

Stop if you hit any P0/P1 issue.

## First Action

Start with Phase 0 only.

Do not implement features until `WORKTREE_INVENTORY_2026_04_30.md`, `RESEARCH_FUSION_NOTES_2026_04_30.md`, and `FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` exist and have been reviewed.
