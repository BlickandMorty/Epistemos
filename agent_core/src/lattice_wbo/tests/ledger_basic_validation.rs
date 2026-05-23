//! Basic ledger-validation guards: active-support presence, malformed envelopes, and contribution-value invariants.

use super::*;

#[test]
fn ledger_validation_requires_active_support_for_active_support_rows() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
            .expect("valid support contribution"),
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution"),
    ];
    let budget = LatticeBudget::new(
        LatticeCoderKind::ShadowKvSketch,
        None,
        SideInformationKind::ActiveSupport,
        contributions,
    );
    let missing_support = WboLedgerEntry::new(
        "L2 Shadow Sketch",
        budget,
        None,
        "F-WBO-DriftLedger; F-ACS-AnchorLookup; F-ULP-Oracle",
        "Active support must be explicitly budgeted.",
    );

    assert_eq!(
        missing_support.validate(),
        Err(LatticeWboError::MissingActiveSupportBudget)
    );
}

#[test]
fn ledger_validation_rejects_missing_active_support_before_missing_t_num() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::KvCache, "ShadowKV cache", 0.01)
            .expect("valid cache contribution"),
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
            .expect("valid support contribution"),
    ];
    let budget = LatticeBudget::new(
        LatticeCoderKind::ShadowKvSketch,
        None,
        SideInformationKind::ActiveSupport,
        contributions,
    );
    let missing_support = WboLedgerEntry::new_for_tier(
        ResidencyTier::L2ShadowSketch,
        budget,
        None,
        "F-WBO-DriftLedger; F-KV-Direct-Gate; F-ACS-AnchorLookup",
        "Missing required active support must not be hidden by a missing numerical guard.",
    );

    assert_eq!(
        missing_support.validate(),
        Err(LatticeWboError::MissingActiveSupportBudget)
    );
}

#[test]
fn ledger_validation_rejects_malformed_active_support_before_missing_t_num() {
    let malformed_support = [
        ActiveSupportBudget::zero(SideInformationKind::ActiveSupport),
        ActiveSupportBudget::new(128, 4, 1024, SideInformationKind::ResidualStream),
    ];
    let mut checked = 0;

    for tier in ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.allows_active_support_budget())
    {
        let contributions = tier
            .canonical_register_terms()
            .iter()
            .copied()
            .filter(|term| *term != WboTermCode::NumericalPostCorrection)
            .map(|term| {
                LatticeErrorContribution::new(
                    term,
                    format!("{} without T_num", tier.canonical_name()),
                    0.01,
                )
                .expect("valid contribution")
            })
            .collect::<Vec<_>>();
        let budget = LatticeBudget::new(
            tier.primary_coder(),
            tier.primary_rate_milli_bits_per_symbol(),
            tier.primary_side_information(),
            contributions,
        );

        for active_support in malformed_support {
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget.clone(),
                Some(active_support),
                tier.primary_falsifier(),
                "Malformed active support must not be hidden by a missing numerical guard.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidActiveSupportSideInformation),
                "{} let missing T_num hide malformed active support {:?}",
                tier.canonical_name(),
                active_support
            );
            checked += 1;
        }
    }

    let allowed_tiers = ResidencyTier::ALL
        .iter()
        .filter(|tier| tier.allows_active_support_budget())
        .count();
    assert_eq!(checked, allowed_tiers * malformed_support.len());
}

#[test]
fn ledger_validation_rejects_empty_register_fields() {
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        Vec::new(),
    );
    let empty_tier = WboLedgerEntry::new(
        "",
        budget,
        None,
        "F-WBO-DriftLedger",
        "Exact path still pays numerics.",
    );

    assert_eq!(empty_tier.validate(), Err(LatticeWboError::EmptyMemoryTier));
}

