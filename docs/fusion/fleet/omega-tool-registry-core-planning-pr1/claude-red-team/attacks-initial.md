---
role: claude-red-team
slice: omega-tool-registry-core-planning-pr1
brief: docs/fusion/deliberation/omega_tool_registry_core_planning_pr1_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 5
p0_attacks: 0
p1_attacks: 1
p2_attacks: 2
p3_attacks: 2
verdict: brief-revise
usefulness: +1
usefulness_reason: Planning-layer filter is correctly scoped; one unpatched sibling surface and two latent test regressions need resolution before merge.
---

## Attacks

### A1 — `builtinCatalogJson()` is an unfiltered sibling planning surface [P1]
**Surface:** `Epistemos/Omega/MCPBridge.swift:210` — `MCPBridge.builtinCatalogJson()`
**Attack:** The diff patches `OmegaToolRegistry.planningSchemas`, `planningSchemasJson`, and `planningPromptBlock`, but `MCPBridge.builtinCatalogJson()` is a distinct catalog-query surface on the `MCPBridge` class that is never touched. Any Core/App Store planner or MCP peer that calls `MCPBridge().builtinCatalogJson()` instead of the newly filtered `OmegaToolRegistry.planningSchemasJson(distribution:)` receives the full, unfiltered tool catalog. The brief's stated goal is "distribution-aware Omega planning schemas" — this surface is squarely in scope and was missed.
**Evidence:** `documentSymbol` confirms `builtinCatalogJson()` at line 210 under the `// Catalog Query` section; `findReferences` returns no references, meaning it is not yet wired anywhere, but the method is public API on a class that will grow callers. The diff has no hunk touching lines 206–213.
**Mitigation proposed:** Add a `builtinCatalogJson(distribution: ToolSurfacePolicy.Distribution = .currentBuild) -> String` overload that calls `OmegaToolRegistry.planningSchemasJson(distribution:)` or a dedicated `MCPBridge`-level catalog builder that respects the filter. Add a corresponding test asserting that `MCPBridge().builtinCatalogJson(distribution: .coreAppStore)` contains no terminal/automation/computer-use schema entries. Keep the no-arg default delegating to `.currentBuild` for backward compatibility.

### A2 — `dispatch()` execution layer is permanently distribution-blind [P2]
**Surface:** `Epistemos/Omega/MCPBridge.swift:237` — `MCPBridge.dispatch(_:)`
**Attack:** The planning filter is visibility-only. `dispatch(_:)` takes raw JSON-RPC and routes to any registered tool regardless of distribution. A Core/App Store session that receives a cached Pro tool name can invoke Pro-only tools without any gate. This is not a regression introduced by the diff, but the diff's approval creates an implicit promise that Core planning cannot reach Pro execution surfaces — a promise the execution layer does not honor.
**Evidence:** `dispatch(_:)` has no distribution parameter and no policy check in the signature. The brief's stop trigger covers prompt/schema visibility, but the complementary execution-side stop trigger is absent.
**Mitigation proposed:** Document explicitly in the brief that execution-layer policy enforcement is deferred to a separate slice. A follow-on slice should add a `ToolSurfacePolicy` check inside dispatch before routing to the tool handler.

### A3 — `omegaToolRegistrySeedsToolSchemas` test breaks latently for `.coreAppStore` [P2]
**Surface:** `EpistemosTests/OmegaToolSchemaGrammarTests.swift:156` — `omegaToolRegistrySeedsToolSchemas`
**Attack:** The existing test asserts `schemas.count == runtime.toolCount`, where `runtime.toolCount` is the count of all tools registered in the MCP dispatcher. After this diff, `planningSchemas` delegates to `surfacedTools(.currentBuild)`. In a Core/App Store build where `.currentBuild` resolves to the Core tier, `planningSchemas.count` will be smaller than `runtime.toolCount`, causing the assertion to fail.
**Evidence:** `omegaToolRegistrySeedsToolSchemas` remains unchanged in the first diff, while `MCPBridge.toolCount` counts full dispatcher registration, not a filtered subset.
**Mitigation proposed:** Update the test to use an explicit Pro/Research distribution for the full-catalog assertion or compare each distribution against `OmegaToolRegistry.surfacedTools(distribution:)`.

### A4 — `static let planningSchemasJson` demoted to `static var` introduces per-call serialization [P3]
**Surface:** `Epistemos/Omega/MCPBridge.swift:119` — `planningSchemasJson` property
**Attack:** The original implementation was a `static let` evaluated once at launch. The diff replaces it with a `static var` that serializes the planning schema array on every access. Any hot path reading this value repeatedly now pays repeated serialization cost.
**Evidence:** Diff hunk changes `static let planningSchemasJson` to `static var planningSchemasJson`.
**Mitigation proposed:** Add bounded memoization keyed by distribution or accept this as a non-hot planning-path cost and keep it under a future performance audit.

### A5 — New tests use brittle magic strings for agent group names [P3]
**Surface:** `EpistemosTests/OmegaToolSchemaGrammarTests.swift:184–195` — `omegaCoreAppStorePlanningPromptHidesProAgentGroups`
**Attack:** The test asserts agent header strings directly. If the header wording changes, the test protects less than intended.
**Evidence:** The first diff includes `#expect(block.contains("FILE agent"))` and `#expect(!block.contains("TERMINAL agent"))`.
**Mitigation proposed:** Assert concrete bullet/tool lines instead of UI-ish header strings, or expose canonical header constants for tests.

## Brief verdict
The diff correctly scopes itself to planning visibility — runtime dispatch, MCP registration, Rust crate, and protected editor files are all untouched. The two new tests pass and correctly assert the Core/App Store tier hides terminal, automation, and computer-use tool names from planning schemas and the planning prompt block. The P1 (`builtinCatalogJson()` unfiltered) is the sole blocking issue: the brief explicitly targets all Omega planning surfaces, and this public catalog-query method on `MCPBridge` is a planning surface that was left unpatched. Patch `builtinCatalogJson()`, add its test, fix the count-assertion test, then re-submit for green-team.

CLAUDE-RETURN: role=RED-TEAM | slice=omega-tool-registry-core-planning-pr1 | round=40 | artifact=docs/fusion/fleet/omega-tool-registry-core-planning-pr1/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=1
