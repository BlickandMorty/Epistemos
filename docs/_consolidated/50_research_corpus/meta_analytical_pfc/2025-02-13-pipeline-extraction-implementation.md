# Pipeline Extraction & App Refactor — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the entire Python analytical pipeline into a standalone portfolio project (meta-analytical-pipeline), then refactor the app (meta-analytical-pfc) to prompt-only reasoning with zero dead code.

**Architecture:** Two-project split. Project 1 is a pip-installable Python library with FastAPI service layer containing all mathematical reasoning, TDA, monitoring, learning, and validation modules. Project 2 is the refactored Next.js app that replaces Python compute with structured prompt templates while keeping daemon agents, steering, and ChromaDB.

**Tech Stack:** Python 3.10+, FastAPI, PyTorch, Ripser, SciPy, NumPy, NetworkX, ChromaDB, sentence-transformers (pipeline); Next.js 16, TypeScript, Zustand, SQLite/Drizzle, Vercel AI SDK (app)

---

## Phase 1: Create Standalone Pipeline Project

### Task 1: Scaffold the project structure

**Files:**
- Create: `/Users/jojo/meta-analytical-pipeline/pyproject.toml`
- Create: `/Users/jojo/meta-analytical-pipeline/Makefile`
- Create: `/Users/jojo/meta-analytical-pipeline/LICENSE`
- Create: `/Users/jojo/meta-analytical-pipeline/.gitignore`

**Step 1: Initialize git repo and create project root**

```bash
mkdir -p /Users/jojo/meta-analytical-pipeline
cd /Users/jojo/meta-analytical-pipeline
git init
```

**Step 2: Create pyproject.toml**

```toml
[build-system]
requires = ["setuptools>=68.0", "wheel"]
build-backend = "setuptools.backends._legacy:_Backend"

[project]
name = "meta-analytical-pipeline"
version = "1.0.0"
description = "A 10-stage meta-analytical reasoning pipeline with topological data analysis, Bayesian inference, causal DAG construction, and self-improving learning — built as a biomimetic prefrontal cortex for LLMs."
readme = "README.md"
license = {text = "MIT"}
requires-python = ">=3.10"
authors = [{name = "jojo"}]
keywords = ["meta-analysis", "bayesian-inference", "causal-inference", "topological-data-analysis", "NLP", "LLM"]
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Science/Research",
    "Topic :: Scientific/Engineering :: Artificial Intelligence",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
]

dependencies = [
    "numpy>=1.24.0",
    "scipy>=1.10.0",
    "pyyaml>=6.0",
    "loguru>=0.7.0",
    "scikit-learn>=1.3.0",
    "python-dotenv>=1.0.0",
    "tqdm>=4.65.0",
    "networkx>=3.0",
]

[project.optional-dependencies]
api = ["anthropic>=0.34.0", "sentence-transformers>=2.2.2", "chromadb>=0.4.0"]
local = ["torch>=2.0.0", "transformers>=4.40.0", "accelerate>=0.30.0", "sentencepiece>=0.1.99", "huggingface-hub>=0.23.0"]
tda = ["ripser>=0.6.4"]
server = ["fastapi>=0.110.0", "uvicorn>=0.29.0"]
plots = ["matplotlib>=3.8.0"]
dev = ["pytest>=7.0.0", "pytest-cov>=4.0.0", "ruff>=0.4.0"]
all = ["meta-analytical-pipeline[api,local,tda,server,plots,dev]"]

[project.urls]
Homepage = "https://github.com/jojo/meta-analytical-pipeline"
Documentation = "https://github.com/jojo/meta-analytical-pipeline/tree/main/docs"

[project.scripts]
map-serve = "server.app:main"
map-train = "training.prepare_data:main"

[tool.setuptools.packages.find]
include = ["meta_analytical_pipeline*", "server*", "training*"]

[tool.ruff]
line-length = 120
target-version = "py310"

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
```

**Step 3: Create Makefile**

```makefile
.PHONY: install dev test lint serve clean

install:
	pip install -e .

dev:
	pip install -e ".[all]"

test:
	pytest tests/ -v --tb=short

lint:
	ruff check meta_analytical_pipeline/ server/ training/

serve:
	uvicorn server.app:create_app --factory --reload --host 0.0.0.0 --port 8000

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null; true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null; true
	rm -rf build/ dist/ *.egg-info
```

**Step 4: Create .gitignore**

Standard Python .gitignore plus: `data/`, `*.egg-info/`, `dist/`, `build/`, `.env`, `__pycache__/`, `.pytest_cache/`, `*.pyc`

**Step 5: Create LICENSE (MIT)**

**Step 6: Commit**

```bash
git add -A && git commit -m "chore: scaffold project structure"
```

---

### Task 2: Copy all Python source modules into library

**Files:**
- Create: `/Users/jojo/meta-analytical-pipeline/meta_analytical_pipeline/` (entire library)

**Step 1: Create the library directory structure**

```bash
mkdir -p meta_analytical_pipeline/{core,reasoning,topology,monitoring,control,learning,validation,config}
```

**Step 2: Copy all source files from meta-analytical-pfc/src/ with new module paths**

Copy each file, updating internal imports from `src.X` to `meta_analytical_pipeline.X`:

| Source (meta-analytical-pfc) | Destination (meta-analytical-pipeline) |
|---|---|
| `src/__init__.py` | `meta_analytical_pipeline/__init__.py` (rewrite as public API) |
| `src/core/types.py` | `meta_analytical_pipeline/core/types.py` |
| `src/core/triage.py` | `meta_analytical_pipeline/core/triage.py` |
| `src/core/memory.py` | `meta_analytical_pipeline/core/memory.py` |
| `src/core/pfc_engine.py` | `meta_analytical_pipeline/core/engine.py` |
| `src/core/adaptive_pfc.py` | `meta_analytical_pipeline/core/adaptive.py` |
| `src/reasoning/statistical_analyzer.py` | `meta_analytical_pipeline/reasoning/statistical.py` |
| `src/reasoning/causal_inference.py` | `meta_analytical_pipeline/reasoning/causal.py` |
| `src/reasoning/meta_analysis.py` | `meta_analytical_pipeline/reasoning/meta_analysis.py` |
| `src/reasoning/bayesian_reasoner.py` | `meta_analytical_pipeline/reasoning/bayesian.py` |
| `src/tda/tda_pipeline.py` | `meta_analytical_pipeline/topology/tda_pipeline.py` |
| `src/tda/activation_capture.py` | `meta_analytical_pipeline/topology/activation_capture.py` |
| `src/monitoring/concepts.py` | `meta_analytical_pipeline/monitoring/concepts.py` |
| `src/monitoring/signals.py` | `meta_analytical_pipeline/monitoring/signals.py` |
| `src/monitoring/telemetry.py` | `meta_analytical_pipeline/monitoring/telemetry.py` |
| `src/control/focus_controller.py` | `meta_analytical_pipeline/control/focus_controller.py` |
| `src/control/cae_engine.py` | `meta_analytical_pipeline/control/cae_engine.py` |
| `src/learning/executive_trace.py` | `meta_analytical_pipeline/learning/executive_trace.py` |
| `src/learning/pattern_detector.py` | `meta_analytical_pipeline/learning/pattern_detector.py` |
| `src/learning/training_generator.py` | `meta_analytical_pipeline/learning/training_generator.py` |
| `src/learning/feedback_loop.py` | `meta_analytical_pipeline/learning/feedback_loop.py` |
| `src/learning/model_updater.py` | `meta_analytical_pipeline/learning/model_updater.py` |
| `src/validation/adversarial_review.py` | `meta_analytical_pipeline/validation/adversarial_review.py` |
| `src/validation/confidence_calibration.py` | `meta_analytical_pipeline/validation/confidence_calibration.py` |
| `src/utils/config_loader.py` | `meta_analytical_pipeline/config/loader.py` |
| `src/dashboard/server.py` | (moves to `server/` — see Task 4) |

For every file: replace all `from src.` imports with `from meta_analytical_pipeline.` and `from config.` with `from meta_analytical_pipeline.config.`.

**Step 3: Create `__init__.py` files for each subpackage**

Each `__init__.py` should export the main classes from that subpackage.

**Step 4: Create the top-level `meta_analytical_pipeline/__init__.py`**

```python
"""
Meta-Analytical Pipeline — A 10-stage reasoning engine for research-grade AI analysis.

Modules:
    core        — Pipeline orchestrator, complexity triage, cross-chat memory
    reasoning   — Statistical, causal, meta-analytical, and Bayesian reasoning engines
    topology    — Topological data analysis via persistent homology (Ripser)
    monitoring  — Leibnizian concept harmonics, signal generation, telemetry
    control     — Continued-fraction focus controller, contextual allostasis safety
    learning    — Executive trace memory, pattern detection, training generation
    validation  — Adversarial review, confidence calibration
"""

__version__ = "1.0.0"

from meta_analytical_pipeline.core.engine import MetaAnalyticalPFC as Pipeline
from meta_analytical_pipeline.core.adaptive import AdaptivePFC
from meta_analytical_pipeline.core.triage import ComplexityTriage
from meta_analytical_pipeline.core.memory import CrossChatMemory
from meta_analytical_pipeline.reasoning.statistical import StatisticalAnalyzer
from meta_analytical_pipeline.reasoning.causal import CausalInferenceEngine
from meta_analytical_pipeline.reasoning.meta_analysis import MetaAnalysisEngine
from meta_analytical_pipeline.reasoning.bayesian import BayesianReasoner
from meta_analytical_pipeline.topology.tda_pipeline import compute_tda
from meta_analytical_pipeline.topology.activation_capture import ActivationCapture
from meta_analytical_pipeline.monitoring.concepts import ConceptRegistry
from meta_analytical_pipeline.monitoring.signals import compute_signals
from meta_analytical_pipeline.control.focus_controller import FocusController
from meta_analytical_pipeline.control.cae_engine import ContextualAllostasisEngine
from meta_analytical_pipeline.learning.executive_trace import ExecutiveTraceMemory
from meta_analytical_pipeline.learning.pattern_detector import PatternDetector
from meta_analytical_pipeline.learning.training_generator import TrainingGenerator
from meta_analytical_pipeline.learning.model_updater import ModelUpdater
from meta_analytical_pipeline.validation.adversarial_review import AdversarialReviewer
from meta_analytical_pipeline.validation.confidence_calibration import ConfidenceCalibrator

__all__ = [
    "Pipeline", "AdaptivePFC", "ComplexityTriage", "CrossChatMemory",
    "StatisticalAnalyzer", "CausalInferenceEngine", "MetaAnalysisEngine", "BayesianReasoner",
    "compute_tda", "ActivationCapture",
    "ConceptRegistry", "compute_signals",
    "FocusController", "ContextualAllostasisEngine",
    "ExecutiveTraceMemory", "PatternDetector", "TrainingGenerator", "ModelUpdater",
    "AdversarialReviewer", "ConfidenceCalibrator",
]
```

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: copy all reasoning modules with updated imports"
```

---

### Task 3: Copy config files and data directory stubs

**Files:**
- Copy: all YAML configs from `meta-analytical-pfc/config/` → `meta-analytical-pipeline/meta_analytical_pipeline/config/`
- Create: `meta_analytical_pipeline/config/defaults.py` (config loader with package-relative paths)
- Create: `data/` directory stubs with `.gitkeep`

**Step 1: Copy YAML configs**

Copy: `model_config.yaml`, `runtime.yaml`, `telemetry.yaml`, `local_model.yaml`, `cae.yaml`, `concepts.yaml`, `feedback.yaml`, `baselines.yaml`, `benchmark.yaml`

**Step 2: Create `defaults.py`** — config loader that resolves paths relative to the package, not CWD

```python
"""Package-relative config loading."""
from pathlib import Path
import yaml

