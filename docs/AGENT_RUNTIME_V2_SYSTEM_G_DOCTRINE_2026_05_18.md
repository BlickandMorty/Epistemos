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

## 8. Phase 2 — W-46 absorb plan

**Status:** kickoff (iter-16, 2026-05-18). Acceptance bar from §4 T11 is met and 8 hardening passes are committed; the next no-compromise nuance is the W-46 absorb of existing parity infrastructure.

**W-46** (from `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` — claimed by T11):

| Source (read-only) | v2 absorb target | Notes |
|---|---|---|
| `Epistemos/LocalAgent/LocalAgentCapabilityRegistry.swift` | `agent_runtime_v2::adapters::local_agent::` | typed capability tier/owner/surface → maps onto `AgentRuntimeV2Capability` + `AgentBlueprint::budget` + `AgentBlueprint::check_against_mode` |
| `Epistemos/LocalAgent/HermesLocalAgentCompatibility.swift` | (none) | pure typealias bridge — no behaviour to absorb |
| `agent_core/src/tools/cli_passthrough.rs` (8 handlers) | `agent_runtime_v2::adapters::cli_passthrough::` | each handler (ClaudeCode / Codex / Gemini / Kimi / Goose / Aider / OpenHands / MiniSweAgent) → one `Para`-implementing adapter, gated by `AgentRuntimeV2Mode::Subprocess` |
| `agent_core/src/mcp/{mod,client,url_servers}.rs` | `agent_runtime_v2::adapters::mcp::` | MCP client → `Para` adapter; surfaces as `ProviderPolicy::Mcp` blueprints |
| `Epistemos/App/ChatCoordinator.swift` (Rust Agent Core path ~L2396) | (Swift bridge) | once the Rust bridge surfaces stabilise, this Swift call site flips to dispatching via v2 |
| cloud tool loop in `agent_core/src/agent_loop.rs` | `agent_runtime_v2::adapters::cloud_loop::` | Anthropic / OpenAI Responses providers absorbed as `Para` adapters keyed off `ProviderPolicy` |

**Falsifier (W-46):** every existing parity adapter (Goose, Aider, OpenHands, CLI passthrough, MCP, LocalAgent) reachable through *one* `AgentBlueprint` dispatch, witnessed end-to-end with:
- thinking-block preservation (`ParaOutput::thinking_digest` survives every adapter)
- capability check (every side-effect routes through `Sealer::seal_and_apply`)
- audit log (every event + sealed mutation appended to `RunEventLog`)

**Scope-lock invariant for phase 2:** the source files listed above remain READ-ONLY. v2 adapters live under `agent_core/src/agent_runtime_v2/adapters/` and *consume* the source types by import (or, for Swift, by the bridge layer when that exists). No edit to the legacy paths.

**Phase 2 cadence:** one adapter per `/loop` tick, in this order:
1. Iter-17: `local_agent` adapter wrapping `LocalAgentCapabilityRegistry` (Swift-side facing; the Rust adapter is a thin mirror that knows the same tier/owner/surface vocabulary)
2. Iter-18..25: one `cli_passthrough` handler per tick (8 handlers)
3. Iter-26: `mcp` adapter
4. Iter-27: `cloud_loop` adapter (Anthropic + OpenAI provider paths)
5. Iter-28: integration test proving the falsifier — one `AgentBlueprint` per provider variant, dispatched through v2, asserting thinking-block + capability + audit witnesses all land

## 6. Iteration log

