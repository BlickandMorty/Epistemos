# Cloud Knowledge Distillation — Design Spec

**Status:** Not yet implemented
**Priority:** Tier 2 (after Phase 6F wiring)
**Approach:** Pre-compiled base knowledge layer + dynamic per-query retrieval

---

## Concept

Every model — local or cloud — gets its own **Model Vault**: a dedicated knowledge profile that the model reads at session start. The user sees these in the Notes sidebar under a "Model Vaults" section and in the Agent Runtime panel. Each vault is a folder of markdown files the user can browse, edit, and rebuild.

- **Claude Opus** has its own vault with your research style preferences
- **Qwen 3.5 4B** has its own vault tuned for fast local queries
- **GPT-5.4** has its own vault with different emphasis

The user can open any model vault, read what the model "knows", edit it, or hit rebuild. It's as tangible as a notes folder.

Cloud models can't be fine-tuned per-user. Instead, we "teach" them by:

1. **Base Knowledge Layer** (compiled offline) — a set of structured reference documents distilled from the vault that persist across conversations. The model reads these once and "knows" your domain.

2. **Dynamic Retrieval Layer** (per-query) — relevant vault chunks injected into context at query time via the existing search pipeline (tantivy + vector + graph + RRF + reranking).

The base layer gives the model your identity, style, and conceptual framework. The retrieval layer gives it specific facts and recent notes. Together they simulate a "personalized" cloud model without actual fine-tuning.

---

## Base Knowledge Layer: What Gets Compiled

### 1. Knowledge Profile (`knowledge_profile.md`)
Generated from vault analysis. Contains:
- **Domain Map**: top-level topics with note counts and recency (e.g., "Machine Learning (47 notes, last 3 days)", "Philosophy of Mind (12 notes, last 2 weeks)")
- **Entity Graph Summary**: key entities (people, projects, concepts) and their relationships, extracted via NER + knowledge graph
- **Writing Style Fingerprint**: average sentence length, vocabulary complexity, preferred formatting patterns, common phrases
- **Terminology Glossary**: domain-specific terms the user uses with their definitions (extracted from vault context)

### 2. Concept Index (`concept_index.md`)
Top 50-100 concepts ranked by:
- Frequency (how often referenced)
- Centrality (knowledge graph PageRank)
- Recency (time-weighted)

Each concept gets a 1-2 sentence definition distilled from the user's own notes (not generic definitions).

### 3. Active Context (`active_context.md`)
Rolling window of recent activity:
- Notes created/edited in last 7 days (titles + first paragraphs)
- Recent chat summaries
- Current projects/threads
- Open questions the user is exploring

### 4. Instruction Layer (`instructions.md`)
User-authored or AI-assisted rules:
- "I prefer concise answers with citations"
- "When discussing ML, assume I know the math"
- "Always reference my existing notes when relevant"
- "My current research focus is X"

---

## Compilation Pipeline

### Trigger
- **Background**: NightBrain job (runs during idle, AC power, good thermals)
- **Manual**: User clicks "Rebuild Knowledge Profile" in Settings
- **Incremental**: After vault sync detects >10 changed notes

### Steps

1. **Vault Scan** — read all notes, extract metadata (titles, tags, timestamps, word counts)
2. **Entity Extraction** — NER on all notes → entity graph (already exists in search pipeline)
3. **Topic Clustering** — group notes by topic using vault embeddings (InstantRecall index)
4. **Concept Ranking** — PageRank on entity graph + frequency + recency weighting
5. **Style Analysis** — sentence length distribution, vocabulary stats, formatting preferences
6. **Distillation** — for each top concept, select the best 2-3 sentences from the user's notes that define it
7. **Assembly** — compose the 4 documents above, respecting a token budget (target: 2000-3000 tokens total for base layer)
8. **Storage** — write to `~/Library/Application Support/Epistemos/knowledge_profile/`

### Token Budget

The base layer must fit within the system prompt budget alongside the agent's instructions:
- Knowledge profile: ~800 tokens
- Concept index: ~600 tokens
- Active context: ~400 tokens
- Instructions: ~200 tokens
- **Total: ~2000 tokens** (leaves room for the agent system prompt)

---

## Dynamic Retrieval Layer (Per-Query)

This already exists via the search pipeline. The enhancement:

1. **Query arrives** from user
2. **Search pipeline** runs (tantivy + vector + graph + RRF + reranking) → top 8-12 chunks
3. **Context compiler** formats chunks as numbered references with source attribution
4. **Injection** — chunks inserted after the base layer in the system prompt or as a separate context block

