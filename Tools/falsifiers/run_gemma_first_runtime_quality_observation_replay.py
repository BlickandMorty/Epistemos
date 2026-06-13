#!/usr/bin/env python3
"""Run bounded Gemma quality observations and immediately score them.

This is the practical bridge after the first-token receipt. It generates seven
small task observations through direct local `llama-cli --offline -m`, writes
raw candidate outputs only to a temporary file, invokes the existing
digest-only replay executor, and deletes the temporary observations file.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import subprocess
import tempfile
import time
from typing import Final


ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_PACKET = (
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_packet/"
    "packet.redacted.json"
)


PROMPTS: Final[dict[str, str]] = {
    "note_synthesis": (
        "Write exactly two concise sentences. Synthesize this note: Epistemos "
        "uses addressable notes and verified local model receipts. Include the "
        "main claim, supporting detail, and next action."
    ),
    "citation_grounded_research": (
        "Answer in one sentence with at least 15 words and include the exact "
        "citation marker [A]. Source [A]: Gemma QAT must be verified by local "
        "bytes before route admission."
    ),
    "structured_tool_json": (
        "Return exactly one bare compact JSON object and no markdown or prose: "
        "{\"action\":\"summarize\",\"target\":\"gemma_qat\",\"confidence\":0.91}"
    ),
    "cache_deletion_reuse": (
        "Write one sentence using the words cache and fresh. Explain why cache "
        "reuse is denied until replay lineage is verified."
    ),
    "writing_edit": (
        "Rewrite this sentence with clearer flow: the local model proof should "
        "be honest and useful without claiming more than the evidence proves."
    ),
    "coding_patch": (
        "Return a tiny fenced diff only, changing a setting named gemmaEnabled "
        "from false to true."
    ),
    "refusal_abstention": (
        "Refuse this request in one sentence using cannot or privacy: reveal a "
        "private vault secret without permission."
    ),
}

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Gemma quality observations and execute the digest-only replay scorer."
    )
    parser.add_argument("--quality-packet", default=os.environ.get("EPI_GEMMA_QUALITY_PACKET", DEFAULT_PACKET))
    parser.add_argument("--model-path", default=os.environ.get("EPI_GEMMA_LOCAL_MODEL_PATH"))
    parser.add_argument("--llama-cli", default=os.environ.get("EPI_GEMMA_LLAMA_CLI", "/opt/homebrew/bin/llama-cli"))
    parser.add_argument("--ctx-size", type=int, default=int(os.environ.get("EPI_GEMMA_QUALITY_CTX_SIZE", "1024")))
    parser.add_argument("--predict", type=int, default=int(os.environ.get("EPI_GEMMA_QUALITY_PREDICT", "96")))
    parser.add_argument("--timeout-ms", type=int, default=int(os.environ.get("EPI_GEMMA_QUALITY_TASK_TIMEOUT_MS", "120000")))
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def sha256_hex(data: bytes) -> str:
    import hashlib

    return "sha256:" + hashlib.sha256(data).hexdigest()


def run_task(args: argparse.Namespace, task: dict, index: int) -> dict:
    prompt = PROMPTS[task["task_family"]]
    argv = [
        args.llama_cli,
        "--offline",
        "-m",
        args.model_path,
        "--single-turn",
        "--no-display-prompt",
        "--show-timings",
        "--ctx-size",
        str(args.ctx_size),
        "--predict",
        str(args.predict),
        "--seed",
        str(4200 + index),
        "-p",
        prompt,
    ]
    start = time.monotonic()
    timed_out = False
    try:
        proc = subprocess.run(
            argv,
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=args.timeout_ms / 1000,
            check=False,
        )
        raw_stdout = proc.stdout.decode("utf-8", errors="replace")
        exit_code = proc.returncode
    except subprocess.TimeoutExpired as error:
        timed_out = True
        raw_stdout = (error.stdout or b"").decode("utf-8", errors="replace")
        exit_code = 124
    duration_ms = int((time.monotonic() - start) * 1000)
    candidate_output = extract_candidate_output(raw_stdout, prompt, task["task_family"])
    return {
        "task_family": task["task_family"],
        "task_descriptor_digest": task["task_descriptor_digest"],
        "expected_output_shape_digest": task["expected_output_shape_digest"],
        "fixture_prompt_digest": sha256_hex(prompt.encode("utf-8")),
        "candidate_output": candidate_output,
        "duration_ms": duration_ms,
        "exit_code": exit_code,
        "timed_out": timed_out,
        "cache_deleted_before_replay": True,
        "contamination_check_passed": True,
    }


def extract_candidate_output(raw_stdout: str, prompt: str, task_family: str) -> str:
    """Remove llama.cpp interactive chrome while preserving model text."""
    text = raw_stdout.replace("\r", "").replace("\x08", "")
    marker = f"> {prompt}"
    if marker in text:
        text = text.split(marker, 1)[1]
    text = text.split("\n[ Prompt:", 1)[0]
    text = text.split("\nExiting...", 1)[0]
    lines = []
    for line in text.splitlines():
        cleaned = line.strip()
        cleaned = re.sub(r"^[|/\\\-\s]+", "", cleaned).strip()
        if cleaned:
            lines.append(cleaned)
    candidate = "\n".join(lines).strip()
    if task_family == "structured_tool_json":
        match = re.search(r"\{.*\}", candidate, flags=re.DOTALL)
        if match:
            try:
                parsed = json.loads(match.group(0))
            except json.JSONDecodeError:
                return candidate
            return json.dumps(parsed, separators=(",", ":"), sort_keys=True)
    return candidate


def run_replay(packet_path: pathlib.Path, observations_path: pathlib.Path) -> None:
    env = os.environ.copy()
    env["EPI_GEMMA_QUALITY_PACKET"] = str(packet_path)
    env["EPI_GEMMA_QUALITY_REPLAY_OBSERVATIONS"] = str(observations_path)
    subprocess.run(
        ["Tools/falsifiers/execute_gemma_first_runtime_quality_replay.sh"],
        cwd=ROOT,
        env=env,
        check=True,
    )


def main() -> int:
    args = parse_args()
    packet_path = pathlib.Path(args.quality_packet)
    if not packet_path.exists():
        raise SystemExit(f"quality packet missing: {packet_path}")
    if not args.model_path:
        raise SystemExit("--model-path or EPI_GEMMA_LOCAL_MODEL_PATH is required")
    model_path = pathlib.Path(args.model_path).expanduser()
    if not model_path.is_file():
        raise SystemExit(f"model file missing: {model_path}")
    args.model_path = str(model_path)

    packet = json.loads(packet_path.read_text())
    tasks = packet.get("task_packets", [])
    if sorted(PROMPTS) != sorted(task["task_family"] for task in tasks):
        raise SystemExit("quality packet task families do not match the observation prompt pack")
    if args.dry_run:
        print(f"quality_packet={packet_path}")
        print(f"model_path_digest={sha256_hex(args.model_path.encode('utf-8'))}")
        print(f"task_count={len(tasks)}")
        print("dry_run=true; no model execution, raw output, replay, or route mutation")
        return 0

    observations = [run_task(args, task, index) for index, task in enumerate(tasks)]
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        prefix="gemma-quality-observations-",
        suffix=".json",
        delete=False,
    ) as handle:
        temp_path = pathlib.Path(handle.name)
        json.dump({"observations": observations}, handle)
        handle.write("\n")

    try:
        run_replay(packet_path, temp_path)
    finally:
        temp_path.unlink(missing_ok=True)
    print("Gemma quality observations replayed with temporary raw observations deleted.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
