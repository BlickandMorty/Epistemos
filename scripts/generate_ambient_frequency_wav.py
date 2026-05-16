#!/usr/bin/env python3
"""Generate mathematically synthesized ambient-frequency WAV files.

Default output is the 30-minute Schumann Cocktail requested for Epistemos:
7.83 Hz amplitude modulation on a 100 Hz carrier, continuous 528 Hz and
432 Hz tones, breath-shaped white noise, intermittent 17 kHz pings, and an
exact 10-second 2500 Hz complex chirp.
"""

from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path

import numpy as np


SAMPLE_RATE = 44_100
CHANNELS = 2
BITS_PER_SAMPLE = 32
TARGET_PEAK = 0.92
TAU = 2.0 * math.pi


def breath_envelope(t: np.ndarray) -> np.ndarray:
    raw = (
        0.56
        + 0.28 * np.sin(TAU * 0.045 * t)
        + 0.18 * np.sin(TAU * 0.017 * t + 1.31)
        + 0.10 * np.sin(TAU * 0.009 * t + 2.17)
    )
    return np.clip(raw, 0.0, 1.0) ** 2


def hann(progress: np.ndarray) -> np.ndarray:
    return 0.5 - 0.5 * np.cos(TAU * np.clip(progress, 0.0, 1.0))


def ping_schedule(duration_seconds: float) -> np.ndarray:
    rng = np.random.default_rng(0x17000BEEF1237781)
    starts = []
    index = 0
    while True:
        start = 7.0 + index * 23.0 + rng.uniform(-6.0, 6.0)
        if start >= duration_seconds:
            break
        if start >= 0:
            starts.append(start)
        index += 1
    return np.array(starts, dtype=np.float64)


def add_windowed_tone(
    left: np.ndarray,
    right: np.ndarray,
    t: np.ndarray,
    start: float,
    duration: float,
    frequency_hz: float,
    amplitude: float,
) -> None:
    local = t - start
    mask = (local >= 0.0) & (local < duration)
    if not np.any(mask):
        return
    local_active = local[mask]
    tone = amplitude * hann(local_active / duration) * np.sin(TAU * frequency_hz * local_active)
    left[mask] += tone
    right[mask] += tone


def add_chirp(
    left: np.ndarray,
    right: np.ndarray,
    t: np.ndarray,
    start: float,
    duration: float = 0.22,
    center_hz: float = 2_500.0,
    sweep_hz: float = 700.0,
    amplitude: float = 0.035,
    harmonic_blend: float = 0.18,
) -> None:
    local = t - start
    mask = (local >= 0.0) & (local < duration)
    if not np.any(mask):
        return
    local_active = local[mask]
    f0 = center_hz - sweep_hz / 2.0
    f1 = center_hz + sweep_hz / 2.0
    slope = (f1 - f0) / duration
    phase = TAU * (f0 * local_active + 0.5 * slope * local_active * local_active)
    primary = np.sin(phase)
    harmonic = np.sin(phase * 2.0)
    chirp = amplitude * hann(local_active / duration) * (
        (1.0 - harmonic_blend) * primary + harmonic_blend * harmonic
    )
    left[mask] += chirp
    right[mask] += chirp


