//! ResidencyTier catalog tests: tier-to-codec/term/side-info/falsifier maps.

use super::*;

#[test]
fn lattice_wbo_error_public_keys_match_all_canonical_keys() {
    let canonical_keys = LatticeWboError::ALL
        .iter()
        .map(|error| error.key())
        .collect::<Vec<_>>();

    assert_eq!(LatticeWboError::CODES, canonical_keys.as_slice());
    for (error, key) in LatticeWboError::ALL.iter().zip(LatticeWboError::CODES) {
        assert_eq!(error.key(), key);
        assert_eq!(LatticeWboError::from_key(key), Some(*error));
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`lattice_wbo_error_public_keys_match_all_canonical_keys`"),
        "register doc must cross-link error public-key exhaustiveness"
    );
}

#[test]
fn wbo_term_public_codes_match_all_canonical_codes() {
    let canonical_codes = WboTermCode::ALL
        .iter()
        .map(|term| term.code())
        .collect::<Vec<_>>();

    assert_eq!(WboTermCode::CODES, canonical_codes.as_slice());
    for (term, code) in WboTermCode::ALL.iter().zip(WboTermCode::CODES) {
        assert_eq!(term.code(), code);
        assert_eq!(WboTermCode::from_code(code), Some(*term));
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`wbo_term_public_codes_match_all_canonical_codes`"),
        "register doc must cross-link WBO term public-code exhaustiveness"
    );
}

#[test]
fn side_information_public_keys_are_trimmed_ascii_pascal_case() {
    for kind in SideInformationKind::ALL {
        let key = kind.key();
        let debug = format!("{kind:?}");
        assert!(!key.is_empty(), "{kind:?}");
        assert_eq!(key.trim(), key, "{kind:?}");
        assert!(key.is_ascii(), "{kind:?}");
        assert!(!key.contains(' '), "{kind:?} key {key}");
        assert!(!key.contains('-'), "{kind:?} key {key}");
        assert!(!key.contains('_'), "{kind:?} key {key}");
        let first = key.chars().next().expect("nonempty");
        assert!(first.is_ascii_uppercase(), "{kind:?} key {key}");
        assert!(
            key.chars().all(|ch| ch.is_ascii_alphanumeric()),
            "{kind:?} key {key}"
        );
        assert_eq!(key, debug.as_str(), "{kind:?} debug should match key");
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`side_information_public_keys_are_trimmed_ascii_pascal_case`"),
        "register doc must cross-link side-information key formatting safety"
    );
}

#[test]
fn side_information_public_keys_match_all_canonical_keys() {
    let canonical_keys = SideInformationKind::ALL
        .iter()
        .map(|kind| kind.key())
        .collect::<Vec<_>>();

    assert_eq!(SideInformationKind::CODES, canonical_keys.as_slice());
    for (kind, key) in SideInformationKind::ALL
        .iter()
        .zip(SideInformationKind::CODES)
    {
        assert_eq!(kind.key(), key);
        assert_eq!(SideInformationKind::from_key(key), Some(*kind));
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`side_information_public_keys_match_all_canonical_keys`"),
        "register doc must cross-link side-information public-key exhaustiveness"
    );
}

#[test]
fn lattice_coder_public_codes_match_all_canonical_names() {
    let canonical_names = LatticeCoderKind::ALL
        .iter()
        .map(|coder| coder.canonical_name())
        .collect::<Vec<_>>();

    assert_eq!(LatticeCoderKind::CODES, canonical_names.as_slice());
    for (coder, code) in LatticeCoderKind::ALL.iter().zip(LatticeCoderKind::CODES) {
        assert_eq!(coder.canonical_name(), code);
        assert_eq!(LatticeCoderKind::from_canonical_name(code), Some(*coder));
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`lattice_coder_public_codes_match_all_canonical_names`"),
        "register doc must cross-link codec public-code exhaustiveness"
    );
}

