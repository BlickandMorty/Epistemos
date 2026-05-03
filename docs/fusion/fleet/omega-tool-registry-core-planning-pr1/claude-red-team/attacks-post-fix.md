---
role: claude-red-team
slice: omega-tool-registry-core-planning-pr1
brief: docs/fusion/deliberation/omega_tool_registry_core_planning_pr1_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 3
p0_attacks: 0
p1_attacks: 1
p2_attacks: 1
p3_attacks: 1
verdict: brief-revise
usefulness: +1
usefulness_reason: Initial builtinCatalogJson visibility P1 was closed; a new P1 found the catalog source-of-truth swap.
---

## Attacks

### A1 — `builtinCatalogJson` silently replaces the Rust-authoritative catalog with a Swift-side view [P1]
**Surface:** `MCPBridge.swift` — `builtinCatalogJson(distribution:)`
**Attack:** The old implementation called `builtinToolsJson()`, whose doc-comment explicitly stated the catalog came from Rust as the source of truth. The patched implementation routed to `OmegaToolRegistry.catalogJson(distribution:)`, which was built from Swift-side `OmegaToolDefinition` values. The slice intent was visibility filtering, not a source-of-truth migration.
**Evidence:** The post-P1 diff replaced `builtinToolsJson()` with `OmegaToolRegistry.catalogJson(distribution:)` and rebuilt catalog entries from Swift structs.
**Mitigation proposed:** Keep `builtinCatalogJson(distribution:)` distribution-aware, but have `OmegaToolRegistry.catalogJson(distribution:)` deserialize the raw `builtinToolsJson()` output, filter by `ToolSurfacePolicy`, and reserialize the original Rust-shaped entries. Add a sync test proving Pro/Research catalog names match the visible raw Rust catalog.

### A2 — `catalogEntry.input_schema_json` double-encodes the schema as a JSON string; no structural test [P2]
**Surface:** `MCPBridge.swift` — `OmegaToolDefinition.catalogEntry`
**Attack:** The Swift-built catalog entry embedded `schemaJson` as `input_schema_json`, preserving a JSON string. If callers expected a structured JSON object, they could fail silently.
**Evidence:** `catalogEntry` wrote `"input_schema_json": schemaJson`; tests only checked names.
**Mitigation proposed:** Remove the Swift-built catalog entry path by filtering raw Rust JSON entries, or add a round-trip schema test.

### A3 — `builtinToolsJson()` is now dead code but not tombstoned [P3]
**Surface:** `MCPBridge.swift` — raw Rust catalog accessor
**Attack:** Removing the last caller would leave a confusing parallel catalog path.
**Evidence:** The post-P1 diff no longer called `builtinToolsJson()` from `builtinCatalogJson`.
**Mitigation proposed:** Preserve `builtinToolsJson()` as the raw source for filtered catalog output.

## Brief verdict
The initial P1 on unfiltered `builtinCatalogJson()` was fixed, but the replacement introduced a source-of-truth swap from Rust catalog JSON to a Swift mirror. Correct resolution is to filter the raw Rust JSON output and add a sync/shape test.

CLAUDE-RETURN: role=RED-TEAM | slice=omega-tool-registry-core-planning-pr1 | round=40 | artifact=docs/fusion/fleet/omega-tool-registry-core-planning-pr1/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=1
