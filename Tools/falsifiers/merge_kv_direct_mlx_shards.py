#!/usr/bin/env python3
"""Merge sharded MLX KV-Direct live-run outputs.

The full F-KV-Direct-Gate run is intentionally large: 100 prompts, 128K
context, and 256 generated tokens per prompt. This tool lets that run happen
in restartable shards while preserving the falsifier contract:

- paired `reference_logits.json` / `test_logits.json`
- one `metrics.json`
- one `spill_trace.json`
- one `manifest.json` with env vars for `f_kv_direct_gate.sh`

It does not promote any route. If the source shards are prompt-cache reload or
KV-quantized development routes, the merged spill label remains false.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_DIR = REPO_ROOT / "artifacts/falsifiers/kv_direct_gate/live_mlx_merged"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Merge KV-Direct MLX live-run shards")
    parser.add_argument("shard_dirs", type=Path, nargs="+")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    shards = [read_shard(path) for path in args.shard_dirs]
    merged = merge_shards(shards)
    write_outputs(args.output_dir, merged)
    print(
        json.dumps(
            {
                "output_dir": str(args.output_dir),
                "prompt_count": len(merged["prompt_ids"]),
                "context_window_tokens": merged["metrics"]["context_window_tokens"],
                "decode_tokens_per_prompt": merged["metrics"]["decode_tokens_per_prompt"],
                "decode_tok_s": merged["metrics"]["decode_tok_s"],
                "spill_labeling": merged["metrics"]["spill_labeling"],
            },
            indent=2,
        )
    )
    return 0


def read_shard(path: Path) -> dict[str, Any]:
    manifest_path = path / "manifest.json"
    metrics_path = path / "metrics.json"
    spill_trace_path = path / "spill_trace.json"
    reference_path = path / "reference_logits.json"
    test_path = path / "test_logits.json"
    for required in [manifest_path, metrics_path, spill_trace_path, reference_path, test_path]:
        if not required.exists():
            raise SystemExit(f"missing shard file: {required}")

    manifest = read_json(manifest_path)
    metrics = read_json(metrics_path)
    spill_trace = read_json(spill_trace_path)
    reference_logits = read_json(reference_path)
    test_logits = read_json(test_path)
    prompt_ids = list(manifest.get("prompt_ids") or spill_trace.get("prompt_ids") or [])
    if len(prompt_ids) != len(reference_logits) or len(prompt_ids) != len(test_logits):
        raise SystemExit(
            f"shard row mismatch for {path}: prompt_ids={len(prompt_ids)} "
            f"reference={len(reference_logits)} test={len(test_logits)}"
        )
    return {
        "path": path,
        "manifest": manifest,
        "metrics": metrics,
        "spill_trace": spill_trace,
        "reference_logits": reference_logits,
        "test_logits": test_logits,
        "prompt_ids": prompt_ids,
    }


def merge_shards(shards: list[dict[str, Any]]) -> dict[str, Any]:
    prompt_ids: list[str] = []
    reference_logits: list[Any] = []
    test_logits: list[Any] = []
    route_traces: list[Any] = []
    shard_manifests: list[str] = []
    seen: set[str] = set()

    peak_ram_gb = 0.0
    suite_wall_clock_min = 0.0
    generated_test_tokens = 0
    test_decode_seconds = 0.0
    observed_decode_tok_s: list[float] = []
    context_window_tokens: int | None = None
    decode_tokens_per_prompt: int | None = None
    spill_labeling = True
    file_backed_cache_reload = True
    routes: set[str] = set()

    for shard in sorted(shards, key=shard_sort_key):
        shard_path = shard["path"]
        metrics = shard["metrics"]
        spill_trace = shard["spill_trace"]
        shard_manifests.append(str(shard_path / "manifest.json"))
        routes.add(str(metrics.get("test_route") or spill_trace.get("route") or "unknown"))

        for prompt_id in shard["prompt_ids"]:
            if prompt_id in seen:
                raise SystemExit(f"duplicate prompt id across shards: {prompt_id}")
            seen.add(prompt_id)
            prompt_ids.append(prompt_id)

        reference_logits.extend(shard["reference_logits"])
        test_logits.extend(shard["test_logits"])
        route_traces.extend(spill_trace.get("route_traces") or [])

        peak_ram_gb = max(peak_ram_gb, float(metrics.get("peak_ram_gb", 0.0)))
        suite_wall_clock_min += float(metrics.get("suite_wall_clock_min", 0.0))
        generated_test_tokens += int(metrics.get("generated_test_tokens", 0))
        test_decode_seconds += float(metrics.get("test_decode_seconds", 0.0))
        observed_decode_tok_s.append(float(metrics.get("decode_tok_s", 0.0)))
        context_window_tokens = min_optional(
            context_window_tokens,
            int(metrics.get("context_window_tokens", 0)),
        )
        decode_tokens_per_prompt = min_optional(
            decode_tokens_per_prompt,
            int(metrics.get("decode_tokens_per_prompt", 0)),
        )
        spill_labeling = spill_labeling and bool(metrics.get("spill_labeling", False))
        spill_labeling = spill_labeling and bool(spill_trace.get("ssd_spill_labeled", False))
        file_backed_cache_reload = file_backed_cache_reload and bool(
            metrics.get("file_backed_cache_reload", False)
        )

    if test_decode_seconds > 0:
        decode_tok_s = generated_test_tokens / test_decode_seconds
    else:
        decode_tok_s = min(observed_decode_tok_s) if observed_decode_tok_s else 0.0
    route_label = "merged:" + ",".join(sorted(routes))
    metrics = {
        "peak_ram_gb": peak_ram_gb,
        "decode_tok_s": decode_tok_s,
        "generated_test_tokens": generated_test_tokens,
        "test_decode_seconds": test_decode_seconds,
        "suite_wall_clock_min": suite_wall_clock_min,
        "spill_labeling": spill_labeling,
        "context_window_tokens": context_window_tokens or 0,
        "decode_tokens_per_prompt": decode_tokens_per_prompt or 0,
        "prompt_count": len(prompt_ids),
        "test_route": route_label,
        "file_backed_cache_reload": file_backed_cache_reload,
    }
    spill_trace = {
        "route": route_label,
        "ssd_spill_labeled": spill_labeling,
        "file_backed_cache_reload": file_backed_cache_reload,
        "reason": (
            "Merged KV-Direct live-run shards. This is a full-suite input "
            "container only; it is not a green SSD-spill witness unless every "
            "source shard is labeled as the residual-patched mmap/NF4 route."
        ),
        "prompt_ids": prompt_ids,
        "route_traces": route_traces,
        "shard_manifests": shard_manifests,
    }
    return {
        "prompt_ids": prompt_ids,
        "reference_logits": reference_logits,
        "test_logits": test_logits,
        "metrics": metrics,
        "spill_trace": spill_trace,
    }


def shard_sort_key(shard: dict[str, Any]) -> tuple[int, str]:
    manifest = shard["manifest"]
    return int(manifest.get("prompt_offset", 0)), str(shard["path"])


def min_optional(current: int | None, candidate: int) -> int:
    if current is None:
        return candidate
    return min(current, candidate)


def write_outputs(output_dir: Path, merged: dict[str, Any]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    reference_path = output_dir / "reference_logits.json"
    test_path = output_dir / "test_logits.json"
    metrics_path = output_dir / "metrics.json"
    spill_trace_path = output_dir / "spill_trace.json"
    manifest_path = output_dir / "manifest.json"

    write_json(reference_path, merged["reference_logits"])
    write_json(test_path, merged["test_logits"])
    write_json(metrics_path, merged["metrics"])
    write_json(spill_trace_path, merged["spill_trace"])
    write_json(
        manifest_path,
        {
            "output_dir": str(output_dir),
            "prompt_count": len(merged["prompt_ids"]),
            "prompt_ids": merged["prompt_ids"],
            "reference_logits": str(reference_path),
            "test_logits": str(test_path),
            "metrics": str(metrics_path),
            "spill_trace": str(spill_trace_path),
            "env_for_falsifier": {
                "EPISTEMOS_KV_DIRECT_REFERENCE_LOGITS": str(reference_path),
                "EPISTEMOS_KV_DIRECT_TEST_LOGITS": str(test_path),
                "EPISTEMOS_KV_DIRECT_METRICS_PATH": str(metrics_path),
                "EPISTEMOS_KV_DIRECT_SPILL_TRACE": str(spill_trace_path),
            },
        },
    )


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, value: Any) -> None:
    with path.open("w", encoding="utf-8") as f:
        json.dump(value, f, indent=2, sort_keys=True)
        f.write("\n")


if __name__ == "__main__":
    raise SystemExit(main())
