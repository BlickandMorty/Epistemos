//! Register doc cross-link tests: canonical headings, witness contracts, and tier-aligned row order.

use super::*;

#[test]
fn register_doc_preserves_required_canon_cross_links_and_caveats() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let required = [
        "`docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 line 367",
        "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.2",
        "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.4",
        "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.8",
        "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.16",
        "`docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.18",
        "`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §2",
        "`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §4",
        "`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §5",
        "`register_doc_canon_line_anchors_match_current_sources`",
        "line anchors must resolve to the current canon section headings",
        "cross-link guardrail rows include concrete `line N` anchors",
        "UAS §2, §4, and §5 line anchors are checked against current headings",
        "MASTER_FUSION §3.2, §3.4, §3.8, §3.16, and §3.18 line anchors are checked against current headings",
        "`register_doc_canonical_anchor_list_matches_guardrail_rows`",
        "canonical-anchor list and cross-link guardrail table line anchors share the same source/section/line triples",
        "`register_doc_cross_link_rows_name_current_canon_headings`",
        "cross-link guardrail row titles mirror the current source headings",
        "`LatticeCoder<BITS>` is an abstraction",
        "It cannot borrow a weight-codec",
        "Weight quantization and KV quantization use different Hessians",
        "`ResidencyTier::primary_falsifier()`",
        "`residency_tier_catalog_maps_every_tier_to_primary_falsifier`",
        "every residency primary falsifier equals its primary codec falsifier",
        "`wbo_ledger_entry_new_for_tier_serializes_canonical_memory_tier_names`",
        "`WboLedgerEntry::new_for_tier()` serializes every `memory_tier` as `ResidencyTier::canonical_name()`",
        "`ledger_validation_rejects_residency_debug_labels`",
        "every `ResidencyTier` debug label is rejected as `UnknownResidencyTier`",
        "`residency_tier_canonical_names_are_trimmed_and_display_safe`",
        "canonical residency names are trimmed, nonempty, ASCII, and free of debug-only enum spelling",
        "`wbo_ledger_entry_serializes_public_accounting_keys`",
        "WboLedgerEntry serializes only `memory_tier`, `budget`, `active_support`, `falsifier`, and `caveat` public keys",
        "`wbo_ledger_entry_json_rejects_invalid_public_rows`",
        "ledger JSON rejects blank row fields, missing `F-ULP-Oracle`, and missing required active support before becoming a public row",
        "`wbo_ledger_entry_serializes_absent_active_support_as_null`",
        "ledger rows without secondary active support keep `active_support` as null",
        "`public_accounting_json_rejects_unknown_fields`",
        "public accounting JSON rejects unknown fields on contribution, budget, active-support budget, ledger-entry, and owner surfaces",
        "`public_accounting_json_rejects_nested_unknown_fields`",
        "public accounting JSON rejects nested unknown fields inside standalone and ledger budget contributions plus ledger active-support budgets",
        "`public_accounting_json_rejects_duplicate_public_keys`",
        "public JSON rows reject duplicate public keys before validation",
        "duplicate-key guard covers nullable public keys and owner paths",
        "`public_accounting_json_rejects_missing_required_keys`",
        "public JSON rows reject missing required keys before validation",
        "missing-key matrix removes every public top-level key",
        "optional public null keys must still be present explicitly",
        "`public_accounting_json_rejects_wrong_type_public_fields`",
        "public JSON rows reject wrong-type public fields before validation",
        "wrong-type guard covers nullable measured and rate fields",
        "wrong-type caveat fields",
        "`lattice_budget_json_rejects_invalid_public_envelopes`",
        "budget JSON rejects empty contribution lists, missing `T_num`, and wrong side-information before becoming a public budget envelope",
        "`lattice_coder_canonical_names_are_trimmed_kebab_case_keys`",
        "canonical codec names are trimmed, nonempty, ASCII kebab-case keys and free of debug-only enum spelling",
        "`lattice_coder_json_uses_canonical_keys_and_rejects_debug_labels`",
        "codec JSON emits and accepts only canonical kebab-case keys; debug enum labels and spoofed case/spacing/separator keys are rejected",
        "`LatticeCoderKind::canonical_side_information()`",
        "`budget_validation_accepts_canonical_side_information_by_codec`",
        "`register_doc_side_information_rows_follow_catalog_order`",
        "side-information register order follows `SideInformationKind::ALL`",
        "`side_information_json_uses_explicit_public_keys`",
        "side-information JSON emits and accepts only explicit public witness keys; spacing, kebab-case, acronym, and prose spoof keys are rejected",
        "`ledger_validation_rejects_every_nonprimary_codec_for_every_residency_tier`",
        "every residency tier rejects every non-primary codec before side-information or falsifier borrowing",
        "non-primary codecs still fail when borrowing the tier primary side-information and falsifier",
        "`ledger_validation_rejects_nonprimary_codec_before_foreign_terms`",
        "non-primary codecs fail before simultaneous residency-term mismatches",
        "`ledger_validation_rejects_every_term_outside_residency_tier_map`",
        "every residency tier rejects every contribution term outside its canonical map",
        "the exhaustive residency-term fixture includes primary-codec-owned terms that remain tier-foreign",
        "`ledger_validation_rejects_missing_non_numerical_residency_terms`",
        "typed residency rows reject sparse rows that omit tier-owned non-`T_num` axes",
        "`ledger_validation_rejects_foreign_terms_before_nonprimary_side_information`",
        "foreign residency terms fail before simultaneous non-primary side-information mismatches",
        "`lattice_budget_validation_rejects_terms_outside_codec_map`",
        "full `LatticeBudget::validate()` and public `validate_composition()` paths",
        "`lattice_budget_validation_rejects_foreign_terms_before_missing_t_num`",
        "foreign codec terms fail before missing numerical post-correction",
        "measured invalid-term fixture also exercises public `validate_composition()` rejection",
        "`budget_validation_rejects_every_noncanonical_side_information_for_every_codec`",
        "every codec row rejects every side-information witness outside its canonical set",
        "full `LatticeBudget::validate()`, public `validate_composition()`, and direct `validate_side_information()` paths",
        "direct `validate_side_information()` rejects the same noncanonical codec witnesses",
        "`budget_validation_rejects_wrong_side_information_before_term_mismatch`",
        "wrong side-information is rejected before a simultaneous foreign-term mismatch",
        "`budget_validation_rejects_every_wrong_side_information_before_term_mismatch`",
        "every noncanonical side-information witness is rejected before simultaneous codec-term mismatches",
        "`lattice_budget_json_rejects_every_codec_wrong_side_information_fixture`",
        "every wrong codec/witness pair also fails public `LatticeBudget` JSON deserialization",
        "wrong-side-info adversarial family covers direct, full, composition, JSON, and measured-status pending paths",
        "measured invalid-side-information fixtures also exercise public `validate_composition()` rejection",
        "`ledger_validation_rejects_side_information_outside_residency_primary`",
        "`ledger_validation_rejects_every_nonprimary_side_information_for_every_residency_tier`",
        "every residency tier rejects every non-primary side-information kind",
        "the exhaustive residency side-information fixture includes primary-codec-accepted witnesses that remain tier-nonprimary",
        "`typed_catalogs_assign_every_side_information_to_codec_rows`",
        "`residency_tier_side_information_matches_primary_codec_catalog`",
        "`ResidencyTier::side_information_witnesses()`",
        "`residency_tier_catalog_maps_every_tier_to_side_information_witnesses`",
        "`residency_tier_side_information_witnesses_match_primary_codec_catalog`",
        "`register_doc_residency_side_information_cells_follow_witness_order`",
        "residency register side-information cells preserve `ResidencyTier::side_information_witnesses()` order",
        "every residency side-information witness is accepted by that tier's primary codec",
        "`ledger_validation_allows_mixed_side_information_with_valid_active_support_budget`",
        "mixed primary side-information rows with valid secondary `ActiveSupportBudget` validate",
        "`ledger_validation_allows_l3_ssd_oracle_without_active_support_budget`",
        "`ledger_validation_allows_max_active_support_budget_without_lattice_overflow`",
        "max-valued secondary active-support axes validate without entering lattice measured totals",
        "`codec_side_information_catalog_keeps_hessian_domains_disjoint`",
        "`weight_codec_catalogs_do_not_claim_kv_cache_terms`",
        "`codec_falsifiers_cover_every_canonical_term_falsifier`",
        "`register_doc_names_every_residency_tier_and_wbo_term`",
        "`register_doc_names_every_codec_and_side_information_kind`",
        "`register_doc_names_every_lattice_wbo_error_variant`",
        "every `LatticeWboError::ALL` variant has one register error row",
        "error variant register rejects stale rows outside `LatticeWboError::ALL`",
        "`register_doc_residency_falsifier_cells_follow_primary_and_term_hook_order`",
        "residency register falsifier cells preserve primary and term `F-*` hook order",
        "`register_doc_error_variant_rows_follow_lattice_wbo_error_all_order`",
        "error variant register order follows `LatticeWboError::ALL`",
        "`lattice_wbo_error_json_uses_explicit_public_keys`",
        "LatticeWboError JSON emits and accepts only explicit public error keys; lowercase, prose, dashed, and spaced spoof keys are rejected",
        "`typed_all_catalogs_have_unique_public_keys`",
        "typed ALL catalogs keep unique residency, codec, side-information, term, and error public keys",
        "`explicit_public_key_tables_follow_all_catalog_order`",
        "explicit public key tables follow their typed ALL catalog order for residency, codec, side-information, WBO term, and error registries",
        "explicit public key tables are exact, non-normalizing surfaces; padded, blank, case-shifted, or separator-shifted keys remain invalid",
        "`LatticeCoderKind::primary_residency_tier()`",
        "standalone weight/sketch codec rows return `None`",
        "cannot silently promote into product lanes",
        "`public_key_registries_deserialize_from_owned_json_values`",
        "public key registries deserialize from owned JSON values for residency, codec, side-information, WBO term, and error keys",
        "`public_key_registries_reject_wrong_type_json_values`",
        "public key registries reject wrong-type JSON values before string-key lookup",
        "`public_key_registries_reject_cross_registry_keys`",
        "public key registries reject keys owned by every other WBO registry",
        "`public_key_registries_reject_unicode_adjacent_public_keys`",
        "unicode-adjacent canonical keys stay invalid",
        "`wbo_term_codes_are_trimmed_ascii_axis_keys`",
        "WBO term codes are trimmed, nonempty, ASCII axis keys and free of debug-only enum spelling",
        "`wbo_term_code_json_uses_public_axis_keys_and_rejects_debug_labels`",
        "WBO term JSON emits and accepts only public `T_*` axis keys; debug enum labels and spoofed case/whitespace keys are rejected",
        "`register_doc_wbo_term_rows_follow_catalog_order`",
        "WBO term register order follows `WboTermCode::ALL`",
        "`register_doc_residency_rows_follow_catalog_order`",
        "residency register order follows `ResidencyTier::ALL`",
        "`register_doc_codec_rows_follow_catalog_order`",
        "codec coverage order follows `LatticeCoderKind::ALL`",
        "exact residency-to-side-information witness set",
        "residency register side-information cells name the primary validation key before secondary witnesses",
        "exact residency-to-falsifier `F-*` hook set",
        "residency register falsifier cells match primary and term `F-*` hook sets exactly",
        "exact term-to-falsifier `F-*` hook set",
        "WBO term falsifier cells match typed `F-*` hook sets exactly",
        "codec coverage term cells match typed `canonical_wbo_terms()` exactly",
        "codec coverage term cells preserve `canonical_wbo_terms()` order",
        "exact codec-to-falsifier `F-*` hook set",
        "exact codec-to-side-information witness set",
        "side-information register owner cells match typed codec witness sets exactly",
        "side-information register owner cells preserve `LatticeCoderKind::ALL` order",
        "`lattice_budget_serializes_public_accounting_keys`",
        "LatticeBudget serializes only `coder`, `rate_milli_bits_per_symbol`, `side_information`, and `contributions` public keys",
        "`lattice_budget_composition_rejects_empty_public_contributions`",
        "`lattice_budget_composition_requires_numerical_post_correction_term`",
        "`lattice_budget_composition_rejects_empty_source_public_contributions`",
        "empty-source composition fixture also exercises full `LatticeBudget::validate()` rejection",
        "`lattice_budget_measured_status_returns_none_for_empty_public_contributions`",
        "semantic and numerical measured slices also remain pending for empty public contribution lists",
        "empty public-contribution measured-status fixture also exercises public `validate_composition()` rejection",
        "`lattice_budget_validate_combines_rate_and_side_information_guards`",
        "combined budget guard fixture rejects empty, invalid-rate, and invalid side-information rows independently",
        "`lattice_budget_composition_handles_signed_max_and_mixed_axes`",
        "signed, max, and mixed semantic/numerical axes are validated together",
        "single finite max mixed-axis fixture pins semantic and `T_num` measured partitions before overflow guard",
        "signed mixed-axis invalid public fields keep every measured-status surface pending",
        "`lattice_budget_composition_rejects_axis_local_overflow_slices`",
        "semantic-only and numerical-only duplicate max overflows both keep measured surfaces pending",
        "`lattice_budget_validation_accepts_zero_and_single_max_budget_edges`",
        "`lattice_budget_validation_rejects_signed_contribution_fields_even_when_totals_cancel`",
        "`lattice_error_contribution_serializes_public_accounting_keys`",
        "LatticeErrorContribution serializes only `term`, `source`, `budget`, and `measured` public keys",
        "`lattice_error_contribution_json_rejects_invalid_public_fields`",
        "contribution JSON rejects negative budget, negative measured, blank source, and wrong-type budget/measured fields",
        "`contribution_measured_status_returns_none_for_invalid_public_fields`",
        "`lattice_budget_measured_status_returns_none_for_invalid_public_fields`",
        "semantic and numerical measured slices also remain pending when public fields are invalid",
        "invalid public-field measured-status fixture also exercises public `validate_composition()` rejection",
        "`lattice_budget_measured_status_returns_none_for_invalid_side_information`",
        "semantic and numerical measured slices also remain pending when side-information ownership is invalid",
        "`lattice_budget_measured_status_returns_none_for_every_noncanonical_side_information`",
        "every codec-level noncanonical side-information measured-status fixture remains pending",
        "`lattice_budget_measured_status_returns_none_for_invalid_terms`",
        "semantic and numerical measured slices also remain pending when codec term ownership is invalid",
        "`ledger_entry_wbo_terms_deduplicates_every_codec_catalog`",
        "ledger WBO term summaries preserve first-seen codec term order while dropping duplicate contributions",
        "`cache_offload_codecs_pin_kv_boundary_quantization_and_numerical_terms`",
        "ShadowKV terms are `T_K` + `T_S` + `T_num`; NF4 SSD Oracle terms are `T_K` + `T_Q` + `T_S` + `T_num`",
        "`lattice_budget_measured_status_returns_none_for_invalid_rate`",
        "invalid-rate measured-status fixture keeps budget totals pending",
        "invalid-rate measured-status fixture covers missing, zero, and stray explicit rates",
        "invalid-rate measured-status fixture also exercises public `validate_composition()` rejection",
        "`ledger_validation_rejects_invalid_rate_on_typed_rate_rows`",
        "typed rate-bearing ledger rows reject missing primary rates",
        "`ledger_validation_rejects_zero_rate_on_typed_rate_rows`",
        "typed rate-bearing ledger rows reject zero primary rates",
        "`ledger_validation_rejects_wrong_primary_rate_on_typed_rate_rows`",
        "typed rate-bearing ledger rows reject nonzero rates that differ from the residency primary rate",
        "`ledger_validation_rejects_rate_on_typed_non_rate_rows`",
        "typed non-rate ledger rows reject explicit borrowed rates",
        "`lattice_budget_serializes_non_rate_rate_field_as_null`",
        "non-rate budget JSON keeps `rate_milli_bits_per_symbol` as null",
        "`lattice_budget_json_rejects_unsigned_rate_spoofs`",
        "budget JSON rejects negative, fractional, string, boolean, object, array, and oversized rate fields",
        "`lattice_coder_catalog_marks_non_rate_codecs`",
        "the exact non-rate codec set is `ExactHot`, `BabaiGptqNearestPlane`, `ShadowKvSketch`, `EngramHashRecall`, `NetworkCascade`, and `SelfEvolvingAdapter`",
        "`lattice_budget_measured_status_returns_none_for_overflowed_totals`",
        "semantic and numerical measured slices also remain pending when aggregate totals overflow",
        "overflowed aggregate measured-status fixture also exercises full `LatticeBudget::validate()` rejection",
        "public struct literals cannot bypass",
        "`lattice_budget_slice_partition_is_order_invariant_across_all_axes`",
        "semantic plus numerical slices conserve the total across reordered and duplicated axes",
        "`lattice_budget_slice_partition_conserves_every_codec_catalog`",
        "codec-wide slice fixture preserves semantic plus numerical conservation for every codec catalog row",
        "`residency_tier_catalog_pins_primary_rate_rows`",
        "only L1 carries 1250 milli-bits and L3 carries 4000 milli-bits",
        "`residency_tier_primary_rates_match_primary_codec_rate_ownership`",
        "each residency primary rate exists exactly when its primary codec is rate-bearing",
        "`ledger_validation_requires_term_falsifier_hook_for_each_contribution`",
        "`ledger_validation_requires_ulp_oracle_for_numerical_post_correction`",
        "`lattice_budget_measured_status_requires_numerical_post_correction_term`",
        "semantic and numerical measured slices also remain pending without `T_num`",
        "missing-`T_num` measured-status fixture also exercises public `validate_composition()` rejection",
        "`falsifier_hook_matching_rejects_substring_collisions`",
        "exact-case verifier matching",
        "hook checks are exact-case and delimiter-aware, not case-insensitive substrings",
        "non-ASCII hook adjacency is rejected instead of treated as punctuation",
        "underscore hook adjacency is rejected instead of treated as punctuation",
        "punctuation-delimited canonical hooks remain valid",
        "`falsifier_hook_extraction_accepts_markdown_punctuation_boundaries`",
        "Markdown punctuation around canonical `F-*` hooks is accepted while adjacent word characters stay rejected",
        "capitalized verifier phrases",
        "`ledger_validation_rejects_spoofed_ulp_oracle_hook`",
        "`ledger_validation_requires_wbo_drift_ledger_for_every_row`",
        "Every ledger row must name `F-WBO-DriftLedger`",
        "`wbo_term_catalog_requires_drift_ledger_for_every_axis`",
        "every WBO term falsifier includes `F-WBO-DriftLedger`",
        "`term_falsifier_catalogs_name_owned_f_hooks_for_every_axis`",
        "`FALSIFIER_HOOK_OWNERS`",
        "`falsifier_hook_registry_owns_every_f_hook_named_by_catalogs`",
        "every falsifier owner hook key must use the `F-` prefix",
        "exact four-row owner map for `F-WBO-DriftLedger`, `F-ULP-Oracle`, `F-KV-Direct-Gate`, and `F-ACS-AnchorLookup`",
        "`falsifier_hook_owner_registry_has_unique_public_hooks`",
        "falsifier owner registry hook keys are unique public `F-*` hooks",
        "`falsifier_hook_registry_owner_rows_follow_canonical_order`",
        "falsifier owner registry order is `F-WBO-DriftLedger`, `F-ULP-Oracle`, `F-KV-Direct-Gate`, then `F-ACS-AnchorLookup`",
        "`falsifier_hook_owner_registry_serializes_public_keys`",
        "FalsifierHookOwner serializes only `hook` and `owner` public keys",
        "`falsifier_hook_owner_json_rejects_unknown_fields`",
        "FalsifierHookOwner JSON rejects unknown fields",
        "`falsifier_hook_owner_json_rejects_unregistered_public_rows`",
        "owner JSON rejects unowned hooks, blank owners, and hook/owner mismatches while accepting exact registry rows",
        "owner JSON rejects unicode-adjacent owner hook keys",
        "`falsifier_hook_owner_json_rejects_cross_owner_borrowing`",
        "owner JSON rejects cross-owner hook and owner-path borrowing",
        "exactly one owner row",
        "`codec_falsifier_catalogs_name_owned_f_hooks_for_every_codec`",
        "`codec_falsifier_catalogs_cover_every_owned_f_hook`",
        "every owned `F-*` hook appears in at least one codec falsifier row",
        "codec doc falsifier cells match typed `F-*` hook sets exactly",
        "`residency_primary_falsifiers_name_owned_f_hooks_for_every_tier`",
        "`residency_primary_falsifiers_cover_every_owned_f_hook`",
        "every owned `F-*` hook appears in at least one residency primary falsifier",
        "`falsifier_hook_registry_owner_paths_exist`",
        "`term_falsifier_catalogs_cover_every_owned_f_hook`",
        "every owned `F-*` hook appears in at least one WBO term falsifier",
        "each falsifier owner path resolves to an existing repo file",
        "falsifier owner paths are relative repository paths without `..` traversal",
        "owner paths must resolve to files, not directories",
        "`falsifier_hook_registry_owner_paths_stay_in_canonical_surfaces`",
        "falsifier owner paths stay inside `docs/fusion/`, `agent_core/src/research/`, or `agent_core/src/scope_rex/` surfaces",
        "`falsifier_hook_owner_files_name_their_hooks`",
        "each falsifier owner file names the exact `F-*` hook it owns",
        "`register_doc_f_hooks_are_owned_by_registry`",
        "every concrete register `F-*` hook has a registry owner",
        "register F-* hook set must match falsifier owner registry",
        "`ledger_validation_rejects_unowned_falsifier_hooks`",
        "canonical hook slash-suffix and non-ASCII adjacency variants are rejected by the ledger owner path",
        "`residency_tier_catalog_attaches_numerical_guard_to_every_tier`",
        "`lattice_coder_catalog_attaches_numerical_guard_to_every_codec`",
        "`residency_primary_falsifiers_name_ulp_oracle_for_numerical_guard`",
        "every residency primary falsifier names `F-ULP-Oracle` for `T_num`",
        "`register_doc_requires_ulp_oracle_on_t_num_table_rows`",
        "`register_doc_codec_falsifier_table_names_ulp_oracle_for_t_num_codecs`",
        "`lattice_coder_catalog_marks_rate_bearing_codecs`",
        "the exact rate-bearing codec set includes standalone `NestedE8` and `NestedLeech24` rows",
        "`F-WBO-DriftLedger` alone is insufficient",
        "`ledger_validation_rejects_active_support_budget_without_substrate_boundary_term`",
        "`residency_tier_catalog_marks_active_support_budget_tiers`",
        "the exact active-support budget tier set is `L2 Shadow Sketch` and `L3 SSD Oracle`",
        "`residency_tier_catalog_distinguishes_required_and_secondary_active_support_budget`",
        "required active-support budget row is `L2 Shadow Sketch` and optional secondary active-support budget row is `L3 SSD Oracle`",
        "`ResidencyTier::allows_secondary_active_support_budget()`",
        "L3 optional secondary active-support path is method-pinned separately from L2 required active support",
        "`residency_tier_catalog_requires_substrate_boundary_for_active_support_budget_tiers`",
        "active-support-capable residency tiers must own `T_S`",
        "`ledger_validation_requires_active_support_for_active_support_rows`",
        "`MissingActiveSupportBudget`",
        "`canonical_residency_rows_validate_against_tier_maps`",
        "typed residency validation supplies `ActiveSupportBudget` for active-support-capable rows",
        "`ledger_validation_accepts_canonical_active_support_budget`",
        "canonical `ActiveSupport` rows with nonzero secondary budgets validate",
        "`ledger_validation_rejects_missing_active_support_before_missing_t_num`",
        "missing required active support fails before missing `T_num`",
        "`ledger_validation_rejects_malformed_active_support_before_missing_t_num`",
        "malformed secondary active support fails before missing `T_num`",
        "`active_support_budget_disallowed_tier_rejection_matrix_counts_are_pinned`",
        "max active-support axes do not bypass disallowed tier rejection",
        "`active_support_budget_wrong_tag_rejection_matrix_counts_are_pinned`",
        "secondary `ActiveSupportBudget` rejects every non-`ActiveSupport` side-information tag",
        "secondary active-support side-information rejection covers both `L2 Shadow Sketch` and `L3 SSD Oracle`",
        "`ledger_validation_rejects_zero_active_support_budget_even_when_secondary`",
        "`active_support_budget_partial_zero_axis_rejection_matrix_counts_are_pinned`",
        "token, page, and resident-byte axes are each nonzero",
        "`ledger_validation_rejects_zero_active_support_budget_with_wrong_side_information`",
        "all-zero active-support budgets crossed with non-ActiveSupport witnesses stay invalid",
        "`ledger_validation_rejects_combined_malformed_active_support_budget`",
        "combined malformed secondary active-support fixture covers every active-support-capable tier",
        "`active_support_budget_serializes_public_accounting_keys`",
        "ActiveSupportBudget serializes only `max_active_tokens`, `max_active_pages`, `max_resident_bytes`, and `side_information` public keys",
        "`active_support_budget_json_rejects_unsigned_axis_spoofs`",
        "ActiveSupportBudget JSON rejects negative, fractional, string, boolean, object, array, and oversized axis values",
        "`active_support_budget_json_rejects_invalid_public_budget`",
        "standalone active-support JSON rejects zero axes and non-`ActiveSupport` side information",
        "`active_support_budget_json_rejects_combined_zero_axes_and_wrong_side_information`",
        "standalone active-support JSON rejects partial-zero axes crossed with every non-`ActiveSupport` witness",
        "partial-zero active-support axis fixture covers every active-support-capable tier",
        "`MissingSubstrateBoundaryTerm`",
        "`ledger_validation_requires_numerical_post_correction_contribution`",
        "`MissingNumericalPostCorrectionTerm`",
        "`ledger_validation_requires_kv_direct_gate_for_kv_cache_term`",
        "KV/cache ledger rows must name `F-KV-Direct-Gate`",
        "`ledger_validation_requires_term_specific_security_verifier_for_t_se`",
        "T_SE ledger rows must name provider/provenance replay or adapter replay/provenance verifier",
        "`ledger_validation_requires_residual_kl_slice_for_residual_term`",
        "T_R ledger rows must name residual KL slice",
        "`ledger_validation_requires_layerwise_reconstruction_for_quantization_term`",
        "T_Q ledger rows must name layerwise reconstruction/logit drift witness",
        "`ledger_validation_requires_layerwise_reconstruction_for_weight_runtime_term`",
        "T_W ledger rows must name layerwise reconstruction/logit drift witness",
        "`ledger_validation_requires_anchor_lookup_for_substrate_boundary_term`",
        "T_S ledger rows must name `F-ACS-AnchorLookup`",
        "Sherry is a WEIGHT codec; its public results are weight-side at calibration time",
        "L1 residual rows CANNOT borrow Sherry's calibration Hessian as proof of residual transfer",
        "| Nested E8 | Standalone nested-lattice E8 vector quantization lane",
        "NestedE8 is not a QuIP/E8 subfamily",
        "owns a separate rate row and reconstruction error profile",
        "| `NestedE8` | Nested E8 standalone codec row |",
        "| Nested Leech24 | Standalone nested-lattice Leech_24 vector quantization lane",
        "NestedLeech24 is not a QuIP/E8 subfamily",
        "owns a separate rate row and Leech_24 reconstruction error profile",
        "| `NestedLeech24` | Nested Leech24 standalone codec row |",
        "`nested_lattice_codecs_pin_weight_quantization_terms_and_rate`",
        "nested standalone codec terms remain `T_W` + `T_Q` + `T_num` with explicit rate ownership",
        "`nested_lattice_codecs_reject_residual_and_kv_side_information`",
        "nested standalone rows reject residual, KV, active-support, and SSD-oracle witnesses through direct, full, and composition validators",
        "L3 SSD Oracle keeps `SsdOracle` as primary side information; `ActiveSupportBudget` is allowed but optional",
        "| L0 RAM hot | Exact fp16/bf16 KV and residual stream | `None` beyond live model state | `T_num` only | `F-WBO-DriftLedger`; `F-ULP-Oracle`; per-token KL witness",
        "`exact_hot_codec_pins_reference_term_and_side_information`",
        "ExactHot terms are `T_num` only and side information is `None`",
        "| L1 Compressed Residual | Lattice-Wyner-Ziv residual codec under `LatticeCoder<1250 milli-bits>` | `ResidualStream` plus `DecoderLmState` | `T_R` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; residual KL slice; layerwise reconstruction/logit drift witness; `F-ACS-AnchorLookup`",
        "| L2 Shadow Sketch | ShadowKV-style active-support sketch: retained pages/tokens plus residual or JL/CountSketch correction | `ActiveSupport` mask, page criticality, residual sketch | `T_K` + `T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-KV-Direct-Gate`; `F-ACS-AnchorLookup`",
        "| L3 SSD Oracle | NF4 mmap/IOSurface pages under `Nf4SsdOracle<4000 milli-bits>` with cold exact-or-higher-fidelity page oracle | `SsdOracle` page plus `ResidualStream` reconstruction witness | `T_K` + `T_Q` + `T_S` + `T_num` | `F-KV-Direct-Gate`; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness; `F-ACS-AnchorLookup`",
        "| L4 Engram | Fixed-budget hash recall for static facts, signatures, dates, and API contracts | Content hash, provenance edge, `StaticFactKey` | `T_S` + `T_num` | `F-ACS-AnchorLookup`; `F-ULP-Oracle`; `F-WBO-DriftLedger`",
        "| L5 Network Cascade | Outlier escalation to larger/cloud teacher or cross-model verifier | `NetworkTeacher` output, signed provenance, claim ledger witness | `T_S` + `T_SE` + `T_num` | provider/provenance replay; `F-ULP-Oracle`; `F-WBO-DriftLedger`; `F-ACS-AnchorLookup`",
        "| L_SE Self-Evolving | Titans-MAC / SEAL-DoRA adapter or surprise-gradient state | `SurpriseGradient`, adapter provenance, replayable mutation envelope | `T_W` + `T_SE` + `T_num` | adapter replay/provenance verifier; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness before promotion",
        "| Babai/GPTQ nearest-plane | Weight quantization as nearest-plane rounding in a Hessian-induced lattice | Calibration Hessian from the weight quantization calibration set | `T_W` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness; layerwise KL/logit drift harness",
        "`lattice_coder_catalog_includes_babai_gptq_nearest_plane`",
        "Babai/GPTQ nearest-plane terms are `T_W` + `T_num`, side information is `CalibrationHessian`, and it is non-rate",
        "| `BabaiGptqNearestPlane` | Babai/GPTQ nearest-plane codec row | `T_W`; `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness |",
        "| Sherry 3:4 sparse ternary | 1.25-bit sparse ternary lattice packing used as a weight-codec reference only | Calibration Hessian for weight lanes | `T_W` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness",
        "`sherry_ternary_codec_pins_weight_terms_rate_and_calibration_side_information`",
        "Sherry terms are `T_W` + `T_Q` + `T_num` with explicit rate ownership and `CalibrationHessian` evidence",
        "| QuIP/E8 | Incoherence rotation plus E8-style lattice codebook for weight blocks | Calibration Hessian / whitening statistics | `T_W` + `T_Q` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; layerwise reconstruction/logit drift witness",
        "`quip_e8_codec_pins_weight_quantization_terms_and_rate`",
        "QuIP/E8 terms are `T_W` + `T_Q` + `T_num` with explicit rate ownership and calibration-side evidence",
        "| Lattice-Wyner-Ziv / `LatticeCoder<BITS>` | Rate-limited residual or state codec decoded with model side information | Decoder LM state, residual stream, active support, or oracle page depending on tier | `T_R` + tier-specific `T_K`/`T_Q`/`T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; tier-specific KL/reconstruction witness",
        "`lattice_wyner_ziv_residual_codec_pins_terms_rate_and_decoder_witnesses`",
        "LatticeWynerZivResidual terms are `T_K` + `T_R` + `T_Q` + `T_S` + `T_num` with `DecoderLmState`, `ResidualStream`, `ActiveSupport`, and `SsdOracle` witnesses",
        "| Residual sketch | JL / CountSketch / FRP-shaped correction stream attached to a compressed residual or KV restore path | Residual stream witness plus decoder LM state; active-support mask when the sketch repairs skipped support | `T_R` + `T_Q` + tier-specific `T_S` + `T_num` | `F-WBO-DriftLedger`; `F-ULP-Oracle`; `F-ACS-AnchorLookup`; tier-specific reconstruction witness",
        "`residual_sketch_codec_pins_correction_terms_and_side_information`",
        "ResidualSketch terms are `T_R` + `T_Q` + `T_S` + `T_num` with `ResidualStream`, `DecoderLmState`, and `ActiveSupport` witnesses",
        "| Engram hash recall | Fixed-budget static-fact hash lookup for signatures, dates, API contracts, and never-recompute knowledge | `StaticFactKey`, content hash, and provenance edge | `T_S` + `T_num` | `F-ACS-AnchorLookup`; `F-ULP-Oracle`; `F-WBO-DriftLedger`",
        "`engram_hash_recall_codec_pins_static_fact_boundary`",
        "EngramHashRecall terms are `T_S` + `T_num`, side information is `StaticFactKey`, and it is non-rate",
        "| Network cascade | Outlier escalation to a larger model, cloud teacher, or cross-model verifier at the L5 boundary | Signed teacher output, provider receipt, claim ledger witness, and replayable provenance | `T_S` + `T_SE` + `T_num` | provider/provenance replay; `F-ULP-Oracle`; `F-WBO-DriftLedger`; `F-ACS-AnchorLookup`",
        "`network_cascade_codec_pins_teacher_boundary_terms_and_side_information`",
        "NetworkCascade terms are `T_S` + `T_SE` + `T_num`, side information is `NetworkTeacher`, and it is non-rate",
        "| Self-evolving adapter | Titans-MAC / SEAL-DoRA / QDoRA-style adapter state that mutates the effective runtime model | Surprise gradient, adapter provenance, replayable mutation envelope, and promotion witness | `T_W` + `T_SE` + `T_num` | adapter replay/provenance verifier; `F-ULP-Oracle`; `F-WBO-DriftLedger`; layerwise reconstruction/logit drift witness",
        "`self_evolving_adapter_codec_pins_mutation_terms_and_side_information`",
        "SelfEvolvingAdapter terms are `T_W` + `T_SE` + `T_num`, side information is `SurpriseGradient`, and it is non-rate",
        "rate_milli_bits_per_symbol` on non-rate codecs",
        "`budget_validation_rejects_zero_explicit_rate`",
        "`budget_validation_rejects_missing_rate_on_rate_codecs`",
        "`budget_validation_accepts_nonzero_rate_on_rate_codecs`",
        "`budget_validation_rejects_rate_on_non_rate_codecs`",
        "invalid-rate fixtures also assert the public `validate_composition()` path",
        "only `L2 Shadow Sketch` and `L3 SSD Oracle` rows may carry this budget surface",
        "`WboTermCode::falsifier()`",
        "`F-KV-Direct-Gate` for `T_K`",
        "`F-ULP-Oracle` for `T_num`",
        "must conserve",
        "`lattice_budget_measured_total_includes_numerical_post_correction`",
        "`measured_semantic_wbo6_pre_softmax_total()`",
        "`measured_numerical_post_correction_total()`",
        "`lattice_budget_measured_slices_partition_complete_total`",
        "`lattice_budget_measured_total_sums_duplicate_semantic_and_numerical_axes`",
        "duplicate semantic and numerical measured slices stay separately summed",
        "`lattice_budget_measured_slices_require_complete_cross_axis_measurements`",
        "`lattice_budget_measured_slices_require_complete_duplicate_axis_measurements`",
        "duplicate semantic or numerical axes cannot produce measured slices until every duplicate carries measured data",
        "semantic and numerical measured slices remain pending when any contribution lacks measured data",
        "missing semantic or missing numerical measurements both keep every measured surface pending",
        "`lattice_error_contribution_serializes_pending_measurement_as_null`",
        "unmeasured contribution JSON keeps `measured` as null",
        "`T_num` is tracked as a numerical post-correction guard",
        "not a seventh",
    ];

    for needle in required {
        assert!(register.contains(needle), "missing {needle}");
    }
}

