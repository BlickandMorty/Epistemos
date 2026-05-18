# Lattice-Wyner-Ziv / WBO Register - 2026-05-18

## Purpose

This register preserves the lattice/WBO lane as accounting substrate. It is not
a speed claim, not a kernel implementation plan, and not a replacement for UAS.
UAS names addressable residency; this document names the error law paid by each
compressed or approximate representation.

Canonical anchors:

- `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T17B.
- `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md`.
- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.2 line 79, §3.4 line 119, §3.8 line 175, §3.16 line 267, §3.18 line 302.
- `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §2 line 19, §4 line 49, §5 line 91.

Rust guard: `register_doc_canon_line_anchors_match_current_sources` asserts
that line anchors must resolve to the current canon section headings.

## Cross-Link Guardrails

| Canon source | Register use | Drift guard |
|---|---|---|
| `MASTER_FUSION` §3.2 line 79 Six-tier memory hierarchy | Supplies L0 / L1 / L2 / L3 / L4 / L5 / L_SE residency names and rate-distortion framing. | Residency names may route rows, but they do not waive codec, side-information, or WBO obligations. |
| `MASTER_FUSION` §3.4 line 119 SCOPE-Rex | Supplies the claim graph / state witness / execution substrate that can carry replayable WBO evidence. | SCOPE-Rex witness state is evidence transport, not proof that approximation drift is zero. |
| `MASTER_FUSION` §3.8 line 175 ACS doctrine row | Supplies the ACS governance lineage and the process-vs-structure naming disambiguation. | ACS admission can constrain a row, but it cannot replace the lattice/WBO error ledger. |
| `MASTER_FUSION` §3.16 line 267 Helios kernels | Supplies target-only kernel and M2 Pro hardware falsifier context. | Kernel targets are not runtime claims here; this register remains pure accounting substrate. |
| `MASTER_FUSION` §3.18 line 302 Provenance ledger | Supplies ClaimLedger / replay / retraction evidence surfaces for provider, adapter, and teacher rows. | Provenance proves what was observed or replayed; it does not collapse `T_S`, `T_SE`, or `T_num`. |
| `UNIFIED_ACTIVE_SUBSTRATE_CANON` §2 line 19 | Supplies the six canonical UAS-ACS surfaces. | UAS addressability is orthogonal to WBO drift accounting. |
| `UNIFIED_ACTIVE_SUBSTRATE_CANON` §4 line 49 | Supplies the no-loss cross-link map for UAS-ACS doctrine and code surfaces. | Cross-links preserve ownership; they must not promote research-only surfaces into product claims. |
| `UNIFIED_ACTIVE_SUBSTRATE_CANON` §5 line 91 | Supplies V1 / V1.x / V2 / never-ships tier sorting. | Ship-tier classification gates exposure, not the underlying WBO charge. |

## Invariants

1. `LatticeCoder<BITS>` is an abstraction over a rate-limited codec family, not
   a promise that every tier is literally decoded by the same lattice.
2. Lattice-Wyner-Ziv means the decoder uses model-side information. That side
   information can be residual stream state, decoder LM state, active support,
   or a cold oracle depending on the tier. It cannot borrow a weight-codec
   calibration Hessian to prove residual transfer.
3. Babai/GPTQ is the nearest-plane interpretation for weight quantization.
   Sherry, ShadowKV, QuIP/E8, residual sketches, NF4 SSD pages, and adapters
   are separate codecs with separate ledgers.
4. Weight quantization and KV quantization use different Hessians. Weight
   quantization uses a calibration Hessian; KV quantization uses runtime
   attention/KV curvature. Do not collapse `T_K` into Lattice-Wyner-Ziv or into
   the Babai/GPTQ weight lane.
5. The WBO post-correction is softmax-1/2: the ledger records pre-softmax
   contributions, then applies the 1/2 contraction after numerical correction.
   `T_num` is tracked as a numerical post-correction guard, not a seventh
   semantic WBO-6 term.

## WBO Term Obligation Map

