---
state: candidate-canon
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source_prompt: user request to emphasize more aspects of engineering logic to better assist the architecture
status: architecture doctrine; no product promotion without explicit invariants, budgets, state machines, witnesses, rollback, and falsifier evidence
---

# Engineering Logic Architecture Intake - 2026-06-01

## Thesis

Engineering logic is the discipline that lets Epistemos keep architectural
ambition without collapsing into vibes, wrappers, or hidden magic.

The posture is:

```text
assume the target can be made real
  -> name the mechanism
  -> state the invariant
  -> bound the state space
  -> budget the hot path
  -> expose the witness
  -> define rollback
  -> falsify before promotion
```

This preserves the user's no-compromise ambition. Future agents should not
begin by assuming the local substrate, UAS/AppColdStore, active model-state
selection, dynamic compute, or 70B cocktail is impossible. They should begin
by asking: what mechanism would make it true, what invariant would it protect,
what budget would it consume, what evidence would prove it, and what rollback
would make failure survivable?

The rigor lock is equally strong: a mechanism is not architecture until its
owner, contract, state machine, budget, failure mode, witness, and rollback are
explicit.

## Why this exists

The current canon already names major organs and laws:

- UAS/OAS for identity and meaning over addresses;
- ColdStore/AppColdStore for dormant residency;
- ActiveAssembly and NeuralImportanceAtlas for active support selection;
- Eidos for evidence and route priors;
- SCOPE-Rex/SovereignGate for admission and mutation governance;
- RuntimeRouter/System G for execution;
- RunEventLog and AnswerPacket for visible proof;
- L8-L13 candidate laws for projection, cold working sets, utility, residency,
  cache lineage, and delta projection.
- L20 candidate law for Pattern-Boosted Residency: offline/idle assembly
  tournaments may improve route/layout policy only after constraint repair,
  sparse fingerprints, held-out replay, abstention, rollback, and witnesses.

Engineering logic is the missing builder grammar. It turns an idea into the
smallest set of proof-carrying artifacts needed before code, docs, or prompts
claim the idea as real.

## L14-Candidate: Engineering Logic Law

A mechanism may enter the architecture only when its invariant, owner, state
transition, budget, failure mode, witness, and rollback are explicit.

```text
EngineeringConfidence(change) =
  invariant_clarity
  + contract_clarity
  + bounded_state_space
  + measured_budget_margin
  + observability
  + rollback_quality
  - hidden_coupling
  - concurrency_risk
  - hot_path_cost
  - migration_risk
  - license_or_source_risk
```

Promotion condition:

- the mechanism names its existing organ, not a new hidden authority;
- ownership and source of truth are explicit;
- preconditions, postconditions, and forbidden states are written down;
- state transitions and side effects are finite enough to test;
- latency, active bytes, cold bytes, copies, allocations, actor hops, disk I/O,
  and verifier cost are budgeted when relevant;
- cancellation, backpressure, retry, and failure surfaces are declared;
- user-visible effects are witnessed in RunEventLog and AnswerPacket;
- rollback exists before mutation; and
- a falsifier or focused local test can reject the claim.

## Engineering Logic Flow

```text
Architecture idea / bug / research motif / PR
  -> DecisionRecord
  -> InvariantLedger
  -> StateMachineCard or BoundaryContract
  -> BudgetVector and HotPathProofCard
  -> FailureEnvelope and ObservabilityProbe
  -> MigrationRail or ImportGateCard when needed
  -> falsifier artifact
  -> RunEventLog + AnswerPacket when user-visible
```

An idea may stay Pro Research with incomplete cards. It may not govern live
behavior, mutate user data, wake cold model state, import source code, or make
product claims while the cards are missing.

## Primitive Set

### `DecisionRecord`

The smallest honest decision object.

```text
DecisionRecord {
  decision_id
  problem_statement
  chosen_option
  rejected_options
  constraints
  affected_organs
  source_refs
  falsifier_refs
  rollback_ref
}
```

### `InvariantLedger`

The invariant registry for a mechanism or subsystem.

```text
InvariantLedger {
  invariant_id
  scope
  owner_organ
  source_of_truth
  preconditions
  postconditions
  forbidden_states
  witness
  falsifier
}
```

### `StateMachineCard`

Finite state and transition discipline.

```text
StateMachineCard {
  machine_id
  states
  events
  allowed_transitions
  guards
  side_effects
  terminal_states
  rollback_transitions
}
```

### `BoundaryContract`

The contract at a subsystem, actor, FFI, tool, model, or storage edge.

```text
BoundaryContract {
  caller
  callee
  ownership
  data_shape
  sendability_or_thread_rule
  error_type
  cancellation_rule
  backpressure_rule
  privacy_class
}
```

### `BudgetVector`

The cost shape of a route.

```text
BudgetVector {
  latency_ms
  p95_latency_ms
  active_bytes
  hot_resident_bytes
  cold_bytes
  copy_count
  allocation_count
  actor_hops
  disk_io_bytes
  verifier_cost
}
```

### `HotPathProofCard`

Focused proof for hot-path work.

```text
HotPathProofCard {
  path_id
  trigger
  caller_actor_or_thread
  worker_actor_or_thread
  per_event_allocations
  copy_count
  debounce_or_coalescing
  p95_budget
  p99_budget
  measurement_ref
}
```

