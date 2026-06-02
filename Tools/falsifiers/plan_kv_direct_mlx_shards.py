#!/usr/bin/env python3
"""Write a restartable shard plan for the F-KV-Direct-Gate MLX runner.

The full KV-Direct live suite is intentionally too large to treat as an
ad-hoc terminal command. This planner turns the canonical prompt suite into a
small manifest that future agents can execute shard-by-shard, merge, and feed
back into `F-KV-Direct-Gate`.

The current MLX runner routes are development witnesses only. The generated
plan records that fact so a prompt-cache reload or KV-quantized run cannot be
mistaken for the final residual-patched mmap/NF4 SSD-spill route.
"""

from __future__ import annotations

import argparse
import json
import shlex
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PROMPT_SUITE = REPO_ROOT / "artifacts/falsifiers/kv_direct_gate/prompt_suite.json"
DEFAULT_PLAN_DIR = REPO_ROOT / "artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan"
DEFAULT_SHARD_ROOT = REPO_ROOT / "artifacts/falsifiers/kv_direct_gate/live_mlx_shards"
DEFAULT_MERGE_OUTPUT = REPO_ROOT / "artifacts/falsifiers/kv_direct_gate/live_mlx_merged"
RUNNER = "Tools/falsifiers/run_kv_direct_mlx_live.sh"
MERGER = "Tools/falsifiers/merge_kv_direct_mlx_shards.sh"
FALSIFIER = "Tools/falsifiers/f_kv_direct_gate.sh"
CANONICAL_MODEL_REPO_ID = "Qwen/Qwen3-8B-MLX-4bit"
CANONICAL_SPILL_ROUTE = "residual_patched_mmap_nf4_ssd_spill"
CURRENT_RUNNER_ROUTES = {"full_kv", "kv_quantized", "prompt_cache_reload"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Plan the sharded KV-Direct MLX live suite")
    parser.add_argument("--prompt-suite", type=Path, default=DEFAULT_PROMPT_SUITE)
    parser.add_argument("--plan-dir", type=Path, default=DEFAULT_PLAN_DIR)
    parser.add_argument("--shard-root", type=Path, default=DEFAULT_SHARD_ROOT)
    parser.add_argument("--merge-output-dir", type=Path, default=DEFAULT_MERGE_OUTPUT)
    parser.add_argument("--model-path", type=Path, default=None)
    parser.add_argument("--shard-size", type=int, default=25)
    parser.add_argument("--context-tokens", type=int, default=None)
    parser.add_argument("--decode-tokens", type=int, default=None)
    parser.add_argument("--prefill-step-size", type=int, default=512)
    parser.add_argument(
        "--test-route",
        choices=sorted(CURRENT_RUNNER_ROUTES),
        default="prompt_cache_reload",
    )
    parser.add_argument("--runner", default=RUNNER)
    parser.add_argument("--merger", default=MERGER)
    parser.add_argument("--write-shell", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.shard_size <= 0:
        raise SystemExit("--shard-size must be positive")

    suite = read_json(args.prompt_suite)
    prompts = suite.get("prompts")
    if not isinstance(prompts, list) or not prompts:
        raise SystemExit(f"prompt suite has no prompts: {args.prompt_suite}")

    target_context_tokens = int(args.context_tokens or suite.get("target_context_tokens", 0))
    decode_tokens_per_prompt = int(args.decode_tokens or suite.get("decode_tokens_per_prompt", 0))
    if target_context_tokens <= 0 or decode_tokens_per_prompt <= 0:
        raise SystemExit("prompt suite must declare target context and decode token counts")

    shards = build_shards(
        prompts=prompts,
        shard_size=args.shard_size,
        shard_root=args.shard_root,
        prompt_suite=args.prompt_suite,
        runner=args.runner,
        model_path=args.model_path,
        test_route=args.test_route,
        context_tokens=target_context_tokens,
        decode_tokens=decode_tokens_per_prompt,
        prefill_step_size=args.prefill_step_size,
    )
    merge_command = [
        args.merger,
        "--output-dir",
        str(args.merge_output_dir),
        *[shard["output_dir"] for shard in shards],
    ]
    plan = {
        "plan_id": "qwen3_8b_128k_kv_direct_full_suite_shards_v1",
        "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "prompt_suite": str(args.prompt_suite),
        "model_path": str(args.model_path) if args.model_path else None,
        "model_repo_id": infer_repo_id(args.model_path) if args.model_path else "auto:canonical-default",
        "canonical_model_repo_id": CANONICAL_MODEL_REPO_ID,
        "model_identity_matches_canonical": (
            infer_repo_id(args.model_path) == CANONICAL_MODEL_REPO_ID if args.model_path else True
        ),
        "model_identity_note": (
            "Unset model_path means the runner auto-detects the canonical Qwen3-8B MLX asset. "
            "Explicit noncanonical model paths are candidate-tier development plans and cannot satisfy F-KV-Direct-Gate."
        ),
        "prompt_count": len(prompts),
        "target_context_tokens": target_context_tokens,
        "decode_tokens_per_prompt": decode_tokens_per_prompt,
        "prefill_step_size": args.prefill_step_size,
        "shard_size": args.shard_size,
        "shard_count": len(shards),
        "test_route": args.test_route,
        "route_is_current_runner_development_route": args.test_route in CURRENT_RUNNER_ROUTES,
        "canonical_spill_route_required": CANONICAL_SPILL_ROUTE,
        "falsifier_green_capable": args.test_route == CANONICAL_SPILL_ROUTE,
        "promotion_note": (
            "This plan maps the 100-prompt full-suite job. It does not make "
            "prompt_cache_reload, kv_quantized, or full_kv green for "
            "F-KV-Direct-Gate; only a residual-patched mmap/NF4 SSD-spill "
            "trace can satisfy the final spill axes."
        ),
        "runner": args.runner,
        "merger": args.merger,
        "merge_output_dir": str(args.merge_output_dir),
        "shards": shards,
        "merge_command": merge_command,
        "merge_command_text": shell_join(merge_command),
        "falsifier_env": {
            **(
                {"EPISTEMOS_KV_DIRECT_MODEL_PATH": str(args.model_path)}
                if args.model_path
                else {}
            ),
            "EPISTEMOS_KV_DIRECT_PROMPT_SUITE": str(args.prompt_suite),
            "EPISTEMOS_KV_DIRECT_REFERENCE_LOGITS": str(args.merge_output_dir / "reference_logits.json"),
            "EPISTEMOS_KV_DIRECT_TEST_LOGITS": str(args.merge_output_dir / "test_logits.json"),
            "EPISTEMOS_KV_DIRECT_METRICS_PATH": str(args.merge_output_dir / "metrics.json"),
            "EPISTEMOS_KV_DIRECT_SPILL_TRACE": str(args.merge_output_dir / "spill_trace.json"),
        },
        "falsifier_command": FALSIFIER,
    }

    if not args.dry_run:
        args.plan_dir.mkdir(parents=True, exist_ok=True)
        write_json(args.plan_dir / "full_suite_run_plan.json", plan)
        if args.write_shell:
            write_shell(args.plan_dir / "run_all_shards.sh", plan)

    print(
        json.dumps(
            {
                "plan_dir": str(args.plan_dir),
                "prompt_count": plan["prompt_count"],
                "shard_count": plan["shard_count"],
                "context_tokens": target_context_tokens,
                "decode_tokens_per_prompt": decode_tokens_per_prompt,
                "prefill_step_size": args.prefill_step_size,
                "test_route": args.test_route,
                "model_path": str(args.model_path) if args.model_path else None,
                "model_repo_id": infer_repo_id(args.model_path) if args.model_path else "auto:canonical-default",
                "model_identity_matches_canonical": (
                    infer_repo_id(args.model_path) == CANONICAL_MODEL_REPO_ID if args.model_path else True
                ),
                "falsifier_green_capable": plan["falsifier_green_capable"],
            },
            indent=2,
        )
    )
    return 0


def build_shards(
    *,
    prompts: list[Any],
    shard_size: int,
    shard_root: Path,
    prompt_suite: Path,
    runner: str,
    model_path: Path | None,
    test_route: str,
    context_tokens: int,
    decode_tokens: int,
    prefill_step_size: int,
) -> list[dict[str, Any]]:
    shards: list[dict[str, Any]] = []
    for offset in range(0, len(prompts), shard_size):
        chunk = prompts[offset : offset + shard_size]
        last = offset + len(chunk) - 1
        shard_id = f"shard_{offset:03}_{last:03}"
        output_dir = shard_root / shard_id
        command = [
            runner,
            "--allow-full-suite",
            "--prompt-suite",
            str(prompt_suite),
            "--prompt-offset",
            str(offset),
            "--max-prompts",
            str(len(chunk)),
            "--context-tokens",
            str(context_tokens),
            "--decode-tokens",
            str(decode_tokens),
            "--prefill-step-size",
            str(prefill_step_size),
            "--test-route",
            test_route,
            "--output-dir",
            str(output_dir),
        ]
        if model_path:
            command[1:1] = ["--model-path", str(model_path)]
        shards.append(
            {
                "shard_id": shard_id,
                "prompt_offset": offset,
                "max_prompts": len(chunk),
                "prompt_ids": [str(prompt.get("id", f"prompt_{offset + i:03}")) for i, prompt in enumerate(chunk)],
                "output_dir": str(output_dir),
                "run_command": command,
                "run_command_text": shell_join(command),
            }
        )
    return shards


def write_shell(path: Path, plan: dict[str, Any]) -> None:
    lines = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "",
        "# Generated by Tools/falsifiers/plan_kv_direct_mlx_shards.py",
    ]
    lines.extend(shard["run_command_text"] for shard in plan["shards"])
    lines.extend(
        [
            plan["merge_command_text"],
            *(
                [
                    f"export EPISTEMOS_KV_DIRECT_MODEL_PATH={shlex.quote(plan['falsifier_env']['EPISTEMOS_KV_DIRECT_MODEL_PATH'])}"
                ]
                if "EPISTEMOS_KV_DIRECT_MODEL_PATH" in plan["falsifier_env"]
                else []
            ),
            f"export EPISTEMOS_KV_DIRECT_PROMPT_SUITE={shlex.quote(plan['falsifier_env']['EPISTEMOS_KV_DIRECT_PROMPT_SUITE'])}",
            f"export EPISTEMOS_KV_DIRECT_REFERENCE_LOGITS={shlex.quote(plan['falsifier_env']['EPISTEMOS_KV_DIRECT_REFERENCE_LOGITS'])}",
            f"export EPISTEMOS_KV_DIRECT_TEST_LOGITS={shlex.quote(plan['falsifier_env']['EPISTEMOS_KV_DIRECT_TEST_LOGITS'])}",
            f"export EPISTEMOS_KV_DIRECT_METRICS_PATH={shlex.quote(plan['falsifier_env']['EPISTEMOS_KV_DIRECT_METRICS_PATH'])}",
            f"export EPISTEMOS_KV_DIRECT_SPILL_TRACE={shlex.quote(plan['falsifier_env']['EPISTEMOS_KV_DIRECT_SPILL_TRACE'])}",
            plan["falsifier_command"],
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")
    path.chmod(0o755)


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, value: Any) -> None:
    with path.open("w", encoding="utf-8") as f:
        json.dump(value, f, indent=2, sort_keys=True)
        f.write("\n")


def shell_join(command: list[str]) -> str:
    return shlex.join(command)


def infer_repo_id(path: Path | None) -> str:
    if path is None:
        return "unknown"
    for part in path.parts:
        if part.startswith("models--"):
            pieces = part.removeprefix("models--").split("--")
            if len(pieces) >= 2:
                return f"{pieces[0]}/{'--'.join(pieces[1:])}"
            return part.removeprefix("models--")
    return "unknown"


if __name__ == "__main__":
    raise SystemExit(main())
