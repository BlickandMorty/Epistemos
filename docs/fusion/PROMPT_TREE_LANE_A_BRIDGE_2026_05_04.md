# Prompt Tree Lane A Bridge - 2026-05-04

Track: T0 Schema-First GenUI / T5 Hermes / prompt-as-data substrate.

This bridge promotes the separate worktree
`/Users/jojo/Downloads/Epistemos-laneA` into the fusion map. It is not inside
`.claude/worktrees/`, but `git worktree list` shows it is an active repo
worktree on branch `lane-A`, currently 601 commits ahead of `main`.

## Donor / Live Authority

Donor:

- worktree `/Users/jojo/Downloads/Epistemos-laneA`
- branch `lane-A`
- head `12183f29` (`plan(tracker): mark N1 as shipped after b8d779ca + af0a0f21`)
- `docs/PROMPT_AS_DATA_SPEC.md`
- `docs/plan/prompts/N1_prompt_tree.md`

Current main evidence:

- `Epistemos/Engine/PromptTree.swift`
- `Epistemos/Engine/PromptRenderer.swift`
- `Epistemos/Engine/PromptCache.swift`
- `Epistemos/Engine/PromptTreePersister.swift`
- `Epistemos/State/PromptTreePreferences.swift`
- `Epistemos/Views/Cost/CostDashboardView.swift`
- `EpistemosTests/PromptTreeTests.swift`
- `agent_core/src/session_insights.rs`
- `docs/PROMPT_AS_DATA_SPEC.md`
- `docs/plan/prompts/N1_prompt_tree.md`

Main is not empty here; the gap is reconciliation. `git diff lane-A -- ...`
still shows meaningful deltas in `ChatCoordinator`, `agent_core::bridge`,
`providers::claude`, `session_insights`, and the prompt-as-data spec.

The Lane A worktree also has a dirty local edit in
`Epistemos/Views/Approval/ApprovalModalView.swift` for approval countdown-ring
anchoring. That edit is separate active WIP and must not be silently folded into
Prompt Tree recovery.

## Contract

N1 turns prompts into typed data:

- JSPF: a Codable/Sendable/Hashable `Prompt` with stable sections for identity,
  tools, memory, task, constraints, output schema, and cache hints.
- PTF: on-disk prompt tree files under
  `<vault>/.epistemos/prompts/<session>/<turn>/`.
- Provider renderers: Anthropic Messages, OpenAI-compatible responses, AFM
  generable shape, and local MLX grammar.
- Cache policy: up to four Anthropic cache-control breakpoints over stable
  subtrees; dynamic memory relocates to the user-message tail.
- Visibility: prompt-cache hit rate must surface as `cached_tokens_share` in
  the cost/spend UI before default-on cutover.

## Recovery Placement

Status:

- Foundation files exist in current main.
- `agent_core/src/session_insights.rs` is no longer orphaned in current main.
- The lane still contains reconciliation deltas around Rust provider telemetry,
  bridge fields, and ChatCoordinator transport shape.

Next slices:

1. Compare Lane A's `ChatCoordinator`, `agent_core/src/bridge.rs`,
   `agent_core/src/providers/claude.rs`, and `session_insights.rs` against
   current main before changing prompt execution.
2. Preserve both gates: explicit `EPISTEMOS_PROMPT_TREE=1` / Settings toggle
   while the measured cache-hit rate bakes; no default-on cutover without
   evidence.
3. Reconcile `cached_tokens_share` from Rust provider responses to the Swift
   cost/spend surface with a visible, non-placeholder UI row.
4. Keep prompt-as-data distinct from recipe-cache: Prompt Tree optimizes LLM
   prompt-prefix reuse; RecipeCache caches deterministic tool results.
5. Treat Lane A's dirty approval-countdown edit as a separate Approval Modal
   UX fix if it is later ported.

## Non-Negotiables

- No "mostly merged" claim without comparing Lane A deltas to current main.
- No prompt-cache success claim without visible cache-hit telemetry.
- No silent provider degradation; render targets stay closed and tested.
- No MAS path outside the vault/security-scoped container for PTF persistence.
- No raw worktree merge.
