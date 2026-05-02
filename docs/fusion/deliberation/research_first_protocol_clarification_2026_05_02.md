# Research-First Protocol Clarification - 2026-05-02

## User Instruction

The user's research corpus should be treated as the first source for every
concept and task, not only for large architecture work. Codex, Claude, Kimi, and
future builders should search local disk canon first, use semantic keyword
expansion, verify current code/logs, then do targeted web validation when local
docs lack a structured answer or current external facts matter.

## Canonical Entry Point

`docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` remains the first lookup. Its
§22 protocol now explicitly covers concepts, tasks, deliberations, build cards,
refactors, reroutes/reductions, bug fixes, dependency choices, deletions,
simplifications, and "simple" edits.

## Semantic Expansion Rule

Agents must search symbols and neighboring concepts, not only literal words. For
example, "zero-copy" expands to UMA, shared Metal buffers, IOSurface,
in-process, single-binary, no hot-path subprocess, no tensor copies,
deterministic/provenance-linked state transitions, direct/bare-metal execution,
and the Epistemos philosophy: "as complex as a brain, as simple as an app, as
fast as a jet."

## Web Validation Rule

Web search is a validation and unblock layer, not a replacement for local canon.
Use it when local docs do not answer or when the slice depends on current API,
OS, package, model, App Store, security, or framework behavior. Prefer primary
or official sources wherever possible.

## Files Updated

- `AGENTS.md`
- `CLAUDE.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/fusion/README_START_HERE_2026_04_30.md`
- `docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
