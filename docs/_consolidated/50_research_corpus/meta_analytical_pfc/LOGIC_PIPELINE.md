# PFC Logic Pipeline

Complete documentation of the PFC meta-analytical reasoning engine — every stage, signal, module, and data flow.

---

## System Architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│                              USER QUERY                                   │
└──────────────────────────────┬────────────────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                     10-STAGE ANALYTICAL PIPELINE                          │
│                                                                           │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐│
│  │Triage  │─▶│Memory  │─▶│Routing │─▶│Statist.│─▶│Causal  │─▶│Meta-   ││
│  │        │  │Retriev.│  │        │  │Analysis│  │Infer.  │  │Analysis││
│  └────────┘  └────────┘  └────────┘  └────────┘  └────────┘  └────────┘│
│                                                                           │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐                         │
│  │Bayesian│─▶│Synth-  │─▶│Advers. │─▶│Calib-  │                         │
│  │Updating│  │esis    │  │Review  │  │ration  │                         │
│  └────────┘  └────────┘  └────────┘  └────────┘                         │
│                                                                           │
│  Each stage yields → PipelineEvent { status, signals, data }             │
└──────────────────────────────┬────────────────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                     TEXT GENERATION (5 functions)                          │
│                                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                    │
│  │ Raw Analysis │  │   Layman     │  │  Reflection  │                    │
│  │ (tagged text)│  │  Summary     │  │ (self-crit.) │                    │
│  └──────────────┘  └──────────────┘  └──────────────┘                    │
│  ┌──────────────┐  ┌──────────────┐                                      │
│  │ Arbitration  │  │    Truth     │                                      │
│  │ (multi-engine│  │ Assessment   │                                      │
│  │   voting)    │  │              │                                      │
│  └──────────────┘  └──────────────┘                                      │
│                                                                           │
│  Mode: Simulation │ API (Cloud) │ Local (Ollama)                         │
└──────────────────────────────┬────────────────────────────────────────────┘
                               │
                    ┌──────────┼──────────┐
                    ▼          ▼          ▼
             ┌──────────┐ ┌────────┐ ┌────────────┐
             │ Steering │ │  SOAR  │ │   Daemon   │
             │  Engine  │ │ Engine │ │  Learning  │
             └──────────┘ └────────┘ └────────────┘
