#!/usr/bin/env python3
"""
IFD (Instruction Following Difficulty) Superfilter for Epistemos Training Data

Scores each training example on multiple quality axes and filters to the top N%.
This is a proxy for GPT-2 perplexity-based IFD scoring (Section 5.1 of the
Master Training Guide), using measurable structural quality signals instead.

Quality axes:
  1. response_length:     Longer, substantive responses score higher (diminishing returns)
  2. has_reasoning:       Contains <think>...</think> tags
  3. has_tool_call:       Contains structured tool call JSON
  4. instruction_clarity: User message is specific (not too short, not too generic)
  5. response_structure:  Has markdown formatting, code blocks, or structured output
  6. deduplication:       Penalize near-duplicate instructions

Output: filtered train/eval JSONL files with IFD scores attached.

Usage:
  python3 ifd_filter.py --input composed_training_data/train.jsonl --top-pct 85
"""

import json
import os
import re
import hashlib
import argparse
from collections import Counter


def score_response_length(messages):
    """Score based on assistant response length. Diminishing returns after 200 chars."""
    assistant_msgs = [m["content"] for m in messages if m["role"] == "assistant"]
    if not assistant_msgs:
        return 0.0
    total_len = sum(len(m) for m in assistant_msgs)
    if total_len < 20:
        return 0.1
    if total_len < 50:
        return 0.3
    if total_len < 100:
        return 0.5
    if total_len < 200:
        return 0.7
    if total_len < 500:
        return 0.85
    return 1.0


def score_reasoning(messages):
    """Score whether the response contains explicit reasoning."""
    for m in messages:
        if m["role"] == "assistant":
            if "<think>" in m["content"] and "</think>" in m["content"]:
                return 1.0
            if "**[REASON]:**" in m["content"]:
                return 1.0
    return 0.0


def score_tool_call(messages):
    """Score whether the response contains a structured tool call."""
    for m in messages:
        if m["role"] == "assistant":
            content = m["content"]
            if '"tool"' in content or '"toolName"' in content:
                return 1.0
            if '`{"tool":' in content:
                return 1.0
            if "**[ACT]:**" in content:
                return 0.8
    return 0.0


def score_instruction_clarity(messages):
    """Score instruction specificity. Too short = vague, too long = noisy."""
    user_msgs = [m["content"] for m in messages if m["role"] == "user"]
    if not user_msgs:
        return 0.0
    user_len = sum(len(m) for m in user_msgs)
    if user_len < 10:
        return 0.2  # Too short to be useful
    if user_len < 30:
        return 0.6
    if user_len < 100:
        return 1.0  # Sweet spot
    if user_len < 300:
        return 0.8
    return 0.6  # Very long instructions may be noisy


def score_structure(messages):
    """Score response formatting and structure."""
    for m in messages:
        if m["role"] == "assistant":
            content = m["content"]
            score = 0.0
            if "```" in content:
                score += 0.3  # Code blocks
            if re.search(r"^#{1,3}\s", content, re.MULTILINE):
                score += 0.2  # Headers
            if re.search(r"^[-*]\s", content, re.MULTILINE):
                score += 0.2  # Bullet lists
            if "`{" in content:
                score += 0.3  # Inline JSON
            if "**" in content:
                score += 0.1  # Bold text
            return min(score, 1.0)
    return 0.0


