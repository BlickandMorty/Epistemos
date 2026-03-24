# Epistemos Knowledge Fusion Subsystem

On-device personal model adaptation via QLoRA fine-tuning on Apple Silicon.

## Overview

Knowledge Fusion teaches the local Qwen 3.5 model to absorb the user's personal knowledge, writing style, and tool preferences from their vault — entirely on-device, with no cloud dependency.

## Five Subsystems

1. **Data Ingestion Engine** — Parses markdown, PDF, and audio into normalized chunks
2. **Synthetic Data Generation** — Self-Instruct backtranslation produces JSONL training pairs
3. **QLoRA Fine-Tuning** — Parameter-efficient training with frozen 4-bit base + 16-bit LoRA
4. **KTO Preference Alignment** — Continuous learning from implicit accept/reject feedback
5. **Dynamic Adapter Routing** — Hot-swap adapters at inference time (never fuse)

## Key Constraints

- Training runs only during idle/overnight (never blocks typing)
- Adapters are hot-swapped, never permanently fused into base weights
- KTO (not DPO) for preference alignment (binary unpaired feedback)
- Markdown-header chunking (not naive recursive splitting)
- 10% experience replay buffer to prevent catastrophic forgetting

## Source of Truth

- Research paper: `On-Device-LLM-Knowledge-Fusion-Research.md`
- Architecture doc: `docs/knowledge-fusion/architecture.md`
