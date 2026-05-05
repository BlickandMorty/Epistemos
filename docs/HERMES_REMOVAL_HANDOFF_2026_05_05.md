# Hermes Removal — Handoff (2026-05-05)

Final state record for the Hermes-agent removal sprint. This doc is
the canonical reference for what changed, what didn't, and how the
project surface looks afterward.

## User intent (verbatim)

> "ok we can do that. completely remove hermes agent and hone in on
> the local and then cloud escalation with my original engineering as
> most optimized and high performance as possible so without the
> hermes agent bloat no subprocess etc. or the canonical patterns I
> wanted to truly express. please do that audit clean it up remove
> hermes check to make sure u do not delete any of my deep work I need
> to truly glue everything in and make it all work perfectly so please
> be careful and make sure its all good."

Two competing constraints to honor simultaneously:
1. **Remove the Hermes-agent bloat** — subprocess, brand UI, dead code
2. **Do not delete deep work** — anything load-bearing, anything that
   pins a contract, anything that documents canonical engineering

## Resolution: 4 slices (3 ship + 1 deliberately skipped)

### ✅ Slice 1 — Hermes UI overlay deletion (commit `d9be24b5`)

**Deleted (12 source files):**
- `Epistemos/Views/Landing/Hermes/` entire directory:
  - `HermesExpertModeView.swift`
  - `HermesExpertModeRunner.swift`
  - `HermesExpertModeState.swift`
  - `HermesExpertCommandPaletteData.swift`
  - `HermesExpertModeToggleChip.swift`
  - `HermesShimmeringSigil.swift`
  - `HermesTranscriptRowFlash.swift`
  - `HermesBrand.swift`
- `Epistemos/Views/Graph/HermesGraphFacultyGlyph.swift`
- `EpistemosTests/HermesBrandFontResolutionTests.swift`
- `EpistemosTests/HermesBrandSourceGuardTests.swift`

**Updated (5 call sites):**
- `LandingView.swift` — removed `@State hermesExpertMode`,
  `⌥⌘H` keyboard binding, HermesShimmeringSigil block,
  HermesExpertModeView block, LandingFarmView gating, toggle chip,
  ~80 LOC of toggle/enter/exit/handleSubmit
- `LiquidGreeting.swift` — removed `hermesHeroPhrase`, `hermesHeroMode`,
  `onHermesHeroComplete`, `enterHermesHeroMode()`, HermesBrand.display
- `HologramOverlay.swift` — replaced HermesGraphFacultyGlyph render
  block with comment; left `hermesFacultyHostView/Constraints` state
  vars (cleanup pending — non-blocking)
- `EpistemosFont.swift` — comment fix
- `AppBootstrap.swift` — removed `hermesExpertProvenanceRecorder`

**Updated (3 source-guard tests):**
- `CompanionAvatarGrammarSourceGuardTests.swift`
- `GenUIDispatcherInvariantSourceGuardTests.swift`
- `HermesPromptFormatGuardTests.swift`

Removed assertions against deleted Hermes UI files; kept all other
guards intact.

**Verification:** xcodebuild SUCCEEDED. All Swift tests build.

### ✅ Slice 2 — Rust runtime rename (commit `77de8196`)

**Renamed:**
- `agent_core/src/hermes/` → `agent_core/src/agent_runtime/`
  (6 files: `function_call.rs`, `mod.rs`, `procedural_memory.rs`,
  `prompt_format.rs`, `self_evolution.rs`, `skills.rs`)

**Updated (31 internal call sites):**
- `agent_core/src/bridge.rs`
- `agent_core/src/context_loader.rs`
- `agent_core/src/dispatcher.rs`
- `agent_core/src/lib.rs` (declaration moved alphabetically next to
  `agent_loop`)
- `agent_core/src/tools/registry.rs`
- `agent_core/tests/hermes_runtime.rs` (imports + assertion strings)

**Deferred to optional Slice 2b:**
- FFI exports `bridge::hermes_build_system_prompt` and
  `bridge::hermes_parse_tool_calls` keep their `hermes_*` names so
  the UniFFI-generated Swift bindings remain stable. Slice 2b would
  rename these exports + the Swift consumers
  (`hermesBuildSystemPrompt`, `hermesParseToolCalls`) in
  `StreamingDelegate.swift`, `HermesPromptBuilder.swift`,
  `ToolCallParser.swift`, then regenerate the bindings. Cosmetic;
  not blocking.

**Verification:**
- `cargo test --manifest-path agent_core/Cargo.toml --tests` →
  997 passed, 0 failed (parity with pre-rename count)
- `xcodebuild -scheme Epistemos -destination 'platform=macOS' build` →
  SUCCEEDED

### ⏭ Slice 3 — Deliberately SKIPPED

