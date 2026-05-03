## Red-Team Report — `command-center-tool-surface-policy-pr1` · Round 42

### Attack Surface Reviewed

| Vector | Status |
|---|---|
| `ToolSurfacePolicy.surfacedTools` bypass via loader passthrough | **CLOSED** — `rebuildToolCatalog` wraps every loader call; `defaultToolCatalogLoader` ignores distribution (correct, filter is downstream) |
| `mcpToolsByAgent` built from unfiltered loader output | **CLOSED** — `tools` local is the post-`surfacedTools` value; `coreAppStoreRefreshToolCatalogFiltersInjectedExternalTools` asserts `rust == [vault_search]` |
| Double-filter regression | **CLOSED** — single fan-in confirmed; `surfacedTools` is the only policy gate |
| Toggle-orphan after filter (`run_command`/`get_ui_tree`/`click` toggled ON, then blocked) | **CLOSED** — `availableTools` and `enabledToolNames` both equal `["vault_search"]` post-filter; orphan toggles not carried into `buildCommandRequest` |
| `@Terminal` mention injected via raw input parser | **CLOSED** — bypass tested; parser rejects tokens not in `contextProviders` |
| `isBuiltInAgentContextProviderVisible` — Core/App Store path | **CORRECT** — `safari`, `terminal`, `automation` all fall through to `default: return false`; `notes` and `file` are the only passthrough IDs |
| `toolSurfaceDistribution` mutability window | **CLOSED** — stored as `private let`; no post-init reassignment path exists |
| `@MainActor` concurrency on `toolSurfaceDistribution` read | **CLEAN** — entire class is `@MainActor`; `@ObservationIgnored private let` is safe |
| `buildCommandRequest` bypasses surface policy | **CLEAN** — `enabledToolNames` is derived from `toolToggles`, which is rebuilt from filtered `availableTools` on every `rebuildToolCatalog` call |
| `proResearch` keeps gateway tools | **CLEAN** — test present, 42/42 green |

---

### Observations Below P1 Threshold

**`isBuiltInAgentContextProviderVisible` direct unit test not shown in the "relevant tests" slice.** The `@Terminal` parser-bypass test provides indirect regression coverage (if `terminal` became visible in Core/App Store, the parser would admit the token and the bypass test would catch it). However, a `coreAppStoreContextProvidersExcludeShellAgents` test asserting `contextProviders` does not contain `safari`/`terminal`/`automation` agent IDs would be belt-and-suspenders. Given the 42-test green log and the parser-layer backstop, this does not rise to P1.

**`proResearchRefreshToolCatalogKeepsInjectedGatewayTools` assertion truncated in the diff.** Presentation artifact only; test suite is green.

---

### Verdict

**brief-approved** — no remaining P0 or P1 blockers. The single policy fan-in (`rebuildToolCatalog` → `ToolSurfacePolicy.surfacedTools`), the immutable injected distribution, and the three-layer defense (loader filter → toggle rebuild → parser rejection) form a coherent, test-backed boundary. Core/App Store bounded-execution canon is enforced at every observable surface.

---

```
CLAUDE-RETURN: role=RED-TEAM | slice=command-center-tool-surface-policy-pr1 | round=42 | artifact=docs/fusion/fleet/command-center-tool-surface-policy-pr1/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=0
```
