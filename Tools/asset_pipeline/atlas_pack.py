#!/usr/bin/env python3
"""
atlas_pack.py — pack an artist's per-frame PNGs (e.g. produced by
`auto_slice.py` then refined in Aseprite) BACK into a single
atlas-grid PNG + UV manifest, ready for Metal's MTLTextureLoader
to ingest as one slice of a `texture2d_array<float>`.

Per DOCTRINE §10.3 step 5 ("Atlas pack: texture array packing —
one 2D slice per head shape, animation states laid out in fixed
grid").

This is the **V2 round-trip** — the artist works on per-frame
PNGs in Aseprite, then atlas_pack.py rebuilds the canonical grid
sheet from them. The V1 procedural pipeline doesn't need this
script (procedural_atlas_v1.py builds the grid directly).
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from _png import read_rgba_png, write_rgba_png, PixelRGBA

from procedural_atlas_v1 import (
    HEAD_PROFILES, STATES_IN_ORDER, FRAMES_PER_STATE, MAX_FRAMES,
)


def pack_atlas(input_dir: Path, head: str, out_path: Path) -> dict:
    profile = HEAD_PROFILES[head]
    atlas_w = profile.cell_w * MAX_FRAMES
    atlas_h = profile.cell_h * len(STATES_IN_ORDER)
    pixels: list[PixelRGBA] = [(0, 0, 0, 0)] * (atlas_w * atlas_h)

    manifest_states: dict[str, dict] = {}
    for row, state in enumerate(STATES_IN_ORDER):
        frames = FRAMES_PER_STATE[state]
        manifest_states[state] = {
            "row": row,
            "frame_count": frames,
            "frame_size": [profile.cell_w, profile.cell_h],
            "frames": [],
        }
        for col in range(frames):
            cell_path = input_dir / f"{state}_{col}.png"
            if not cell_path.is_file():
                raise FileNotFoundError(
                    f"missing per-frame PNG: {cell_path}"
                )
            w, h, cell_pixels = read_rgba_png(cell_path)
            if (w, h) != (profile.cell_w, profile.cell_h):
                raise ValueError(
                    f"{cell_path} is {w}x{h}, expected "
                    f"{profile.cell_w}x{profile.cell_h}"
                )
            for dy in range(h):
                for dx in range(w):
                    src = cell_pixels[dy * w + dx]
                    pixels[(row * profile.cell_h + dy) * atlas_w
                           + col * profile.cell_w + dx] = src
            manifest_states[state]["frames"].append({
                "x": col * profile.cell_w,
                "y": row * profile.cell_h,
                "w": profile.cell_w,
                "h": profile.cell_h,
            })

    write_rgba_png(out_path, pixels, atlas_w, atlas_h)
    manifest = {
        "head_shape": head,
        "atlas_size": [atlas_w, atlas_h],
        "cell_size": [profile.cell_w, profile.cell_h],
        "max_frames": MAX_FRAMES,
        "states": manifest_states,
        "channels": {"r": "eye", "g": "accent", "b": "body", "a": "alpha"},
        "doctrine_refs": ["§5.3", "§10.3", "§10.5"],
    }
    out_path.with_suffix(".json").write_text(
        json.dumps(manifest, indent=2) + "\n"
    )
    return manifest


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=Path,
                    help="directory of per-frame <state>_<col>.png files")
    ap.add_argument("--head", required=True, choices=sorted(HEAD_PROFILES))
    ap.add_argument("--output", required=True, type=Path,
                    help="atlas PNG output path")
    args = ap.parse_args()
    manifest = pack_atlas(args.input, args.head, args.output)
    print(f"  ✓ packed {args.head} → {args.output} ({manifest['atlas_size'][0]}x{manifest['atlas_size'][1]})")


if __name__ == "__main__":
    main()