def instruction_fingerprint(messages):
    """Create a fingerprint for near-duplicate detection."""
    user_msgs = [m["content"].lower().strip() for m in messages if m["role"] == "user"]
    text = " ".join(user_msgs)
    # Normalize: remove punctuation, extra spaces
    text = re.sub(r"[^\w\s]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    # Use first 100 chars as fingerprint (catches exact and near dupes)
    return hashlib.md5(text[:100].encode()).hexdigest()


def compute_ifd_score(example, seen_fingerprints):
    """Compute composite IFD score for a training example."""
    messages = example.get("messages", [])
    if not messages:
        return 0.0, {}

    # Individual axis scores
    length_score = score_response_length(messages)
    reasoning_score = score_reasoning(messages)
    tool_score = score_tool_call(messages)
    clarity_score = score_instruction_clarity(messages)
    structure_score = score_structure(messages)

    # Dedup penalty
    fp = instruction_fingerprint(messages)
    seen_fingerprints[fp] = seen_fingerprints.get(fp, 0) + 1
    dedup_penalty = 1.0 if seen_fingerprints[fp] == 1 else 0.5 if seen_fingerprints[fp] == 2 else 0.2

    # Weighted composite
    # Tool call and reasoning are most important for embodied agent training
    composite = (
        0.15 * length_score
        + 0.25 * reasoning_score
        + 0.25 * tool_score
        + 0.10 * clarity_score
        + 0.10 * structure_score
        + 0.15 * dedup_penalty
    )

    details = {
        "length": round(length_score, 3),
        "reasoning": round(reasoning_score, 3),
        "tool_call": round(tool_score, 3),
        "clarity": round(clarity_score, 3),
        "structure": round(structure_score, 3),
        "dedup": round(dedup_penalty, 3),
        "composite": round(composite, 4),
    }

    return composite, details


def filter_dataset(input_path, top_pct=85):
    """Score and filter a JSONL dataset to the top N%."""
    examples = []
    with open(input_path) as f:
        for line in f:
            line = line.strip()
            if line:
                examples.append(json.loads(line))

    # Score all examples
    seen_fingerprints = {}
    scored = []
    for ex in examples:
        score, details = compute_ifd_score(ex, seen_fingerprints)
        ex["ifd_score"] = score
        ex["ifd_details"] = details
        scored.append((score, ex))

    # Sort by score descending
    scored.sort(key=lambda x: -x[0])

    # Keep top N%
    keep_count = int(len(scored) * top_pct / 100)
    kept = [ex for _, ex in scored[:keep_count]]
    dropped = [ex for _, ex in scored[keep_count:]]

    # Stats
    all_scores = [s for s, _ in scored]
    kept_scores = [ex["ifd_score"] for ex in kept]
    dropped_scores = [ex["ifd_score"] for ex in dropped]

    stats = {
        "input_count": len(examples),
        "kept_count": len(kept),
        "dropped_count": len(dropped),
        "top_pct": top_pct,
        "score_mean": round(sum(all_scores) / max(len(all_scores), 1), 4),
        "score_min": round(min(all_scores) if all_scores else 0, 4),
        "score_max": round(max(all_scores) if all_scores else 0, 4),
        "kept_mean": round(sum(kept_scores) / max(len(kept_scores), 1), 4),
        "dropped_mean": round(sum(dropped_scores) / max(len(dropped_scores), 1), 4) if dropped_scores else 0,
        "unique_fingerprints": len(seen_fingerprints),
        "duplicate_count": sum(1 for v in seen_fingerprints.values() if v > 1),
    }

    # Score distribution
    buckets = Counter()
    for s in all_scores:
        if s >= 0.8:
            buckets["0.8-1.0"] += 1
        elif s >= 0.6:
            buckets["0.6-0.8"] += 1
        elif s >= 0.4:
            buckets["0.4-0.6"] += 1
        elif s >= 0.2:
            buckets["0.2-0.4"] += 1
        else:
            buckets["0.0-0.2"] += 1
    stats["distribution"] = dict(sorted(buckets.items()))

    return kept, dropped, stats


def main():
    parser = argparse.ArgumentParser(description="IFD superfilter for training data")
    parser.add_argument("--input", required=True, help="Input JSONL file")
    parser.add_argument("--output", default=None, help="Output JSONL (default: input_filtered.jsonl)")
    parser.add_argument("--top-pct", type=int, default=85, help="Keep top N%% (default: 85)")
    args = parser.parse_args()

    output_path = args.output or args.input.replace(".jsonl", "_filtered.jsonl")

    print("IFD Superfilter")
    print("  Input:  {}".format(args.input))
    print("  Top:    {}%".format(args.top_pct))

    kept, dropped, stats = filter_dataset(args.input, args.top_pct)

    # Write filtered output
    with open(output_path, "w") as f:
        for ex in kept:
            f.write(json.dumps(ex) + "\n")

    # Write report
    report_path = output_path.replace(".jsonl", "_report.json")
    with open(report_path, "w") as f:
        json.dump(stats, f, indent=2)

    print("\n=== IFD Filter Results ===")
    print("  Input:              {} examples".format(stats["input_count"]))
    print("  Kept:               {} examples ({}%)".format(stats["kept_count"], args.top_pct))
    print("  Dropped:            {} examples".format(stats["dropped_count"]))
    print("  Score mean:         {:.4f}".format(stats["score_mean"]))
    print("  Score range:        [{:.4f}, {:.4f}]".format(stats["score_min"], stats["score_max"]))
    print("  Kept mean:          {:.4f}".format(stats["kept_mean"]))
    print("  Dropped mean:       {:.4f}".format(stats["dropped_mean"]))
    print("  Unique fingerprints: {}".format(stats["unique_fingerprints"]))
    print("  Duplicates:         {}".format(stats["duplicate_count"]))
    print("  Distribution:")
    for bucket, count in sorted(stats["distribution"].items()):
        print("    {}: {}".format(bucket, count))
    print("\n  Output:  {}".format(output_path))
    print("  Report:  {}".format(report_path))


if __name__ == "__main__":
    main()
