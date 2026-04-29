#!/usr/bin/env python3
"""
procedural_atlas_v1.py — V1 legal-safe procedural atlas generator
for Simulation Mode S10.

Reads each Character DNA doc + draws original pixel-art for every
§5.3 14-state animation rig per head shape, emitting:

  Resources/CompanionAssets/atlas/<head>.png
  Resources/CompanionAssets/atlas/<head>.json          (UV manifest)
  Resources/CompanionAssets/atlas/<head>.provenance.json

The atlas is a 2D RGBA image with a fixed grid:

    Columns: max(frame_count) per row of state
    Rows: 14 — one per animation state in §5.3 order
    Cell: head-shape-specific (48×48 for Compact/Orb/Hermes;
          64×48 for Wide; 48×64 for Sage)

The atlas pixels carry the §10.5 palette mask:

    R channel — eye region
    G channel — accent region
    B channel — body region
    A channel — coverage

The fragment shader (`Companion.metal`) recolors at draw time
using the palette uniform indexed by `palette_id`.

Per DOCTRINE §10.1 the visual identity is conveyed via:
  - color palette family (provider-locked or Custom)
  - role behavior (animation personality from Character DNA)
  - prop category (overlay, separate atlas)

NEVER through verbatim mascot pixels. This generator draws
ORIGINAL pixel patterns that follow the silhouette direction
specified in each Character DNA doc — the silhouette parameters
(aspect, legs, antennae, eye_treatment) are doctrine-mandated;
the specific pixel pattern is the substantive human authorship
encoded here.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Sequence

from _png import PixelRGBA, write_rgba_png


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
ATLAS_DIR = REPO_ROOT / "Epistemos" / "Resources" / "CompanionAssets" / "atlas"


# §5.3 14-state animation rig — order is canonical and matches
# `agent_core::simulation::state::AnimationState::atlas_row`.
STATES_IN_ORDER = [
    "idle", "walk", "think", "speak", "tool", "spawn",
    "handoff_give", "handoff_receive", "retrieve", "error",
    "recover", "success", "sleep", "gate",
]

# Frames per state — matches AnimationState::frame_count.
FRAMES_PER_STATE = {
    "idle":            4,
    "walk":            8,
    "think":           6,
    "speak":           4,
    "tool":            6,
    "spawn":           5,
    "handoff_give":    8,
    "handoff_receive": 6,
    "retrieve":        6,
    "error":           4,
    "recover":         6,
    "success":         4,
    "sleep":           4,
    "gate":            2,
}


# RGBA mask channel sentinels — these are the *mask colors*, not
# the final rendered colors. The fragment shader (§10.5) recolors
# using the palette uniform.
TRANSPARENT: PixelRGBA = (0, 0, 0, 0)
BODY:        PixelRGBA = (0,   0, 255, 255)  # mask.b = 1 → palette.body
ACCENT:      PixelRGBA = (0, 255,   0, 255)  # mask.g = 1 → palette.accent
EYE:         PixelRGBA = (255, 0,   0, 255)  # mask.r = 1 → palette.eye
NEGATIVE:    PixelRGBA = (0,   0,   0,   0)  # eye negative-space cutout


@dataclass(frozen=True)
class HeadProfile:
    """One head shape's atlas layout. The frame_size is the cell
    dimensions; the atlas is laid out as 14 rows × max-frames
    cells. Variable-length states pad with transparent."""
    slug: str
    cell_w: int
    cell_h: int


HEAD_PROFILES = {
    "block_compact": HeadProfile("block_compact", 48, 48),
    "block_wide":    HeadProfile("block_wide",    64, 48),
    "orb":           HeadProfile("orb",           48, 48),
    "sage":          HeadProfile("sage",          48, 64),
    "hermes_snake":  HeadProfile("hermes_snake",  64, 48),
}

# Max frames in any state — drives atlas column count.
MAX_FRAMES = max(FRAMES_PER_STATE.values())  # 8


# =============================================================================
# Pixel buffer helpers
# =============================================================================

class CellBuffer:
    """A `cell_w × cell_h` RGBA pixel buffer. Drawn-into by the
    head-specific composer functions, then placed into the atlas."""

    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.px: list[PixelRGBA] = [TRANSPARENT] * (w * h)

    def set(self, x: int, y: int, color: PixelRGBA) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = color

    def fill_rect(self, x: int, y: int, w: int, h: int, color: PixelRGBA) -> None:
        for dy in range(h):
            for dx in range(w):
                self.set(x + dx, y + dy, color)

    def fill_rect_outline(
        self,
        x: int, y: int, w: int, h: int,
        body: PixelRGBA, edge: PixelRGBA | None = None,
    ) -> None:
        """Body fill with optional 1-pixel-darker edge outline."""
        for dy in range(h):
            for dx in range(w):
                is_edge = (
                    edge is not None
                    and (dx == 0 or dx == w - 1 or dy == 0 or dy == h - 1)
                )
                self.set(x + dx, y + dy, edge if is_edge else body)

    def draw_circle(
        self,
        cx: int, cy: int, radius: int, color: PixelRGBA,
    ) -> None:
        """Stepped pixel circle per I-16 (no AA edges). Filled."""
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                if dx * dx + dy * dy <= radius * radius:
                    self.set(cx + dx, cy + dy, color)

    def draw_ring(
        self,
        cx: int, cy: int, outer: int, inner: int, color: PixelRGBA,
    ) -> None:
        for dy in range(-outer, outer + 1):
            for dx in range(-outer, outer + 1):
                d2 = dx * dx + dy * dy
                if inner * inner < d2 <= outer * outer:
                    self.set(cx + dx, cy + dy, color)


# =============================================================================
# Block (Compact)
# =============================================================================

def draw_block_compact(state: str, frame: int) -> CellBuffer:
    """Compact Block (~48×48, 1:1). Two stub legs, flat top, filled
    eyes. Driven by docs/simulation-mode/character-dna/block_compact.md.
    """
    p = HEAD_PROFILES["block_compact"]
    cell = CellBuffer(p.cell_w, p.cell_h)

    # Idle baseline — body 36×34 anchored bottom-center, two stub
    # legs, eyes in upper third.
    sway = _idle_sway(state, frame, amplitude=1)
    body_x = 6 + sway
    body_y = 4
    cell.fill_rect_outline(body_x, body_y, 36, 34, BODY, ACCENT)

    # Inner accent stripe — vertical 1px column down the center.
    cell.fill_rect(body_x + 17, body_y + 2, 2, 30, ACCENT)

    # Eyes — two filled rectangles in the upper third.
    eye_y = body_y + 10
    cell.fill_rect(body_x + 8,  eye_y, 6, 4, EYE)
    cell.fill_rect(body_x + 22, eye_y, 6, 4, EYE)

    # Stub legs — two 6×6 stubs at the bottom edge.
    leg_y = body_y + 34
    cell.fill_rect_outline(body_x + 7,  leg_y, 6, 6, BODY, ACCENT)
    cell.fill_rect_outline(body_x + 23, leg_y, 6, 6, BODY, ACCENT)

    # State-specific decorations.
    _decorate_block(cell, state, frame, body_x, body_y, eye_y, leg_y, wide=False)

    return cell


# =============================================================================
# Block (Wide — Claude Code direction)
# =============================================================================

def draw_block_wide(state: str, frame: int) -> CellBuffer:
    """Wide Block (~64×48, 1.4:1). Multi-leg notches, single
    antenna, negative-space eye cutouts. Per
    docs/simulation-mode/character-dna/block_wide.md.
    """
    p = HEAD_PROFILES["block_wide"]
    cell = CellBuffer(p.cell_w, p.cell_h)

    sway = _idle_sway(state, frame, amplitude=1)
    body_x = 6 + sway
    body_y = 6
    body_w, body_h = 52, 34

    cell.fill_rect_outline(body_x, body_y, body_w, body_h, BODY, ACCENT)

    # Vertical accent stripe down the center (the "spine").
    cell.fill_rect(body_x + body_w // 2 - 1, body_y + 2, 2, body_h - 4, ACCENT)

    # Negative-space eye cutouts — punched-through alpha so the
    # theater backdrop shows through.
    eye_y = body_y + 10
    cell.fill_rect(body_x + 14, eye_y,     5, 4, NEGATIVE)
    cell.fill_rect(body_x + 33, eye_y,     5, 4, NEGATIVE)
    # Round the corner of each cutout (1 corner pixel per).
    cell.set(body_x + 14, eye_y,     BODY)
    cell.set(body_x + 18, eye_y,     BODY)
    cell.set(body_x + 14, eye_y + 3, BODY)
    cell.set(body_x + 18, eye_y + 3, BODY)
    cell.set(body_x + 33, eye_y,     BODY)
    cell.set(body_x + 37, eye_y,     BODY)
    cell.set(body_x + 33, eye_y + 3, BODY)
    cell.set(body_x + 37, eye_y + 3, BODY)

    # Multi-leg notches (4 legs ~6px wide each, evenly spaced).
    leg_y = body_y + body_h
    for i in range(4):
        lx = body_x + 4 + i * 12
        cell.fill_rect_outline(lx, leg_y, 6, 5, BODY, ACCENT)

    # Single antenna (top-right, ~4×6 with 1px cap).
    ant_x = body_x + body_w - 8
    ant_y = body_y - 6
    antenna_sway = _antenna_sway(state, frame)
    cell.fill_rect(ant_x + antenna_sway, ant_y, 4, 6, BODY)
    cell.set(ant_x + 1 + antenna_sway, ant_y - 1, ACCENT)  # cap

    _decorate_block(cell, state, frame, body_x, body_y, eye_y, leg_y, wide=True)

    return cell


# =============================================================================
# Block decorations (state-specific, shared by Compact + Wide)
# =============================================================================

def _decorate_block(
    cell: CellBuffer, state: str, frame: int,
    body_x: int, body_y: int, eye_y: int, leg_y: int,
    wide: bool,
) -> None:
    if state == "speak":
        # Eye-region brightness pulse — overlay accent dots.
        if frame % 2 == 0:
            cell.set(body_x + 11, eye_y + 1, ACCENT)
            cell.set(body_x + 25 + (12 if wide else 0), eye_y + 1, ACCENT)

    elif state == "think":
        # Head-tilt: top row of the body shifts 1px right.
        if frame >= 2:
            for x in range(36 + (16 if wide else 0)):
                cell.set(body_x + x + 1, body_y, ACCENT)

    elif state == "tool":
        # Prop articulation — render a wrench-tip accent pixel
        # rising from the right side.
        prop_y = body_y + 18 - frame
        cell.set(body_x + 36 + (16 if wide else 0), prop_y, ACCENT)
        cell.set(body_x + 37 + (16 if wide else 0), prop_y, ACCENT)

    elif state == "spawn":
        # Bottom-up materialisation — clip the upper rows for
        # early frames.
        clip_rows = (5 - frame) * 6
        for y in range(body_y, body_y + clip_rows):
            for x in range(body_x, body_x + (52 if wide else 36)):
                cell.set(x, y, TRANSPARENT)

    elif state == "handoff_give":
        # Outstretched arm — accent pixel chain extending right.
        if frame >= 2:
            arm_y = body_y + 20
            arm_len = 2 + (frame - 2)
            for i in range(arm_len):
                cell.set(
                    body_x + (52 if wide else 36) + i, arm_y, ACCENT
                )

    elif state == "handoff_receive":
        # Catch-and-bring-in — accent pixel chain pulling left.
        if frame < 5:
            arm_y = body_y + 20
            arm_len = 4 - frame
            for i in range(arm_len):
                cell.set(body_x - i - 1, arm_y, ACCENT)

    elif state == "retrieve":
        # Folder-consult: a small folder shape below the body.
        if frame >= 2:
            f_x = body_x + 14
            f_y = body_y + 30
            cell.fill_rect(f_x, f_y, 8, 4, ACCENT)

    elif state == "error":
        # Jagged shake — body offset already handled via _idle_sway
        # exception below. Add accent flicker pixels at corners.
        if frame % 2 == 0:
            cell.set(body_x, body_y, EYE)
            cell.set(body_x + (52 if wide else 36) - 1, body_y, EYE)

    elif state == "recover":
        # Slow breath — accent stripe brighten at the spine in
        # alternating frames.
        if frame % 3 == 0:
            cell.fill_rect(
                body_x + (26 if wide else 17),
                body_y + 4,
                2, 26,
                EYE,
            )

    elif state == "success":
        # Celebration bob — body offset handled via sway override;
        # add a 1-frame accent crown at the top.
        if frame == 0:
            for x in range(36 + (16 if wide else 0)):
                cell.set(body_x + x, body_y - 1, EYE)

    elif state == "sleep":
        # Slow body lower — Z-mark above the body.
        if frame == 0 or frame == 2:
            cell.set(body_x + (52 if wide else 36) - 4, body_y - 4, ACCENT)
            cell.set(body_x + (52 if wide else 36) - 3, body_y - 5, ACCENT)
            cell.set(body_x + (52 if wide else 36) - 2, body_y - 4, ACCENT)

    elif state == "gate":
        # Asking-permission pose — accent ring above the body.
        cell.set(body_x + (26 if wide else 18), body_y - 3, EYE)
        cell.set(body_x + (27 if wide else 19), body_y - 4, EYE)
        cell.set(body_x + (28 if wide else 20), body_y - 3, EYE)


def _idle_sway(state: str, frame: int, amplitude: int) -> int:
    if state in ("walk",):
        # Brisk gait — sway -1, 0, 1, 0 (cycle of 4 over 8 frames).
        return [-1, 0, 1, 0, -1, 0, 1, 0][frame] * amplitude
    if state == "error":
        return [-amplitude, amplitude, -amplitude, amplitude][frame]
    if state == "idle":
        return [0, amplitude, 0, -amplitude][frame % 4]
    return 0


def _antenna_sway(state: str, frame: int) -> int:
    """Wide Block antenna's per-frame sway (always 0 for Compact)."""
    if state == "think":
        return [0, 1, 0, -1, 0, 1][frame % 6]
    if state == "error":
        # 1.5× amplitude per DNA.
        return [-2, 2, -2, 2][frame]
    if state == "idle":
        return [0, 0, 1, 0][frame % 4]
    if state == "sleep":
        return [1, 1, 1, 1][frame % 4]
    return 0


