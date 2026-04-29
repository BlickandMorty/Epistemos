#!/usr/bin/env python3
"""
build_halo_textures.py — bake placeholder halo / eye-bloom PNGs
for Simulation Mode S4.

Per DOCTRINE I-16 + §5.7 the halo is a SEPARATE additive-blend
quad with PRE-BAKED soft-edge texture. Softness lives in the
TEXTURE, never in a runtime blur. The falloff is STEPPED (not
smooth) so the bit-perfect contract holds.

S4 ships these as placeholders (procedurally generated radial
gradients). S10 replaces them with hand-pixeled assets in
Aseprite by the design pipeline (DOCTRINE §10.3).

Output:
    Resources/CompanionAssets/effects/halo_active.png       (64×64 RGBA)
    Resources/CompanionAssets/effects/eye_glow.png          (16×16 RGBA)
    Resources/CompanionAssets/effects/provenance.json
"""

from __future__ import annotations

import json
import math
import struct
import zlib
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parent.parent
EFFECTS_DIR = REPO_ROOT / "Epistemos" / "Resources" / "CompanionAssets" / "effects"


def _png_chunk(name: bytes, data: bytes) -> bytes:
    """Compose one PNG chunk: length(4) + name(4) + data + CRC32(4)."""
    crc = zlib.crc32(name + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + name + data + struct.pack(">I", crc)


def write_png(path: Path, pixels: list[tuple[int, int, int, int]], width: int, height: int) -> None:
    """Write an 8-bit RGBA PNG to *path* using stdlib (struct + zlib)."""
    assert len(pixels) == width * height
    # IHDR
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    # Raw scanlines: filter byte 0 (None) per row + rgba bytes.
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter byte
        for x in range(width):
            r, g, b, a = pixels[y * width + x]
            raw.append(r & 0xFF)
            raw.append(g & 0xFF)
            raw.append(b & 0xFF)
            raw.append(a & 0xFF)
    idat = zlib.compress(bytes(raw), 9)
    out = bytearray()
    out += b"\x89PNG\r\n\x1a\n"
    out += _png_chunk(b"IHDR", ihdr)
    out += _png_chunk(b"IDAT", idat)
    out += _png_chunk(b"IEND", b"")
    path.write_bytes(bytes(out))


def stepped_radial(
    width: int,
    height: int,
    steps: int,
    color: tuple[int, int, int],
) -> list[tuple[int, int, int, int]]:
    """Generate a STEPPED radial-gradient pixel array per I-16.

    `color` is the RGB tint to apply at full intensity. Alpha
    decreases in `steps` discrete bands from centre to edge — the
    softness lives in the texture, not in any sampler.
    """
    pixels: list[tuple[int, int, int, int]] = []
    cx = (width - 1) / 2.0
    cy = (height - 1) / 2.0
    max_dist = math.hypot(cx, cy)
    for y in range(height):
        for x in range(width):
            d = math.hypot(x - cx, y - cy) / max_dist
            # 1.0 at centre → 0.0 at edge.
            intensity = max(0.0, 1.0 - d)
            # Quantise to `steps` discrete bands.
            band = math.floor(intensity * steps) / steps
            alpha = int(round(band * 255))
            pixels.append((color[0], color[1], color[2], alpha))
    return pixels


def main() -> None:
    EFFECTS_DIR.mkdir(parents=True, exist_ok=True)

    # halo_active.png — 64×64, warm-white, 6-step falloff. The
    # body's tint multiplies in the fragment shader so the halo
    # picks up each companion's palette.
    halo = stepped_radial(64, 64, steps=6, color=(255, 248, 235))
    write_png(EFFECTS_DIR / "halo_active.png", halo, 64, 64)

    # eye_glow.png — 16×16, sharper falloff (4 steps), brighter
    # centre. Drawn over the eye region of the body sprite.
    eye = stepped_radial(16, 16, steps=4, color=(255, 255, 255))
    write_png(EFFECTS_DIR / "eye_glow.png", eye, 16, 16)

    provenance = {
        "category": "raster-effect-texture",
        "origin": "epistemos-original",
        "license": "CC0-1.0 (Epistemos placeholder; S10 replaces with hand-pixeled assets)",
        "generator": "Tools/build_halo_textures.py",
        "doctrine_refs": ["I-16", "§5.7", "§10.4"],
        "files": {
            "halo_active.png": {
                "size": "64x64",
                "format": "RGBA8",
                "falloff_steps": 6,
                "purpose": "additive-blend active-state aura",
            },
            "eye_glow.png": {
                "size": "16x16",
                "format": "RGBA8",
                "falloff_steps": 4,
                "purpose": "additive-blend eye highlight bloom",
            },
        },
    }
    (EFFECTS_DIR / "provenance.json").write_text(
        json.dumps(provenance, indent=2) + "\n"
    )

    print(f"wrote {EFFECTS_DIR}/halo_active.png    (64×64 RGBA, 6-step radial)")
    print(f"wrote {EFFECTS_DIR}/eye_glow.png       (16×16 RGBA, 4-step radial)")
    print(f"wrote {EFFECTS_DIR}/provenance.json")


if __name__ == "__main__":
    main()