### Enhancement: Knowledge-Aware Retrieval

When the base layer's concept index mentions a concept that appears in the user's query, boost retrieval results from notes tagged with that concept. This creates a feedback loop where the compiled knowledge improves retrieval relevance.

---

## Cloud Model Integration Points

### For Hermes Agent (Python subprocess)
The compiled knowledge files are injected into the Hermes system prompt at session start:
- `HermesSubprocessManager` passes the knowledge profile path as an environment variable
- `epistemos_bridge.py` reads the files and prepends to the system prompt
- Files are read once at session start, not per-turn

### For Apple Intelligence (FoundationModels)
- `AppleIntelligenceService` prepends the knowledge profile to the system prompt
- Shorter version (~500 tokens) due to 4096 token limit
- Active context only (skip full concept index)

### For Direct Cloud API Calls (CloudLLMClient)
- System prompt includes full base layer
- Per-query retrieval results in user message context

---

## File Structure (Per-Model Vaults)

Each model gets its own vault directory. The user sees these as folders in the Notes sidebar.

```
~/Library/Application Support/Epistemos/model_vaults/
├── claude-opus-4.6/
│   ├── knowledge_profile.md      # Domain map, entity graph, writing style
│   ├── concept_index.md          # Top concepts with definitions
│   ├── active_context.md         # Rolling 7-day window
│   ├── instructions.md           # User-authored preferences (editable!)
│   ├── meta.json                 # Last compiled, note count, hash
│   └── history/
│       └── 2026-04-01.json
├── qwen35-4b/
│   ├── knowledge_profile.md      # Shorter — fits 4K local context
│   ├── concept_index.md          # Top 20 concepts only
│   ├── active_context.md
│   ├── instructions.md
│   └── meta.json
├── gpt-5.4/
│   └── ...
└── apple-intelligence/
    ├── knowledge_profile.md      # Minimal — 500 token budget
    ├── active_context.md
    ├── instructions.md
    └── meta.json
```

**Per-model differences:**
- Cloud models (Claude, GPT): full ~2000 token base layer
- Local models (Qwen 4B): shorter ~800 tokens (constrained context)
- Apple Intelligence: minimal ~500 tokens (4096 hard limit)

---

## UI Integration

### Notes Sidebar
Under a "Model Vaults" section header:
- List each model vault as a collapsible folder
- Each file inside is a readable/editable markdown note
- Badge showing last compile date
- "Rebuild" button per vault

### Agent Runtime Panel
- Current model's vault shown as context indicator
- "Knowledge: 47 concepts, compiled 2h ago"
- Tap to view/edit the model vault

### Settings
- "Model Vaults" section
- Toggle: auto-rebuild on vault changes (default ON)
- Token budget slider per model type
- "Rebuild All" button

---

## Implementation Plan

### New Files
- `Epistemos/KnowledgeFusion/CloudKnowledgeCompiler.swift` — main compilation pipeline
- `Epistemos/KnowledgeFusion/ConceptRanker.swift` — PageRank + frequency + recency ranking
- `Epistemos/KnowledgeFusion/StyleAnalyzer.swift` — writing style fingerprinting
- `Epistemos/KnowledgeFusion/KnowledgeProfileStore.swift` — read/write/versioning of compiled files

### Integration Points
- `NightBrainService.swift` — add compilation job to background pipeline
- `HermesSubprocessManager.swift` — pass knowledge profile path to Hermes env
- `AppleIntelligenceService.swift` — prepend short profile to system prompt
- `AgentViewModel.swift` — inject base layer at session start
- Settings UI — "Knowledge Profile" section showing last compile time, concept count, rebuild button

### Dependencies
- InstantRecall index (for topic clustering) — already exists
- Search pipeline (for entity extraction) — already exists
- VaultSyncService (for note access) — already exists
- NightBrain (for background scheduling) — already exists

---

## What This Is NOT

- NOT fine-tuning — no model weights are modified
- NOT RAG alone — the base layer persists across queries, unlike pure retrieval
- NOT prompt engineering — the content is automatically distilled from the user's own knowledge
- NOT cloud upload — all compilation happens locally, only the distilled text enters the API call

The cloud model sees your knowledge as structured context, not training data. It "forgets" between sessions unless the profile is re-injected. But because the profile is stable (changes slowly as vault evolves), the experience feels like the model "knows" you.