CONFIG_DIR = Path(__file__).parent

def load_config(name: str) -> dict:
    """Load a YAML config by name (without extension)."""
    path = CONFIG_DIR / f"{name}.yaml"
    if not path.exists():
        raise FileNotFoundError(f"Config not found: {path}")
    with open(path) as f:
        return yaml.safe_load(f)
```

**Step 3: Create data directory stubs**

```bash
mkdir -p data/{memory,executive_traces,learned_knowledge,telemetry,feedback,evaluation,training}
touch data/{memory,executive_traces,learned_knowledge,telemetry,feedback,evaluation,training}/.gitkeep
```

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add config files and data directory stubs"
```

---

### Task 4: Copy training scripts

**Files:**
- Copy: `training/prepare_data.py` and `training/fine_tune_pfc.py` → `training/`
- Update imports

**Step 1: Copy and update**

Copy both files, updating imports from `src.learning.*` to `meta_analytical_pipeline.learning.*`.

Rename `fine_tune_pfc.py` → `fine_tune.py` for cleaner naming.

**Step 2: Commit**

```bash
git add -A && git commit -m "feat: add training scripts with updated imports"
```

---

### Task 5: Build the FastAPI server layer

**Files:**
- Create: `server/__init__.py`
- Create: `server/app.py` — factory + main
- Create: `server/schemas.py` — Pydantic request/response models
- Create: `server/middleware.py` — CORS, error handling
- Create: `server/routes/analyze.py` — POST /analyze (full pipeline)
- Create: `server/routes/statistical.py` — POST /statistical
- Create: `server/routes/causal.py` — POST /causal
- Create: `server/routes/bayesian.py` — POST /bayesian
- Create: `server/routes/meta_analysis.py` — POST /meta-analysis
- Create: `server/routes/tda.py` — POST /tda
- Create: `server/routes/signals.py` — POST /signals
- Create: `server/routes/concepts.py` — POST /concepts
- Create: `server/routes/learning.py` — POST /learn
- Create: `server/routes/health.py` — GET /health

**Step 1: Create Pydantic schemas** (`server/schemas.py`)

Define request/response models for each endpoint:
- `AnalyzeRequest(query, mode?, config?)` → `AnalysisResult(stages[], signals, truth_assessment, raw_analysis, layman_summary)`
- `StatisticalRequest(query, studies?[])` → `StatisticalResult(effect_sizes, power, significance, interpretation)`
- `CausalRequest(query, exposure, outcome)` → `CausalResult(dag, bradford_hill_scores, verdict, confidence)`
- `BayesianRequest(query, prior?, likelihood?)` → `BayesianResult(posterior, bayes_factor, credible_intervals)`
- `MetaAnalysisRequest(query, studies[])` → `MetaAnalysisResult(pooled_effect, i_squared, eggers_p, forest_data)`
- `TDARequest(model_name?, query)` → `TDAResult(betti_numbers, persistence_entropy, max_persistence, topology_graph)`
- `SignalRequest(query, reasoning_trace?)` → `SignalResult(entropy, dissonance, health, confidence, focus_plan)`
- `ConceptRequest(query)` → `ConceptResult(concepts[], chord_product, frequencies[], harmony_distance)`
- `LearnRequest(traces[])` → `LearnResult(patterns_detected, skills_learned[])`

**Step 2: Create route files**

Each route file instantiates the corresponding module and wraps it in a FastAPI endpoint with proper error handling and docstrings.

