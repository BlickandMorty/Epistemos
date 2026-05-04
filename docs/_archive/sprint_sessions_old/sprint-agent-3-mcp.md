# Sprint Agent-3: MCP + Computer Use

> **Index status**: SUPERSEDED-HISTORICAL — Older sprint plan superseded by MASTER_FUSION.md sprint plan §10.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).


## Duration: 1-2 sessions | Priority: HIGH — make MCP real and make computer use native

---

## Pre-Read (do this FIRST)

```bash
cat CLAUDE.md
cat docs/agent-system/AGENT_ARCHITECTURE.md
cat docs/agent-system/GAP_ANALYSIS.md
cat docs/PROGRESS.md
sed -n '250,340p' docs/agent-system/AGENT_ARCHITECTURE.md
sed -n '1,260p' omega-mcp/src/dispatcher.rs
sed -n '1,260p' omega-mcp/src/registry.rs
sed -n '1,260p' omega-mcp/src/server.rs
sed -n '1,240p' omega-ax/src/lib.rs
sed -n '1,260p' omega-ax/src/ax_tree.rs
sed -n '1,260p' omega-ax/src/input.rs
sed -n '1,240p' Epistemos/Omega/MCPBridge.swift
sed -n '1,260p' Epistemos/Omega/Inference/DeviceAgentService.swift
sed -n '1,260p' Epistemos/Omega/Inference/DualBrainRouter.swift
sed -n '1,260p' Epistemos/Omega/Vision/Screen2AXFusion.swift
sed -n '1,240p' Epistemos/Omega/Vision/VisualVerifyLoop.swift
```

Also inspect the current directories before editing:

```bash
find omega-mcp/src -maxdepth 2 -type f | sort
find omega-ax/src -maxdepth 2 -type f | sort
find Epistemos/Omega -maxdepth 2 -type f | sort
```

After reading, confirm:
"Architecture read. Building Sprint Agent-3: MCP + Computer Use. First file: `omega-mcp/src/dispatcher.rs`."

---

## Goals

This sprint is not about making Omega look smarter.
It is about making the agent boundary more real:

1. Rust MCP should stop being validation theater and become the authoritative tool surface.
2. Swift computer use should stay native and fast: AX-first, screenshot fallback, verified actions.
3. The system should expose clean seams for future Claude `mcp_servers` and real remote connectors.
4. Logging and safety should stay auditable.

---

## Tasks (execute in order)

### Task 1: Audit and classify the existing MCP path
Read before editing:
- `omega-mcp/src/dispatcher.rs`
- `omega-mcp/src/registry.rs`
- `omega-mcp/src/server.rs`
- `Epistemos/Omega/MCPBridge.swift`

Requirements:
- document what is real today vs still Swift-side pending execution
- do not rewrite until the current boundary is explicit
- identify which parts are KEEP / MIGRATE / REPLACE

Output:
- add a short Sprint Agent-3 note to `docs/PROGRESS.md` before major edits

### Task 2: Make `omega-mcp` the authoritative execution/logging surface
Target files:
- `omega-mcp/src/dispatcher.rs`
- `omega-mcp/src/types.rs`
- `omega-mcp/src/logger.rs`
- `Epistemos/Omega/MCPBridge.swift`

Requirements:
- keep JSON-RPC compatibility for `tools/list` and `tools/call`
- preserve argument validation and safety metadata
- reduce Swift-side duplication where Rust already knows the tool contract
- keep execution logging inspectable and durable
- do not corrupt stdout transport assumptions if a stdio MCP path is introduced later

### Task 3: Add a vault-focused MCP surface plan
Read before editing:
- `omega-mcp/src/registry.rs`
- `Epistemos/Omega/Agents/NotesAgent.swift`
- `Epistemos/Sync/VaultSyncService.swift`

Requirements:
- define the first real vault MCP tool set:
  - `vault_search`
  - `vault_read`
  - `vault_write`
  - optional `vault_graph_query`
- prefer reusing existing vault/search code over inventing a parallel path
- if the full stdio server cannot be completed in this sprint, leave an honest scaffold and document the missing seam

### Task 4: Harden the AX-first computer-use path
Read before editing:
- `omega-ax/src/ax_tree.rs`
- `omega-ax/src/input.rs`
- `omega-ax/src/permissions.rs`
- `Epistemos/Omega/Vision/Screen2AXFusion.swift`
- `Epistemos/Omega/Vision/VisualVerifyLoop.swift`
- `Epistemos/Omega/Inference/DeviceAgentService.swift`

Requirements:
- keep AX queries as the primary grounding path
- keep screenshot/vision as fallback or verification, not the first move
- preserve post-action verification
- keep destructive or uncertain actions gateable
- do not introduce screenshot-only computer-use routing

### Task 5: Close the device-backend execution seam
Read before editing:
- `Epistemos/Omega/Inference/DeviceAgentService.swift`
- `Epistemos/Omega/Inference/DualBrainRouter.swift`
- `Epistemos/Omega/Vision/VisualVerifyLoop.swift`

Requirements:
- ensure Brain 2 execution is auditable
- keep the local-agent-backed structured resolver honest
- avoid duplicating tool/selector logic between DeviceAgentService and Swift callers
- if confidence is low, preserve the existing verification/escalation boundary

### Task 6: Add focused tests
Suggested files:
- `EpistemosTests/DeviceAgentServiceTests.swift`
- `EpistemosTests/VisualVerifyLoopTests.swift`
- `omega-mcp/tests/` or inline Rust tests
- `omega-ax/tests/` or inline Rust tests

Required coverage:
- MCP `tools/list`
- MCP `tools/call` validation and safety metadata
- execution log persistence or query path
- AX tree query path
- device action fallback behavior
- post-action verification path
- low-confidence / destructive action handling

---

## Verification (run ALL after completing)

```bash
echo "=== Sprint Agent-3 Verification ==="

for f in \
  omega-mcp/src/dispatcher.rs \
  omega-mcp/src/registry.rs \
  omega-ax/src/ax_tree.rs \
  omega-ax/src/input.rs \
  Epistemos/Omega/MCPBridge.swift \
  Epistemos/Omega/Inference/DeviceAgentService.swift \
  Epistemos/Omega/Vision/VisualVerifyLoop.swift; do
  [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

echo "--- MCP checks ---"
printf 'tools/list handlers: '
rg -c 'tools/list|TOOLS_LIST' omega-mcp/src
printf 'tools/call handlers: '
rg -c 'tools/call|TOOLS_CALL' omega-mcp/src
printf 'execution logging: '
rg -c 'log_execution|recent_executions|ExecutionRecord' omega-mcp/src Epistemos/Omega/MCPBridge.swift

echo "--- Computer-use checks ---"
printf 'AX-first path: '
rg -c 'AX|axTree|walkAxTree|resolveUIAction' omega-ax/src Epistemos/Omega
printf 'verification path: '
rg -c 'verify|VerifyResult|VisualVerifyLoop' Epistemos/Omega
printf 'screenshot fallback path: '
rg -c 'ScreenCapture|Screen2AX|screenshot' Epistemos/Omega

echo "--- Rust tests ---"
cargo test --manifest-path omega-mcp/Cargo.toml
cargo test --manifest-path omega-ax/Cargo.toml

echo "--- Swift build ---"
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build-for-testing
```

---

## After Completing

Update:
- `docs/PROGRESS.md`
- `docs/AGENT_PROGRESS.md`

Then proceed to Sprint Agent-4 in a fresh session.