# =============================================================================
# Orb
# =============================================================================

def draw_orb(state: str, frame: int) -> CellBuffer:
    """Orb (~48×48). Stepped pixel disc, drifts. Per
    docs/simulation-mode/character-dna/orb.md.
    """
    p = HEAD_PROFILES["orb"]
    cell = CellBuffer(p.cell_w, p.cell_h)

    cx, cy = 24, 24
    drift_y = _orb_drift_y(state, frame)
    cy += drift_y
    radius = 16

    # Spawn growth: radius scales by frame.
    if state == "spawn":
        radius = max(1, [1, 5, 9, 13, 16][frame])

    # Sleep contraction.
    if state == "sleep":
        radius = [16, 15, 16, 15][frame]

    # Body fill.
    cell.draw_circle(cx, cy, radius, BODY)

    # Accent rim — ring at outermost pixel.
    cell.draw_ring(cx, cy, radius, radius - 1, ACCENT)

    # Eye region — horizontal slot above center (Closed eye).
    eye_y = cy - 4
    eye_color = EYE if state in ("speak", "think", "retrieve") and frame % 2 == 0 else BODY
    cell.fill_rect(cx - 3, eye_y, 6, 1, eye_color)

    # State decorations.
    if state == "speak":
        # Ring pulse — outer accent ring 1-2 px out.
        cell.draw_ring(cx, cy, radius + 1 + frame, radius + frame, ACCENT)

    elif state == "think":
        # Inner-glow pulse — eye color core dot.
        if frame >= 2:
            cell.set(cx, cy - 1, EYE)
            cell.set(cx, cy, EYE)

    elif state == "tool":
        # Prop floats around the orb — 6 frames, prop on a small
        # arc.
        arc_steps = [(0, -8), (3, -7), (5, -3), (5, 3), (3, 7), (0, 8)]
        ox, oy = arc_steps[frame % len(arc_steps)]
        cell.fill_rect(cx + ox - 1, cy + oy - 1, 3, 3, ACCENT)

    elif state == "retrieve":
        # Inward gold ring contracting.
        ring_r = max(1, 6 - frame)
        cell.draw_ring(cx, cy, ring_r + 1, ring_r, EYE)

    elif state == "error":
        # Violent jitter handled via `drift_y`; add accent
        # flicker at perimeter.
        if frame % 2 == 0:
            cell.set(cx + radius, cy, EYE)
            cell.set(cx - radius, cy, EYE)

    elif state == "recover":
        # Slow re-stabilise — no extra decoration; drift returns
        # to center.
        pass

    elif state == "success":
        # Concentric ring — ring expands frame by frame.
        cell.draw_ring(cx, cy, radius + 2 + frame, radius + 1 + frame, EYE)

    elif state == "gate":
        # Bright eye, still pose.
        cell.fill_rect(cx - 3, eye_y, 6, 1, EYE)

    elif state == "handoff_give":
        # Slow lift — accent dot drifts up + right.
        prop_x = cx + 4 + frame
        prop_y = cy - 4 - frame // 2
        cell.fill_rect(prop_x - 1, prop_y - 1, 3, 3, ACCENT)

    elif state == "handoff_receive":
        # Catch — accent dot pulls into orb.
        prop_x = cx + 12 - frame * 2
        prop_y = cy
        cell.fill_rect(prop_x - 1, prop_y - 1, 3, 3, ACCENT)

    return cell


