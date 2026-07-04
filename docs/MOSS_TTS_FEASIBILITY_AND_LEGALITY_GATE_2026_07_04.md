# MOSS TTS — Feasibility + MAS-Legality Gate (2026-07-04)

**Bottom line (honest):** MOSS-TTS-Nano is **legally viable** for the Mac App Store (MAS) build
— Apache-2.0, an official **PyTorch-free** inference path, tiny (0.1B), Apple-Silicon-capable.
But it is **not integrated and not verified** from this session: shipping it needs real engine
work (below) plus a **sandboxed-run audio proof** that requires the model weights and a MAS
build. **Kokoro remains the MAS voice.** This is the directive's "NO on proof → report the
exact blocker, keep Kokoro" outcome — nothing here is faked or gated-open.

## Model lineup (all Apache-2.0, OpenMOSS/MOSI.AI)
- **MOSS-TTS-Nano** — 0.1B params, realtime on CPU (no GPU), simple deploy → **MAS candidate**.
- **MOSS-TTS** (flagship), **MOSS-TTSD** (multi-speaker dialogue + zero-shot cloning),
  **MOSS-VoiceGenerator** (voice design) → heavier, **Pro-only** variants.

## Native path (the reason MOSS is even a candidate)
MOSS ships an **official torch-free pipeline**:
- **Backbone (Qwen3):** `llama.cpp` on **GGUF** weights (`OpenMOSS-Team/MOSS-TTS-GGUF`).
- **Audio tokenizer/codec:** **ONNX Runtime / TensorRT** on `OpenMOSS-Team/MOSS-Audio-Tokenizer-ONNX`.
- First-class impl: `OpenMOSS/llama.cpp` branch `moss-tts-firstclass` (end-to-end docs + runnable pipeline).
- **No MLX** path advertised (mlx-audio not present for MOSS as of this research).

## MAS-legality gate assessment (the 4 criteria)
| Criterion | Verdict | Basis |
|---|---|---|
| (a) PyTorch-free | **YES** | llama.cpp + ONNX Runtime; PyTorch not required for inference |
| (b) Fully in-process (no subprocess/socket/JIT) | **FEASIBLE, unproven** | llama.cpp is embeddable (app already embeds it); codec via ONNX Runtime *or* CoreML, both in-process |
| (c) Apple Silicon | **YES** | llama.cpp + ONNX Runtime both run on arm64 |
| (d) ≤16 GB | **YES** | Nano 0.1B ≈ 100–200 MB quantized |

→ **Nano passes on legality**, but (b) is only proven by an actual in-process render, which needs the engine below + a run.

## Exact blockers (why it is NOT shipped from here)
- **B1 — embedded llama.cpp lacks MOSS-TTS support.** The app embeds **upstream** llama.cpp via
  `LocalPackages/EpistemosLlama` (built `llama.framework`, has `mtmd`), NOT the OpenMOSS
  `moss-tts-firstclass` fork. MOSS-TTS uses a custom head/tokenization the upstream build does
  not decode. Fix: port the `moss-tts-firstclass` changes into EpistemosLlama (a real
  llama.cpp fork-merge, must stay maintainable against upstream).
- **B2 — audio codec dependency.** The ONNX audio tokenizer needs **either** ONNX Runtime as a
  new in-process native framework (added binary + maintenance) **or** conversion of the ONNX
  codec to **CoreML** to ride the existing Kokoro CoreML playback path. **RECOMMENDED: CoreML**
  — no new dependency, reuses `KokoroCoreML*` infra + the in-process AVAudioPlayerNode path.
- **B3 — weights not installed.** GGUF backbone + codec are weights-as-data (download OK, never
  commit `.gguf/.onnx/.mlpackage`). Needs a MossModelDownloadService mirroring Kokoro's.
- **B4 — audio proof requires owner machine.** The (b) in-process proof + "actually HEAR it"
  gate need a **sandboxed MAS build + a real render**. Debug is non-sandboxed and would lie.

## Recommended integration path (mirrors Kokoro, minimizes new surface)
1. **Engine seam:** add `Epistemos/VoicePro/Moss*` mirroring `Kokoro*` —
   `MossVoiceGateStatus` (honest-gate; `isReady` only when engine linked + weights valid),
   `MossCoreMLRuntimeLoader`, `MossCoreMLSynthesizer.renderRawText(...)`.
2. **Backbone:** MOSS GGUF via EpistemosLlama once B1 (MOSS-TTS llama.cpp support) lands.
3. **Codec:** convert ONNX tokenizer → CoreML (B2), decode in-process, feed the SAME
   `AVAudioPlayerNode` path in `EpistemosSpeechSynthesizer`.
4. **Consumption side is ALREADY READY:** `ReadAloudButton` + `speak(voiceIdentifier:)` +
   `ModelVoicePickerSection` are engine-agnostic. When `MossVoiceGateStatus.isReady`, add a MOSS
   section to the picker (Kokoro | MOSS) and route `speak()` to the MOSS synthesizer by voice id.
5. **Gate:** MOSS **Pro-only** for heavier variants regardless; Nano on MAS **only** after B4
   passes in a sandboxed run. Until then MOSS honest-gates OFF, Kokoro is MAS.

## What IS done + shippable now (this session)
- Kokoro engine LIVE + hardened (0 AVSpeech-speak calls, clean audio lifecycle — verified).
- Kokoro **voice selection** end-to-end (picker → `speak(voiceIdentifier:)` → voice pack).
- ReadAloudButton on meeting + notes (honest-gated); QuickCapture pre-existing.
- The shared engine/UI is **engine-plural-ready** — MOSS drops in behind the same seam.

## Sources
- https://github.com/OpenMOSS/MOSS-TTS
- https://github.com/OpenMOSS/MOSS-TTS-Nano
- https://github.com/OpenMOSS/MOSS-TTSD
- https://huggingface.co/OpenMOSS-Team/MOSS-TTS-GGUF
- https://github.com/OpenMOSS/llama.cpp/tree/moss-tts-firstclass