#[test]
fn contribution_budget_rejects_negative_nan_and_infinite_values() {
    for budget in [-0.01, f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
        assert_eq!(
            LatticeErrorContribution::new(WboTermCode::Quantization, "bad budget", budget),
            Err(LatticeWboError::InvalidBudget)
        );
    }

    let contribution =
        LatticeErrorContribution::new(WboTermCode::Quantization, "finite budget", 1.0)
            .expect("finite budget should be valid");
    for measured in [-0.01, f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
        assert_eq!(
            contribution.clone().with_measured(measured),
            Err(LatticeWboError::InvalidBudget)
        );
    }
}

#[test]
fn active_support_budget_preserves_max_values() {
    let value = ActiveSupportBudget::new(
        u32::MAX,
        u32::MAX,
        u64::MAX,
        SideInformationKind::ActiveSupport,
    );
    let encoded = serde_json::to_string(&value).expect("serialize max active support budget");
    let decoded: ActiveSupportBudget =
        serde_json::from_str(&encoded).expect("deserialize max active support budget");

    assert_eq!(decoded, value);
    assert!(!decoded.is_zero());
}

#[test]
fn active_support_budget_zero_axis_predicates_distinguish_partial_zero() {
    let zero = ActiveSupportBudget::zero(SideInformationKind::ActiveSupport);
    assert!(zero.is_zero());
    assert!(zero.has_zero_axis());

    for partial in [
        ActiveSupportBudget::new(0, 1, 1, SideInformationKind::ActiveSupport),
        ActiveSupportBudget::new(1, 0, 1, SideInformationKind::ActiveSupport),
        ActiveSupportBudget::new(1, 1, 0, SideInformationKind::ActiveSupport),
    ] {
        assert!(!partial.is_zero());
        assert!(partial.has_zero_axis());
    }

    let nonzero = ActiveSupportBudget::new(1, 1, 1, SideInformationKind::ActiveSupport);
    assert!(!nonzero.is_zero());
    assert!(!nonzero.has_zero_axis());
}

#[test]
fn residency_tier_catalog_covers_l0_through_lse_register_rows() {
    assert_eq!(
        ResidencyTier::ALL
            .iter()
            .map(|tier| tier.canonical_name())
            .collect::<Vec<_>>(),
        vec![
            "L0 RAM hot",
            "L1 Compressed Residual",
            "L2 Shadow Sketch",
            "L3 SSD Oracle",
            "L4 Engram",
            "L5 Network Cascade",
            "L_SE Self-Evolving",
        ]
    );
}

#[test]
fn residency_tier_public_codes_match_all_canonical_names() {
    let canonical_names = ResidencyTier::ALL
        .iter()
        .map(|tier| tier.canonical_name())
        .collect::<Vec<_>>();

    assert_eq!(ResidencyTier::CODES, canonical_names.as_slice());
    for (tier, code) in ResidencyTier::ALL.iter().zip(ResidencyTier::CODES) {
        assert_eq!(tier.canonical_name(), code);
        assert_eq!(ResidencyTier::from_canonical_name(code), Some(*tier));
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`residency_tier_public_codes_match_all_canonical_names`"),
        "register doc must cross-link residency public-code exhaustiveness"
    );
}

#[test]
fn lattice_wbo_error_public_keys_are_trimmed_ascii_pascal_case() {
    for error in LatticeWboError::ALL {
        let key = error.key();
        let debug = format!("{error:?}");
        assert!(!key.is_empty(), "{error:?}");
        assert_eq!(key.trim(), key, "{error:?}");
        assert!(key.is_ascii(), "{error:?}");
        assert!(!key.contains(' '), "{error:?} key {key}");
        assert!(!key.contains('-'), "{error:?} key {key}");
        assert!(!key.contains('_'), "{error:?} key {key}");
        let first = key.chars().next().expect("nonempty");
        assert!(first.is_ascii_uppercase(), "{error:?} key {key}");
        assert!(
            key.chars().all(|ch| ch.is_ascii_alphanumeric()),
            "{error:?} key {key}"
        );
        assert_eq!(key, debug.as_str(), "{error:?} debug should match key");
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`lattice_wbo_error_public_keys_are_trimmed_ascii_pascal_case`"),
        "register doc must cross-link error public-key formatting safety"
    );
}