#[test]
fn register_doc_requires_ulp_oracle_on_t_num_table_rows() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let mut checked_rows = 0;

    for line in register.lines().filter(|line| line.starts_with('|')) {
        let cells = line
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .collect::<Vec<_>>();

        if cells.len() >= 6 && cells[3].contains("`T_num`") {
            checked_rows += 1;
            assert!(
                cells[4].contains("F-ULP-Oracle"),
                "missing F-ULP-Oracle on numerical row: {line}"
            );
        }
    }

    assert!(
        checked_rows >= 17,
        "expected register and codec rows carrying T_num"
    );
}

#[test]
fn register_doc_codec_falsifier_table_names_ulp_oracle_for_t_num_codecs() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

    for coder in LatticeCoderKind::ALL {
        if coder
            .canonical_wbo_terms()
            .contains(&WboTermCode::NumericalPostCorrection)
        {
            let prefix = format!("| `{:?}` |", coder);
            let row = register
                .lines()
                .find(|line| line.starts_with(&prefix))
                .unwrap_or_else(|| panic!("missing codec falsifier row for {coder:?}"));
            assert!(
                row.contains("F-ULP-Oracle"),
                "codec falsifier row must name F-ULP-Oracle for {coder:?}: {row}"
            );
        }
    }
}

#[test]
fn register_doc_requires_reconstruction_witness_on_t_q_table_rows() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let mut checked_rows = 0;

    for line in register.lines().filter(|line| line.starts_with('|')) {
        let cells = line
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .collect::<Vec<_>>();

        if cells.len() >= 6 && cells[3].contains("`T_Q`") {
            checked_rows += 1;
            assert!(
                cells[4].contains("layerwise reconstruction/logit drift witness"),
                "missing quantization reconstruction witness on T_Q row: {line}"
            );
        }
    }

    assert!(checked_rows >= 8, "expected T_Q register and codec rows");
}