#[test]
fn lattice_coder_canonical_side_information_lists_are_dedup_and_canonical() {
    for coder in LatticeCoderKind::ALL {
        let witnesses = coder.canonical_side_information();
        assert!(
            !witnesses.is_empty(),
            "{coder:?} must declare at least one canonical side-information witness"
        );
        for (index, witness) in witnesses.iter().enumerate() {
            assert!(
                !witnesses[index + 1..].contains(witness),
                "{coder:?} must not duplicate witness {:?}",
                witness
            );
            assert!(
                SideInformationKind::ALL.contains(witness),
                "{coder:?} witness {:?} must remain in SideInformationKind::ALL",
                witness
            );
        }
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains(
            "`lattice_coder_canonical_side_information_lists_are_dedup_and_canonical`"
        ),
        "register doc must cross-link codec side-info dedup invariant"
    );
}

#[test]
fn lattice_coder_canonical_wbo_terms_are_dedup_and_canonical() {
    for coder in LatticeCoderKind::ALL {
        let terms = coder.canonical_wbo_terms();
        assert!(
            !terms.is_empty(),
            "{coder:?} must declare at least one canonical WBO term"
        );
        for (index, term) in terms.iter().enumerate() {
            assert!(
                !terms[index + 1..].contains(term),
                "{coder:?} must not duplicate term {}",
                term.code()
            );
            assert!(
                WboTermCode::ALL.contains(term),
                "{coder:?} term {} must remain in WboTermCode::ALL",
                term.code()
            );
        }
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`lattice_coder_canonical_wbo_terms_are_dedup_and_canonical`"),
        "register doc must cross-link codec term dedup invariant"
    );
}

