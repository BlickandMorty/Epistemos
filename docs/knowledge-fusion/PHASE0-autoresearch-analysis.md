# Phase 0: Autoresearch Loop Analysis

Source: /Users/jojo/Downloads/autoresearch-master

## Core Loop Pattern

1. **Propose:** AI agent edits train.py with one experimental change (hyperparameter, architecture, optimizer config)
2. **Commit:** git commit the modification
3. **Train:** Run `uv run train.py > run.log 2>&1` with fixed 5-minute wall-clock budget
4. **Evaluate:** Extract `val_bpb` (validation bits per byte) from run.log
5. **Keep/Discard:** If val_bpb improved → keep commit (branch advances). If equal/worse → `git reset --hard HEAD~1`
6. **Log:** Append to results.tsv (untracked): commit, val_bpb, memory_gb, status, description
7. **Repeat:** Loop indefinitely until manually stopped

## Training Budget

- Fixed 300 seconds (5 minutes) of actual training time (wall-clock)
- Steps 1-10 excluded as warmup (compilation overhead)
- Timing starts at step 11, stops when cumulative time >= TIME_BUDGET
- ~950 optimizer steps on H100, ~499.6M tokens per experiment

## Evaluation Metric

- `val_bpb` = validation bits per byte (lower is better, vocab-size-independent)
- Computed via: sum per-token cross-entropy (nats) / (ln(2) × total target bytes)
- Fixed validation set (shard_06542.parquet), 20.97M evaluation tokens
- Special tokens (byte length 0) masked out

## Checkpointing

- Pure git-based: each experiment is a commit, kept or reset
- No model weight snapshots saved
- results.tsv is untracked, records all experiments
- Deterministic: same commit + same seed = same result

## Epistemos Adaptation Plan

| Autoresearch Pattern | Epistemos Adaptation |
|---------------------|---------------------|
| Edit train.py | Vary LoRA hyperparameters (rank, lr, replay_ratio, curriculum order) |
| 5-min wall-clock budget | 200 training iterations (~30 min) |
| val_bpb metric | Composite: Direct Probing × 0.5 + Indirect Probing × 0.3 + Style BERTScore × 0.2 |
| git commit/reset | ExperimentTracker with experiment_log.jsonl + best_config.json |
| Infinite loop | Runs during extended idle (>60min idle, plugged in), max 30min per iteration |
| results.tsv | experiments/experiment_log.jsonl (append-only JSON) |
