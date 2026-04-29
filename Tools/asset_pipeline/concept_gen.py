#!/usr/bin/env python3
"""
concept_gen.py — V2 concept-art entry point.

Per DOCTRINE §10.3 step 1 ("Concept: Character DNA doc → AI
concept image (Midjourney v7 / Flux.2 / SDXL with pixel-art LoRA
+ ControlNet pose constraint)") this script is the canonical
hand-off between the human-authored Character DNA and the AI
concept stage of the V2 pipeline.

By itself this script does not call any AI provider — provider
keys are out of scope for the simulation worktree. Instead it
generates a structured **prompt brief** for the artist + a
**ControlNet pose-sheet template** that locks the 14 §5.3 states
into a grid for the chosen head shape.

The artist runs the prompt+template through their preferred
generator (Midjourney / Flux / SDXL with a pixel-art LoRA) and
hands the result to `auto_slice.py` for slicing, then to Aseprite
for refinement, then back to `atlas_pack.py` for packing.

Usage:
    python concept_gen.py \
        --head block_compact \
        --output concept_briefs/block_compact/
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from textwrap import dedent

from _png import write_rgba_png, PixelRGBA
from procedural_atlas_v1 import (
    HEAD_PROFILES, STATES_IN_ORDER, FRAMES_PER_STATE, MAX_FRAMES,
)

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DNA_DIR = REPO_ROOT / "docs" / "simulation-mode" / "character-dna"


def write_pose_template(head: str, out_path: Path) -> tuple[int, int]:
    """Write a ControlNet pose-sheet template — a black-on-white
    grid showing each (state, frame) cell. The artist feeds this
    into ControlNet alongside the prompt brief; the pose sheet
    locks the grid layout and the per-frame anchor positions."""
    profile = HEAD_PROFILES[head]
    cell_w, cell_h = profile.cell_w, profile.cell_h
    sheet_w = cell_w * MAX_FRAMES
    sheet_h = cell_h * len(STATES_IN_ORDER)

    BG: PixelRGBA = (255, 255, 255, 255)
    GRID: PixelRGBA = (0, 0, 0, 255)
    ANCHOR: PixelRGBA = (128, 128, 128, 255)

    pixels: list[PixelRGBA] = [BG] * (sheet_w * sheet_h)
    # Grid lines.
    for y in range(sheet_h):
        for x in range(sheet_w):
            on_col_grid = x % cell_w == 0
            on_row_grid = y % cell_h == 0
            if on_col_grid or on_row_grid:
                pixels[y * sheet_w + x] = GRID
    # Per-cell anchor dot at center to encode the pose-anchor
    # ControlNet wants.
    for row in range(len(STATES_IN_ORDER)):
        frames = FRAMES_PER_STATE[STATES_IN_ORDER[row]]
        for col in range(frames):
            cx = col * cell_w + cell_w // 2
            cy = row * cell_h + cell_h // 2
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    pixels[(cy + dy) * sheet_w + (cx + dx)] = ANCHOR

    write_rgba_png(out_path, pixels, sheet_w, sheet_h)
    return sheet_w, sheet_h


def build_brief(head: str) -> dict:
    profile = HEAD_PROFILES[head]
    dna = (DNA_DIR / f"{head}.md").read_text()
    return {
        "head_shape": head,
        "cell_size": [profile.cell_w, profile.cell_h],
        "max_frames": MAX_FRAMES,
        "states": {
            s: FRAMES_PER_STATE[s] for s in STATES_IN_ORDER
        },
        "character_dna_excerpt": dna,
        "prompt_template": dedent(f"""
            Pixel art {head} sprite sheet, 14 animation states laid
            out as 14 rows × 8 columns (where each row is one state
            and each column is one animation frame). Cell size is
            {profile.cell_w}×{profile.cell_h}. Use the supplied pose
            grid as ControlNet input — every cell's center must hold
            the silhouette anchor. Palette mask convention: R channel
            for eye region, G for accent, B for body, A for alpha.
            Stepped pixel-art ONLY — no anti-aliasing, no smoothing,
            no soft edges. Read the matching Character DNA doc at
            docs/simulation-mode/character-dna/{head}.md for personality
            direction. Forbidden inspirations are NON-NEGOTIABLE — see
            the same DNA doc for the explicit list.
        """).strip(),
        "next_steps": [
            "Feed prompt + pose_template.png to the generator.",
            "Receive a candidate sheet (RGBA PNG).",
            "Refine in Aseprite per `aseprite_refine.lua`.",
            "Run `auto_slice.py` to split into per-frame PNGs.",
            "Run `atlas_pack.py` to rebuild the grid (validates frame counts).",
            "Run `manifest_gen.py` to refresh provenance metadata "
            "(record artist + model used).",
            "Run `validate.py` to gate the V2 atlas before committing.",
        ],
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--head", required=True, choices=sorted(HEAD_PROFILES))
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    brief = build_brief(args.head)
    (args.output / "brief.json").write_text(json.dumps(brief, indent=2) + "\n")
    sheet_w, sheet_h = write_pose_template(args.head, args.output / "pose_template.png")
    print(f"  ✓ {args.head}: brief.json + pose_template.png ({sheet_w}x{sheet_h}) "
          f"in {args.output}")


if __name__ == "__main__":
    main()
