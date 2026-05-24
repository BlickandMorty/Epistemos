---
state: falsifier
gate: F-ShadowFirst-PageEscalation
ladder_position: 4 (after F-ACS-Anchor-Addressing, before F-PageGather-M2Pro)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase B.G.B4
target_rig: M2 Pro 16 GB
---

# F-ShadowFirst-PageEscalation

> Gate #4 in the §4.G falsifier ladder. **HeliosPage sketch → residual → exact-SSD escalation. KL/token stays
> under 0.06 on a controlled retrieval/attention probe.** Per Shadow Memory canon: INT8 sketch dot-product +
> Metal scoring + top-k + exact decode of selected pages.

## §1. Why this gate exists

The §4.G hierarchy puts Shadow-first paging directly above the Kernels layer: it is the SENSORY FILTER that
decides whether a query gets answered from the cheap INT8 sketch, the medium-cost residual, or the full exact
page from SSD. Without a measured KL-divergence ceiling, "we route through sketches" is wishful thinking —
not a verifiable substrate primitive.

Driver §4.G prose:

> **F-ShadowFirst-PageEscalation** — HeliosPage sketch → residual → exact-SSD escalation. KL/token stays under
> 0.06 on a controlled retrieval/attention probe. Per Shadow Memory canon (sketch + INT8 dot-product + Metal
> scoring + top-k + exact decode of selected pages).

Cross-reference: `epistemos-research/src/shadow_memory.rs` is the doctrine source for the 5-tier ladder
(L0..L4) and the threshold table; this gate operationalizes the L0 → L1 → L2 escalation policy.

## §2. The HeliosPage three-stage shape

The harness lands at `agent_core/src/research/page_gather/` (gap as of 2026-05-17 — Phase B.G.B4 target). The
three stages of a HeliosPage:

| Stage | Bit-width | Storage | Read cost | Acceptance threshold |
|---|---|---|---|---|
| **Sketch** | INT8 (1 byte/elem) | RAM hot working set | full-buffer streaming (PageGather kernel territory) | always read |
| **Residual** | INT8 + per-block scale (Sherry 1.25-bit or NestQuant lattice) | RAM warm pool | streamed on top-k sketches | read if sketch score ≥ residual_threshold |
| **Exact** | bf16 / fp16 / fp32 (per-codec) | SSD cold | mmap'd via Metal IOSurface | read if residual margin ≤ exact_threshold |

Escalation policy:

```text
∀ query q:
  scores = sketch_topk(q, K_SKETCH)               # K_SKETCH = 128 candidates
  residual_scores = residual_rescore(scores, K_RESIDUAL)  # K_RESIDUAL = 32 promoted
  if max(residual_scores) - second_max(residual_scores) ≥ EXACT_THRESHOLD:
      return top1_residual          # cheap path
  else:
      exact_scores = exact_decode(top_k_residual)  # SSD read for K_RESIDUAL pages
      return argmax(exact_scores)   # exact path
```

Default thresholds (Phase B.G.B4 — calibrated against the controlled probe):

- `K_SKETCH = 128`
- `K_RESIDUAL = 32`
- `EXACT_THRESHOLD = 0.08` (margin in normalized score space)
- `RESIDUAL_THRESHOLD = 0.20` (sketch-score quantile that promotes to residual)

These are tunable. The gate measures the post-tuning KL-divergence.

## §3. Pass/fail recipe (the test that decides)

A `#[test]` in `agent_core/tests/page_gather_shadow_escalation.rs` (lands in Phase B.G.B4) runs a controlled
retrieval/attention probe:

```rust
// 1. Build a synthetic corpus of P = 10_000 pages.
//    Each page is a 256-dim embedding (Model2Vec-shape) plus a
//    1024-dim "residual" body summary plus a 4096-dim "exact" body.
let corpus = SyntheticCorpus::build_seeded(P, sketch_dim=256,
    residual_dim=1024, exact_dim=4096, seed=0xABCD);

// 2. Generate Q = 200 ground-truth queries with known top-1 page.
let queries = SyntheticQuerySet::build_seeded(Q, ground_truth_topk=10,
    seed=0xDEF0);

// 3. For each query, compute the reference distribution (exact path
//    only — the oracle that the escalation policy must approximate).
let reference = queries.iter()
    .map(|q| exact_only_topk(q, &corpus, K=10))
    .collect::<Vec<_>>();

// 4. For each query, run the three-stage escalation pipeline.
let routed = queries.iter()
    .map(|q| three_stage_topk(q, &corpus, K=10, thresholds))
    .collect::<Vec<_>>();

// 5. Per-query KL divergence over the top-K score distributions.
let kl_per_query = reference.iter().zip(&routed)
    .map(|(r, x)| kl_divergence(softmax(&r.scores), softmax(&x.scores)))
    .collect::<Vec<f64>>();

let kl_mean = kl_per_query.iter().sum::<f64>() / Q as f64;
let kl_max = kl_per_query.iter().fold(0.0_f64, |a, &b| a.max(b));

// 6. Gate.
assert!(kl_mean < 0.06,
    "F-ShadowFirst-PageEscalation FAILED: KL/token mean = {} (budget < 0.06)",
    kl_mean);
assert!(kl_max < 0.20,
    "F-ShadowFirst-PageEscalation FAILED: KL/token max = {} (worst-case ceiling)",
    kl_max);
```

### §3.1 Synthetic corpus design

The synthetic corpus is constructed to stress the escalation policy:

- **Easy queries (40%)**: the top-1 reference page has a clear margin over second-place. Should escape on the
  sketch path; cheap.
- **Medium queries (40%)**: the top-1 reference page is in the top-5 by sketch score but not always #1.
  Should promote to residual + decide there.
- **Hard queries (20%)**: the top-1 reference page is in the top-32 by sketch score but not in the top-3.
  Should promote all the way to exact decode.

The escalation policy is supposed to spend cheap-path tokens on easy/medium queries and exact-path tokens only
on the 20% hard. Total exact-decode rate is also measured (must stay < 25% of queries).

## §4. M2 Pro 16 GB budget

| Metric | Budget |
|---|---|
| **KL/token mean** | < 0.06 (per §4.G ladder) |
| **KL/token max** (worst-case ceiling) | < 0.20 |
| **Exact-decode rate** | < 25% of queries |
| **Total wall-time per query (p99)** | < 5 ms |
| **Peak RAM during run** | < 1 GB (10k pages × 5380-dim float ≈ 215 MB sketches + residual + 50 MB working pool) |
| **SSD read bandwidth observed** | (informational; F-PageGather-M2Pro owns the bandwidth gate) |

## §5. Measurement methodology

Same warmup / iteration / median-of-3 / Spotlight-off discipline as F-UAS-ZeroCopy-Spine §4. Specific to this
gate:

- **Reference is the oracle**: the "exact path only" branch (full exact decode for every query) is the
  reference distribution. KL is measured against it, not against ground truth, because the escalation policy's
  job is to approximate the exact path while being cheaper — not to be perfect.
- **Per-difficulty-bucket KL** is reported: the harness emits `kl_mean[easy] / kl_mean[medium] / kl_mean[hard]`
  separately. A regression in hard-query KL is the most informative failure signal.
- **Seed reproducibility**: corpus + query seeds are logged. Failure includes the seed in the BLOCKER commit.
- **Threshold-sensitivity sweep**: when the gate fails, the harness automatically reruns with
  `EXACT_THRESHOLD ∈ {0.04, 0.08, 0.16, 0.32}` and `K_RESIDUAL ∈ {16, 32, 64}` to confirm the failure is
  policy-level, not a tuning-knob accident.

## §6. Fallback if the gate fails

Per §4.G "No silent skips":

1. **Identify the failure mode**.
   - **KL/token mean ≥ 0.06 across the board**: the sketch is too lossy to drive useful top-k. Investigate
     the INT8 quantization codec.
   - **KL/token mean high only on hard queries**: the residual layer is missing distinguishing information.
     Add channels or revisit the residual codec.
   - **Exact-decode rate ≥ 25%**: the `EXACT_THRESHOLD` is too tight or the score-margin metric is
     ill-conditioned.
   - **wall_us_p99 ≥ 5 ms**: the SSD-read path is bottlenecking. F-PageGather-M2Pro will catch the underlying
     bandwidth issue.
