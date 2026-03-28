#!/usr/bin/env python3
"""
CAMPUS Curriculum Sort for Epistemos Training Data

Sorts training examples by difficulty on 4 axes (Section 5.1 of Master Training Guide):
  1. tree_depth:         AX tree depth (deeper = harder)
  2. selector_ambiguity: How many similar elements exist (more = harder)
  3. chain_length:       Number of steps in the trajectory (longer = harder)
  4. ifd_score:          IFD quality score (lower = harder to learn)

Easy examples first → hard examples last (curriculum learning).

Usage:
  python3 campus_sort.py --input train_filtered.jsonl --output train_sorted.jsonl
"""

import json
import os
import re
import argparse


def estimate_tree_depth(example):
    """Estimate AX tree depth from the example content."""
    messages = example.get("messages", [])
    for m in messages:
        if m["role"] == "assistant":
            content = m["content"]
            # Count nested AX references
            ax_refs = len(re.findall(r"AX\w+", content))
            if ax_refs > 15:
                return 1.0  # Deep tree
            if ax_refs > 8:
                return 0.6
            if ax_refs > 3:
                return 0.3
            return 0.1
    return 0.1


def estimate_selector_ambiguity(example):
    """Estimate how ambiguous the target element selection is."""
    messages = example.get("messages", [])
    for m in messages:
        if m["role"] == "assistant":
            content = m["content"]
            # Multiple click_element calls = more ambiguous navigation
            clicks = len(re.findall(r"click_element|click", content))
            if clicks > 4:
                return 1.0
            if clicks > 2:
                return 0.6
            if clicks > 0:
                return 0.3
            return 0.1
    return 0.1


def estimate_chain_length(example):
    """Estimate the reasoning chain length."""
    step_count = example.get("step_count", 1)
    messages = example.get("messages", [])
    for m in messages:
        if m["role"] == "assistant":
            steps = len(re.findall(r"\*\*Step \d+", m["content"]))
            if steps > 0:
                step_count = max(step_count, steps)

    if step_count >= 6:
        return 1.0
    if step_count >= 4:
        return 0.7
    if step_count >= 2:
        return 0.4
    return 0.1


def campus_difficulty(example):
    """Compute composite CAMPUS difficulty score (0=easy, 1=hard)."""
    tree = estimate_tree_depth(example)
    ambiguity = estimate_selector_ambiguity(example)
    chain = estimate_chain_length(example)
    ifd = 1.0 - example.get("ifd_score", 0.5)  # Invert: low IFD = harder

    # Weighted composite
    score = 0.25 * tree + 0.25 * ambiguity + 0.30 * chain + 0.20 * ifd
    return round(score, 4)


def main():
    parser = argparse.ArgumentParser(description="CAMPUS curriculum sort")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", default=None)
    args = parser.parse_args()

    output = args.output or args.input.replace(".jsonl", "_sorted.jsonl")

    with open(args.input) as f:
        examples = [json.loads(l) for l in f if l.strip()]

    # Score each example
    for ex in examples:
        ex["campus_difficulty"] = campus_difficulty(ex)

    # Sort easy→hard (ascending difficulty)
    examples.sort(key=lambda x: x["campus_difficulty"])

    with open(output, "w") as f:
        for ex in examples:
            f.write(json.dumps(ex) + "\n")

    # Stats
    scores = [ex["campus_difficulty"] for ex in examples]
    quartiles = [
        scores[len(scores) // 4],
        scores[len(scores) // 2],
        scores[3 * len(scores) // 4],
    ]

    print("CAMPUS Curriculum Sort")
    print("  Input:    {} examples".format(len(examples)))
    print("  Output:   {}".format(output))
    print("  Difficulty range: [{:.4f}, {:.4f}]".format(min(scores), max(scores)))
    print("  Quartiles: Q1={:.4f} Q2={:.4f} Q3={:.4f}".format(*quartiles))
    print("  Mean:     {:.4f}".format(sum(scores) / len(scores)))


if __name__ == "__main__":
    main()
