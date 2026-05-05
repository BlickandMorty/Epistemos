# Hermes Removal Archive — 2026-05-05

These documents describe the (now removed) Hermes Agent integration —
the Python `hermes-agent` subprocess that was planned to own cloud API
orchestration, the skills system, procedural memory, and multi-step
planning out-of-process.

## Why this was removed

User decision 2026-05-05: pivot to local-first canon with cloud
escalation only when needed. The subprocess + brand bloat was traded
for the original engineering — direct in-process Rust + MLX + Swift
with no hot-path subprocess.

Direct quote from the user:

> "completely remove hermes agent and hone in on the local and then
> cloud escalation with my original engineering as most optimized and
> high performance as possible so without the hermes agent bloat no
> subprocess etc. or the canonical patterns I wanted to truly express."

## What was removed (in code)

Slice 1 (UI overlay) — committed before slice 2:
- `Epistemos/Views/Landing/Hermes/` (8 files: HermesExpertModeView,
  HermesExpertModeRunner, HermesExpertModeState, HermesExpertCommandPaletteData,
  HermesExpertModeToggleChip, HermesShimmeringSigil, HermesTranscriptRowFlash,
  HermesBrand)
- `Epistemos/Views/Graph/HermesGraphFacultyGlyph.swift`
- `EpistemosTests/HermesBrandFontResolutionTests.swift`,
  `HermesBrandSourceGuardTests.swift`
- LandingView, LiquidGreeting, HologramOverlay, AppBootstrap, EpistemosFont,
  and 3 source-guard tests updated to drop the dead references.

Slice 2 (Rust module rename, commit `77de8196`):
- `git mv agent_core/src/hermes/ agent_core/src/agent_runtime/`
- 31 internal call sites updated.
- FFI exports (`bridge::hermes_build_system_prompt`,
  `bridge::hermes_parse_tool_calls`) keep their `hermes_*` names for
  now so the UniFFI Swift bindings stay stable; an optional Slice 2b
  can rename them later if you want to drop the brand from the FFI
  surface as well.

## What was NOT removed (and why)

The following are NOT "the Hermes agent" — they are the canonical
local-first agent path that uses the Hermes-3 model's prompt format
(a Nous Research model spec, not a brand name in this context):

- `Epistemos/LocalAgent/HermesPromptBuilder.swift` — local agent prompt
  builder. Used by `LocalAgentLoop`, `ToolTierBridge`. Canonical.
- `Epistemos/LocalAgent/HermesGatewayPolicy.swift` — gateway boundary
  policy lines. Used by `CapabilityBridge`, `LLMService`,
  `XPC/AgentServiceProtocol`. Canonical architecture surface.
- `Epistemos/LocalAgent/HermesCommandDispatcher.swift` + 16
  `Hermes*Command.swift` files — slash-command dispatcher wired through
  the XPC `AgentServiceProtocol` consumed by `AgentServiceClient`.
  Renaming these would be cosmetic and would break the source-guard
  tests in `EpistemosTests/HermesPromptFormatGuardTests.swift` and
  `HermesGatewayPolicyTests.swift` etc.

The two inert subprocess test files are also deliberately retained:
- `EpistemosTests/HermesSubprocessTests.swift` (`#if false`)
- `EpistemosTests/HermesBridgeIntegrationTests.swift` (`#if false`)

Both carry explicit "Do not delete: the tests document the contract
that any future re-introduction must honor" comments. They are
zero-cost (compile guards prevent build/run) and respect the user's
"do not delete any of my deep work" directive.

## Files in this archive

- `HERMES_INTEGRATION_RESEARCH.md` — original integration research
- `HERMES_PARITY_REPORT.md` — parity-with-Python-subprocess report

If a future iteration ever resurrects the subprocess approach, start
here.
