# Red-Team Report — command-center-tool-surface-policy-pr1 · Round 42

**Scope:** Round 42 diff only — `AgentCommandCenterState.swift` + four test anchors.
**Canon:** MASTER_RESEARCH_INDEX §12 (Core = bounded, no shell/Docker/CLI/iMessage/background) + §6 (Hermes/Omega gateway tools = Pro/Research only).
**Prior rounds assumed closed:** R41 Omega JSON-RPC gating, `ToolSurfacePolicy.surfacedTools`.

---

## P0 — Critical Blockers

### P0-1 · `mcpToolsByAgent` surface not visible in diff — potential unfiltered MCP tool exposure

The PR description states the patch "filters both loaded availableTools/toolToggles/**mcpToolsByAgent**" but the diff contains no modification to `rebuildMCPToolCatalog()` or any write path to `mcpToolsByAgent`. Only `rebuildToolCatalog()` (the built-in Omega tool catalog) is shown being filtered.

**Attack vector:** Core build opens Command Center → switches to the MCP tools panel → arbitrary MCP server tools (`run_command`, `bash`, any gateway MCP) appear unfiltered because `mcpToolsByAgent` bypasses `surfacedTools()`.

**Risk:** Full policy bypass via MCP panel on a Core/App Store build. If `rebuildMCPToolCatalog()` exists and is not shown, this is P0 until confirmed patched. If MCP tools are dynamically populated from a separate code path (e.g., `MCPBridge.discoveredTools`), the filter must be applied at that fan-in point, not just in the built-in loader.

**Required evidence to close:** Show the `mcpToolsByAgent` write site (or `rebuildMCPToolCatalog`) also passes through `surfacedTools(distribution:)`.

---

### P0-2 · Double application of `surfacedTools()` on the default loader path — idempotency assumption unverified

`defaultToolCatalogLoader` now calls `ToolSurfacePolicy.surfacedTools(…, distribution:)` internally. `rebuildToolCatalog()` also wraps the loader's return value in a second `surfacedTools(…, distribution:)` call.

```swift
// rebuildToolCatalog:
let tools = ToolSurfacePolicy.surfacedTools(
    toolCatalogLoader(…),          // defaultToolCatalogLoader already calls surfacedTools
    distribution: toolSurfaceDistribution
)
```

This is only safe if `surfacedTools` is **pure and idempotent**. If the implementation accumulates metrics, mutates shared state, or has any non-idempotent side effect on the tool list (e.g., de-duplicating by index, appending sentinel entries, or emitting audit log events that gate downstream decisions), the double call produces either incorrect tool sets or inflated audit counts.

The custom-loader injection path (tests, future callers) does NOT double-filter — it sees one `surfacedTools` call in `rebuildToolCatalog`. The default path sees two. This asymmetry means the policy invariant is not uniformly enforced across loader implementations, which is a structural correctness gap even if today's `surfacedTools` happens to be idempotent.

**Required fix:** Remove the inner `surfacedTools` call from `defaultToolCatalogLoader`; enforce the filter exclusively at the `rebuildToolCatalog` fan-in. One call-site, one policy application.

---

## P1 — High-Severity Gaps

### P1-1 · Context provider token bypass via direct text input

`isBuiltInAgentContextProviderVisible` gates whether the UI picker **shows** `@Safari`, `@Terminal`, `@Automation`. It does not validate tokens already present in the input buffer. A user (or a compromised agent producing tool-calls that inject text into the input bar) can type `@Safari` manually — or paste a pre-formed prompt referencing `@Terminal` — and the downstream context resolution code may honour the token if it only checks for provider existence in the stored catalog rather than against the surface policy at resolution time.

**Attack path:** Core build → user or agent writes `@Terminal summarize /etc/passwd` → if `contextProviders` lookup falls back to a raw-string match rather than the filtered list, Terminal context resolves despite being hidden.

**Required fix:** Surface-policy check must be enforced at the **context-provider resolution/expansion** site, not only at the UI population site.

---

