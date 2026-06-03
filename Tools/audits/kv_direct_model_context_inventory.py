#!/usr/bin/env python3
"""Inventory local MLX/HF model configs for the KV-Direct 128K gate.

This is a read-only audit. It does not download, delete, link, or modify model
assets. Its job is to keep the Capability Ceiling loop honest about whether a
local model asset can satisfy the F-KV-Direct-Gate context contract.
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPO_ROOT / "docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json"
REQUIRED_CONTEXT_TOKENS = 128_000
CANONICAL_REPO_ID = "Qwen/Qwen3-8B-MLX-4bit"
CANONICAL_SLUG = "models--Qwen--Qwen3-8B-MLX-4bit"
CONTEXT_KEYS = [
    "max_position_embeddings",
    "max_sequence_length",
    "max_seq_len",
    "seq_length",
    "context_length",
    "model_max_length",
]
KV_DIRECT_WEIGHT_SUFFIXES = {".safetensors", ".npz"}
NON_KV_DIRECT_WEIGHT_SUFFIXES = {".gguf"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Inventory KV-Direct local model context support")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--required-context", type=int, default=REQUIRED_CONTEXT_TOKENS)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    entries = scan_model_configs(discovery_roots())
    entries.sort(
        key=lambda entry: (
            bool(entry["is_canonical_kv_direct_model"]),
            int(entry["effective_context_tokens"]),
            bool(entry["has_local_weights"]),
            str(entry["repo_id"]),
        ),
        reverse=True,
    )
    summary = summarize(entries, args.required_context)
    payload = {
        "audit_id": "kv_direct_model_context_inventory_2026_05_28",
        "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "non_destructive": True,
        "required_context_tokens": args.required_context,
        "canonical_repo_id": CANONICAL_REPO_ID,
        "canonical_slug": CANONICAL_SLUG,
        "skips_non_kv_direct_weight_formats": True,
        "summary": summary,
        "entries": entries,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({**summary, "output": str(args.output)}, indent=2, sort_keys=True))
    return 0


def discovery_roots() -> list[Path]:
    roots: list[Path] = []
    user = os.environ.get("SUDO_USER") or os.environ.get("USER") or os.environ.get("LOGNAME")
    homes = []
    if user:
        homes.append(Path("/Users") / user)
    homes.append(Path.home())

    for home in homes:
        roots.append(home / "Library/Application Support/Epistemos/Models")
        roots.append(home / ".cache/huggingface/hub")

    if env_root := os.environ.get("EPISTEMOS_LOCAL_MODEL_ROOT"):
        roots.append(Path(env_root))
    if hf_home := os.environ.get("HF_HOME"):
        roots.append(Path(hf_home) / "hub")

    deduped: list[Path] = []
    seen: set[str] = set()
    for root in roots:
        try:
            resolved = str(root.expanduser().resolve())
        except OSError:
            resolved = str(root.expanduser())
        if resolved not in seen:
            seen.add(resolved)
            deduped.append(Path(resolved))
    return [root for root in deduped if root.exists()]


def scan_model_configs(roots: list[Path]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    seen: set[str] = set()
    for root in roots:
        for config_path in root.rglob("config.json"):
            model_dir = config_path.parent
            key = str(model_dir)
            if key in seen:
                continue
            seen.add(key)
            try:
                config = json.loads(config_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            entry = entry_from_config(model_dir, config)
            if entry["has_non_kv_direct_weights"] and not entry["has_local_weights"]:
                continue
            entries.append(entry)
    return entries


def entry_from_config(model_dir: Path, config: dict[str, Any]) -> dict[str, Any]:
    declared_context, context_source = declared_context_tokens(config)
    rope_label, rope_effective = rope_effective_context(config.get("rope_scaling"), declared_context)
    effective_context = max(declared_context, rope_effective or 0)
    repo_id = infer_repo_id(model_dir)
    weight_suffixes = {path.suffix for path in model_dir.iterdir() if path.is_file()}
    has_weights = any(suffix in KV_DIRECT_WEIGHT_SUFFIXES for suffix in weight_suffixes)
    has_non_kv_direct_weights = any(suffix in NON_KV_DIRECT_WEIGHT_SUFFIXES for suffix in weight_suffixes)
    is_canonical = repo_id == CANONICAL_REPO_ID or CANONICAL_SLUG in str(model_dir)
    model_type = str(config.get("model_type", "unknown"))
    is_text_generation_candidate = model_type not in {"model2vec"}
    return {
        "path": str(model_dir),
        "repo_id": repo_id,
        "model_type": model_type,
        "declared_context_tokens": declared_context,
        "effective_context_tokens": effective_context,
        "context_source": (
            "rope_scaling_effective_context"
            if rope_effective and rope_effective > declared_context
            else context_source
        ),
        "rope_scaling": rope_label,
        "has_local_weights": has_weights,
        "has_non_kv_direct_weights": has_non_kv_direct_weights,
        "is_text_generation_candidate": is_text_generation_candidate,
        "satisfies_required_context": effective_context >= REQUIRED_CONTEXT_TOKENS,
        "is_canonical_kv_direct_model": is_canonical,
    }


def declared_context_tokens(config: dict[str, Any]) -> tuple[int, str]:
    for key in CONTEXT_KEYS:
        value = config.get(key)
        if isinstance(value, int) and value >= 0:
            return value, key
    return 0, "unset"


def rope_effective_context(value: Any, declared_context: int) -> tuple[str, int | None]:
    if value is None:
        return "none", None
    label = json.dumps(value, sort_keys=True)
    if not isinstance(value, dict):
        return label, None
    factor = value.get("factor")
    original = (
        value.get("original_max_position_embeddings")
        or value.get("original_context_length")
        or value.get("original_max_seq_len")
        or declared_context
    )
    if isinstance(factor, (int, float)) and factor > 1 and isinstance(original, int):
        return label, int(original * factor)
    return label, None


def infer_repo_id(path: Path) -> str:
    parts = path.parts
    for i, part in enumerate(parts):
        if part.startswith("models--"):
            slug = part.removeprefix("models--")
            bits = slug.split("--", 1)
            if len(bits) == 2:
                return f"{bits[0]}/{bits[1]}"
            return slug.replace("--", "/")
    name = path.name
    if "--" in name:
        org, model = name.split("--", 1)
        return f"{org}/{model}"
    return name


def summarize(entries: list[dict[str, Any]], required_context: int) -> dict[str, Any]:
    weighted = [e for e in entries if e["has_local_weights"]]
    candidates = [
        e
        for e in weighted
        if int(e["effective_context_tokens"]) >= required_context
    ]
    text_candidates = [e for e in candidates if e["is_text_generation_candidate"]]
    canonical = [e for e in entries if e["is_canonical_kv_direct_model"]]
    canonical_ok = any(
        e["has_local_weights"] and int(e["effective_context_tokens"]) >= required_context
        for e in canonical
    )
    best = max(
        text_candidates,
        key=lambda e: (int(e["effective_context_tokens"]), str(e["repo_id"])),
        default=None,
    )
    return {
        "config_count": len(entries),
        "weighted_model_count": len(weighted),
        "required_context_candidate_count": len(candidates),
        "required_context_text_model_candidate_count": len(text_candidates),
        "canonical_candidate_count": len(canonical),
        "canonical_context_ok": canonical_ok,
        "best_required_context_candidate_repo_id": best["repo_id"] if best else "none",
        "best_required_context_candidate_path": best["path"] if best else "none",
        "best_required_context_candidate_tokens": int(best["effective_context_tokens"]) if best else 0,
    }


if __name__ == "__main__":
    raise SystemExit(main())
