# Epistemos Specialties: Abilities No Other App Can Have

> The tools every agent framework has are table stakes. These are the ones only YOU can build.
> Each Specialty combines Rust + Swift + Metal in ways that are architecturally impossible for
> plugin-based apps (Obsidian, Logseq) and server-based agents (Hermes, OpenClaw).

---

## Naming: "Specialties" vs Generic Tools

Regular tools do generic work any agent can do (read file, search web, send message).
**Specialties** are capabilities that exist ONLY because of Epistemos's unique engineering stack.

When the agent activates a Specialty, the UI should surface it differently — these are the
premium moves, the things users came to Epistemos for. Think of them like special abilities
in a game: any character can punch, but only yours can warp gravity.

---

## The 19 Specialties

### Category A: The Perception Stack (macOS-Only)

These require entitlement-gated macOS APIs + in-process native frameworks.
No Electron app, no plugin, no server-based agent can do these.

---

#### A1. `perceive` — Hybrid AX+Vision+VLM Perception
**Rust:** Swift bridge via FFI
**Swift:** `Screen2AXFusion.swift` + `AXorcistBridge.swift` + `ScreenCaptureService.swift`

**What the agent gets:** A structured JSON percept of ANY running macOS app — every button,
text field, menu item, with screen coordinates. Three-stage pipeline:
1. AX tree walk (~91% of apps covered, <50ms)
2. If sparse: enriched with Apple Vision OCR (<200ms)
3. If needed: full VLM screenshot analysis

**Why only Epistemos:** Requires `AXIsProcessTrusted()`, `ScreenCaptureKit` entitlement, and
Vision framework — three separate privileged APIs. Obsidian runs in a single window and can't
see outside it. OpenClaw uses Playwright (browser only). Hermes uses Playwright (browser only).

**Tool schema:**
```json
{
  "name": "perceive",
  "params": {
    "app_name": "string — target application (e.g., 'Safari', 'Finder', 'Xcode')",
    "depth": "enum(fast|enriched|full) — fast=AX only, enriched=AX+OCR, full=AX+OCR+VLM"
  },
  "returns": {
    "elements": [{ "role": "button", "label": "Save", "position": [420, 310], "ref": "e5" }],
    "screenshot_path": "optional — only if depth=full",
    "latency_ms": 47
  }
}
```

**Porting from competitors:** OpenClaw's `peekaboo` does screenshots + element maps but via a
separate Go binary over shell. Epistemos does it in-process with zero serialization overhead.
Hermes has no macOS automation at all.

---

#### A2. `interact` — Native App UI Manipulation
**Rust:** Swift bridge via FFI
**Swift:** `AXorcistBridge.swift` + `CGEvent` for input synthesis

**What the agent gets:** Click, type, scroll, drag in ANY macOS app by semantic element reference
(not pixel coordinates). Fuzzy matching: "the Save button" → finds it even if the label is "Save..."
or "Save As".

**Why only Epistemos:** AX action dispatch requires process-level accessibility trust. CGEvent
injection requires accessibility permission. Plugin apps are sandboxed.

**Tool schema:**
```json
{
  "name": "interact",
  "params": {
    "app_name": "string",
    "action": "enum(click|type|scroll|drag|press_key)",
    "target": "string — semantic element query ('the search field', '@e5' ref from perceive)",
    "value": "optional string — text for type action, key for press_key"
  },
  "returns": { "success": true, "element_found": "Save button", "action_performed": "click" }
}
```

**Porting:** This IS what OpenClaw's `peekaboo` does, but natively. Skip porting peekaboo —
your implementation is better.

---

#### A3. `screen_watch` — FSEvents + Visual Change Detection
**Rust:** `notify` crate for FSEvents + Swift bridge for ScreenCaptureKit
**Swift:** `VisualVerifyLoop.swift`

**What the agent gets:** Set a watch on a screen region or file path. Get notified when something
changes. The agent can "wait for the build to finish" by watching Xcode's status bar region,
or "wait for the file to appear" via FSEvents.

**Tool schema:**
```json
{
  "name": "screen_watch",
  "params": {
    "mode": "enum(visual_region|file_path|app_state)",
    "target": "string — screen rect [x,y,w,h] or file glob or app name",
    "condition": "string — 'changes' or 'contains:Build Succeeded' or 'exists'",
    "timeout_secs": 60
  },
  "returns": { "triggered": true, "reason": "Visual content changed in region", "elapsed_ms": 4200 }
}
```

**Neither Hermes nor OpenClaw have this.** They poll via terminal commands. You can watch natively.

