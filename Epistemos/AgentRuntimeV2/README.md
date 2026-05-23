# Epistemos/AgentRuntimeV2/ — Swift bridge to Agent Runtime v2 (System G / Invader Agent)

**Status:** scaffold-only (`not-implemented` per the doctrine's WRV rubric).

This directory will host the Swift-side bridge to the Rust
`agent_core::agent_runtime_v2::` namespace once the bridge surfaces
are wired. The directory exists now so the namespace is reserved and
future commits don't have to fight ownership.

Until the bridge lands:

- **No `.swift` files** live here yet. Adding `.swift` files implies an
  Xcode project membership update + an `xcodebuild` verification cycle,
  which the T11 disk-pressure guard forbids in a Rust/docs-only
  iteration.
- The Rust surfaces the bridge will consume are already typed and
  serde-stable (see `agent_core/src/agent_runtime_v2/`). When the
  bridge lands it will mirror the same shape:
  - `AgentBlueprint` + `MissionPacket` → SwiftData / `@Observable`
  - `AgentEvent` stream → `AsyncStream<AgentEvent>` via UniFFI
  - `MutationEnvelope` + `Sealer` → main-actor write coordinator
  - `RunEventLog` + `AnswerPacket` → `AgentRunTimelineView`
- Mode gate: the Swift dispatcher MUST observe
  `AgentRuntimeV2Mode::Disabled` in the MAS bundle (build-time gate),
  and MUST call `AgentBlueprint::check_against_mode` before invoking
  any executor (so `mas_cannot_call_cli` holds end-to-end).
- Naming: the user-visible name is **System G** / **Invader Agent**.
  Aegis is REJECTED — see `docs/AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md` §4.

Doctrine cross-references:

- §2 Para morphism
- §4 Naming distinction from Hermes / Aegis
- §4.1 Aegis-name CI lint sketch
- §7 Cross-terminal wiring relationships (W-14 / W-15 / W-16)

Created 2026-05-18 (T11 iter-10).
