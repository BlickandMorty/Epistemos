#!/usr/bin/env python3
"""
Epistemos Knowledge Fusion — Knowledge Adapter Training Script

Trains a QLoRA adapter targeting BOTH attention AND MLP layers for factual
knowledge absorption. Invoked by QLoRATrainer.swift via Process().

Source: Research paper "Optimal Hyperparameters" section.
  - rank=32, alpha=64
  - targets: q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj
  - lr=2e-5
  - WHY MLP: Facts stored in MLP key-value memory networks

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
LORA_RANK = 32
LORA_ALPHA = 64
TARGET_MODULES = [
    "q_proj", "k_proj", "v_proj", "o_proj",   # attention layers (style)
    "gate_proj", "up_proj", "down_proj",        # MLP layers (factual knowledge)
]
LEARNING_RATE = 2e-5
WEIGHT_DECAY = 0.01      # L2 regularization — per ANCHOR 4, Mitigation 4
REPLAY_RATIO = 0.10      # 10% experience replay — per ANCHOR 4, Mitigation 1
BATCH_SIZE = 4
MAX_SEQ_LEN = 2048


def parse_args():
    parser = argparse.ArgumentParser(description="Train knowledge QLoRA adapter")
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

    # Validate inputs
    if not os.path.exists(args.data_path):
        print(f"ERROR: Data file not found: {args.data_path}", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(args.model_path):
        print(f"ERROR: Model not found: {args.model_path}", file=sys.stderr)
        sys.exit(1)

    # Count training examples
    with open(args.data_path, "r") as f:
        num_examples = sum(1 for line in f if line.strip())
    print(f"Training examples: {num_examples}")

    # Create output directory
    os.makedirs(args.output_path, exist_ok=True)

    try:
        import mlx.core as mx
        from mlx_lm import lora as mlx_lora
        from mlx_lm.utils import load as mlx_load
    except ImportError as e:
        print(f"ERROR: Required package not installed: {e}", file=sys.stderr)
        sys.exit(1)

    mx.random.seed(args.seed)

    # Build lora config
    lora_config = {
        "rank": LORA_RANK,
        "alpha": LORA_ALPHA,
        "dropout": 0.0,
        "scale": LORA_ALPHA / LORA_RANK,
    }

    # Write adapter config for later loading
    adapter_config = {
        "lora_layers": TARGET_MODULES,
        "lora_parameters": lora_config,
    }
    config_path = os.path.join(args.output_path, "adapter_config.json")
    with open(config_path, "w") as f:
        json.dump(adapter_config, f, indent=2)

    # Run training via mlx_lm.lora CLI-equivalent
    # Using the Python API directly for better control
    train_args = [
        "--model", args.model_path,
        "--data", os.path.dirname(args.data_path),
        "--train-file", os.path.basename(args.data_path),
        "--adapter-path", args.output_path,
        "--iters", str(args.num_iters),
        "--batch-size", str(BATCH_SIZE),
        "--lora-rank", str(LORA_RANK),
        "--lora-layers", str(len(TARGET_MODULES)),
        "--learning-rate", str(LEARNING_RATE),
        "--seed", str(args.seed),
    ]

    # Use mlx_lm.lora training function
    from mlx_lm.tuner.trainer import TrainingArgs
    from mlx_lm.tuner.utils import build_schedule
    from mlx_lm import tuner as mlx_tuner

    # Load model and tokenizer
    print(f"Loading model from {args.model_path}...")
    model, tokenizer = mlx_load(args.model_path)

    # Apply LoRA to target modules
    from mlx_lm.tuner.utils import linear_to_lora_layers

    # Configure which layers get LoRA
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

    # Ensure output directory exists
    os.makedirs(args.output_path, exist_ok=True)
    adapter_file = os.path.join(args.output_path, "adapter_weights.safetensors")

    # Training arguments
    training_args = TrainingArgs(
        batch_size=BATCH_SIZE,
        iters=args.num_iters,
        steps_per_report=10,
        steps_per_eval=0,
        steps_per_save=args.num_iters,  # Save at the end
        adapter_file=adapter_file,
        max_seq_length=MAX_SEQ_LEN,
    )

    # Create optimizer with research-paper learning rate and L2 regularization
    import mlx.optimizers as optim
    optimizer = optim.AdamW(learning_rate=LEARNING_RATE, weight_decay=WEIGHT_DECAY)

    # Train
    print("Starting training...")
    from mlx_lm.tuner.trainer import train as mlx_train
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

    # Save training metadata
    metadata = {
        "adapter_type": "knowledge",
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
    print(f"Metadata saved to: {metadata_path}")


if __name__ == "__main__":
    main()