Example for `/analyze`:
```python
from fastapi import APIRouter, HTTPException
from server.schemas import AnalyzeRequest, AnalysisResult
from meta_analytical_pipeline import Pipeline

router = APIRouter()

@router.post("/analyze", response_model=AnalysisResult, summary="Run the full 10-stage analytical pipeline")
async def analyze(request: AnalyzeRequest):
    """Execute the complete meta-analytical reasoning pipeline on a research query."""
    try:
        pipeline = Pipeline()
        result = pipeline.analyze(request.query, mode=request.mode)
        return AnalysisResult.from_pipeline_result(result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

**Step 3: Create app factory** (`server/app.py`)

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from server.routes import analyze, statistical, causal, bayesian, meta_analysis, tda, signals, concepts, learning, health

def create_app() -> FastAPI:
    app = FastAPI(
        title="Meta-Analytical Pipeline",
        description="10-stage research reasoning engine with TDA, Bayesian inference, and causal analysis",
        version="1.0.0",
    )
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

    app.include_router(health.router, tags=["Health"])
    app.include_router(analyze.router, tags=["Analysis"])
    app.include_router(statistical.router, tags=["Statistical"])
    app.include_router(causal.router, tags=["Causal"])
    app.include_router(bayesian.router, tags=["Bayesian"])
    app.include_router(meta_analysis.router, tags=["Meta-Analysis"])
    app.include_router(tda.router, tags=["TDA"])
    app.include_router(signals.router, tags=["Signals"])
    app.include_router(concepts.router, tags=["Concepts"])
    app.include_router(learning.router, tags=["Learning"])

    return app

def main():
    import uvicorn
    uvicorn.run("server.app:create_app", factory=True, host="0.0.0.0", port=8000, reload=True)

if __name__ == "__main__":
    main()
```

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add FastAPI server with all route endpoints"
```

---

### Task 6: Write the portfolio README

**Files:**
- Create: `/Users/jojo/meta-analytical-pipeline/README.md`

**Step 1: Write a comprehensive README with:**

- Project title and tagline
- Architecture diagram (ASCII)
- Feature highlights (10-stage pipeline, 4 reasoning engines, TDA, learning loop, safety state machine)
- Quickstart (pip install, library usage, server launch)
- API endpoint table with curl examples
- Mathematical foundations summary (Bradford Hill, DerSimonian-Laird, Bayesian conjugate priors, Ripser persistent homology, Leibnizian concept harmonics, continued-fraction focus control)
- Module-by-module description
- Tech stack badges

**Step 2: Commit**

```bash
git add -A && git commit -m "docs: add portfolio README with architecture and API docs"
```

---

### Task 7: Write module documentation

**Files:**
- Create: `docs/architecture.md`
- Create: `docs/mathematical-foundations.md`
- Create: `docs/api-reference.md`
- Create: `docs/quickstart.md`

**Step 1: `architecture.md`** — System architecture with data flow diagram showing how the 10 stages connect, how signals feed into focus control, how TDA connects to activation capture, how learning traces feed back into prompt augmentation.

**Step 2: `mathematical-foundations.md`** — The math behind each module:
- Statistical: Cohen's d, power analysis formulas, MCID thresholds
- Causal: Bradford Hill 9 criteria, DAG formalism, counterfactual framework
- Meta-Analysis: DerSimonian-Laird estimator, I² derivation, Egger's regression
- Bayesian: Conjugate normal updating, Bayes factor computation, credible intervals
- TDA: Persistent homology, Betti numbers, persistence entropy formula
- Concepts: Leibnizian prime encoding, chord product, dissonance evaluation
- Control: Continued-fraction expansion, focus plan derivation

**Step 3: `api-reference.md`** — Full endpoint documentation with request/response schemas and examples.

**Step 4: `quickstart.md`** — Getting started in <5 minutes.

**Step 5: Commit**

```bash
git add -A && git commit -m "docs: add architecture, math foundations, API reference, quickstart"
```

---

### Task 8: Write tests

**Files:**
- Create: `tests/test_reasoning/test_statistical.py`
- Create: `tests/test_reasoning/test_causal.py`
- Create: `tests/test_reasoning/test_bayesian.py`
- Create: `tests/test_reasoning/test_meta_analysis.py`
- Create: `tests/test_monitoring/test_concepts.py`
- Create: `tests/test_monitoring/test_signals.py`
- Create: `tests/test_control/test_focus_controller.py`
- Create: `tests/test_core/test_triage.py`

**Step 1: Write tests for each reasoning module**

Test the core mathematical computations:
- Statistical: effect size interpretation, power calculation
- Causal: Bradford Hill scoring, DAG construction
- Bayesian: posterior calculation, Bayes factor
- Meta-Analysis: pooled effect, I² computation, Egger's test
- Concepts: chord product, dissonance rules
- Signals: signal bundle generation
- Focus: depth/temperature scaling
- Triage: complexity routing

**Step 2: Run tests**

```bash
pytest tests/ -v
```

**Step 3: Commit**

```bash
git add -A && git commit -m "test: add unit tests for all reasoning modules"
```

---

## Phase 2: Refactor the App (meta-analytical-pfc)

### Task 9: Delete Python source, training, configs, and data

**Files:**
- Delete: `/Users/jojo/meta-analytical-pfc/src/` (entire directory)
- Delete: `/Users/jojo/meta-analytical-pfc/training/` (entire directory)
- Delete: `/Users/jojo/meta-analytical-pfc/config/` (entire directory)
- Delete: `/Users/jojo/meta-analytical-pfc/data/` (entire directory)
- Delete: `/Users/jojo/meta-analytical-pfc/requirements.txt`
- Delete: `/Users/jojo/meta-analytical-pfc/setup.py`
- Delete: `/Users/jojo/meta-analytical-pfc/src/` `__pycache__` dirs
- Delete: Any `.pyc` files
- Delete: Any Python-related root scripts (`run_pfc.ps1`, `run_learning_demo.py`, etc. if they exist)

**Step 1: Remove files**

```bash
cd /Users/jojo/meta-analytical-pfc
rm -rf src/ training/ config/ data/ requirements.txt setup.py
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null; true
find . -name "*.pyc" -delete 2>/dev/null; true
```

**Step 2: Verify no Python files remain outside pfc-app/**

```bash
find . -name "*.py" -not -path "./pfc-app/*" -not -path "./.git/*"
```

Expected: empty output.

**Step 3: Commit**

```bash
git add -A && git commit -m "refactor: remove Python pipeline (extracted to meta-analytical-pipeline)"
```

---

### Task 10: Update Settings page — remove TDA/training references

**Files:**
- Modify: `/Users/jojo/meta-analytical-pfc/pfc-app/app/settings/page.tsx`

**Step 1: Update Suite Tier descriptions**

Change the third tier from `'Full AI & Measurement', desc: '+ Pipeline, signals, TDA'` to `'Full AI & Measurement', desc: '+ Pipeline, signals, deep analysis'`.

**Step 2: Update Analytics Engine description**

Change the subtitle from `"Signal computation, TDA, steering, SOAR"` to `"Signal computation, steering, SOAR"`.

**Step 3: Update the "Analytics Disabled" warning text**

Change `"Signal computation, TDA topology analysis, steering directives, and SOAR meta-reasoning are all disabled."` to `"Signal computation, steering directives, and SOAR meta-reasoning are all disabled. The AI chat will still work but without analytical pipeline processing — responses will not include confidence scores, evidence grades, or epistemic tags."`

**Step 4: Update the "What the analytics engine does" bullet points**

Replace the "Structural Complexity" bullet:
- From: `"Heuristic metrics (labeled TDA β₀, β₁) derived from entity count and complexity. These provide useful relative rankings but are not real persistent homology computations."`
- To: `"Heuristic structural metrics derived from entity count and complexity, providing useful relative rankings for query categorization."`

**Step 5: Update the "Computation honesty note"**

Remove all references to TDA. Update text to reflect prompt-only architecture:
- Remove: `"In simulation mode, the analysis text is template-generated with illustrative statistics."`
- Keep but update the honest signaling about heuristic nature.

**Step 6: Commit**

```bash
cd /Users/jojo/meta-analytical-pfc && git add pfc-app/app/settings/page.tsx && git commit -m "refactor: remove TDA/training references from settings UI"
```

---

### Task 11: Update simulate.ts signal generation comments

**Files:**
- Modify: `/Users/jojo/meta-analytical-pfc/pfc-app/lib/engine/simulate.ts`

**Step 1: Update the `generateSignals` JSDoc (around line 855-869)**

Remove references to TDA. The signals are already heuristic functions that don't depend on Python — this is just comment cleanup. Update:
- Remove: `"topological data analysis"` from the NOT-derived-from list
- Remove: `"TDA computation"` references in analytics engine comments
- Keep all the actual signal computation code (it's pure TypeScript and works fine)

**Step 2: Update the `betti0`/`betti1` variable comments (around line 878-883)**

Change from referencing "TDA invariants" to just "structural complexity heuristics":
- From: `"Structural complexity heuristics (named after TDA invariants but computed as simple functions of query properties, NOT real persistent homology)"`
- To: `"Structural complexity heuristics — simple functions of query properties that produce useful relative rankings for steering and display"`

**Step 3: Commit**

```bash
git add pfc-app/lib/engine/simulate.ts && git commit -m "refactor: update signal generation comments to reflect prompt-only architecture"
```

---

### Task 12: Create prompt templates for analytical stages

**Files:**
- Create: `/Users/jojo/meta-analytical-pfc/pfc-app/lib/engine/prompts/statistical.ts`
- Create: `/Users/jojo/meta-analytical-pfc/pfc-app/lib/engine/prompts/causal.ts`
- Create: `/Users/jojo/meta-analytical-pfc/pfc-app/lib/engine/prompts/meta-analysis.ts`
- Create: `/Users/jojo/meta-analytical-pfc/pfc-app/lib/engine/prompts/bayesian.ts`
- Create: `/Users/jojo/meta-analytical-pfc/pfc-app/lib/engine/prompts/index.ts`

These encode the mathematical frameworks as structured prompts that guide the LLM to reason with the same rigor as the Python compute modules.

**Step 1: Create `statistical.ts`**

```typescript
/**
 * Statistical analysis prompt template.
 * Encodes the same analytical frameworks as the Python StatisticalAnalyzer:
 * Cohen's d interpretation, power analysis, MCID thresholds, bias detection.
 */