#[test]
fn register_doc_requires_reconstruction_witness_on_t_w_table_rows() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let mut checked_rows = 0;

    for line in register.lines().filter(|line| line.starts_with('|')) {
        let cells = line
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .collect::<Vec<_>>();

        if cells.len() >= 6 && cells[3].contains("`T_W`") {
            checked_rows += 1;
            assert!(
                cells[4].contains("layerwise reconstruction/logit drift witness"),
                "missing weight/runtime reconstruction witness on T_W row: {line}"
            );
        }
    }

    assert!(checked_rows >= 7, "expected T_W register and codec rows");
}

#[test]
fn register_doc_requires_anchor_lookup_on_t_s_table_rows() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let mut checked_rows = 0;

    for line in register.lines().filter(|line| line.starts_with('|')) {
        let cells = line
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .collect::<Vec<_>>();

        if cells.len() >= 6 && cells[3].contains("`T_S`") {
            checked_rows += 1;
            assert!(
                cells[4].contains("F-ACS-AnchorLookup"),
                "missing anchor lookup verifier on T_S row: {line}"
            );
        }
    }

    assert!(checked_rows >= 8, "expected T_S register and codec rows");
}

#[test]
fn register_doc_preserves_babai_gptq_non_rate_caveat() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(register.contains(
        "Babai/GPTQ nearest-plane is a calibration-Hessian weight codec, not a `LatticeCoder<BITS>` rate abstraction"
    ));
}