```

---

## The 10 Pipeline Stages

The pipeline runs as an async generator in `lib/engine/simulate.ts`, yielding SSE-compatible `PipelineEvent` objects. Each stage contributes status text and signal updates.

### Stage 1: Complexity Triage

**File:** `lib/engine/simulate.ts` (inline)

Routes queries to one of three reasoning depths:

| Depth | Trigger | Focus Depth |
|-------|---------|-------------|
| Quick | Simple factual questions, short queries | 2-4 |
| Standard | Moderate complexity, analytical queries | 4-7 |
| Deep | Meta-analytical, philosophical, multi-domain | 7-10 |

Complexity scoring uses keyword detection (causal markers, meta-analytical terms, epistemic uncertainty words), query length, question type classification, and domain mapping.

### Stage 2: Memory Retrieval

**File:** `lib/engine/simulate.ts` (inline)

Searches conversation history and stored executive traces for relevant prior analyses. In Simulation mode, generates template-based memory hits. In API/Local mode, uses ChromaDB semantic search if available.

### Stage 3: Routing

**File:** `lib/engine/simulate.ts` (inline)

Determines which analytical engines to engage based on triage results:
- Statistical analysis for effect-size or power questions
- Causal inference for "does X cause Y" patterns
- Meta-analysis for synthesis across studies
- Bayesian updating for prior/posterior reasoning
- All engines for deep-mode queries

### Stage 4: Statistical Analysis

**File:** `lib/engine/prompts/statistical.ts`

Structured prompt template encoding:
- **Cohen's d**: Standardized mean difference with interpretation (negligible < 0.2 < small < 0.5 < medium < 0.8 < large)
- **Power analysis**: Required sample size at given power and alpha
- **Clinical significance**: MCID (Minimal Clinically Important Difference)
- **Bias assessment**: Selection bias, measurement bias, attrition markers

The prompt instructs the LLM to produce structured output with `[DATA]`, `[MODEL]`, `[UNCERTAIN]`, and `[CONFLICT]` tags.

### Stage 5: Causal Inference

**File:** `lib/engine/prompts/causal.ts`

Structured prompt encoding:
- **Bradford Hill Criteria**: 9 criteria scored 0-1 (strength, consistency, specificity, temporality, biological gradient, plausibility, coherence, experiment, analogy)
- **DAG construction**: Directed acyclic graph of causal relationships
- **Counterfactual framework**: Potential outcomes reasoning
- **Study design detection**: RCT, cohort, case-control, cross-sectional classification

### Stage 6: Meta-Analysis

**File:** `lib/engine/prompts/meta-analysis.ts`

Structured prompt encoding:
- **DerSimonian-Laird**: Random effects pooling with between-study variance
- **I² heterogeneity**: Proportion of variability from true heterogeneity (low < 25% < moderate < 50% < substantial < 75% < considerable)
- **Egger's regression**: Publication bias via funnel plot asymmetry
- **Forest plot structure**: Effect sizes with confidence intervals per study

### Stage 7: Bayesian Updating

**File:** `lib/engine/prompts/bayesian.ts`

Structured prompt encoding:
- **Conjugate normal updating**: Closed-form posterior computation
- **Bayes factors**: Evidence strength on Jeffreys' scale (1-3 anecdotal → >100 extreme)
- **Prior specification**: Informative vs. uninformative prior reasoning
- **Credible intervals**: 95% highest posterior density

### Stage 8: Synthesis

Integrates results from all active analytical engines into a unified evidence assessment. Identifies convergent findings and tensions between methods.

### Stage 9: Adversarial Review

**File:** `lib/engine/reflection.ts`

Five-point self-critique system:
1. Weakest claims in the analysis
2. Alternative explanations not considered
3. Overclaiming detection
4. Missing context identification
5. Unknown unknowns estimation

### Stage 10: Confidence Calibration

Final calibrated confidence with uncertainty bounds. Adjusts based on:
- Effect size strength (statistical boost)
- Bradford Hill score (causal boost)
- Adversarial critique severity (penalty)
- Heterogeneity (wider bounds with I² > 50%)

---

## Signal System

All signals are heuristic functions computed from query properties, pipeline stage outputs, and steering bias. They flow through every stage of the pipeline.

### Core Signals

| Signal | Range | Computation | Purpose |
|--------|-------|-------------|---------|
| `confidence` | 0.1 – 0.95 | Base from complexity + analytical boosts | Evidence-grounded certainty |
| `entropy` | 0.01 – 0.95 | Keyword density + domain complexity | Query noise / information disorder |
| `dissonance` | 0.01 – 0.95 | Conflicting evidence markers | Internal tension between claims |
| `healthScore` | 0.2 – 1.0 | `1 - entropy×0.45 - dissonance×0.35` | Composite cognitive health |
| `focusDepth` | 2 – 10 | Triage routing + steering adjustment | Reasoning depth indicator |

### Safety Signals

| Signal | Range | Purpose |
|--------|-------|---------|
| `safetyState` | green / yellow / orange / red | Threshold-based risk level |
| `riskScore` | 0.01 – 0.9 | Safety keyword detection |
| `temperatureScale` | 0.1 – 1.0 | LLM exploration vs. determinism |

### Derived Signals

| Signal | Range | Purpose |
|--------|-------|---------|
| `activeConcepts` | string[] | Domain-specific concept pool |
| `bayesianPriorStrength` | 0 – 1 | Strength of prior evidence |

### Signal Flow

```
Query Features → Stage Processing → Signal Computation → Steering Adjustment
                                          │
                                    ┌─────┴─────┐
                                    ▼           ▼
                              Safety State   Focus Plan
                              Assessment     Generation
```

---

## Inference Modes

PFC operates in three modes that share the same pipeline but differ in text generation:

### Simulation Mode (Default)

No external dependencies. Template-based generation produces structured analytical text. Signals are computed from query features alone. Ideal for exploring the pipeline architecture.

### API Mode

Cloud LLM calls through Vercel AI SDK. Supports:
- **Anthropic**: Claude Sonnet 4, Claude Opus 4
- **OpenAI**: GPT-4o, GPT-4o-mini
- **Google**: Gemini

Prompt templates from `lib/engine/prompts/` encode analytical frameworks into structured LLM instructions. Responses parsed for `[DATA]`/`[MODEL]`/`[UNCERTAIN]`/`[CONFLICT]` tags.

### Local Mode (Ollama)

Runs models locally via Ollama (llama3.1, qwen2.5, mistral, phi3). Same prompt templates as API mode. Auto-detects available models at `http://localhost:11434`.

