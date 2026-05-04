# Hardware Target And Windows Constraints

> **Index status**: DEFERRED-RESEARCH — Windows porting research; deferred (V1 = macOS-only per ambient_V1_DECISION.md).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/windows_research/`.



## Target Machine

- Dell XPS 16
- Intel Core Ultra 9 185H
- Hybrid CPU: P-cores + E-cores
- Intel NPU present
- NVIDIA RTX 4060 laptop GPU
- GPU power budget approximately 40-50W
- 64 GB RAM
- Windows 11

## Implications

### CPU

- Hybrid-core scheduling matters.
- Token generation can stutter if inference or decode threads bounce onto E-cores.
- Background indexing, graph rebuilds, and vault sync should use low-priority utility work, not contend with token generation.

### GPU

- The RTX 4060 is useful, but it is not a desktop-class always-full-power 4060.
- VRAM budgeting must be explicit.
- A "just load the biggest model that fits" strategy is wrong on this hardware.
- Small and medium local models should be treated as first-class residents.

### RAM

- 64 GB allows much larger CPU-backed models and broader caching strategies than the current MacBook target.
- That does not remove the need for low-copy boundaries.
- The right strategy is still to keep large bodies on disk and structured metadata in a queryable store.

### NPU

- The Intel NPU should be treated as a specialization target, not a default answer.
- It is promising for lightweight background inference.
- It should not be assumed to replace the GPU or the primary local chat runtime.

## Required Windows Parity

The Windows version should preserve these behaviors:

- native multi-window notes
- native mini chat windows
- native context menus and toolbars
- fast notes browsing and editing
- local-first chat and reasoning
- graph overlay / graph workspace
- compact direct architecture
- low visual latency during streaming

## Things The Research Must Refuse

- Tauri
- Electron
- browser-based editor shell
- webview-first UI
- replacing the native editor with a JS markdown editor
- adding architectural layers that exist only to hide platform seams

## What "Perfect" Means Here

For this project, "optimized" means:

- startup is fast
- note switching is cheap
- chat streaming is smooth
- graph interaction does not hitch
- windows open and restore quickly
- large note bodies do not force database bloat
- model routing does not lie to the user
- UI work stays off hot Rust/model paths

## Known Stack Caveat

The current research starting point should not blindly assume `swift-winui` is the final production answer. Its public README has described it as an outdated example that points developers toward `swift-winrt`-generated projections. Research must explicitly validate the Windows Swift UI stack instead of treating it as settled fact.
