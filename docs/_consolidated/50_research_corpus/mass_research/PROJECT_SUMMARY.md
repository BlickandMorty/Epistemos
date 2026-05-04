# Meta-Analytical PFC — Project Summary

A note-taking and research app with AI-powered analytical reasoning.

## Reasoning Pipeline

The app processes queries through a 10-stage analytical pipeline using structured prompt templates that encode mathematical frameworks:

1. **Statistical Analysis** — Cohen's d interpretation, power assessment, bias detection, clinical significance
2. **Causal Inference** — Bradford Hill criteria, DAG reasoning, confounding analysis, counterfactual evaluation
3. **Meta-Analysis** — DerSimonian-Laird concepts, heterogeneity assessment (I²), publication bias, GRADE framework
4. **Bayesian Updating** — prior specification, posterior interpretation, Bayes factor scale, sensitivity analysis
5. **Adversarial Validation** — structured 5-point red-team self-critique

## Flow

1. Triage the query (complexity, domain, entities)
2. Retrieve relevant context from ChromaDB memory
3. Route to the appropriate analytical depth
4. Run analytical stages via structured LLM prompts
5. Synthesize evidence and generate dual-layer response (research + layman)
6. Adversarial self-critique and confidence calibration
7. Output answer + confidence + evidence grade

## Steering & Control

- **Prompt Composer** — translates user settings (sliders) into behavioral LLM directives
- **3-Layer Steering Engine** — contrastive vectors + Bayesian priors + k-NN recall
- **SOAR** — Self-Optimizing Analytical Reasoning for hard queries

## Background Agents (Daemon)

5 autonomous tasks that learn from your notes:
- Connection Finder, Daily Brief, Auto-Organizer, Research Assistant, Learning Protocol

## Key Entry Points

- `pfc-app/lib/engine/simulate.ts` — 10-stage pipeline orchestrator
- `pfc-app/lib/engine/prompts/` — structured analytical prompt templates
- `pfc-app/lib/engine/steering/prompt-composer.ts` — math-to-prompt translation
- `pfc-app/daemon/` — background agent system
- `pfc-app/app/(chat)/api/chat/route.ts` — main API endpoint

> **Note:** The standalone mathematical implementations (Python) live in the separate [`meta-analytical-pipeline`](../meta-analytical-pipeline) project.