| Term | Register obligation | Primary codec / lane | Required side information | Falsifier / verifier |
|---|---|---|---|---|
| `T_W` | Lattice/weight/runtime perturbation owed by Babai/GPTQ, QuIP/E8, Sherry weight lanes, and self-evolving adapter promotion | Babai/GPTQ nearest-plane; QuIP/E8; Sherry weight lane; L_SE adapter state | Calibration Hessian for weight codecs; surprise-gradient provenance for L_SE | `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness; adapter replay/provenance verifier |
| `T_K` | KV/cache compression and restore drift owed by ShadowKV, NF4 SSD pages, and KV-Direct residual reconstruction | ShadowKV sketch; L3 NF4 SSD Oracle; KV-Direct residual patch | Runtime attention/KV curvature, active-support mask, cold page oracle | `F-KV-Direct-Gate`; `F-WBO-DriftLedger` |
| `T_R` | Residual reconstruction gap owed by Lattice-Wyner-Ziv and residual sketches | `LatticeCoder<BITS>` residual lane; residual sketches | Decoder LM state plus residual stream witness | `F-WBO-DriftLedger`; residual KL slice |
| `T_Q` | Quantization approximation owed by NF4, Sherry, QuIP/E8, E8/Leech, and residual sketches | Sherry 3:4 sparse ternary; QuIP/E8; NF4 SSD Oracle; E8/Leech VQ | Codec-specific codebook, calibration statistics, or oracle page | `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness |
| `T_S` | Side-information, substrate-boundary, and active-support selection owed when the live path omits context or crosses a side-effect boundary | ShadowKV active support; L3 SSD Oracle; L4 Engram; L5 Network Cascade | Active-support budget, provenance edge, oracle page, or signed teacher witness | `F-ACS-AnchorLookup`; provider/provenance replay; `F-WBO-DriftLedger` |
| `T_SE` | Self-evolving, security, or sovereign enforcement owed when state changes authority or crosses protected execution | L_SE adapters; L5 teacher path; Sovereign/security gate | Surprise gradient, mutation envelope, signed claim ledger, capability witness | Adapter replay/provenance verifier; provider/provenance replay |
| `T_num` | Numerical guard applied before the post-softmax 1/2 contraction | Every tier, including exact hot L0 | IEEE/fp mode, softmax correction, per-token KL witness | `F-ULP-Oracle`; `F-WBO-DriftLedger` |

## Side-Information Decoding Kinds

| Rust kind | Decoding meaning | Must not be confused with |
|---|---|---|
| `None` | Exact live state is the reference path. | A missing ledger row. L0 still pays `T_num`. |
| `DecoderLmState` | The model's current decoder state helps reconstruct a rate-limited residual/state code. | Calibration Hessian or runtime KV curvature. |
| `ResidualStream` | Residual activations witness reconstruction of logits, K/V, or compressed residual deltas. | Weight-only quantization evidence. |
| `CalibrationHessian` | Offline Hessian/statistics used by Babai/GPTQ, QuIP/E8, or Sherry weight quantization. | Runtime KV Hessian. |
| `RuntimeKvHessian` | Runtime attention/KV curvature used by cache compression or restore accounting. | Offline calibration Hessian. |
| `ActiveSupport` | Retained-token/page mask plus active-support budget. | UAS residency itself; active support must still pay `T_S`. |
| `SsdOracle` | Cold exact or higher-fidelity page that decodes or verifies an L3 approximation. | Proof that NF4 pages are exact. |
| `StaticFactKey` | Content hash, static-fact key, or provenance edge used by L4 Engram lookup. | Dynamic reasoning, residual reconstruction, or exact recall of changing facts. |
| `NetworkTeacher` | Signed teacher/verifier output crossing the L5 boundary. | Local lattice decoding. |
| `SurpriseGradient` | L_SE adapter update evidence and replayable mutation state. | KV/cache compression. |

## Active-Support Budget Surface

`ActiveSupportBudget` is the required accounting surface when a row claims
`ActiveSupport` side information. It records:

| Field | Meaning | WBO obligation |
|---|---|---|
| `max_active_tokens` | Maximum retained tokens in the active support. | Prevents skipped tokens from disappearing outside `T_S`. |
| `max_active_pages` | Maximum retained pages or page groups. | Couples ShadowKV/L3 page selection to a falsifiable bound. |
| `max_resident_bytes` | Maximum resident bytes held hot for the selected support. | Separates UAS residency pressure from lattice error. |
| `side_information` | The decoding evidence kind for this active support. | Must be `ActiveSupport` for active-support rows. |

## Rust Validator Rules

The lightweight Rust module is ledger-only, but it rejects register rows that
would erase the error law:

| Guard | Rejected row shape |
|---|---|
| Canonical residency | `WboLedgerEntry::validate()` rejects tier labels outside `ResidencyTier::ALL`. |
| Residency-codec mapping | A row whose memory tier's primary codec differs from `ResidencyTier::primary_coder()` is rejected before it can borrow another tier's falsifier or side information; `ResidencyTier::primary_falsifier()` exposes the tier-owned hook directly. `ledger_validation_rejects_every_nonprimary_codec_for_every_residency_tier` asserts that every residency tier rejects every non-primary codec before side-information or falsifier borrowing. |
| Residency-term mapping | A row whose contribution term is outside `ResidencyTier::canonical_register_terms()` is rejected even if the codec family could use that term in another lane. `ledger_validation_rejects_every_term_outside_residency_tier_map` asserts that every residency tier rejects every contribution term outside its canonical map. |
| Residency side-information mapping | `ledger_validation_rejects_side_information_outside_residency_primary` asserts that a ledger row must use `ResidencyTier::primary_side_information()`, even when another side-information kind is legal for the codec family. `ledger_validation_rejects_every_nonprimary_side_information_for_every_residency_tier` asserts that every residency tier rejects every non-primary side-information kind. |
| Codec side-information map | `LatticeCoderKind::canonical_side_information()` defines the allowed side-information set for each codec family, rejecting unrelated witnesses even when they are valid for another codec. `budget_validation_rejects_every_noncanonical_side_information_for_every_codec` asserts that every codec row rejects every side-information witness outside its canonical set through the full `LatticeBudget::validate()` path. |
| Side-information ownership coverage | `typed_catalogs_assign_every_side_information_to_codec_rows` asserts that every `SideInformationKind::ALL` member has at least one codec owner; `residency_tier_side_information_matches_primary_codec_catalog` asserts that each residency primary side-information kind is accepted by that tier's primary codec. |
| Residency witness catalog | `ResidencyTier::side_information_witnesses()` records the full per-tier witness set while `ResidencyTier::primary_side_information()` remains the validation key; `residency_tier_catalog_maps_every_tier_to_side_information_witnesses` pins L1 residual stream plus decoder LM state and L3 SSD oracle plus residual reconstruction witness. |
| Crossed Hessian domains | Weight codecs reject `RuntimeKvHessian`; KV/cache codecs reject `CalibrationHessian`; `codec_side_information_catalog_keeps_hessian_domains_disjoint` asserts no codec declares both Hessian domains. |
| Weight/KV term split | `weight_codec_catalogs_do_not_claim_kv_cache_terms` asserts that weight-codec lanes do not claim `T_K`; ShadowKV and NF4 SSD Oracle own cache/offload `T_K` rows. |
| Exact hot side information | `ExactHot` accepts only `None`, because L0 is the reference path. |
| Boundary side information | `EngramHashRecall` accepts `StaticFactKey`; `NetworkCascade` accepts `NetworkTeacher`; `SelfEvolvingAdapter` accepts `SurpriseGradient`. |
| Active-support budget | Rows with `ActiveSupport` side information require an `ActiveSupportBudget` whose token, page, and resident-byte axes are each nonzero and whose own side information is also `ActiveSupport`; only `L2 Shadow Sketch` and `L3 SSD Oracle` rows may carry this budget surface. `residency_tier_catalog_marks_active_support_budget_tiers` asserts that the exact active-support budget tier set is `L2 Shadow Sketch` and `L3 SSD Oracle`. `ledger_validation_rejects_every_non_active_support_budget_side_information` asserts that the secondary `ActiveSupportBudget` rejects every non-`ActiveSupport` side-information tag. `ledger_validation_rejects_partial_zero_active_support_axes` pins the axis-level guard. |
| Active-support boundary term | `ledger_validation_rejects_active_support_budget_without_substrate_boundary_term` asserts that any row carrying `ActiveSupportBudget` must include `T_S`; otherwise validation returns `MissingSubstrateBoundaryTerm`. `residency_tier_catalog_requires_substrate_boundary_for_active_support_budget_tiers` asserts that active-support-capable residency tiers must own `T_S`. |
| Mixed side information | Rows may pair another primary side-information kind with `ActiveSupportBudget`, but the secondary active-support budget must still have each active-support axis nonzero and be tagged `ActiveSupport`. `ledger_validation_allows_l3_ssd_oracle_without_active_support_budget` pins the no-secondary-budget case. L3 SSD Oracle keeps `SsdOracle` as primary side information; `ActiveSupportBudget` is allowed but optional. |
| Falsifier hook | A nonempty falsifier string must mention at least one canonical hook from the row's `LatticeCoderKind::falsifier()`; `falsifier_hook_matching_rejects_substring_collisions` rejects spoofed substrings such as noncanonical prefixes or suffixed hook variants, and `ledger_validation_rejects_spoofed_ulp_oracle_hook` verifies that the ledger path rejects a spoofed `F-ULP-Oracle`. |
| WBO drift ledger hook | `ledger_validation_requires_wbo_drift_ledger_for_every_row` asserts that Every ledger row must name `F-WBO-DriftLedger`; `wbo_term_catalog_requires_drift_ledger_for_every_axis` asserts that every WBO term falsifier includes `F-WBO-DriftLedger`; term-specific hooks such as `F-ULP-Oracle`, `F-KV-Direct-Gate`, or `F-ACS-AnchorLookup` are additive rather than substitutes. |
| Falsifier owner registry | `FALSIFIER_HOOK_OWNERS` assigns every cataloged `F-*` hook to an owner path; `falsifier_hook_registry_owns_every_f_hook_named_by_catalogs` asserts every hook named by codec, term, or residency catalogs has an owner and every owner is still used. `falsifier_hook_registry_owner_paths_exist` asserts that each falsifier owner path resolves to an existing repo file. `register_doc_f_hooks_are_owned_by_registry` asserts that every concrete register `F-*` hook has a registry owner. |
| KV direct gate hook | `ledger_validation_requires_kv_direct_gate_for_kv_cache_term` asserts that KV/cache ledger rows must name `F-KV-Direct-Gate`; `F-WBO-DriftLedger` alone cannot witness `T_K`. |
| Residual KL hook | `ledger_validation_requires_residual_kl_slice_for_residual_term` asserts that T_R ledger rows must name residual KL slice; `F-WBO-DriftLedger` alone cannot witness residual reconstruction. |
| Quantization reconstruction hook | `ledger_validation_requires_layerwise_reconstruction_for_quantization_term` asserts that T_Q ledger rows must name layerwise reconstruction/logit drift witness; `F-WBO-DriftLedger` alone cannot witness quantization approximation. |
| Weight/runtime reconstruction hook | `ledger_validation_requires_layerwise_reconstruction_for_weight_runtime_term` asserts that T_W ledger rows must name layerwise reconstruction/logit drift witness; `F-WBO-DriftLedger` alone cannot witness weight/runtime perturbation. |
| Substrate anchor hook | `ledger_validation_requires_anchor_lookup_for_substrate_boundary_term` asserts that T_S ledger rows must name `F-ACS-AnchorLookup`; `F-WBO-DriftLedger` alone cannot witness side-information or active-support boundary accounting. |
| Security/provenance verifier hook | `ledger_validation_requires_term_specific_security_verifier_for_t_se` asserts that T_SE ledger rows must name provider/provenance replay or adapter replay/provenance verifier according to the tier; `F-WBO-DriftLedger` alone cannot witness security or self-evolving provenance. |
| Contribution-term falsifier hook | `ledger_validation_requires_term_falsifier_hook_for_each_contribution` asserts that the row falsifier also covers each actual contribution term's `WboTermCode::falsifier()` hook. |
| Numerical post-correction hook | `ledger_validation_requires_numerical_post_correction_contribution` asserts that a ledger row must include `T_num` and returns `MissingNumericalPostCorrectionTerm` when it does not; `LatticeBudget::validate()` rejects budgets without `T_num`; `ledger_validation_requires_ulp_oracle_for_numerical_post_correction` asserts that any row containing `T_num` must name `F-ULP-Oracle`; `residency_tier_catalog_attaches_numerical_guard_to_every_tier` and `lattice_coder_catalog_attaches_numerical_guard_to_every_codec` assert that every typed tier and codec carries `T_num`; `register_doc_requires_ulp_oracle_on_t_num_table_rows` applies the same guard to register-like Markdown table rows; `register_doc_codec_falsifier_table_names_ulp_oracle_for_t_num_codecs` applies it to the codec-falsifier coverage table. `F-WBO-DriftLedger` alone is insufficient. |
| Codec term coverage | Every contribution term must belong to `LatticeCoderKind::canonical_wbo_terms()` for the row's codec. |
| Codec-term falsifier coverage | `codec_falsifiers_cover_every_canonical_term_falsifier` asserts that every codec-owned WBO term has at least one matching falsifier hook in the codec catalog. |
| Term ownership coverage | `typed_catalogs_assign_every_wbo_term_to_codec_and_residency_rows` asserts that every `WboTermCode::ALL` member appears in at least one codec map and at least one residency-tier row. |
| Register doc coverage | `register_doc_names_every_residency_tier_and_wbo_term` and `register_doc_names_every_codec_and_side_information_kind` assert that the Markdown register still names every canonical residency tier, `WboTermCode::ALL` term row, codec variant, and side-information kind. |
| Standalone budget validation | `LatticeBudget::validate()` rejects empty contribution lists even before the budget is wrapped in a `WboLedgerEntry`; `lattice_budget_composition_rejects_empty_public_contributions` asserts that the public composition validator rejects the same empty list, and `lattice_budget_measured_status_returns_none_for_empty_public_contributions` asserts that empty public contribution lists cannot report measured success. |
| Contribution field validation | `lattice_budget_validation_rejects_signed_contribution_fields_even_when_totals_cancel` asserts that public struct literals cannot bypass the nonnegative finite budget and measured-value guards by offsetting one signed contribution with another. `contribution_measured_status_returns_none_for_invalid_public_fields` and `lattice_budget_measured_status_returns_none_for_invalid_public_fields` assert that measured status methods return pending instead of success when public fields contain invalid signed values. |
| Budget edge validation | `lattice_budget_validation_accepts_zero_and_single_max_budget_edges` asserts that zero-budget exact numerics and one finite `f64::MAX` contribution remain valid, while aggregate overflow is still rejected by composition validation. `lattice_budget_measured_status_returns_none_for_overflowed_totals` asserts that overflowed aggregate totals cannot report `measured_within_budget()` success. |
| Rate parameter ownership | `LatticeBudget::validate_rate()` uses `LatticeCoderKind::allows_rate_parameter()` to reject zero rates and reject `rate_milli_bits_per_symbol` on non-rate codecs such as exact hot, Engram, network cascade, or self-evolving adapter rows; `budget_validation_rejects_zero_explicit_rate`, `budget_validation_accepts_nonzero_rate_on_rate_codecs`, and `budget_validation_rejects_rate_on_non_rate_codecs` pin those cases. `lattice_coder_catalog_marks_rate_bearing_codecs` asserts that the exact rate-bearing codec set includes standalone `NestedE8` and `NestedLeech24` rows. |