#[test]
fn lattice_coder_canonical_wbo_terms_end_with_t_num() {
    for coder in LatticeCoderKind::ALL {
        let terms = coder.canonical_wbo_terms();
        assert!(
            !terms.is_empty(),
            "{coder:?} must declare at least one canonical WBO term"
        );
        let last = *terms.last().expect("nonempty canonical wbo terms");
        assert_eq!(
            last,
            WboTermCode::NumericalPostCorrection,
            "{coder:?} canonical wbo terms must end with T_num"
        );
        let t_num_index = terms
            .iter()
            .position(|term| *term == WboTermCode::NumericalPostCorrection)
            .expect("T_num present in every codec canonical term row");
        assert_eq!(
            t_num_index,
            terms.len() - 1,
            "{coder:?} canonical wbo terms must place T_num exactly once at the end"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`lattice_coder_canonical_wbo_terms_end_with_t_num`"),
        "register doc must cross-link codec T_num closing-axis invariant"
    );
}

#[test]
fn residency_tier_canonical_register_terms_end_with_t_num() {
    for tier in ResidencyTier::ALL {
        let terms = tier.canonical_register_terms();
        assert!(
            !terms.is_empty(),
            "{} must declare at least one register term",
            tier.canonical_name()
        );
        let last = *terms.last().expect("nonempty register terms");
        assert_eq!(
            last,
            WboTermCode::NumericalPostCorrection,
            "{} canonical register terms must end with T_num",
            tier.canonical_name()
        );
        let t_num_index = terms
            .iter()
            .position(|term| *term == WboTermCode::NumericalPostCorrection)
            .expect("T_num present in every register tier");
        assert_eq!(
            t_num_index,
            terms.len() - 1,
            "{} canonical register terms must place T_num exactly once at the end",
            tier.canonical_name()
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`residency_tier_canonical_register_terms_end_with_t_num`"),
        "register doc must cross-link residency T_num closing-axis invariant"
    );
}

#[test]
fn residency_tier_catalog_maps_every_tier_to_primary_codec_and_terms() {
    for tier in ResidencyTier::ALL {
        for (index, term) in tier.canonical_register_terms().iter().enumerate() {
            assert!(
                !tier.canonical_register_terms()[index + 1..].contains(term),
                "{} must not duplicate {} in canonical register terms",
                tier.canonical_name(),
                term.code()
            );
        }
    }

    let rows = ResidencyTier::ALL
        .iter()
        .map(|tier| {
            (
                tier.canonical_name(),
                tier.primary_coder(),
                tier.canonical_register_terms(),
            )
        })
        .collect::<Vec<_>>();

    assert_eq!(
        rows,
        vec![
            (
                "L0 RAM hot",
                LatticeCoderKind::ExactHot,
                &[WboTermCode::NumericalPostCorrection][..],
            ),
            (
                "L1 Compressed Residual",
                LatticeCoderKind::LatticeWynerZivResidual,
                &[
                    WboTermCode::ResidualWynerZiv,
                    WboTermCode::Quantization,
                    WboTermCode::NumericalPostCorrection,
                ][..],
            ),
            (
                "L2 Shadow Sketch",
                LatticeCoderKind::ShadowKvSketch,
                &[
                    WboTermCode::KvCache,
                    WboTermCode::SubstrateBoundary,
                    WboTermCode::NumericalPostCorrection,
                ][..],
            ),
            (
                "L3 SSD Oracle",
                LatticeCoderKind::Nf4SsdOracle,
                &[
                    WboTermCode::KvCache,
                    WboTermCode::Quantization,
                    WboTermCode::SubstrateBoundary,
                    WboTermCode::NumericalPostCorrection,
                ][..],
            ),
            (
                "L4 Engram",
                LatticeCoderKind::EngramHashRecall,
                &[
                    WboTermCode::SubstrateBoundary,
                    WboTermCode::NumericalPostCorrection,
                ][..],
            ),
            (
                "L5 Network Cascade",
                LatticeCoderKind::NetworkCascade,
                &[
                    WboTermCode::SubstrateBoundary,
                    WboTermCode::SelfEvolvingSecurity,
                    WboTermCode::NumericalPostCorrection,
                ][..],
            ),
            (
                "L_SE Self-Evolving",
                LatticeCoderKind::SelfEvolvingAdapter,
                &[
                    WboTermCode::WeightRuntime,
                    WboTermCode::SelfEvolvingSecurity,
                    WboTermCode::NumericalPostCorrection,
                ][..],
            ),
        ]
    );
}

#[test]
fn residency_tier_primary_codec_exhaustiveness_matrix_is_pinned() {
    let primary_codecs = ResidencyTier::ALL
        .iter()
        .map(|tier| tier.primary_coder())
        .collect::<Vec<_>>();
    let standalone_codecs = LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| !primary_codecs.contains(coder))
        .collect::<Vec<_>>();

    assert_eq!(
        primary_codecs,
        vec![
            LatticeCoderKind::ExactHot,
            LatticeCoderKind::LatticeWynerZivResidual,
            LatticeCoderKind::ShadowKvSketch,
            LatticeCoderKind::Nf4SsdOracle,
            LatticeCoderKind::EngramHashRecall,
            LatticeCoderKind::NetworkCascade,
            LatticeCoderKind::SelfEvolvingAdapter,
        ]
    );
    assert_eq!(
        standalone_codecs,
        vec![
            LatticeCoderKind::BabaiGptqNearestPlane,
            LatticeCoderKind::SherryTernary3Of4,
            LatticeCoderKind::NestedE8,
            LatticeCoderKind::NestedLeech24,
            LatticeCoderKind::QuipE8,
            LatticeCoderKind::ResidualSketch,
        ]
    );
    assert_eq!(primary_codecs.len(), ResidencyTier::ALL.len());
    assert_eq!(
        primary_codecs.len() + standalone_codecs.len(),
        LatticeCoderKind::ALL.len()
    );
}

#[test]
fn residency_tier_primary_codecs_are_unique_and_round_trip_to_tiers() {
    for (index, tier) in ResidencyTier::ALL.iter().enumerate() {
        let primary_coder = tier.primary_coder();
        assert_eq!(
            primary_coder.primary_residency_tier(),
            Some(*tier),
            "{} primary codec must round-trip to its tier",
            tier.canonical_name()
        );
        for prior_tier in &ResidencyTier::ALL[..index] {
            assert_ne!(
                primary_coder,
                prior_tier.primary_coder(),
                "{} and {} share primary codec {:?}",
                tier.canonical_name(),
                prior_tier.canonical_name(),
                primary_coder
            );
        }
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`residency_tier_primary_codecs_are_unique_and_round_trip_to_tiers`"),
        "register doc must cross-link residency primary-codec uniqueness"
    );
}

#[test]
fn lattice_coder_primary_residency_tier_rejects_standalone_codec_promotion() {
    let rows = LatticeCoderKind::ALL
        .iter()
        .map(|coder| (*coder, coder.primary_residency_tier()))
        .collect::<Vec<_>>();

    assert_eq!(
        rows,
        vec![
            (LatticeCoderKind::ExactHot, Some(ResidencyTier::L0RamHot)),
            (
                LatticeCoderKind::LatticeWynerZivResidual,
                Some(ResidencyTier::L1CompressedResidual)
            ),
            (LatticeCoderKind::BabaiGptqNearestPlane, None),
            (LatticeCoderKind::SherryTernary3Of4, None),
            (
                LatticeCoderKind::ShadowKvSketch,
                Some(ResidencyTier::L2ShadowSketch)
            ),
            (
                LatticeCoderKind::EngramHashRecall,
                Some(ResidencyTier::L4Engram)
            ),
            (LatticeCoderKind::NestedE8, None),
            (LatticeCoderKind::NestedLeech24, None),
            (LatticeCoderKind::QuipE8, None),
            (
                LatticeCoderKind::Nf4SsdOracle,
                Some(ResidencyTier::L3SsdOracle)
            ),
            (LatticeCoderKind::ResidualSketch, None),
            (
                LatticeCoderKind::NetworkCascade,
                Some(ResidencyTier::L5NetworkCascade)
            ),
            (
                LatticeCoderKind::SelfEvolvingAdapter,
                Some(ResidencyTier::LSeSelfEvolving)
            ),
        ]
    );
    for tier in ResidencyTier::ALL {
        assert_eq!(
            tier.primary_coder().primary_residency_tier(),
            Some(tier),
            "{} primary codec must map back to its product residency tier",
            tier.canonical_name()
        );
    }
}

#[test]
fn standalone_codecs_remain_term_scoped_without_product_residency() {
    for coder in LatticeCoderKind::ALL {
        if coder.primary_residency_tier().is_some() {
            continue;
        }

        assert!(
            coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::NumericalPostCorrection),
            "{coder:?} standalone rows still owe T_num"
        );
        assert!(
            coder
                .canonical_wbo_terms()
                .iter()
                .all(|term| term.is_semantic_wbo6()
                    || *term == WboTermCode::NumericalPostCorrection),
            "{coder:?} must stay term-scoped without hidden residency ownership"
        );
        assert!(
            !matches!(
                coder.canonical_side_information(),
                [SideInformationKind::None]
                    | [SideInformationKind::StaticFactKey]
                    | [SideInformationKind::NetworkTeacher]
                    | [SideInformationKind::SurpriseGradient]
            ),
            "{coder:?} must not masquerade as a product residency side-information row"
        );
    }
}