---

## Steering Engine

A 3-layer hybrid feedback loop that learns from user corrections and adapts future signal generation.

**File:** `lib/engine/steering/engine.ts`

### Layer 1: Contrastive Exemplar Storage

Stores positive/negative exemplars from explicit user corrections (thumbs up/down, signal slider overrides). Each exemplar records:
- Query text and domain
- Signal snapshot at correction time
- Correction direction (+/-)
- Timestamp and decay weight

### Layer 2: Bayesian Priors

Beta(α, β) distributions per steering dimension with adaptive learning rates:
- Each correction updates the Beta parameters
- Prior strength grows with more corrections
- Decay mechanism prevents over-fitting to old patterns

Dimensions: `focusDepth`, `confidence`, `entropy`, `dissonance`, `temperatureScale`

### Layer 3: Contextual k-NN

For a new query, finds the k most similar past queries via cosine similarity on feature vectors:
- Computes context-aware bias from weighted neighbor corrections
- More similar neighbors receive higher weight
- Recent corrections weighted more than old ones

### Prompt Composer

**File:** `lib/engine/steering/prompt-composer.ts`

Translates numerical steering biases into natural-language directives injected into LLM system prompts. Examples:
- High focus bias → "Be extremely thorough and detailed in your analysis"
- High confidence bias → "Express conclusions with clear conviction where evidence supports it"
- Low temperature → "Be precise and deterministic in your reasoning"

---

## SOAR Engine

Self-Organized Analytical Reasoning for queries at the edge of learnability.

**File:** `lib/engine/soar/`

### Architecture

```
                     ┌─────────────┐
                     │   Probe     │ ← Detect if query is at edge
                     │  (detector) │
                     └──────┬──────┘
                            │
                     Not at edge? → Skip, return baseline
                            │
                     At edge ↓
              ┌─────────────────────────────┐
              │    ITERATION LOOP (1-3x)    │
              │                             │
              │  ┌────────┐   Teacher generates N stepping-stone
              │  │Teacher │   problems targeting specific skills
              │  └───┬────┘   (assumption ID, adversarial thinking,
              │      │        structural transfer, etc.)
              │      ▼
              │  ┌────────┐   Student works through stones
              │  │Student │   sequentially, building reasoning
              │  └───┬────┘   context with each step
              │      │
              │      ▼
              │  ┌────────┐   Student re-attacks target problem
              │  │ Final  │   with accumulated curriculum context
              │  │Attempt │
              │  └───┬────┘
              │      │
              │      ▼
              │  ┌────────┐   Measures improvement vs baseline:
              │  │Reward  │   Δconfidence, -Δentropy, -Δdissonance
              │  │Signal  │   Early stop if no improvement
              │  └────────┘
              └─────────────────────────────┘
                            │
                            ▼
              ┌─────────────────────────────┐
              │  OOLONG Contradiction Scan   │
              │  O(n²) pairwise comparison   │
              │  of all claims in analysis   │
              └─────────────────────────────┘
```

### Key Insight

The teacher is rewarded by measured student improvement on the TARGET problem, not by the quality of stepping stones. This prevents reward hacking and diversity collapse seen in intrinsic reward schemes.

### SOAR Modules

| Module | File | Purpose |
|--------|------|---------|
| **Detector** | `soar/detector.ts` | Edge-of-learnability probe with hard indicator keywords, question type classification |
| **Teacher** | `soar/teacher.ts` | Curriculum generation — 10 template stepping stones or LLM-generated with rationale |
| **Student** | `soar/student.ts` | Progressive reasoning — attempts stones sequentially, re-attacks target with context |
| **Reward** | `soar/reward.ts` | Grounded 5-dimensional composite reward: confidence, entropy, dissonance, health, TDA |
| **Contradiction** | `soar/contradiction.ts` | OOLONG O(n²) scanner — negation, antonyms, temporal markers, scope quantifiers |
| **Engine** | `soar/engine.ts` | Main orchestrator: probe → (teach → learn → evaluate) × N → contradiction scan |

---

## Text Generation Pipeline

After the 10-stage pipeline completes, PFC generates 5 distinct text outputs:

### 1. Raw Analysis

