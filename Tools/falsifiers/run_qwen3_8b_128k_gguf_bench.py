#!/usr/bin/env python3
"""llama.cpp bench runner for the Qwen3-8B 128K GGUF candidate route.

Default mode is a smoke-sized model-load and throughput witness. It writes the
metrics shape consumed by `falsify_qwen3_8b_128k_gguf_route.rs`, but it cannot
green the route by itself because the route still requires paired logits.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import signal
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
PLAN_PATH = REPO_ROOT / "artifacts/falsifiers/qwen3_8b_128k_gguf_route/asset_plan.json"
DEFAULT_OUTPUT_DIR = REPO_ROOT / "artifacts/falsifiers/qwen3_8b_128k_gguf_route/live_bench"
FULL_CONTEXT_TOKENS = 128_000
FULL_DECODE_TOKENS = 256
SAFE_CONTEXT_TOKENS = 32_768
HEAVY_RUN_ENV = "EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run llama-bench for the GGUF candidate route")
    parser.add_argument("--asset-plan", type=Path, default=PLAN_PATH)
    parser.add_argument("--model-path", type=Path, default=None)
    parser.add_argument("--runner", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--context-tokens", type=int, default=2048)
    parser.add_argument("--decode-tokens", type=int, default=16)
    parser.add_argument("--batch-size", type=int, default=512)
    parser.add_argument("--ubatch-size", type=int, default=256)
    parser.add_argument("--gpu-layers", type=int, default=99)
    parser.add_argument("--cache-type-k", default="f16")
    parser.add_argument("--cache-type-v", default="f16")
    parser.add_argument("--flash-attn", type=int, choices=[0, 1], default=0)
    parser.add_argument("--no-kv-offload", type=int, choices=[0, 1], default=0)
    parser.add_argument("--timeout-seconds", type=float, default=None)
    parser.add_argument("--allow-full-suite", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.allow_full_suite and (
        args.context_tokens > 4096 or args.decode_tokens > 64
    ):
        raise SystemExit(
            "refusing non-smoke GGUF bench without --allow-full-suite"
        )
    if args.context_tokens > SAFE_CONTEXT_TOKENS and os.environ.get(HEAVY_RUN_ENV) != "1":
        raise SystemExit(
            f"refusing >{SAFE_CONTEXT_TOKENS} context GGUF bench without "
            f"{HEAVY_RUN_ENV}=1; this path can stall Metal and destabilize "
            "the laptop"
        )

    plan = read_json(args.asset_plan)
    model_path = args.model_path or Path(plan["default_local_paths"]["model_file"])
    runner = args.runner or find_runner("llama-bench")
    if runner is None:
        raise SystemExit("llama-bench not found; install llama.cpp or pass --runner")
    if not model_path.is_file():
        raise SystemExit(f"GGUF model file is missing: {model_path}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    stdout_path = args.output_dir / "bench.json"
    stderr_path = args.output_dir / "bench.stderr"
    metrics_path = args.output_dir / "metrics.json"
    manifest_path = args.output_dir / "manifest.json"

    command = [
        "/usr/bin/time",
        "-l",
        str(runner),
        "-m",
        str(model_path),
        "-p",
        str(args.context_tokens),
        "-n",
        str(args.decode_tokens),
        "-r",
        "1",
        "-b",
        str(args.batch_size),
        "-ub",
        str(args.ubatch_size),
        "-ngl",
        str(args.gpu_layers),
        "-ctk",
        args.cache_type_k,
        "-ctv",
        args.cache_type_v,
        "-fa",
        str(args.flash_attn),
        "-nkvo",
        str(args.no_kv_offload),
        "-o",
        "json",
    ]
    started = time.perf_counter()
    timed_out = False
    proc = subprocess.Popen(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        stdout, stderr = proc.communicate(timeout=args.timeout_seconds)
        returncode = proc.returncode
    except subprocess.TimeoutExpired:
        timed_out = True
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            stdout, stderr = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            stdout, stderr = proc.communicate()
        returncode = 124
    elapsed_s = time.perf_counter() - started
    stdout_path.write_text(stdout, encoding="utf-8")
    stderr_path.write_text(stderr, encoding="utf-8")

    manifest: dict[str, Any] = {
        "runner": str(runner),
        "model_path": str(model_path),
        "command": command,
        "exit_status": returncode,
        "timed_out": timed_out,
        "timeout_seconds": args.timeout_seconds,
        "context_window_tokens": args.context_tokens,
        "decode_tokens_per_prompt": args.decode_tokens,
        "output_dir": str(args.output_dir),
        "bench_json": str(stdout_path),
        "bench_stderr": str(stderr_path),
        "metrics": str(metrics_path),
        "falsifier_green_capable": False,
        "reason": "llama-bench provides throughput/RSS only; paired reference/test logits remain required.",
    }
    if returncode != 0:
        if metrics_path.exists():
            metrics_path.unlink()
        manifest["metrics"] = "not_written"
        manifest["failure_reason"] = (
            "llama-bench timed out; stale metrics removed"
            if timed_out
            else "llama-bench exited non-zero; stale metrics removed"
        )
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        return returncode

    bench_rows = json.loads(stdout)
    prefill_row = first_row_with(bench_rows, "n_prompt")
    decode_row = first_row_with(bench_rows, "n_gen")
    peak_rss_bytes = parse_peak_rss_bytes(stderr)
    metrics = {
        "prompt_count": 1,
        "context_window_tokens": args.context_tokens,
        "decode_tokens_per_prompt": args.decode_tokens,
        "peak_ram_gb": peak_rss_bytes / (1024**3) if peak_rss_bytes else 999.0,
        "decode_tok_s": float(decode_row.get("avg_ts", 0.0)) if decode_row else 0.0,
        "suite_wall_clock_min": elapsed_s / 60.0,
        "prefill_tok_s": float(prefill_row.get("avg_ts", 0.0)) if prefill_row else 0.0,
        "runner": str(runner),
        "metrics_source": "llama_bench",
        "cache_type_k": args.cache_type_k,
        "cache_type_v": args.cache_type_v,
        "flash_attn": args.flash_attn,
        "no_kv_offload": args.no_kv_offload,
        "falsifier_green_capable": False,
    }
    metrics_path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    manifest["metrics"] = str(metrics_path)
    manifest["bench_summary"] = {
        "prefill_tok_s": metrics["prefill_tok_s"],
        "decode_tok_s": metrics["decode_tok_s"],
        "peak_ram_gb": metrics["peak_ram_gb"],
    }
    manifest["env_for_falsifier"] = {
        "EPISTEMOS_QWEN3_8B_128K_GGUF_METRICS_PATH": str(metrics_path)
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    return 0


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def find_runner(name: str) -> Path | None:
    resolved = shutil.which(name)
    return Path(resolved) if resolved else None


def first_row_with(rows: list[dict[str, Any]], key: str) -> dict[str, Any] | None:
    return next((row for row in rows if int(row.get(key, 0)) > 0), None)


def parse_peak_rss_bytes(stderr: str) -> int:
    match = re.search(r"([0-9]+)\s+maximum resident set size", stderr)
    return int(match.group(1)) if match else 0


if __name__ == "__main__":
    sys.exit(main())