#[test]
fn l1_residual_uses_lwz_and_sherry_stays_weight_side_only() {
    assert_eq!(
        ResidencyTier::L1CompressedResidual.primary_coder(),
        LatticeCoderKind::LatticeWynerZivResidual
    );
    assert_eq!(
        ResidencyTier::L1CompressedResidual.primary_side_information(),
        SideInformationKind::ResidualStream
    );
    assert_eq!(
        LatticeCoderKind::SherryTernary3Of4.canonical_side_information(),
        &[SideInformationKind::CalibrationHessian]
    );
    assert!(
        !LatticeCoderKind::SherryTernary3Of4
            .canonical_wbo_terms()
            .contains(&WboTermCode::ResidualWynerZiv),
        "Sherry is a weight codec; residual transfer must use the Lattice-Wyner-Ziv row"
    );
}

#[test]
fn residency_tier_catalog_attaches_numerical_guard_to_every_tier() {
    for tier in ResidencyTier::ALL {
        assert!(
            tier.canonical_register_terms()
                .contains(&WboTermCode::NumericalPostCorrection),
            "{} must carry T_num as a numerical post-correction guard",
            tier.canonical_name()
        );
    }
}

#[test]
fn lattice_coder_falsifiers_are_trimmed_ascii_nonempty_clauses() {
    for coder in LatticeCoderKind::ALL {
        let falsifier = coder.falsifier();
        assert!(!falsifier.is_empty(), "{coder:?}");
        assert_eq!(falsifier.trim(), falsifier, "{coder:?}");
        assert!(falsifier.is_ascii(), "{coder:?}");
        assert!(!falsifier.contains("  "), "{coder:?}");
        assert!(
            !falsifier.starts_with(';') && !falsifier.ends_with(';'),
            "{coder:?} falsifier must not begin or end with a semicolon"
        );
        for clause in falsifier.split(';') {
            let trimmed = clause.trim();
            assert!(
                !trimmed.is_empty(),
                "{coder:?} falsifier must not contain empty clauses: {falsifier}"
            );
        }
        let hooks = f_hooks_in(falsifier);
        assert!(
            !hooks.is_empty(),
            "{coder:?} falsifier must name at least one F-* hook: {falsifier}"
        );
    }
    for term in WboTermCode::ALL {
        let falsifier = term.falsifier();
        assert!(!falsifier.is_empty(), "{term:?}");
        assert_eq!(falsifier.trim(), falsifier, "{term:?}");
        assert!(falsifier.is_ascii(), "{term:?}");
        assert!(!falsifier.contains("  "), "{term:?}");
        for clause in falsifier.split(';') {
            let trimmed = clause.trim();
            assert!(
                !trimmed.is_empty(),
                "{term:?} falsifier must not contain empty clauses: {falsifier}"
            );
        }
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`lattice_coder_falsifiers_are_trimmed_ascii_nonempty_clauses`"),
        "register doc must cross-link codec/term falsifier string-safety guard"
    );
}