#[test]
fn register_doc_preserves_budget_level_numerical_guard() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(register.contains("`LatticeBudget::validate()` rejects budgets without `T_num`"));
}

#[test]
fn register_doc_names_every_residency_tier_and_wbo_term() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

    for tier in ResidencyTier::ALL {
        let needle = format!("| {} |", tier.canonical_name());
        assert!(
            register.contains(&needle),
            "missing register doc row for {}",
            tier.canonical_name()
        );
        let row_count = register
            .lines()
            .filter(|line| line.starts_with(&needle))
            .count();
        assert_eq!(
            row_count,
            1,
            "{} must name one residency register row",
            tier.canonical_name()
        );
        let row = register
            .lines()
            .find(|line| line.starts_with(&needle))
            .expect("residency row should exist");
        let cells = row
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .collect::<Vec<_>>();
        match tier.primary_rate_milli_bits_per_symbol() {
            Some(rate) => assert!(
                row.contains(&format!("{rate} milli-bits")),
                "{} row must name primary rate {rate} milli-bits",
                tier.canonical_name()
            ),
            None => assert!(
                !row.contains("milli-bits"),
                "{} row must not name a primary rate",
                tier.canonical_name()
            ),
        }
        let side_information_cell = cells.get(2).unwrap_or_else(|| {
            panic!(
                "{} row must have side-information cell",
                tier.canonical_name()
            )
        });
        let primary_side_information = format!("`{:?}`", tier.primary_side_information());
        assert!(
            side_information_cell.contains(&primary_side_information),
            "{} row must name primary side-information validation key {primary_side_information}",
            tier.canonical_name()
        );
        let first_side_information = side_information_cell.split('`').nth(1).unwrap_or_else(|| {
            panic!(
                "{} row must begin side-information cell with a canonical witness key",
                tier.canonical_name()
            )
        });
        assert_eq!(
            first_side_information,
            format!("{:?}", tier.primary_side_information()),
            "{} row must list primary side-information before secondary witnesses",
            tier.canonical_name()
        );
        for side_information in SideInformationKind::ALL {
            let side_information_name = format!("`{side_information:?}`");
            let expected = tier
                .side_information_witnesses()
                .contains(&side_information);
            assert_eq!(
                side_information_cell.contains(&side_information_name),
                expected,
                "{} row side-information cell must exactly match {side_information_name} ownership",
                tier.canonical_name()
            );
        }
        let falsifier_cell = cells
            .get(4)
            .unwrap_or_else(|| panic!("{} row must have falsifier cell", tier.canonical_name()));
        let mut expected_hooks = f_hooks_in(tier.primary_falsifier());
        for term in tier.canonical_register_terms() {
            for hook in f_hooks_in(term.falsifier()) {
                if !expected_hooks.contains(&hook) {
                    expected_hooks.push(hook);
                }
            }
        }
        let mut expected_hook_set = expected_hooks.clone();
        expected_hook_set.sort_unstable();
        expected_hook_set.dedup();
        let mut actual_hook_set = f_hooks_in(falsifier_cell);
        actual_hook_set.sort_unstable();
        actual_hook_set.dedup();
        assert_eq!(
            actual_hook_set,
            expected_hook_set,
            "{} residency row falsifier cell must exactly match primary and term F-* hooks",
            tier.canonical_name()
        );
        for hook in f_hooks_in(falsifier_cell) {
            assert!(
                expected_hooks.contains(&hook),
                "{} residency row must not name unowned hook {hook}",
                tier.canonical_name()
            );
        }
    }

    for term in WboTermCode::ALL {
        let needle = format!("| `{}` |", term.code());
        assert!(
            register.contains(&needle),
            "missing WBO term doc row for {}",
            term.code()
        );
        let term_rows = register
            .lines()
            .skip_while(|line| *line != "## WBO Term Obligation Map")
            .skip(1)
            .take_while(|line| *line != "### WBO Witness Contracts")
            .collect::<Vec<_>>();
        let row_count = term_rows
            .iter()
            .filter(|line| line.starts_with(&needle))
            .count();
        assert_eq!(
            row_count,
            1,
            "{} must name one WBO term obligation row",
            term.code()
        );
        let row = term_rows
            .iter()
            .find(|line| line.starts_with(&needle))
            .expect("term row should exist");
        let cells = row
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .collect::<Vec<_>>();
        assert!(
            cells.get(1).is_some_and(|cell| cell
                .to_ascii_lowercase()
                .contains(&term.obligation().to_ascii_lowercase())),
            "{} doc row must name typed obligation {}",
            term.code(),
            term.obligation()
        );
        let falsifier_cell = cells
            .get(4)
            .unwrap_or_else(|| panic!("{} doc row must have falsifier cell", term.code()));
        for clause in term.falsifier().split(';').map(str::trim) {
            assert!(
                falsifier_cell.contains(clause),
                "{} doc falsifier cell must name typed falsifier clause {clause}",
                term.code()
            );
        }
        let row_hooks = f_hooks_in(row);
        for hook in f_hooks_in(term.falsifier()) {
            assert!(
                row_hooks.contains(&hook),
                "{} doc row must name falsifier hook {hook}",
                term.code()
            );
        }
        let expected_hooks = f_hooks_in(term.falsifier());
        let mut expected_hook_set = expected_hooks.clone();
        expected_hook_set.sort_unstable();
        expected_hook_set.dedup();
        let mut actual_hook_set = f_hooks_in(falsifier_cell);
        actual_hook_set.sort_unstable();
        actual_hook_set.dedup();
        assert_eq!(
            actual_hook_set,
            expected_hook_set,
            "{} doc falsifier cell must exactly match typed F-* hooks",
            term.code()
        );
        for hook in f_hooks_in(falsifier_cell) {
            assert!(
                expected_hooks.contains(&hook),
                "{} doc falsifier cell must not name unowned hook {hook}",
                term.code()
            );
        }
    }
}

