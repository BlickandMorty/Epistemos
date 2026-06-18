# R-CUA verdict — trycua/cua vs Epistemos (2026-06-18)

**Verdict: LIFT ONE NATIVE PIECE (Lume, Swift + Virtualization.framework, MIT)
for the Act=Osaurus sandbox — Pro/dev-gated. The CU loop is largely MATCHED by
Epistemos's native computer-use stack. Python (Agent SDK, cua-computer-server) is
NO-SIDECAR — patterns-only. Research-first; no code lifted this slice.**

## What cua is
MIT-licensed computer-use-agent infra (trycua/cua). Four pieces:
- **Lume** — macOS/Linux VM management on Apple Silicon via Apple's
  **Virtualization.framework**, **written in Swift**, standalone CLI
  (`lume run macos-sequoia-vanilla`). Near-native VMs + snapshots. Lumier =
  Docker-compatible interface over it.
- **Cua Driver** — native (Swift/Rust) desktop automation (macOS/Windows/Linux).
- **Agent SDK** — **Python** (`cua` pip package): the orchestration loop
  (Sandbox.ephemeral → screenshot → model → mouse/keyboard → verify).
- **cua-computer-server** — **Python** sidecar for sandbox interaction.

## Side-by-side vs Epistemos

| cua piece | Epistemos today | Verdict |
|---|---|---|
| **Lume — Swift Virtualization.framework VM manager (snapshots)** | none — the Act sandbox plan is Apple **Containerization** (Pro-only, per the Osaurus direction); no VM-level sandbox | ✅ **LIFT NATIVELY** — Lume is Swift + MIT, exactly the VM-sandbox layer the Act=Osaurus plan wants. Pro/dev-gated (VMs need the virtualization entitlement + are not MAS-shippable). |
| **CU loop: screenshot → model → action → verify** | `DeviceAgentService` + `VisualVerifyLoop` + `Screen2AXFusion` + `ScreenCaptureService` + `CGEvent`/AXorcist (native macOS computer-use) | ✅ matched — Epistemos already drives the perceive→decide→act→verify loop natively. Lift cua-driver PATTERNS only where stronger (cross-OS sandbox targeting). |
| **Sandbox/Driver abstraction (unified VM/container API)** | partial — Containerization (Pro); no unified VM+container+screen API | ➖ pattern worth adopting: a unified `Sandbox` seam (VM via Lume / container via Containerization / host) behind one API, fed to the CU loop. |
| **Holo VL (vision-language for CU)** | R-HOLO-VL verdict (vision lane gap — GGUF lane is text-only) | ➖ deep CU needs a vision model; tracked separately (R-HOLO-VL). |
| **Agent SDK orchestration (Python)** | agent_core loop (Rust) + LocalAgentLoop (Swift) | ⮕ NO-SIDECAR — do NOT run the Python; the orchestration is already native. |
| **cua-computer-server (Python sidecar)** | n/a | ⮕ NO-SIDECAR — forbidden on MAS. |

## The fuse (owner: "fused to browser-use or used aside from it")
1. **Lume → Act=Osaurus sandbox** (Pro/dev): lift the Swift Lume
   Virtualization.framework VM manager as the VM-sandbox layer for Act, alongside
   Containerization. Gives sandboxed, snapshot-able macOS/Linux VMs for autonomous
   Act runs — the heaviest isolation tier. This is the concrete native lift.
2. **CU loop → native stack**: Epistemos's DeviceAgentService/VisualVerifyLoop/
   Screen2AXFusion already do screenshot→model→action→verify. Lift cua-driver
   PATTERNS (the unified Sandbox abstraction, cross-OS targeting) into a
   `Sandbox` seam; pair with Holo VL (R-HOLO-VL) for the vision lane.
3. **browser-use fuse**: the CU loop can drive a browser inside a Lume VM
   (sandboxed browser-use) OR aside from it (host AXorcist) — the unified Sandbox
   seam makes both first-class.

## Why mostly not a port
The Python Agent SDK + server are NO-SIDECAR on MAS (Pro/dev only). The
orchestration is already native (agent_core + LocalAgentLoop + the CU stack). The
ONLY substantial native lift is **Lume** (Swift, MIT, Virtualization.framework) —
which is exactly the Act sandbox VM layer.

## Recommendation
1. Fold "lift Lume natively" into the **Osaurus P3.0 ACT plan** as the VM-sandbox
   tier (Pro/dev-gated, virtualization entitlement). Vendor the Swift Lume source
   through `F-ProprietaryCompression-ProvenanceGate` (MIT → direct_import or
   adapter_wrap).
2. Adopt the unified `Sandbox` seam pattern (VM / container / host) for the CU
   loop + browser-use.
3. No Python. No code lifted this slice (research-first verdict).
