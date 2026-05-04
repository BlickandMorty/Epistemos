# Sprint Agent-4: Multi-Provider + Polish

> **Index status**: SUPERSEDED-HISTORICAL — Older sprint plan superseded by MASTER_FUSION.md sprint plan §10.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).


## Duration: 1-2 sessions | Priority: HIGH — finish the provider surface without re-breaking the living loop

---

## Pre-Read (do this FIRST)

```bash
cat CLAUDE.md
cat docs/agent-system/AGENT_ARCHITECTURE.md
cat docs/agent-system/GAP_ANALYSIS.md
cat docs/PROGRESS.md
cat docs/AGENT_PROGRESS.md
sed -n '256,290p' docs/agent-system/AGENT_ARCHITECTURE.md
sed -n '1,240p' agent_core/src/provider.rs
sed -n '1,260p' agent_core/src/routing.rs
sed -n '1,320p' agent_core/src/bridge.rs
sed -n '1,320p' agent_core/src/providers/claude.rs
sed -n '1,240p' agent_core/src/prompts.rs
sed -n '1,260p' Epistemos/Bridge/StreamingDelegate.swift
sed -n '1,260p' Epistemos/ViewModels/AgentViewModel.swift
sed -n '1,260p' Epistemos/Views/OmegaPanel.swift
```

Also inspect the current provider surface before editing:

```bash
find agent_core/src/providers -maxdepth 2 -type f | sort
find agent_core/src -maxdepth 2 -type f | sort
```

After reading, confirm:
"Architecture read. Building Sprint Agent-4: Multi-Provider + Polish. First file: `agent_core/src/routing.rs`."

---

## Goals

This sprint is about making the provider layer real and coherent:

1. Route research to Perplexity, shell/tool-heavy execution to OpenAI, reasoning to Claude.
2. Move provider selection out of stringly-typed seams and into the real Rust router.
3. Keep MCP transport/provider integration on the provider side, not in the computer-use sprint.
4. Finish the user-visible polish that depends on the runtime already being honest.

---

## Tasks (execute in order)

### Task 1: Wire routing into the live Rust bridge
Read before editing:
- `agent_core/src/routing.rs`
- `agent_core/src/bridge.rs`
- `agent_core/src/provider.rs`

Requirements:
- stop selecting providers only by raw string when the router already knows better
- preserve explicit user/provider overrides where they already exist
- keep the bridge surface auditable: routed vs forced provider should be inspectable
- do not break the existing Claude path while wiring the router

### Task 2: Add `PerplexityProvider`
Target files:
- `agent_core/src/providers/perplexity.rs`
- `agent_core/src/lib.rs`
- `agent_core/src/provider.rs`

Requirements:
- implement the real HTTP request/response surface for research with citations
- keep the response model compatible with the living loop
- preserve bounded tool/result behavior
- if Perplexity cannot support the full Claude-style tool loop, keep the limitation explicit in code and docs

### Task 3: Add `OpenAIProvider`
Target files:
- `agent_core/src/providers/openai.rs`
- `agent_core/src/lib.rs`
- `agent_core/src/provider.rs`

Requirements:
- use the Responses API path described in the architecture docs
- keep the implementation native to this repo even if `rig-core` is used as a helper
- do not add nonexistent Swift SDK imports
- keep shell/code-execution routing explicit and testable

### Task 4: Defer or scaffold provider-side MCP transport honestly
Read before editing:
- `agent_core/src/providers/claude.rs`
- `docs/sprint-sessions/sprint-agent-3-mcp.md`
- `docs/AGENT_PROGRESS.md`

Requirements:
- stdio/HTTP MCP transport is no longer an Agent-3 task
- if transport is not implemented in this sprint, leave an honest scaffold and document the missing seam
- if transport is implemented, keep it provider-side with `mcp_servers` handling and no stdout-corrupting surprises

### Task 5: Finish context compaction polish
Read before editing:
- `agent_core/src/agent_loop.rs`
- `agent_core/src/session.rs`
- `agent_core/src/prompts.rs`

Requirements:
- keep compaction provider-owned
- make the threshold/summary behavior inspectable
- avoid giant tool blobs in history

### Task 6: Add user-facing polish only after runtime work is real
Suggested files:
- `Epistemos/Views/OmegaPanel.swift`
- `Epistemos/ViewModels/AgentViewModel.swift`
- related runtime-consumer seams already in app targets

Requirements:
- polish only after provider/routing surfaces are honest
- do not fake streaming or invent UI phases the runtime cannot emit
- keep changes minimal and tied to real runtime events

---

## Verification (run ALL after completing)

```bash
echo "=== Sprint Agent-4 Verification ==="

for f in \
  agent_core/src/routing.rs \
  agent_core/src/bridge.rs \
  agent_core/src/providers/claude.rs \
  agent_core/src/providers/perplexity.rs \
  agent_core/src/providers/openai.rs; do
  [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

echo "--- Routing checks ---"
printf 'router references: '
rg -c 'ConfidenceRouter|HeuristicClassifier|RoutingDecision' agent_core/src
printf 'provider routing in bridge: '
rg -c 'RoutingDecision|route\\(' agent_core/src/bridge.rs agent_core/src

echo "--- Provider checks ---"
printf 'Perplexity provider: '
rg -c 'Perplexity|sonar|citations' agent_core/src/providers
printf 'OpenAI provider: '
rg -c 'OpenAI|Responses API|responses' agent_core/src/providers
printf 'Claude mcp_servers support: '
rg -c 'mcp_servers' agent_core/src/providers/claude.rs

echo "--- Rust tests ---"
cargo test --manifest-path agent_core/Cargo.toml

echo "--- Swift build ---"
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build-for-testing
```

---

## After Completing

Update:
- `docs/PROGRESS.md`
- `docs/AGENT_PROGRESS.md`

If provider transport is still deferred, say so explicitly and keep the next step narrow.