#[test]
fn register_doc_wbo_witness_contracts_cover_every_term() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let witness_contract_rows = register_wbo_witness_contract_rows(register);

    for term in WboTermCode::ALL {
        let needle = format!("| `{}` |", term.code());
        let matching_rows = witness_contract_rows
            .iter()
            .filter(|line| line.starts_with(&needle))
            .count();

        assert_eq!(
            matching_rows,
            1,
            "{} must have exactly one witness-contract row",
            term.code()
        );
    }
}

#[test]
fn register_doc_wbo_witness_contracts_name_term_f_hooks() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let witness_contract_rows = register_wbo_witness_contract_rows(register);

    for term in WboTermCode::ALL {
        let needle = format!("| `{}` |", term.code());
        let row = witness_contract_rows
            .iter()
            .find(|line| line.starts_with(&needle))
            .unwrap_or_else(|| panic!("missing witness-contract row for {}", term.code()));
        let row_hooks = f_hooks_in(row);

        for hook in f_hooks_in(term.falsifier()) {
            assert!(
                row_hooks.contains(&hook),
                "{} witness contract must name typed falsifier hook {hook}",
                term.code()
            );
        }
    }
}

#[test]
fn register_doc_wbo_witness_contracts_match_exact_term_f_hooks() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let witness_contract_rows = register_wbo_witness_contract_rows(register);

    for term in WboTermCode::ALL {
        let needle = format!("| `{}` |", term.code());
        let row = witness_contract_rows
            .iter()
            .find(|line| line.starts_with(&needle))
            .unwrap_or_else(|| panic!("missing witness-contract row for {}", term.code()));
        let mut actual = f_hooks_in(row);
        actual.sort_unstable();
        actual.dedup();
        let mut expected = f_hooks_in(term.falsifier());
        expected.sort_unstable();
        expected.dedup();

        assert_eq!(
            actual,
            expected,
            "{} witness contract F-* hooks must exactly match typed term falsifier hooks",
            term.code()
        );
    }
    assert!(
        register.contains("`register_doc_wbo_witness_contracts_match_exact_term_f_hooks`"),
        "register doc must cross-link the exact witness-contract hook guard"
    );
}