export function buildStatisticalPrompt(query: string, context?: string): string {
  return `You are a PhD-level biostatistician performing a rigorous statistical evaluation.

QUERY: ${query}
${context ? `PRIOR CONTEXT:\n${context}\n` : ''}
ANALYTICAL FRAMEWORK — apply ALL of the following:

1. EFFECT SIZE INTERPRETATION (Cohen's d scale):
   - Negligible: |d| < 0.20
   - Small: 0.20 ≤ |d| < 0.50
   - Medium: 0.50 ≤ |d| < 0.80
   - Large: |d| ≥ 0.80
   If effect sizes are reported or can be estimated, classify and interpret them.

2. STATISTICAL POWER ASSESSMENT:
   - Adequate power: ≥ 0.80 (β = 0.20)
   - Minimum detectable effect given sample size
   - Whether the study is underpowered for the claimed effects

3. CLINICAL/PRACTICAL SIGNIFICANCE:
   - Does the effect cross the Minimum Clinically Important Difference (MCID)?
   - Statistical significance ≠ practical importance
   - Number Needed to Treat (NNT) if applicable

4. BIAS DETECTION:
   - Publication bias indicators (file drawer problem)
   - p-hacking risk (p-values clustering just below 0.05)
   - Multiple comparisons without correction
   - Selective reporting of outcomes

5. CONFIDENCE INTERVAL ANALYSIS:
   - Width relative to effect size (precision)
   - Whether CI crosses zero or MCID threshold
   - Asymmetry suggesting skewed distributions

OUTPUT FORMAT:
[DATA] Key statistical findings with specific numbers
[POWER] Power assessment and sample adequacy
[CLINICAL] Practical significance evaluation
[BIAS] Identified sources of bias or methodological concern
[INTERPRETATION] Overall statistical verdict with caveats`;
}
```

**Step 2: Create `causal.ts`**

```typescript
/**
 * Causal inference prompt template.
 * Encodes Bradford Hill criteria, DAG reasoning, counterfactual framework.
 */
export function buildCausalPrompt(query: string, context?: string): string {
  return `You are an epidemiologist evaluating causal claims using formal frameworks.

QUERY: ${query}
${context ? `PRIOR CONTEXT:\n${context}\n` : ''}
ANALYTICAL FRAMEWORK — apply ALL of the following:

1. BRADFORD HILL CRITERIA (score each 0.0–1.0):
   - Strength: How large is the association?
   - Consistency: Replicated across populations/settings?
   - Specificity: Does the exposure specifically predict this outcome?
   - Temporality: Does exposure precede outcome? (Required for causation)
   - Biological gradient: Dose-response relationship?
   - Plausibility: Mechanistically coherent?
   - Coherence: Consistent with broader knowledge?
   - Experiment: Supported by experimental/quasi-experimental evidence?
   - Analogy: Similar cause-effect relationships known?

2. STUDY DESIGN HIERARCHY:
   - RCT > Prospective Cohort > Retrospective Cohort > Case-Control > Cross-Sectional > Case Report
   - What study designs inform this question? What's the highest quality evidence?

3. CONFOUNDING ANALYSIS:
   - Identify plausible confounders (common causes of exposure and outcome)
   - Assess whether studies controlled for key confounders
   - Residual confounding risk

4. COUNTERFACTUAL REASONING:
   - What would happen if the exposure were removed?
   - Is the counterfactual well-defined and testable?

5. DAG NARRATIVE:
   - Describe the causal pathway: Exposure → [Mediators] → Outcome
   - Identify backdoor paths (confounding pathways)
   - Describe what would need to be conditioned on

OUTPUT FORMAT:
[DESIGN] Study design assessment
[HILL] Bradford Hill criteria evaluation (score each criterion)
[CONFOUNDERS] Identified confounders and control adequacy
[DAG] Causal pathway narrative
[VERDICT] Causal verdict: Likely causal | Possibly causal | Insufficient evidence | Likely non-causal`;
}
```

**Step 3: Create `meta-analysis.ts`**

```typescript
/**
 * Meta-analysis prompt template.
 * Encodes DerSimonian-Laird concepts, heterogeneity interpretation, publication bias.
 */
export function buildMetaAnalysisPrompt(query: string, context?: string): string {
  return `You are a meta-analyst evaluating the totality of evidence across studies.

QUERY: ${query}
${context ? `PRIOR CONTEXT:\n${context}\n` : ''}
ANALYTICAL FRAMEWORK — apply ALL of the following:

1. STUDY SYNTHESIS:
   - How many studies inform this question?
   - What are the individual effect estimates?
   - Would a fixed-effects or random-effects model be appropriate?
   - Random-effects (DerSimonian-Laird) is preferred when studies differ in populations, methods, or settings.

2. HETEROGENEITY ASSESSMENT (I² scale):
   - Low: I² < 25% — studies show consistent results
   - Moderate: 25% ≤ I² < 50% — some variation between studies
   - Substantial: 50% ≤ I² < 75% — considerable variation
   - Considerable: I² ≥ 75% — pooling may not be meaningful
   - What sources explain the heterogeneity? (population, intervention, measurement, risk of bias)

3. PUBLICATION BIAS:
   - Funnel plot asymmetry (conceptual): Would small negative studies be missing?
   - Egger's test concept: Is there systematic bias in smaller studies?
   - Grey literature: Were unpublished studies considered?
   - Language bias: English-only searches?

4. SENSITIVITY ANALYSIS:
   - Would removing any single study change the conclusion?
   - Are results robust to different analytical assumptions?
   - Subgroup analyses: Do effects differ by key moderators?

5. EVIDENCE GRADING (GRADE framework concepts):
   - High / Moderate / Low / Very Low certainty
   - Downgrade for: risk of bias, inconsistency, indirectness, imprecision, publication bias
   - Upgrade for: large effect, dose-response, plausible confounding

OUTPUT FORMAT:
[STUDIES] Overview of available evidence
[POOLED] Pooled effect estimate and direction
[HETEROGENEITY] I² interpretation and sources
[BIAS] Publication bias assessment
[GRADE] Evidence certainty and overall conclusion`;
}
```

**Step 4: Create `bayesian.ts`**

```typescript
/**
 * Bayesian reasoning prompt template.
 * Encodes prior specification, posterior interpretation, Bayes factor scale.
 */
export function buildBayesianPrompt(query: string, context?: string): string {
  return `You are a Bayesian statistician updating beliefs with evidence.

QUERY: ${query}
${context ? `PRIOR CONTEXT:\n${context}\n` : ''}
ANALYTICAL FRAMEWORK — apply ALL of the following:

1. PRIOR SPECIFICATION:
   - What was the prior belief before this evidence? Specify:
     - Skeptical prior (centered at null, wide): appropriate when claim is extraordinary
     - Informed prior (centered at previous estimates): appropriate when prior literature exists
     - Enthusiastic prior (centered at expected effect): appropriate when mechanism is well-understood
   - Justify your prior choice.

2. LIKELIHOOD ASSESSMENT:
   - How strongly does the new evidence support the hypothesis vs. the null?
   - What is the likelihood ratio?
   - How much should the evidence shift our beliefs?

3. POSTERIOR INTERPRETATION:
   - After updating, what is the revised belief?
   - 95% credible interval: What range of values is most plausible?
   - How much did beliefs shift from prior to posterior?

4. BAYES FACTOR SCALE:
   - BF < 1: Evidence favors null hypothesis
   - BF 1–3: Anecdotal evidence
   - BF 3–10: Moderate evidence
   - BF 10–30: Strong evidence
   - BF 30–100: Very strong evidence
   - BF > 100: Decisive evidence

5. PRIOR SENSITIVITY:
   - Would a different prior change the conclusion?
   - At what prior would the conclusion flip?
   - Is the evidence strong enough to overwhelm reasonable priors?

OUTPUT FORMAT:
[PRIOR] Prior specification and justification
[EVIDENCE] Likelihood assessment
[POSTERIOR] Updated belief with credible interval
[BF] Bayes factor interpretation
[SENSITIVITY] How robust is the conclusion to prior choice?`;
}
```

**Step 5: Create `index.ts`**

```typescript
export { buildStatisticalPrompt } from './statistical';
export { buildCausalPrompt } from './causal';
export { buildMetaAnalysisPrompt } from './meta-analysis';
export { buildBayesianPrompt } from './bayesian';
```

**Step 6: Commit**

```bash
git add pfc-app/lib/engine/prompts/ && git commit -m "feat: add structured prompt templates for analytical reasoning stages"
```

---

### Task 13: Update all documentation files

**Files:**
- Modify: `/Users/jojo/meta-analytical-pfc/README.md`
- Modify: `/Users/jojo/meta-analytical-pfc/PROJECT_SUMMARY.md`
- Modify: `/Users/jojo/meta-analytical-pfc/RESEARCH_OVERVIEW.md`
- Modify: `/Users/jojo/meta-analytical-pfc/USER_GUIDE.md`
- Modify: `/Users/jojo/meta-analytical-pfc/FEEDBACK_LOOP.md`
- Modify: `/Users/jojo/meta-analytical-pfc/FRONTEND_SPEC.md`
- Modify: `/Users/jojo/meta-analytical-pfc/paper.md` (add note only)

**Step 1: Rewrite `README.md`**

Complete rewrite to describe the refactored app:
- Note-taking and research app with AI-powered analytical reasoning
- 10-stage prompt-based pipeline (no Python dependencies)
- Daemon background agents for auto-learning notes
- Steering engine translates mathematical frameworks into behavioral LLM directives
- Remove all Python setup instructions, conda environments, local model loading
- Add note: "The mathematical reasoning modules have been extracted into a standalone project: [meta-analytical-pipeline](link)"
- Keep: Next.js setup, Ollama integration, feature descriptions

**Step 2: Rewrite `PROJECT_SUMMARY.md`**

Remove Python engine references. Describe:
- 5 reasoning stages as prompt-based (statistical, causal, meta-analysis, Bayesian, adversarial)
- Steering engine (prompt-composer.ts)
- Daemon agents (5 background tasks)
- Note-taking system
- Research tools (Semantic Scholar integration)

**Step 3: Rewrite `RESEARCH_OVERVIEW.md`**

Remove:
- Dashboard panels referencing Python telemetry (WebSocket streaming, JSONL replay)
- TDA mapper, Leibnizian spectrogram descriptions that reference Python compute
- References to `localhost:8000` Python dashboard
Update:
- Signal descriptions to reflect heuristic computation
- Architecture to reflect prompt-only pipeline

**Step 4: Rewrite `USER_GUIDE.md`**

Remove:
- `./run_pfc.ps1` command
- `:learn` and `:skills` interactive commands
- Python smoke tests
- `localhost:8000` dashboard references
- Config file editing for YAML files that no longer exist
Add:
- `npm run dev` / `pnpm dev` startup
- Daemon start/stop instructions
- Settings page navigation guide

**Step 5: Rewrite `FEEDBACK_LOOP.md`**

Reframe as prompt-based self-improvement:
- The steering engine's 3-layer hybrid (contrastive + Bayesian priors + k-NN recall) IS the feedback loop
- Exemplars stored in steering memory, not Python traces
- Remove references to fine-tuning, dataset building, model weight updates

**Step 6: Update `FRONTEND_SPEC.md`**

Remove:
- Analytics Engine tier dependency on Python backend
- TDA-specific dashboard panels
- References to Python API endpoints
Update:
- Signal generation description (heuristic TS functions)
- Architecture diagram (no Python backend)

**Step 7: Add note to `paper.md`**

Add a brief note at the top: "NOTE: The mathematical implementations described in this paper have been extracted into a standalone project: meta-analytical-pipeline. The application (meta-analytical-pfc) now uses prompt-based reasoning informed by these mathematical frameworks."

Do NOT rewrite the paper — it's the academic documentation of the math and should stay as-is for the portfolio.

**Step 8: Commit**

```bash
git add README.md PROJECT_SUMMARY.md RESEARCH_OVERVIEW.md USER_GUIDE.md FEEDBACK_LOOP.md FRONTEND_SPEC.md paper.md && git commit -m "docs: update all documentation to reflect prompt-only architecture"
```

---

### Task 14: Grep and remove ALL remaining dead references

**Files:**
- Scan: entire `pfc-app/` directory

**Step 1: Search for dead references**

```bash
cd /Users/jojo/meta-analytical-pfc/pfc-app
# Search for Python/TDA/training references
grep -r "python" --include="*.ts" --include="*.tsx" -l
grep -r "TDA\|tda_pipeline\|topological\|persistent homology\|ripser\|Betti" --include="*.ts" --include="*.tsx" -l
grep -r "activation_capture\|ActivationCapture\|activation capture" --include="*.ts" --include="*.tsx" -l
grep -r "fine.tune\|fine_tune\|finetune\|training suite\|model training" --include="*.ts" --include="*.tsx" -l
grep -r "localhost:8000\|FastAPI\|uvicorn" --include="*.ts" --include="*.tsx" -l
grep -r "requirements\.txt\|setup\.py\|pip install" --include="*.ts" --include="*.tsx" --include="*.md" -l
grep -r "src/core\|src/reasoning\|src/tda\|src/monitoring\|src/learning" --include="*.ts" --include="*.tsx" -l
```

**Step 2: For each file found, remove or update the reference**

- If it's a comment mentioning TDA/Python: update the comment
- If it's an import: remove the import
- If it's UI text: update to reflect prompt-only architecture
- If it's a config reference: remove or redirect

**Step 3: Verify zero dead references**

Re-run all grep searches. Expected: zero results for Python backend references.

**Step 4: Commit**

```bash
git add -A && git commit -m "refactor: remove all dead references to Python pipeline"
```

---

### Task 15: Verify the app builds and runs

**Step 1: Build check**

```bash
cd /Users/jojo/meta-analytical-pfc/pfc-app
npm run build
```

Expected: Clean build with zero errors.

**Step 2: Fix any build errors from removed references**

If build fails, trace the errors to dead imports/references and fix.

**Step 3: Commit if fixes were needed**

```bash
git add -A && git commit -m "fix: resolve build errors from pipeline extraction"
```

---

### Task 16: Verify the standalone pipeline project

**Step 1: Install and test**

```bash
cd /Users/jojo/meta-analytical-pipeline
pip install -e ".[dev]"
pytest tests/ -v
```

**Step 2: Test the server**

```bash
make serve &
curl -X POST http://localhost:8000/health
curl -X POST http://localhost:8000/analyze -H "Content-Type: application/json" -d '{"query": "What is the effect of exercise on depression?"}'
```

**Step 3: Fix any import errors or missing dependencies**

**Step 4: Final commit**

```bash
git add -A && git commit -m "fix: resolve test and import issues"
```

---

## Phase 3: Final Cleanup

### Task 17: Final verification sweep

**Step 1: Confirm no Python in app**

```bash
cd /Users/jojo/meta-analytical-pfc
find . -name "*.py" -not -path "./.git/*" | wc -l
# Expected: 0
```

**Step 2: Confirm pipeline project is self-contained**

```bash
cd /Users/jojo/meta-analytical-pipeline
python -c "from meta_analytical_pipeline import Pipeline, StatisticalAnalyzer, compute_tda; print('All imports OK')"
```

**Step 3: Confirm app builds clean**

```bash
cd /Users/jojo/meta-analytical-pfc/pfc-app
npm run build 2>&1 | tail -5
# Expected: Build successful
```

**Step 4: Final commit on both repos**

```bash
cd /Users/jojo/meta-analytical-pipeline
git add -A && git commit -m "chore: final cleanup and verification"

cd /Users/jojo/meta-analytical-pfc
git add -A && git commit -m "chore: final cleanup — zero Python, zero dead code"
```

---

## Summary

| Phase | Tasks | What Happens |
|-------|-------|-------------|
| **Phase 1** | Tasks 1–8 | Standalone pipeline project created with all math, FastAPI routes, tests, docs |
| **Phase 2** | Tasks 9–15 | App refactored: Python deleted, settings cleaned, prompts created, docs updated, dead code removed |
| **Phase 3** | Tasks 16–17 | Both projects verified working independently |

**Total estimated tasks:** 17
**Key constraint:** Every file deleted from the app must have its references cleaned. Every file copied to the pipeline must have its imports updated. Zero dead code in either project.
