---
state: living-doc
created_on: 2026-05-12
scope: User-facing diagnostic depth playbook — what to capture when, ranked fastest → deepest
---

# Diagnostic Playbook

## TL;DR — what to do when you see X

| Symptom | First move (under 1 min) | If still unclear (5 min) |
|---|---|---|
| App feels frozen | `sample <pid>` in Terminal | Instruments → Hangs |
| Graph laggy / low FPS | `sample <pid>` during the lag | Instruments → Animation Hitches |
| Memory ballooning | Activity Monitor → memory tab | Instruments → Allocations |
| Random crash | `~/Library/Logs/DiagnosticReports/` | Look for `.ips` files from today |
| Specific operation slow | Runtime log paste (current habit) | Instruments → Time Profiler |
| Network seems slow | Console.app filter on `URLSession` | Instruments → Network |

## Depth hierarchy

### Tier 0 — Runtime log paste (current habit)

What you've been doing. Pasting Console output from the running app.

**Strengths:** Free, instant, captures async os_log warnings.

**Limits:** Only surfaces what the app explicitly chose to log. Misses the actual stack frame where a hang happens.

### Tier 1 — `log stream` (Console.app or CLI)

Live os_log streaming. Same data as Tier 0 but as it happens.

```bash
log stream --predicate 'process == "Epistemos"' --info
```

**Use when:** you want to see logs in real time while reproducing a bug.

### Tier 2 — Crash reports

Look in `~/Library/Logs/DiagnosticReports/`. Files named `Epistemos-*.ips` are crash reports with stack traces.

```bash
ls -lt ~/Library/Logs/DiagnosticReports/ | grep Epistemos | head -5
```

**Use when:** app actually crashed.

### Tier 3 — `sample <pid>` (Terminal, no Xcode)

The fastest deep-diagnostic tool. Snapshots stacks of every thread in the process over 5 seconds and prints a hierarchy.

```bash
# Find PID:
pgrep -f Epistemos

# Sample for 5 seconds:
sample $(pgrep -f Epistemos | head -1) 5

# Sample for 10 seconds with finer granularity:
sample $(pgrep -f Epistemos | head -1) 10 -mayDie
```

**Strengths:** No tools to install, no Xcode launch, output is text you can paste directly.

**Output shape:** call tree by time spent. Bigger numbers at the top = hotter code.

**Use when:** Anything CPU- or hang-related. This is the single most useful command.

### Tier 4 — `spindump`

System-wide stuck-process scan. Less focused than `sample` but catches deadlocks across processes.

```bash
sudo spindump 5
```

**Use when:** suspecting cross-process deadlocks (XPC, etc.).

### Tier 5 — Instruments → Hangs

The trace you just sent. Catches every main-thread stall over the threshold (default 250ms; 33ms in your last trace).

**To run:**
1. `xcrun open -a Instruments` or `⌘Space → Instruments`
2. Pick "Hangs" template (under "Animation, UI Responsiveness")
3. Click record (red dot), reproduce the bug, click stop
4. Hangs track at top — wider bars = longer hangs
5. Click the longest bar — call tree appears in bottom pane

**Output:** stack trace exactly at moment of hang.

**Best for:** "Why does this freeze?"

### Tier 6 — Instruments → Time Profiler

CPU sampling across all threads. Pinpoints which function is burning cycles.

**Best for:** "Why is this slow?"

**Output:** call tree with self-time + total-time per function.

The trace you sent is actually a Time Profiler trace with Hangs instrument enabled — strict superset of Tier 5.

### Tier 7 — Instruments → Allocations

Tracks every memory allocation + their call-site stacks.

**Best for:** "Why is RAM growing? What's leaking?"

### Tier 8 — Instruments → System Trace

Kernel + GPU + thread state. Heavy but comprehensive.

**Best for:** "What's the actual cross-thread / cross-process dependency causing the lag?"

### Tier 9 — Instruments → Animation Hitches

Frame-by-frame animation timing. Shows exactly which frame drops below 60fps + why.

**Best for:** Graph FPS complaints, scrolling jank, transition smoothness.

### Tier 10 — Memory Graph Debugger (Xcode)

Live snapshot of every object in memory + retain cycle detection.

**To use:** With app running under Xcode debugger, click the Memory Graph button in the debug bar (between Pause and Continue).

**Best for:** Hunting retain cycles + verifying tear-down.

## Recommended routine

**Daily / casual:** Tier 0 (runtime log) — current habit.

**When the app feels slow:** Tier 3 (`sample <pid>`) — 5 seconds, paste the output.

**When you need definitive answers:** Tier 5/6 (Instruments Hangs / Time Profiler) — what you used today to pin the SHA-256 hotspot.

**For memory worries:** Tier 7 (Allocations).

**For graph FPS specifically:** Tier 9 (Animation Hitches).

## Bonus: built-in app diagnostics

The app already has several diagnostic surfaces:

- **Settings → General → Diagnostics** — Halo health row, APIKeys health, Cognitive DAG status, Force Idle Unload button
- **`Epistemos/Library/Application Support/Epistemos/runtime_diagnostics/`** — JSON snapshots of lifecycle events
- **`Epistemos/Library/Application Support/Epistemos/crash_reports/`** — app-side crash records (separate from system crash reports)

These are good for "what's the current state?" but less good for "why is it slow?".

## How the BLAKE3 fix was found

Walking through the workflow to make the playbook concrete:

1. **You captured an Instruments Hangs trace** (Tier 5/6)
2. **Saved it as `epi.trace` in iCloud Drive**
3. **Pasted the path here**
4. **The trace's call tree showed:**
   - 27.7% of CPU in `sha2::sha256::soft::compress`
   - Called from `agent_core::resources::service::checksum`
   - Called from `VaultResourceService::read` on every vault file read
5. **The hash was an opaque OCC version string** — easy swap to BLAKE3
6. **Result:** commit `90b8c0d33` swapped SHA-256 → BLAKE3, expected ~10× speedup

Without the Hangs trace, the hotspot would have been invisible. The runtime log only shows "Main thread hang detected: 538 ms" — it doesn't say WHICH function. Tier 5+ is how you find that.