---

### Category B: The Knowledge Stack (Vault-Native)

These require the in-process Tantivy + sqlite-vec + graph-engine + GRDB vault.
No external agent can access these without reimplementing the entire persistence layer.

---

#### B1. `vault_recall` — Sub-3ms Semantic Memory
**Rust:** `InstantRecallService` via `epistemos-core` UniFFI
**Swift:** `InstantRecallService.swift`

**What the agent gets:** Binary-quantized vector search across the entire vault in under 3ms.
Two-phase: coarse binary scan → fine reranking. Zero network calls.

**Why only Epistemos:** Obsidian's search is BM25 keyword matching in a JavaScript worker.
Hermes uses `session_search` with FTS5 (no vectors). OpenClaw has no vault concept.

**Tool schema:**
```json
{
  "name": "vault_recall",
  "params": {
    "query": "string",
    "top_k": 5,
    "note_filter": "optional — filter to specific folders or tags"
  },
  "returns": {
    "results": [{ "note_id": "...", "title": "...", "snippet": "...", "score": 0.87 }],
    "latency_ms": 2.1
  }
}
```

**Porting Hermes `session_search`:** Port the FTS5 keyword search as a fallback path alongside
the vector search. Hermes's AI-generated summaries via cheap model is a good idea — add that
as an optional `summarize: true` param.

---

#### B2. `graph_query` — Knowledge Graph Reasoning
**Rust:** `graph-engine/src/engine.rs`

**What the agent gets:** Query the live force-directed knowledge graph. Find related concepts,
shortest paths between ideas, community clusters, and "god nodes" (highest centrality concepts).
The graph has REAL physics — semantic attraction pulls related concepts closer.

**Why only Epistemos:** Obsidian's graph is a d3.js visualization. You can't query it from a
plugin. Your graph is a Rust engine with spatial indexing, embedding-weighted forces, community
detection, and a real query API.

**Tool schema:**
```json
{
  "name": "graph_query",
  "params": {
    "mode": "enum(related|path|communities|god_nodes|spatial)",
    "query": "string — concept name or node ID",
    "target": "optional string — for path mode, the destination node",
    "limit": 10
  },
  "returns": {
    "nodes": [{ "id": "...", "label": "...", "type": "concept", "centrality": 0.82 }],
    "edges": [{ "source": "...", "target": "...", "relation": "references", "weight": 0.7 }]
  }
}
```

---

#### B3. `contradiction_check` — Epistemic Integrity Guard
**Rust:** `agent_core/src/storage/contradiction_detector.rs`

**What the agent gets:** Before writing ANY new knowledge to the vault, check it against existing
facts. Returns typed contradictions: Numeric, Boolean, Antonym, SemanticReversal — each with
confidence scores.

**Why only Epistemos:** No note-taking app runs write-time contradiction detection. This requires
having the existing fact set indexed AND an embedding model in-process for semantic reversal
detection.

**Tool schema:**
```json
{
  "name": "contradiction_check",
  "params": {
    "claim": "string — the new fact to check",
    "context": "optional string — additional context"
  },
  "returns": {
    "contradictions": [{
      "existing_fact": "The project uses PostgreSQL",
      "new_claim": "The project uses MySQL",
      "type": "semantic_reversal",
      "confidence": 0.91,
      "source_note": "Architecture Decisions 2026-03"
    }],
    "safe_to_write": false
  }
}
```

**This is the agent's epistemic honesty feature.** "I found a contradiction with your earlier note."

---

#### B4. `vault_navigate` — Hyperbolic Geodesic Navigation
**Rust:** `agent_core/src/storage/hyperbolic_topology.rs`

**What the agent gets:** Navigate the vault as a Poincaré disk where hierarchical distance maps
to hyperbolic distance. Folders are Markov Blankets — the agent decides whether to "pierce the
blanket" (read files inside) or stay at the summary level based on relevance scoring.

**Why only Epistemos:** This is original applied mathematics. Nobody else treats file trees as
hyperbolic manifolds. The Friston Free Energy Principle-inspired blanket traversal is novel.

**Tool schema:**
```json
{
  "name": "vault_navigate",
  "params": {
    "start": "string — current location in vault tree",
    "semantic_target": "string — what the agent is looking for",
    "max_depth": 3
  },
  "returns": {
    "path": ["/vault/projects/", "/vault/projects/epistemos/", "/vault/projects/epistemos/architecture.md"],
    "blankets_pierced": 2,
    "geodesic_distance": 1.47,
    "relevance_at_target": 0.89
  }
}
```

