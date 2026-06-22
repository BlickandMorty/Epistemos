# Runtime screenshot artifact — build agent instructions

> **Status:** `osa_runtime_2026_06_22.png` is NOT in the repo (binary PNGs are captured at runtime, not committed
> until the build agent produces one). Ground-truth reference path:
> `docs/research/osa_runtime_2026_06_22.png`

## Build agent — first run MUST capture

On the **first iteration** (or whenever the PNG is missing):

1. **Build:** `xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify`
2. **Launch:** `open /path/to/Epistemos.app` (DerivedData build product)
3. **Capture act surface:**
   ```bash
   screencapture -x docs/research/osa_runtime_2026_06_22.png
   # Or window-specific:
   screencapture -x -o -l$(osascript -e 'tell app "System Events" to id of window 1 of process "Epistemos"') /tmp/epi_act_baseline.png
   ```
4. **Read the PNG** with the agent's Read tool — confirm D1–D5 state against strict prompt D-section.
5. **Commit** the PNG only if owner policy allows runtime artifacts in repo; otherwise keep at `/tmp/` and
   reference path in STRICT_RECERT_LOG. (Current policy: capture to `docs/research/osa_runtime_2026_06_22.png`
   when re-certifying D-defects.)

## If app is already running

```bash
screencapture -x docs/research/osa_runtime_2026_06_22.png
```

Then `Read` the file. Re-capture after every act-surface fix and note delta in STRICT_RECERT_LOG.

## Per-surface captures (mandatory for 0.2 / 0.5)

| Surface | Suggested path |
|---------|----------------|
| Main act | `/tmp/epi_act_main.png` |
| Mini chat | `/tmp/epi_act_mini.png` |
| Graph chat | `/tmp/epi_act_graph.png` |
| Note chat | `/tmp/epi_act_note.png` |
| Landing (pre-blur) | `/tmp/epi_landing.png` |
| Settings (D4) | `/tmp/epi_settings.png` |

One main-act PNG does **not** satisfy multi-surface queue items.

## Send-text harness (paired with screencapture)

Every iteration also runs the headless send-text harness (queue 0.23) — screencapture proves UI; harness
proves inference. Both must pass before `[x]` on send-related items.
