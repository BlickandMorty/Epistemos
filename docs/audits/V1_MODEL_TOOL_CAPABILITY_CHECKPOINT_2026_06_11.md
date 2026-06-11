# V1 Model, Tool, Skill, and Vault Capability Checkpoint - 2026-06-11

Status: scoped v1 hardening checkpoint, not a full architecture resume and not a final release verdict.

Current HEAD observed during checkpoint: `438e78bd1d`.

## Scope

This checkpoint covers the app-facing chat capability layer:

- MiniChat and chat tool-call grammar/parser behavior.
- Skill discovery and packaged skill availability.
- Tool catalog integrity and duplicate-surface controls.
- Vault recall and app-side storage/search wiring.
- RuntimeRouter, System G seam, Qwen local path, GGUF lane, and Gemma gated handoff.

It intentionally does not resume broad Helios/System G architecture construction.

## Fixes Landed In This Pass

### Skills

- `SkillDiscoveryCatalog` now treats packaged `SourceMirror/.agents/skills` as bundled app skills when `DefaultSkills` is present.
- Duplicate skill identifiers are collapsed deterministically, with bundled skills preferred over user/Codex skills.
- The app runtime asset bundler now copies `.agents/skills/**/SKILL.md` into `Contents/Resources/DefaultSkills`.

Runtime evidence from built app startup:

- `Skill catalog refreshed: 7 skills`
- `Tool catalog refreshed: 56 tools, 0 executions`

Built app payload includes these seven packaged skills:

- `note-create`
- `note-read`
- `note-write`
- `note-delete`
- `epistemos_release_audit`
- `recursive_app_audit`
- `graph_physics_audit`

### Vault Recall

- `VaultRecallBridge` now supports an installed real trace provider.
- `VaultSyncService` installs a provider backed by `SearchIndexService` when the search index is active and clears it when the vault stops watching.
- `VaultRecallBridge.trace(query:)` now prefers the real provider and falls back to the scaffold only when no provider exists or the provider returns nil.
- `SearchIndexService` trace-only query normalization strips boilerplate and avoids treating chatter-only text as meaningful vault recall.

Proof target:

- Real provider traces report `vault-search-index-v1` / `.real`.
- Stub fallback remains explicit and testable.

### Models And Runtime

- `ProviderPolicy.local_gguf(model_id)` is now represented in the Rust AgentRuntimeV2 blueprint.
- System G runtime validates the GGUF model id and emits `local_model_handoff`.
- `RealSystemGRunSeam` maps local GGUF model ids to the `local_gguf` provider policy.
- Gemma QAT GGUF is a gated local handoff, not a default app model and not a live T4/product claim.

Observed app startup truth:

- Selected local agent model remains `Qwen 3 8B`.
- Gemma stays out of default promotion until the product route gate is satisfied.

## Verification Run

### Rust

- `cargo test --manifest-path agent_core/Cargo.toml tools --lib --quiet`
  - 331 passed.
- `cargo test --manifest-path agent_core/Cargo.toml skill --lib --quiet`
  - 53 passed.

### Swift/Xcode Focused Suites

- `EpistemosTests/VaultRecallWiringTests`
  - 10 tests passed.
- `EpistemosTests/ControlPlaneSurfaceTests`
  - 25 tests passed.
- `EpistemosTests/ReleaseScriptAuditTests` plus `EpistemosTests/ControlPlaneSurfaceTests`
  - 52 tests passed.
- `EpistemosTests/ReleasePackagingHardeningTests`
  - 20 tests passed.
- Focused MiniChat/tool/vault surface:
  - `OmegaToolSchemaGrammarTests`
  - `MCPExecutionTruthGuardTests`
  - `ToolSurfacePolicyTests`
  - `ToolSurfaceBehavioralMatrixTests`
  - `ToolTierCrossRuntimeParityTests`
  - `ResourceRuntimeToolPathE2ETests`
  - `MiniChatViewAuditTests`
  - `AgentCommandCenterStateTests`
  - 101 tests passed.
- Corrected tool grammar/parser run:
  - `ToolSchemaGrammarTests`
  - `LocalToolGrammarTests`
  - `ToolCallParserTests`
  - `IncrementalToolCallDetectorTests`
  - 68 tests passed.
- Model/runtime route run:
  - `SystemGRunSeamTests`
  - `LocalGGUFClientTests`
  - `LocalBackendLLMClientTests`
  - `RuntimeRouterTests`
  - `LocalAgentLoopTests`
  - `LocalModelReleaseSweepTests`
  - `UserFacingModelOutputTests`
  - `LocalModelInfrastructureTests`
  - 208 tests passed.

### App Logs Observed During Tests

- `System G run seam: local model dispatch registered`
- `Skill catalog refreshed: 7 skills`
- `Brain catalog refreshed: 1 brains`
- `Local agent model selected: Qwen 3 8B`
- `Local model gating probe: strict-tool-grammar=ACTIVE, soft-guidance=ON, local-agent-loop=OK`
- `Tool catalog refreshed: 56 tools, 0 executions`

## Important Non-Claims

- Gemma is not live, not default, not quality-proven, not T4, and not user-facing as the main chat model.
- The current v1 usable local model path remains the Qwen/local route.
- GGUF is present as a lane and System G handoff shape, but route admission still needs owner-approved local model bytes, receipt, same-fixture replay, RuntimeRouter/System G dry-run admission, AnswerPacket, RunEventLog, rollback, and product-capability recheck before any promotion.
- This checkpoint does not claim full direct-release readiness or Mac App Store readiness.
- This checkpoint does not cover manual UI/runtime release audit, notarization, privacy metadata, or three zero-fail release passes.

## Next Safest Task

Do not resume broad architecture first.

The next safest v1 task is:

1. Finish any remaining app-facing tool capability audit around real manual MiniChat interactions.
2. Run one disposable-vault manual pass: create note, search vault, ask MiniChat to use a vault/search/file tool, verify logs and visible result.
3. If Gemma is still desired for v1 visibility, add only honest gated visibility: no default mutation, no route mutation, no quality claim.
4. Only after v1 capability proof is stable, create a larger architecture continuation checkpoint.