#[test]
fn public_key_registry_sizes_are_pinned() {
    assert_eq!(ResidencyTier::ALL.len(), 7);
    assert_eq!(ResidencyTier::CODES.len(), ResidencyTier::ALL.len());
    assert_eq!(LatticeCoderKind::ALL.len(), 13);
    assert_eq!(LatticeCoderKind::CODES.len(), LatticeCoderKind::ALL.len());
    assert_eq!(SideInformationKind::ALL.len(), 10);
    assert_eq!(
        SideInformationKind::CODES.len(),
        SideInformationKind::ALL.len()
    );
    assert_eq!(WboTermCode::ALL.len(), 7);
    assert_eq!(WboTermCode::CODES.len(), WboTermCode::ALL.len());
    assert_eq!(WboTermCode::SEMANTIC_WBO6.len(), 6);
    assert_eq!(LatticeWboError::ALL.len(), 18);
    assert_eq!(LatticeWboError::CODES.len(), LatticeWboError::ALL.len());
    assert_eq!(FALSIFIER_HOOK_OWNERS.len(), 4);

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`public_key_registry_sizes_are_pinned`"),
        "register doc must cross-link public-key registry sizes"
    );
}

#[test]
fn public_key_registry_aggregate_surface_is_pinned_and_disjoint() {
    let registries = [
        ("ResidencyTier::CODES", &ResidencyTier::CODES[..]),
        ("LatticeCoderKind::CODES", &LatticeCoderKind::CODES[..]),
        (
            "SideInformationKind::CODES",
            &SideInformationKind::CODES[..],
        ),
        ("WboTermCode::CODES", &WboTermCode::CODES[..]),
        ("LatticeWboError::CODES", &LatticeWboError::CODES[..]),
    ];
    let total_public_keys = registries.iter().map(|(_, keys)| keys.len()).sum::<usize>();
    assert_eq!(total_public_keys, 55);

    let mut all_keys = Vec::with_capacity(total_public_keys);
    for (registry, keys) in registries {
        assert!(!keys.is_empty(), "{registry} must not be empty");
        for key in keys {
            assert!(
                !all_keys.iter().any(|(_, existing_key)| existing_key == key),
                "{registry} public key {key} collides with another registry"
            );
            all_keys.push((registry, *key));
        }
    }
    assert_eq!(all_keys.len(), total_public_keys);

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`public_key_registry_aggregate_surface_is_pinned_and_disjoint`"),
        "register doc must cross-link aggregate public-key registry hardening"
    );
}

