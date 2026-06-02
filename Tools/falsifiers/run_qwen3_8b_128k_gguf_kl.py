#!/usr/bin/env python3
"""llama.cpp KL runner for the Qwen3-8B 128K GGUF candidate route."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
PLAN_PATH = REPO_ROOT / "artifacts/falsifiers/qwen3_8b_128k_gguf_route/asset_plan.json"
DEFAULT_OUTPUT_DIR = REPO_ROOT / "artifacts/falsifiers/qwen3_8b_128k_gguf_route/live_kl"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run llama-perplexity KL witness")
    parser.add_argument("--asset-plan", type=Path, default=PLAN_PATH)
    parser.add_argument("--model-path", type=Path, default=None)
    parser.add_argument("--runner", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--context-tokens", type=int, default=128)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--ubatch-size", type=int, default=64)
    parser.add_argument("--gpu-layers", type=int, default=99)
    parser.add_argument("--reference-cache-type", default="f16")
    parser.add_argument("--test-cache-type", default="q4_0")
    parser.add_argument("--allow-full-suite", action="store_true")
    parser.add_argument("--keep-logits", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.allow_full_suite and args.context_tokens > 4096:
        raise SystemExit("refusing non-smoke KL run without --allow-full-suite")

    plan = read_json(args.asset_plan)
    model_path = args.model_path or Path(plan["default_local_paths"]["model_file"])
    runner = args.runner or find_runner("llama-perplexity")
    if runner is None:
        raise SystemExit("llama-perplexity not found; install llama.cpp or pass --runner")
    if not model_path.is_file():
        raise SystemExit(f"GGUF model file is missing: {model_path}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    prompt_path = args.output_dir / "prompt.txt"
    reference_logits = args.output_dir / "reference_logits.bin"
    reference_stdout = args.output_dir / "reference.stdout"
    reference_stderr = args.output_dir / "reference.stderr"
    test_stdout = args.output_dir / "test.stdout"
    test_stderr = args.output_dir / "test.stderr"
    kl_metrics_path = args.output_dir / "kl_metrics.json"
    manifest_path = args.output_dir / "manifest.json"

    prompt_path.write_text(materialize_prompt(args.context_tokens), encoding="utf-8")
    reference_cmd = [
        str(runner),
        "-m",
        str(model_path),
        "-f",
        str(prompt_path),
        "-c",
        str(args.context_tokens),
        "-b",
        str(args.batch_size),
        "-ub",
        str(args.ubatch_size),
        "-ngl",
        str(args.gpu_layers),
        "-ctk",
        args.reference_cache_type,
        "-ctv",
        args.reference_cache_type,
        "--save-all-logits",
        str(reference_logits),
    ]
    test_cmd = [
        str(runner),
        "-m",
        str(model_path),
        "-f",
        str(prompt_path),
        "-c",
        str(args.context_tokens),
        "-b",
        str(args.batch_size),
        "-ub",
        str(args.ubatch_size),
        "-ngl",
        str(args.gpu_layers),
        "-ctk",
        args.test_cache_type,
        "-ctv",
        args.test_cache_type,
        "--kl-divergence",
        "--kl-divergence-base",
        str(reference_logits),
    ]
    started = time.perf_counter()
    ref_proc = run(reference_cmd, reference_stdout, reference_stderr)
    test_proc = run(test_cmd, test_stdout, test_stderr) if ref_proc.returncode == 0 else None
    elapsed_s = time.perf_counter() - started

    test_text = test_stdout.read_text(encoding="utf-8") if test_stdout.exists() else ""
    kl = parse_kl_stats(test_text)
    if reference_logits.exists() and not args.keep_logits:
        reference_logits.unlink()
    metrics = {
        "prompt_count": 1,
        "context_window_tokens": args.context_tokens,
        "average_d_kl_nats": kl.get("mean_kld", 999.0),
        "max_d_kl_nats": kl.get("max_kld", 999.0),
        "p99_d_kl_nats": kl.get("p99_kld", 999.0),
        "same_top_p_percent": kl.get("same_top_p_percent", 0.0),
        "reference_route": f"llama_perplexity_{args.reference_cache_type}_kv",
        "test_route": f"llama_perplexity_{args.test_cache_type}_kv",
        "reference_status": ref_proc.returncode,
        "test_status": test_proc.returncode if test_proc else -1,
        "suite_wall_clock_min": elapsed_s / 60.0,
        "reference_logits_retained": bool(args.keep_logits),
        "reference_logits_path": str(reference_logits),
        "falsifier_green_capable": False,
    }
    kl_metrics_path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    manifest = {
        "runner": str(runner),
        "model_path": str(model_path),
        "reference_command": reference_cmd,
        "test_command": test_cmd,
        "output_dir": str(args.output_dir),
        "kl_metrics": str(kl_metrics_path),
        "falsifier_green_capable": False,
        "reason": "Default KL run is smoke-sized; full route still requires 100 prompts and 128K context.",
        "env_for_falsifier": {
            "EPISTEMOS_QWEN3_8B_128K_GGUF_KL_METRICS_PATH": str(kl_metrics_path)
        },
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    return 0 if ref_proc.returncode == 0 and test_proc and test_proc.returncode == 0 else 1


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def find_runner(name: str) -> Path | None:
    resolved = shutil.which(name)
    return Path(resolved) if resolved else None


def materialize_prompt(context_tokens: int) -> str:
    unit = (
        "Epistemos GGUF KL witness retains checksum delta-41411, owner local, "
        "and exception clause no-product-claim. "
    )
    repeats = 80 if context_tokens <= 4096 else max(80, context_tokens // 8)
    return unit * repeats


def run(command: list[str], stdout_path: Path, stderr_path: Path) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(command, text=True, capture_output=True, check=False)
    stdout_path.write_text(proc.stdout, encoding="utf-8")
    stderr_path.write_text(proc.stderr, encoding="utf-8")
    return proc


def parse_kl_stats(text: str) -> dict[str, float]:
    return {
        "mean_kld": find_float(text, r"Mean\s+KLD:\s+([-0-9.]+)"),
        "max_kld": find_float(text, r"Maximum KLD:\s+([-0-9.]+)"),
        "p99_kld": find_float(text, r"99\.0%\s+KLD:\s+([-0-9.]+)"),
        "same_top_p_percent": find_float(text, r"Same top p:\s+([-0-9.]+)"),
    }


def find_float(text: str, pattern: str) -> float:
    match = re.search(pattern, text)
    return float(match.group(1)) if match else 999.0


if __name__ == "__main__":
    sys.exit(main())
