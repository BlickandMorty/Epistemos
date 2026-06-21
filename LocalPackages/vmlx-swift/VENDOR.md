# Vendored: osaurus-ai/vmlx-swift (the consolidated MLX stack for the full-Osaurus link)

Take-control vendor (`.git` stripped) of Osaurus's consolidated MLX fork — the package
OsaurusCore depends on. Vendored so Epistemos **consolidates onto ONE MLX** and links OsaurusCore
without the dual-MLX module clash. See `docs/research/OSAURUS_MAS_ENTITLEMENTS_RESEARCH_2026_06_21.md`.

| Field | Value |
|-------|-------|
| Upstream | https://github.com/osaurus-ai/vmlx-swift |
| Pinned revision | `4453909ef453f9235fd7e65986ca3ffc62ff904d` |
| Clone date | 2026-06-21 |
| License | **MIT** |
| ProvenanceGate | `direct_import` |
| Submodules (flattened in-tree) | `Source/Cmlx/mlx` = osaurus-ai/mlx @`e59d1d47` (MLX C++ core), `Source/Cmlx/mlx-c` = osaurus-ai/mlx-c @`3e013fb5`. A local SwiftPM path package needs the submodule sources PRESENT or the Cmlx C++ target fails (`compiled.cpp not found`) — so they're vendored as plain source, `.git` stripped. |

## Why this replaces `mlx-swift-lm` + `ml-explore/mlx-swift`
`vmlx-swift` provides the SAME module names Epistemos imports — `MLX`, `MLXNN`, `MLXOptimizers`,
`MLXRandom`, `MLXFast`, `MLXLLM`, `MLXLMCommon`, `MLXVLM`, `MLXEmbedders` — plus Osaurus-prefixed
`VMLXTokenizers`/`VMLXJinja`/etc. Because the `MLX*` names match, Epistemos's 8 MLX files map 1:1.
Two packages can't both define `MLX*` in one binary, so consolidating onto vmlx-swift removes the
clash AND keeps Osaurus's own MLX stack (osaurus-ness intact).

## Import-site changes (Epistemos side)
1. `import Tokenizers` → `import VMLXTokenizers` (`NativeKTOTrainer.swift`).
2. `MLXStructured` package dropped (pinned ml-explore mlx-swift → would re-clash); its consumer
   `LocalToolGrammar.swift` is `#if canImport`-guarded → degrades to omegaSoftGuidance fallback.

## ⚠️ EPISTEMOS OVERLAY PATCHES (re-apply after re-vendoring)
A re-vendor (`update-vmlx.sh`) OVERWRITES the source — re-apply these marked patches:
- `Libraries/MLXLMCommon/ChatSession.swift` (end of file, `// MARK: - EPISTEMOS OVERLAY`):
  adds public `ChatSession.extractKVCache()` + `injectKVCache(_:)` — ports Epistemos's SSM
  session-resume hardening onto the vmlx engine (must live in that file for `private cache` access).

## Status
project.yml swapped (both targets → vmlx-swift + MLXHuggingFace for `#huggingFaceTokenizerLoader()`);
KV-cache reconciliation complete (switch cases, kvScheme drop, loadContainer local-dir overload,
extract/inject overlay); build verification in progress.