#[test]
fn register_doc_wbo_witness_contract_rows_follow_catalog_order() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let actual = register_wbo_witness_contract_rows(register)
        .into_iter()
        .filter_map(|line| {
            line.strip_prefix("| `")
                .and_then(|tail| tail.split_once("` |"))
                .map(|(name, _)| name.to_owned())
        })
        .collect::<Vec<_>>();
    let expected = WboTermCode::ALL
        .iter()
        .map(|term| term.code().to_owned())
        .collect::<Vec<_>>();

    assert_eq!(
        actual, expected,
        "WBO witness-contract rows must stay in WboTermCode::ALL order"
    );
    assert!(
        register.contains("`register_doc_wbo_witness_contract_rows_follow_catalog_order`"),
        "register doc must cross-link the witness-contract ordering guard"
    );
}

#[test]
fn register_doc_names_softmax_half_pre_post_helpers() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

    for helper in [
        "softmax_half_pre_correction_budget()",
        "softmax_half_post_correction_budget()",
        "measured_softmax_half_pre_correction_total()",
        "measured_softmax_half_post_correction_total()",
    ] {
        assert!(
            register.contains(helper),
            "register must name explicit softmax-half helper {helper}"
        );
    }
}

fn register_wbo_witness_contract_rows(register: &str) -> Vec<&str> {
    register
        .lines()
        .skip_while(|line| *line != "### WBO Witness Contracts")
        .skip(1)
        .take_while(|line| !line.starts_with("## "))
        .collect::<Vec<_>>()
}

