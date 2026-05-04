# Recipe Cache Recovery Bridge - 2026-05-04

Track: T5 Hermes / T13 multi-agent tooling / performance.

This bridge promotes the `codex/post-audit-feature-work` recipe-cache branch
finding into fusion. The code is already present in current main; the recovery
work is wiring, visibility, and provenance, not a raw cherry-pick.

## Donor / Live Authority

Donor:

- branch `codex/post-audit-feature-work`
- commit `c217b266` (`Implement recipe_cache: SQLite-backed tool result caching for agent_core`)
- `agent_core/src/storage/recipe_cache.rs`

Current main evidence:

- `agent_core/src/storage/recipe_cache.rs` exists and is exported through
  `agent_core::storage::recipe_cache`.
- `agent_core/Cargo.toml` already has the required SQLite, SHA-256, and chrono
  dependencies through the broader runtime stack.

The current-main diff against the branch is formatting-only for
`recipe_cache.rs`; main's `Cargo.toml` has moved far beyond the donor branch.

## Contract

The recipe cache is a persistent cache for deterministic, read-only tool
results:

- key: `(tool_name, input_hash)`;
- input hash: SHA-256 over canonical JSON;
- value: output text, error flag, creation time, hit count;
- storage: SQLite with WAL and TTL/cap eviction;
- default TTL: 7 days;
- default cap: 10,000 entries;
- default path: `~/.epistemos/cache/recipe_cache.db`.

Side-effectful tools are uncacheable by default:

- `bash`;
- `write_file`;
- `delete_file`;
- `terminal`;
- `computer_use`.

## Recovery Placement

Status:

- The module and inline tests exist in main.
- The module is not yet visibly integrated into `ToolRegistry` execution or a
  user-facing provenance surface.

Next slices:

1. Add an explicit `ToolCachePolicy` so cacheability is declared by tool
   metadata, not string-name folklore.
2. Wire `RecipeCache` only around idempotent read/search tools after execution
   receipts exist.
3. Surface cache hits in tool provenance so users can tell cached output from
   fresh execution.
4. Store cache DB under the app container/App Group path for MAS builds rather
   than an unconstrained home-directory fallback.
5. Add source guards that side-effectful tools cannot opt into recipe caching.

## Non-Negotiables

- No cache around mutating tools.
- No cache hit may masquerade as fresh execution.
- No hidden cache for sensitive vault contents without an explicit retention
  policy.
- No use as a trust primitive; cached output is performance evidence, not
  provenance evidence.
- No MAS path outside the app container/App Group for production storage.