#[test]
fn residency_primary_falsifiers_name_wbo_drift_ledger_for_every_tier() {
    for tier in ResidencyTier::ALL {
        let hooks = f_hooks_in(tier.primary_falsifier());
        assert!(
            hooks.iter().any(|hook| *hook == "F-WBO-DriftLedger"),
            "{} primary falsifier must name F-WBO-DriftLedger: {}",
            tier.canonical_name(),
            tier.primary_falsifier()
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register
            .contains("`residency_primary_falsifiers_name_wbo_drift_ledger_for_every_tier`"),
        "register doc must cross-link residency drift-ledger falsifier coverage"
    );
}

#[test]
fn residency_primary_falsifiers_name_ulp_oracle_for_numerical_guard() {
    for tier in ResidencyTier::ALL {
        assert!(
            tier.canonical_register_terms()
                .contains(&WboTermCode::NumericalPostCorrection),
            "{} must carry T_num before requiring F-ULP-Oracle",
            tier.canonical_name()
        );
        assert!(
            contains_falsifier_hook(tier.primary_falsifier(), "F-ULP-Oracle"),
            "{} owns T_num and must name F-ULP-Oracle in its primary falsifier",
            tier.canonical_name()
        );
    }
}

#[test]
fn residency_tier_catalog_maps_every_tier_to_side_information() {
    let rows = ResidencyTier::ALL
        .iter()
        .map(|tier| (tier.canonical_name(), tier.primary_side_information()))
        .collect::<Vec<_>>();

    assert_eq!(
        rows,
        vec![
            ("L0 RAM hot", SideInformationKind::None),
            (
                "L1 Compressed Residual",
                SideInformationKind::ResidualStream
            ),
            ("L2 Shadow Sketch", SideInformationKind::ActiveSupport),
            ("L3 SSD Oracle", SideInformationKind::SsdOracle),
            ("L4 Engram", SideInformationKind::StaticFactKey),
            ("L5 Network Cascade", SideInformationKind::NetworkTeacher),
            ("L_SE Self-Evolving", SideInformationKind::SurpriseGradient),
        ]
    );
}

#[test]
fn residency_tier_primary_side_information_is_unique_across_tiers() {
    for (index, tier) in ResidencyTier::ALL.iter().enumerate() {
        let primary = tier.primary_side_information();
        for prior_tier in &ResidencyTier::ALL[..index] {
            assert_ne!(
                primary,
                prior_tier.primary_side_information(),
                "{} and {} share primary side-information {:?}",
                tier.canonical_name(),
                prior_tier.canonical_name(),
                primary
            );
        }
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`residency_tier_primary_side_information_is_unique_across_tiers`"),
        "register doc must cross-link residency primary side-information uniqueness"
    );
}

#[test]
fn residency_tier_catalog_pins_primary_rate_rows() {
    let rows = ResidencyTier::ALL
        .iter()
        .map(|tier| {
            (
                tier.canonical_name(),
                tier.primary_rate_milli_bits_per_symbol(),
            )
        })
        .collect::<Vec<_>>();

    assert_eq!(
        rows,
        vec![
            ("L0 RAM hot", None),
            ("L1 Compressed Residual", Some(1250)),
            ("L2 Shadow Sketch", None),
            ("L3 SSD Oracle", Some(4000)),
            ("L4 Engram", None),
            ("L5 Network Cascade", None),
            ("L_SE Self-Evolving", None),
        ]
    );
}

#[test]
fn residency_tier_primary_rates_match_primary_codec_rate_ownership() {
    for tier in ResidencyTier::ALL {
        assert_eq!(
            tier.primary_rate_milli_bits_per_symbol().is_some(),
            tier.primary_coder().allows_rate_parameter(),
            "{} primary rate must match {:?} rate ownership",
            tier.canonical_name(),
            tier.primary_coder()
        );
    }
}

#[test]
fn residency_tier_catalog_maps_every_tier_to_side_information_witnesses() {
    for tier in ResidencyTier::ALL {
        for (index, witness) in tier.side_information_witnesses().iter().enumerate() {
            assert!(
                !tier.side_information_witnesses()[index + 1..].contains(witness),
                "{} must not duplicate {witness:?} in side-information witnesses",
                tier.canonical_name()
            );
        }
    }

    let rows = ResidencyTier::ALL
        .iter()
        .map(|tier| (tier.canonical_name(), tier.side_information_witnesses()))
        .collect::<Vec<_>>();

    assert_eq!(
        rows,
        vec![
            ("L0 RAM hot", &[SideInformationKind::None][..]),
            (
                "L1 Compressed Residual",
                &[
                    SideInformationKind::ResidualStream,
                    SideInformationKind::DecoderLmState,
                ][..],
            ),
            (
                "L2 Shadow Sketch",
                &[SideInformationKind::ActiveSupport][..]
            ),
            (
                "L3 SSD Oracle",
                &[
                    SideInformationKind::SsdOracle,
                    SideInformationKind::ResidualStream,
                ][..],
            ),
            ("L4 Engram", &[SideInformationKind::StaticFactKey][..]),
            (
                "L5 Network Cascade",
                &[SideInformationKind::NetworkTeacher][..]
            ),
            (
                "L_SE Self-Evolving",
                &[SideInformationKind::SurpriseGradient][..],
            ),
        ]
    );

    for tier in ResidencyTier::ALL {
        assert!(
            tier.side_information_witnesses()
                .contains(&tier.primary_side_information()),
            "{} witnesses must include the primary side-information kind",
            tier.canonical_name()
        );
    }
}

#[test]
fn residency_tier_side_information_matches_primary_codec_catalog() {
    for tier in ResidencyTier::ALL {
        assert!(
            tier.primary_coder()
                .canonical_side_information()
                .contains(&tier.primary_side_information()),
            "{} primary side information must be accepted by {:?}",
            tier.canonical_name(),
            tier.primary_coder()
        );
    }
}

#[test]
fn residency_tier_side_information_witnesses_lead_with_primary_witness() {
    for tier in ResidencyTier::ALL {
        let witnesses = tier.side_information_witnesses();
        assert!(
            !witnesses.is_empty(),
            "{} must declare at least one side-information witness",
            tier.canonical_name()
        );
        assert_eq!(
            witnesses[0],
            tier.primary_side_information(),
            "{} must lead with its primary side-information witness",
            tier.canonical_name()
        );
        for (index, witness) in witnesses.iter().enumerate() {
            assert!(
                !witnesses[index + 1..].contains(witness),
                "{} must not duplicate witness {:?}",
                tier.canonical_name(),
                witness
            );
        }
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register
            .contains("`residency_tier_side_information_witnesses_lead_with_primary_witness`"),
        "register doc must cross-link residency witness primary-first invariant"
    );
}

#[test]
fn residency_tier_side_information_witnesses_match_primary_codec_catalog() {
    for tier in ResidencyTier::ALL {
        for witness in tier.side_information_witnesses() {
            assert!(
                tier.primary_coder()
                    .canonical_side_information()
                    .contains(witness),
                "{} witness {:?} must be accepted by {:?}",
                tier.canonical_name(),
                witness,
                tier.primary_coder()
            );
        }
    }
}

#[test]
fn residency_tier_catalog_maps_every_tier_to_primary_falsifier() {
    for tier in ResidencyTier::ALL {
        assert_eq!(tier.primary_falsifier(), tier.primary_coder().falsifier());
        assert!(!tier.primary_falsifier().is_empty());
    }
    assert_eq!(
        ResidencyTier::L3SsdOracle.primary_falsifier(),
        "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger; layerwise reconstruction/logit drift witness; F-ACS-AnchorLookup"
    );
}

#[test]
fn residency_tier_catalog_marks_active_support_budget_tiers() {
    let active_support_tiers = ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.allows_active_support_budget())
        .map(ResidencyTier::canonical_name)
        .collect::<Vec<_>>();

    assert_eq!(
        active_support_tiers,
        vec!["L2 Shadow Sketch", "L3 SSD Oracle"]
    );
}

