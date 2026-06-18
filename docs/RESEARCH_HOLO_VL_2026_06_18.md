# R-HOLO — Holo-3.1-4B VL for computer-use (honest verdict, 2026-06-18)

Owner asked to add **Hcompany/Holo-3.1-4B** — a vision-language model (VLM) for
computer-use agents (Qwen3-VL-4B lineage; Holo3.1 adds mobile + native
function-calling + quantized local checkpoints). Unlike the four text models
added today (26B-A4B, LFM2.5, Gemma 12B 2-bit), Holo is **vision** — and that
changes everything.

## VERDICT: do NOT add it as a text-GGUF candidate (it would fake vision)

**Ground truth:** the Epistemos GGUF runtime lane is `llama-cli` **text**
generation — `agent_core/src/providers/gguf_cli.rs:348` declares
`supports_vision: false`. A VLM's entire value is *seeing the screen*; loading
Holo on the text lane would (a) likely not load correctly, and (b) even if it
generated text, it would be blind — a fake "computer-use" capability. The honesty
constraints (REAL APIs only, no fake features, honest capability gating) forbid
adding it as a runnable `gguf_llama_cpp_offline` candidate. So it is NOT added to
`GemmaQATRuntimeLadder.candidates`. This is the "surface honestly / flag, don't
fake" the owner mandated.

## What Holo actually needs (the real gap)

A **local vision inference lane** that Epistemos does not have today:
- **Option A (llama.cpp multimodal):** `llama-mtmd-cli` + the model's `mmproj-*.gguf`
  projector (the Holo GGUF repos ship an `mmproj` alongside the weights). This is a
  *different binary/flag path* than the current `llama-cli` text lane — a new
  `GgufVisionCliProvider` (Pro/dev, MAS-forbidden subprocess, security.rs hardened)
  that passes `--mmproj <proj> --image <screenshot>`.
- **Option B (MLX VL):** an MLX-VLM Swift path for Qwen-VL-class models (on-device,
  MAS-viable) — heavier lift, no subprocess.

Then wire the lane into the EXISTING computer-use subsystem as a LOCAL vision
backend: `DeviceAgentService` / `ComputerUseBridge` / `VisualVerifyLoop` /
`ScreenCaptureService` / `Screen2AXFusion` already capture the screen + drive
actions; today that path is cloud/host-intercept (per the provider matrix +
the `computer_use` host-intercept note). Holo-3.1-4B would be the **local** vision
policy model feeding it (screenshot → Holo → grounded action/function-call), with
honest function-calling validated against the P8.2 deterministic schemas.

## Recommended sequencing
1. **Now:** this verdict + the ledger gap (done). NO fake catalog add.
2. **Vision lane (Pro):** build `GgufVisionCliProvider` (llama-mtmd-cli + mmproj),
   `supports_vision: true`, behind the GGUF flag + Pro gate. Fetch the real Holo
   GGUF + mmproj provenance (HF tree API) when wiring.
3. **Wire to computer-use:** Holo as the local vision policy in DeviceAgentService;
   function-calls validated vs P8.2 schemas; honest gating (Pro/dev; on MAS,
   computer-use stays the bounded/native path).
4. **Then** the catalog add becomes honest (a real vision candidate on a real
   vision lane).

## Sources
- [Hcompany/Holo-3.1-4B (base VLM)](https://huggingface.co/Hcompany/Holo-3.1-4B)
- [mradermacher/Holo1.5-3B-GGUF (GGUF + quant range; base Qwen2.5-VL-3B)](https://huggingface.co/mradermacher/Holo1.5-3B-GGUF)
- [Hcompany/Holo-3.1-35B-A3B-GGUF (official Holo GGUF w/ mmproj)](https://huggingface.co/Hcompany/Holo-3.1-35B-A3B-GGUF)
- ground truth: `agent_core/src/providers/gguf_cli.rs:348` `supports_vision: false`
