#!/usr/bin/env python3
"""Acquire one official Gemma 4 QAT GGUF into explicit local quarantine.

This is an acquisition bridge, not a runtime proof. It downloads exactly one
official Google QAT Q4_0 GGUF file to an explicit Application Support
quarantine directory, verifies byte count and SHA256, and optionally invokes
the existing digest-only owner-approved receipt materializer. It does not run
`llama-cli`, start a server, use `-hf` as runtime proof, or mutate any route.
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import os
import pathlib
import shlex
import subprocess
import sys
from typing import Final

from huggingface_hub import hf_hub_download


ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_DEST_ROOT = (
    pathlib.Path.home()
    / "Library"
    / "Application Support"
    / "Epistemos"
    / "ModelQuarantine"
    / "GemmaQAT"
)


@dataclasses.dataclass(frozen=True)
class Lane:
    name: str
    repo_id: str
    revision: str
    filename: str
    byte_count: int
    sha256: str
    label: str


LANES: Final[dict[str, Lane]] = {
    "e2b": Lane(
        name="e2b",
        repo_id="google/gemma-4-E2B-it-qat-q4_0-gguf",
        revision="1894d1fc0a19d86697abd40483f5983c867df03f",
        filename="gemma-4-E2B_q4_0-it.gguf",
        byte_count=3_349_514_112,
        sha256="3646b4c147cd235a44d91df1546d3b7d8e29b547dbe4e1f80856419aa455e6fd",
        label="Gemma 4 E2B QAT GGUF first proof",
    ),
    "e4b": Lane(
        name="e4b",
        repo_id="google/gemma-4-E4B-it-qat-q4_0-gguf",
        revision="bb3b92e6f031fa438b409f898dd9f14f499a0cb0",
        filename="gemma-4-E4B_q4_0-it.gguf",
        byte_count=5_154_939_136,
        sha256="e8b6a059ba86947a44ace84d6e5679795bc41862c25c30513142588f0e9dba1d",
        label="Gemma 4 E4B QAT GGUF balanced lane",
    ),
    "12b": Lane(
        name="12b",
        repo_id="google/gemma-4-12B-it-qat-q4_0-gguf",
        revision="f6e7774e6148da3b7f201e42ba37cf084c1db35f",
        filename="gemma-4-12b-it-qat-q4_0.gguf",
        byte_count=6_975_877_728,
        sha256="faff1a63667fac17ac5e777f47114688fcefea96e220e211aaa8d62c2c4561f1",
        label="Gemma 4 12B QAT GGUF Pro flagship candidate",
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Acquire and verify one official Gemma 4 QAT Q4_0 GGUF file."
    )
    parser.add_argument("--lane", choices=sorted(LANES), default="e2b")
    parser.add_argument("--dest-root", type=pathlib.Path, default=DEFAULT_DEST_ROOT)
    parser.add_argument("--owner-approval-phrase", default=os.environ.get("EPI_GEMMA_OWNER_APPROVAL_PHRASE"))
    parser.add_argument("--llama-cli", default=os.environ.get("EPI_GEMMA_LLAMA_CLI", "/opt/homebrew/bin/llama-cli"))
    parser.add_argument("--force-download", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--materialize-receipt", action="store_true")
    return parser.parse_args()


def destination_for(lane: Lane, dest_root: pathlib.Path) -> pathlib.Path:
    repo_dir = lane.repo_id.replace("/", "--")
    return dest_root.expanduser() / repo_dir / lane.revision


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(16 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_file(path: pathlib.Path, lane: Lane) -> None:
    if path.name != lane.filename:
        raise SystemExit(f"wrong filename: expected {lane.filename}, observed {path.name}")
    observed_size = path.stat().st_size
    if observed_size != lane.byte_count:
        raise SystemExit(
            f"wrong byte count for {path}: expected {lane.byte_count}, observed {observed_size}"
        )
    observed_sha = sha256_file(path)
    if observed_sha != lane.sha256:
        raise SystemExit(
            f"wrong sha256 for {path}: expected {lane.sha256}, observed {observed_sha}"
        )


def download_or_select(lane: Lane, dest_dir: pathlib.Path, args: argparse.Namespace) -> pathlib.Path:
    path = dest_dir / lane.filename
    if args.verify_only:
        if not path.exists():
            raise SystemExit(f"verify-only file missing: {path}")
        return path

    dest_dir.mkdir(parents=True, exist_ok=True)
    downloaded = hf_hub_download(
        repo_id=lane.repo_id,
        filename=lane.filename,
        revision=lane.revision,
        repo_type="model",
        local_dir=str(dest_dir),
        local_dir_use_symlinks=False,
        force_download=args.force_download,
        token=os.environ.get("HF_TOKEN") or None,
    )
    return pathlib.Path(downloaded).resolve()


def materialize_receipt(path: pathlib.Path, lane: Lane, args: argparse.Namespace) -> None:
    if not args.owner_approval_phrase:
        raise SystemExit("EPI_GEMMA_OWNER_APPROVAL_PHRASE or --owner-approval-phrase is required")

    env = os.environ.copy()
    env.update(
        {
            "EPI_GEMMA_OWNER_APPROVAL_PHRASE": args.owner_approval_phrase,
            "EPI_GEMMA_LOCAL_MODEL_PATH": str(path),
            "EPI_GEMMA_SELECTED_MODEL_ID": lane.repo_id,
            "EPI_GEMMA_SOURCE_REPO": lane.repo_id,
            "EPI_GEMMA_EXPECTED_FILENAME": lane.filename,
            "EPI_GEMMA_EXPECTED_BYTE_COUNT": str(lane.byte_count),
            "EPI_GEMMA_EXPECTED_LFS_SHA256": lane.sha256,
            "EPI_GEMMA_SOURCE_REVISION": lane.revision,
            "EPI_GEMMA_SOURCE_LICENSE_REF": "apache-2.0",
            "EPI_GEMMA_PROVENANCE_MODE": "owner_approved_hf_snapshot_download_to_quarantine",
            "EPI_GEMMA_HARDWARE_PROFILE_REF": "hardware:local-owner-approved-quarantine",
            "EPI_GEMMA_LLAMA_CLI": args.llama_cli,
        }
    )
    subprocess.run(
        ["Tools/falsifiers/materialize_gemma_owner_approved_local_artifact_receipt.sh"],
        cwd=ROOT,
        env=env,
        check=True,
    )


def print_next_commands(path: pathlib.Path, lane: Lane, args: argparse.Namespace) -> None:
    quoted_path = shlex.quote(str(path))
    print(f"Gemma QAT artifact verified: {lane.label}")
    print(f"repo={lane.repo_id}")
    print(f"revision={lane.revision}")
    print(f"file={quoted_path}")
    print(f"bytes={lane.byte_count}")
    print(f"sha256={lane.sha256}")
    if not args.materialize_receipt:
        print("\nReceipt command:")
        print('export EPI_GEMMA_OWNER_APPROVAL_PHRASE="<owner approval phrase>"')
        print(f"export EPI_GEMMA_LOCAL_MODEL_PATH={quoted_path}")
        print(f"export EPI_GEMMA_SELECTED_MODEL_ID={shlex.quote(lane.repo_id)}")
        print(f"export EPI_GEMMA_SOURCE_REPO={shlex.quote(lane.repo_id)}")
        print(f"export EPI_GEMMA_EXPECTED_FILENAME={shlex.quote(lane.filename)}")
        print(f'export EPI_GEMMA_EXPECTED_BYTE_COUNT="{lane.byte_count}"')
        print(f"export EPI_GEMMA_EXPECTED_LFS_SHA256={shlex.quote(lane.sha256)}")
        print(f"export EPI_GEMMA_SOURCE_REVISION={shlex.quote(lane.revision)}")
        print('export EPI_GEMMA_SOURCE_LICENSE_REF="apache-2.0"')
        print(f"export EPI_GEMMA_LLAMA_CLI={shlex.quote(args.llama_cli)}")
        print("Tools/falsifiers/materialize_gemma_owner_approved_local_artifact_receipt.sh")


def main() -> int:
    args = parse_args()
    lane = LANES[args.lane]
    dest_dir = destination_for(lane, args.dest_root)
    if args.dry_run:
        print(f"lane={lane.name}")
        print(f"repo={lane.repo_id}")
        print(f"revision={lane.revision}")
        print(f"filename={lane.filename}")
        print(f"dest={dest_dir / lane.filename}")
        print("dry_run=true; no download, hash, receipt, runtime, or route mutation")
        return 0

    path = download_or_select(lane, dest_dir, args)
    verify_file(path, lane)
    if args.materialize_receipt:
        materialize_receipt(path, lane, args)
    print_next_commands(path, lane, args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