- **Iter 1 (2026-05-18)** — module skeleton (`mod.rs`, `mode.rs`, `para.rs`), `AgentRuntimeV2Mode` enum with MAS/Pro defaults, `Para<P, A, B>` trait + frozen `ParaOutput` + BLAKE3 digest, property test `reverse_leg_cannot_mutate_stop_reason`, thinking-blocks-hash-identical forensic path. Doctrine doc created. *(commit 68caff3f8)*
- **Iter 2** — `AgentRuntimeV2Capability` trait + `MacaroonCapability` wired to `cognitive_dag::macaroons::verify_macaroon` / `evaluate_caveats`. Property tests: `forged_macaroon_rejected`, `expired_macaroon_rejected`, `tampered_caveat_rejected`, `narrowed_macaroon_with_scope_caveat_still_verifies`, `valid_macaroon_accepted`. *(commit 8b417333b)*
- **Iter 3** — `BudgetGate` with `BudgetSpec { max_tokens, max_wall_ms, max_tool_calls, max_subprocess_ms }`, `BudgetLedger`, `BudgetDebit`, `BudgetTerm`. Pure `check_and_debit` returns advanced ledger on success, never mutates on rejection. Property tests: `over_budget_call_rejected`, `rejected_call_leaves_ledger_untouched`, plus boundary / subprocess / zero-cap / stable-codes coverage. Cross-references the WBO-6 T_S + T_SE terms in doc comments. *(commit 5eba5888e)*
- **Iter 4** — `MutationEnvelope<P>` binds capability_hash + debit + payload; `Sealer::seal_and_apply` sequences capability → budget → writer with short-circuit rejection at each gate. Property tests: `denied_mutation_does_not_write`, `over_budget_mutation_does_not_write`, `approved_mutation_applies_and_advances_ledger`, `capability_hash_in_envelope_matches_macaroon`, `envelope_round_trips_through_json`. *(commit a3cbad198)*
- **Iter 5** — `AgentBlueprint` (`id`, `display_name`, `provider_policy`, `budget`, `capability_root_hash`), `ProviderPolicy` + `CliAdapter`, `check_against_mode` gate. `MissionPacket` typed input + `ToolCall::validate` with charset/dot/oversize rejection. `AgentEvent` closed taxonomy. Property tests: `mas_cannot_call_cli`, `pro_bounded_refuses_subprocess`, `research_subprocess_accepts_all_providers`, `malformed_tool_call_rejected_*` (5 variants), `malformed_tool_call_becomes_error_event`. *(commit 9a9e92e31)*
- **Iter 6** — `RunEventLog` append-only with monotonic ordinals + BLAKE3 root over canonical JSON; `RunEventEntry { Event | SealedMutation | LedgerSnapshot }`. `AnswerPacket::emit` captures witness root at emit time. Property tests: `answer_packet_emitted_with_typed_stop_reason`, `answer_packet_distinguishes_budget_exhausted_from_end_turn`, `answer_packet_witness_root_changes_when_log_changes`, log ordering / round-trip / append-monotonicity. *(commit 8c811ab52)*
- **Iter 7 (batched test gate)** — `cargo test -p agent_core --lib agent_runtime_v2` ran for the first time. Three minimum fixes: `BudgetDebit` gained serde derives; `AgentEvent` `#[serde(tag)]` renamed from `kind` → `event_type` to avoid collision with the `Error { kind }` variant field; `SealError` dropped `Eq` (CapabilityError is only `PartialEq`). **Result: 50/50 narrow tests pass, including all ten §4 T11 acceptance invariants.** *(commit a30d43ba6)*
- **Iter 8 (deep hardening pass 1)** — `ParaSeq` sequential composition of two `Para` morphisms. Property test `composed_reverse_leg_cannot_mutate_either_stop_reason` proves the no-mutation invariant LIFTS through composition (both stages' digests survive composed `rev`). Adversarial fixtures: `capability_missing_entirely_blocks_write` (NoCapability implementor — the gate, not the cryptography, is what blocks), `runaway_tool_loop_bounded_by_max_tool_calls` (100 calls vs cap 3 → exactly 3 accepted, call 4 trips `BudgetError::Exhausted`), `partial_mutation_rollback_when_writer_fails_after_gates_clear` (writer fails AFTER both gates clear → `SealError::Write` returned, caller-held ledger untouched).
- **Iter 9** — thinking-block end-to-end preservation through `AnswerPacket.thinking_digest`; Aegis CI-lint sketch (grep + exempt-paths) in §4.1. *(commit 3527b6abb)*
- **Iter 10** — Swift bridge marker `Epistemos/AgentRuntimeV2/README.md`; `variant_ladder` scaffold (T1/T2/T3 tiers, debits_tokens, validate). *(commit eeab1e7f9)*
- **Iter 11** — `IdentityPara` + ParaSeq inner-fwd-error short-circuit + `BudgetDebit::for_tool_call/for_thinking_turn` helpers. *(commit 0475b9732)*
- **Iter 12** — `naming_lint` real impl (8 variant tests); `forged_thinking_digest_caught_by_digest_intact`; macaroon exact-expiry boundary (now_ms == until_ts_ms rejected). *(commit ed00771bf)*
- **Iter 13** — capability replay round-trip seals; `RunEventLog::find_capability_hash`; BudgetGate 32-thread concurrency test. *(commit fe103ec48)*
- **Iter 14** — `Sealer` scope-wrong adversarial test; `scan_text` with line/column positions; RunEventLog ordinal-density across 2500 appends. *(commit 2b9630dcc)*
- **Iter 15** — Sealer thread-safety (16-thread shared capability + ledger + writer); `AgentEvent::stop` helper; `AEGIS_LINT_EXEMPT_DOCS` constant + `is_path_exempt`. *(commits edc68978d, 7d892de41)*
- **Iter 16** — W-46 phase 2 kickoff (later paused per RULE 2): `adapters/` namespace + `LocalAgentAdapter` scaffold. Doctrine §8 phase-2 absorb plan. *(commit 19ec2dd8d)*
- **Iter 17** — `LocalAgentAdapter` body: tier/owner/surface enum mirrors, command_token Swift parity, tier+subprocess admissibility. *(commit dcf4f53df)*
- **Iter 18 (Phase 1 pivot-back)** — multi-hop thinking preservation across 5 tool-hop sequence + mid-stream-error variant; capability replay DETECTION via `detect_capability_reuse`; `BudgetLedger::refund(debit)` for cancel paths. *(commit 83d172902)*
- **Iter 19** — `BudgetSpec::max_memory_bytes` + `BudgetTerm::MemoryBytes` (5th axis); `AgentEvent::is_terminal` helper; lint coverage for git commit messages + branch names. *(commit 84d4c562c)*
- **Iter 20** — `RunEventLog::validate_ordinal_density` gap detection; ParaSeq outer-stop_reason propagation; Sealer non-dedupe boundary documented. *(commit 6430b7e8f)*
- **Iter 21** — multi-caveat macaroon (ScopePrefix + ExpiryAfter + ToolNameEq composed); naming_lint Unicode + emoji safety; `Citation::MAX_RECOMMENDED_PER_PACKET` + `exceeds_recommended_citation_cap`. *(commit 88f035e08)*
- **Iter 22** — BudgetGate u64::MAX boundary (no panic on saturating_add); ParaSeq Send/Sync compile-time probe; StopReason canonical-bytes uniqueness + prefix-free. *(commit ced62e839)*
- **Iter 23** — `Mode::allows_subprocess` defensive survey; `capability_root_hash` binding load-bearing for blueprint identity; `MutationEnvelope::MAX_RECOMMENDED_PAYLOAD_BYTES` 4MiB soft cap. *(commit 0fa843f5e)*
- **Iter 24** — naming_lint 10-input UTF-8 fuzz (CR/LF/NUL/non-BMP/emoji); `AgentBlueprintId` HashMap stability; BudgetGate spec-mutation semantics (tighten = future-only, loosen = future-also). *(commit 87afec913)*
- **Iter 25** — ParaSeq 7×7 stop-reason matrix (49 combos); `RunEventLog::entry_count_by_kind`; AgentEvent + AgentEventErrorKind JSON tag stability. *(commit 14a439e52)*
- **Iter 26** — `Mode::is_pro` helper; `RunEventLog::total_tokens_debited` (saturating); macaroon caveat-order distinct capability_hash invariant. *(commit 0634cea15)*
- **Iter 27** — `MissionPacket::validate_prompt` enforcement; chained-log merge produces distinct root_hash; `Citation::is_valid`. *(commit 73a0ec9d1)*
- **Iter 28** — backward-compat serde (legacy JSON without memory_bytes deserialises); `ToolCall::MAX_NAME_BYTES = 256` + `OversizeName`; `SealError` Debug repr stability. *(commit 354b2273a)*
- **Iter 29** — variant_ladder × BudgetGate cross-check (LLM tier must debit tokens, non-LLM may not); `AgentEvent::error` helper; `Hash::zero` default binding for `thinking_digest`. *(commit 1f04622dc)*
- **Iter 30** — Sealer error attribution (Capability before Budget); MAS Disabled survey covers all 6 ProviderPolicy variants; RunEventLog corruption-recovery contract (discard + rebuild). *(commit adb577d21)*
- **Iter 31** — ParaSeq outer-rev short-circuit (mirror of fwd); `Citation::as_display_string`; AgentRuntimeV2Mode snake_case JSON discriminator pinned. *(commit b815b7264)*
- **Iter 32** — `ToolCallError` Debug repr stability (5 variants); `BudgetGate::spec` getter test; `AnswerPacket::was_terminated_by_error`. *(commit 642a8999d)*
- **Iter 33** — macaroon `delegated` flag survives through v2 capability surface; `RunEventLog::last_stop_event`; `VariantLadderSpec::default_tier`. *(commit 1b6a11a7e)*
- **Iter 34** — `BudgetSpec::default` semantics (all-zero unbounded) pinned; `BlueprintModeError` Debug repr pinned; `AgentEvent::concat_reasoning_text`. *(commit f0f4c0dd8)*
- **Iter 35** — `AgentEvent::concat_final_text`; `ParaError` variant Debug stability; `RunEventLog::find_tool_calls`. *(commit dfd3677ff)*
- **Iter 36** — `naming_lint::count_hits` (alloc-free); `capability_hash_is_stable_across_identical_rebuilds`. *(commit ac9309a44)*
- **Iter 37** — `AgentBlueprintId` Display; `ParaOutput::clone` preserves digests bit-for-bit; `RunEventLog::ledger_at_ordinal`. *(commit 25cb142bb)*
- **Iter 38** — `AnswerPacket::token_usage_ratio`; `Citation::from_tuple`; `root_hash` purity contract. *(commit 681c65552)*
- **Iter 39** — `AgentBlueprint::is_subprocess_provider`; `MutationEnvelope` Clone equality; `REJECTED_NAME_LOWERCASE.len()` pinned at 5. *(commit 0996b5226)*
- **Iter 40** — `LocalAgentCapabilityTier::required_mode`; `AnswerPacket::is_empty_run`; `RunEventLog::stop_count`. *(commit 5760b7b71)*
- **Iter 41** — `MissionPacket::new` constructor with built-in validation; `AgentEvent::VARIANT_COUNT = 6` pinned; macaroon double-restrict behaviour documented. *(commit 26a6a1224)*
- **Iter 42** — `BudgetGate` Copy/Clone/Send/Sync compile-time probe; `VariantTier::next_higher` auto-promotion edges; lint consecutive-match non-overlap. *(commit 0f6c9855a)*
- **Iter 43** — `VariantTier` Display (PascalCase, distinct from code()); `RunEventLog::first_event_ordinal`; `ParaError::Transport(_)` context preservation. *(commit 3bb3a3f7d)*
- **Iter 44** — `MissionPacket` Display (prompt-omitting); `AgentBlueprint::vault_persistence_path`; `BudgetTerm` Display reuses .code(). *(commit 67b50d239)*
- **Iter 45** — `AnswerPacket` Display (one-line, body-omitting); `BudgetSpec` serde required-field invariant (4 negatives); `ParaError` PartialEq payload-aware. *(commit fa9577f09)*
- **Iter 46** — `RunEventLog::sealed_mutations` lazy iterator; `AgentEventErrorKind` Display reuses snake_case; lint parity across 11 diverse inputs. *(commit 9fd55fb85)*
- **Iter 47 (this commit)** — Iteration log refresh + acceptance-bar status snapshot. Doc-only.

## 9. Current acceptance bar status (as of iter-47, 2026-05-18)

The ten §4 T11 acceptance items, mapped to their committed property tests:

| # | Acceptance item | Test pointer | Status |
|---|---|---|---|
| 1 | `Para<P, A, B>` with `fwd` and `rev` | `para::tests::fwd_output_digest_is_intact_immediately` | ✓ |
| 2 | `AgentRuntimeV2Capability`, `AgentRuntimeV2Mode::{Disabled, IpcBounded, Subprocess}`, WBO budget check, macaroon verify, `MutationEnvelope` | `capability::tests::valid_macaroon_accepted`, `mode::tests::mas_default_is_disabled`, `budget::tests::over_budget_call_rejected`, `envelope::tests::approved_mutation_applies_and_advances_ledger` | ✓ |
| 3 | Canonical flow `AgentBlueprint → MissionPacket → AgentEvent → approval → MutationEnvelope → RunEventLog → AnswerPacket` | `answer::tests::answer_packet_emitted_with_typed_stop_reason` | ✓ |
| 4 | Reverse leg cannot mutate `stop_reason` | `para::tests::reverse_leg_cannot_mutate_stop_reason` | ✓ |
| 5 | Thinking blocks hash-identical | `para::tests::thinking_blocks_round_trip_with_identical_hash` + `thinking_blocks_preserved_across_n_tool_hops` | ✓ |
| 6 | Forged macaroon rejected | `capability::tests::forged_macaroon_rejected` | ✓ |
| 7 | Expired macaroon rejected | `capability::tests::expired_macaroon_rejected` + `expiry_boundary_at_exactly_now_ms_rejected` | ✓ |
| 8 | Over-budget call rejected | `budget::tests::over_budget_call_rejected` + 4-axis coverage | ✓ |
| 9 | Denied mutation does not write | `envelope::tests::denied_mutation_does_not_write` + scope-wrong fixture | ✓ |
| 10 | MAS cannot call CLI; malformed tool call rejected; AnswerPacket emitted | `blueprint::tests::mas_cannot_call_cli` + `mas_disabled_mode_refuses_every_provider_variant`, `mission::tests::malformed_tool_call_rejected_*` (5 variants), `answer::tests::answer_packet_emitted_with_typed_stop_reason` | ✓ |

**Bar provably met at iter-7 (50/50 narrow tests green).** Iters 8-46 land deep hardening per §3.5 cadence step 10: ParaSeq composition + 7×7 stop matrix, capability replay-detection + caveat-order + multi-caveat composition, BudgetGate concurrency + memory-byte axis + refund + overflow boundary, multi-hop thinking + mid-stream-error, naming_lint full surface (commit/branch/file/comment/Unicode/emoji), RunEventLog corruption-detect / chained-merge / sealed-mutations iter / ledger-at-ordinal, MAS-survey of all 6 ProviderPolicy variants, replay-parity guardrails (caveat order, JSON discriminators, Debug reprs, byte counts, ID stability, capability_root_hash binding).

**Current narrow test count: 235 passed, 0 failed across 17 modules of `agent_core::agent_runtime_v2::`.** Zero regressions across 39 hardening commits.

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