def global_fade(frame_indices: np.ndarray, total_frames: int) -> np.ndarray:
    fade_frames = min(total_frames // 2, max(1, int(0.02 * SAMPLE_RATE)))
    envelope = np.ones(frame_indices.shape, dtype=np.float64)
    attack = frame_indices < fade_frames
    if np.any(attack):
        envelope[attack] = hann(frame_indices[attack] / fade_frames)
    remaining = total_frames - frame_indices - 1
    release = remaining < fade_frames
    if np.any(release):
        envelope[release] = hann(remaining[release] / fade_frames)
    return envelope


def synth_chunk(
    frame_start: int,
    frame_count: int,
    total_frames: int,
    ping_starts: np.ndarray,
    chirp_starts: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    frames = frame_start + np.arange(frame_count, dtype=np.float64)
    t = frames / SAMPLE_RATE
    left = np.zeros(frame_count, dtype=np.float64)
    right = np.zeros(frame_count, dtype=np.float64)

    modulation = 1.0 + 0.86 * np.sin(TAU * 7.83 * t)
    modulated_carrier = 0.16 * modulation * np.sin(TAU * 100.0 * t)
    tone_528 = 0.055 * np.sin(TAU * 528.0 * t)
    tone_432 = 0.09 * np.sin(TAU * 432.0 * t)
    base = modulated_carrier + tone_528 + tone_432
    left += base
    right += base

    rng = np.random.default_rng(0xA7F0432052800783 + frame_start)
    noise = rng.uniform(-1.0, 1.0, frame_count)
    breath = 0.045 * breath_envelope(t) * noise
    left += breath
    right += breath

    chunk_start_time = frame_start / SAMPLE_RATE
    chunk_end_time = (frame_start + frame_count) / SAMPLE_RATE
    for start in ping_starts[(ping_starts < chunk_end_time) & (ping_starts + 0.045 > chunk_start_time)]:
        add_windowed_tone(left, right, t, float(start), 0.045, 17_000.0, 0.018)

    for start in chirp_starts[(chirp_starts < chunk_end_time) & (chirp_starts + 0.22 > chunk_start_time)]:
        add_chirp(left, right, t, float(start))

    fade = global_fade(frame_start + np.arange(frame_count), total_frames)
    left *= fade
    right *= fade
    return left, right


def write_float_wav_header(file, total_frames: int) -> None:
    data_bytes = total_frames * CHANNELS * (BITS_PER_SAMPLE // 8)
    byte_rate = SAMPLE_RATE * CHANNELS * (BITS_PER_SAMPLE // 8)
    block_align = CHANNELS * (BITS_PER_SAMPLE // 8)
    file.write(b"RIFF")
    file.write(struct.pack("<I", 36 + data_bytes))
    file.write(b"WAVE")
    file.write(b"fmt ")
    file.write(struct.pack("<IHHIIHH", 16, 3, CHANNELS, SAMPLE_RATE, byte_rate, block_align, BITS_PER_SAMPLE))
    file.write(b"data")
    file.write(struct.pack("<I", data_bytes))


def render(output: Path, duration_minutes: float, chunk_frames: int) -> None:
    duration_seconds = duration_minutes * 60.0
    total_frames = int(round(duration_seconds * SAMPLE_RATE))
    ping_starts = ping_schedule(duration_seconds)
    chirp_starts = np.arange(0.0, duration_seconds, 10.0, dtype=np.float64)

    peak = 0.0
    for frame_start in range(0, total_frames, chunk_frames):
        count = min(chunk_frames, total_frames - frame_start)
        left, right = synth_chunk(frame_start, count, total_frames, ping_starts, chirp_starts)
        peak = max(peak, float(np.max(np.abs(left))), float(np.max(np.abs(right))))

    if peak <= 0.0:
        raise RuntimeError("generated silence")
    gain = TARGET_PEAK / peak

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as file:
        write_float_wav_header(file, total_frames)
        for frame_start in range(0, total_frames, chunk_frames):
            count = min(chunk_frames, total_frames - frame_start)
            left, right = synth_chunk(frame_start, count, total_frames, ping_starts, chirp_starts)
            interleaved = np.empty((count, CHANNELS), dtype="<f4")
            interleaved[:, 0] = left * gain
            interleaved[:, 1] = right * gain
            file.write(interleaved.tobytes())

    print(f"Wrote {output}")
    print(f"duration_seconds={total_frames / SAMPLE_RATE:.6f}")
    print(f"sample_rate={SAMPLE_RATE}")
    print(f"channels={CHANNELS}")
    print(f"format=32-bit IEEE float WAV")
    print(f"peak_before_normalization={peak:.9f}")
    print(f"target_peak={TARGET_PEAK:.2f}")
    print(f"chirp_count={len(chirp_starts)}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("artifacts/ambient-frequencies/schumann-cocktail-30min-44100-float32.wav"),
        help="Output WAV path.",
    )
    parser.add_argument("--duration-minutes", type=float, default=30.0)
    parser.add_argument("--chunk-frames", type=int, default=1_048_576)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not math.isfinite(args.duration_minutes) or args.duration_minutes <= 0:
        raise SystemExit("--duration-minutes must be positive and finite")
    if args.chunk_frames <= 0:
        raise SystemExit("--chunk-frames must be positive")
    render(args.output, args.duration_minutes, args.chunk_frames)


if __name__ == "__main__":
    main()
