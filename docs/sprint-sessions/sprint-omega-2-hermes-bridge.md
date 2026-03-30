# Sprint Omega-2: Hermes Subprocess Bridge
## Duration: 1-2 sessions | Priority: HIGH — enables cloud orchestration

---

## What This Sprint Does

Adds the Swift subprocess infrastructure for launching, communicating with, and monitoring the hermes-agent Python process. Communication uses newline-delimited JSON-RPC over stdio, matching the Rust transport layer from Sprint Omega-1.

## Prerequisites

- Sprint Omega-1 complete (prompt caching, think tool, compaction, security, MCP transport)
- `hermes-agent/` directory present with `run_agent.py`
- Python3 available on PATH

---

## Tasks (execute in order)

### Task 1: HermesSubprocessManager.swift

**Create:** `Epistemos/Agent/HermesSubprocessManager.swift`

Manages the hermes-agent Python process lifecycle. Uses Foundation `Process` (project is Swift 6.0).

**Implementation requirements:**
- `HermesConfig` struct: pythonPath, hermesAgentPath, environment, model, maxTurns
- `HermesSubprocessManager` @Observable class with `ProcessState` enum (idle/starting/running/crashed/stopped)
- `launch()` async throws — spawns Process with stdin/stdout/stderr pipes
- `terminate()` — graceful SIGTERM then SIGKILL after timeout
- `restart()` async throws — terminate + launch
- Stderr drain to buffer (capped at 8KB)
- Termination handler updates state on main actor
- Process group management via `processGroupIdentifier`

**Verify:**
```bash
[ -f Epistemos/Agent/HermesSubprocessManager.swift ] && echo "OK" || echo "MISSING"
grep -c "class HermesSubprocessManager" Epistemos/Agent/HermesSubprocessManager.swift
grep -c "func launch\|func terminate\|ProcessState" Epistemos/Agent/HermesSubprocessManager.swift
```

### Task 2: HermesMCPClient.swift

**Create:** `Epistemos/Agent/HermesMCPClient.swift`

MCP stdio client that sends JSON-RPC requests to the Hermes subprocess and receives responses.

**Implementation requirements:**
- `HermesMCPClient` class wrapping subprocess stdin/stdout
- `send(method:params:)` async throws -> JSON response
- Request ID generation and response correlation
- Timeout handling per request
- Background reader task dispatching responses to continuations
- Thread-safe pending request map

**Verify:**
```bash
[ -f Epistemos/Agent/HermesMCPClient.swift ] && echo "OK" || echo "MISSING"
grep -c "class HermesMCPClient\|func send" Epistemos/Agent/HermesMCPClient.swift
```

### Task 3: EpistemosMCPServer.swift

**Create:** `Epistemos/Agent/EpistemosMCPServer.swift`

MCP stdio server that receives JSON-RPC requests from Hermes and dispatches to local macOS tools.

**Implementation requirements:**
- `EpistemosMCPServer` class reading incoming requests from subprocess stdout
- Route to registered tool handlers
- Send responses back on subprocess stdin
- Built-in handlers: tools/list, tools/call, ping
- Thread-safe handler registration

**Verify:**
```bash
[ -f Epistemos/Agent/EpistemosMCPServer.swift ] && echo "OK" || echo "MISSING"
grep -c "class EpistemosMCPServer\|func handleRequest" Epistemos/Agent/EpistemosMCPServer.swift
```

### Task 4: Pipe-based watchdog heartbeat + process group management

**Add to HermesSubprocessManager:**
- `startWatchdog(interval:timeout:)` — periodic MCP ping, kill+restart on timeout
- Process group management: set `process.processGroupIdentifier` for clean group kill
- `terminateProcessGroup()` — SIGTERM to process group

**Verify:**
```bash
grep -c "watchdog\|heartbeat\|processGroup" Epistemos/Agent/HermesSubprocessManager.swift
```

### Task 5: Integration with AppBootstrap lifecycle

**Modify:** `Epistemos/App/AppBootstrap.swift`
- Add `hermesManager: HermesSubprocessManager` property
- Initialize in `init()` after mcpBridge

**Modify:** `Epistemos/App/EpistemosApp.swift` (teardown)
- Call `hermesManager.terminate()` in `performTeardown()`

**Verify:**
```bash
grep -c "hermesManager\|HermesSubprocessManager" Epistemos/App/AppBootstrap.swift
```

### Task 6: Hermes health check on launch

**Add to HermesSubprocessManager:**
- `static func healthCheck() -> HealthResult` — verifies Python3 + hermes-agent importability
- Called during AppBootstrap to surface availability in UI

**Verify:**
```bash
grep -c "healthCheck\|HealthResult" Epistemos/Agent/HermesSubprocessManager.swift
```

### Task 7: Full compilation + test sweep

Run full verify and ensure no regressions.

```bash
./scripts/verify/omega_verify.sh --recursive
```