### P1-2 · `resolvedDistribution` divergence between context-provider path and tool catalog path

`isBuiltInAgentContextProviderVisible` calls `ToolSurfacePolicy.resolvedDistribution(toolSurfaceDistribution)` and compares the result to `.coreAppStore`. `rebuildToolCatalog` calls `ToolSurfacePolicy.surfacedTools(_, distribution: toolSurfaceDistribution)` which presumably does its own internal resolution.

If `resolvedDistribution()` and the resolution logic inside `surfacedTools` are not guaranteed to be the same code path (e.g., one reads a compile-time flag, the other reads an environment variable at call time), the tool catalog and the context provider list can desynchronise. In a Core build where `resolvedDistribution` momentarily returns `.proResearch` (race, environment injection, unit-test leakage), `isBuiltInAgentContextProviderVisible` would expose Safari/Terminal in the picker while the tool catalog is correctly filtered — or vice versa.

**Required fix:** Both call-sites must use the same resolved distribution value, computed once per `refreshCatalogs()` invocation and passed through rather than re-resolved independently.

---

### P1-3 · Specialist configuration reapplication can bypass surface filter ordering

`isApplyingSpecialistConfiguration` is set during specialist preset application. If `applySpecialistConfiguration()` writes directly to `availableTools` or `toolToggles` before `rebuildToolCatalog()` re-filters, a specialist preset that encodes a gateway tool name (e.g., `run_command`) in its stored toggle state can temporarily enable a blocked tool between the preset write and the catalog rebuild.

**Attack path:** Craft a `UserDefaults`-persisted specialist preset with `toolToggles["run_command"] = true` → load it on a Core build → between preset application and the next `rebuildToolCatalog`, the toggle is live in memory.

**Required fix:** Verify that any specialist preset application path ends with a guarded `rebuildToolCatalog()` that re-applies the surface filter and strips orphaned toggles before any observer sees the updated state.

---

### P1-4 · `previousToggles` leaks Pro-tool enabled state across distribution boundary

`rebuildToolCatalog` preserves `previousToggles` by key when rebuilding:

```swift
let previousToggles = toolToggles
availableTools = tools
toolToggles = Dictionary(…)  // merges previousToggles
```

If a tool is toggled ON in Pro mode and the build later resolves as Core (e.g., `toolSurfaceDistribution` injected differently, or the `UserDefaults` persisted the toggle from a Pro session), `previousToggles["run_command"] = true` survives into the rebuilt Core `toolToggles`. Even though `availableTools` is filtered and the tool is absent from the catalog, the toggle entry is live in `toolToggles` — and any observer that reads `toolToggles` directly (e.g., serialisation, specialist save) will persist the enabled state and potentially resurface it.

**Required fix:** After filtering `availableTools`, strip `toolToggles` to only keys present in the filtered `availableTools` set, discarding any orphaned Pro-tool keys unconditionally.

---

## Observations (Non-blocking)

- **`toolCatalogLoader` arity change** (`distribution` parameter added) is source-compatible for callers that used trailing-closure syntax but may silently break any stored closures not yet updated. Tests confirm the new signature works; confirm no other production call-site passes the old 2-arg closure.
- The four new tests cover Core-catalog filtering and Pro-catalog preservation but do not test the **toggle persistence** case from P1-4 or the **specialist-preset reapplication** ordering from P1-3. Adding those would close the gap without requiring new production changes.

---

## Verdict

| Severity | Count | Status |
|---|---|---|
| P0 | 2 | BLOCK — do not merge |
| P1 | 4 | Fix before merge or accept with tracking ticket |

P0-1 (MCP panel unfiltered) and P0-2 (double-filter asymmetry) must be resolved before this slice lands. P1s are all fixable in-slice without architecture changes.

---

**CLAUDE-RETURN:** role=RED-TEAM | slice=command-center-tool-surface-policy-pr1 | round=42 | artifact=docs/fusion/fleet/command-center-tool-surface-policy-pr1/claude-red-team/attacks.md | usefulness=+1 | p0=2 | p1=4
