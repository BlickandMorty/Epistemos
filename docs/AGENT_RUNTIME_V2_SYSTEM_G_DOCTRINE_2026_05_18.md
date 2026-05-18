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

### 4.1 Aegis-name CI lint (sketch)

A grep-based CI gate is enough — the rule is pure absence-check. The
acceptable shape:

```bash
# fail CI if any committed source/doc names "Aegis" outside this doc
matches=$(git grep -ni 'aegis' -- \
  ':!docs/AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md' \
  ':!docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md' \
  ':!docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md' \
  ':!docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md' \
  ':!docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md' \
  || true)
if [ -n "$matches" ]; then
  echo "::error::Aegis name reintroduced (rejected by user direction):"
  echo "$matches"
  exit 1
fi
```

Exclude paths are the docs that may legitimately mention the rejection
(this doctrine + the prior-design doc + the prompt deck + the dispatch
doc + the substrate handoff doc — each names "Aegis" only in the
context of explaining the rejection).

The lint is *status: scaffold-only* until wired into a `.github/workflows/`
job or local pre-commit hook by a future iteration. Adding the wire-up
is out of scope for T11 (touches CI infrastructure outside the
v2 namespace).

## 5. Cross-references

- §4 T11 in `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` — acceptance bar.
- `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` — prior design extract (intent only; do not rename).
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §2.6 — macaroon-style capabilities; `agent_core/src/cognitive_dag/macaroons.rs` is the implementation v2 must verify against.
- `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md` — WBO budget shape; `agent_core/src/wbo6.rs` is the budget surface v2 must debit.
- `docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` §3.5 — forever-loop discipline.
- `agent_core/src/agent_runtime_v2/` — Rust home (NEW).
- `Epistemos/AgentRuntimeV2/` — Swift bridge home (NEW; populated as the bridge surfaces land).

## 6. Iteration log

- **Iter 1 (2026-05-18)** — module skeleton (`mod.rs`, `mode.rs`, `para.rs`), `AgentRuntimeV2Mode` enum with MAS/Pro defaults, `Para<P, A, B>` trait + frozen `ParaOutput` + BLAKE3 digest, property test `reverse_leg_cannot_mutate_stop_reason`, thinking-blocks-hash-identical forensic path. Doctrine doc created. *(commit 68caff3f8)*
- **Iter 2** — `AgentRuntimeV2Capability` trait + `MacaroonCapability` wired to `cognitive_dag::macaroons::verify_macaroon` / `evaluate_caveats`. Property tests: `forged_macaroon_rejected`, `expired_macaroon_rejected`, `tampered_caveat_rejected`, `narrowed_macaroon_with_scope_caveat_still_verifies`, `valid_macaroon_accepted`. *(commit 8b417333b)*
- **Iter 3** — `BudgetGate` with `BudgetSpec { max_tokens, max_wall_ms, max_tool_calls, max_subprocess_ms }`, `BudgetLedger`, `BudgetDebit`, `BudgetTerm`. Pure `check_and_debit` returns advanced ledger on success, never mutates on rejection. Property tests: `over_budget_call_rejected`, `rejected_call_leaves_ledger_untouched`, plus boundary / subprocess / zero-cap / stable-codes coverage. Cross-references the WBO-6 T_S + T_SE terms in doc comments. *(commit 5eba5888e)*
- **Iter 4** — `MutationEnvelope<P>` binds capability_hash + debit + payload; `Sealer::seal_and_apply` sequences capability → budget → writer with short-circuit rejection at each gate. Property tests: `denied_mutation_does_not_write`, `over_budget_mutation_does_not_write`, `approved_mutation_applies_and_advances_ledger`, `capability_hash_in_envelope_matches_macaroon`, `envelope_round_trips_through_json`. *(commit a3cbad198)*
- **Iter 5** — `AgentBlueprint` (`id`, `display_name`, `provider_policy`, `budget`, `capability_root_hash`), `ProviderPolicy` + `CliAdapter`, `check_against_mode` gate. `MissionPacket` typed input + `ToolCall::validate` with charset/dot/oversize rejection. `AgentEvent` closed taxonomy. Property tests: `mas_cannot_call_cli`, `pro_bounded_refuses_subprocess`, `research_subprocess_accepts_all_providers`, `malformed_tool_call_rejected_*` (5 variants), `malformed_tool_call_becomes_error_event`. *(commit 9a9e92e31)*
- **Iter 6** — `RunEventLog` append-only with monotonic ordinals + BLAKE3 root over canonical JSON; `RunEventEntry { Event | SealedMutation | LedgerSnapshot }`. `AnswerPacket::emit` captures witness root at emit time. Property tests: `answer_packet_emitted_with_typed_stop_reason`, `answer_packet_distinguishes_budget_exhausted_from_end_turn`, `answer_packet_witness_root_changes_when_log_changes`, log ordering / round-trip / append-monotonicity. *(commit 8c811ab52)*
- **Iter 7 (batched test gate)** — `cargo test -p agent_core --lib agent_runtime_v2` ran for the first time. Three minimum fixes: `BudgetDebit` gained serde derives; `AgentEvent` `#[serde(tag)]` renamed from `kind` → `event_type` to avoid collision with the `Error { kind }` variant field; `SealError` dropped `Eq` (CapabilityError is only `PartialEq`). **Result: 50/50 narrow tests pass, including all ten §4 T11 acceptance invariants.** *(commit a30d43ba6)*
- **Iter 8 (deep hardening pass 1)** — `ParaSeq` sequential composition of two `Para` morphisms. Property test `composed_reverse_leg_cannot_mutate_either_stop_reason` proves the no-mutation invariant LIFTS through composition (both stages' digests survive composed `rev`). Adversarial fixtures: `capability_missing_entirely_blocks_write` (NoCapability implementor — the gate, not the cryptography, is what blocks), `runaway_tool_loop_bounded_by_max_tool_calls` (100 calls vs cap 3 → exactly 3 accepted, call 4 trips `BudgetError::Exhausted`), `partial_mutation_rollback_when_writer_fails_after_gates_clear` (writer fails AFTER both gates clear → `SealError::Write` returned, caller-held ledger untouched).

## 7. Cross-terminal wiring relationships

The agent_runtime_v2 namespace is the v2-side substrate that the W-row
backlog's eventual UI-wiring targets need to consume. Today the
backlog references T2's legacy `agent_runtime` namespace; that text
predates this T-prompt and remains accurate for the legacy path. When
T11's v2 lands behind a mode gate in product code, the same W-rows
become satisfiable via the v2 surfaces as well:

- **W-14** (every chat reply emits an AnswerPacket visible in RunEventLog
  + Provenance Console). v2 alternative: `AnswerPacket::emit` +
  `RunEventLog::root_hash`. The `final_text` / `citations` /
  `stop_reason` shape mirrors what `StreamingDelegate.swift` already
  consumes from the legacy `function_call.rs`.
- **W-15** (Settings → Agent → AgentBlueprint creation flow). v2
  alternative: `AgentBlueprint` + `AgentBlueprintId` + `ProviderPolicy`
  (serde-persistable to `vault/agents/<id>.json`). `check_against_mode`
  is the runtime gate the UI dispatcher must call before invoking any
  executor — refuses MAS-mode CLI providers without UI ceremony.
- **W-16** (replay-from-log UI control). v2 alternative:
  `RunEventLog::entries()` is the deterministic read surface; the
  BLAKE3 `root_hash()` is the integrity check replay must reproduce.
  `AnswerPacket::run_event_log_root` is the binding witness so a
  replay can prove it walked the same log.
