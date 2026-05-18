# Agent Runtime v2 — System G / Invader Agent Doctrine

**Date:** 2026-05-18
**Status:** v0.1 doctrine (T11 acceptance bar, §4 of `NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md`)
**Authority:** Doctrine doc for the `agent_core::agent_runtime_v2::` namespace and the Swift `Epistemos/AgentRuntimeV2/` bridge.

> Canonical user-visible name: **System G** / **Invader Agent**.
> `Aegis` is **REJECTED** by user direction and must never appear in code, docs, prompts, comments, or UI strings.
> Neutral code namespace: `agent_runtime_v2` (Rust) and `AgentRuntimeV2` (Swift).
> Hermes subprocess remains purged. Hermes prompt-format parity may remain only as a compatibility shim under `LocalAgent/`.

---

## 0. Why this doctrine exists

Per `docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md` and §4 T11 of the endgame prompt deck, Agent Runtime v2 is the **typed, budgeted, witnessed, capability-gated executor layer** that sits above the legacy `agent_runtime::` orchestration. v2 does not replace `agent_runtime::` — it wraps it so that every executor invocation is:

- **typed** — parametric morphism `Para<P, A, B>` with frozen output
- **budgeted** — every call passes through a WBO-6 budget check (`wbo6::`)
- **witnessed** — every mutation wrapped in a `MutationEnvelope` and recorded in the `RunEventLog`
- **capability-gated** — every tool / mutation gated by a macaroon (`cognitive_dag::macaroons::`) whose root key is bound to a Sovereign Gate session

The prior design (`docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`) supplies the architectural shape; this doctrine is the no-compromise realisation under the **System G / Invader Agent** name lock.

## 1. Tier behaviour (locked)

`AgentRuntimeV2Mode` is the single source of truth for which v2 paths are alive in a given build.

| Mode          | Tier            | Bounded executor | Subprocess CLI | MAS-safe |
|---------------|-----------------|------------------|----------------|----------|
| `Disabled`    | MAS V1          | no               | no             | yes      |
| `IpcBounded`  | Pro V1.x        | yes              | no             | no       |
| `Subprocess`  | Pro Research    | yes              | yes (hardened) | no       |

- **MAS V1 → `Disabled`.** v2 is dormant. The legacy `agent_runtime::` paths serve all in-process orchestration. v2 callers MUST refuse to drive any executor when the active mode is `Disabled`. MAS cannot pivot to `IpcBounded` or `Subprocess` at runtime — flipping requires a CLAUDE.md edit + App Review re-submission (see `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` IR-1).
- **Pro V1.x → `IpcBounded`.** Bounded, in-process executor. WBO budget + macaroon verification + `MutationEnvelope` wrapping all required. Pro CLI adapters live in this mode through hardened `Command::new` paths (see `agent_core/src/security.rs`).
- **Pro Research → `Subprocess`.** Gated subprocess adapter path for Pro Research builds only. Must remain behind a Cargo feature; never compiled into the MAS bundle.

## 2. The `Para<P, A, B>` morphism

Every v2 executor implements:

```rust
pub trait Para<P, A, B>: Send + Sync {
    fn fwd(&self, params: &P, input: A) -> Result<ParaOutput<B>, ParaError>;
    fn rev(&self, params: &P, output: &ParaOutput<B>) -> Result<ParaFeedback<P>, ParaError>;
}
```

The reverse-leg invariant — **`rev` MUST NOT mutate `stop_reason` or any other field of `ParaOutput`** — is enforced two ways:

1. **Compile-time** — `rev` takes `&ParaOutput<B>` (shared reference). There is no `&mut` path through the trait surface.
2. **Runtime forensic** — every `ParaOutput` carries a frozen BLAKE3 digest (`stop_reason_digest`) computed over `stop_reason.canonical_bytes()` and the thinking-block bytes. `ParaOutput::digest_intact()` recomputes the digest and asserts equality; the property test in `para::tests::reverse_leg_cannot_mutate_stop_reason` exercises this.

The same digest doubles as the "thinking blocks hash-identical" invariant: any tampering with the thinking bytes between `fwd` and the AnswerPacket emit is caught by `digest_intact()`.

## 3. Canonical flow (target)

```
AgentBlueprint
   ↓
MissionPacket               ← typed (provider-neutral)
   ↓
AgentEvent stream           ← yielded by Para::fwd
   ↓
approval (SovereignGate)    ← macaroon verify + WBO debit
   ↓
MutationEnvelope            ← wraps every write; never bypassed
   ↓
RunEventLog (append-only)   ← witness trail
   ↓
AnswerPacket
```

Iter-1 lands the trait surface (`Para` + `StopReason` + `ParaOutput`); the rest of the flow is built up one node per `/loop` tick.

## 4. Naming distinction from Hermes / Aegis

- **Hermes** = the prior in-process Rust agent orchestrator. The namespace was purged from code 2026-05-05 (see `CLAUDE.md`). The prior **Hermes Agent Core 2.0** design doc is read as design intent only; the namespace is `agent_runtime_v2`, not `hermes`.
- **Aegis** = a candidate name discussed in a prior Claude session and **explicitly rejected by the user**. Aegis MUST NOT appear in code, docs, prompts, comments, or UI strings. CI lint should flag any reintroduction.
- **System G / Invader Agent** = the user-visible name. The neutral code namespace `agent_runtime_v2` is what callers see.

## 5. Cross-references

- §4 T11 in `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` — acceptance bar.
- `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` — prior design extract (intent only; do not rename).
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §2.6 — macaroon-style capabilities; `agent_core/src/cognitive_dag/macaroons.rs` is the implementation v2 must verify against.
- `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md` — WBO budget shape; `agent_core/src/wbo6.rs` is the budget surface v2 must debit.
- `docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` §3.5 — forever-loop discipline.
- `agent_core/src/agent_runtime_v2/` — Rust home (NEW).
- `Epistemos/AgentRuntimeV2/` — Swift bridge home (NEW; populated as the bridge surfaces land).

## 6. Iteration log

- **Iter 1 (2026-05-18)** — module skeleton (`mod.rs`, `mode.rs`, `para.rs`), `AgentRuntimeV2Mode` enum with MAS/Pro defaults, `Para<P, A, B>` trait + frozen `ParaOutput` + BLAKE3 digest, property test `reverse_leg_cannot_mutate_stop_reason`, thinking-blocks-hash-identical forensic path. Doctrine doc created.