def _orb_drift_y(state: str, frame: int) -> int:
    if state == "idle":
        return [0, 1, 0, -1][frame % 4]
    if state == "walk":
        # Glide horizontally; zero vertical bob (no legs to bob).
        return 0
    if state == "error":
        return [-2, 2, -2, 2][frame]
    if state == "sleep":
        return [0, 1, 0, -1][frame % 4]
    return 0


# =============================================================================
# Sage
# =============================================================================

def draw_sage(state: str, frame: int) -> CellBuffer:
    """Sage (~48×64). Tall humanoid with discrete head/body/legs.
    Per docs/simulation-mode/character-dna/sage.md.
    """
    p = HEAD_PROFILES["sage"]
    cell = CellBuffer(p.cell_w, p.cell_h)

    # Head — 12×12 centered horizontally at the top.
    head_x = 18 + _sage_head_drift(state, frame)
    head_y = 4
    cell.fill_rect_outline(head_x, head_y, 12, 12, BODY, ACCENT)
    # Eyes.
    cell.fill_rect(head_x + 3, head_y + 5, 2, 2, EYE)
    cell.fill_rect(head_x + 7, head_y + 5, 2, 2, EYE)

    # Neck — 2px wide.
    cell.fill_rect(23, 16, 2, 2, BODY)

    # Body / robe — 36×36 centered.
    body_y = 18
    body_x = 6 + _sage_body_drift(state, frame)
    cell.fill_rect_outline(body_x, body_y, 36, 36, BODY, ACCENT)

    # Belt — horizontal accent stripe at the body's vertical
    # midpoint.
    belt_y = body_y + 18
    cell.fill_rect(body_x + 1, belt_y, 34, 1, ACCENT)

    # Legs — two 5×10 legs at the bottom.
    leg_y = body_y + 36
    cell.fill_rect_outline(body_x + 11, leg_y, 5, 10, BODY, ACCENT)
    cell.fill_rect_outline(body_x + 20, leg_y, 5, 10, BODY, ACCENT)

    # State-specific arms & decorations.
    _decorate_sage(cell, state, frame, body_x, body_y, head_x, head_y)

    return cell


