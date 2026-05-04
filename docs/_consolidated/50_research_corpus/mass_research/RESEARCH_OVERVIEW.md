# Meta-Analytical PFC — Research Overview

This system is a research-oriented AI reasoning framework that structures LLM behavior through analytical pipelines, computes heuristic signals, and provides steering controls for tuning inference quality.

## What It Does

1. Routes queries by complexity and domain via triage analysis.
2. Runs specialized reasoning stages through structured prompt templates encoding mathematical frameworks (Bradford Hill, Cohen's d, DerSimonian-Laird, Bayesian updating).
3. Computes heuristic signals (confidence, entropy, dissonance, health) from query properties.
4. Translates user steering settings into behavioral LLM directives via the prompt composer.
5. Runs background agents that auto-learn from your notes.
6. Provides a dual-layer response: research-grade analysis + accessible layman summary.

## Why It Matters

The system makes AI reasoning structured, inspectable, and tunable:
- **Structured** — forces the LLM through formal analytical frameworks rather than free-form generation.
- **Inspectable** — every stage produces visible signals (confidence, entropy, dissonance) and tagged output.
- **Tunable** — the steering engine lets you adjust how the LLM reasons, not just what it produces.

## Signal System

All signals are **heuristic functions** of query properties (domain, complexity, entity count) and user steering settings. They are not calibrated probabilities or information-theoretic measures — they provide useful relative rankings for UI display and steering.

| Signal | What It Represents | Range |
|--------|-------------------|-------|
| **Confidence** | Evidence-grounded certainty estimate | 0.1 – 0.95 |
| **Entropy** | Query complexity / activation noise | 0.01 – 0.95 |
| **Dissonance** | Degree of internal tension between claims | 0.01 – 0.95 |
| **Health Score** | Weighted fusion: `1 - entropy×0.45 - dissonance×0.35` | 0.2 – 1.0 |
| **Risk Score** | Safety-sensitive query indicator | 0.01 – 0.9 |
| **Focus Depth** | Analytical depth scaling | 2 – 10 |
| **Temperature** | LLM exploration vs. determinism | 0.1 – 1.0 |

## Analytics Dashboard

The analytics page provides 8 sub-tabs:

- **Research Copilot** — methodology guidance and technique scaffolding
- **Cortex Archive** — saved brain-state snapshots as a card grid
- **Steering Lab** — live parameter sliders (complexity bias, adversarial intensity, Bayesian prior strength, focus depth, temperature)
- **Pipeline** — real-time 10-stage visualization with per-stage status and progress
- **Signals** — confidence, entropy, dissonance line charts over time
- **Visualizer** — interactive D3 charts: parallel coordinates, heat maps, smoothing, trendlines
- **Evaluate** — truth assessment / claim validity tool
- **Concepts** — concept hierarchy tree and weight visualization

## Prompt Template Architecture

The analytical stages (Statistical, Causal, Meta-Analysis, Bayesian) use structured prompt templates in `pfc-app/lib/engine/prompts/`. Each template encodes a formal analytical framework with:
- Specific rubrics and scoring criteria
- Mathematical threshold scales (e.g., Cohen's d: negligible < 0.2, small < 0.5, medium < 0.8, large)
- Output format tags (e.g., `[DATA]`, `[HILL]`, `[POOLED]`, `[PRIOR]`)
- Explicit instructions for what to evaluate and how

This approach means the LLM applies the same analytical rigor as formal statistical methods, but with contextual understanding of the actual research domain.

> **Note:** For numerical computation using these frameworks (actual DerSimonian-Laird pooling, Ripser TDA, etc.), see the standalone [`meta-analytical-pipeline`](../meta-analytical-pipeline) project.
