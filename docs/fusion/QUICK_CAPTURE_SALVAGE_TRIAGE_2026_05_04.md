# Quick Capture salvage triage — 2026-05-04

**Source**: `docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/` —
25 Rust files across 10 modules salvaged from the `vigorous-goldberg`
worktree. Total 5,656 LOC. Master plan at
`docs/fusion/salvage/from-vigorous-goldberg/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md`
(3,715 lines, Waves 0-5).

**This doc is handoff notes, not a port plan.** Per the recovery loop's
wait-for-signal contract, V2.1 (Cognitive DAG) does not auto-start. When
the user types `RESUME SUBSTRATE V2`, the next building agent picks a
Tier A / Tier B slice from this register and lands it independently.

---

## Tier A — Integration-ready today (no DAG dependency)

These modules are self-contained data types or pure deterministic
algorithms. They could land into `agent_core/src/` in their own commits
without waiting for V2.1 Phase 8.

| Module | Files | LOC | What | Depends on |
|---|---|---|---|---|
| `format/` | mod + intent + mem + skill | ~600 | Hybrid JSON+Markdown formats (.mem, .intent, .skill); pure data definitions per Plan §2 + §8 + §24 | serde only |
| `canon/` | mod + alias | ~280 | Deterministic concept canonicalizer (lowercase → unicode-fold → stem → sort → kebab); no LLM per Plan §1.4 No-LLM-First | rust-stemmers crate |
| `grammar/` | mod | 208 | llguidance-based grammar compiler from JSON Schema — single source of truth for tool-call shape per Plan §3.3 + §17 | llguidance 1.x |
| `undo/` | mod | 579 | SQLite-backed undo_events log + 24h ⌘Z reversal per Plan §8.5 | rusqlite |

**2026-05-04 integration note**: `format/` core landed in
`agent_core/src/format/` as a selective Tier A port with
`mem` / `intent` / `skill` and `agent_core/tests/format_salvage.rs`.
The port intentionally preserves the serde-only acceptance bar from this
triage doc rather than importing the divergent salvage tree's missing
JSON Schema / schemars / ulid dependency surface. `.soul` paired-file IO
and full JSON Schema 2020-12 validation remain a separate follow-up
because the salvaged `soul.rs` depends on helpers not present in current
main.

**2026-05-04 integration note**: `canon/` core landed in
`agent_core/src/canon/` as a selective Tier A port with the deterministic
English canonicalizer and alias table. It preserves Plan §3.7's
no-LLM-first rule, the explicit user-gated alias/propose/defer bands,
and the sorted-token invariant (`Gradient Checkpointing` →
`checkpoint-gradient`) despite the source plan's example-text
divergence. Covered by `agent_core/tests/canon_salvage.rs`.

**2026-05-04 integration note**: `grammar/` core landed in
`agent_core/src/grammar/` as a selective Tier A port with JSON Schema →
`llguidance::api::TopLevelGrammar`, closed dispatch-schema construction,
and the CRANE open-thinking / closed-answer wrapper shape. This is the
Rust-native grammar bridge only; inference-loop token masking and
MLX-Structured Swift wiring remain Phase 6 / route-integration work.
Covered by `agent_core/tests/grammar_salvage.rs`.

**2026-05-04 integration note**: `undo/` core landed in
`agent_core/src/undo/` as a selective Tier A port with the
`undo_events` SQLite schema, WAL + `synchronous=NORMAL`, 24h routine TTL,
7d auto-research TTL, `mark_undone`, lazy expired-entry eviction, and a
`has_undo_since` acceptance-signal query for later `skill_discovery/`.
Because live `effect/` is still Tier B, `effect` and `inverse` persist as
typed JSON values until the Intent→Effect bridge lands. Covered by
`agent_core/tests/undo_salvage.rs`.

