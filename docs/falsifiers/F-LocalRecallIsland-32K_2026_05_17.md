---
state: falsifier
gate: F-LocalRecallIsland-32K
ladder_position: 9 (after F-SemiseparableBlockScan-Correctness, before F-PacketRouter1bit-Dispatch)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase C
target_rig: M2 Pro 16 GB
---

# F-LocalRecallIsland-32K

> Gate #9 in the §4.G falsifier ladder. **Exact-recall island for passkeys / pinned / recent tokens preserves
> recall ≥ 95% under sketch-heavy routing.** Helios v6.2 §7 acceptance: 50 trials × 5 depths passkey ≥ 0.95.

## §1. Why this gate exists

The §4.G hierarchy puts kernels under Shadow-first paging. Once sketch-based routing is the default
(F-ShadowFirst-PageEscalation), there is a class of items — passkeys, pinned references, recent tokens —
where sketch-based loss is unacceptable. The LocalRecallIsland kernel reserves an exact-decoded region of the
context (the "island") and guarantees ≥ 95% recall on items placed inside it.

Without this gate, the system's claim of "Shadow paging without losing critical tokens" is unverified.

Driver §4.G prose + Helios v6.2 §7 acceptance bar:

> LocalRecallIsland.metal 32K Core acceptance: 50 trials × 5 depths passkey ≥ 0.95, niah_single_1 ≥ 0.95.

The CPU substrate at `agent_core/src/helios/local_recall_island.rs` (418 LOC) lands the `RecallStore` +
`passkey_retrieve` + `run_passkey_trials` substrate. This gate operationalizes the acceptance.

## §2. The harness shape

The harness lives at `agent_core/src/research/local_recall_island/` (gap as of 2026-05-17). It composes the
existing CPU substrate with a live 32k-context model (Qwen 3 8B at 32k, or any 32k-capable model on the rig)
to run the canonical passkey-retrieve + niah_single_1 tasks per RULER methodology.

The "island" within the context is the last 4k tokens; cold-paged tokens live in the remaining 28k.

## §3. Pass/fail recipe (the test that decides)

A Swift integration test at `EpistemosIntegrationTests/LocalRecallIsland32KTests.swift`:

```swift
let model = try await load(.qwen3_8b_mlx().withContextWindow(32_000))

// Task 1 — passkey retrieval at 5 depths.
let depths = [0.10, 0.25, 0.50, 0.75, 0.90]  // fraction of context where passkey is hidden
var passkeyResults: [Double] = []

for depth in depths {
    var hits = 0
    for trial in 0..<50 {
        let prompt = PasskeyBenchmark.build(contextTokens: 32_000, depth: depth, seed: trial)
        let result = try await model.generate(prompt: prompt.text, maxTokens: 20)
        if PasskeyBenchmark.verify(result, expectedKey: prompt.key) { hits += 1 }
    }
    passkeyResults.append(Double(hits) / 50.0)
}

let passkeyRate = passkeyResults.reduce(0, +) / Double(passkeyResults.count)

// Task 2 — RULER niah_single_1 at 32k.
let niahResults = try await rulerNiahSingle1(model: model, contextTokens: 32_000, trials: 100)

// Gates
XCTAssertGreaterThanOrEqual(passkeyRate, 0.95,
    "F-LocalRecallIsland-32K FAILED: passkey rate \(passkeyRate) < 0.95")
for (depth, rate) in zip(depths, passkeyResults) {
    XCTAssertGreaterThanOrEqual(rate, 0.90,
        "F-LocalRecallIsland-32K FAILED: depth \(depth) rate \(rate) < 0.90 (per-depth floor)")
}
XCTAssertGreaterThanOrEqual(niahResults.successRate, 0.95,
    "F-LocalRecallIsland-32K FAILED: niah_single_1 rate \(niahResults.successRate) < 0.95")
```

Gate **fails** if the average passkey rate is below 0.95 OR any single depth is below 0.90 OR
niah_single_1 is below 0.95.

### §3.1 Passkey-vs-niah-vs-other-tasks

