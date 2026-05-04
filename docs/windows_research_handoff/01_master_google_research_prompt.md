# Master Google Research Prompt

> **Index status**: DEFERRED-RESEARCH — Windows porting research; deferred (V1 = macOS-only per ambient_V1_DECISION.md).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/windows_research/`.



Act as a Principal Windows Systems Architect and native AI runtime engineer. You are researching a production-grade Windows 11 port of an existing macOS app called Epistemos.

Your job is not to brainstorm vaguely. Your job is to produce a defensible implementation blueprint with concrete tradeoffs, failure modes, and an execution plan.

## Product Goal

Port Epistemos from macOS to Windows as a fully native Windows 11 desktop app with the same product surface and the same architectural quality bar:

- native note editor
- native multi-window note system
- native chat surfaces
- high-performance graph view backed by Rust
- local-first AI orchestration
- no browser stack
- no Tauri
- no Electron
- no WebView shell

The Windows app should feel equivalent in quality to a high-end macOS native app, but expressed through Windows-native controls and conventions.

## Hard Constraints

- Frontend must be native Windows UI, not web UI.
- Preserve the current architecture split: native frontend + Rust engine/core.
- Swift 6 is strongly preferred on Windows if viable for a production app with native controls.
- Research must explicitly evaluate whether the best path is:
  - Swift 6 + WinUI 3 via `swift-winui`
  - Swift 6 + generated WinRT projections via `swift-winrt`
  - Swift 6 with a thinner C ABI around a C++/WinRT host
- Do not assume `swift-winui` is production-ready without proof.
- Backend/system core should remain Rust-first.
- The app must support local LLM routing, model selection, and token streaming.

## Target Hardware

- Dell XPS 16
- Intel Core Ultra 9 185H
- Intel NPU available
- NVIDIA RTX 4060 laptop GPU, roughly 40-50W power budget
- 64 GB RAM
- Windows 11

Research should optimize for this target first, while noting what generalizes to other Windows laptops.

## The Existing App's Real Engineering Style

The current macOS app is not a toy SwiftUI prototype. It follows these patterns:

- minimal layers and direct control flow
- `@MainActor @Observable` state on the UI side
- Rust FFI for performance-critical systems
- hybrid persistence: structured data in the app database, large note bodies on disk
- low-copy data movement
- aggressive cacheing and debounce in hot paths
- native text system integration instead of custom web-like editors
- native multi-window behavior
- explicit anti-pattern avoidance around UI update cascades and unnecessary refetches

The handoff docs attached after this prompt describe the app's architecture and coding patterns.

## Research Questions You Must Answer

### 1. Frontend Viability

Determine the best way to build a truly native Windows frontend while keeping Swift 6 in the stack if possible.

You must compare:

- Swift 6 + `swift-winui`
- Swift 6 + `swift-winrt`
- Swift 6 + direct Windows API / WinRT bindings
- Swift frontend with a tiny Windows-native host layer if pure Swift is not yet enough

For each path, answer:

- Is it actively viable in 2026 for a real desktop app?
- What parts are mature vs fragile?
- What tooling gaps exist?
- How hard is packaging, signing, distribution, crash reporting, and dependency shipping?
- How risky is long-term maintenance?
- What would break first under a complex multi-window, text-heavy, AI-heavy desktop app?

### 2. Native UI Architecture

Design the Windows-native equivalent of the current app shell:

- main note workspace
- multiple attached note windows
- mini chat windows/tabs
- toolbar-heavy note editing
- graph overlay / graph workspace
- settings and model-management surfaces

Specify:

- windowing model
- state ownership model
- how environment injection or equivalent DI should work
- how to preserve directness and avoid view-model bloat
- how to map the app's current native AppKit/TextKit editor behavior into Windows-native text controls

### 3. Rust Boundary Design

Propose the cleanest ABI boundary between Windows frontend code and the Rust core.

Answer:

- C ABI only, or C ABI plus generated bindings?
- Which objects stay Rust-owned?
- Which objects stay frontend-owned?
- How should string, byte buffer, and streaming token ownership work?
- How should shared-memory or ring-buffer patterns be used for graph/query transport?
- How do we avoid repeated marshaling and large copies?

### 4. Local AI Runtime Strategy

Design the Windows-local AI runtime for:

- Apple-style lightweight assist equivalent on Windows
- local Qwen chat and reasoning
- model selection in the UI
- fallback and routing policy
- streaming token delivery to the UI

Research the best runtime stack for this hardware:

- `llama.cpp`
- `ggml`
- CUDA-first runtimes
- DirectML only if there is a compelling reason
- OpenVINO for NPU-bound low-intensity background workloads

Be specific about:

- small always-hot model strategy
- larger reasoning model strategy
- coding-model strategy
- quantization recommendations
- VRAM residency strategy
- CPU affinity strategy on Intel Core Ultra hybrid cores
- whether E-cores should be excluded from hot token generation threads

### 5. NPU Use

Research whether Intel NPU use is actually worth it here.

Do not hand-wave. Determine:

- whether OpenVINO or another runtime can reliably target the Core Ultra NPU on Windows 11
- which specific workloads should go to the NPU
- which workloads should never go to the NPU
- expected latency/throughput class for embedding, reranking, summarization, and background graph scans
- whether the NPU path adds real user-perceived value or just complexity

### 6. Notes Editor Port

This is one of the most important areas.

The current app uses a native text-system bridge with persistent text views, storage swapping, native undo wiring, debounced sync, and strict avoidance of layout feedback loops.

Research the best Windows-native equivalent for:

- persistent editor instances
- zero-teardown page switching
- native undo/redo
- incremental syntax highlighting
- markdown-aware editing
- streaming AI text insertion
- selection preservation
- scroll position preservation
- multiple note windows

Recommend the best native text stack, not the easiest one.

### 7. Graph View Port

The graph is Rust-backed and performance-sensitive.

Research:

- best Windows-native rendering surface for a Rust-backed graph
- whether to use Direct3D 12, DirectComposition, Win2D, or another path
- how to preserve the current low-latency interaction loop
- how to keep incremental graph updates cheap
- how to stream graph/query state from Rust without UI-thread stalls

### 8. Production Hardening

Provide exact recommendations for:

- crash capture
- telemetry that does not slow the app
- performance tracing
- background task scheduling
- startup-time minimization
- memory-pressure handling
- packaging and shipping Rust + Swift on Windows
- update strategy

## Required Deliverables

Return a structured report with these sections:

1. Executive recommendation
2. Best frontend stack and why
3. Best Rust interop boundary and why
4. Best AI runtime design for this exact hardware
5. Best note-editor architecture on Windows
6. Best graph/rendering architecture on Windows
7. Concrete CPU/GPU/NPU scheduling strategy
8. Memory and copy-budget strategy
9. Packaging/distribution/tooling risks
10. Step-by-step migration plan from macOS architecture to Windows architecture
11. Red flags and things that look promising but should be rejected

## Output Style

- Be direct.
- Prefer concrete engineering detail over generic platform marketing.
- If something is immature, say it is immature.
- If Swift 6 on Windows is not enough by itself, propose the smallest native host layer necessary.
- Optimize for product quality, latency, and long-term maintainability.
- Assume this app is intended to ship.
