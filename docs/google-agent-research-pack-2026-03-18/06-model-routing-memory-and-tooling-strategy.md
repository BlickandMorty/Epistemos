# Model Routing, Memory, And Tooling Strategy

This is the key strategic question: how to get agents that feel powerful, not fake.

## Core Recommendation

Use a **hybrid intelligence stack**, not local-only and not API-only.

Recommended order:

1. Apple Intelligence for trivial on-device work
2. MLX local models for lightweight reasoning, summarization, extraction, compaction, and retrieval prep
3. frontier API models for the hardest planning, writing, and multi-step tool-using tasks

## Why Local-Only Is Not Enough

If the goal is to match the feeling of strong agent products, local-only will probably underperform for:

- hard planning
- multi-step research
- long-horizon tool loops
- final writing quality
- nuanced essay generation

Local models are still very valuable for:

- instant triage
- cheap background enrichment
- fast note transforms
- memory compaction
- classification
- suggestion generation

## Recommended Role Split

### Apple Intelligence

Use for:

- trivial rewrites
- short summaries
- lightweight note operations
- latency-sensitive tiny tasks

### MLX local Qwen / Gemma

Use for:

- task classification
- note enrichment drafts
- compaction and memory summaries
- proactive note suggestions
- graph / note retrieval preparation
- medium-complexity writing transforms

### Cloud frontier models

Use for:

- difficult research plans
- tool-using autonomous loops
- best-quality essay writing
- high-stakes synthesis
- long-horizon reasoning

## What Makes Agents Feel Strong

The strongest agent feeling usually comes more from:

- tool quality
- retrieval quality
- memory quality
- approval UX
- writeback safety
- session continuity
- model routing

than from any one "agent framework."

## Recommended Memory Shape

The old three-tier framing is still useful:

- **working memory**
  - current task context
  - live todo / step list
- **episodic memory**
  - previous sessions
  - prior actions
  - prior outputs
- **semantic memory**
  - search, retrieval, graph grounding, note relationships

But V1 should stay pragmatic:

- keep working memory simple
- keep episodic memory auditable
- let the app's graph, search index, and note corpus do most of the semantic grounding

## Recommended Tooling Shape

The best first tool families are likely:

- note read / note update / note create
- graph query / graph search
- search index search
- research lookup
- note enrichment trigger
- safe file-backed vault operations

Important engineering requirements:

- explicit tool schemas
- approval gates for destructive writes
- cancellable steps
- token / step budget
- durable action log
- replayable session history

## Practical Read

If you want the app to feel as strong as the best API-backed agent tools:

- do not chase "fully local" purity
- do use local models where they help cost, latency, and ambient intelligence
- do use frontier APIs for the hard parts

