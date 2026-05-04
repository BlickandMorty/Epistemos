# Hermes Strategic Fork Analysis: Build vs Bundle

> **Index status**: CANONICAL-RESEARCH — Hermes integration research (Phase D + K reference).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/hermes_research/`.



## Overview
Recent synthesized research highlights a critical architectural fork for Epistemos: **Bundle Hermes via a Python Subprocess** vs. **Build a Native Rust Planner leveraging Hermes's prompt conventions.**

## The Consensus Evaluation
While the subprocess path (Strategy B) is extensively documented in our implementation specs, the native Rust approach provides significant long-term advantages tailored specifically for the Epistemos macOS environment.

| Dimension | Option A: Bundle Subprocess | Option B: Build Native Rust Planner |
| --------- | --------------------------- | ----------------------------------- |
| **Effort** | 2 eng-weeks MVP. Uses pre-existing Hermes logic. | 2-4 eng-weeks. Requires writing a ~1.5K LOC planner loop in `agent_core`. |
| **Footprint** | Adds ~180MB to app bundle + 300MB if Chromium is attached. | ~0MB added payload. |
| **Latency** | 2–5s Python cold start overhead. | Instant native execution. |
| **Complexity** | Extremely high codesigning overhead (`python-build-standalone`, deep `.dylib` signing). | Near zero complexity, utilizes existing Swift/Rust bridging. |
| **Ecosystem** | Inherits Python dependency vulnerability. | Bulletproof Apple Silicon native execution. |

## The Recommended "Hybrid" Path
You already possess 80% of the primitives required to run this natively: `agent_core`, `omega-mcp`, `omega-ax`, and `MCPBridge.swift`.

**The Hybrid Execution Strategy:**
1. **Adopt the Format, Not the Runtime:** Do not run Python. Instead, adopt Hermes's `<tool_call>` XML prompt format and `agentskills.io` skill format natively.
2. **Train your Rust Loop:** Since open-source models are tuned explicitly against these Hermes XML tool-calling prompt structures, implementing the Rust planner loop to parse and format XML exactly like Hermes gets you 100% of the reasoning capability of Hermes without executing a single line of Python.
3. **Native Tethers:** Swap heavy Python dependencies for native APIs:
   - Replace PyMuPDF with Apple's `PDFKit`.
   - Replace Python Tesseract with Apple `Vision` framework.
   - Execute web searches directly via Swift's URLSession mapping to Tavily.

## Conclusion
Bundling the subprocess is the fastest path to an out-of-the-box demo, but the Native Rust approach is the only sustainable product trajectory for a solo dev. It aligns with Apple's ecosystem, avoids Apple Store (MAS) sandboxing rejection, and maintains Epistemos's identity as a hyper-fast native shell.
