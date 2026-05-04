# Epistemos — Next 3 Major Features (Priority Order)

> **Index status**: SUPERSEDED-HISTORICAL — Older roadmap superseded by 04_PHASES.md.
> **Superseded by / Phase**: 04_PHASES.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## 1. Knowledge Fusion (Phases 2-10)
**Status**: Phase 0-1 complete (vault analyzer, classifier, boilerplate filter). Phases 2-10 deferred.
**Branch**: `feature/knowledge-fusion-v1` (current)
**What**: Complete the synthetic data pipeline that transforms 710+ vault notes into high-quality training data.
- Phase 2: Retrieval-augmented context windowing
- Phase 3: Synthetic QA pair generation from notes
- Phase 4: Tool-call trace generation (ODIA format)
- Phase 5: Multi-step reasoning trace synthesis
- Phase 6: macOS automation example generation
- Phase 7: Data mixing and quality filtering (40/20/20/20 composition)
- Phase 8: Export to training-ready format (HuggingFace datasets)
- Phase 9: On-device QLoRA fine-tuning pipeline (MLX)
- Phase 10: Evaluation harness (accuracy, JSON validity, reasoning drift)
**Why first**: This produces the training data that feeds Feature #2.

## 2. MOHAWK Model Training (Hybrid Mamba-Attention)
**Status**: TRAINING_GUIDE.md written. Config templates ready. No training started.
**What**: Train a custom Epistemos model using MOHAWK 3-stage distillation.
- Hybrid Mamba-Attention architecture (75% Mamba, 25% Attention)
- Teacher: Llama 3.1 8B → Student: Epistemos-Base 3B
- 3 stages: Matrix Orientation → Hidden-State Alignment → Knowledge Distillation
- ~12B tokens total, ~$1,500-2,500 on RunPod (8x A100)
- Quantize to 4-bit for on-device inference via MLX
- MoLoRA routing: multiple LoRA adapters for different task domains
**Why second**: Purpose-built model >> generic Qwen for agent planning.
**Depends on**: Knowledge Fusion training data (Feature #1).

## 3. Agent Orchestration Overhaul (Omega v2)
**Status**: Research prompt written (docs/OMEGA_DEEP_RESEARCH_PROMPT.md). Current Omega works for basic tasks.
**What**: Rebuild orchestration using best patterns from OpenClaw, NemoClaw, CoPaw, and others.
- Constrained decoding for guaranteed valid JSON plans
- ReAct observe-think-act loop with AX tree as observation
- Re-planning after failures (not just retry)
- Parallel step execution for independent tasks
- Screen2AX visual grounding (VLM fallback when AX tree sparse)
- Episodic memory + skill library (Voyager pattern)
- Multi-app workflow chaining
- Natural language macro recording
**Why third**: Benefits massively from better model (Feature #2) and better data (Feature #1).
**Depends on**: Custom trained model for reliable planning.

---

## Timeline Estimate
| Feature | Duration | Prerequisites |
|---------|----------|---------------|
| Knowledge Fusion | 2-3 sessions | None (Phase 0-1 done) |
| MOHAWK Training | 1 session setup + 3-5 days GPU | KF training data |
| Agent Overhaul | 3-4 sessions | Trained model + deep research results |
