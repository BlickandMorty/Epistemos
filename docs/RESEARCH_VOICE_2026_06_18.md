# R-VOICE — Voice (TTS + STT) + retro filter verdict (2026-06-18)

Research-first verdict for **P7.7 (voice)**. Owner asks: add ONE real voice model
(TTS + STT), a Settings **auto-mode with granular toggles** (auto-read-screen /
read-AI-replies-aloud / voice-input, each independently on/off), and a selectable
**pixel-art retro voice filter** (bitcrush/formant DSP). Prefer on-device; keys in
Keychain if cloud.

> **OWNER DECISION 2026-06-18: ship BOTH voices.** (1) **Kokoro-82M** = the
> everyday on-device voice (+ AVSpeechSynthesizer instant fallback). (2)
> **MOSS-TTS** = a special "reading voice", selectable for reading a page in any
> note type + in-chat reading. Both selectable in the voice picker; the retro
> filter applies over either. MOSS path deepened below.

## TL;DR verdict

| Piece | Verdict | Cost | License | On-device? |
|---|---|---|---|---|
| **TTS model** | **TAKE Kokoro-82M** (via a Swift CoreML/MLX pipeline) as the "real voice"; keep AVSpeechSynthesizer as the instant zero-download fallback | Free | Apache-2.0 | ✅ ANE/GPU, ~330–600 MB |
| **STT** | **KEEP Apple SpeechAnalyzer/SFSpeech** (already wired); WhisperKit optional later for accuracy | Free | Apple / MIT | ✅ |
| **Retro pixel-art filter** | **BUILD** as an AVAudioEngine DSP chain on the TTS output (bitcrush + sample-rate reduction + formant/pitch shift) | Free | n/a (our code) | ✅ |
| **MOSS-TTS** ("reading voice", owner-required) | **TAKE via ONNX Runtime** (in-process, no Python) as a Pro/dev build lane; honest "install the MOSS reading-voice pack" blocker until the lane lands — see deep-dive below | Free | Apache-2.0 | ✅ via ONNX RT (needs wiring) |
| Cloud TTS (ElevenLabs/OpenAI) | **SKIP** for the default — conflicts with "prefer on-device" + local-first North Star. Could be a Pro opt-in later (keys in Keychain). | Paid | proprietary | ❌ |

## What the app ALREADY has (don't rebuild — extend)

- `Epistemos/Engine/EpistemosSpeechSynthesizer.swift` — Apple-native TTS (AVSpeechSynthesizer), thread-safe speak/pause/stop.
- `Epistemos/Views/Shared/ReadAloudButton.swift` — read AI replies aloud (the "read-AI-replies" affordance, per-message).
- `Epistemos/Views/Shared/VoiceInputButton.swift` — voice input (STT → composer); used in ChatInputBar.
- `Epistemos/Views/Shared/ModelVoicePickerSection.swift` — a voice picker (Settings).
- `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift` — STT pipeline.
- STT runtime: SpeechAnalyzer (macOS 26) / SFSpeechRecognizer, already used; `VoicePreferences` for dictation auto-stop.
- `media.text_to_speech` agent tool (ToolTierBridge) — the agent can already speak.
- Screen capture for "auto-read-screen": `ScreenCaptureService` + `Screen2AXFusion` already exist (permission-gated) — reuse, never silent.

So ~70% of P7.7 is wiring + Settings, not new infra. The genuinely-new pieces are
(1) a higher-quality neural TTS model option, and (2) the retro DSP filter.

## (1) TTS model — Kokoro-82M (TAKE)

Kokoro-82M is the clear on-device pick: 82M params, **Apache-2.0**, real-time on
Apple Silicon, 54 voices / 10 languages, and — critically — it has **maintained
Swift pipelines that need zero Python at inference**:

- `mweinbach/kokoro-swift` — MLX (GPU) + CoreML (ANE), on-demand voice downloads from HuggingFace.
- `mattmireles/kokoro-coreml` — PyTorch→CoreML conversion (runs on the Apple Neural Engine).
- `FluidInference/FluidAudio` — Swift, CoreML, TTS + STT + VAD + diarization in one package (a strong all-in-one).
- `soniqo/speech-swift`, `argmaxinc/WhisperKit` (STT) — adjacent on-device Swift stacks.

Recommendation: add Kokoro as the optional "premium voice" behind the existing
`ModelVoicePickerSection`, **downloaded like a model** (reuse `ModelDownloadManager`
+ the P1.8 honest progress UI), with **AVSpeechSynthesizer as the always-available
fallback** (no download, instant). This keeps the default light and MAS-safe
(no subprocess — CoreML/MLX is in-process) and gives a real upgrade on demand.
Honest gating: only show the Kokoro voice once its CoreML/MLX assets are installed.

Founding-Thesis fit: on-device, deterministic, no cloud dependency — same edge as
the local Fast/Think/Code models.

## (2) Retro pixel-art voice filter — BUILD (AVAudioEngine)

No model needed. A selectable "voice" that runs any TTS output through an
`AVAudioEngine` DSP chain so it sounds like a retro-game/anime character:

- **Bitcrush**: quantize samples to N bits (e.g. 6–8) → the classic crunch.
- **Sample-rate reduction** (sample-and-hold / decimation) → lo-fi chip texture.
- **Formant / pitch shift** (AVAudioUnitTimePitch, or a formant-preserving shift) → the "small character" timbre.
- Optional ring-mod / slight pitch wobble for the anime feel.

Implementation: an `AVAudioUnit` (or `AVAudioSourceNode` post-processor) inserted
between the synth output and the output node. Tunable params (bits, downsample
factor, pitch) → a few presets ("8-bit", "anime", "robot"). Fully on-device,
free, theme-aware UI (a preset row in the voice picker). This is the unique,
on-brand piece and is cheap to build.

## (3) Settings auto-mode + granular toggles

Three INDEPENDENT toggles (each off by default; honest, never silent):

- **Auto-read screen** — reuse `ScreenCaptureService` + `Screen2AXFusion`,
  **permission-gated** (Screen Recording entitlement), with a visible "reading
  screen" indicator. Never capture silently.
- **Read AI replies aloud** — auto-invoke `EpistemosSpeechSynthesizer` (or Kokoro)
  on each assistant message when on; reuse `ReadAloudButton` plumbing.
- **Voice input** — `VoiceInputButton` is already there; the toggle just controls
  whether it's shown/auto-armed.

Plus: a **voice picker** (system voices + Kokoro voices when installed + the retro
presets), and the retro-filter toggle. All in a Settings "Voice" section,
pixel-art minimal, theme-aware. Keep the existing thought-process display + voice
input intact.

## (4) MOSS-TTS as the special "reading voice" — DEEP DIVE (owner-required)

The owner-named "MOSS-TTS-PNY" maps to the **OpenMOSS MOSS-TTS family** ("PNY" =
its **Pinyin/phoneme-level pronunciation control** feature, not a separate repo;
ZDisket is a re-uploader/quantizer). It's a production-grade, expressive,
voice-cloning, ultra-long-stable AR discrete-token TTS. **License: Apache-2.0.**

**On-device feasibility — REAL, but a build lane (not a quick wire):**

- **Best fit = MOSS-TTS-Nano** — ~120M params total (a 0.1B token-LLM +
  ~20M `MOSS-Audio-Tokenizer-Nano` that decodes tokens → 48 kHz audio). Runs on
  **CPU, no GPU**. Apache-2.0.
- **The honest no-Python path = ONNX Runtime.** MOSS-TTS-Nano ships an
  `infer_onnx.py` / ONNX export that runs on **ONNX Runtime (CPU)** with **no
  PyTorch** and ~2× CPU efficiency. ONNX Runtime has a C/C++ API with Apple
  (iOS/macOS) packages → it links **in-process** into the Swift app. That means
  MOSS can run **fully on-device with NO Python and NO hidden subprocess** —
  MAS-honest, unlike a Python sidecar.
- Heavier alts exist (`mlx-community/MOSS-TTS-8B-8bit` via MLX-Swift;
  `smcleod/MOSS-TTS-v1.5-GGUF`) but 8B is ~5–8 GB and still needs the audio
  detokenizer — overkill for a "reading voice" on the 16 GB ship rig. Nano is the
  pick.
- **No turnkey Swift/CoreML MOSS pipeline exists today** (unlike Kokoro's
  `kokoro-swift`/`FluidAudio`). So MOSS needs real engineering: (1) obtain/export
  the two ONNX models, (2) link ONNX Runtime (Swift/C bindings) — a new SPM dep,
  (3) wire the text→token (LLM ONNX) → token→audio (tokenizer ONNX) glue + the
  Pinyin/phoneme front-end in Swift.

**Verdict / plan:** MOSS is the special **"reading voice"** as a **Pro/dev build
lane on ONNX Runtime** (in-process, on-device, Apache-2.0 — never Python on the
MAS path, never a hidden subprocess). Sequence it AFTER Kokoro (which has a ready
Swift path): ship Kokoro + AVSpeech + the retro filter first; add MOSS-via-ONNX as
its own slice. Until the ONNX lane lands, the MOSS voice option in the picker
shows an **honest blocker** ("MOSS reading voice — install the reading-voice
pack" / "available in the Pro/dev build"), never a fake/greyed voice that does
nothing. Founding-Thesis fit: fully local + deterministic, same edge as the local
text models.

## Open questions for the owner (pick to unblock the build)

1. Kokoro as a downloadable premium voice (recommended) — yes/no? If no, ship the
   retro filter + auto-mode on AVSpeechSynthesizer alone (still good).
2. Retro filter presets — which vibe(s): 8-bit chiptune, anime-character, robot?
3. Auto-read-screen — Pro-only or both builds? (It needs Screen Recording
   permission; MAS-allowed with the entitlement + user grant.)

## Sources

- [Best Offline TTS for Mac 2026 (spokio)](https://spokio.pro/best-offline-tts-mac-2026)
- [Best Open-Source TTS 2026 (bentoml)](https://www.bentoml.com/blog/exploring-the-world-of-open-source-text-to-speech-models)
- [kokoro-swift — MLX + CoreML Swift inference](https://github.com/mweinbach/kokoro-swift)
- [kokoro-coreml — PyTorch→CoreML for ANE](https://github.com/mattmireles/kokoro-coreml)
- [FluidAudio — Swift CoreML TTS/STT/VAD](https://github.com/FluidInference/FluidAudio)
- [Otosaku TTS-iOS — FastPitch+HiFiGAN CoreML offline](https://github.com/Otosaku/OtosakuTTS-iOS)
- [WhisperKit — on-device STT Swift](https://github.com/argmaxinc/WhisperKit)
- [mlx-audio — TTS/STT/STS on MLX](https://github.com/Blaizzy/mlx-audio)
- [Bit-crusher 101 (retro DSP technique)](https://audiomixingmastering.com/blog/bit-crusher-101-how-to-add-retro-grit-without-ruining-your-mix/)
- [OpenMOSS/MOSS-TTS (family, Apache-2.0)](https://github.com/OpenMOSS/MOSS-TTS)
- [OpenMOSS/MOSS-TTS-Nano (0.1B, CPU, ONNX path)](https://github.com/OpenMOSS/MOSS-TTS-Nano)
- [mlx-community/MOSS-TTS-8B-8bit (MLX quant)](https://huggingface.co/mlx-community/MOSS-TTS-8B-8bit)
- [smcleod/MOSS-TTS-v1.5-GGUF (GGUF quant)](https://huggingface.co/smcleod/MOSS-TTS-v1.5-GGUF)
