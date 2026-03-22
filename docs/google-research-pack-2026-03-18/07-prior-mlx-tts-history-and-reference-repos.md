# Prior MLX / TTS History and Reference Repos

## Local reference repos on disk

These local repos exist and were part of prior brainstorming:

- `/Users/jojo/projects/logic to implement/mlxchat-main`
- `/Users/jojo/projects/logic to implement/chatterbox-master`
- `/Users/jojo/projects/logic to implement/fish-speech-main`

## How to treat them

### MLXChat

Use as the strongest reference for:

- MLX Swift model loading
- Apple Silicon GPU memory handling
- local streaming generation
- Qwen chat-template quirks

Most important likely reference file:

- `/Users/jojo/projects/logic to implement/mlxchat-main/MLXChat/Engine/MLXEngine.swift`

### Chatterbox

Use as the strongest V1 TTS reference.

Reasons:

- Chatterbox Turbo is much lighter than Fish
- Chatterbox repo already has explicit `mps` handling in code
- Chatterbox is far easier to imagine inside a Mac app than Fish
- Chatterbox license is MIT

Important local refs:

- `/Users/jojo/projects/logic to implement/chatterbox-master/README.md`
- `/Users/jojo/projects/logic to implement/chatterbox-master/src/chatterbox/tts_turbo.py`

### Fish Speech

Use only as a comparative / phase-2 reference unless research strongly proves otherwise.

Reasons:

- much heavier operating profile
- docs are much more Linux/WSL/CUDA/server oriented
- commercial license is not as straightforward as Chatterbox

Important local refs:

- `/Users/jojo/projects/logic to implement/fish-speech-main/README.md`
- `/Users/jojo/projects/logic to implement/fish-speech-main/docs/en/install.md`
- `/Users/jojo/projects/logic to implement/fish-speech-main/LICENSE`

## Prior internal design docs

The strongest previous internal docs are:

- `/Users/jojo/Epistemos/docs/superpowers/specs/2026-03-10-craft-inspired-vision-design.md`
- `/Users/jojo/Epistemos/docs/plans/2026-03-07-agent-system-implementation-plan.md`
- `/Users/jojo/Epistemos/docs/plans/2026-03-07-agent-system-design.md`

## Key prior decisions from those docs

Previously approved direction:

- Apple Intelligence first
- MLX local second
- Qwen primary local family
- Gemma fallback local family
- first-run setup should pre-download a small Qwen and a small Gemma
- Chatterbox Turbo via persistent Python daemon subprocess

Those older docs also referenced model candidates like:

- `mlx-community/Qwen3.5-0.8B-MLX-4bit`
- `mlx-community/Qwen3.5-2B-MLX-4bit`
- `mlx-community/Qwen3.5-4B-MLX-4bit`
- `mlx-community/Qwen3.5-9B-MLX-4bit`
- `ResembleAI/chatterbox-turbo`

Research should validate whether those are still the best starting points or should now be replaced with newer Qwen/Gemma options.

## Historical implementation commits

The app previously had MLX/TTS implementation work in git history:

- `74242ad` — `Phase 1: MLX on-device inference provider`
- `d165391` — `Phase 8: Voice system scaffold (VoiceEngine)`
- `6944dd0` — `TTS fully integrated across all surfaces`
- `60efc0c` — `Revert all agent system implementation (phases 1-10)`

That history matters because:

- prior implementation ideas may still be useful
- current branch should not blindly restore them
- the right move is likely selective modern reimplementation, not wholesale restoration

## Key practical conclusion so far

The working assumption for research should be:

- MLX native local inference is the right path for local LLMs
- Chatterbox is the right first TTS engine
- Fish should be treated as optional/later unless research overturns that
