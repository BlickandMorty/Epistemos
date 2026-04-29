"""
_png.py — minimal stdlib-only RGBA PNG writer.

Mirrors the writer used by Tools/build_halo_textures.py. We avoid
Pillow so the asset pipeline runs on a fresh CI worker without an
extra package. The resulting files are ordinary PNGs that any
viewer + Metal's MTKTextureLoader can ingest.

DOCTRINE refs: I-16 (no smoothing — we write raw 8-bit RGBA, the
PNG itself never smooths anything; the renderer's nearest sampler
is what enforces I-16 at draw time).
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path
from typing import Iterable, Sequence


PixelRGBA = tuple[int, int, int, int]


def _png_chunk(name: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(name + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + name + data + struct.pack(">I", crc)


def write_rgba_png(
    path: Path,
    pixels: Sequence[PixelRGBA],
    width: int,
    height: int,
) -> None:
    """Write an 8-bit RGBA PNG to *path*. *pixels* is row-major
    (top-to-bottom, left-to-right)."""
    if len(pixels) != width * height:
        raise ValueError(
            f"pixel count {len(pixels)} doesn't match {width}*{height}={width*height}"
        )
    ihdr = struct.pack(
        ">IIBBBBB",
        width,
        height,
        8,    # bit depth
        6,    # color type 6 = RGBA
        0,    # compression
        0,    # filter
        0,    # interlace
    )
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter byte 0 = None
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

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(out))


def read_rgba_png(path: Path) -> tuple[int, int, list[PixelRGBA]]:
    """Read an 8-bit RGBA PNG. Returns (width, height, pixels).
    Used by validate.py for grid-region reachability checks.
    Supports only the subset write_rgba_png produces (no
    interlace, no palette, no 16-bit depth)."""
    data = path.read_bytes()
    if data[0:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG")
    pos = 8
    width = height = 0
    raw_idat = bytearray()
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos+4])[0]
        ctype = data[pos+4:pos+8]
        chunk = data[pos+8:pos+8+length]
        pos += 8 + length + 4  # skip CRC
        if ctype == b"IHDR":
            width, height, depth, color, compr, filt, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
            if depth != 8 or color != 6:
                raise ValueError(f"{path}: only 8-bit RGBA supported")
            if interlace != 0:
                raise ValueError(f"{path}: interlace not supported")
        elif ctype == b"IDAT":
            raw_idat += chunk
        elif ctype == b"IEND":
            break
    raw = zlib.decompress(bytes(raw_idat))
    pixels: list[PixelRGBA] = []
    stride = width * 4
    for y in range(height):
        line_start = y * (stride + 1)
        if raw[line_start] != 0:
            raise ValueError(
                f"{path}: only filter type 0 supported (got {raw[line_start]})"
            )
        for x in range(width):
            i = line_start + 1 + x * 4
            pixels.append((raw[i], raw[i+1], raw[i+2], raw[i+3]))
    return width, height, pixels