Tagged analytical text with evidence markers:
- `[DATA]` — empirical findings and statistics
- `[MODEL]` — theoretical frameworks and models
- `[UNCERTAIN]` — areas of genuine uncertainty
- `[CONFLICT]` — tensions between evidence sources

### 2. Layman Summary

5-section accessible explanation:
1. Bottom line answer
2. Key evidence
3. What we don't know
4. Why this matters
5. What to watch for

### 3. Self-Reflection

Independent critique identifying:
- Weakest claims in the analysis
- Alternative explanations
- Overclaiming detection
- Missing context
- Unknown unknowns

### 4. Multi-Engine Arbitration

Simulates disagreement between analytical "engines" (statistical, causal, Bayesian) and resolves conflicts through weighted voting. Surfaces tensions that a single perspective would miss.

### 5. Truth Assessment

Independent evaluation of response reliability with signal interpretation. Produces a truth score and explanation of what drives confidence up or down.

---

## State Management

**File:** `lib/store/` (13 Zustand slices)

### Store Architecture

All state lives in a single Zustand store composed from 13 slices:

| Slice | File | Key State |
|-------|------|-----------|
| **message** | `slices/message.ts` | Chat history, message lifecycle, query submission |
| **notes** | `slices/notes.ts` | Pages, blocks, properties, links, undo/redo (71KB) |
| **learning** | `slices/learning.ts` | Learning goals, page learning state, SOAR sessions |
| **ui** | `slices/ui.ts` | Dark mode, layout, chat mode, modal visibility |
| **inference** | `slices/inference.ts` | Provider, model, API key, temperature |
| **pipeline** | `slices/pipeline.ts` | Active stage, progress, stage results |
| **concepts** | `slices/concepts.ts` | Extracted concepts, hierarchy, concept atlas |
| **controls** | `slices/controls.ts` | Steering sliders (focus, complexity bias) |
| **cortex** | `slices/cortex.ts` | Brain state snapshots (save/restore) |
| **soar** | `slices/soar.ts` | SOAR engine state, sessions, probe results |
| **research** | `slices/research.ts` | Research library, papers, ideas |
| **tier** | `slices/tier.ts` | Feature tier management |
| **portal** | `slices/portal.ts` | Modal/drawer state |
| **toast** | `slices/toast.ts` | Toast notifications |

### Cross-Slice Event Bus

**File:** `lib/store/events.ts`

Slices communicate through a typed event bus instead of direct cross-slice mutations:

| Event | Emitted By | Consumed By |
|-------|------------|-------------|
| `query:submitted` | message | pipeline, learning |
| `query:completed` | message | pipeline, concepts |
| `chat:cleared` | message | pipeline, concepts |
| `learning:page-created` | learning | notes |
| `learning:block-created` | learning | notes |

---

## Database

**File:** `lib/db/schema.ts` (Drizzle ORM + SQLite)

Local SQLite database (`pfc.db`) with WAL mode for concurrent reads:

### Tables

| Table | Purpose |
|-------|---------|
| `users` | Single-user app, stores user ID |
| `chats` | Conversation threads |
| `messages` | Chat messages with role, content, metadata |
| `notes_pages` | Note pages with titles, tags, properties |
| `notes_blocks` | Content blocks within pages |
| `notes_links` | Page-to-page and block-to-page links |
| `concepts` | Extracted concepts with prime encodings |
| `brain_snapshots` | Cortex archive snapshots |

---

## Daemon System

**File:** `daemon/`

Background agents that run periodically to improve the system passively:

### Tasks

| Task | File | Schedule | Purpose |
|------|------|----------|---------|
| **Connection Finder** | `tasks/connection-finder.ts` | Every 30 min | Discovers implicit relationships between notes |
| **Auto Organizer** | `tasks/auto-organizer.ts` | Every 1 hour | Tags and clusters notes automatically |
| **Daily Brief** | `tasks/daily-brief.ts` | Once per day | Generates morning summary of insights |
| **Research Assistant** | `tasks/research-assistant.ts` | Every 2 hours | Identifies open research questions |
| **Learning Runner** | `tasks/learning-runner.ts` | On trigger | 7-step recursive learning protocol |

### Learning Runner Protocol

The learning runner implements a 7-step recursive learning loop:
1. Select a note page flagged for learning
2. Extract key claims and concepts
3. Generate probing questions
4. Attempt to answer with current knowledge
5. Identify gaps and contradictions
6. Generate new blocks with insights
7. Update learning state and schedule next iteration