def _sage_head_drift(state: str, frame: int) -> int:
    if state == "idle":
        return [0, 0, 1, 0][frame % 4]
    if state == "think":
        return [0, 1, 1, 0, -1, 0][frame % 6]
    if state == "error":
        # Head wobbles independently.
        return [-1, 2, -1, 2][frame]
    if state == "sleep":
        return [0, 1, 1, 0][frame % 4]
    return 0


def _sage_body_drift(state: str, frame: int) -> int:
    if state == "walk":
        return [0, 1, 0, -1, 0, 1, 0, -1][frame]
    if state == "error":
        return [-1, 1, -1, 1][frame]
    return 0


def _decorate_sage(
    cell: CellBuffer, state: str, frame: int,
    body_x: int, body_y: int, head_x: int, head_y: int,
) -> None:
    # Default arms — short hanging arms.
    arm_y = body_y + 4
    cell.fill_rect(body_x - 2, arm_y, 3, 16, BODY)
    cell.fill_rect(body_x + 35, arm_y, 3, 16, BODY)

    if state == "think":
        # Left arm rises — replace left arm with raised pose.
        cell.fill_rect(body_x - 2, arm_y, 3, 6, TRANSPARENT)
        cell.fill_rect(body_x + 6, head_y + 8, 4, 6, BODY)

    elif state == "tool":
        # Two-handed forward. Replace both arms with forward
        # extension.
        cell.fill_rect(body_x - 2, arm_y, 3, 16, TRANSPARENT)
        cell.fill_rect(body_x + 35, arm_y, 3, 16, TRANSPARENT)
        cell.fill_rect(body_x - 2, body_y + 12, 8, 4, BODY)
        cell.fill_rect(body_x + 30, body_y + 12, 8, 4, BODY)

    elif state == "handoff_give":
        # Full-arm extension.
        cell.fill_rect(body_x - 2, arm_y, 3, 16, TRANSPARENT)
        ext_x = body_x + 35 + frame
        cell.fill_rect(ext_x, body_y + 14, 6, 3, BODY)

    elif state == "handoff_receive":
        # Two-handed receipt.
        cell.fill_rect(body_x - 2, arm_y, 3, 16, TRANSPARENT)
        cell.fill_rect(body_x + 35, arm_y, 3, 16, TRANSPARENT)
        cell.fill_rect(body_x - 2, body_y + 12, 6, 3, BODY)
        cell.fill_rect(body_x + 32, body_y + 12, 6, 3, BODY)

    elif state == "speak":
        # Mouth pulse — accent pixel below eyes.
        if frame % 2 == 0:
            cell.fill_rect(head_x + 5, head_y + 9, 2, 1, ACCENT)

    elif state == "error":
        # Off-balance accent flicker on belt.
        if frame % 2 == 0:
            cell.fill_rect(body_x + 12, body_y + 18, 12, 1, EYE)

    elif state == "recover":
        # Belt brighten on alternate frames.
        if frame % 3 == 0:
            cell.fill_rect(body_x + 1, body_y + 18, 34, 1, EYE)

    elif state == "success":
        # Right arm rises — accent dot above the head.
        if frame >= 2:
            cell.fill_rect(body_x + 35, body_y + 4 - 4, 3, 4, BODY)
            cell.set(head_x + 13, head_y - 2, EYE)

    elif state == "gate":
        # Both hands forward, palms up.
        cell.fill_rect(body_x - 2, arm_y, 3, 16, TRANSPARENT)
        cell.fill_rect(body_x + 35, arm_y, 3, 16, TRANSPARENT)
        cell.fill_rect(body_x - 4, body_y + 10, 6, 3, BODY)
        cell.fill_rect(body_x + 34, body_y + 10, 6, 3, BODY)

    elif state == "spawn":
        # Foot-up materialisation — clip top rows.
        clip_height = (5 - frame) * 12
        for y in range(0, clip_height):
            for x in range(cell.w):
                cell.set(x, y, TRANSPARENT)

    elif state == "sleep":
        # Head-droop — Z mark.
        if frame == 0:
            cell.set(head_x + 14, head_y - 2, ACCENT)
            cell.set(head_x + 15, head_y - 3, ACCENT)
            cell.set(head_x + 16, head_y - 2, ACCENT)


