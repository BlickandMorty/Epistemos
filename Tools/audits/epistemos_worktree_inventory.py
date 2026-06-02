#!/usr/bin/env python3
"""Inventory local Epistemos-like folders/worktrees.

This is a read-only duplicate-surface scanner. It does not delete, move, fetch,
checkout, or reset anything. It exists so architecture loops can see whether
there are sibling worktrees or copied folders that may already contain related
work before creating another surface.
"""

from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SCAN_ROOT = REPO_ROOT.parent
DEFAULT_OUTPUT = REPO_ROOT / "docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Inventory local Epistemos worktrees/folders")
    parser.add_argument("--scan-root", type=Path, default=DEFAULT_SCAN_ROOT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--max-depth", type=int, default=1)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    candidates = discover_candidates(args.scan_root, args.max_depth)
    current_common = git_text(REPO_ROOT, ["rev-parse", "--git-common-dir"])
    current_common_abs = normalize_git_path(REPO_ROOT, current_common) if current_common else None
    current_top = git_text(REPO_ROOT, ["rev-parse", "--show-toplevel"])
    current_top_abs = str(Path(current_top).resolve()) if current_top else str(REPO_ROOT.resolve())
    entries = [inspect_candidate(path, current_top_abs, current_common_abs) for path in candidates]
    summary = summarize(entries)
    inventory = {
        "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "scan_root": str(args.scan_root),
        "current_repo": str(REPO_ROOT),
        "current_git_toplevel": current_top_abs,
        "current_git_common_dir": current_common_abs,
        "summary": summary,
        "entries": entries,
        "non_destructive": True,
        "next_rule": (
            "Before creating a new Epistemos worktree/folder, inspect entries "
            "where classification is current_repo, sibling_worktree, or "
            "dirty_epistemos_copy. Continue or preserve existing work instead "
            "of duplicating it."
        ),
    }
    if not args.dry_run:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "output": str(args.output),
                **summary,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


def discover_candidates(root: Path, max_depth: int) -> list[Path]:
    if max_depth != 1:
        raise SystemExit("only --max-depth 1 is supported for the safe local inventory")
    if not root.exists():
        return []
    candidates = []
    for child in sorted(root.iterdir(), key=lambda p: p.name.lower()):
        if child.is_dir() and "epistemos" in child.name.lower():
            candidates.append(child)
    if REPO_ROOT not in candidates:
        candidates.append(REPO_ROOT)
    return sorted({path.resolve() for path in candidates}, key=lambda p: str(p).lower())


def inspect_candidate(path: Path, current_top: str, current_common: str | None) -> dict[str, Any]:
    top = git_text(path, ["rev-parse", "--show-toplevel"])
    is_git = top is not None
    if not is_git:
        return {
            "path": str(path),
            "name": path.name,
            "is_git": False,
            "classification": "non_git_epistemos_folder",
            "duplicate_risk": "unknown_non_git_folder",
        }

    branch = git_text(path, ["branch", "--show-current"]) or "detached"
    head = git_text(path, ["rev-parse", "--short=12", "HEAD"]) or "unknown"
    remote = git_text(path, ["config", "--get", "remote.origin.url"]) or "none"
    common = git_text(path, ["rev-parse", "--git-common-dir"])
    common_abs = normalize_git_path(path, common) if common else None
    status = git_status_counts(path)
    top_abs = str(Path(top).resolve())
    same_common = bool(current_common and common_abs == current_common)
    is_current = top_abs == current_top
    classification = classify(is_current, same_common, status)
    return {
        "path": str(path),
        "name": path.name,
        "is_git": True,
        "git_toplevel": top_abs,
        "git_common_dir": common_abs,
        "shares_current_common_git_dir": same_common,
        "branch": branch,
        "head": head,
        "remote_origin": remote,
        "status": status,
        "classification": classification,
        "duplicate_risk": duplicate_risk(classification, status),
    }


def classify(is_current: bool, same_common: bool, status: dict[str, int]) -> str:
    if is_current:
        return "current_repo"
    if same_common:
        return "sibling_worktree_dirty" if status["dirty_total"] else "sibling_worktree_clean"
    if status["dirty_total"]:
        return "dirty_epistemos_copy"
    return "clean_epistemos_copy"


def duplicate_risk(classification: str, status: dict[str, int]) -> str:
    if classification == "current_repo":
        return "active_surface"
    if classification == "sibling_worktree_dirty":
        return "high_preserve_before_new_work"
    if classification == "dirty_epistemos_copy":
        return "high_manual_compare_before_new_work"
    if classification == "sibling_worktree_clean":
        return "medium_existing_branch_surface"
    if classification == "clean_epistemos_copy":
        return "medium_possible_stale_copy"
    if status.get("dirty_total", 0):
        return "high_unknown_dirty_surface"
    return "unknown"


def summarize(entries: list[dict[str, Any]]) -> dict[str, int]:
    total = len(entries)
    git_count = sum(1 for entry in entries if entry.get("is_git"))
    sibling_worktrees = sum(
        1 for entry in entries if str(entry.get("classification", "")).startswith("sibling_worktree")
    )
    dirty = sum(1 for entry in entries if entry.get("status", {}).get("dirty_total", 0) > 0)
    high_risk = sum(
        1 for entry in entries if str(entry.get("duplicate_risk", "")).startswith("high")
    )
    non_git = total - git_count
    return {
        "candidate_count": total,
        "git_candidate_count": git_count,
        "non_git_candidate_count": non_git,
        "sibling_worktree_count": sibling_worktrees,
        "dirty_candidate_count": dirty,
        "high_duplicate_risk_count": high_risk,
    }


def git_status_counts(path: Path) -> dict[str, int]:
    out = git_text(path, ["status", "--porcelain=v1", "-uno"])
    tracked_dirty = len(out.splitlines()) if out else 0
    untracked_out = git_text(path, ["status", "--porcelain=v1", "--untracked-files=all"])
    untracked = 0
    total = 0
    if untracked_out:
        for line in untracked_out.splitlines():
            total += 1
            if line.startswith("??"):
                untracked += 1
    return {
        "tracked_dirty": tracked_dirty,
        "untracked": untracked,
        "dirty_total": total,
    }


def git_text(path: Path, args: list[str]) -> str | None:
    result = subprocess.run(
        ["git", "-C", str(path), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode != 0:
        return None
    text = result.stdout.strip()
    return text or None


def normalize_git_path(repo_path: Path, value: str) -> str:
    path = Path(value)
    if not path.is_absolute():
        path = repo_path / path
    return str(path.resolve())


if __name__ == "__main__":
    raise SystemExit(main())
