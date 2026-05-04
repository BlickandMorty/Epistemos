# R15 Live MLX Memory Preflight — 2026-05-03

> **Purpose.** Capture the host machine state needed to decide whether the
> R15 live MLX tok/s harness (PR8 closure) is safe to run, or whether it
> stays blocked. Read-only: no benchmarks were executed. Generated per
> `CODEX_PARALLEL_WORK_RATIONALE_PROMPT_2026_05_03.md` P5.
>
> Doctrine §7 lane: Core open — R15 remaining specialized baselines.

---

## 1. Capture timestamp

```
2026-05-03T15:25:10Z (UTC)
```

## 2. Host machine

```
ProductName:    macOS
ProductVersion: 26.3.1
BuildVersion:   25D2128

hw.model:       Mac14,9        (Apple Silicon — Mac mini / MacBook Pro generation)
hw.memsize:     17,179,869,184 bytes  =  16 GiB unified memory
```

## 3. Memory snapshot (vm_stat)

Page size: **16 KiB** (Apple Silicon)

| Class | Pages | Bytes (≈) |
|---|---|---|
| Free | 5,684 | 93 MiB |
| Active | 196,418 | 3.07 GiB |
| Inactive | 189,982 | 2.97 GiB |
| Speculative | 5,086 | 83 MiB |
| Throttled | 0 | 0 |
| Wired down | 183,929 | 2.87 GiB |
| Purgeable | 5 | 80 KiB |

**Reclaimable headroom (Free + Inactive + Speculative + Purgeable):** ≈ **3.15 GiB**

(Active is in-use; Wired is kernel/system; only the four reclaimable classes can be freed under pressure.)

## 4. Disk

```
Filesystem      Size    Used   Avail   Capacity
/dev/disk3s3s1  926Gi   12Gi   188Gi   6%
```

188 GiB free on /. Plenty of headroom for MLX weight loading (typical 7B-4bit ≈ 4 GiB on disk, KV cache writes negligible).

## 5. Power

```
Drawing from:  AC Power
Battery:       100%, charged, present
```

On AC, fully charged — thermal headroom is the only physical concern, not battery.

---

## 6. Verdict — should the R15 live MLX harness run today?

**Verdict: BLOCKED — defer until headroom recovers OR run with strict ceiling.**

### Reasoning

1. **Per the user's hardware memory ([user_hardware.md](/Users/jojo/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/user_hardware.md)):**
   > "16 GB unified memory ceiling; realistic budget ~10–11 GB for weights+KV; 4-bit 7-8B is the sweet spot."
2. **Current free + reclaimable is only ≈ 3.15 GiB** (93 MiB free + 3 GiB inactive). Loading even a 4-bit 7B (~4 GiB resident weights + 1–2 GiB KV under streaming) would force aggressive swapping and / or trigger memory-pressure cascades into other Epistemos services.
3. **The `MLXInferenceService` memory-pressure handlers ([CLAUDE.md](/Users/jojo/Downloads/Epistemos/CLAUDE.md))** already drop `persistentSSMSession` on `.warning` and unload the model container on `.critical`. Running the harness while the system is at ≈ 3 GiB reclaimable would likely fire these handlers mid-bench, contaminating the tok/s number.
4. **The R15 PR8 brief ([UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md](/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md) item 1)** already records "PR8 has an opt-in live MLX tok/s harness and a documented blocked sentinel run." This preflight confirms the blocked sentinel still applies.

### Conditions under which the harness becomes safe

The harness can run when **all** of the following hold:

- vm_stat reports ≥ **8 GiB** in `Free + Inactive + Speculative + Purgeable` before the run.
- The user's other heavy apps (Chrome, Xcode, Cursor, Slack, etc.) are quit or paused.
- The Mac is on AC power AND has been idle for ≥ 60 s (so thermal state is at baseline).
- The benchmark uses a 4-bit 7–8B model (per the user's stated sweet spot), not a Q4 13B or Q8 7B.
- The harness writes a single tok/s line per token batch — it must NOT spool a per-token log to memory or disk during the run, or the I/O will skew the number.

### Re-run cadence

Re-capture this preflight **before each attempted live run**. The reclaimable headroom number decays fast as the user opens IDEs and chat apps; a snapshot from yesterday is not authoritative.

A short helper script that prints the four critical numbers (free, inactive, available disk, AC power state) would let the user one-line the preflight without re-reading this doc each time. Suggested location: `scripts/r15-mlx-preflight.sh`. Out of scope for this artifact.

---

## 7. Reservation respect

This artifact creates **one new file** in a previously-empty directory and **edits no code or canonical state docs**. It is disjoint from Codex's round-73 reservation set:

- Did not touch: `Phase7Bridge.swift`, `Phase5Bridge.swift`, the GraphEvent guard tests, `UNIFIED_SUBSTRATE_CURRENT_STATE_*`, `AGENT_BUILD_WORKCARDS_*`, `REGISTRY.md`, any current deliberation/oversight/fleet folder.
- No benchmark was run.