2. **Mitigation tier** (least invasive first):
   - **Tier 1 — threshold tune**: re-run with adjusted `EXACT_THRESHOLD` / `RESIDUAL_THRESHOLD` / `K_*`. If
     KL drops below 0.06 within the threshold sweep range, this is the fix.
   - **Tier 2 — codec swap**: replace INT8 sketch with INT4 (smaller) or fp8 (less lossy). Sherry 1.25-bit
     for the residual is the most promising swap candidate per the Sherry Lattice substrate (register row #31).
   - **Tier 3 — channel widening**: add a small bf16 "discriminator" channel that piggybacks on the sketch
     read and breaks ties cheaply without escalating to residual.
   - **Tier 4 — escalation-policy refactor**: switch from threshold-based to learned-policy (small classifier
     deciding sketch-vs-residual-vs-exact per query). Out-of-scope for v1; flag as research-tier follow-up.
   - **Tier 5 — STALLED**: file STALLED row #8 / #41 in canonical-doctrine §5 + BLOCKER commit. Do not push.
3. **Document the mitigation** on the source: `// F-ShadowFirst-PageEscalation: threshold tuned to 0.06 via
   sweep; see docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md §6.`

## §7. Acceptance bar (gate-pass criteria)

The gate **passes** when ALL of the following are true on M2 Pro 16 GB:

- [ ] `kl_mean < 0.06` over Q = 200 queries against the exact-path reference.
- [ ] `kl_max < 0.20` (worst-case ceiling).
- [ ] Per-difficulty-bucket: `kl_mean[easy] < 0.01`, `kl_mean[medium] < 0.05`, `kl_mean[hard] < 0.18`.
- [ ] Exact-decode rate < 25% of queries (the escalation policy must actually save cost on the easy/medium
  buckets).
- [ ] `wall_us_p99 < 5 ms` per query end-to-end.
- [ ] Peak RAM < 1 GB during the full harness run.
- [ ] Reproducibility: same seed produces same KL stats across 3 median-of-3 runs.
- [ ] `cargo test` count remains ≥ baseline + new tests. No regressions.
- [ ] Doctrine doc §5 register row #8 + #41 status updates from `not yet` → `landed`.
- [ ] `Co-Authored-By: Codex (T3)` on every commit.

## §8. Dependencies + downstream gates

**Depends on**:

- Phase B.G.B1: `UasAddress` (page identity).
- Phase B.G.B2: F-UAS-ZeroCopy-Spine pass (the sketch/residual/exact buffers are page-gather hot paths;
  failed zero-copy will mask the cost).
- Phase B.G.B3: F-ACS-Anchor-Addressing pass (each page carries an `AcsAnchor` with `tier` and `source_hash`;
  escalation policy may use `tier` as a prior).
- Existing infrastructure: `agent_core::helios::page_gather` (CPU scatter/gather reference) +
  `epistemos-research::shadow_memory::MemoryTier` (5-tier ladder doctrine) +
  `agent_core/src/research/sherry_lattice/` (1.25-bit residual codec, register row #31).

**Unblocks**:

- Gate #5 F-PageGather-M2Pro (the page-gather kernel's bandwidth target presumes the escalation policy is
  cost-effective; without that, raw bandwidth doesn't translate to system value).
- Vault retrieval repair (§4.H F-VaultRecall-50, T4-owned) — "Shadow Search 1.0" per the 2026-05-12 synthesis
  applies the same sketch/residual/exact idea to vault retrieval.

## §9. Cross-references

- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §4 ladder + §5 register row #7
  (Shadow Memory taxonomy) + #8 (HeliosPage) + #10 (PageGather) + #41 (HeliosPage three-stage).
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §A row #7-8-9-10 + §C gap list.
- Driver authority: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G ladder gate #4.
- Shadow Memory canon: `epistemos-research/src/shadow_memory.rs` (Lane 3 research-only 5-tier L0-L4) +
  `agent_core/src/shared_memory.rs` (L0 ExactHot active analog with drift gate
  `active_app_shmpool_implements_l0_exact_hot_only`).
- Sherry 1.25-bit residual codec: Huang et al. arXiv:2601.07892 + `agent_core/src/research/sherry_lattice/`.
- PageGather CPU reference: `agent_core/src/helios/page_gather.rs` (342 LOC).
- §4.H vault-retrieval cross-link: "Shadow Search 1.0" per `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md`.
