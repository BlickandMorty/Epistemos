# ADOPT vs IP-LAYER MAP (2026-06-21) — FIRST PASS (monitor-synthesized; deep sub-agent pass pending API recovery)

The sub-agent research 529'd 3× (server overload). This is a grounded FIRST-PASS synthesized from the
committed research (AGENT_STACK_CONVERGENCE + OPENCODE_VS_GOOSE_WORK_ENGINE) + CLAUDE.md's FILE MAP. Treat as
PROVISIONAL — a deeper cited pass should regenerate this when the API recovers (esp. the "anything-else" repo
sweep + license/MAS detail). Classification: ADOPT (public repo solves it) / IP-LAYER (owner differentiator) /
HYBRID (adopt engine, layer IP).

| Capability | Class | Best public source / note | Owner-IP part |
|---|---|---|---|
| Act agent engine | ADOPT | Osaurus (vendored, linked) | brain on top |
| Work agent engine | ADOPT | OpenCode (Arch C) | brain on top via MCP |
| Model serving (OpenAI-compat) | ADOPT | Osaurus LocalModelServer (in-proc loopback) | — |
| Tool-calling + MCP + plugins | ADOPT | Osaurus MCP/plugins; OpenCode | tool-tier/skills wiring |
| Code-exec sandbox | ADOPT | Osaurus Containerization VM (Pro); WASM/cloud substitute (MAS) | — |
| In-process LSP (code intel) | IP/EXISTING | YOUR `agent_core::lsp_runtime` (tree-sitter) — reuse, do NOT import OpenCode's | yours |
| Lexical+vector search | HYBRID | tantivy + usearch (ADOPT libs) | YOUR RRF fusion + Halo/Shadow wiring |
| Embeddings / clustering | HYBRID | embedding models/libs (ADOPT) | YOUR SemanticClusterService |
| Prose editor (native, 120fps) | IP-LAYER | — (hand-tuned TextKit) | YOURS — protected, no-regress |
| Epdoc rich editor | HYBRID | Tiptap (ADOPT, JS) | YOUR MD-V2 md-first architecture |
| Knowledge graph + Metal render | IP-LAYER | — | YOURS (graph + Metal shaders) |
| Recall/Eidos + compressed retrieval | IP-LAYER | — | YOUR TurboVec/Eidos IP |
| Provenance ledger + cognitive DAG | IP-LAYER | — | YOUR BRAIN — core IP |
| Honesty gating / prompts / routing | IP-LAYER | — | YOUR BRAIN — core IP |
| MLX inference | ADOPT | mlx-swift / vmlx-swift | — |
| Model mgmt (QAT ladder, picks) | IP-LAYER | (MLX libs adopt) | YOUR QAT ladder + Epistemos Picks + per-model |
| Compaction / context budgeting | ADOPT | Osaurus ContextBudgetManager/CompactionWatermark | your compaction IP if better |
| Computer-use / AX | HYBRID | AXorcist (ADOPT) | YOUR DeviceAgentService/VisualVerify |
| UI / design / motion language | IP-LAYER | — | YOURS — the soul |

## C CROSS-CHECK (the owner's gate before finalizing)
Architecture C = OpenCode work engine + Goose UNIQUE-bits as clean-room Rust tools (NOT a 2nd engine). Map verdict:
- **OpenCode = work engine → ADOPT. CONFIRMED** (no duplication; one engine).
- **Goose "unique bits":** RetryManager / RepetitionGuard / recipes = genuine agent-HARDENING value, NOT pure
  commodity → KEEP as clean-room work-loop tools (justified). **`permissions` MAY overlap OpenCode's own
  permissioning → VERIFY; drop the Goose one if OpenCode already covers it** (dedup). This is the ONE refinement
  the deep pass should confirm.
- **LSP = your existing `lsp_runtime`** (do not import OpenCode's) — CONFIRMED.
→ **C HOLDS.** Only open dedup check: Goose-permissions vs OpenCode-permissions.

## PLAN ADDITIONS (paste-ready)
- Standing: classify each capability ADOPT/IP-LAYER/HYBRID before building; never hand-build an ADOPT capability.
- Protected IP-LAYER (never commoditized): brain (Eidos/cognitive-DAG/provenance/honesty/prompts), Prose 120fps,
  MD-V2, graph+Metal, model lab (QAT/Epistemos-Picks/per-model), UI/motion.
- Work: OpenCode engine; verify Goose-permissions overlap before keeping that one tool.
- DEEP-PASS TODO (API recovery): full cited repo sweep + "anything-else"/Talaria + license/MAS per capability.
