# OpenChamber Deep Audit

Cycle: ProShell subprocess env hardening, 2026-07-05

Status: in progress. This document records the OpenChamber audit slice used for the current build cycle. It does not claim the full forever-loop running-app DoD; screenshot/runtime proof remains pending behind the active external `xcodebuild`.

## Boundary

Touched paths for this cycle are constrained to `Epistemos/ProAgent/**`, `EpistemosTests/**`, `.claude/skills/**`, and this audit artifact. Protected areas remain read-only: vault/sync/graph/notes/editor surfaces, MAS June, Experimental, shared engine/FFI/Rust core, security/entitlements, generated Xcode project files, and build scripts.

## Seven-Layer OpenChamber Audit

1. Supervision lifecycle: CONNECTED. `ProAgentRuntimeSupervisor.shared` keeps the runtime app-scoped, with explicit `idle/starting/running/failed/stopped` states and separate child references for web, opencode, and goosed (`Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:70`, `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:77`, `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:116`). The startup path waits for the web health endpoint to prove both server and opencode readiness before surfacing `.running` (`Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:468`, `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:474`, `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:677`).
2. Child and zombie reaping: CONNECTED. A crash-durable ledger records pid plus kernel start time and usec, then the next launch sweeps only matching stale children with TERM then KILL (`Epistemos/ProAgent/ProAgentChildLedger.swift:5`, `Epistemos/ProAgent/ProAgentChildLedger.swift:47`, `Epistemos/ProAgent/ProAgentChildLedger.swift:110`). The supervisor calls the sweep before spawning new children (`Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:265`).
3. Script-message bridge: CONNECTED. The desktop bridge validates the message body, whitelists commands, caps notification strings, and routes read-aloud to the shared native synthesizer rather than webview audio code (`Epistemos/ProAgent/ProAgentSurfaceView.swift:57`, `Epistemos/ProAgent/ProAgentSurfaceView.swift:81`, `Epistemos/ProAgent/ProAgentSurfaceView.swift:92`, `Epistemos/ProAgent/ProAgentSurfaceView.swift:128`).
4. Theme fidelity: CONNECTED. The theme bridge maps Epistemos resolved tokens into OpenChamber CSS variables, pins dark/light classes, and re-applies after donor theme mutations (`Epistemos/ProAgent/ProAgentThemeBridge.swift:5`, `Epistemos/ProAgent/ProAgentThemeBridge.swift:38`, `Epistemos/ProAgent/ProAgentThemeBridge.swift:119`, `Epistemos/ProAgent/ProAgentThemeBridge.swift:159`).
5. MCP vault-fusion handoff: CONNECTED WITH BOUNDARY WATCH. The supervisor writes the merge-preserving fusion config only when an app vault and bundled MCP server exist, then passes the same `OPENCODE_CONFIG` and vault root to the opencode child and OpenChamber web server (`Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:303`, `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:312`, `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:318`, `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:379`). This calls Work public APIs and does not edit vault/sync/core code.
6. Provider-key flow: CONNECTED AFTER THIS CYCLE. Provider keys are read from Keychain off-main with a 4s timeout, only bridged to opencode, and omitted on timeout rather than wedging startup (`Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:280`, `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:287`, `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:301`). This cycle closed the remaining child-env gap by bounding inherited values, rejecting NUL bytes, requiring absolute path-like values, capping/deduping PATH, and preserving only deliberate binary/canonical/user tool directories (`Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:90`, `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift:726`, `Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift:5`, `Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift:19`, `Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift:50`, `Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift:78`).
7. Instant-open and blank-screen recovery: CONNECTED. The surface creates an eager non-persistent `WebPage`, keeps children alive across tab switches, loads once per connection, probes React readiness, captures page errors, and bounds reload/runtime retry storms (`Epistemos/ProAgent/ProAgentSurfaceView.swift:133`, `Epistemos/ProAgent/ProAgentSurfaceView.swift:323`, `Epistemos/ProAgent/ProAgentSurfaceView.swift:444`, `Epistemos/ProAgent/ProAgentSurfaceView.swift:480`, `Epistemos/ProAgent/ProAgentSurfaceView.swift:521`).

## Confirmed Finding Fixed

- HIGH-ENV-1: ProAgent inherited allowlisted environment values and PATH entries without the Goose-level bounds, NUL rejection, or absolute-path gate. Impact: a hostile or corrupted launch environment could pass oversized, invalid, or current-directory-dependent values into OpenChamber child processes, and PATH could grow or duplicate beyond intended bounds. Fix: ported bounded env/PATH helpers into `ProAgentRuntimeSupervisor.childEnvironment` and `withUserToolPath`, with direct regression coverage in `EpistemosTests/ProAgentRuntimeSupervisorTests.swift`.

## Remaining Open Items

- Runtime proof: focused tests and running-app screenshots are pending until the active external `xcodebuild` clears.
- Broader OpenChamber parity: goosed route behavior, all-chats live fetch, provider auth happy path, and web-render screenshots still need a running Pro build proof in a later continuation.
- Shared app shell: separate audit remains required before claiming the full two-domain Phase A complete.
