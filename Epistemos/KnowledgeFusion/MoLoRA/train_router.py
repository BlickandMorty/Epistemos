#!/usr/bin/env python3
"""
Epistemos MoLoRA — Router Centroid Training

Computes deterministic KMeans-style centroids for AdaFuse decide-once routing.
No neural network training — just mean embeddings per domain, L2-normalized.

Usage:
    python train_router.py \
        --model_path /path/to/base/model \
        --knowledge_data knowledge_pairs.jsonl \
        --style_data style_pairs.jsonl \
        --tool_data tool_pairs.jsonl \
        --output_path router_centroids.safetensors

The centroid file is loaded at inference time by AdaFuseRouter.
Routing decision: cosine_similarity(token_hidden, centroids) → argmax.
"""

import argparse
import json
import os
import sys
import time

MIN_SAMPLES_PER_DOMAIN = 5


def parse_args():
    parser = argparse.ArgumentParser(description="Train MoLoRA router centroids")
    parser.add_argument("--model_path", required=True, help="Base model path")
    parser.add_argument("--knowledge_data", default=None, help="Knowledge domain JSONL")
    parser.add_argument("--style_data", default=None, help="Style domain JSONL")
    parser.add_argument("--tool_data", default=None, help="Tool domain JSONL")
    parser.add_argument("--output_path", required=True, help="Output centroids safetensors path")
    parser.add_argument("--num_samples", type=int, default=200, help="Max samples per domain")
    parser.add_argument("--max_seq_len", type=int, default=256, help="Max tokens per sample")
    return parser.parse_args()


def load_prompts_from_jsonl(path: str, max_samples: int) -> list[str]:
    """Load prompt texts from JSONL. Supports both chat format and plain format."""
    if not path or not os.path.exists(path):
        return []

    prompts = []
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Chat format: {"messages": [{"role": "user", "content": "..."}]}
            if "messages" in entry:
                for msg in entry["messages"]:
                    if msg.get("role") == "user":
                        prompts.append(msg["content"])
                        break
            # Plain format: {"instruction": "...", "input": "..."}
            elif "instruction" in entry:
                text = entry["instruction"]
                if entry.get("input"):
                    text += " " + entry["input"]
                prompts.append(text)
            # Simple format: {"prompt": "..."}
            elif "prompt" in entry:
                prompts.append(entry["prompt"])

            if len(prompts) >= max_samples:
                break

    return prompts


def extract_layer0_hidden(model, tokenizer, texts: list[str], max_seq_len: int = 256):
    """
    Extract hidden states from the base model's embedding + first transformer layer.
    Returns the mean-pooled hidden state per text: [N, d_model].
    """
    import mlx.core as mx
    import mlx.nn as nn

    embeddings = []

    for text in texts:
        # Tokenize (truncate to max_seq_len)
        tokens = tokenizer.encode(text)
        if len(tokens) > max_seq_len:
            tokens = tokens[:max_seq_len]
        if not tokens:
            continue

        token_ids = mx.array([tokens])  # [1, seq_len]

        # Get embedding
        if hasattr(model, "model"):
            embed = model.model.embed_tokens(token_ids)  # [1, seq_len, d_model]
            # Run through first transformer layer only
            layer0 = model.model.layers[0]
        elif hasattr(model, "layers"):
            embed = model.embed_tokens(token_ids)
            layer0 = model.layers[0]
        else:
            # Fallback: just use embeddings
            embed = model.embed_tokens(token_ids) if hasattr(model, "embed_tokens") else None
            if embed is None:
                continue
            # Mean pool and use embedding directly
            pooled = mx.mean(embed, axis=1).squeeze(0)  # [d_model]
            embeddings.append(pooled)
            continue

        # Forward through layer 0
        # Most transformer layers expect (hidden_states, mask, cache)
        try:
            hidden, _ = layer0(embed)
        except TypeError:
            try:
                hidden = layer0(embed, mask=None)
            except TypeError:
                # Last resort: just use embeddings
                hidden = embed

        # Mean pool across sequence length: [1, seq_len, d_model] → [d_model]
        pooled = mx.mean(hidden, axis=1).squeeze(0)
        embeddings.append(pooled)

        mx.eval(pooled)  # Force evaluation to free intermediate memory

    if not embeddings:
        return None

    return mx.stack(embeddings)  # [N, d_model]