#[test]
fn residency_tier_catalog_distinguishes_required_and_secondary_active_support_budget() {
    let required_tiers = ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.requires_active_support_budget())
        .map(ResidencyTier::canonical_name)
        .collect::<Vec<_>>();
    let secondary_tiers = ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.allows_secondary_active_support_budget())
        .map(ResidencyTier::canonical_name)
        .collect::<Vec<_>>();

    assert_eq!(required_tiers, vec!["L2 Shadow Sketch"]);
    assert_eq!(secondary_tiers, vec!["L3 SSD Oracle"]);
    for tier in ResidencyTier::ALL {
        assert_eq!(
            tier.allows_active_support_budget(),
            tier.requires_active_support_budget()
                || tier.allows_secondary_active_support_budget(),
            "{} active-support budget allowance must be exhausted by required or secondary paths",
            tier.canonical_name()
        );
        assert!(
            !(tier.requires_active_support_budget()
                && tier.allows_secondary_active_support_budget()),
            "{} cannot be both a required primary and optional secondary active-support row",
            tier.canonical_name()
        );
    }
}

#[test]
fn active_support_budget_residency_matrix_counts_are_pinned() {
    let required_tiers = ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.requires_active_support_budget())
        .collect::<Vec<_>>();
    let secondary_tiers = ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.allows_secondary_active_support_budget())
        .collect::<Vec<_>>();
    let allowed_tiers = ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.allows_active_support_budget())
        .collect::<Vec<_>>();
    let disallowed_tiers = ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| !tier.allows_active_support_budget())
        .collect::<Vec<_>>();

    assert_eq!(ResidencyTier::ALL.len(), 7);
    assert_eq!(required_tiers, vec![ResidencyTier::L2ShadowSketch]);
    assert_eq!(secondary_tiers, vec![ResidencyTier::L3SsdOracle]);
    assert_eq!(
        allowed_tiers,
        vec![ResidencyTier::L2ShadowSketch, ResidencyTier::L3SsdOracle]
    );
    assert_eq!(
        disallowed_tiers,
        vec![
            ResidencyTier::L0RamHot,
            ResidencyTier::L1CompressedResidual,
            ResidencyTier::L4Engram,
            ResidencyTier::L5NetworkCascade,
            ResidencyTier::LSeSelfEvolving,
        ]
    );
}

