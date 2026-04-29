#!/usr/bin/env python3
"""
validate.py — CI gate for the V1 atlas pipeline.

Checks per IMPLEMENTATION §S10 acceptance:
  - Every preset atlas exists (5 head shapes).
  - Every atlas has all 14 §5.3 animation states.
  - Every atlas has a paired UV manifest.
  - Every atlas has a paired provenance manifest.
  - Atlas dimensions match `atlas_size` declared in manifest.
  - Total texture memory ≤ 50 MB (§12).
  - Provenance declares license + origin + author + (if any) AI
    model used.
  - No verbatim copying claim (provenance.allowed_inspirations
    list is non-empty; provenance.forbidden_inspirations list is
    non-empty — i.e. the human author thought about boundaries).

Returns exit code 0 on success, 1 on any check failure.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path

from _png import read_rgba_png


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
ATLAS_DIR = REPO_ROOT / "Epistemos" / "Resources" / "CompanionAssets" / "atlas"

REQUIRED_HEADS = {"block_compact", "block_wide", "orb", "sage", "hermes_snake"}
REQUIRED_STATES = {
    "idle", "walk", "think", "speak", "tool", "spawn",
    "handoff_give", "handoff_receive", "retrieve", "error",
    "recover", "success", "sleep", "gate",
}
TEXTURE_MEMORY_CAP_BYTES = 50 * 1024 * 1024  # §12


@dataclass
class Check:
    name: str
    ok: bool
    detail: str


def validate() -> list[Check]:
    checks: list[Check] = []

    if not ATLAS_DIR.exists():
        return [Check("atlas_dir_exists", False, f"{ATLAS_DIR} missing")]

    found_pngs = {p.stem for p in ATLAS_DIR.glob("*.png")}
    missing = REQUIRED_HEADS - found_pngs
    extra = found_pngs - REQUIRED_HEADS
    checks.append(Check(
        "all_required_atlases_present",
        not missing,
        f"missing={sorted(missing)}, extra={sorted(extra)}"
    ))

    total_bytes = 0
    for slug in REQUIRED_HEADS:
        png_path = ATLAS_DIR / f"{slug}.png"
        json_path = ATLAS_DIR / f"{slug}.json"
        prov_path = ATLAS_DIR / f"{slug}.provenance.json"

        # Manifest exists.
        checks.append(Check(
            f"manifest_exists::{slug}",
            json_path.is_file(),
            str(json_path),
        ))
        checks.append(Check(
            f"provenance_exists::{slug}",
            prov_path.is_file(),
            str(prov_path),
        ))

        if not (png_path.is_file() and json_path.is_file()):
            continue

        manifest = json.loads(json_path.read_text())

        # All 14 states.
        states = set(manifest.get("states", {}).keys())
        miss = REQUIRED_STATES - states
        checks.append(Check(
            f"all_14_states::{slug}",
            not miss,
            f"missing={sorted(miss)}",
        ))

        # Atlas dimensions match the PNG.
        try:
            png_w, png_h, _pixels = read_rgba_png(png_path)
        except Exception as e:
            checks.append(Check(
                f"png_readable::{slug}",
                False,
                f"{e}",
            ))
            continue
        man_w, man_h = manifest.get("atlas_size", [0, 0])
        checks.append(Check(
            f"atlas_dims_match::{slug}",
            (png_w, png_h) == (man_w, man_h),
            f"png={png_w}x{png_h}, manifest={man_w}x{man_h}",
        ))

        # Frame count per state matches §5.3 table.
        from procedural_atlas_v1 import FRAMES_PER_STATE
        for state, expected_frames in FRAMES_PER_STATE.items():
            actual = len(manifest["states"].get(state, {}).get("frames", []))
            checks.append(Check(
                f"frame_count::{slug}::{state}",
                actual == expected_frames,
                f"expected {expected_frames}, got {actual}",
            ))

        # Atlas memory contribution.
        total_bytes += png_w * png_h * 4

        # Provenance integrity.
        if prov_path.is_file():
            prov = json.loads(prov_path.read_text())
            for required_key in ("category", "origin", "license",
                                 "author", "allowed_inspirations",
                                 "forbidden_inspirations",
                                 "doctrine_refs"):
                present = required_key in prov
                checks.append(Check(
                    f"provenance::{slug}::{required_key}",
                    present,
                    "present" if present else f"missing key {required_key}",
                ))
            non_empty = (
                len(prov.get("allowed_inspirations", [])) > 0
                and len(prov.get("forbidden_inspirations", [])) > 0
            )
            checks.append(Check(
                f"provenance::{slug}::has_inspirations",
                non_empty,
                "both lists populated" if non_empty else "either list is empty",
            ))

    # Total memory.
    checks.append(Check(
        "texture_memory_within_cap",
        total_bytes <= TEXTURE_MEMORY_CAP_BYTES,
        f"{total_bytes:,} B (cap {TEXTURE_MEMORY_CAP_BYTES:,} B)",
    ))

    return checks


def main() -> int:
    checks = validate()
    failures = [c for c in checks if not c.ok]
    for c in checks:
        prefix = "  ✓" if c.ok else "  ✗"
        print(f"{prefix} {c.name}: {c.detail}")
    if failures:
        print(f"\n{len(failures)} check(s) failed.")
        return 1
    print(f"\nAll {len(checks)} checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
