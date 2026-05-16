# B2-H16 Chatterbox TTS - User Decision Research

**Status:** COMPLETE_RESEARCH_READY
**Date:** 2026-05-16
**Terminal E scope:** user-decision preparation only; no implementation.

## Problem Statement

The user needs to decide whether Chatterbox TTS belongs in Epistemos, and if so where: MAS V1/V1.x, Pro V1.1+, or nowhere.

The reconciliation gate splits the issue into two different surfaces:

- Epistemos already has native Apple TTS UX through `AVSpeechSynthesizer`, per-model voice personas, read-aloud buttons, and manual/auto voice preferences.
- `agent_core` also has a Pro-only `media.text_to_speech` tool that shells out to the macOS `say` command with explicit playback/output-file gating.
- Chatterbox itself is not present in production code, Cargo features, Xcode project references, or local package manifests.
- Upstream Chatterbox is permissively licensed, but it is a Python/PyTorch package with large transitive ML dependencies and packaging/runtime implications that do not fit MAS V1.

The decision is not "does Epistemos need voice?" Voice already exists. The decision is whether Chatterbox's quality and voice-cloning advantages justify a future Pro-only Python daemon/runtime package, or whether MAS and Pro should stay on Apple-native/system TTS.

## Options

### Option A - MAS native TTS only; evaluate Chatterbox for Pro only after a real quality gap

Keep MAS V1 and MAS V1.x on Apple-native `AVSpeechSynthesizer` and the existing UI voice surfaces. Do not bundle Chatterbox, Python, PyTorch, model weights, or a daemon in MAS. Revisit Chatterbox only for Pro if users hit a concrete quality gap that Apple voices cannot close.

**Pros**
- Matches current MAS-safe implementation.
- Avoids bundling Python, PyTorch, TorchAudio, Transformers, Diffusers, Gradio, and Chatterbox weights.
- Keeps App Review and notarization risk low.
- Preserves Chatterbox as an optional Pro path if quality genuinely matters later.
- Lets the project measure native voice quality first instead of adding infrastructure speculatively.

**Cons**
- Chatterbox-specific strengths such as emotion control, paralinguistic tags, multilingual voice cloning, and zero-shot cloning are not available in MAS.
- If native Apple voices disappoint users, the Pro evaluation still has to be built later.
- Pro users who expect local open-source neural voice cloning will wait.

### Option B - Start a bounded Pro Chatterbox daemon spike after V1

Keep MAS native-only, but schedule a Pro spike immediately after V1 to evaluate Chatterbox Turbo as a separate Python daemon behind a Unix domain socket.

**Pros**
- Tests the highest-value Chatterbox path without contaminating MAS.
- Aligns with Five Laws Law 5: Python goes out-of-process immediately.
- Gives concrete latency, memory, disk, signing, update, and voice-asset measurements.
- Can be killed after the spike if native voices are sufficient.

**Cons**
- Still adds Python runtime, dependency, model-weight, IPC, crash-recovery, and update complexity to Pro.
- Requires a separate security/signing story for a Python daemon and model assets.
- Competes with other V1.1 Pro work unless a real voice-quality need exists.

### Option C - Ship Chatterbox in MAS

Bundle or auto-install Chatterbox for the MAS build, either in-process or through a managed internal environment.

**Pros**
- Gives MAS users open-source neural TTS and voice cloning.
- Makes Chatterbox the primary TTS engine as the superseded March research prompt originally requested.

**Cons**
- Conflicts with the current MAS direction and binding no-sidecar/no-Python packaging rules.
- Adds App Review risk around executable runtimes, subprocesses, model downloads, voice cloning, and generated-audio disclosure.
- Increases bundle/download/update complexity.
- Duplicates a native Apple TTS surface that already exists.
- The upstream package is Linux/Python/PyTorch-oriented, not a native Swift/MLX framework.

### Option D - Remove Chatterbox from the roadmap permanently

Declare Chatterbox closed and keep all TTS on Apple-native/system TTS forever.

**Pros**
- Simplest long-term product and security posture.
- Eliminates a recurring user-decision item.
- Avoids voice-cloning policy and asset-management work.