The hook check is intentionally substring-based and case-insensitive so docs can
name compound verifier strings such as `F-KV-Direct-Gate; F-WBO-DriftLedger`
without forcing a separate parser. It is still strict enough to reject a row
whose verifier belongs to a different codec lane.

## Measured Budget Semantics

`LatticeErrorContribution` stores a reserved budget and an optional measured
value. `LatticeBudget` composes measured totals only when every contribution in
the row has a measurement:

| Rust helper | Meaning |
|---|---|
| `WboTermCode::SEMANTIC_WBO6` | The six semantic terms `T_W` / `T_K` / `T_R` / `T_Q` / `T_S` / `T_SE`; excludes `T_num`. |
| `WboTermCode::is_semantic_wbo6()` | Returns false for `T_num` so numerical post-correction cannot become a seventh semantic term. |
| `WboTermCode::falsifier()` | Names the verifier hook for each WBO term, including `F-KV-Direct-Gate` for `T_K` and `F-ULP-Oracle` for `T_num`. |
| `pre_softmax_budget()` | Sum of reserved pre-softmax contribution budgets. |
| `semantic_wbo6_pre_softmax_budget()` | Sum of reserved pre-softmax contribution budgets whose terms are in semantic WBO-6 only. |
| `numerical_post_correction_budget()` | Sum of reserved `T_num` guard budget before the softmax-1/2 correction; not a semantic WBO-6 term. |
| `softmax_half_corrected_budget()` | Reserved budget after the WBO softmax-1/2 correction. |
| `measured_pre_softmax_total()` | `Some(total)` only when every contribution has `measured`; otherwise `None`. `lattice_budget_measured_total_includes_numerical_post_correction` pins that complete measured totals include `T_num` even though the semantic WBO-6 slice excludes it. |
| `measured_softmax_half_corrected_total()` | Measured total after the 1/2 correction, only when complete. |
| `measured_within_budget()` | `Some(true/false)` only when measured data is complete; unmeasured rows stay pending instead of silently passing. |

