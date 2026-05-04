# Canonical Source Map and Gate Register - 2026-04-30

## Purpose

This file tells builder/auditor agents what to read, what each source is allowed to decide, and how to preserve nuance without turning every older research document into direct execution authority.

## Highest Authority

Read these first:

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/CLAUDE.md` if present
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
4. `/Users/jojo/Downloads/Epistemos/docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`
5. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/CODEX_VERIFIED_STATE_2026_04_25.md`
6. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/MASTER_FUSION.md`
7. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/MASTER_BUILD_PLAN.md`
8. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/RESEARCH_INDEX_BY_FEATURE.md`
9. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md`
10. `/Users/jojo/Downloads/Epistemos/docs/fusion/README_START_HERE_2026_04_30.md`
11. `/Users/jojo/Downloads/Epistemos/docs/fusion/CANONICAL_SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md`

Read these April 30 Downloads docs next:

1. `/Users/jojo/Downloads/EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_2026_04_30.md`
2. `/Users/jojo/Downloads/SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md`
3. `/Users/jojo/Downloads/CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30.md`

## Source Clusters

### Active Repo And Consolidated Canon

Path roots:

- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/`
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/20_canonical_research/`
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/30_canonical_operational/`
- `/Users/jojo/Downloads/Epistemos/docs/audits/`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/`

Role:

- governs current architecture
- establishes verified floor
- maps research by feature
- defines release/hardening rules

Gate:

- direct authority only if it matches current code and logs
- claims of "done", "green", or "shipped" require fresh verification

### Lane A

Path roots:

- `/Users/jojo/Downloads/Epistemos-laneA/`
- `/Users/jojo/Downloads/Epistemos-laneA/docs/`

Known purpose:

- control plane / driver channel work
- already appears substantially merged into main, but must still be verified

Gate:

- treat as donor/reference unless diff proves it has unmerged value
- do not overwrite main files from Lane A blindly
- create a lane-specific inventory before any cherry-pick

### Quick Capture / Agent-Core Worktree

Likely path root:

- `/Users/jojo/Downloads/Epistemos/.claude/worktrees/vigorous-goldberg-3a2d35/`

Known purpose:

- Quick Capture
- agent core / provenance / typed capture work

Gate:

- sibling-canonical, not trunk authority
- extract concepts, tests, and small patches only after inventory
- preserve capture UX and data model ideas
- rebuild on main's current substrate if assumptions drifted

### Simulation / Hermes / Theater Worktree

Likely path root:

- `/Users/jojo/Downloads/Epistemos/.claude/worktrees/simulation/`

Known purpose:

- Simulation Theater
- companion/Hermes visuals and workflows

Gate:

- Pro/direct-distribution donor only
- no Core/Mac App Store hot-path subprocesses
- no external CLI spawning in MAS target
- do not merge broad UI/visual systems before Core release gates

### Honest Handle / Single Binary Refactor Worktree

Likely path root:

- `/Users/jojo/Downloads/Epistemos/.claude/worktrees/agent-a0550f9c/`

Known purpose:

- Rust/FFI handle refactor
- single-binary style work

Gate:

- high-risk donor only
- benchmark and safety proof required before any FFI adoption
- no broad FFI replacement
- no unsafe pointer code without tests, layout assertions, and rollback

### Ambient / Halo Research

Path root:

- `/Users/jojo/Downloads/ambient/`

Important files:

- `/Users/jojo/Downloads/ambient/EPISTEMOS_V1_DECISION.md`
- `/Users/jojo/Downloads/ambient/HaloController.swift`
- `/Users/jojo/Downloads/ambient/epistemos_shadow.rs`
- `/Users/jojo/Downloads/ambient/claude ambient.md`
- `/Users/jojo/Downloads/ambient/gemini ambient.txt`

Role:

- Halo / Contextual Shadows donor research
- V1 magical first-impression source

Gate:

- implement only after Core substrate and performance gates
- no typing latency regression
- no MainActor embedding/search work
- no graph/search rebuild on every keystroke

### Hermes / CLI / Capability Tunnels Research

Path roots:

- `/Users/jojo/Downloads/final/`
- `/Users/jojo/Downloads/final v2/`
- `/Users/jojo/Downloads/final v3/`
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/20_canonical_research/hermes_research/`

Role:

- Pro capability-tunnel design
- Hermes integration strategy
- CLI / MCP / model-provider ideas

Gate:

- Pro-only until Core/MAS is stable
- no MAS user-installed CLI spawn
- no Docker/devcontainer in Core
- no "Hermes is the app" framing
- Epistemos substrate remains sovereign

### Advice / External Research Pack

Path root:

- `/Users/jojo/Downloads/Advice/`

Role:

- comparative LLM/product/research input
- useful for option analysis and risks

Gate:

- not direct code authority
- older sidecar/Tauri/Docker/private API assumptions are superseded
- any current API claim must be checked against primary sources

### Conversation Dumps / Pasted Research

Known local file:

- `/Users/jojo/Downloads/Pasted markdown.md`

Role:

- captures earlier user/GPT deliberation about Ambient Recall, Instant Recall, wiring gaps, performance blockers, agent runtime, computer-use, knowledge-core, and Quick Capture
- useful for preserving nuance that may not have made it into later summaries

Gate:

- donor research only
- every "exists", "done", "not wired", or file-specific claim must be rechecked against current repo code
- do not let older broad implementation ideas override the April 30 Core/Pro split

## Laptop Research Scan Protocol

Before any feature slice, the builder must search local research using targeted queries.

Required pattern:

```bash
cd /Users/jojo/Downloads/Epistemos
rg -n --hidden --glob '!build/**' --glob '!DerivedData/**' --glob '!test_results/**' "<feature keyword>" docs /Users/jojo/Downloads/final /Users/jojo/Downloads/'final v2' /Users/jojo/Downloads/'final v3' /Users/jojo/Downloads/ambient /Users/jojo/Downloads/Advice /Users/jojo/Downloads/Pasted\ markdown.md /Users/jojo/Downloads/Epistemos-laneA 2>/dev/null
```

For worktree code:

```bash
git worktree list
git status --short -uall
git log --oneline --decorate --graph --all --max-count=80
```

For branch/worktree comparison:

```bash
git diff --stat <base>..<worktree-branch>
git diff --name-status <base>..<worktree-branch>
```

## Core / MAS Gate

Allowed:

- public Apple APIs
- Swift/AppKit/TextKit/SwiftUI/Metal native surfaces
- local vault graph/search/recall
- Apple Foundation Models where available
- MLX/Core ML/local model paths when bundled or user-managed safely
- App Intents, Spotlight, menu bar capture, security-scoped file access

Blocked:

- private Apple APIs
- private ANE access
- downloaded code that changes app functionality
- user-installed coding CLI spawning
- Docker/devcontainer
- broad computer-use / screen control
- hidden cloud calls
- Pro-only tunnels reachable from MAS build

## Pro / Direct Gate

Allowed behind explicit Pro/direct flags:

- Hermes
- Claude Code / Codex / Kimi / Gemini CLI tunnels
- MCP server tunnels
- browser/computer-use
- Docker/devcontainer
- Simulation Theater
- Deep Deliberation / research jury

Still required:

- explicit user opt-in
- provenance logs
- capability policy
- no hot-path subprocesses
- no hidden data egress
- Core fallback unaffected

## Research-Only Gate

These remain research until explicitly reclassified:

- private ANE
- direct activation steering
- KV cache snapshot promises
- literal infinite neural context
- dynamic code loading in Core
- neural-kernel claims
- automatic graph explosion from every paragraph

## Conflict Resolution

If two sources disagree:

1. Current code behavior and passing tests/logs win.
2. Repo authority docs win over Downloads research.
3. April 30 fusion docs win over older research packs.
4. Core/MAS safety wins over Pro ambition.
5. A proven small patch wins over a broad rewrite.
6. Donor worktree code must be inventoried before reuse.

## Required Outputs Before Building

Before code changes, produce:

- `/Users/jojo/Downloads/Epistemos/docs/fusion/WORKTREE_INVENTORY_2026_04_30.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/RESEARCH_FUSION_NOTES_2026_04_30.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md`

Each implementation queue item must include:

- source cluster
- current code evidence
- files likely touched
- protected files
- Core/Pro/Both classification
- risk
- tests
- rollback
- acceptance criteria
