# Omega Audit Insights
> Cross-session learnings from code audits. Read this before modifying Omega files.
> Last updated: 2026-03-24 (Ω10-Ω14 audit by independent auditor)

## Critical Findings

### MLXConstrainedGenerator — No-Op Wrapper (Ω11)
`MLXConstrainedGenerator.generateConstrained()` accepts a `LogitProcessor` parameter but **does not thread it** into the `TokenIterator`. Line 228 of `MLXConstrainedGenerator.swift` simply delegates to `generate(request:)`. The `JSONSchemaLogitProcessor.process()` only penalizes EOS tokens by -50 logits — no structural masking.

**To fix**: Refactor `MLXInferenceService.generate()` to accept an optional `LogitProcessor` parameter, then pass it through to `TokenIterator.init(...)`. The architecture (protocol → processor → iterator) is correct — only the binding is missing.

**Upgrade path**: `mlx-swift-structured` by @petrukha-ivan (Tier 1 full masking).

## Verified Patterns (Safe to Extend)

- **All 30 Omega Swift files** use `@MainActor @Observable` — zero `ObservableObject`
- **Zero `try!` or force unwraps** across all Omega files
- **All agents route through Rust tool layer** — no direct `osascript` calls
- **`CheckedContinuation`** used in: `ResearchPause`, `SharedGPUBackend`, `Screen2AXFusion`
- **`Duration` extensions** are file-private — no collision risk, but duplicated in 3 files (`VisualVerifyLoop`, `Screen2AXFusion`, `DeviceAgentService`)

## Wiring Reference (AppBootstrap Init Order)

New Omega services init in this order (lines 255-303 of AppBootstrap.swift):
1. `DeviceAgentService(hardwareTier:)` → 2. `DualBrainRouter` → 3. `SharedGPUBackend` → 4. `Screen2AXFusion` → 5. `VisualVerifyLoop` → 6. `registerAgents(constrainedDecoding:)` → 7. `setGenerator(MLXConstrainedGenerator)` → 8. `AgentGraphMemory` → 9. `RecipeGraphSkills` → 10. `GhostBrainCoauthor` → 11. wire `agentGraphMemory` to orchestrator

**AppEnvironment** injects (lines 33-38): `constrainedDecoding`, `hardwareTierManager`, `dualBrainRouter`, `screen2AXFusion`, `visualVerifyLoop`, `ghostBrainCoauthor`

## R4/R5 Research Results (Empirical)

- **R5**: 91% of macOS apps have FULL AX metadata. Sparse threshold set to 10 (not 5).
- **R4**: EasyOCR rejected (20s). Apple Vision OCR used instead (<200ms). YOLO viable (260ms) but rarely needed.

## Test Counts (as of Ω14 complete)

| Crate | Tests |
|-------|-------|
| omega-mcp | 89 |
| omega-ax | 10 |
| epistemos-core | 80 |
| graph-engine | 2432 (**DO NOT TOUCH**) |

## Anti-Patterns to Watch For

- Don't add new `Duration` extensions — consolidate into `Omega/Extensions/`
- `RecipeGraphSkills.listRecipesJson()` dispatches `recipes/list` via JSON-RPC — if this MCP method isn't registered, it returns `[]` gracefully (not a bug)
- `HardwareTierManager.detectTier()` classifies by memory only — chip generation (`AppleSiliconGeneration`) is detected but not used in tier classification yet