The reserved semantic WBO-6 slice plus the reserved `T_num` slice must conserve
the full pre-softmax budget. `lattice_budget_slice_partition_is_order_invariant_across_all_axes`
asserts that semantic plus numerical slices conserve the total across reordered and duplicated axes. `T_num` is a numerical guard partition, not a semantic
seventh term.

`LatticeBudget::validate()` also rejects non-finite composed totals. A row may
reserve a finite per-term budget, but if the aggregate pre-softmax or
softmax-half-corrected total overflows, the row is invalid until it is split or
renormalized.

## Register

| Memory tier | Codec / representation | Side information | WBO term(s) | Falsifier / verifier | Canonical caveat |
|---|---|---|---|---|---|
| L0 RAM hot | Exact fp16/bf16 KV and residual stream | None beyond live model state | `T_num` only | `F-WBO-DriftLedger`; `F-ULP-Oracle`; per-token KL witness | Exact hot state is the reference path. It can pay numerical drift, but it must not hide codec error. |
| L1 Compressed Residual | Lattice-Wyner-Ziv residual codec under `LatticeCoder<1250 milli-bits>` | Residual stream plus decoder LM state | `T_R` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; residual KL slice from `F-KV-Direct-Gate`; layerwise reconstruction/logit drift witness before any runtime claim | Sherry is a WEIGHT codec; its public results are weight-side at calibration time. L1 residual rows CANNOT borrow Sherry's calibration Hessian as proof of residual transfer. |
| L2 Shadow Sketch | ShadowKV-style active-support sketch: retained pages/tokens plus residual or JL/CountSketch correction | Active support mask, page criticality, residual sketch | `T_K` + `T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-KV-Direct-Gate`; `F-ACS-AnchorLookup` when K/V reconstruction is claimed | ShadowKV is a KV/cache selectivity lane, not the Halo lexical shadow. It reduces active support only after the skipped support is charged to the ledger. |
| L3 SSD Oracle | NF4 mmap/IOSurface pages with cold exact-or-higher-fidelity page oracle | SSD oracle page plus residual stream reconstruction witness | `T_K` + `T_Q` + `T_S` + `T_num` | `F-KV-Direct-Gate`; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness; `F-ACS-AnchorLookup`; per-token KL witness | L3 is a residency/offload tier, not a proof that SSD pages are semantically exact. NF4 and page faults still pay cache, quantization, and substrate-boundary terms. |
| L4 Engram | Fixed-budget hash recall for static facts, signatures, dates, and API contracts | Content hash, provenance edge, static-fact key | `T_S` + `T_num` | `F-ACS-AnchorLookup`; `F-ULP-Oracle`; `F-WBO-DriftLedger` if retrieved facts steer generation | O(1) means hash-table lookup only. It does not make dynamic reasoning exact and it does not replace residual/KV accounting. |
| L5 Network Cascade | Outlier escalation to larger/cloud teacher or cross-model verifier | Network teacher output, signed provenance, claim ledger witness | `T_S` + `T_SE` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; provider/provenance replay checks | Network cascade is a side-effect boundary. It can verify or supply an answer, but it is not local lattice decoding and must return witnessed claims. |
| L_SE Self-Evolving | Titans-MAC / SEAL-DoRA adapter or surprise-gradient state | Surprise gradient, adapter provenance, replayable mutation envelope | `T_W` + `T_SE` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; adapter replay/provenance verifier; layerwise reconstruction/logit drift witness before promotion | Self-evolving state changes the effective runtime model. It is not KV compression and must never be silently folded into `T_K` or `T_R`. |

