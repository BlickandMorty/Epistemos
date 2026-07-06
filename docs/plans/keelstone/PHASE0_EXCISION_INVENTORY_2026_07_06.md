# KEELSTONE Phase 0 Excision Inventory

Date: 2026-07-06

Scope: `OpenChamber`, `ProAgent`, `PRO_BUILD`, and `openchamber` references across production
sources, `project.yml`, scripts, and tests.

## Result

KEEP-LIST IS NOT EMPTY. Per PLAN_KEELSTONE_EPI-RP-07-KEELSTONE.md §6.1, do not prune
OpenChamber/ProAgent infrastructure until these references are removed, renamed, or replaced by
non-OpenChamber 1Code equivalents.

## Keep-list

These are referenced by non-OpenChamber code and are load-bearing in the current tree:

- `Epistemos/ExperimentalAgent/ExperimentalRuntimeSupervisor.swift`
  - Resolved in the current pass: no direct `ProAgentRuntimeSupervisor` or
    `ProAgentChildLedger` calls remain.
- `Epistemos/AgentSurface/AgentSurfaceRuntimeSupport.swift`
  - Neutral shared runtime support now owns shared Node resolution, port allocation,
    subprocess environment construction, provider-env bridging, and loopback URL formation.
  - Still resolves the shared Node binary from `openchamber-runtime/bin/node`; rename the
    staged resource before removing OpenChamber packaging.
- `Epistemos/AgentSurface/AgentSurfaceChildLedger.swift`
  - Neutral child ledger now owns record/forget/sweep behavior.
  - Intentionally preserves the legacy `pro-agent-children.json` filename so already-recorded
    child processes are still swept.
- `Epistemos/ProAgent/*`
  - Still compiled into the non-AppStore target via the synced `Epistemos` source folder.
  - Some old helper names now delegate to neutral `AgentSurface*` helpers, but the
    ProAgent/OpenChamber implementation files remain in the target until they are excluded
    or deleted.
- `EpistemosTests/ProAgentRuntimeSupervisorTests.swift`
  - Directly validates `ProAgentRuntimeSupervisor` process environment/path behavior.
- `EpistemosTests/WorkOpenCodeRuntimeTests.swift`
  - Reads `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift`.
  - Validates OpenChamber MCP/config environment wiring.
  - Uses `ProAgentThemeBridge.payloadJSON(for:)`.
- `build-openchamber-web.sh`
  - Produces `Epistemos/Resources/openchamber-runtime/...`.
  - Stages `openchamber-web.tar.gz`.
- `project.yml`
  - The main `Epistemos` prebuild chain still invokes `build-openchamber-web.sh`.

## Kill-list Candidates

These appear to be legacy third-surface identifiers or tests once the keep-list is replaced:

- `Epistemos/Views/Landing/LandingView.swift`
  - Resolved in the current pass: the flag-less `#else` branch no longer mounts
    `ProAgentSurfaceView`; routing is AppStore June vs Experimental.
- `Epistemos/Views/Settings/ProAgentHealthRow.swift`
  - No longer mounted by current settings, but still compiles while `Epistemos/ProAgent/*`
    remains in the target.
- `EpistemosTests/ProAgentChatListTests.swift`
  - Direct ProAgent chat-list tests.
- `EpistemosTests/ProAgentRuntimeSupervisorTests.swift`
  - Direct ProAgent runtime-supervisor tests.
- `EpistemosTests/PromptForgeTests.swift`
  - Fixture text still names OpenChamber.
- `EpistemosTests/WorkOpenCodeRuntimeTests.swift`
  - OpenChamber-specific assertions.
- `build-openchamber-web.sh`
  - Removable only after the Experimental runtime no longer depends on the staged shared runtime
    or web artifacts.

## Resolved in Current Pass

- `Epistemos/App/RootView.swift`
  - No longer mounts `ProAgentNavBar` for non-App-Store agent toolbar controls.
- `Epistemos/Views/Settings/SubstrateHealthPanel.swift`
  - No longer mounts `ProAgentHealthRow`.
  - No longer describes generation engines as living in OpenChamber/OpenGUI surfaces.
- `Epistemos/State/UIState.swift`
  - Agent-home comments no longer describe an OpenChamber surface.
- `Epistemos/ExperimentalAgent/ExperimentalRuntimeSupervisor.swift`
  - No longer calls `ProAgentRuntimeSupervisor` or `ProAgentChildLedger`; it uses
    neutral `AgentSurfaceRuntimeSupport` and `AgentSurfaceChildLedger`.
- `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift`
  - Shared statics for Node resolution, port allocation, env construction, provider-env
    bridging, loopback URL formation, and random secret generation now delegate to
    `AgentSurfaceRuntimeSupport`.
- `Epistemos/ProAgent/ProAgentChildLedger.swift`
  - Legacy ledger API now delegates to `AgentSurfaceChildLedger`.
- `Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift`
  - Legacy subprocess-env API now delegates to `AgentSurfaceSubprocessEnvironment`.

## Plan Mismatch

PLAN §6.1 says "You confirmed this code is dead." The live repo contradicts that: the
The initial live repo contradicted that: the Experimental surface directly depended on
ProAgent/OpenChamber infrastructure for runtime resolution, child-process ledgering,
environment construction, port allocation, diagnostics, and settings health. The current pass
has moved the shared runtime/ledger/env helpers behind neutral `AgentSurface*` names and removed
current surface mounts, but the ProAgent/OpenChamber implementation, tests, and packaging script
are still compiled or invoked. In §1 ledger terms, treating ProAgent as dead right now would still
remove source that participates in the build until target membership, tests, and packaging are
updated.

## Next Safe Step

Before any deletion:

1. Rename the shared Node resource path away from `openchamber-runtime` and update packaging.
2. Exclude or remove unmounted `Epistemos/ProAgent/*` sources from the Experimental target.
3. Update tests to validate the new two-surface names and behavior.
4. Re-run this inventory; only then remove `Epistemos/ProAgent/*`, `build-openchamber-web.sh`, and
   OpenChamber-specific tests/scripts.
