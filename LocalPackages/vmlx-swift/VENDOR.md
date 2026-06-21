# Vendored: osaurus-ai/vmlx-swift (the consolidated MLX stack for the full-Osaurus link)

Take-control vendor (`.git` stripped) of Osaurus's consolidated MLX fork — the package
OsaurusCore depends on. Vendored here so Epistemos can **consolidate onto ONE MLX** and link
OsaurusCore without the dual-MLX module clash (see
`docs/research/OSAURUS_MAS_ENTITLEMENTS_RESEARCH_2026_06_21.md`).

| Field | Value |
|-------|-------|
| Upstream | https://github.com/osaurus-ai/vmlx-swift |
| Pinned revision | `4453909ef453f9235fd7e65986ca3ffc62ff904d` (the revision OsaurusCore's Package.swift pins) |
| Clone date | 2026-06-21 |
| License | **MIT** |
| ProvenanceGate | `direct_import` |

## Why this replaces `mlx-swift-lm` + `ml-explore/mlx-swift`
`vmlx-swift` is a single consolidated package that provides the SAME module names Epistemos
already imports — `MLX`, `MLXNN`, `MLXOptimizers`, `MLXRandom`, `MLXFast`, `MLXLLM`, `MLXLMCommon`,
`MLXVLM`, `MLXEmbedders` — PLUS Osaurus-prefixed `VMLXTokenizers`/`VMLXJinja`/`VMLXHub`/etc.
(renamed to avoid a swift-transformers collision). Because the `MLX*` module names match, Epistemos's
8 MLX-importing files map 1:1 with only two friction points (below). Two packages can't BOTH define
`MLX*` in one binary — so consolidating onto vmlx-swift removes the clash AND keeps Osaurus's own MLX
stack (osaurus-ness intact).

## Status
Vendored on disk only — **NOT yet wired into project.yml.** The package-swap + the two import fixups
(below) are the next slice, done with build verification.

## The only two import-site friction points (Epistemos side, 8 files total)
1. `import Tokenizers` (1 file) → `import VMLXTokenizers` (vmlx renamed it). Check API namespace.
2. `import MLXStructured` (1 file) → already `#if canImport(MLXStructured)` guarded; if its package
   (petrukha-ivan/mlx-swift-structured, built vs ml-explore MLXLMCommon) is dropped, the guard compiles
   it out cleanly. Re-point or drop deliberately.
All other imports (`MLX`, `MLXNN`, `MLXOptimizers`, `MLXLLM`, `MLXLMCommon`, `MLXVLM`) are unchanged.
