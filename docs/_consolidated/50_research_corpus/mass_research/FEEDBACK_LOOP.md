# Feedback Loop — Self-Improvement Architecture

The app improves its analytical behavior over time through two mechanisms: the **steering engine** and **background learning agents**.

## Steering Engine (Active Learning)

The 3-layer hybrid steering engine is the primary self-improvement mechanism:

### Layer 1: Contrastive Vectors
- Stores positive and negative exemplars from user feedback
- Computes: `mean(positive_exemplars) - mean(negative_exemplars)` → steering direction
- Confidence weighted by exemplar count and separation magnitude

### Layer 2: Bayesian Prior Adaptation
- Beta(α, β) priors per dimension, updated on each outcome
- Learning rate: `0.5 × 0.99^sampleCount` (slows as data accumulates)
- Converts prior distributions to biases via deviation from neutral (0.5)

### Layer 3: Contextual k-NN Recall
- Finds k nearest positive exemplars by query feature similarity
- Computes centroid of their signal vectors
- Context bias = `(centroid - globalMean) × contextMatchScore`

### Combined Output
```
finalBias = w1·contrastive + w2·bayesian + w3·contextual
steeringStrength = min(1.0, sqrt(totalExemplars / 20))
```

The prompt composer then translates these numerical biases into natural-language behavioral directives injected into the LLM system prompt.

## Background Learning Agents (Passive Learning)

The daemon's 5 background tasks provide passive improvement:

1. **Connection Finder** — discovers implicit relationships between notes, enriching the knowledge graph
2. **Auto-Organizer** — tags and clusters notes, improving retrieval quality
3. **Research Assistant** — identifies knowledge gaps, prompting deeper investigation
4. **Learning Protocol** — runs a 7-step recursive learning loop:
   - Inventory → Gap Analysis → Deep Dive → Cross-Reference → Synthesis → Questions → Iterate

## How It Works Together

```
User asks question
  ↓
Steering engine applies learned biases to prompt composition
  ↓
Pipeline runs with tuned analytical prompts
  ↓
User provides implicit feedback (follow-up questions, corrections, ratings)
  ↓
Steering engine updates exemplars and priors
  ↓
Next query benefits from updated steering
```

The system gets better at analytical reasoning for *your* specific research domain over time, without any model fine-tuning — purely through prompt-level behavioral adaptation.

## Implementation

- Steering engine: `pfc-app/lib/engine/steering/engine.ts` (479 lines)
- Prompt composer: `pfc-app/lib/engine/steering/prompt-composer.ts` (282 lines)
- Exemplar storage: `pfc-app/lib/engine/steering/memory.ts`
- Feedback evaluation: `pfc-app/lib/engine/steering/feedback.ts`
- Daemon tasks: `pfc-app/daemon/tasks/`