#[test]
fn residency_tier_catalog_requires_substrate_boundary_for_active_support_budget_tiers() {
    for tier in ResidencyTier::ALL {
        if tier.allows_active_support_budget() {
            assert!(
                tier.canonical_register_terms()
                    .contains(&WboTermCode::SubstrateBoundary),
                "{} may carry ActiveSupportBudget and must own T_S",
                tier.canonical_name()
            );
        }
    }
}

#[test]
fn canonical_residency_rows_validate_against_tier_maps() {
    let mut active_support_rows = Vec::new();

    for tier in ResidencyTier::ALL {
        let contributions = tier
            .canonical_register_terms()
            .iter()
            .map(|term| {
                LatticeErrorContribution::new(
                    *term,
                    format!("{} {}", tier.canonical_name(), term.code()),
                    0.01,
                )
                .expect("canonical contribution should be valid")
            })
            .collect::<Vec<_>>();
        let budget = LatticeBudget::new(
            tier.primary_coder(),
            tier.primary_rate_milli_bits_per_symbol(),
            tier.primary_side_information(),
            contributions,
        );
        let active_support = tier.allows_active_support_budget().then(|| {
            active_support_rows.push(tier.canonical_name());
            ActiveSupportBudget::new(
                2048,
                32,
                64 * 1024 * 1024,
                SideInformationKind::ActiveSupport,
            )
        });
        let entry = WboLedgerEntry::new_for_tier(
            tier,
            budget,
            active_support,
            format!("{}; F-ULP-Oracle", tier.primary_coder().falsifier()),
            "Canonical register row keeps residency, codec, terms, and falsifier aligned.",
        );

        assert_eq!(entry.validate(), Ok(()), "{}", tier.canonical_name());
    }

    assert_eq!(
        active_support_rows,
        vec!["L2 Shadow Sketch", "L3 SSD Oracle"]
    );
}

#[test]
fn wbo_ledger_entry_new_for_tier_serializes_canonical_memory_tier_names() {
    for tier in ResidencyTier::ALL {
        let budget = LatticeBudget::new(
            tier.primary_coder(),
            tier.primary_rate_milli_bits_per_symbol(),
            tier.primary_side_information(),
            tier_probe_contributions(tier),
        );
        let active_support = tier.allows_active_support_budget().then(|| {
            ActiveSupportBudget::new(128, 4, 1024, SideInformationKind::ActiveSupport)
        });
        let value = WboLedgerEntry::new_for_tier(
            tier,
            budget,
            active_support,
            tier.primary_falsifier(),
            "Typed residency row uses canonical public tier names.",
        );
        let encoded = serde_json::to_value(&value).expect("serialize ledger entry");
        let object = encoded
            .as_object()
            .expect("ledger entry must serialize as an object");

        assert_eq!(
            object["memory_tier"],
            serde_json::json!(tier.canonical_name())
        );
        assert_ne!(
            object["memory_tier"],
            serde_json::json!(format!("{tier:?}"))
        );
        assert!(value.validate().is_ok(), "{}", tier.canonical_name());
    }
}