**Cons**
- Discards an MIT-licensed open-source neural TTS family that may be valuable for Pro.
- Forecloses emotion control, paralinguistic tags, multilingual zero-shot cloning, and local voice-cloning workflows even if users later ask for them.
- May force the project to revisit another TTS engine later from scratch.

## Canonical Sources

### `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md`

- Lines 166-170: B2-H16 frames Chatterbox as a production packaging architecture question: Python runtime bundling, subprocess IPC, voice asset management, latency, caching, signed distribution, and App Review risk.
- Lines 399 and 611: current audit register says the default is MAS native `AVSpeechSynthesizer` only, with Pro Chatterbox evaluation gated on a quality complaint.

### `docs/google-research-pack-2026-03-18/00-google-master-prompt.md`

- Lines 1-4: the source pack is explicitly superseded historical research.
- Lines 12-16 and 52: the older prompt wanted local TTS using Chatterbox and called Chatterbox the primary TTS engine.
- Lines 102-128: the actual unresolved question is production Chatterbox architecture: Python runtime approach, App Store realism, daemon/subprocess architecture, IPC, lifecycle, voice assets, caching, latency, streaming, cancellation, offline behavior, Turbo default, multilingual option, default voice, and custom voice cloning.
- Lines 196-205: distribution strategy must cover direct-download builds, App Store-compatible builds, feature gating if Python-based Chatterbox is not App Store-safe, notarization/signing, and external-weight compliance.

### `docs/google-research-pack-2026-03-18/07-prior-mlx-tts-history-and-reference-repos.md`

- Lines 31-40: historical research preferred Chatterbox over Fish because Turbo looked lighter, Chatterbox had MPS handling in local references, and the license was MIT.
- Lines 73-80: older direction included Chatterbox Turbo through a persistent Python daemon subprocess.
- Lines 92-105: prior MLX/TTS implementation work was reverted and should not be blindly restored.
- Lines 107-113: the older working assumption still considered Chatterbox the first TTS engine, but this predates the current MAS V1 native TTS and no-sidecar decisions.

### `CLAUDE.md`

- Lines 11-12: non-negotiable constraint says no sidecar; inference and orchestration run in-process via Rust FFI or MLX-Swift, with only the oMLX oversized-model exception.
- Lines 74 and 87-92: subprocesses are forbidden for inference/orchestration, though hardened subprocess helpers exist for allowed non-inference tool calls.

### `docs/NEW_SESSION_HANDOFF_2026_05_15.md`

- Lines 41-46: Five Laws Law 5 says Python goes out-of-process immediately behind a Unix domain socket, saving bundle size and crash-isolating Python. This is a Pro/post-V1 daemon shape, not a MAS V1 bundled in-process shape.

### `Epistemos/Engine/VoicePreferences.swift`

- Lines 5-24: voice preferences are already a central store for agent response TTS, note read-aloud, dictation, brain-dump dictation, and per-model voice routing.
- Lines 88-108: conservative defaults set agent response TTS and note read-aloud to manual.
- Lines 111-134: settings expose `agentResponseTTS`, `noteReadAloud`, `dictationAutoStop`, `brainDumpHotkeyDictate`, and `perModelVoicePersona`.

### `Epistemos/Engine/EpistemosSpeechSynthesizer.swift`

- Lines 7-18: Wave 9.1/9.1.b implements Apple-native TTS through `AVSpeechSynthesizer`, per-model voice personas, a premium voice catalog, and playback controls.
- Lines 28-40: the implementation does not auto-download Premium voices, does not block, and relies on state observation for UI.
- Lines 123-157: `speak` uses `AVSpeechUtterance`, resolved Apple voices, rate, pitch, and process-wide playback state.
- Lines 181-228: the app enumerates installed voices and falls back through premium, enhanced, and system default voices.
- Lines 230-252: the UI can surface hints for installing higher-quality Apple voices.

### `Epistemos/Models/SDModelProfile.swift`

- Lines 75-91: model profiles already persist `voiceIdentifier`, `voiceRate`, and `voicePitch`.