# =============================================================================
# Hermes Snake
# =============================================================================

def draw_hermes_snake(state: str, frame: int) -> CellBuffer:
    """Hermes Snake (~64×48). Coiling caduceus, hovers. Per
    docs/simulation-mode/character-dna/hermes_snake.md.
    """
    p = HEAD_PROFILES["hermes_snake"]
    cell = CellBuffer(p.cell_w, p.cell_h)

    # Three stacked coils at the canvas center.
    cx, cy = 32, 24
    drift = _hermes_drift(state, frame)
    cy += drift

    # Spawn fades the spiral in.
    spawn_radius_factor = 1.0
    if state == "spawn":
        spawn_radius_factor = [0.2, 0.4, 0.6, 0.8, 1.0][frame]

    # Three stacked coils.
    for i, y_off in enumerate((-12, 0, 12)):
        radius = max(1, int(6 * spawn_radius_factor))
        r = cell  # alias
        # outer body
        r.draw_ring(cx, cy + y_off, radius, max(1, radius - 1), BODY)
        # inner accent (bronze stripe pattern)
        if i == 1:
            r.set(cx + radius - 1, cy + y_off, ACCENT)
            r.set(cx - radius + 1, cy + y_off, ACCENT)

    # Head — emerging from the top-right.
    head_offset = _hermes_head_offset(state, frame)
    head_x = cx + 8 + head_offset[0]
    head_y = cy - 18 + head_offset[1]
    cell.fill_rect_outline(head_x, head_y, 6, 6, BODY, ACCENT)

    # Slit eyes.
    cell.fill_rect(head_x + 1, head_y + 2, 1, 3, EYE)
    cell.fill_rect(head_x + 4, head_y + 2, 1, 3, EYE)

    # Tail — emerging from the bottom-left.
    tail_x = cx - 14
    tail_y = cy + 14
    cell.fill_rect(tail_x, tail_y, 4, 4, BODY)
    cell.set(tail_x + 1, tail_y + 1, ACCENT)

    # State decorations.
    if state == "tool":
        # Tail wraps around an imagined node — gold ring at tail.
        cell.draw_ring(tail_x + 2, tail_y + 2, 3, 2, EYE)

    elif state == "speak":
        # Head bob — already reflected in head_offset; pulse the
        # eyes brighter.
        cell.fill_rect(head_x + 1, head_y + 2, 1, 3, ACCENT)
        cell.fill_rect(head_x + 4, head_y + 2, 1, 3, ACCENT)

    elif state == "think":
        # Coil tighten — already in head/tail offsets.
        pass

    elif state == "retrieve":
        # Tail-coil ring contracts.
        r = max(1, 4 - frame)
        cell.draw_ring(tail_x + 2, tail_y + 2, r + 1, r, EYE)

    elif state == "error":
        # Coil breaks — replace center coil with disconnected dots.
        cell.fill_rect(cx - 6, cy, 12, 12, TRANSPARENT)
        # 4 disconnected dots.
        cell.fill_rect(cx - 6, cy, 2, 2, BODY)
        cell.fill_rect(cx + 4, cy, 2, 2, BODY)
        cell.fill_rect(cx, cy - 6, 2, 2, BODY)
        cell.fill_rect(cx, cy + 4, 2, 2, BODY)

    elif state == "recover":
        # Coil reforms slowly — already handled via base draw.
        pass

    elif state == "success":
        # Triumphant lift handled via drift; gold halo at head.
        cell.draw_ring(head_x + 3, head_y + 3, 4, 3, EYE)

    elif state == "sleep":
        # Coil contracts — accent ring at center.
        cell.draw_ring(cx, cy, 3, 2, ACCENT)

    elif state == "gate":
        # Defensive S-curve — head higher, accent ring at body.
        cell.draw_ring(cx, cy, 6, 5, EYE)

    elif state == "handoff_give":
        # Body uncoils right.
        ext = frame
        cell.fill_rect(cx + 8 + ext, cy - 1, 4, 2, BODY)

    elif state == "handoff_receive":
        # Re-coil tight.
        if frame < 4:
            cell.fill_rect(cx + 14 - frame * 2, cy, 2, 2, BODY)

    elif state == "spawn":
        # Already handled via spawn_radius_factor.
        pass

    return cell


