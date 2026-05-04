# Local Canon First Specificity Protocol — 2026-05-04

## Purpose

This protocol prevents concrete user/research intent from being compressed away
by high-level doctrine labels. Every phase, wave, slice, refactor, delete,
reroute, simplification, or "small" edit must research local canon first,
recover concrete specifics, verify current code, and only then browse the web if
current external facts matter.

The rule is simple:

> A compressed plan label is never enough. If the user's research says what the
> thing should look like, feel like, route through, or prove, the brief must
> carry that detail into implementation.

## Mandatory Source Order

1. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
2. The canonical source named by the master index for the concept.
3. `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md`
4. `docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md`
5. `docs/fusion/CODEX_AGENT_FLEET_PROMPT_2026_05_02.md`
6. Current code/logs for the feature.
7. Related local research roots:
   - `/Users/jojo/Documents/Epistemos-QuickCapture/`
   - `/Users/jojo/Downloads/kimis deep research/`
   - `/Users/jojo/Downloads/GPT Research/`
   - `/Users/jojo/Downloads/GPT research/`
   - `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/`
   - `/Users/jojo/Downloads/jordan's research/`
   - `/Users/jojo/Downloads/latest research/`
   - `/Users/jojo/Downloads/old research/`
   - `/Users/jojo/Downloads/mass research folder/`
8. Targeted web validation only when the task depends on current API, OS,
   package, App Store, security, framework, or model behavior.

## Mandatory Search Pattern

For every slice:

1. Search the exact user phrase.
2. Search semantic siblings and compressed-doctrine terms.
3. Search likely code symbol names.
4. Search donor/research roots for the same concept.
5. Verify current code truth with `rg`/file reads.
6. If code and canon differ, stage a canon gap before coding or cite the
   already-open gap.

Use `rg` first. Keep the search useful: stop once the slice has enough evidence
to act safely, but do not skip concrete product details because the doctrine is
more abstract.

## Specificity Locks

### T5 — Hermes Expert Mode / Hermes Gateway

Search terms:

`Hermes`, `Hermes Agent`, `slash commands`, `slash command reference`,
`Expert Mode`, `cloud gateway`, `MCP`, `tool catalog`, `caduceus`, `parity`,
`/help`, `/status`, `/model`, `/persona`, `/tools`, `/mcp`, `/web search`,
`/calc`, `HermesCommandDispatcher`, `ProviderXPC`, `AgentXPC`.

Concrete intent to preserve:

- Hermes is the unified cloud/tool gateway, not random direct provider calls.
- The app should feel unified and fast while Hermes absorbs cloud/API/tool
  churn.
- Slash-command capability must map to native Epistemos surfaces, not a fake
  terminal skin.
- Visual identity is Hermes Agent/caduceus branded, not generic SF Symbols or
  placeholder avatar art.
- Core/MAS remains sandbox-safe; Pro/Research tunnels remain gated.

### T6 — Simulation Mode v1.6 / Companion Farm

Search terms:

`Tamagotchi`, `companion`, `farm`, `Landing Farm`, `Graph Live Theater`,
`Notes Sidebar Skin`, `avatar`, `creature`, `pet`, `sprite`, `emote`,
`body grammar`, `walk`, `roam`, `wander`, `Hermes Snake`, `Character DNA`,
`CompanionView`.

Concrete intent to preserve:

- Companions are small Tamagotchi-style creatures, not SF Symbols, generic
  orbs, static cards, or abstract badges.
- Landing Farm gets deterministic idle walking/roaming.
- Graph later gets companion presence from the same registry.
- Notes Sidebar Skin remains a slimmer companion projection.
- Reduce-motion renders static pose + state badge, not hidden features.

Canonical recovery artifact:

`docs/fusion/fleet/t6-tamagotchi-body-grammar/T6_TAMAGOTCHI_BODY_GRAMMAR_RECOVERY_2026_05_04.md`

### T3 — Resonance Gate

Search terms:

`Resonance Gate`, `tau`, `τ`, `pi`, `π`, `lambda`, `λ`, `rho`, `ρ`,
`kappa`, `κ`, `eta`, `η`, `delta`, `δ`, `Knowledge Sieve`,
`Gap Winner Rule`, `Verified Research Mode`, `VRM`, `no τ=-1`.

Concrete intent to preserve:

- It is a user-visible cognitive immune system, not a generic confidence score.
- Signature fields must remain explicit and typed.
- No contradicted claim reaches the user.
- Edge claims surrender to evidence/search rather than model intuition.
- T0-T4 verification ladder must not collapse into one runtime check.

### T2/T4 — Sovereign Gate / Capability Lattice

Search terms:

`Sovereign Gate`, `Touch ID`, `biometric`, `LAContext`, `Secure Enclave`,
`capability token`, `Capability::BiometricSession`, `delete`, `restore`,
`archive`, `adapter`, `credential`, `keychain`, `permission`.

Concrete intent to preserve:

- Destructive/sensitive actions route through the canonical Sovereign Gate.
- Biometric UX is an app feature and trust primitive, not just a security
  implementation detail.
- Capability tokens are typed, scoped, expiring, and audit-emitting.
- New biometric code does not appear outside the Sovereign owner path.

### T0/T1 — Kernel / XPC / Substrate

Search terms:

`zero-copy`, `UMA`, `single-binary`, `in-process`, `deterministic`,
`XPC Mastery`, `VaultXPC`, `AgentXPC`, `ProviderXPC`, `WASMExecXPC`,
`IOSurface`, `capability-token IPC`, `App Group`, `HELIOS`, `WBO6`,
`E8`, `Sherry`, `KV direct`, `hotpath`.

Concrete intent to preserve:

- Performance is architecture: no hot-path subprocess, tensor copy, or
  multi-process inference regression.
- XPC is a defense-in-depth boundary for MAS, not an excuse to fragment the
  substrate.
- Every service boundary needs minimal entitlement, trust attestation, and
  AgentEvent audit.

### UI/UX Surfaces

Search terms:

`Landing`, `Liquid`, `Halo`, `Contextual Shadows`, `Freeform Pulse`,
`Rail`, `Graph Theater`, `GenUI`, `artifact`, `typed payload`, `Tamagotchi`,
`Companion`, `Hermes`.

Concrete intent to preserve:

- UI is not generic scaffolding. It must carry the product philosophy.
- Typed payload/GenUI surfaces should replace markdown/YAML pseudo-renderers.
- Protected graph/editor paths require dedicated deliberation.

## Brief Requirement

Every future deliberation brief must include:

- `Local search terms used: ...`
- `Concrete specifics recovered: ...`
- `Current code truth: ...`
- `Canon drift found: none | staged at <path>`
- `External validation needed: none | <official source>`

## Stop Triggers

Stop before coding when:

- A concept is not in `MASTER_RESEARCH_INDEX_2026_05_02.md`.
- Local research has concrete UX/assets/behavior that the final plan omits.
- Current code disagrees with canon in a way that changes implementation order.
- A web/API claim is needed but no primary source has been checked.
- The slice would touch protected graph/editor/security files without a
  dedicated deliberation.

## Verification Command Template

```bash
rg -n -i "<exact phrase>|<semantic sibling>|<code symbol>" docs/fusion docs "/Users/jojo/Documents/Epistemos-QuickCapture" "/Users/jojo/Downloads/kimis deep research" "/Users/jojo/Downloads/GPT Research" "/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive" "/Users/jojo/Downloads/jordan's research"
```

## Usefulness

+1 — makes the user's local research corpus operational and prevents future
agents from building flattened versions of features whose details already exist
on disk.