### `agent_core/src/tools/media.rs`

- Lines 677-754: the Pro media `text_to_speech` tool uses the macOS `say` subprocess, requires `allow_audio_playback=true` when no output file is provided, and can render to an output file.
- Lines 998-1027: the schema documents macOS `say`, voice/rate/output path, playback consent, file output, and an 8,000-character cap.

### `agent_core/src/tools/registry.rs`

- Lines 1129-1174: `register_phase_six_media` is gated by `pro-build`; it registers `media.text_to_speech` with `RiskLevel::Modification`.
- Lines 3777-3812: tests assert ChatPro includes `media.text_to_speech` while ChatLite is the baseline.

### `agent_core/src/resources/tool_authz.rs`

- Lines 100-105: TTS playback without a stable output resource is not file-gated, while output-file writes are gated as file writes.

### Current codebase search

- `rg -n "Chatterbox|chatterbox" Epistemos agent_core LocalPackages Epistemos.xcodeproj agent_core/Cargo.toml` returned no production-code matches on 2026-05-16.

### Upstream Chatterbox primary sources checked 2026-05-16

- Resemble AI Chatterbox page: `https://www.resemble.ai/learn/models/chatterbox`
  - Describes Chatterbox as an open-source MIT-licensed family with original, multilingual, and Turbo models.
  - Claims emotion control, faster-than-realtime synthesis, zero-shot voice cloning from seconds of reference audio, built-in PerTh watermarking, and 23+ language support.
- GitHub repository: `https://github.com/resemble-ai/chatterbox`
  - README describes three models: Turbo 350M English, Multilingual 500M 23+ languages, and original 500M English.
  - Quickstart is `pip install chatterbox-tts`; example code loads models with `device="cuda"`.
  - README says development/testing used Python 3.11 on Debian 11 with pinned dependencies.
  - `LICENSE` is MIT.
  - `pyproject.toml` version is `0.1.7`, `requires-python = ">=3.10"`, and dependencies include `torch`, `torchaudio`, `transformers`, `diffusers`, `gradio`, `librosa`, `safetensors`, `conformer`, `resemble-perth`, and language/audio utilities.
- PyPI package: `https://pypi.org/project/chatterbox-tts/`
  - Latest observed version on 2026-05-16 is `0.1.7`, uploaded 2026-03-26.
  - PyPI metadata says license is MIT and Python requirement is `>=3.10`.
  - PyPI page repeats the Python 3.11 / Debian 11 development note.

## Code Impact Estimate

### Option A - MAS native TTS only; conditional Pro evaluation

Estimated implementation now: 0-200 LOC, mostly docs/status cleanup.

Potential follow-up work:

- Add an explicit "Chatterbox not in MAS" note to voice settings docs if needed.
- Add a Pro evaluation ticket only if native TTS quality complaints arrive.
- Keep existing `AVSpeechSynthesizer` tests and manual QA as the V1 voice baseline.

Tests:

- No Chatterbox tests now.
- Existing Swift voice UI tests remain the relevant MAS surface.
- Optional Pro `media.text_to_speech` tests can continue to prove the system `say` tool is gated separately.

### Option B - Pro daemon spike

Estimated implementation: 2,000-5,000 LOC plus packaging scripts and binary/model asset management.

Likely work:

- Python environment manager for Pro only.
- Unix domain socket daemon protocol.
- Model/voice asset download, integrity, cache, eviction, and uninstall.
- Crash recovery, health checks, cancellation, queueing, and streaming/chunking.
- Consent and disclosure for voice cloning/reference clips.
- Pro-only feature gates and MAS symbol/package audits.

Tests:

- Daemon lifecycle tests.
- IPC schema and cancellation tests.
- Model asset integrity tests.
- MAS build test proving no Chatterbox/Python bundle leakage.
- Latency/memory benchmark on the V1 16GB rig and larger Pro tiers.

### Option C - MAS Chatterbox

Estimated implementation: 4,000-9,000 LOC plus high-risk distribution work.

Likely work:

- All Option B work.
- App Store review packet, entitlement review, generated-audio/voice-cloning disclosure, model download compliance, and fallback path if downloads fail.
- Bundle-size, cold-start, and update strategy.

Tests:

- All Option B tests.
- MAS sandbox and App Review rehearsal.
- Offline/low-storage scenarios.

### Option D - Remove Chatterbox permanently

Estimated implementation: 100-500 LOC docs cleanup.

Likely work:

- Mark B2-H16 closed in audit docs.
- Remove Chatterbox references from future queues and handoffs.
- Keep native TTS roadmap tied to Apple voices and system TTS only.

## Recommendation

Recommend **Option A: MAS native TTS only; evaluate Chatterbox for Pro only after a real quality gap**.

Recommended decision record:

> MAS stays Apple-native for TTS. V1 uses `AVSpeechSynthesizer` with manual defaults, per-model voice personas, and read-aloud controls. Chatterbox is rejected for MAS because it is a Python/PyTorch runtime plus model-asset packaging problem, not a native framework, and current binding rules forbid that scope for MAS. Pro may run a bounded Chatterbox Turbo daemon spike only after a concrete Apple-voice quality gap is observed. If that spike happens, Python must run out-of-process behind a Unix domain socket, Chatterbox must be absent from `mas-build`, and model/voice assets need integrity, disclosure, cache, and uninstall handling.

Reasoning:

- The project already ships MAS-friendly voice UX. Chatterbox is not needed to answer the V1 voice requirement.
- Upstream Chatterbox's MIT license is favorable, but licensing is not the hard part; Python/PyTorch packaging, daemon lifecycle, weights, and voice-cloning policy are.
- The source research pack is explicitly superseded historical context. It is useful for future Pro research, but it should not override current MAS V1 rules and current native TTS code.
- A Pro-only spike preserves the option without making MAS carry the risk.

## Acceptance Criteria

If the user chooses **Option A**:

- No Chatterbox, Python runtime, PyTorch dependency, or Chatterbox model asset is added to MAS.
- Current `AVSpeechSynthesizer` read-aloud and per-model voice persona surfaces remain the V1 voice path.
- The MAS plan records Chatterbox as rejected for MAS and conditional for Pro only.
- A Pro Chatterbox ticket is opened only after a concrete native-voice quality complaint or explicit user override.
- Any future Pro spike must prove Chatterbox is absent from `mas-build`.

If the user chooses **Option B**:

- MAS remains native-only.
- Pro spike uses a Python daemon behind UDS, not in-process Python.
- Spike has exit criteria: latency, memory, disk, startup, crash recovery, voice-asset policy, model integrity, and MAS symbol-leak proof.
- Spike can be killed without affecting MAS voice UX.

If the user chooses **Option C**:

- User explicitly accepts MAS App Review and packaging risk.
- Implementation includes a review/disclosure packet for voice cloning, generated audio, model downloads, Python runtime, and external weights.
- Build tests prove all runtime assets are signed, cacheable, uninstallable, and recoverable after failure.

If the user chooses **Option D**:

- B2-H16 is removed from future user-decision queues.
- Docs preserve the rationale that Chatterbox was rejected despite MIT licensing because native voice is sufficient and Python/PyTorch packaging is not worth the product complexity.

## Decision-Ready Prompt

**B2-H16 Chatterbox TTS decision:** What should Epistemos do with Chatterbox?

1. **MAS native TTS only; Pro evaluation only after quality gap** - keep MAS on `AVSpeechSynthesizer`; reject Chatterbox for MAS; revisit Pro only if native voices are insufficient. **Recommended.**
2. **Start Pro Chatterbox daemon spike after V1** - MAS stays native-only, but Pro immediately evaluates Chatterbox Turbo behind a Python UDS daemon.
3. **Ship Chatterbox in MAS** - accept Python/PyTorch/model-asset packaging and App Review risk.
4. **Remove Chatterbox permanently** - close the option and keep all TTS on Apple/system voices.

Answer with one option label and constraints, for example: "Option 1, but run a Pro spike if multilingual voice cloning becomes a paid feature."