#[test]
fn register_doc_residency_side_information_cells_follow_witness_order() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

    for tier in ResidencyTier::ALL {
        let needle = format!("| {} |", tier.canonical_name());
        let row = register
            .lines()
            .find(|line| line.starts_with(&needle))
            .unwrap_or_else(|| panic!("missing register doc row for {}", tier.canonical_name()));
        let side_information_cell = row
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .nth(2)
            .unwrap_or_else(|| {
                panic!(
                    "{} row must have side-information cell",
                    tier.canonical_name()
                )
            });
        let actual_witnesses = side_information_cell
            .split('`')
            .skip(1)
            .step_by(2)
            .filter_map(|witness| {
                SideInformationKind::ALL
                    .iter()
                    .copied()
                    .find(|kind| format!("{kind:?}") == witness)
            })
            .collect::<Vec<_>>();

        assert_eq!(
            actual_witnesses,
            tier.side_information_witnesses(),
            "{} row side-information keys must preserve ResidencyTier::side_information_witnesses() order",
            tier.canonical_name()
        );
    }
}

#[test]
fn register_doc_residency_falsifier_cells_follow_primary_and_term_hook_order() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

    for tier in ResidencyTier::ALL {
        let needle = format!("| {} |", tier.canonical_name());
        let row = register
            .lines()
            .find(|line| line.starts_with(&needle))
            .unwrap_or_else(|| panic!("missing register doc row for {}", tier.canonical_name()));
        let falsifier_cell = row
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .nth(4)
            .unwrap_or_else(|| panic!("{} row must have falsifier cell", tier.canonical_name()));
        let mut expected_hooks = f_hooks_in(tier.primary_falsifier());
        for term in tier.canonical_register_terms() {
            for hook in f_hooks_in(term.falsifier()) {
                if !expected_hooks.contains(&hook) {
                    expected_hooks.push(hook);
                }
            }
        }

        assert_eq!(
            f_hooks_in(falsifier_cell),
            expected_hooks,
            "{} row falsifier hooks must preserve primary falsifier order before tier-term hooks",
            tier.canonical_name()
        );
    }
}

fn register_residency_rows(register: &str) -> Vec<String> {
    register
        .lines()
        .skip_while(|line| *line != "## Register")
        .skip(1)
        .take_while(|line| !line.starts_with("## "))
        .filter_map(|line| {
            let name = line.strip_prefix("| ")?.split_once(" |")?.0;
            (name != "Memory tier" && !name.starts_with("---")).then(|| name.to_owned())
        })
        .collect::<Vec<_>>()
}

#[test]
fn register_doc_residency_rows_follow_catalog_order() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let expected = ResidencyTier::ALL
        .iter()
        .map(|tier| tier.canonical_name().to_owned())
        .collect::<Vec<_>>();

    assert_eq!(
        register_residency_rows(register),
        expected,
        "residency rows must stay in ResidencyTier::ALL order"
    );
}

fn register_wbo_term_rows(register: &str) -> Vec<String> {
    register
        .lines()
        .skip_while(|line| *line != "## WBO Term Obligation Map")
        .skip(1)
        .take_while(|line| *line != "### WBO Witness Contracts")
        .filter_map(|line| {
            line.strip_prefix("| `")
                .and_then(|tail| tail.split_once("` |"))
                .map(|(name, _)| name.to_owned())
        })
        .collect::<Vec<_>>()
}