def _hermes_drift(state: str, frame: int) -> int:
    if state == "idle":
        return [0, 1, 0, -1][frame % 4]
    if state == "walk":
        # Slither — head leads, tail follows; constant hover.
        return [0, 1, 1, 0, -1, -1, 0, 1][frame % 8]
    if state == "success":
        return [-2, -4, -4, -2][frame]
    if state == "sleep":
        return [0, 1, 1, 0][frame % 4]
    return 0


def _hermes_head_offset(state: str, frame: int) -> tuple[int, int]:
    if state == "speak":
        return [(0, 0), (0, -1), (0, 0), (0, 0)][frame]
    if state == "think":
        # Coil-tighten — head pulls in.
        return [(0, 0), (-1, 1), (-1, 1), (0, 0), (1, -1), (1, -1)][frame % 6]
    if state == "gate":
        return [(0, -2), (0, -2)][frame]
    return (0, 0)


# =============================================================================
# Atlas composition
# =============================================================================

DRAWERS: dict[str, Callable[[str, int], CellBuffer]] = {
    "block_compact": draw_block_compact,
    "block_wide":    draw_block_wide,
    "orb":           draw_orb,
    "sage":          draw_sage,
    "hermes_snake":  draw_hermes_snake,
}


def build_atlas(slug: str) -> tuple[list[PixelRGBA], int, int, dict]:
    profile = HEAD_PROFILES[slug]
    drawer = DRAWERS[slug]

    atlas_w = profile.cell_w * MAX_FRAMES
    atlas_h = profile.cell_h * len(STATES_IN_ORDER)
    pixels: list[PixelRGBA] = [TRANSPARENT] * (atlas_w * atlas_h)

    manifest_states: dict[str, dict] = {}

    for row, state in enumerate(STATES_IN_ORDER):
        frames = FRAMES_PER_STATE[state]
        # Record manifest entry — UV is in pixel coordinates;
        # consumers convert to [0,1] using atlas_w / atlas_h.
        manifest_states[state] = {
            "row": row,
            "frame_count": frames,
            "frame_size": [profile.cell_w, profile.cell_h],
            "frames": [
                {
                    "x": col * profile.cell_w,
                    "y": row * profile.cell_h,
                    "w": profile.cell_w,
                    "h": profile.cell_h,
                }
                for col in range(frames)
            ],
        }
        for col in range(frames):
            cell = drawer(state, col)
            _blit(pixels, atlas_w, cell, col * profile.cell_w, row * profile.cell_h)

    manifest = {
        "head_shape": slug,
        "atlas_size": [atlas_w, atlas_h],
        "cell_size": [profile.cell_w, profile.cell_h],
        "max_frames": MAX_FRAMES,
        "states": manifest_states,
        "channels": {
            "r": "eye",
            "g": "accent",
            "b": "body",
            "a": "alpha",
        },
        "doctrine_refs": ["§5.3", "§10.3", "§10.5"],
    }
    return pixels, atlas_w, atlas_h, manifest


