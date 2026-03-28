#!/usr/bin/env python3
"""
Training Data Mix Composer for Epistemos-Nano

Composes the validated chat-style data + embodied trajectories into
the target training mix from the Master Training Guide:

  40% tool-calling / embodied action
  20% general instruction-following
  20% Epistemos app-specific (code graph + symbol QA, capped)
  10% negative / refusal
  10% error recovery

Inputs:
  - epistemos_training_data_validated/*.jsonl  (chat-style, 3192 examples)
  - embodied_data/embodied_trajectories_sft.jsonl  (embodied, 503 examples)

Outputs:
  - composed_training_data/train.jsonl  (rebalanced training set)
  - composed_training_data/eval.jsonl   (held-out eval set, 10%)
  - composed_training_data/mix_report.json  (composition stats)

Usage:
  python3 compose_training_mix.py [--output-dir DIR] [--max-total N]
"""

import json
import os
import random
import argparse
from datetime import datetime, timezone


def load_jsonl(path):
    """Load all examples from a JSONL file."""
    examples = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            examples.append(json.loads(line))
    return examples


def categorize_example(example):
    """Map an example to one of the 5 mix buckets."""
    cat = example.get("category", "")
    task_type = example.get("task_type", "")
    layer = example.get("layer", 0)

    # Embodied trajectories
    if example.get("format") == "embodied_v1" or "embodied" in cat:
        if task_type == "negative":
            return "negative"
        if task_type == "error_recovery":
            return "error_recovery"
        if task_type == "tool_call":
            return "tool_calling"
        if task_type == "research":
            return "tool_calling"  # Research involves tool use
        return "tool_calling"  # All embodied data is tool-calling

    # Chat-style categories
    if cat in ("negative",) or "negative" in cat:
        return "negative"
    if cat in ("error_recovery", "error_diagnosis") or "error" in cat:
        return "error_recovery"
    if cat in ("tool_call", "axpress_schema", "scroll_gesture", "multi_app_workflow",
               "temporal_sequential"):
        return "tool_calling"
    if cat in ("trajectory", "reasoning_chain"):
        return "tool_calling"
    if cat in ("code_graph", "symbol_qa", "code_grounded"):
        return "app_specific"
    if cat in ("ax_atlas",):
        return "tool_calling"  # AX atlas is about UI interaction
    if cat in ("macos_knowledge", "general_macos", "general_knowledge",
               "system_info", "file_management", "app_launch", "app_control",
               "keyboard_shortcuts", "safari", "text_editing", "git_operations",
               "process_management", "accessibility", "shortcuts", "multi_step"):
        return "general"

    # Default: classify by layer
    if layer >= 3:
        return "tool_calling"
    if layer in (1, 2):
        return "app_specific"

    return "general"