#[test]
fn register_doc_wbo_term_rows_follow_catalog_order() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let expected = WboTermCode::ALL
        .iter()
        .map(|term| term.code().to_owned())
        .collect::<Vec<_>>();

    assert_eq!(
        register_wbo_term_rows(register),
        expected,
        "WBO term rows must stay in WboTermCode::ALL order"
    );
}

struct RegisterCanonAnchor {
    path: &'static str,
    section: &'static str,
    line_number: usize,
    source: &'static str,
    expected_heading: &'static str,
    row_title: &'static str,
}

impl RegisterCanonAnchor {
    fn doc_anchor(&self) -> String {
        format!("`{}` {} line {}", self.path, self.section, self.line_number)
    }

    fn guardrail_row_prefix(&self) -> String {
        format!("| {}", self.doc_anchor())
    }
}

fn register_canon_anchors() -> [RegisterCanonAnchor; 10] {
    let endgame_deck =
        include_str!("../../../../docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md");
    let helios_budget = include_str!("../../../../docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md");
    let master_fusion = include_str!("../../../../docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md");
    let uas_canon =
        include_str!("../../../../docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md");
    [
        RegisterCanonAnchor {
            path: "docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md",
            section: "§4",
            line_number: 367,
            source: endgame_deck,
            expected_heading: "### T17B - Lattice / WBO Register",
            row_title: "T17B - Lattice / WBO Register",
        },
        RegisterCanonAnchor {
            path: "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md",
            section: "§Canonical Inequality Shape",
            line_number: 32,
            source: helios_budget,
            expected_heading: "## Canonical Inequality Shape",
            row_title: "Canonical Inequality Shape",
        },
        RegisterCanonAnchor {
            path: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md",
            section: "§3.2",
            line_number: 89,
            source: master_fusion,
            expected_heading: "### 3.2 Six-tier memory hierarchy",
            row_title: "Six-tier memory hierarchy",
        },
        RegisterCanonAnchor {
            path: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md",
            section: "§3.4",
            line_number: 129,
            source: master_fusion,
            expected_heading: "### 3.4 SCOPE-Rex",
            row_title: "SCOPE-Rex",
        },
        RegisterCanonAnchor {
            path: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md",
            section: "§3.8",
            line_number: 185,
            source: master_fusion,
            expected_heading: "### 3.8 ACS",
            row_title: "ACS",
        },
        RegisterCanonAnchor {
            path: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md",
            section: "§3.16",
            line_number: 277,
            source: master_fusion,
            expected_heading: "### 3.16 Helios kernels",
            row_title: "Helios kernels",
        },
        RegisterCanonAnchor {
            path: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md",
            section: "§3.18",
            line_number: 312,
            source: master_fusion,
            expected_heading: "### 3.18 Provenance ledger",
            row_title: "Provenance ledger",
        },
        RegisterCanonAnchor {
            path: "docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md",
            section: "§2",
            line_number: 30,
            source: uas_canon,
            expected_heading: "## 2. The 6 canonical surfaces",
            row_title: "The 6 canonical surfaces",
        },
        RegisterCanonAnchor {
            path: "docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md",
            section: "§4",
            line_number: 60,
            source: uas_canon,
            expected_heading: "## 4. UAS-ACS cross-link map",
            row_title: "UAS-ACS cross-link map",
        },
        RegisterCanonAnchor {
            path: "docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md",
            section: "§5",
            line_number: 102,
            source: uas_canon,
            expected_heading: "## 5. V1 / V1.x / V2 / Never-ships sort",
            row_title: "V1 / V1.x / V2 / Never-ships sort",
        },
    ]
}

#[test]
fn register_doc_canon_line_anchors_match_current_sources() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

    for anchor in register_canon_anchors() {
        let doc_anchor = anchor.doc_anchor();
        assert!(
            register.contains(&doc_anchor),
            "register missing {doc_anchor}"
        );
        let actual_line = anchor
            .source
            .lines()
            .nth(anchor.line_number - 1)
            .expect("canon anchor line should exist");
        assert!(
            actual_line.contains(anchor.expected_heading),
            "{doc_anchor} points at {actual_line:?}, expected {:?}",
            anchor.expected_heading
        );
    }
}

#[test]
fn register_doc_cross_link_rows_name_canon_paths() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let anchors = register_canon_anchors();

    for anchor in anchors {
        let row_prefix = anchor.guardrail_row_prefix();
        assert!(register.contains(&row_prefix), "missing {row_prefix}");
    }
    let anchored_doc_rows = register
        .lines()
        .filter(|line| line.starts_with("| `docs/") && line.contains(" line "))
        .count();
    assert_eq!(
        anchored_doc_rows,
        register_canon_anchors().len(),
        "every canon-source line-anchor row must have an explicit test guard"
    );
}

#[test]
fn register_doc_cross_link_rows_name_current_canon_headings() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

    for anchor in register_canon_anchors() {
        let actual_heading = anchor
            .source
            .lines()
            .nth(anchor.line_number - 1)
            .expect("canon heading line should exist");
        assert!(
            actual_heading.contains(anchor.expected_heading),
            "{} points at {actual_heading:?}",
            anchor.doc_anchor()
        );
        let row_prefix = anchor.guardrail_row_prefix();
        let row = register
            .lines()
            .find(|line| line.starts_with(&row_prefix))
            .expect("register cross-link row should exist");
        assert!(
            row.contains(anchor.row_title),
            "{row_prefix} row must name current heading title {:?}: {row:?}",
            anchor.row_title
        );
    }
}

#[test]
fn register_doc_json_surface_source_line_anchors_match_current_code() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let accounting_source = include_str!("../accounting.rs");
    let register_source = include_str!("../register.rs");
    let verifier_source = include_str!("../verifier.rs");
    let required_structs: [(&str, &str, &str); 5] = [
        ("FalsifierHookOwner", "verifier.rs", verifier_source),
        (
            "LatticeErrorContribution",
            "accounting.rs",
            accounting_source,
        ),
        ("LatticeBudget", "accounting.rs", accounting_source),
        ("ActiveSupportBudget", "accounting.rs", accounting_source),
        ("WboLedgerEntry", "register.rs", register_source),
    ];

    for (struct_name, file_name, source) in required_structs {
        let declaration = format!("pub struct {struct_name}");
        let line_number = source
            .lines()
            .position(|line| line.contains(&declaration))
            .map(|index| index + 1)
            .expect("serialized surface declaration should exist");
        let anchor =
            format!("`agent_core/src/lattice_wbo/{file_name}:{line_number}` `{struct_name}`");
        assert!(
            register.contains(&anchor),
            "register missing serialized source anchor {anchor}"
        );
    }
}

#[test]
fn register_doc_canonical_anchor_list_matches_guardrail_rows() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let canonical_anchor_lines = register
        .lines()
        .skip_while(|line| *line != "Canonical anchors:")
        .skip(1)
        .skip_while(|line| line.trim().is_empty())
        .take_while(|line| !line.trim().is_empty())
        .collect::<Vec<_>>();

    for anchor in register_canon_anchors() {
        let path_needle = format!("`{}`", anchor.path);
        let section_line_needle = format!("{} line {}", anchor.section, anchor.line_number);
        assert!(
            canonical_anchor_lines
                .iter()
                .any(|line| { line.contains(&path_needle) && line.contains(&section_line_needle) }),
            "canonical anchor list missing {path_needle} {section_line_needle}"
        );
        assert!(
            register.contains(&format!("| {path_needle} {section_line_needle}")),
            "guardrail table missing {path_needle} {section_line_needle}"
        );
    }
}
