# Master Research Index Authority Update - 2026-05-02

## Tier

Docs-only / All tiers. No runtime behavior, build settings, generated bindings,
provider routing, UI, Rust FFI, graph, or editor code changed.

## Trigger

The May 2 deep-scan produced
`docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`, a 62 KB concept-to-source map
compiled from 8 parallel worktree/research-root scans. The user asked to make
that file the final full backlog and research lookup authority for ongoing
build work.

## Decision

Promote `MASTER_RESEARCH_INDEX_2026_05_02.md` as the first lookup for any
feature, concept, mini-task, worktree, or research-root question. Its §22
operating rule is now the session rule: Ctrl-F the master index first, read the
canonical source it names, cross-reference only when needed, trust §0 Honest
Discoveries over older docs they correct, and verify against current code/logs.

Current code plus fresh logs still remain the highest authority. If the master
index reports a gap that a later patch has since closed, the later code/log
evidence wins for that exact implementation state.

## Files Updated

- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/ALL_DOCS_INDEX_2026_05_02.md`
- `docs/fusion/README_START_HERE_2026_04_30.md`
- `docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`
- `docs/fusion/CODEX_DELIBERATION_PROMPT_2026_05_02.md`
- `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md`
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`

## Honest Corrections Preserved

- Lane A is no longer described as "mostly merged"; N1 Prompt Tree work is
  treated as 601 unmerged donor commits.
- Hermes-parity's active donor prompt path is plain markdown; NousResearch
  ChatML/XML is documented as route-specific future/local-agent formatting, not
  an automatic rewrite mandate.
- Workcards and current-state build order now say to resolve concepts through
  the master index before assigning or implementing a slice.
- Stale staged addendum language for PromptTree was corrected to point at H1.

## Verification

- Documentation-only patch.
- Run `git diff --check` on this doc set before commit.
- The in-flight relay-channel AgentEvent PR13 red test remains separate and
  must not be staged with this docs-only update.