def compose_mix(all_examples, target_total=2000):
    """Compose the training mix at target ratios.

    Target ratios:
      40% tool_calling
      20% general
      20% app_specific
      10% negative
      10% error_recovery
    """
    # Bucket all examples
    buckets = {
        "tool_calling": [],
        "general": [],
        "app_specific": [],
        "negative": [],
        "error_recovery": [],
    }

    for ex in all_examples:
        bucket = categorize_example(ex)
        buckets[bucket].append(ex)

    # Target counts
    targets = {
        "tool_calling": int(target_total * 0.40),
        "general": int(target_total * 0.20),
        "app_specific": int(target_total * 0.20),
        "negative": int(target_total * 0.10),
        "error_recovery": int(target_total * 0.10),
    }

    composed = []
    stats = {}

    for bucket_name, target_count in targets.items():
        available = buckets[bucket_name]
        stats[bucket_name] = {
            "available": len(available),
            "target": target_count,
        }

        if len(available) >= target_count:
            # Downsample
            random.shuffle(available)
            selected = available[:target_count]
            stats[bucket_name]["selected"] = target_count
            stats[bucket_name]["action"] = "downsampled"
        elif len(available) > 0:
            # Upsample by repeating (with note)
            repeats = (target_count // len(available)) + 1
            expanded = (available * repeats)[:target_count]
            selected = expanded
            stats[bucket_name]["selected"] = target_count
            stats[bucket_name]["action"] = "upsampled_{}x".format(repeats)
        else:
            # No data available
            selected = []
            stats[bucket_name]["selected"] = 0
            stats[bucket_name]["action"] = "empty"

        composed.extend(selected)

    return composed, stats


def main():
    parser = argparse.ArgumentParser(description="Compose training data mix")
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--max-total", type=int, default=2000,
                        help="Target total examples (default: 2000)")
    args = parser.parse_args()

    base_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = args.output_dir or os.path.join(base_dir, "composed_training_data")
    os.makedirs(output_dir, exist_ok=True)

    # Load all data sources
    all_examples = []

    # 1. Chat-style validated data
    validated_dir = os.path.join(base_dir, "epistemos_training_data_validated")
    if os.path.isdir(validated_dir):
        for fname in sorted(os.listdir(validated_dir)):
            if fname.endswith(".jsonl") and fname not in ("train.jsonl", "eval.jsonl"):
                path = os.path.join(validated_dir, fname)
                examples = load_jsonl(path)
                print("  Loaded {:4d} examples from {}".format(len(examples), fname))
                all_examples.extend(examples)

    # 2. Embodied trajectories (SFT format)
    embodied_path = os.path.join(base_dir, "embodied_data", "embodied_trajectories_sft.jsonl")
    if os.path.exists(embodied_path):
        examples = load_jsonl(embodied_path)
        print("  Loaded {:4d} embodied trajectories from {}".format(len(examples), "embodied_trajectories_sft.jsonl"))
        all_examples.extend(examples)

    # 3. General macOS instruction data
    general_path = os.path.join(base_dir, "embodied_data", "general_macos_instructions.jsonl")
    if os.path.exists(general_path):
        examples = load_jsonl(general_path)
        print("  Loaded {:4d} general macOS examples from {}".format(len(examples), "general_macos_instructions.jsonl"))
        all_examples.extend(examples)

    print("\nTotal source examples: {}".format(len(all_examples)))

    # Categorize before composing
    bucket_counts = {}
    for ex in all_examples:
        b = categorize_example(ex)
        bucket_counts[b] = bucket_counts.get(b, 0) + 1
    print("\nBucket distribution (before rebalancing):")
    for b, c in sorted(bucket_counts.items(), key=lambda x: -x[1]):
        pct = c / len(all_examples) * 100
        print("  {:20s}: {:5d} ({:5.1f}%)".format(b, c, pct))

    # Compose the mix
    random.seed(42)
    composed, stats = compose_mix(all_examples, target_total=args.max_total)
    random.shuffle(composed)

    # 90/10 train/eval split
    split_idx = int(len(composed) * 0.9)
    train = composed[:split_idx]
    eval_set = composed[split_idx:]

    # Write train
    train_path = os.path.join(output_dir, "train.jsonl")
    with open(train_path, "w") as f:
        for ex in train:
            f.write(json.dumps(ex) + "\n")

    # Write eval
    eval_path = os.path.join(output_dir, "eval.jsonl")
    with open(eval_path, "w") as f:
        for ex in eval_set:
            f.write(json.dumps(ex) + "\n")

    # Final stats
    final_buckets = {}
    for ex in composed:
        b = categorize_example(ex)
        final_buckets[b] = final_buckets.get(b, 0) + 1

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_total": len(all_examples),
        "composed_total": len(composed),
        "train_count": len(train),
        "eval_count": len(eval_set),
        "target_ratios": {
            "tool_calling": "40%",
            "general": "20%",
            "app_specific": "20%",
            "negative": "10%",
            "error_recovery": "10%",
        },
        "actual_ratios": {
            b: "{:.1f}%".format(c / len(composed) * 100)
            for b, c in sorted(final_buckets.items(), key=lambda x: -x[1])
        },
        "bucket_stats": stats,
    }

    report_path = os.path.join(output_dir, "mix_report.json")
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    print("\nComposed mix: {} total ({} train, {} eval)".format(len(composed), len(train), len(eval_set)))
    print("Final distribution:")
    for b, c in sorted(final_buckets.items(), key=lambda x: -x[1]):
        pct = c / len(composed) * 100
        target = {"tool_calling": 40, "general": 20, "app_specific": 20, "negative": 10, "error_recovery": 10}
        print("  {:20s}: {:5d} ({:5.1f}% / target {:2d}%)".format(b, c, pct, target.get(b, 0)))

    print("\nOutput:")
    print("  Train: {}".format(train_path))
    print("  Eval:  {}".format(eval_path))
    print("  Report: {}".format(report_path))


if __name__ == "__main__":
    main()