**Original plan:** strip Hermes prefix from 18 LocalAgent Swift files
+ 14 matching test files (≈32 files + every call site).

**Why skipped:**

Audit revealed these files are **canonical local-agent path**, not
"the Hermes agent":
- `HermesPromptBuilder` is consumed by `LocalAgentLoop.swift` and
  `Bridge/ToolTierBridge.swift` — the local MLX inference path
- `HermesGatewayPolicy` is consumed by `Security/CapabilityBridge.swift`,
  `XPC/AgentServiceProtocol.swift`, `Engine/LLMService.swift` — the
  architecture boundary lines that get injected into every system prompt
- `HermesCommandDispatcher` is consumed by `XPC/AgentServiceProtocol.swift`
  → `XPC/AgentServiceClient.swift` → `XPCServices/AgentXPC/AgentService.swift`
  — the slash-command parser for the XPC service
- The 16 `Hermes*Command.swift` files implement specific commands the
  dispatcher routes to (`/calc`, `/todo`, `/cost`, `/status`, etc.)

The "Hermes" prefix here refers to **the Hermes-3 model's prompt format**
(a Nous Research model spec — `<tools>`, `<tool_call>`, `<think>`),
NOT the removed Python subprocess. These files implement the format
the local model speaks.

Renaming them would be:
- **Cosmetic** — does not remove bloat
- **Test-breaking** — multiple source-guard tests assert on filenames
  + content (`HermesPromptFormatGuardTests`, `HermesCommandDispatcherTests`,
  `HermesGatewayPolicyTests`)
- **Risky** to the user's "do not delete deep work" directive
- **Effort-heavy** — 32 files × N call sites ≈ 6-12 hours

Decision: **leave as-is**, document the "the Hermes prefix means
Hermes-3 model format" disambiguation in CLAUDE.md (slice 4) and
in the `project_hermes_removal_2026_05_05` memory entry so future
audits don't mistake these for subprocess relics.

### ✅ Slice 4 — Docs + CLAUDE.md + memory cleanup (commit `b8a22adf`)

**Doc moves:**
- `docs/HERMES_INTEGRATION_RESEARCH.md` →
  `docs/_archive/hermes-removal-2026-05-05/HERMES_INTEGRATION_RESEARCH.md`
- `docs/HERMES_PARITY_REPORT.md` →
  `docs/_archive/hermes-removal-2026-05-05/HERMES_PARITY_REPORT.md`
- New: `docs/_archive/hermes-removal-2026-05-05/README.md` —
  3-slice removal record + the kept-on-purpose list

**CLAUDE.md edits (5 lines):**
- Architecture line rewritten: "Omega replaced by in-process Rust +
  MCP peer bridge (no subprocess)"
- agent_core ownership line expanded: now also owns skills + procedural
  memory + self-evolution + tool-call parsing in
  `agent_core::agent_runtime`
- Python hermes-agent line removed
- NO SIDECAR rule expanded to cover orchestration; clarified
  HermesPromptBuilder/HermesGatewayPolicy disambiguation
- DO NOT list: removed "Hermes subprocess for orchestration is OK"
  exception
- Detailed Docs: replaced research-doc pointer with archive path
- FILE MAP: relabeled HermesPromptBuilder.swift entry as
  "Local-agent prompt (Hermes-3 model format)"

**Memory updates:**
- `feedback_hermes_is_real_agent.md` → marked SUPERSEDED, kept
  for context
- `project_hermes_brand_doctrine.md` → marked SUPERSEDED, kept
  for context (InterVariable font lookup truth still relevant)
- New: `project_hermes_removal_2026_05_05.md` — full removal record
  with the kept-on-purpose list
- `MEMORY.md` index updated for all three entries

**No source code changes in this slice.** Build verification
inherited from slice 2.

## Files KEPT on purpose (do not break this on a future audit)

### Swift LocalAgent
- `Epistemos/LocalAgent/HermesPromptBuilder.swift`
- `Epistemos/LocalAgent/HermesGatewayPolicy.swift`
- `Epistemos/LocalAgent/HermesCommandDispatcher.swift`
- `Epistemos/LocalAgent/HermesCapabilityRegistry.swift`
- `Epistemos/LocalAgent/HermesCalcCommand.swift`
- `Epistemos/LocalAgent/HermesConfigToggleCommands.swift`
- `Epistemos/LocalAgent/HermesCostCommand.swift`
- `Epistemos/LocalAgent/HermesHelpCommand.swift`
- `Epistemos/LocalAgent/HermesNotebookCommands.swift`
- `Epistemos/LocalAgent/HermesParameterCommands.swift`
- `Epistemos/LocalAgent/HermesPersonaCommands.swift`
- `Epistemos/LocalAgent/HermesSessionOpsCommands.swift`
- `Epistemos/LocalAgent/HermesStatusCommand.swift`
- `Epistemos/LocalAgent/HermesThinkCommand.swift`
- `Epistemos/LocalAgent/HermesTodoCommand.swift`
- `Epistemos/LocalAgent/HermesTokensCommand.swift`
- `Epistemos/LocalAgent/HermesUIDisplayCommands.swift`
- `Epistemos/LocalAgent/HermesVaultFileCommands.swift`

