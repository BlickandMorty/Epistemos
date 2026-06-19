# ENGINE-ISOLATION DOCTRINE — code-grounded plan (S17, 2026-06-19)

Read-only research (subagent). Feeds DEEP_PLAN_AUDIT_HUB. The owner's MOST-IMPORTANT constraint:
engines (Chat/Act/Work + the 2 Act lanes) must NOT cross-muddy in code/logic; connect ONLY via
shared MEMORY + CAPABILITY-AWARENESS (Act ⊇ Chat via its OWN registration, not by calling Chat's code).

## Verdict up front
**The doctrine is already largely satisfied by good layering — the hard clause (no cross-engine import) is TRUE today.** Gaps: (a) the 3-engine axis is unmodeled (only `.chat`/`.act`), (b) the two shared seams aren't fully typed/wired (sessions carry no engine tag; `<vault>/sessions/` isn't indexed), (c) the mandated guardrail exists only for Work, not as a general invariant.

## 1. Model the Chat/Act/Work axis (the missing primitive)
Today `CoworkChatMode` = `{chat, act}` (a presentation over `operatingMode`, NOT an engine); no `.work`, no `ActEngine` enum. `EpistemosOperatingMode {fast/thinking/pro/agent}` is the TIER axis (orthogonal — don't overload). Plan (nonisolated enums in `Engine/`): add `CoworkChatMode.work` (thin presentation, no engine imports) + `ActLane{openClaw, osaurusLocal}` (the 2-lane picker — the Hermes-fused LocalAgent brain lives INSIDE `.osaurusLocal`, NOT a 3rd case). Axis is 2-D: `(engine, lane?)`, lane non-nil only when engine==.act. **Keep engine/lane selection OUT of `InferenceState`/`ChatCoordinator`** — it's presentation/coordinator (RootView) state; `ChatCoordinator` (243KB) currently has ZERO refs to CoworkChatMode/ActOsaurus/WorkBackend (its routing is `OverseerExecutionRoute` at `:2125-2216`) — KEEP it that way; Act-Osaurus + Work get their OWN coordinators.

## 2. The isolation boundary in code
**Module-direction rule:** Chat runtime (`ChatCoordinator`), Act-Osaurus (`ActOsaurus/*`), Work (`WorkBackend.swift`) must not name each other's RUNTIME types; only the shared VALUE `EpistemosOperatingMode.agent` + the shared registries/memory cross.
**Already respects it (the model):** `WorkBackend.swift:9` ("ISOLATED — touches NOTHING in Chat/Act"; imports only Foundation); `ActOsaurusBridge` talks to Osaurus only over loopback HTTP, never imports Chat; `#if !EPISTEMOS_APP_STORE` + InertBridge (isLive=false, throws rather than cloud-fallback) = the MAS-honesty firewall; **ChatCoordinator never imports Act/Work (0 grep hits) — the highest-blast-radius file is already clean.**
**Risks:** convergence creep (don't add Work/lane logic to InferenceState — entangles all 3 through the one clean file); Swift↔Rust capability table drift (`ToolTierBridge` aliases/allowlist duplicate `registry.rs`); a future "convenience" delegate from Act into ChatCoordinator's tool path = the classic violation (forbidden).

## 3. The two sanctioned shared seams
**Seam A — capability/tool registry (Act⊇Chat by construction):** ONE canonical definition `register_default_tools` (`registry.rs:923`); each engine binds its OWN `ToolRegistry::with_tier(...)` (no shared singleton — chat `bridge.rs:3155/3219`, agent `:978/1184`, command-center, delegation `:668`). **Capability is shared because the DEFINITION is shared; invocation is each engine's own instance** = exactly the doctrine. Superset enforced by the ORDERED tier ladder `ToolTier{None,ChatLite,ChatPro,Agent,Full}` (`:241`) + `is_tool_permitted` (`:699`): Agent ⊇ ChatLite/ChatPro by construction = Act⊇Chat WITHOUT Act calling Chat. `LocalAgentCapabilityRegistry.swift:55` is the awareness layer (advertises capability, doesn't execute).
**Seam B — memory substrate (read-flavored awareness):** sessions are engine-AGNOSTIC peers — `SessionRegistry`/`SessionHandle` (`session.rs:241/245`) have NO engine/kind field (keyed by opaque id); provenance `ClaimLedger` + cognitive DAG are process-shared, engine-agnostic. **GAP:** search indexes only pages/blocks (`SearchIndexService:347/360`, `fusedSearch:902`); the shadow crawl covers `notes/**`+`chats/**` but **NOT `<vault>/sessions/` (OQ-1)** — so session content is on disk but invisible to search; an Act session can't yet "know about" a Chat session. PLAN: (a) add an optional engine/kind tag to `SessionHandle`/`SessionFolder` (typed awareness, still read-only); (b) enroll `sessions/` in the shadow crawl (or reconcile to `chats/`).

## 4. The guardrail test (owner-mandated)
A prototype EXISTS for Work — `WorkBackendSeamTests.swift:38-50` asserts `WorkBackend.swift` doesn't contain `CoworkChatMode`/`ChatCoordinator` + flag parity (`:57-77`). **Generalize to `EngineIsolationDoctrineTests`:** (1) source-text guard over the matrix {Chat,Act,Work,lanes} — each runtime file must not name another engine's runtime types (lock today's 0-refs as an invariant); (2) capability flows only through the shared registry — assert each engine binds its own `with_tier`, + Swift↔Rust alias/allowlist parity (kills the drift seam); (3) memory substrate has no engine-runtime coupling. **Promote to CI lint:** extend the existing `agent_core/src/bin/epistemos_doctrine_lint.rs` (its `check_gate_5_4:353-407` already walks Swift files + flags forbidden cross-layer refs, exit-3, CI-enforced) with an engine-isolation gate.

## 5. MiniChat + session-as-native-tab compose with isolation
MiniChat=MainChat is ALREADY parity-by-construction (both derive from the shared `MainChatOperatingModePreference.supportedModes`; the 2026-06-18 fix removed Mini's narrower set so they can't drift; parity tests fail on drift). Compose rule: the new engine/lane axis must be a SINGLE shared source both surfaces render + extend the parity test. Session-as-native-tab does NOT exist yet (native tabbing wired only for Notes/Epdoc/HTML docs + the Mini window, not sessions); build it on the proven `tabbingIdentifier` pattern uniform across engines/lanes — this REINFORCES isolation (each session = isolated context + isolated tab; engines connect only via the shared memory seam).

## 6. Ordered plan (each independently shippable, flag-gated, zero-regression)
1. Land the axis primitive (`CoworkChatMode.work` + `ActLane`), selection as presentation state NOT in InferenceState/ChatCoordinator.
2. Generalize the guardrail → `EngineIsolationDoctrineTests` + add the engine-isolation gate to `epistemos_doctrine_lint` (CI) — do 2nd so every later step is fenced.
3. Capability parity lock (Swift↔Rust alias/allowlist; assert Act binds its own with_tier).
4. MiniChat parity extension (single shared engine/lane source).
5. Memory seam wiring (engine tag on SessionHandle + enroll sessions/ in shadow crawl — resolves OQ-1).
6. Session-as-native-tab on the tabbingIdentifier pattern.
7. Arm engines (Pro, flag-gated) only after 1-6, lint enforcing no cross-engine import per commit.

**Net:** the hardest clause is already true; the work is to model the missing axis without re-coupling, type+wire the two seams (registry already correct; memory designed-but-unwired), and promote the one-off Work guardrail into a general CI-enforced invariant.

Key files: `Engine/CoworkChatMode.swift` · `App/ChatCoordinator.swift:2125` · `State/InferenceState.swift:{423,1347,2774,4972}` · `ActOsaurus/ActOsaurusBridge.swift` · `Work/WorkBackend.swift:9` · `agent_core/src/tools/registry.rs:{241,349,548,699,923}` · `Bridge/ToolTierBridge.swift:{351,361}` · `LocalAgent/LocalAgentCapabilityRegistry.swift:55` · `agent_core/src/session.rs:{10,241,245}` · `provenance/ledger.rs:443` · `Sync/SearchIndexService.swift:{347,902}` · `Engine/ShadowVaultBootstrapper.swift:{49,113}` · `Views/MiniChat/MiniChatView.swift:{667,675}` · `EpistemosTests/WorkBackendSeamTests.swift:38-77` · `agent_core/src/bin/epistemos_doctrine_lint.rs:353-407`.