## Codec Register

| Codec | Canonical interpretation | Side information | WBO term(s) | Falsifier / verifier | Caveat |
|---|---|---|---|---|---|
| Babai/GPTQ nearest-plane | Weight quantization as nearest-plane rounding in a Hessian-induced lattice | Calibration Hessian from the weight quantization calibration set | `T_W` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness; layerwise KL/logit drift harness | Babai/GPTQ nearest-plane is a calibration-Hessian weight codec, not a `LatticeCoder<BITS>` rate abstraction. Calibration Hessian is offline weight-side geometry. It is not the runtime KV Hessian and must not be reused to justify `T_K`. |
| Sherry 3:4 sparse ternary | 1.25-bit sparse ternary lattice packing used as a weight-codec reference only | Calibration Hessian for weight lanes | `T_W` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness | Sherry is weight-side only. Residual-stream compression must use the Lattice-Wyner-Ziv row and its own residual KL witness. |
| QuIP/E8 | Incoherence rotation plus E8-style lattice codebook for weight blocks | Calibration Hessian / whitening statistics | `T_W` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness | QuIP/E8 is a weight-codec lane. Its E8 geometry does not imply that KV pages or residual streams share the same Hessian or codebook. |
| Nested E8 | Standalone nested-lattice E8 vector quantization lane with its own rate ownership, separate from QuIP/E8 | Calibration Hessian / whitening statistics for the NestedE8 weight blocks | `T_W` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness; `F-ULP-Oracle` for `T_num` | NestedE8 is not a QuIP/E8 subfamily. It shares the falsifier family, but owns a separate rate row and reconstruction error profile. |
| Nested Leech24 | Standalone nested-lattice Leech_24 vector quantization lane with its own rate ownership, separate from QuIP/E8 | Calibration Hessian / whitening statistics for the NestedLeech24 weight blocks | `T_W` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness; `F-ULP-Oracle` for `T_num` | NestedLeech24 is not a QuIP/E8 subfamily. It shares the falsifier family, but owns a separate rate row and Leech_24 reconstruction error profile. |
| Lattice-Wyner-Ziv / `LatticeCoder<BITS>` | Rate-limited residual or state codec decoded with model side information | Decoder LM state, residual stream, active support, or oracle page depending on tier | `T_R` + tier-specific `T_K`/`T_Q`/`T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; tier-specific KL/reconstruction witness; layerwise reconstruction/logit drift witness when `T_Q` is claimed | `BITS` is an accounting rate parameter. Side information is load-bearing and must be named per row. |
| Residual sketch | JL / CountSketch / FRP-shaped correction stream attached to a compressed residual or KV restore path | Residual stream witness plus decoder LM state; active-support mask when the sketch repairs skipped support | `T_R` + `T_Q` + tier-specific `T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; tier-specific reconstruction witness; layerwise reconstruction/logit drift witness before any speed or memory claim | A sketch is a correction witness, not proof that omitted residual mass vanished. If it repairs KV/cache state it must also name the `T_K` owner row instead of hiding under generic Lattice-Wyner-Ziv language. |
| Engram hash recall | Fixed-budget static-fact hash lookup for signatures, dates, API contracts, and never-recompute knowledge | `StaticFactKey`, content hash, and provenance edge | `T_S` + `T_num` | `F-ACS-AnchorLookup`; `F-ULP-Oracle`; `F-WBO-DriftLedger` when retrieved facts steer generation | O(1) is hash-table lookup only. It does not make dynamic facts exact, and it cannot replace residual, KV, or network-teacher accounting. |
| Network cascade | Outlier escalation to a larger model, cloud teacher, or cross-model verifier at the L5 boundary | Signed teacher output, provider receipt, claim ledger witness, and replayable provenance | `T_S` + `T_SE` + `T_num` | Provider/provenance replay; `F-ULP-Oracle`; `F-WBO-DriftLedger`; `F-ACS-AnchorLookup` when teacher output steers logits or claims | The cascade is a side-effect and authority boundary, not a local decoder. It may verify or supply claims only when the returned evidence is typed and replayable. |
| Self-evolving adapter | Titans-MAC / SEAL-DoRA / QDoRA-style adapter state that mutates the effective runtime model | Surprise gradient, adapter provenance, replayable mutation envelope, and promotion witness | `T_W` + `T_SE` + `T_num` | Adapter replay/provenance verifier; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness before promotion | Adapter state changes model weights or effective weight deltas. It is not KV/cache compression, and it must not be charged to `T_K` or hidden as residual reconstruction. |