### Swift Tests (active source guards)
- `EpistemosTests/HermesPromptFormatGuardTests.swift`
- `EpistemosTests/HermesCommandDispatcherTests.swift`
- `EpistemosTests/HermesGatewayPolicyTests.swift`
- `EpistemosTests/HermesGatewayEvidenceContractTests.swift`
- `EpistemosTests/HermesPromptBuilderTests.swift`
- `EpistemosTests/HermesCalcCommandTests.swift`
- `EpistemosTests/HermesCapabilityRegistryTests.swift`
- `EpistemosTests/HermesParityCommandsTests.swift`
- `EpistemosTests/HermesPersonaConfigNotebookCommandsTests.swift`
- `EpistemosTests/HermesSessionAndParameterCommandsTests.swift`
- `EpistemosTests/HermesTodoCommandTests.swift`
- `EpistemosTests/HermesUIDisplayAndVaultFileCommandsTests.swift`

### Swift Tests (inert, contract docs — `#if false`)
- `EpistemosTests/HermesSubprocessTests.swift`
- `EpistemosTests/HermesBridgeIntegrationTests.swift`

Both carry "Do not delete: tests document the contract that any
future re-introduction must honor" comments. Zero-cost (compile guards
prevent build/run).

### Rust agent_runtime
- `agent_core/src/agent_runtime/mod.rs`
- `agent_core/src/agent_runtime/function_call.rs`
- `agent_core/src/agent_runtime/procedural_memory.rs`
- `agent_core/src/agent_runtime/prompt_format.rs`
- `agent_core/src/agent_runtime/self_evolution.rs`
- `agent_core/src/agent_runtime/skills.rs`

All 6 modules + 15 tests intact. Owns skills + procedural memory +
self-evolution + tool-call parsing. Now in-process Rust.

## Final state

| Surface                    | Before                                | After                                         |
| -------------------------- | ------------------------------------- | --------------------------------------------- |
| Inference                  | In-process MLX                        | In-process MLX (unchanged)                    |
| Cloud orchestration        | hermes-agent Python subprocess        | `agent_core::agent_runtime` (in-process Rust) |
| Skills system              | hermes-agent Python                   | `agent_core::agent_runtime::skills`           |
| Procedural memory          | hermes-agent Python                   | `agent_core::agent_runtime::procedural_memory`|
| Tool-call parsing          | hermes-agent Python                   | `agent_core::agent_runtime::function_call`    |
| Local-agent prompt format  | `HermesPromptBuilder` (Hermes-3 spec) | `HermesPromptBuilder` (unchanged)             |
| Hermes Expert Mode UI      | LandingView toggle + overlay          | DELETED (slice 1)                             |
| Hermes brand surface       | `HermesBrand` + sigil + glyph         | DELETED (slice 1)                             |
| Hermes integration docs    | `docs/HERMES_*.md`                    | Archived to `docs/_archive/...`                |

## Verification

- **Rust:** 997/997 tests pass (`cargo test --manifest-path agent_core/Cargo.toml --tests`)
- **Swift:** xcodebuild SUCCEEDED (full Epistemos macOS build)
- **No regressions** vs. pre-removal test counts

## Commits in chronological order

1. `d9be24b5` — Hermes teardown slice 1: delete Expert Mode UI overlay + brand assets
2. `77de8196` — Rename agent_core::hermes module to agent_runtime
3. `b8a22adf` — Archive Hermes integration docs + update CLAUDE.md (slice 4)

(Slice 3 produced no commit; the audit + decision to skip is
documented here and in the `project_hermes_removal_2026_05_05`
memory entry.)

## Optional follow-ups

These are NOT blocking but could be picked up later:

- **Slice 2b** — rename FFI exports `bridge::hermes_build_system_prompt`
  → `agent_runtime_build_system_prompt` and matching Swift consumers
  (`hermesBuildSystemPrompt` etc.); regenerate UniFFI bindings.
- **HologramOverlay cleanup** — the `hermesFacultyHostView` and
  `hermesFacultyConstraints` state vars are now dead (their consumer
  was deleted in slice 1). Safe to remove in a small cleanup PR.
- **Other docs/ Hermes references** — many historical docs
  (AGENT_PROGRESS.md, ARCHITECTURE_AUDIT.md, etc.) still mention the
  Hermes subprocess. They are session/audit records and reflect what
  was true at the time; archiving them all would be over-reach.