**Recommended landing order**: `format/` first (everything else
references its types) → `canon/` (zero-deps) → `grammar/` (pre-req for
real route Variant B) → `undo/` (pre-req for skill_discovery's "user
accepted" check).

---

## Tier B — Integration-ready with host wiring (no DAG; needs Swift wiring or trait impl)

These modules are self-contained logic but expect the host (Swift /
AppBootstrap) to provide a probe, callback, or trait implementation.
The Rust side ships clean; the Swift wiring is a separate slice.

| Module | Files | LOC | What | Host wiring required |
|---|---|---|---|---|
| `nightbrain/` | mod | 334 | Idle scheduler; thermal + battery + idle gates per Plan §7.1 | Swift `RuntimeDiagnosticsMonitor` already exposes thermal + memory pressure; needs a battery probe + idle-since-last-input timestamp |
| `heal/` | mod + breaker + log | ~900 | Self-healing Try-Heal-Retry loop + per-tool circuit breaker per Plan §5 | Diagnostician trait impl (LLM-bearing in production; `GiveUpDiagnostician` already present for tests) |
| `route/` | mod + variant_a/b/c | ~1,500 | Four-variant routing pipeline per Plan §4 (place \| merge \| create_folder \| defer) | Variant A: folder-medoid index (Tantivy or HNSW). Variant B: GBNF classifier (uses `grammar/`). Variant C: concept-anchored placement (uses `canon/`). Variant D ships standalone today. |
| `effect/` | mod + dispatcher + 3 appliers + receipt | ~1,200 | Intent-to-Effect state pattern + per-effect inverse for undo per Plan §8 | Receipt module has a Wave 5 stabilize TODO for Ed25519 / Keychain / Secure Enclave signing; current HMAC receipt is a local tamper-evidence placeholder, not final trust geometry |

**2026-05-04 integration note**: `heal/` core landed in
`agent_core/src/heal/` as a selective Tier B port with
`HealLoop`, `Diagnostician`, `GiveUpDiagnostician`, reuse of the
existing bit-packed `CircuitBreaker`, and `HealEventLog`
`heal_events` SQLite persistence. The port consumes `effect::ApplyError`
directly so there is one failure taxonomy. LLM-bearing diagnostician
and Swift trace UI surfacing remain host-wiring follow-ups. Covered by
`agent_core/tests/heal_salvage.rs`.

**2026-05-04 integration note**: `effect/` core landed in
`agent_core/src/effect/` as a selective Tier B port with typed
`Effect`, `Inverse`, `ApplyError`, `IntentApplier`, `IntentDispatcher`,
vault/concept/memory appliers, and `ExecutionReceipt` hash/MAC
verification. It consumes the already-landed `format/`, `canon/`, and
`undo` substrate without Swift host wiring yet. Ed25519 / Keychain /
Secure Enclave production signing remains a named follow-up; this slice
does not claim final receipt trust geometry. Covered by
`agent_core/tests/effect_salvage.rs`.

**2026-05-04 integration note**: `nightbrain/` core landed in
`agent_core/src/nightbrain/` as a selective Tier B port with
`NightBrainScheduler`, `HostActivitySnapshot`, shared
`CancellationToken`, `NightBrainTask`, `TaskCtx`, and the canonical
Plan §7.1 worker-pool cap (`min(4, available_cores - 2)`, floor 1).
The port adapts the salvage rather than importing its stale
`lifecycle::idle_monitor` dependency: Swift remains responsible for the
macOS idle / thermal / power probes, while Rust owns admission,
preemption, task context, and cancellation contracts. Covered by
`agent_core/tests/nightbrain_salvage.rs`. Swift battery-percent wiring
landed in `NightBrainService` / `PowerGate`; live task registration remains a
host follow-up. The stale-run fallback also now uses
`NightBrainService.runInlineFallback()` and records success only after a
`.finished` pipeline result, rather than merely registering the scheduler.

**2026-05-04 continuation note**: Rust-side NightBrain task registration
landed in `NightBrainScheduler`: named task registration, duplicate-name
rejection, stable registered-name listing, and ordered registered-task
execution that stops after a preempted task. Swift/UniFFI exposure of this
registry remains the host follow-up; the macOS idle / thermal / power probes
must stay on the existing Swift `NightBrainService` / `PowerGate` authority.

**2026-05-04 continuation note**: Swift/UniFFI exposure for the safe,
non-probe portion of the registry has now landed. Rust exports
`nightbrain_canonical_task_names` and `nightbrain_preview_admission`; Swift
guards compare the exported names against `NightBrainService.Job.allCases` and
verify the 60-second idle admission contract. Full Swift-owned execution handle
wiring for registered Rust tasks remains the host follow-up.

**2026-05-04 integration note**: `route/` core landed in
`agent_core/src/route/` as a selective Tier B port with the closed
`structure.route_capture` surface, canonical four-action enum
(`place`, `merge_into_existing_note`, `create_folder`, `defer`),
Plan §4 floors (A 0.85 / B 0.75 / C 0.70), Variant A centroid routing,
Variant B GBNF/closed-vocab classifier trait and `NEW` / `DEFER`
sentinels, Variant C concept-anchored merge/create-folder logic, and
Variant D review-inbox fallback. Covered by
`agent_core/tests/route_salvage.rs`. At first landing, real
folder-medoid persistence, MLX/GBNF classifier wiring, and
concept/neighbour host implementations remained follow-up slices.

**2026-05-04 continuation note**: Variant A folder-medoid persistence
landed through `FolderMedoidStore` with SQLite WAL /
`synchronous=NORMAL`, deterministic path-ordered loading, and
finite-vector validation. MLX/GBNF classifier wiring and
concept/neighbour host implementations remain follow-up slices.

**2026-05-04 continuation note**: Variant B's closed vocabulary is now
enforced in both grammar construction and runtime acceptance. The allowed
folder set excludes `_inbox/`, sorts and deduplicates paths, appends `NEW` /
`DEFER`, and rejects classifier outputs that are not in the closed folder set
even when the reported confidence exceeds the canonical 0.75 floor.

**2026-05-04 continuation note**: Swift/UniFFI Route host contract exposure
has landed. Rust exports `route_capture_contract` for schema IDs, action wire
names, canonical floors/gates, trace cap, and review-inbox fallback, plus
`route_variant_b_schema_json` so Swift can build the same deterministic
closed-vocabulary schema from live vault paths. MLX/GBNF classifier wiring and
concept/neighbour host providers remain the Route follow-up slices.

**Recommended landing order**: `effect/` first (everything else emits
Effects) → `heal/` (consumes Effect failures) → `nightbrain/` (uses
heal for retry semantics) → `route/` (uses all of the above). Since
`effect/`, `heal/`, the Rust `nightbrain/` scheduler core, and the
Rust `route/` ladder core are now landed, the remaining Tier B work is
host wiring rather than salvage recovery.

---

## Tier C — DAG-blocked (needs V2.1 Phase 8 first)

These modules read provenance facts that only become typed and
queryable once the Cognitive DAG lands. Trying to integrate before
Phase 8 means hand-rolling the provenance API twice.

| Module | Files | LOC | What | Why DAG-blocked |
|---|---|---|---|---|
| `skill_discovery/` | mod | 434 | Proposes `.skill.json` / `.skill.md` pairs from successful tool compositions per Plan §11 + Phase 12.5 | Reads (1) tool-sequence-hash (a DAG-provenance edge), (2) "user accepted" = no ⌘Z within 5 min (DAG provenance + undo log), (3) latency budget met (DAG node attribute). All three become first-class once Phase 8 ships; pre-Phase-8 they require a parallel ledger. |

---

## Tier D — Browser engine / Pro-only (Wave 6+; beyond V2 scope)

| Module | Files | LOC | What | Status |
|---|---|---|---|---|
| `browser_engine/` | mod | 470 | BrowserEngine trait + WebKit (MAS-safe) / Obscura (Pro-only) / Mock adapter pattern per FINAL_SYNTHESIS §6 | Wave 6 in the source plan; replaces the legacy `tools/browser.rs` direct-spawn. The trait is small enough to land into agent_core today as a non-default surface, but the actual adapter implementations (esp. ObscuraBrowserEngine) are Pro-only and beyond V2's MAS-first scope. |

---

## Master plan section map

The 3,715-line `QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` covers more than
the 10 salvaged modules. The salvage is the substrate (Waves 0-5);
the plan also covers:

- **§6 Native Skills + Local Inference** (Spotlight, Vision OCR, MLX
  ephemeral pipeline, per-model engineering for 12 models). Some pieces
  exist today (Spotlight indexer, MLXInferenceService); the per-model
  catalog is canon-target.
- **§7 Model Workspace Protocol** (filesystem-as-orchestrator). Adjacent
  to but not blocked by V2.1 DAG.
- **§9 Minimalist Capture Surface** (UI). Belongs in `Epistemos/Views/`,
  not agent_core.
- **§17 Compile-Verify-Mint + Sampler-Bound Tool Dispatch** (the
  breakthrough — grammar-bound dispatch makes local strictly more
  reliable than cloud on tool-call shape). Implements via `grammar/`
  + future runtime wiring.
- **§18 Auto-Generation Pipeline** (skill / tool minting from compose).
  Builds on `skill_discovery/` (Tier C).

---

## Acceptance bar before this triage is "done"

- [ ] Each Tier A module landed as its own commit per the five-question
      PR discipline (Stage / GenUI route / Sovereign / Pro impact /
      TEMP-FREE-TIER).
      - `format/` landed 2026-05-04 as Recovery Tier A, no GenUI route,
        no mutating Sovereign action, MAS/Pro shared pure Rust, and no
        App Group or entitlement impact.
      - `canon/` landed 2026-05-04 as Recovery Tier A, no GenUI route,
        no mutating Sovereign action, MAS/Pro shared pure Rust, and no
        App Group or entitlement impact.
      - `grammar/` landed 2026-05-04 as Recovery Tier A, no GenUI route,
        no mutating Sovereign action, MAS/Pro shared pure Rust, and no
        App Group or entitlement impact.
      - `undo/` landed 2026-05-04 as Recovery Tier A, no GenUI route,
        no direct mutating Sovereign action, MAS/Pro shared pure Rust,
        and no App Group or entitlement impact.
- [ ] Each Tier B module landed with the named host wiring as a
      separate Swift commit.
      - `effect/` Rust core landed 2026-05-04; production receipt
        signing remains the host/trust follow-up.
      - `heal/` Rust core landed 2026-05-04; production diagnostician
        and Swift trace UI remain the host follow-up.
      - `nightbrain/` Rust core landed 2026-05-04; Swift
        battery-percent snapshot wiring landed, Rust task registration
        now exists, and Swift/UniFFI exposure of that registry remains
        the host follow-up.
      - `route/` Rust core landed 2026-05-04; folder-medoid persistence
        landed, while MLX/GBNF classifier wiring and concept/neighbour
        host impls remain host follow-ups.
- [ ] Tier C deferred until V2.1 Phase 8 lands.
- [ ] Tier D deferred until Pro-build is on the critical path (per the
      MAS-first focus doctrine).

Until then, the salvage tree under
`docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/` stays
read-only. Don't import from the salvage path at compile time —
copy the file into `agent_core/src/` when you're ready to land it.
