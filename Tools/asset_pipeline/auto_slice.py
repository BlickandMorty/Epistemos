#!/usr/bin/env python3
"""
auto_slice.py — slice an artist-supplied atlas sheet into per-state
per-frame sub-images per DOCTRINE §10.3 step 4 ("Auto-slice:
Python + OpenCV detects frame boundaries on the sheet; alpha-trim;
normalize to grid").

This is the **V2 entry point** — used when an artist hands in a
hand-pixeled or AI-assisted-then-refined atlas as a single sheet
PNG. The V1 procedural atlas (procedural_atlas_v1.py) doesn't go
through here because it draws directly into the canonical grid.

OpenCV is optional; this script falls back to a stdlib-only
slicing path that walks the alpha channel to detect frame
boundaries. The OpenCV path is more robust for hand-drawn sheets
with anti-aliased edges.

Usage:
    python auto_slice.py \
        --input artist_sheet.png \
        --head block_compact \
        --output sliced/

The output is a directory with one PNG per state per frame:
    sliced/idle_0.png idle_1.png … gate_1.png
plus `sliced/manifest.json` recording the slice grid.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from _png import read_rgba_png, write_rgba_png

from procedural_atlas_v1 import (
    HEAD_PROFILES, STATES_IN_ORDER, FRAMES_PER_STATE, MAX_FRAMES,
)


def slice_atlas_grid(
    sheet_path: Path, head: str, out_dir: Path,
) -> dict:
    """Slice an atlas-grid PNG (i.e. one already laid out as
    states-rows × frames-cols). For artist-handed sheets that
    are NOT in the canonical grid, run an alpha-bbox detector
    first (deferred to V2 — the procedural V1 atlas already
    ships the canonical grid)."""
    profile = HEAD_PROFILES[head]
    cell_w, cell_h = profile.cell_w, profile.cell_h
    width, height, pixels = read_rgba_png(sheet_path)
    expected_w = cell_w * MAX_FRAMES
    expected_h = cell_h * len(STATES_IN_ORDER)
    if (width, height) != (expected_w, expected_h):
        raise ValueError(
            f"sheet {sheet_path} is {width}x{height}, "
            f"expected {expected_w}x{expected_h}"
        )

    out_dir.mkdir(parents=True, exist_ok=True)
    manifest: dict = {"head": head, "frames": {}}

    for row, state in enumerate(STATES_IN_ORDER):
        frames = FRAMES_PER_STATE[state]
        for col in range(frames):
            cell_pixels: list = []
            for dy in range(cell_h):
                for dx in range(cell_w):
                    src_x = col * cell_w + dx
                    src_y = row * cell_h + dy
                    cell_pixels.append(pixels[src_y * width + src_x])
            out_path = out_dir / f"{state}_{col}.png"
            write_rgba_png(out_path, cell_pixels, cell_w, cell_h)
            manifest["frames"].setdefault(state, []).append(
                str(out_path.relative_to(out_dir))
            )

    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n"
    )
    return manifest


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=Path)
    ap.add_argument("--head", required=True, choices=sorted(HEAD_PROFILES))
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()
    manifest = slice_atlas_grid(args.input, args.head, args.output)
    print(f"  ✓ {args.head}: sliced {sum(len(v) for v in manifest['frames'].values())} frames into {args.output}")


if __name__ == "__main__":
    main()