The gate locks the two RULER tasks that Helios v6.2 §7 explicitly names (passkey + niah_single_1). Other RULER
tasks (niah_multikey_1, vt, cwe, qa_1, qa_2, etc.) are informational for this gate; the gate that exercises
them broadly is F-SemiseparableBlockScan Track B (gate #8) and the eventual long-context-harness gate
(`agent_core/src/helios/long_context_harness.rs`).

## §4. M2 Pro 16 GB budget

| Metric | Budget |
|---|---|
| Passkey rate (average over 5 depths) | ≥ 0.95 |
| Per-depth passkey rate | ≥ 0.90 |
| niah_single_1 success rate | ≥ 0.95 |
| Peak RAM | < 13 GB (F-KV-Direct-Gate ceiling) |
| Decode throughput (steady-state) | ≥ 10 tok/s (F-KV-Direct-Gate ceiling) |
| Wall-time per trial (32k prompt, 20-token decode) | < 60 s |

## §5. Measurement methodology

- Passkey insertion follows the canonical methodology per Mohtashami & Jaggi arXiv:2305.16300 (Landmark
  Attention). The passkey is a 5-digit numeric string hidden in filler text at fractional depth.
- niah_single_1 follows Hsieh et al. arXiv:2404.06654.
- Both tasks reuse the F-KV-Direct-Gate (gate #7) cold-spill path. If this gate runs without F-KV-Direct
  passing first, the run is INVALID and the gate cannot pass.
- Seed reproducibility: trial seed `t ∈ 0..<50` is the passkey-content seed; depths are deterministic.
- Median-of-3 runs on niah_single_1 (1-run is the canonical RULER protocol but median-of-3 absorbs MLX
  dispatch noise).

## §6. Fallback if the gate fails

Per §4.G "No silent skips":

1. **Identify which depth fails most**. Common: deep-context (0.10 = passkey near the start) is the hardest;
   if only deep-context fails, the island isn't reaching far enough into the cold tier.
2. **Mitigation tier**:
   - **Tier 1 — island-size tune**: increase the island from 4k → 8k tokens. Trades RAM for recall.
   - **Tier 2 — exact-decode-on-passkey-pattern detection**: parse the prompt for passkey-prefix patterns
     ("The passkey is …") and bind exact decode on those token spans regardless of cold-tier status.
   - **Tier 3 — extend the F-ShadowFirst escalation policy** to escalate any cold page with a passkey-prefix
     pattern automatically.
   - **Tier 4 — STALLED** if no recovery: file STALLED row #15 in canonical-doctrine §5 + BLOCKER. Don't
     push.

## §7. Acceptance bar

- [ ] Average passkey rate ≥ 0.95 over 5 depths × 50 trials.
- [ ] Per-depth passkey rate ≥ 0.90.
- [ ] niah_single_1 success rate ≥ 0.95 over 100 trials.
- [ ] Peak RAM < 13 GB; decode throughput ≥ 10 tok/s (inherited from F-KV-Direct-Gate).
- [ ] Reproducibility: same trial seeds produce same hit/miss across 3 runs.
- [ ] `cargo test` ≥ baseline + new tests. `xcodebuild` clean.
- [ ] Doctrine doc §5 register row #15 status updates from `scaffolded` → `landed`.
- [ ] `Co-Authored-By: Codex (T3)` on every commit.

## §8. Dependencies + downstream gates

**Depends on**:

- F-KV-Direct-Gate (gate #7) PASS — cold-spill path must work before recall over 32k context is meaningful.
- F-ShadowFirst-PageEscalation (gate #4) PASS — escalation policy decides which cold pages survive.
- CPU substrate at `agent_core/src/helios/local_recall_island.rs` (already lands; passkey_retrieve +
  RecallStore + run_passkey_trials).
- Live 32k-capable model (Qwen 3 8B at 32k, or the M2 Pro 16 GB-feasible variant).

**Unblocks**:

- Gate #12 F-70B-Local-Cocktail-Composition (the cocktail relies on the recall island for prompt fidelity).
- §4.E model gating — wider context-window claim for power-user mode.
- `agent_core/src/helios/long_context_harness.rs` (the RULER+BABILong harness scaffold, register row #32).

## §9. Cross-references

- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §4 ladder + §5 row #15.
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §B.1 row 2.
- Driver authority: driver §4.G ladder gate #9 + Helios v6.2 §7 acceptance.
- Passkey-retrieval primary: Mohtashami & Jaggi arXiv:2305.16300 (Landmark Attention).
- RULER niah_single_1 primary: Hsieh et al. arXiv:2404.06654.
- CPU substrate: `agent_core/src/helios/local_recall_island.rs` (418 LOC).
- Active KV cache the test drives: `Epistemos/Engine/MLXInferenceService.swift`.
