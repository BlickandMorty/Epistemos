# Hermes Parity Report — Discovery Phase

> **Index status**: CANONICAL-OPERATIONAL — Hermes parity report; companion to EPISTEMOS-HERMES-PARITY-PLAN.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



## Date: 2026-03-30

## 1. Implementation Map

### FULL parity (cloud/subprocess mode)
- Agent loop — delegated to Hermes subprocess via bridge
- Streaming (thinking/text/tool deltas) — bridge converts callbacks to JSON events
- Session persistence — Hermes SessionManager, JSONL files
- Memory — Hermes MemoryStore, frozen snapshot pattern
- Approvals/security — bridge emits permission_required, waits for response
- Cron management — bridge admin protocol, full CRUD
- MCP server management — bridge admin protocol, full CRUD
- Tools configuration — bridge admin protocol, list/toggle
- Config management — bridge admin protocol, get/set
- Session admin — list/resume/fork/new via bridge

### PARTIAL parity
- Skills management — list-only via bridge, no install/remove/configure yet
- Prompt building — full in subprocess, minimal in LocalAgent mode
- Update — check-only, no install (app updates via macOS app store)
- Version/health — version passed from bridge, no structured health check
- Diagnostics — no hermes doctor equivalent

### MISSING
- Local Hermes-compatible HTTP endpoint for agent-capable local models
- Smart model routing (cheap-model heuristics)
- Trajectory export (ShareGPT format)
- Gateway multi-channel delivery (not applicable for macOS app)
- hermes doctor diagnostics

### LocalAgent mode gaps (when using local models offline)
- No prompt caching
- No context compression
- No memory system
- No skills
- No approvals/security gates
- No session persistence
- No cron
- In-memory history only

## 2. Endpoint Reality Check

**Hermes already has a built-in API server**: `gateway/platforms/api_server.py`
- OpenAI-compatible `/v1/chat/completions` endpoint
- Default: localhost:8642
- Bearer token auth, CORS, SQLite response store
- Launched via `hermes --gateway`

**Current Epistemos integration**: stdio bridge only, no HTTP server

**Best local endpoint design**:
- Swift-owned lightweight HTTP server (NWListener or NIO) serving `/v1/chat/completions`
- Routes to existing MLX-Swift inference in-process
- Hermes configured with `base_url: http://localhost:<port>/v1`
- Keeps inference in-process per CLAUDE.md constraint ("NO SIDECAR for INFERENCE")

## 3. Routing Matrix (Current State)

| Model Type | Agent Mode | Panel | Status |
|---|---|---|---|
| Cloud (Claude/GPT/Gemini) | Yes — Hermes | AgentSessionPanel | CORRECT |
| Local canActAsAgent + thinking | Yes — local loop | AgentRuntimePanel | CORRECT (but no Hermes features) |
| Local canActAsAgent only | Yes — local loop | AgentRuntimePanel | CORRECT (but no Hermes features) |
| Local no canActAsAgent + thinking | No | fast + thinking | CORRECT |
| Local no canActAsAgent | No | fast only | CORRECT |
| Apple Intelligence | No | fast only | CORRECT |

## 4. Remaining Work Priority

1. **Extend bridge with doctor/diagnostics** — ~30 min
2. **Extend skills admin** (install/remove) — ~30 min
3. **Add session search to bridge** — ~20 min
4. **Track critical untracked files in git** — ~10 min
5. **Local HTTP endpoint for agent-capable models** — ~4-8 hours (separate project)
