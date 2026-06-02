#!/usr/bin/env python3
"""MLX live runner for the F-KV-Direct-Gate contract.

This runner materializes the canonical prompt-suite manifest and emits the
paired JSON inputs consumed by `falsify_kv_direct_gate.rs`.

It is deliberately conservative:
- default mode is smoke-sized and cannot satisfy the falsifier;
- full 100-prompt / 128K / 256-decode execution requires --allow-full-suite;
- every test route is labeled. KV-quantized and prompt-cache-reload routes can
  produce paired logits for development, but they are not residual-patched SSD
  oracle witnesses.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import platform
import resource
import time
from pathlib import Path
from typing import Any, List, Optional, Sequence

import mlx.core as mx
import numpy as np
from mlx_lm import load
from mlx_lm.generate import generate_step
from mlx_lm.models.cache import load_prompt_cache, make_prompt_cache, save_prompt_cache


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PROMPT_SUITE = REPO_ROOT / "artifacts/falsifiers/kv_direct_gate/prompt_suite.json"
DEFAULT_OUTPUT_DIR = REPO_ROOT / "artifacts/falsifiers/kv_direct_gate/live_mlx"
DEFAULT_MODEL_SLUG = "models--Qwen--Qwen3-8B-MLX-4bit"
CANONICAL_MODEL_REPO_ID = "Qwen/Qwen3-8B-MLX-4bit"
FULL_PROMPTS = 100
FULL_CONTEXT_TOKENS = 128_000
FULL_DECODE_TOKENS = 256
SMOKE_PROMPTS = 1
SMOKE_CONTEXT_TOKENS = 2_048
SMOKE_DECODE_TOKENS = 1


class JsonRowsWriter:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.file = path.open("w", encoding="utf-8")
        self.file.write("[\n")
        self.count = 0

    def write_row(self, row: Sequence[float]) -> None:
        if self.count:
            self.file.write(",\n")
        json.dump(list(row), self.file, separators=(",", ":"))
        self.count += 1

    def close(self) -> None:
        self.file.write("\n]\n")
        self.file.close()

    def __enter__(self) -> "JsonRowsWriter":
        return self

    def __exit__(self, exc_type: object, exc: object, tb: object) -> None:
        self.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the MLX side of F-KV-Direct-Gate")
    parser.add_argument("--model-path", type=Path, default=None)
    parser.add_argument("--prompt-suite", type=Path, default=DEFAULT_PROMPT_SUITE)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--prompt-offset", type=int, default=0)
    parser.add_argument("--max-prompts", type=int, default=None)
    parser.add_argument("--context-tokens", type=int, default=None)
    parser.add_argument("--decode-tokens", type=int, default=None)
    parser.add_argument("--prefill-step-size", type=int, default=2048)
    parser.add_argument(
        "--test-route",
        choices=["full_kv", "kv_quantized", "prompt_cache_reload"],
        default="kv_quantized",
    )
    parser.add_argument("--kv-bits", type=int, default=4)
    parser.add_argument("--kv-group-size", type=int, default=64)
    parser.add_argument("--quantized-kv-start", type=int, default=0)
    parser.add_argument("--allow-full-suite", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    suite = read_json(args.prompt_suite)
    specs = suite.get("prompts", [])
    if not specs:
        raise SystemExit(f"prompt suite has no prompts: {args.prompt_suite}")

    model_path = args.model_path or discover_model_path()
    if model_path is None:
        raise SystemExit("No Qwen3-8B MLX model path found; set --model-path")

    if args.prompt_offset < 0:
        raise SystemExit("--prompt-offset must be non-negative")
    max_prompts, context_tokens, decode_tokens = execution_shape(args, suite, len(specs))
    selected_specs = specs[args.prompt_offset : args.prompt_offset + max_prompts]
    if not selected_specs:
        raise SystemExit(
            f"prompt selection is empty: offset={args.prompt_offset} max_prompts={max_prompts}"
        )
    args.output_dir.mkdir(parents=True, exist_ok=True)

    plan = {
        "model_path": str(model_path),
        "model_repo_id": infer_repo_id(model_path),
        "canonical_model_repo_id": CANONICAL_MODEL_REPO_ID,
        "model_identity_matches_canonical": infer_repo_id(model_path) == CANONICAL_MODEL_REPO_ID,
        "prompt_suite": str(args.prompt_suite),
        "output_dir": str(args.output_dir),
        "prompt_offset": args.prompt_offset,
        "prompt_count": len(selected_specs),
        "prompt_ids": [str(spec.get("id", f"prompt_{i:03}")) for i, spec in enumerate(selected_specs)],
        "context_window_tokens": context_tokens,
        "decode_tokens_per_prompt": decode_tokens,
        "test_route": args.test_route,
        "allow_full_suite": bool(args.allow_full_suite),
        "will_satisfy_shape_floor": (
            len(selected_specs) >= FULL_PROMPTS
            and context_tokens >= FULL_CONTEXT_TOKENS
            and decode_tokens >= FULL_DECODE_TOKENS
        ),
    }
    write_json(args.output_dir / "run_plan.json", plan)
    print(json.dumps(plan, indent=2))
    if args.dry_run:
        return 0

    model, tokenizer = load(str(model_path))
    reference_path = args.output_dir / "reference_logits.json"
    test_path = args.output_dir / "test_logits.json"
    metrics_path = args.output_dir / "metrics.json"
    spill_trace_path = args.output_dir / "spill_trace.json"
    manifest_path = args.output_dir / "manifest.json"
    progress_path = args.output_dir / "progress.json"
    prompt_cache_dir = args.output_dir / "prompt_cache_reload"

    prompt_ids: List[str] = []
    route_traces: List[dict[str, Any]] = []
    generated_test_tokens = 0
    test_decode_seconds = 0.0
    started = time.perf_counter()
    write_progress(
        progress_path,
        status="running",
        prompt_offset=args.prompt_offset,
        prompt_count=len(selected_specs),
        completed_prompt_ids=[],
        current_prompt_id=None,
        generated_test_tokens=0,
        test_decode_seconds=0.0,
    )

    with JsonRowsWriter(reference_path) as ref_writer, JsonRowsWriter(test_path) as test_writer:
        for spec in selected_specs:
            prompt_id = str(spec.get("id", f"prompt_{len(prompt_ids):03}"))
            write_progress(
                progress_path,
                status="running",
                prompt_offset=args.prompt_offset,
                prompt_count=len(selected_specs),
                completed_prompt_ids=prompt_ids,
                current_prompt_id=prompt_id,
                generated_test_tokens=generated_test_tokens,
                test_decode_seconds=test_decode_seconds,
            )
            prompt_ids.append(prompt_id)
            tokens = materialize_tokens(tokenizer, spec, context_tokens)

            ref_logprobs, _ = run_route(
                model,
                tokens,
                decode_tokens=1,
                prefill_step_size=args.prefill_step_size,
                route="full_kv",
                kv_bits=None,
                kv_group_size=args.kv_group_size,
                quantized_kv_start=args.quantized_kv_start,
                cache_file=None,
            )
            ref_writer.write_row(logprobs_to_list(ref_logprobs))
            mx.clear_cache()

            route_started = time.perf_counter()
            cache_file = prompt_cache_dir / f"{prompt_id}.safetensors"
            test_logprobs, produced = run_route(
                model,
                tokens,
                decode_tokens=decode_tokens,
                prefill_step_size=args.prefill_step_size,
                route=args.test_route,
                kv_bits=args.kv_bits if args.test_route == "kv_quantized" else None,
                kv_group_size=args.kv_group_size,
                quantized_kv_start=args.quantized_kv_start,
                cache_file=cache_file,
            )
            test_decode_seconds += max(time.perf_counter() - route_started, 0.0)
            generated_test_tokens += produced
            if args.test_route == "prompt_cache_reload":
                route_traces.append(prompt_cache_trace(cache_file, prompt_id))
            test_writer.write_row(logprobs_to_list(test_logprobs))
            mx.clear_cache()
            write_progress(
                progress_path,
                status="running",
                prompt_offset=args.prompt_offset,
                prompt_count=len(selected_specs),
                completed_prompt_ids=prompt_ids,
                current_prompt_id=None,
                generated_test_tokens=generated_test_tokens,
                test_decode_seconds=test_decode_seconds,
            )

    wall_clock_min = (time.perf_counter() - started) / 60.0
    decode_tok_s = generated_test_tokens / test_decode_seconds if test_decode_seconds > 0 else 0.0
    file_backed_cache_reload = args.test_route == "prompt_cache_reload"
    spill_labeling = False
    metrics = {
        "peak_ram_gb": peak_rss_gb(),
        "decode_tok_s": decode_tok_s,
        "generated_test_tokens": generated_test_tokens,
        "test_decode_seconds": test_decode_seconds,
        "suite_wall_clock_min": wall_clock_min,
        "spill_labeling": spill_labeling,
        "context_window_tokens": context_tokens,
        "decode_tokens_per_prompt": decode_tokens,
        "prompt_count": len(selected_specs),
        "test_route": args.test_route,
        "file_backed_cache_reload": file_backed_cache_reload,
    }
    spill_trace = {
        "route": args.test_route,
        "ssd_spill_labeled": spill_labeling,
        "file_backed_cache_reload": file_backed_cache_reload,
        "reason": spill_trace_reason(args.test_route),
        "prompt_ids": prompt_ids,
        "route_traces": route_traces,
    }
    manifest = {
        **plan,
        "reference_logits": str(reference_path),
        "test_logits": str(test_path),
        "metrics": str(metrics_path),
        "spill_trace": str(spill_trace_path),
        "env_for_falsifier": {
            "EPISTEMOS_KV_DIRECT_MODEL_PATH": str(model_path),
            "EPISTEMOS_KV_DIRECT_PROMPT_SUITE": str(args.prompt_suite),
            "EPISTEMOS_KV_DIRECT_REFERENCE_LOGITS": str(reference_path),
            "EPISTEMOS_KV_DIRECT_TEST_LOGITS": str(test_path),
            "EPISTEMOS_KV_DIRECT_METRICS_PATH": str(metrics_path),
            "EPISTEMOS_KV_DIRECT_SPILL_TRACE": str(spill_trace_path),
        },
    }
    write_json(metrics_path, metrics)
    write_json(spill_trace_path, spill_trace)
    write_json(manifest_path, manifest)
    write_progress(
        progress_path,
        status="complete",
        prompt_offset=args.prompt_offset,
        prompt_count=len(selected_specs),
        completed_prompt_ids=prompt_ids,
        current_prompt_id=None,
        generated_test_tokens=generated_test_tokens,
        test_decode_seconds=test_decode_seconds,
    )
    print(f"wrote {manifest_path}")
    return 0


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(value, f, indent=2, sort_keys=True)
        f.write("\n")


def write_progress(
    path: Path,
    *,
    status: str,
    prompt_offset: int,
    prompt_count: int,
    completed_prompt_ids: Sequence[str],
    current_prompt_id: Optional[str],
    generated_test_tokens: int,
    test_decode_seconds: float,
) -> None:
    write_json(
        path,
        {
            "status": status,
            "prompt_offset": prompt_offset,
            "prompt_count": prompt_count,
            "completed_prompt_count": len(completed_prompt_ids),
            "completed_prompt_ids": list(completed_prompt_ids),
            "current_prompt_id": current_prompt_id,
            "generated_test_tokens": generated_test_tokens,
            "test_decode_seconds": test_decode_seconds,
            "updated_unix_seconds": time.time(),
        },
    )


def discover_model_path() -> Optional[Path]:
    env = os.environ.get("EPISTEMOS_KV_DIRECT_MODEL_PATH")
    if env:
        path = Path(env)
        if usable_model_path(path):
            return path
    user = os.environ.get("USER") or os.environ.get("LOGNAME")
    roots = []
    home = os.environ.get("HOME")
    if home:
        roots.append(Path(home) / "Library/Application Support/Epistemos/Models")
    if user:
        roots.append(Path("/Users") / user / "Library/Application Support/Epistemos/Models")
    for root in roots:
        repo = root / "text/hub" / DEFAULT_MODEL_SLUG
        snapshots = repo / "snapshots"
        if snapshots.exists():
            for child in sorted(snapshots.iterdir()):
                if usable_model_path(child):
                    return child
        if usable_model_path(repo):
            return repo
    return None


def usable_model_path(path: Path) -> bool:
    if not path.exists():
        return False
    return (
        (path / "config.json").exists()
        and (path / "tokenizer.json").exists()
        and any(p.suffix in {".safetensors", ".gguf", ".npz"} for p in path.iterdir())
    )


def infer_repo_id(path: Path) -> str:
    for part in path.parts:
        if part.startswith("models--"):
            pieces = part.removeprefix("models--").split("--")
            if len(pieces) >= 2:
                return f"{pieces[0]}/{'--'.join(pieces[1:])}"
            return part.removeprefix("models--")
    return "unknown"


def execution_shape(args: argparse.Namespace, suite: dict, suite_count: int) -> tuple[int, int, int]:
    suite_context = int(suite.get("target_context_tokens", FULL_CONTEXT_TOKENS))
    suite_decode = int(suite.get("decode_tokens_per_prompt", FULL_DECODE_TOKENS))
    if args.allow_full_suite:
        max_prompts = args.max_prompts or suite_count
        context_tokens = args.context_tokens or suite_context
        decode_tokens = args.decode_tokens or suite_decode
    else:
        max_prompts = min(args.max_prompts or SMOKE_PROMPTS, SMOKE_PROMPTS)
        context_tokens = min(args.context_tokens or SMOKE_CONTEXT_TOKENS, SMOKE_CONTEXT_TOKENS)
        decode_tokens = min(args.decode_tokens or SMOKE_DECODE_TOKENS, SMOKE_DECODE_TOKENS)
    return max_prompts, context_tokens, decode_tokens


def materialize_tokens(tokenizer: Any, spec: dict, target_context_tokens: int) -> mx.array:
    anchor = str(spec.get("anchor", "KV direct prompt block."))
    query = str(spec.get("query", "Return the witnessed answer."))
    block = f"{anchor}\n"
    suffix = f"\nQuery: {query}\nAnswer:"
    block_tokens = encode(tokenizer, block)
    suffix_tokens = encode(tokenizer, suffix)
    if not block_tokens:
        block_tokens = [0]
    body_budget = max(target_context_tokens - len(suffix_tokens), 1)
    repeats = max(1, math.ceil(body_budget / len(block_tokens)))
    body = (block_tokens * repeats)[:body_budget]
    tokens = body + suffix_tokens
    return mx.array(tokens[:target_context_tokens])


def encode(tokenizer: Any, text: str) -> List[int]:
    try:
        return list(tokenizer.encode(text, add_special_tokens=False))
    except TypeError:
        return list(tokenizer.encode(text))


def run_route(
    model: Any,
    tokens: mx.array,
    *,
    decode_tokens: int,
    prefill_step_size: int,
    route: str,
    kv_bits: Optional[int],
    kv_group_size: int,
    quantized_kv_start: int,
    cache_file: Optional[Path],
) -> tuple[mx.array, int]:
    if route == "prompt_cache_reload":
        if cache_file is None:
            raise RuntimeError("prompt_cache_reload requires a cache file path")
        return run_prompt_cache_reload_route(
            model,
            tokens,
            decode_tokens=decode_tokens,
            prefill_step_size=prefill_step_size,
            cache_file=cache_file,
        )

    produced = 0
    first_logprobs = None
    kwargs = {
        "max_tokens": decode_tokens,
        "prefill_step_size": prefill_step_size,
    }
    if route == "kv_quantized":
        kwargs.update(
            {
                "kv_bits": kv_bits,
                "kv_group_size": kv_group_size,
                "quantized_kv_start": quantized_kv_start,
            }
        )
    for _token, logprobs in generate_step(tokens, model, **kwargs):
        if first_logprobs is None:
            first_logprobs = logprobs
        produced += 1
        if produced >= decode_tokens:
            break
    if first_logprobs is None:
        raise RuntimeError("model produced no logits")
    mx.eval(first_logprobs)
    return first_logprobs, produced


def run_prompt_cache_reload_route(
    model: Any,
    tokens: mx.array,
    *,
    decode_tokens: int,
    prefill_step_size: int,
    cache_file: Path,
) -> tuple[mx.array, int]:
    if len(tokens) < 2:
        raise RuntimeError("prompt_cache_reload requires at least two prompt tokens")

    cache_file.parent.mkdir(parents=True, exist_ok=True)
    prefix = tokens[:-1]
    final_token = tokens[-1:]

    prompt_cache = make_prompt_cache(model)
    for _token, _logprobs in generate_step(
        prefix,
        model,
        max_tokens=0,
        prompt_cache=prompt_cache,
        prefill_step_size=prefill_step_size,
    ):
        pass
    save_prompt_cache(
        str(cache_file),
        prompt_cache,
        {
            "route": "prompt_cache_reload",
            "format": "mlx_prompt_cache",
            "witness": "file_backed_reload_intermediate",
        },
    )
    mx.clear_cache()

    reloaded_cache = load_prompt_cache(str(cache_file))
    produced = 0
    first_logprobs = None
    for _token, logprobs in generate_step(
        final_token,
        model,
        max_tokens=decode_tokens,
        prompt_cache=reloaded_cache,
        prefill_step_size=prefill_step_size,
    ):
        if first_logprobs is None:
            first_logprobs = logprobs
        produced += 1
        if produced >= decode_tokens:
            break
    if first_logprobs is None:
        raise RuntimeError("prompt_cache_reload produced no logits")
    mx.eval(first_logprobs)
    return first_logprobs, produced


def prompt_cache_trace(cache_file: Path, prompt_id: str) -> dict[str, Any]:
    stat = cache_file.stat()
    return {
        "prompt_id": prompt_id,
        "cache_file": str(cache_file),
        "cache_bytes": stat.st_size,
        "file_backed_reload": True,
    }


def spill_trace_reason(route: str) -> str:
    if route == "prompt_cache_reload":
        return (
            "The runner saved and reloaded an MLX prompt cache from disk before "
            "emitting test logits. This is a file-backed cache reload witness, "
            "not the final residual-patched mmap/NF4 SSD-spill KV-Direct route."
        )
    if route == "kv_quantized":
        return (
            "The runner emitted KV-quantized MLX logits for development. It does "
            "not exercise the SSD-spill KV-Direct route."
        )
    return "The runner emitted full-KV MLX logits; no SSD-spill route was exercised."


def logprobs_to_list(logprobs: mx.array) -> List[float]:
    values = np.array(logprobs.astype(mx.float32)).astype(np.float32).reshape(-1)
    return [float(v) for v in values]


def peak_rss_gb() -> float:
    rss = float(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
    if platform.system() != "Darwin":
        rss *= 1024.0
    return rss / 1_000_000_000.0


if __name__ == "__main__":
    raise SystemExit(main())