---

## API Routes

### SSE Pipeline Route

```
POST /api/(chat)/api/chat
```

Main entry point. Accepts query + inference config, runs the 10-stage pipeline as a Server-Sent Events stream. Each stage yields `PipelineEvent` objects.

### Other Routes

| Route | Method | Purpose |
|-------|--------|---------|
| `/api/assistant` | POST | Alternative assistant endpoint |
| `/api/daemon` | GET/POST | Daemon task control (whitelist + body cap) |
| `/api/notes` | POST | Note CRUD operations |
| `/api/notes-ai` | POST | AI-powered note enhancement |
| `/api/notes-learn` | POST | Trigger learning on a note |
| `/api/ollama-check` | GET | Local model detection |
| `/api/ollama-status` | POST | Model status polling |
| `/api/test-connection` | POST | API key verification |
| `/api/history` | GET | Chat history retrieval |

---

## Pages & UI

| Route | Component | Purpose |
|-------|-----------|---------|
| `/` (chat) | `app/(chat)/` | Main chat interface with pipeline visualization |
| `/analytics` | `app/analytics/` | 8-tab dashboard: copilot, archive, steering lab, pipeline, signals, visualizer, evaluate, concepts |
| `/notes` | `app/notes/` | Note-taking with canvas, graph view, AI assistance |
| `/settings` | `app/settings/` | Inference mode, API keys, steering config |
| `/library` | `app/library/` | Research paper management |
| `/daemon` | `app/daemon/` | Background agent controls |
| `/research-copilot` | `app/research-copilot/` | Research methodology guidance |
| `/visualizer` | `app/visualizer/` | Interactive D3 signal radar |
| `/diagnostics` | `app/diagnostics/` | System health check |

### Note Canvas

**File:** `components/notes/note-canvas.tsx` (~1,540 lines)

Obsidian-like freeform canvas inspired by tldraw:
- Card types: text, note, group, paper (with fold animation)
- Pan/zoom with CSS transforms and inertial panning
- Bezier edge connections between cards
- 7 colors, resize handles, snap-to-grid
- Undo/redo with transaction batching
- Marquee selection, snap guides, viewport culling
- LOD rendering, minimap, keyboard shortcuts

---

## Security & Hardening

### Rate Limiting

**File:** `lib/rate-limit.ts`

Sliding-window rate limiter applied to all 13 API routes via `withMiddleware` wrapper.

### Auth

Token-based via `x-pfc-token` header or `PFC_API_TOKEN` environment variable.

### Input Validation

- Query length cap: 50,000 characters
- Body size cap: 1 MB on daemon routes
- String input capping via `capStr()` utility
- AbortSignal for client disconnect handling

### Hydration Safety

- All store slices initialize with safe defaults
- Hydration deferred to `useEffect` to prevent SSR mismatches
- `lib/store/hydrate.ts` centralizes persistence from localStorage

---

## Testing

**Framework:** Vitest 4 + happy-dom + @testing-library

| Test File | Coverage |
|-----------|----------|
| API utilities | Request/response helpers |
| Rate limiting | Sliding window behavior |
| Branded types | Type safety enforcement |
| Store SOAR | SOAR state management |
| Store events | Cross-slice event bus |
| File processing | Document parsing |

---

## Relationship to Python Pipeline

The PFC app and the standalone Python Meta-Analytical Pipeline are complementary:

```
Python Pipeline (meta-analytical-pipeline)
├── Numerical computation with real math
│   (NumPy/SciPy: DerSimonian-Laird, Bradford Hill, Ripser TDA)
├── FastAPI server for programmatic access
├── SOAR engine (Python port)
└── Training data generation from executive traces

          ↕  Shared concepts, different implementations

PFC App (pfc-app)
├── User interface with real-time visualization
├── Structured prompt templates encoding the same frameworks
│   (LLM executes the analytical reasoning via prompts)
├── SOAR engine (TypeScript original)
├── 3-layer steering feedback loop
├── Daemon background learning agents
└── Note-taking with concept extraction
```

The Python pipeline performs actual numerical computation (real effect sizes, real Bayesian posteriors). The PFC app encodes the same mathematical frameworks as structured prompts for LLMs to reason through, producing natural-language analyses grounded in the same rigor.