### `FailureEnvelope`

Failure is part of the architecture, not a surprise.

```text
FailureEnvelope {
  failure_id
  known_failures
  detection_signal
  user_visibility
  retry_policy
  fallback_route
  data_loss_risk
  rollback_ref
}
```

### `ObservabilityProbe`

The witness that tells the system whether reality matched the plan.

```text
ObservabilityProbe {
  probe_id
  signal_kind: metric | log | signpost | artifact | answer_packet_field
  sample_cadence
  redaction_policy
  pass_threshold
  fail_threshold
  owner
}
```

### `MigrationRail`

How a mechanism changes safely over time.

```text
MigrationRail {
  migration_id
  current_state
  target_state
  compatibility_shim
  data_migration
  validation_step
  kill_switch
  rollback_state
}
```

### `ImportGateCard`

The source-mining and dependency gate.

```text
ImportGateCard {
  source_url_or_path
  license
  dependency_graph
  setup_cost
  security_notes
  maintenance_status
  benchmark_requirement
  status: source_mine_only | vendor_candidate | rejected
}
```

### `SimplicityBudget`

Complexity must buy something real.

```text
SimplicityBudget {
  complexity_added
  duplication_removed
  user_visible_value
  performance_value
  test_or_falsifier_count
  rollback_cost
  indirection_count
}
```

## Application To Epistemos Organs

| Organ | Engineering logic emphasis |
|---|---|
| UAS/OAS | Every addressable object needs source of truth, owner, digest, privacy, residency status, and migration rail. |
| ColdStore/AppColdStore | Every cold wake needs active/cold byte budgets, compatibility fence, lease, cold-miss witness, fallback, and rollback. |
| ActiveAssembly | Every support set needs utility claim, BudgetVector, failure envelope, verifier route, and no hidden unit selection. |
| NeuralImportanceAtlas | Every importance signal needs counterfactual baseline, interference risk, source refs, and ablation falsifier. |
| ResidencyPatternBoost | Every discovered assembly needs a genome, repair trace, sparse fingerprint, held-out score, elite archive lineage, LatticeAbstentionGate result, ComputeResumeLease, rollback, and cold-route patch boundary. |
| Eidos | Every route prior needs source cards, citation validity, contradiction handling, and no hidden self-router authority. |
| RuntimeRouter/System G | Every executor path needs BoundaryContract, cancellation, backpressure, error taxonomy, and RunEventLog events. |
| Swift/AppKit/UI | Every hot UI path needs actor isolation, debounce/coalescing, no disk read in view body, no repeatForever loop, and measured budget. |
| Rust/FFI/Metal | Every boundary needs repr/layout truth, memory ownership, nil guards, SAFETY comments, copy count, and crash-safe falsifier. |
| Note/editor substrate | Every edit should be an EditorDeltaMonoid or explicit rebuild escape hatch with selection, undo, digest, and projection witness. |
| Imported research/code | Every repo motif needs ImportGateCard before source import and license/setup/vendor review before dependency adoption. |

## Agent Procedure

When a future session touches architecture, the agent should:

1. State the ambitious target as a mechanism, not as a mood.
2. Name the existing organ that owns it.
3. Decide whether the work is MAS, Pro Live, Pro Gated, Pro Research,
   Pro Vault-Preserved, TargetOnly, or Blocked.
4. Write the DecisionRecord and at least one InvariantLedger row.
5. Add a StateMachineCard or BoundaryContract for the dangerous edge.
6. Add a BudgetVector for any hot path, model route, storage route, or UI route.
7. Add a FailureEnvelope before mutation or user-visible behavior.
8. Add an ObservabilityProbe or falsifier so the claim can be rejected.
9. Keep the change small enough that rollback is real.
10. Update canon only after the mechanism has a route through visible proof.

For model-state, cold residency, route selection, or 70B-cocktail work, the
agent must also read
`docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` and
`docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`. The engineering
logic rule is: no discovered route/layout policy becomes canonical unless it is
repairable, measurable, abstention-gated, replayable, and reversible.

## Product Locks

- Do not create a new top-level organ when an existing organ can own the idea.
- Do not add wrappers around wrappers to feel safe; write the direct contract.
- Do not make SSD-as-RAM, hidden-base-weight-mutation, hidden-neural-control,
  or unmeasured-routing claims.
- Do not use "research says" as authority without source cards and local
  falsifiers.
- Do not import repo code without ImportGateCard and license/setup review.
- Do not optimize by breaking Swift actor isolation, FFI ownership, privacy
  policy, or rollback.
- Do preserve ambitious target doctrine as Pro Research or TargetOnly when the
  mechanism is not yet proven.

## Backlog Falsifier Bundle

Candidate gates live in:

`docs/falsifiers/F-ENGINEERING-LOGIC-ARCHITECTURE-BUNDLE_2026_06_01.md`

The first useful implementation is not a new runtime. It is schemas and tests
that prove a small architecture change can emit DecisionRecord,
InvariantLedger, BoundaryContract, BudgetVector, FailureEnvelope, and
ObservabilityProbe artifacts without adding hidden authority.