def _blit(
    dst: list[PixelRGBA], dst_w: int,
    cell: CellBuffer, x: int, y: int,
) -> None:
    for dy in range(cell.h):
        for dx in range(cell.w):
            src = cell.px[dy * cell.w + dx]
            if src[3] == 0 and src != NEGATIVE:
                continue
            dst[(y + dy) * dst_w + (x + dx)] = src


def emit_atlas(slug: str) -> dict:
    pixels, atlas_w, atlas_h, manifest = build_atlas(slug)
    png_path = ATLAS_DIR / f"{slug}.png"
    json_path = ATLAS_DIR / f"{slug}.json"
    write_rgba_png(png_path, pixels, atlas_w, atlas_h)
    json_path.write_text(json.dumps(manifest, indent=2) + "\n")
    return {
        "slug": slug,
        "png": str(png_path.relative_to(REPO_ROOT)),
        "json": str(json_path.relative_to(REPO_ROOT)),
        "atlas_size": [atlas_w, atlas_h],
        "byte_count": atlas_w * atlas_h * 4,
    }


def main() -> None:
    summary = []
    for slug in HEAD_PROFILES:
        summary.append(emit_atlas(slug))
        print(f"  ✓ {slug}: {summary[-1]['atlas_size'][0]}x{summary[-1]['atlas_size'][1]} "
              f"({summary[-1]['byte_count']:,} B)")
    total_bytes = sum(s["byte_count"] for s in summary)
    cap_bytes = 50 * 1024 * 1024  # §12 budget
    print(f"\nTotal atlas memory: {total_bytes:,} B "
          f"({total_bytes / cap_bytes:.1%} of §12 50 MB cap)")


if __name__ == "__main__":
    main()