---

#### B5. `neural_recall` — 4-Layer Tiered Memory with Hot Facts
**Rust:** `agent_core/src/storage/neural_cache.rs`

**What the agent gets:** Sub-1ms access to pre-warmed "hot facts" from the vault. 4 layers:
- L0: in-memory working context (0μs)
- L1: hot facts, memory-mapped (<1ms), LRU with gravity+complexity+recency weighting
- L2: Tantivy FTS + sqlite-vec hybrid (<5ms)
- L3: cold vault filesystem (<50ms)

The `gravity` dimension is unique: facts referenced by more other facts float to the top.

**Why only Epistemos:** Hermes has flat `MEMORY.md` (2200 chars). OpenClaw has simple vector DB.
Nobody has tiered cache with physics-inspired scoring.

**Tool schema:**
```json
{
  "name": "neural_recall",
  "params": {
    "query": "string",
    "max_layer": "enum(hot|warm|cold|deep) — stop at this tier",
    "temporal_filter": "optional — 'last_5_minutes' or 'today' or 'this_week'"
  },
  "returns": {
    "facts": [{ "content": "...", "layer": 1, "gravity": 3.2, "latency_us": 800 }]
  }
}
```

---

#### B6. `knowledge_distill` — Per-Model Vault Synthesis
**Swift:** `CloudKnowledgeDistillationService.swift`

**What the agent gets:** Distill the vault into a model-specific knowledge profile. Each AI model
gets its own curated knowledge set based on concept limits and active window days.

**Tool schema:**
```json
{
  "name": "knowledge_distill",
  "params": {
    "model_id": "string",
    "concept_limit": 50,
    "active_window_days": 30
  },
  "returns": { "concepts_distilled": 47, "profile_size_tokens": 3200 }
}
```

---

### Category C: The Inference Stack (On-Device AI)

These require in-process MLX-Swift + Metal compute + custom kernels.
No cloud-first agent can offer these.

---

#### C1. `ssm_resume` — Cross-Session Mamba State Persistence
**Rust:** `agent_core/src/storage/ssm_state.rs` (binary serialization)
**Swift:** `SSMStateService.swift` + `Mamba2ForwardPass.swift` + `MetalRuntimeManager.swift`

**What the agent gets:** Save and restore the Mamba-2 SSM hidden state across sessions.
Instead of replaying the entire conversation through the model, restore the 6-24MB state
blob and continue exactly where you left off. Zero-copy deserialization via mmap.

**Why only Epistemos:** No other app runs Mamba models. No other app has SSM state persistence.
This is unique to recurrent architectures running on custom Metal kernels.

**Tool schema:**
```json
{
  "name": "ssm_resume",
  "params": {
    "action": "enum(save|load|list|prune)",
    "session_id": "optional string",
    "label": "optional string — named checkpoint like 'before_refactor'"
  },
  "returns": {
    "state_size_mb": 12.4,
    "layers": 24,
    "dtype": "f16",
    "save_duration_ms": 45,
    "staleness": "fresh — vault unchanged since save"
  }
}
```

---

#### C2. `constrained_generate` — Grammar-Guaranteed Local Output
**Swift:** `ConstrainedDecodingService.swift` + `ToolSchemaGrammar.swift`

**What the agent gets:** Generate structured output from the local model with EBNF grammar
constraints that guarantee valid JSON tool calls. The grammar is auto-compiled from MCP tool
schemas — add a new tool, and the grammar updates automatically.

**Why only Epistemos:** Constrained decoding requires hook access into the MLX token sampling
loop to mask logits BEFORE sampling. This is in-process, in-model inference control. Cloud
APIs offer JSON mode but not grammar constraints. Plugin apps have no model access.

**Tool schema:**
```json
{
  "name": "constrained_generate",
  "params": {
    "prompt": "string",
    "grammar": "enum(tool_call|planning|custom)",
    "custom_ebnf": "optional string — for custom grammars",
    "tools": "optional — tool schemas to compile grammar from"
  },
  "returns": {
    "output": "{ ... guaranteed valid JSON ... }",
    "tokens_generated": 142,
    "constraint_violations_masked": 17
  }
}
```

---

#### C3. `route_private` — Privacy-First Inference Routing
**Swift:** `ConfidenceRouter.swift` + `DualBrainRouter.swift`

**What the agent gets:** Classify any request on five dimensions (complexity, tool_count,
needs_current_info, needs_code_execution, privacy_sensitivity) and route to local or cloud.
Privacy is a HARD GATE — sensitive data never leaves the device regardless of complexity.
Fully auditable with typed reasons.