## Codec-to-Falsifier Coverage

| Rust `LatticeCoderKind` | Canonical row owner | Falsifier / verifier |
|---|---|---|
| `ExactHot` | L0 RAM hot | `F-WBO-DriftLedger`; `F-ULP-Oracle` for numerical guard |
| `LatticeWynerZivResidual` | L1 Compressed Residual; Lattice-Wyner-Ziv codec row | `F-WBO-DriftLedger`; `F-ULP-Oracle`; residual KL slice; layerwise reconstruction/logit drift witness; `F-ACS-AnchorLookup` when `T_S` is claimed |
| `BabaiGptqNearestPlane` | Babai/GPTQ nearest-plane codec row | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness |
| `SherryTernary3Of4` | Sherry weight-codec row | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness |
| `ShadowKvSketch` | L2 Shadow Sketch | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-KV-Direct-Gate`; `F-ACS-AnchorLookup` when K/V reconstruction is claimed |
| `EngramHashRecall` | L4 Engram | `F-ACS-AnchorLookup`; `F-ULP-Oracle`; `F-WBO-DriftLedger` when retrieved facts steer generation |
| `NestedE8` | Nested E8 standalone codec row | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness |
| `NestedLeech24` | Nested Leech24 standalone codec row | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness |
| `QuipE8` | QuIP/E8 codec row | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness |
| `Nf4SsdOracle` | L3 SSD Oracle | `F-KV-Direct-Gate`; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness; `F-ACS-AnchorLookup` |
| `ResidualSketch` | Lattice-Wyner-Ziv residual/sketch lane | `F-WBO-DriftLedger`; `F-ULP-Oracle`; tier-specific reconstruction witness; `F-ACS-AnchorLookup` |
| `NetworkCascade` | L5 Network Cascade | Provider/provenance replay; `F-ULP-Oracle`; `F-WBO-DriftLedger`; `F-ACS-AnchorLookup` |
| `SelfEvolvingAdapter` | L_SE Self-Evolving | Adapter replay/provenance verifier; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness |
