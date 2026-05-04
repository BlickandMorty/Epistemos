# Pipeline Extraction & App Refactor Design

**Date:** 2025-02-13
**Status:** Approved
**Scope:** Extract Python pipeline into standalone portfolio project; refactor app to prompt-only reasoning

---

## Overview

Split the monolithic meta-analytical-pfc into two projects:

1. **meta-analytical-pipeline** — Standalone Python library + FastAPI service containing all mathematical reasoning engines, TDA, learning systems, and monitoring. Portfolio/resume piece.
2. **meta-analytical-pfc** (refactored) — Note-taking & research app with prompt-based analytical reasoning. No heavy compute. Daemon agents auto-learn from notes.

---

## Project 1: meta-analytical-pipeline

### Structure

```
meta-analytical-pipeline/
├── README.md                          # Portfolio-grade with badges, architecture diagram
├── pyproject.toml                     # Modern Python packaging (pip installable)
├── LICENSE
├── Makefile                           # dev, test, lint, serve commands
│
├── meta_analytical_pipeline/          # Library core (importable)
│   ├── __init__.py                    # Public API exports
│   ├── core/
│   │   ├── engine.py                  # 10-stage pipeline orchestrator (from pfc_engine.py)
│   │   ├── triage.py                  # Complexity routing
│   │   ├── memory.py                  # ChromaDB cross-chat memory
│   │   └── types.py                   # ReasoningMode enum, dataclasses
│   │
│   ├── reasoning/
│   │   ├── statistical.py             # Cohen's d, power analysis, MCID
│   │   ├── causal.py                  # DAG construction, Bradford Hill criteria
│   │   ├── bayesian.py                # Prior/posterior, Bayes factors, credible intervals
│   │   └── meta_analysis.py           # DerSimonian-Laird, I², Egger's test
│   │
│   ├── topology/
│   │   ├── activation_capture.py      # Transformer layer hook system
│   │   ├── tda_pipeline.py            # Ripser persistent homology, PCA, entropy
│   │   └── types.py                   # TDAResult, ActivationTrace dataclasses
│   │
│   ├── monitoring/
│   │   ├── concepts.py                # Leibnizian chord computation (prime encoding)
│   │   ├── signals.py                 # Entropy, dissonance, health score generation
│   │   └── telemetry.py               # JSONL event logging
│   │
│   ├── control/
│   │   ├── focus_controller.py        # Continued-fraction entropy valve
│   │   └── cae_engine.py              # Contextual Allostasis Engine (safety states)
│   │
│   ├── learning/
│   │   ├── executive_trace.py         # Trace recording & persistence
│   │   ├── pattern_detector.py        # TF-IDF + DBSCAN clustering
│   │   ├── training_generator.py      # Trace → training example conversion
│   │   ├── feedback_loop.py           # Reward/penalty signals
│   │   └── model_updater.py           # Knowledge base management
│   │
│   ├── validation/
│   │   ├── adversarial_review.py      # 5-point red-team self-critique
│   │   └── confidence_calibration.py  # Evidence-based certainty calibration
│   │
│   └── config/                        # All YAML configs
│       ├── model_config.yaml
│       ├── runtime.yaml
│       ├── telemetry.yaml
│       ├── local_model.yaml
│       ├── cae.yaml
│       ├── concepts.yaml
│       ├── feedback.yaml
│       └── defaults.py                # Config loader with defaults
│
├── server/                            # FastAPI layer
│   ├── __init__.py
│   ├── app.py                         # FastAPI app factory
│   ├── routes/
│   │   ├── analyze.py                 # POST /analyze — full 10-stage pipeline
│   │   ├── statistical.py             # POST /statistical — isolated statistical analysis
│   │   ├── causal.py                  # POST /causal — DAG + Bradford Hill
│   │   ├── bayesian.py                # POST /bayesian — prior/posterior updating
│   │   ├── meta_analysis.py           # POST /meta-analysis — pooled effects
│   │   ├── tda.py                     # POST /tda — topological data analysis
│   │   ├── signals.py                 # POST /signals — compute signal bundle
│   │   ├── concepts.py                # POST /concepts — Leibnizian chord analysis
│   │   ├── learning.py                # POST /learn — trigger learning from traces
│   │   └── health.py                  # GET /health — service health check
│   ├── middleware.py                   # CORS, logging, error handling
│   └── schemas.py                     # Pydantic request/response models
│
├── training/                          # Training CLI tools
│   ├── prepare_data.py                # Trace → training data conversion
│   └── fine_tune.py                   # Knowledge base integration
│
├── tests/
│   ├── test_reasoning/
│   ├── test_topology/
│   ├── test_monitoring/
│   ├── test_control/
│   ├── test_learning/
│   └── test_server/
│
├── docs/
│   ├── architecture.md                # System architecture with diagrams
│   ├── mathematical-foundations.md    # The math behind each module
│   ├── api-reference.md               # Endpoint documentation
│   └── quickstart.md                  # Getting started guide
│
└── data/                              # Runtime data directories
    ├── memory/                        # ChromaDB persistence
    ├── executive_traces/              # Reasoning trace storage
    ├── learned_knowledge/             # Knowledge base JSON
    └── telemetry/                     # Event logs
```

### FastAPI Endpoints

| Method | Path | Description | Input | Output |
|--------|------|-------------|-------|--------|
| POST | /analyze | Full 10-stage pipeline | query, mode, config | AnalysisResult (all stages, signals, truth assessment) |
| POST | /statistical | Statistical analysis | query, studies[] | EffectSizes, power, significance |
| POST | /causal | Causal inference | query, exposure, outcome | DAG, Bradford Hill scores, verdict |
| POST | /bayesian | Bayesian updating | query, prior, likelihood | Posterior, Bayes factor, credible intervals |
| POST | /meta-analysis | Meta-analytical synthesis | query, studies[] | Pooled effect, I², Egger's p, forest plot data |
| POST | /tda | Topological analysis | model_name, query | Betti numbers, persistence entropy, topology graph |
| POST | /signals | Signal computation | query, reasoning_trace | Entropy, dissonance, health, focus plan |
| POST | /concepts | Concept analysis | query | Chord product, frequencies, harmony distance |
| POST | /learn | Trigger learning | traces[] | Patterns detected, skills learned |
| GET | /health | Health check | — | Status, version, loaded models |

### Library Usage

```python
from meta_analytical_pipeline import Pipeline, StatisticalAnalyzer, CausalEngine

# Full pipeline
pipeline = Pipeline()
result = pipeline.analyze("What is the effect of bilingualism on cognitive decline?")
print(result.signals.confidence)
print(result.truth_assessment)

# Individual modules
stats = StatisticalAnalyzer()
analysis = stats.analyze(query="...", studies=[...])

causal = CausalEngine()
dag = causal.build_dag(exposure="bilingualism", outcome="cognitive_decline")
```

---

## Project 2: meta-analytical-pfc (Refactored)

### What Gets Removed

**Files deleted:**
- `src/` — entire Python source directory
- `training/` — entire training suite
- `config/` — all YAML configs (moved to pipeline project)
- `requirements.txt` — Python dependencies
- `setup.py` — Python package config
- `data/` — runtime data directories (memory, traces, telemetry)
- `benchmarks/` — if exists
- `tests/` — Python tests (if any at root level)

**Frontend references cleaned:**
- Settings page: Remove Analytics Engine section, TDA references, activation capture settings
- Settings page: Remove training/fine-tuning UI
- Dashboard: Remove TDA visualization tab content that depends on Python compute
- Signal displays: Signals now come from prompt-based heuristics, not Python compute
- Any imports or API calls to Python backend endpoints
- Documentation files: Update to reflect prompt-only architecture

**Dependencies removed from app:**
- PyTorch, transformers, accelerate, bitsandbytes
- Ripser, scipy (heavy), scikit-learn
- sentence-transformers (unless kept for ChromaDB embeddings)
- networkx, matplotlib
- FastAPI/uvicorn (Python server no longer needed from app)