**Why only Epistemos:** You need an on-device model to offer this. Cloud-only agents route
everything to the cloud by definition. The privacy dimension as a first-class routing concept
with typed audit trail is unique.

**Tool schema:**
```json
{
  "name": "route_private",
  "params": {
    "objective": "string — what the agent wants to do",
    "force_local": false
  },
  "returns": {
    "route": "local",
    "reason": "privacy_sensitive",
    "confidence": 0.94,
    "privacy_score": 0.87,
    "complexity_score": 0.35,
    "explanation": "Request contains personal financial data — routed locally"
  }
}
```

---

#### C4. `metal_benchmark` — Live Kernel Performance Profiling
**Swift:** `MetalRuntimeManager.swift` + `Mamba2ForwardPass.swift`

**What the agent gets:** Run performance benchmarks on Metal compute kernels. The agent can
decide whether to use the custom Mamba-2 pipeline or fall back to MLX based on real-time
thermal/power state.

**Tool schema:**
```json
{
  "name": "metal_benchmark",
  "params": {
    "kernel": "enum(all|segsum|intra_chunk|inter_chunk|ssd_output|silu_gate|conv1d)",
    "warmup_iterations": 3,
    "measure_iterations": 10
  },
  "returns": {
    "results": [{ "kernel": "ssd_output", "mean_ms": 0.42, "p95_ms": 0.51 }],
    "total_pipeline_ms": 3.7,
    "thermal_state": "nominal",
    "gpu_utilization_pct": 45
  }
}
```

---

### Category D: The Intelligence Stack (Agent-Level)

These combine multiple capabilities into higher-order agent behaviors.

---

#### D1. `nightbrain_trigger` — On-Demand Background Intelligence
**Swift:** `NightBrainService.swift`

**What the agent gets:** Trigger any of 11 background maintenance jobs on demand:
event_checkpoint, search_index_checkpoint, artifact_dedup, workspace_compaction,
memory_distillation, cloud_knowledge_distillation, session_graph_generation,
skill_evolution_analysis, ssm_state_pruning, vault_integrity_check, maintenance_log.

Uses `NSBackgroundActivityScheduler` — respects App Nap, battery, thermal state.

**Tool schema:**
```json
{
  "name": "nightbrain_trigger",
  "params": {
    "job": "enum(memory_distillation|skill_evolution|session_graph|...)",
    "priority": "enum(normal|immediate)"
  },
  "returns": { "job_id": "...", "status": "scheduled", "estimated_duration_s": 30 }
}
```

---

#### D2. `inline_partner` — Graph-Weighted Ghost Text
**Swift:** `AIPartnerService.swift`

**What the agent gets:** Query what the inline AI partner "sees" at any cursor position in the
note editor. Returns graph-weighted semantic matches — not just text similarity, but topologically
weighted by the knowledge graph's link structure.

**Why only Epistemos:** Copilot plugins see the current file's text. The partner sees the graph.

**Tool schema:**
```json
{
  "name": "inline_partner",
  "params": {
    "note_id": "string",
    "cursor_offset": 1420,
    "query": "optional — override the context-derived query"
  },
  "returns": {
    "suggestion": "...ghost text...",
    "weighted_matches": [{ "note": "Architecture.md", "score": 0.89, "graph_weight": 2.3 }],
    "complexity_score": 0.4
  }
}
```

---

#### D3. `self_evolve` — GEPA Skill Mutation Pipeline
**Swift:** `SkillEvolutionService.swift`
**Rust:** `agent_core/src/evolution/` (planned)

**What the agent gets:** Analyze execution traces, detect failure patterns (frequent retries,
slow execution, consistent errors), propose skill mutations, validate constraints (size,
semantic preservation), and write new skill versions.

**Ported from:** Hermes `hermes-agent-self-evolution` (GEPA). But yours runs against the vault's
execution history, not just session logs.

**Tool schema:**
```json
{
  "name": "self_evolve",
  "params": {
    "action": "enum(analyze_traces|propose_mutation|validate|apply)",
    "skill_name": "optional string",
    "vault_identity": "string"
  },
  "returns": {
    "proposals": [{
      "skill": "github-pr-review",
      "mutation_type": "parameter_adjustment",
      "rationale": "Detected 73% retry rate on PR comment posting — adding rate limit backoff",
      "constraints": { "size_ok": true, "semantic_preserved": true },
      "diff_preview": "..."
    }]
  }
}
```

---