def compute_centroids(hidden_by_domain: dict[str, "mx.array"]) -> dict[str, "mx.array"]:
    """
    Compute L2-normalized mean embedding per domain.
    Returns {domain_name: centroid [d_model]}.
    """
    import mlx.core as mx

    centroids = {}
    for domain, embeddings in hidden_by_domain.items():
        if embeddings is None or embeddings.shape[0] == 0:
            continue
        # Mean across all samples
        centroid = mx.mean(embeddings, axis=0)  # [d_model]
        # L2 normalize for cosine similarity routing
        norm = mx.linalg.norm(centroid)
        centroid = centroid / mx.maximum(norm, mx.array(1e-8))
        centroids[domain] = centroid

    return centroids


def main():
    args = parse_args()
    t_start = time.time()

    # Collect domain data
    domains = {}
    if args.knowledge_data:
        prompts = load_prompts_from_jsonl(args.knowledge_data, args.num_samples)
        if len(prompts) >= MIN_SAMPLES_PER_DOMAIN:
            domains["knowledge"] = prompts
            print(f"Knowledge: {len(prompts)} prompts")
    if args.style_data:
        prompts = load_prompts_from_jsonl(args.style_data, args.num_samples)
        if len(prompts) >= MIN_SAMPLES_PER_DOMAIN:
            domains["style"] = prompts
            print(f"Style: {len(prompts)} prompts")
    if args.tool_data:
        prompts = load_prompts_from_jsonl(args.tool_data, args.num_samples)
        if len(prompts) >= MIN_SAMPLES_PER_DOMAIN:
            domains["tool"] = prompts
            print(f"Tool: {len(prompts)} prompts")

    if len(domains) < 2:
        print(f"ERROR: Need at least 2 domains with >= {MIN_SAMPLES_PER_DOMAIN} samples each. "
              f"Found {len(domains)} domains.", file=sys.stderr)
        sys.exit(1)

    # Load model
    try:
        import mlx.core as mx
        from mlx_lm.utils import load as mlx_load
    except ImportError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Loading model from {args.model_path}...")
    model, tokenizer = mlx_load(args.model_path)
    model.eval()

    # Extract hidden states per domain
    print("Extracting hidden states...")
    hidden_by_domain = {}
    for domain, prompts in domains.items():
        print(f"  Processing {domain} ({len(prompts)} samples)...")
        hidden = extract_layer0_hidden(model, tokenizer, prompts, args.max_seq_len)
        if hidden is not None:
            hidden_by_domain[domain] = hidden
            print(f"  → {hidden.shape[0]} embeddings, dim={hidden.shape[1]}")

    if len(hidden_by_domain) < 2:
        print("ERROR: Failed to extract embeddings for enough domains.", file=sys.stderr)
        sys.exit(1)

    # Compute centroids
    print("Computing centroids...")
    centroids = compute_centroids(hidden_by_domain)

    # Save as safetensors
    os.makedirs(os.path.dirname(args.output_path) or ".", exist_ok=True)
    mx.save_safetensors(args.output_path, centroids)

    t_end = time.time()
    print(f"\nRouter centroids saved to: {args.output_path}")
    print(f"Domains: {list(centroids.keys())}")
    for domain, centroid in centroids.items():
        print(f"  {domain}: dim={centroid.shape[0]}, norm={float(mx.linalg.norm(centroid)):.4f}")
    print(f"Completed in {t_end - t_start:.1f}s")


if __name__ == "__main__":
    main()
