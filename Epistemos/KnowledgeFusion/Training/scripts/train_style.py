#!/usr/bin/env python3
"""
Epistemos Knowledge Fusion — Style Adapter Training Script

Trains a QLoRA adapter targeting ONLY attention layers for writing style
cloning. Does NOT target MLP layers to prevent hallucinating false facts
while imitating persona.

Source: Research paper "Optimal Hyperparameters" section.
  - rank=8, alpha=16
  - targets: q_proj, k_proj, v_proj, o_proj ONLY (no MLP)
  - lr=1e-5
  - WHY LOW RANK: Prevents hallucinating false facts while imitating persona.
    Low capacity = style only, no factual bleed.

CRITICAL (ANCHOR 3, GAP 1): This script NEVER fuses adapters into base weights.
Adapters are saved as separate .safetensors files for hot-swap loading.
"""

import argparse
import json
import os
import sys
import time

# DO NOT MODIFY these values without research paper justification.
# Source: "Optimal Hyperparameters" section of research paper.
LORA_RANK = 8
LORA_ALPHA = 16
TARGET_MODULES = [
    "q_proj", "k_proj", "v_proj", "o_proj",   # attention ONLY — no MLP
    # REASON: Low rank prevents hallucinating facts while imitating persona
]
LEARNING_RATE = 1e-5
WEIGHT_DECAY = 0.01      # L2 regularization — per ANCHOR 4, Mitigation 4
REPLAY_RATIO = 0.10      # 10% experience replay — per ANCHOR 4, Mitigation 1
BATCH_SIZE = 1
MAX_SEQ_LEN = 1024


def parse_args():
    parser = argparse.ArgumentParser(description="Train style QLoRA adapter")
    parser.add_argument("--model_path", required=True, help="Path to base model weights")
    parser.add_argument("--data_path", required=True, help="Path to .jsonl training data")
    parser.add_argument("--output_path", required=True, help="Path to save adapter")
    parser.add_argument("--replay_path", default=None, help="Path to experience replay JSONL")
    parser.add_argument("--num_iters", type=int, default=1000, help="Training iterations")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    return parser.parse_args()


def main():
    args = parse_args()
    t_start = time.time()

    if not os.path.exists(args.data_path):
        print(f"ERROR: Data file not found: {args.data_path}", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(args.model_path):
        print(f"ERROR: Model not found: {args.model_path}", file=sys.stderr)
        sys.exit(1)

    with open(args.data_path, "r") as f:
        num_examples = sum(1 for line in f if line.strip())
    print(f"Training examples: {num_examples}")

    os.makedirs(args.output_path, exist_ok=True)

    try:
        import mlx.core as mx
        from mlx_lm.utils import load as mlx_load
    except ImportError as e:
        print(f"ERROR: Required package not installed: {e}", file=sys.stderr)
        sys.exit(1)

    mx.random.seed(args.seed)

    # Write adapter config
    lora_config = {
        "rank": LORA_RANK,
        "alpha": LORA_ALPHA,
        "dropout": 0.0,
        "scale": LORA_ALPHA / LORA_RANK,
    }
    adapter_config = {
        "lora_layers": TARGET_MODULES,
        "lora_parameters": lora_config,
    }
    config_path = os.path.join(args.output_path, "adapter_config.json")
    with open(config_path, "w") as f:
        json.dump(adapter_config, f, indent=2)

    # Load model and tokenizer
    print(f"Loading model from {args.model_path}...")
    model, tokenizer = mlx_load(args.model_path)

    # Apply LoRA to attention-only modules
    from mlx_lm.tuner.utils import linear_to_lora_layers

    num_layers = len(model.model.layers) if hasattr(model, 'model') else len(model.layers)
    lora_config = {
        "keys": TARGET_MODULES,
        "rank": LORA_RANK,
        "alpha": LORA_ALPHA,
        "dropout": 0.0,
        "scale": LORA_ALPHA / LORA_RANK,
    }

    linear_to_lora_layers(model, num_layers, lora_config)
    print(f"Applied LoRA: rank={LORA_RANK}, alpha={LORA_ALPHA}, targets={TARGET_MODULES}")

    # Prepare data directory (mlx-lm expects train.jsonl in a directory)
    from pathlib import Path
    import shutil
    data_dir = Path(args.output_path) / "_training_data"
    data_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.data_path, data_dir / "train.jsonl")
    # Do NOT create empty valid/test files — mlx-lm returns [] for missing files
    # but crashes on empty files (IndexError: list index out of range)

    # Load training data
    from mlx_lm.tuner.datasets import load_local_dataset
    from types import SimpleNamespace
    dataset_config = SimpleNamespace(max_seq_length=MAX_SEQ_LEN)
    train_set, valid_set, test_set = load_local_dataset(
        data_path=data_dir,
        tokenizer=tokenizer,
        config=dataset_config,
    )
    print(f"Loaded {len(train_set)} training examples")

    # Wrap in CacheDataset so iterate_batches gets processed (tokens, offset) tuples
    from mlx_lm.tuner.datasets import CacheDataset
    train_set = CacheDataset(train_set)
    if valid_set:
        valid_set = CacheDataset(valid_set)

    # Training arguments
    from mlx_lm.tuner.trainer import TrainingArgs, train as mlx_train
    os.makedirs(args.output_path, exist_ok=True)
    adapter_file = os.path.join(args.output_path, "adapter_weights.safetensors")

    training_args = TrainingArgs(
        batch_size=BATCH_SIZE,
        iters=args.num_iters,
        steps_per_report=10,
        steps_per_eval=0,
        steps_per_save=args.num_iters,
        adapter_file=adapter_file,
        max_seq_length=MAX_SEQ_LEN,
    )

    import mlx.optimizers as optim
    optimizer = optim.AdamW(learning_rate=LEARNING_RATE, weight_decay=WEIGHT_DECAY)

    print("Starting training...")
    model.train()
    mlx_train(
        model=model,
        optimizer=optimizer,
        train_dataset=train_set,
        val_dataset=valid_set if valid_set else None,
        args=training_args,
    )

    t_end = time.time()
    duration = t_end - t_start

    metadata = {
        "adapter_type": "style",
        "source_vault": os.path.dirname(args.data_path),
        "lora_rank": LORA_RANK,
        "lora_alpha": LORA_ALPHA,
        "target_modules": TARGET_MODULES,
        "learning_rate": LEARNING_RATE,
        "weight_decay": WEIGHT_DECAY,
        "num_examples": num_examples,
        "num_iters": args.num_iters,
        "training_duration_seconds": round(duration, 1),
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "base_model": args.model_path,
        "quality_score": None,
    }
    metadata_path = os.path.join(args.output_path, "training_metadata.json")
    with open(metadata_path, "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"Training complete in {duration:.1f}s")
    print(f"Adapter saved to: {args.output_path}")


if __name__ == "__main__":
    main()