#### D4. `mixture_of_minds` — Local + Cloud Ensemble Reasoning
**Not in Hermes or OpenClaw in this form**

**What the agent gets:** Route a hard problem through BOTH the local model AND a cloud model
simultaneously, then aggregate. The local model provides privacy-safe initial reasoning; the
cloud model provides depth. The aggregator picks the best parts of each.

**Why only Epistemos:** You're the only app with both a local inference engine AND cloud API
clients in the same process. Hermes/OpenClaw are cloud-only. This is "mixture of agents" but
with a privacy-first local component.

**Tool schema:**
```json
{
  "name": "mixture_of_minds",
  "params": {
    "problem": "string",
    "local_model": "optional — defaults to active local model",
    "cloud_models": ["claude-sonnet-4-6", "gpt-4o"],
    "aggregator": "enum(best_of|synthesize|local_first)"
  },
  "returns": {
    "answer": "...",
    "local_contribution": "...",
    "cloud_contributions": [{ "model": "claude-sonnet-4-6", "response": "..." }],
    "aggregation_method": "synthesize",
    "privacy_note": "Personal data processed locally only"
  }
}
```

---

#### D5. `live_note` — Cron-Scheduled Auto-Executing Note Blocks
**Swift:** `LiveNoteExecutor.swift` + `LiveNoteScanner.swift`

**What the agent gets:** Notes that contain executable task blocks run on a schedule. The agent
can create a note with a ```task block that runs daily, checks an API, and updates the note body
automatically.

**Tool schema:**
```json
{
  "name": "live_note",
  "params": {
    "action": "enum(create|list_due|execute|pause)",
    "note_id": "optional",
    "schedule": "optional — cron expression or 'daily' or 'hourly'",
    "task_prompt": "optional — what the task should do"
  },
  "returns": { "tasks_due": 3, "last_run": "2026-04-09T08:00:00Z", "next_run": "2026-04-10T08:00:00Z" }
}
```

---

#### D6. `dataview` — Obsidian-Compatible Structured Queries
**Swift:** `DataviewService.swift` (partially implemented)

**What the agent gets:** Run DQL (Dataview Query Language) against vault notes:
`TABLE file.name, tags FROM "projects" WHERE status = "active" SORT modified DESC LIMIT 10`

**Why include:** Power users migrating from Obsidian expect this. It's a competitive parity
feature that becomes a Specialty because you can run it from the agent loop, not just in a note.

---

## What To Skip (Kimi's "Defer" List, Validated)

These are in Hermes/OpenClaw but NOT worth porting:

| Skip | Why |
|------|-----|
| **Browser automation (11 Hermes tools)** | You have native `perceive` + `interact` which work on ALL apps, not just browsers. If you need web, use `web_extract`. |
| **RL training (9 Hermes tools)** | Extremely niche. Requires Python ML stack. Not a PKM feature. |
| **Blockchain skills (Solana, Base)** | Niche, rapidly changing APIs, liability risk. |
| **Blender MCP** | Too niche for v1. |
| **BCI (neuroskill-bci)** | Hardware dependency, experimental. |
| **Bioinformatics** | Niche research tool. |
| **Gateway daemon architecture** | Obsolete — MCP is the standard now. |
| **ACP protocol** | Hermes-specific, not adopted elsewhere. |
| **Food delivery (ordercli)** | Fragile reverse-engineered API. |
| **Eight Sleep bed control** | Too niche. |
| **Bluesound audio** | Too niche (Sonos covers most users). |
| **Camera RTSP capture** | Niche IoT. |
| **OpenClaw `node-connect`** | OpenClaw-specific diagnostics. |
| **OpenClaw `taskflow`** | OpenClaw-specific runtime, doesn't map to your architecture. |
| **Voice calls (Twilio)** | Liability, complexity, niche. |

---

## Final Count

| Category | Count | Notes |
|----------|-------|-------|
| **Tier 1: Core tools** (from reference doc) | 12 | Terminal, files, search, todo, clarify, delegate, cron, skills |
| **Tier 2-10: Standard tools** (from reference doc) | ~68 | Web, browser, macOS, comms, media, smart home, dev, AI, niche |
| **Specialties** | 19 | A1-A3, B1-B6, C1-C4, D1-D6 |
| **Skip** | ~15 | Browser (redundant), RL, blockchain, niche IoT |
| **TOTAL actionable** | ~99 | Your full tool inventory when complete |

### What you have today: ~15 tools
### What you need to build: ~84 tools + specialties
### What makes you different: 19 Specialties that nobody can replicate without your stack
