---
role: claude-red-team
slice: omega-tool-registry-core-planning-pr1
brief: docs/fusion/deliberation/omega_tool_registry_core_planning_pr1_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 3
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 1
verdict: brief-approved
usefulness: +1
usefulness_reason: Third pass closed all prior P1s; remaining items are non-blocking, and Codex addressed the cheap cross-source invariant before commit.
---

## Attacks

### A1 — `planningSchemas` and `catalogJson` filter from divergent sources; no cross-check test [P2]
**Surface:** `OmegaToolRegistry.planningSchemas(distribution:)` vs `OmegaToolRegistry.catalogJson(distribution:)`
**Attack:** `planningSchemas` filters the decoded Swift `OmegaToolDefinition` cache, while `catalogJson` filters raw Rust `builtinToolsJson()` output by name. If one source gains a tool before the other, schemas and catalog output could diverge.
**Evidence:** `planningSchemas(distribution:)` maps `surfacedTools(distribution:)`; `catalogJson(distribution:)` deserializes and filters `builtinToolsJson()`.
**Mitigation proposed:** Add a test asserting planning schema names are backed by catalog names for both Core and Pro/Research.
**Codex follow-up:** Addressed before commit with `Omega planning schemas stay backed by the visible catalog`.

### A2 — Execution layer remains distribution-blind [P2]
**Surface:** `MCPBridge.dispatch(_:)`
**Attack:** The planning filter is visibility-only. A Core/App Store session that receives a cached Pro tool name can still invoke Pro-only tools via `dispatch` because no distribution check exists there.
**Evidence:** `dispatch(_:)` has no distribution parameter and no policy check. This slice intentionally did not change runtime registration or execution.
**Mitigation proposed:** Track as a follow-on execution-gate slice; do not expand this planning-visibility patch.

### A3 — `planningSchemasJson` computed property serializes on every access [P3]
**Surface:** `OmegaToolRegistry.planningSchemasJson`
**Attack:** The old `static let` was evaluated once, while the new computed property serializes on each access.
**Evidence:** The property now delegates to `planningSchemasJson(distribution: .currentBuild)`.
**Mitigation proposed:** Memoize later if profiling shows planning-schema serialization on a hot path.

## Brief verdict
The third-pass diff resolves the prior blockers: `builtinCatalogJson(distribution:)` is distribution-aware, `OmegaToolRegistry.catalogJson(distribution:)` filters the raw Rust `builtinToolsJson()` output instead of a Swift mirror, Core planning schemas/prompt/catalog hide Pro gateway tools, and Pro/Research catalog names preserve the Rust-visible source. Runtime dispatch, MCP registration, Rust crate, and editor files are untouched. No P0/P1 attacks remain.

CLAUDE-RETURN: role=RED-TEAM | slice=omega-tool-registry-core-planning-pr1 | round=40 | artifact=docs/fusion/fleet/omega-tool-registry-core-planning-pr1/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=0