### What Gets Kept

**Core app (unchanged):**
- Next.js frontend, all UI components
- SQLite database + Drizzle ORM
- Zustand state management
- All note-taking functionality (block editor, vaults, concepts, links)
- Research tools (Semantic Scholar, paper review, citation search)
- SOAR meta-learning engine (TypeScript)
- LLM provider layer (Anthropic, OpenAI, Google, Ollama)

**Steering system (kept + enhanced):**
- `lib/engine/steering/prompt-composer.ts` — the math-to-prompt translator
- `lib/engine/steering/engine.ts` — 3-layer hybrid steering
- `lib/engine/steering/encoder.ts`, `memory.ts`, `feedback.ts`

**Daemon (kept as background agents):**
- All 5 tasks: Connection Finder, Daily Brief, Auto-Organizer, Research Assistant, Learning Protocol
- Daemon HTTP server on port 3099
- Permission tiers (Sandboxed → File Access → Full Access)
- Agent behavior controls (complexity bias, adversarial intensity, etc.)

**Pipeline (refactored to prompt-only):**
- 10-stage architecture preserved
- Stages 4-7 become structured prompt templates instead of Python compute
- Stages 1-3, 8-10 unchanged (already TypeScript/LLM)

### Prompt Template Architecture

Each analytical stage gets a mathematical framework prompt that replaces the Python computation:

**Statistical Stage prompt includes:**
- Cohen's d interpretation thresholds (negligible < 0.2, small < 0.5, medium < 0.8, large)
- Power analysis framework (α, β, minimum detectable effect)
- MCID clinical significance thresholds
- Publication bias indicators (funnel asymmetry, trim-and-fill)

**Causal Stage prompt includes:**
- Bradford Hill 9 criteria with scoring rubric
- DAG construction guidance (exposure → mediators → outcome → confounders)
- Counterfactual reasoning framework
- Dose-response assessment

**Meta-Analysis Stage prompt includes:**
- Random-effects vs fixed-effects selection criteria
- I² heterogeneity interpretation (low < 25%, moderate < 50%, substantial < 75%, considerable)
- Forest plot narrative structure
- Egger's test for small-study effects

**Bayesian Stage prompt includes:**
- Prior specification guidance (skeptical, informed, enthusiastic)
- Posterior interpretation framework
- Bayes factor interpretation scale (anecdotal < 3, moderate < 10, strong < 30, very strong < 100, decisive)
- Credible interval vs confidence interval distinction

### Signal Generation (Prompt-Based)

Current Python signals → prompt-based equivalents:
- **Entropy**: LLM self-assessed complexity of its own reasoning (0-1)
- **Dissonance**: LLM detection of internal contradictions (0-1)
- **Confidence**: Evidence-grounded certainty from calibration stage (already LLM)
- **Health**: Derived from entropy + dissonance (simple TS formula kept)
- **Focus plan**: Depth/temperature scaling based on above signals (TS formula kept)

### Documentation Updates

**Files to update:**
- `README.md` — New architecture description (note-taking + research app with AI reasoning)
- `PROJECT_SUMMARY.md` — Remove Python engine references
- `RESEARCH_OVERVIEW.md` — Update signal descriptions
- `FRONTEND_SPEC.md` — Remove Analytics Engine tier dependencies
- `USER_GUIDE.md` — Remove Python setup instructions, `:learn` command
- `FEEDBACK_LOOP.md` — Reframe as prompt-based self-improvement
- `paper.md` — Add note that mathematical implementation lives in meta-analytical-pipeline

---

## Success Criteria

1. `meta-analytical-pipeline` is a standalone project that someone can clone, install, and run
2. `meta-analytical-pfc` has zero Python files, zero Python dependencies, zero dead references
3. All 10 pipeline stages work via prompts with equivalent analytical depth
4. Daemon agents function as background note-learning systems
5. No dead code, no ghost imports, no orphaned UI elements
6. All documentation accurately reflects current architecture
