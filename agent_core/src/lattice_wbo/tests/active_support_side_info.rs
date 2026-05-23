//! Side-information validation and ActiveSupportBudget rejection-matrix tests.

use super::*;

#[test]
fn nested_lattice_codecs_reject_residual_and_kv_side_information() {
    let nested_codecs = [LatticeCoderKind::NestedE8, LatticeCoderKind::NestedLeech24];
    let borrowed_witnesses = [
        SideInformationKind::DecoderLmState,
        SideInformationKind::ResidualStream,
        SideInformationKind::RuntimeKvHessian,
        SideInformationKind::ActiveSupport,
        SideInformationKind::SsdOracle,
    ];
    let mut checked = 0;

    for coder in nested_codecs {
        assert_eq!(
            coder.canonical_side_information(),
            &[SideInformationKind::CalibrationHessian],
            "{coder:?} must stay a standalone weight-codec row"
        );

        for side_information in borrowed_witnesses {
            let budget = side_information_probe_budget(coder, side_information);
            assert_eq!(
                budget.validate_side_information(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} direct validator borrowed {side_information:?}"
            );
            assert_eq!(
                budget.validate(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} full validator borrowed {side_information:?}"
            );
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} composition validator borrowed {side_information:?}"
            );
            checked += 1;
        }
    }

    assert_eq!(checked, nested_codecs.len() * borrowed_witnesses.len());
}

#[test]
fn ledger_validation_rejects_active_support_budget_with_wrong_side_information() {
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
    let wrong_support_kind =
        ActiveSupportBudget::new(128, 4, 1024, SideInformationKind::ResidualStream);
    let entry = WboLedgerEntry::new(
        "L2 Shadow Sketch",
        budget,
        Some(wrong_support_kind),
        "F-WBO-DriftLedger; F-ACS-AnchorLookup; F-ULP-Oracle",
        "Active support must be explicitly budgeted.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::InvalidActiveSupportSideInformation)
    );
}

#[test]
fn active_support_budget_wrong_tag_rejection_matrix_counts_are_pinned() {
    let mut checked = 0;

    for tier in ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.allows_active_support_budget())
    {
        let budget = LatticeBudget::new(
            tier.primary_coder(),
            tier.primary_rate_milli_bits_per_symbol(),
            tier.primary_side_information(),
            tier_probe_contributions(tier),
        );
        for side_information in SideInformationKind::ALL {
            if side_information == SideInformationKind::ActiveSupport {
                continue;
            }
            let support = ActiveSupportBudget::new(128, 4, 1024, side_information);
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget.clone(),
                Some(support),
                tier.primary_falsifier(),
                "Active support budget must use ActiveSupport side information.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidActiveSupportSideInformation),
                "{} accepted active-support budget side information {side_information:?}",
                tier.canonical_name()
            );
            checked += 1;
        }
    }

    let allowed_tiers = ResidencyTier::ALL
        .iter()
        .filter(|tier| tier.allows_active_support_budget())
        .count();
    assert_eq!(allowed_tiers, 2);
    assert_eq!(SideInformationKind::ALL.len() - 1, 9);
    assert_eq!(checked, 18);
    assert_eq!(
        checked,
        allowed_tiers * (SideInformationKind::ALL.len() - 1)
    );
}

#[test]
fn ledger_validation_allows_mixed_side_information_with_valid_active_support_budget() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::KvCache, "SSD KV restore", 0.0)
            .expect("valid KV contribution"),
        LatticeErrorContribution::new(WboTermCode::Quantization, "NF4 page quant", 0.0)
            .expect("valid quantization contribution"),
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "SSD boundary", 0.01)
            .expect("valid contribution"),
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution"),
    ];
    let budget = LatticeBudget::new(
        LatticeCoderKind::Nf4SsdOracle,
        Some(4000),
        SideInformationKind::SsdOracle,
        contributions,
    );
    let support =
        ActiveSupportBudget::new(256, 8, 4 * 1024 * 1024, SideInformationKind::ActiveSupport);
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L3SsdOracle,
        budget,
        Some(support),
        ResidencyTier::L3SsdOracle.primary_falsifier(),
        "SSD oracle rows may still carry active-support accounting.",
    );

    assert_eq!(entry.validate(), Ok(()));
}

#[test]
fn ledger_validation_allows_max_active_support_budget_without_lattice_overflow() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::KvCache, "SSD KV restore", 0.0)
            .expect("valid KV contribution")
            .with_measured(0.0)
            .expect("valid measured KV contribution"),
        LatticeErrorContribution::new(WboTermCode::Quantization, "NF4 page quant", 0.0)
            .expect("valid quantization contribution")
            .with_measured(0.0)
            .expect("valid measured quantization contribution"),
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "SSD boundary", 0.01)
            .expect("valid contribution")
            .with_measured(0.01)
            .expect("valid measured contribution"),
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution")
        .with_measured(0.0)
        .expect("valid measured numerical contribution"),
    ];
    let budget = LatticeBudget::new(
        LatticeCoderKind::Nf4SsdOracle,
        Some(4000),
        SideInformationKind::SsdOracle,
        contributions,
    );
    let support = ActiveSupportBudget::new(
        u32::MAX,
        u32::MAX,
        u64::MAX,
        SideInformationKind::ActiveSupport,
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L3SsdOracle,
        budget,
        Some(support),
        ResidencyTier::L3SsdOracle.primary_falsifier(),
        "SSD oracle rows keep active-support accounting separate from lattice totals.",
    );

    assert_eq!(entry.validate(), Ok(()));
    assert_eq!(entry.budget.measured_pre_softmax_total(), Some(0.01));
    assert_eq!(entry.budget.measured_within_budget(), Some(true));
}

#[test]
fn ledger_validation_allows_l3_ssd_oracle_without_active_support_budget() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::KvCache, "SSD KV restore", 0.01)
            .expect("valid KV contribution"),
        LatticeErrorContribution::new(WboTermCode::Quantization, "NF4 page quant", 0.01)
            .expect("valid quantization contribution"),
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "SSD page oracle", 0.01)
            .expect("valid substrate contribution"),
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution"),
    ];
    let budget = LatticeBudget::new(
        LatticeCoderKind::Nf4SsdOracle,
        Some(4000),
        SideInformationKind::SsdOracle,
        contributions,
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L3SsdOracle,
        budget,
        None,
        "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger; layerwise reconstruction/logit drift witness; F-ACS-AnchorLookup",
        "L3 SSD oracle keeps SsdOracle primary; active-support accounting is optional.",
    );

    assert_eq!(entry.validate(), Ok(()));
}

fn assert_typed_row_rejects_rate(tier: ResidencyTier, rate: Option<u32>) {
    let budget = LatticeBudget::new(
        tier.primary_coder(),
        rate,
        tier.primary_side_information(),
        tier_probe_contributions(tier),
    );
    let entry = WboLedgerEntry::new_for_tier(
        tier,
        budget,
        None,
        tier.primary_coder().falsifier(),
        "Typed rows still reject invalid codec rates.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::InvalidRate),
        "{} accepted rate {rate:?}",
        tier.canonical_name()
    );
}

#[test]
fn ledger_validation_rejects_invalid_rate_on_typed_rate_rows() {
    let mut checked = 0;
    for tier in ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.primary_rate_milli_bits_per_symbol().is_some())
    {
        assert_typed_row_rejects_rate(tier, None);
        checked += 1;
    }

    assert_eq!(checked, 2);
}

#[test]
fn ledger_validation_rejects_zero_rate_on_typed_rate_rows() {
    let mut checked = 0;
    for tier in ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.primary_rate_milli_bits_per_symbol().is_some())
    {
        assert_typed_row_rejects_rate(tier, Some(0));
        checked += 1;
    }

    assert_eq!(checked, 2);
}

#[test]
fn ledger_validation_rejects_wrong_primary_rate_on_typed_rate_rows() {
    let mut checked = 0;
    for tier in ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.primary_rate_milli_bits_per_symbol().is_some())
    {
        let wrong_rate = tier
            .primary_rate_milli_bits_per_symbol()
            .expect("rate-bearing tier")
            + 1;
        assert_typed_row_rejects_rate(tier, Some(wrong_rate));
        checked += 1;
    }

    assert_eq!(checked, 2);
}

#[test]
fn ledger_validation_rejects_rate_on_typed_non_rate_rows() {
    let mut checked = 0;
    for tier in ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.primary_rate_milli_bits_per_symbol().is_none())
    {
        assert_typed_row_rejects_rate(tier, Some(1250));
        checked += 1;
    }

    assert_eq!(checked, ResidencyTier::ALL.len() - 2);
}

#[test]
fn ledger_validation_rejects_active_support_budget_without_substrate_boundary_term() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::KvCache, "ShadowKV restore", 0.01)
            .expect("valid KV contribution"),
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
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L2ShadowSketch,
        budget,
        Some(ActiveSupportBudget::new(
            2048,
            32,
            64 * 1024 * 1024,
            SideInformationKind::ActiveSupport,
        )),
        "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger",
        "Active support cannot be attached without a substrate-boundary term.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::MissingSubstrateBoundaryTerm)
    );
}

#[test]
fn ledger_validation_rejects_zero_active_support_budget_even_when_secondary() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "SSD boundary", 0.01)
            .expect("valid contribution"),
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution"),
    ];
    let budget = LatticeBudget::new(
        LatticeCoderKind::Nf4SsdOracle,
        Some(4000),
        SideInformationKind::SsdOracle,
        contributions,
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L3SsdOracle,
        budget,
        Some(ActiveSupportBudget::zero(
            SideInformationKind::ActiveSupport,
        )),
        "F-KV-Direct-Gate; F-WBO-DriftLedger; F-ACS-AnchorLookup; F-ULP-Oracle",
        "A zero active-support budget cannot witness skipped support.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::InvalidActiveSupportSideInformation)
    );
}

#[test]
fn ledger_validation_rejects_zero_active_support_budget_with_wrong_side_information() {
    let mut checked = 0;

    for tier in ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.allows_active_support_budget())
    {
        let budget = LatticeBudget::new(
            tier.primary_coder(),
            tier.primary_rate_milli_bits_per_symbol(),
            tier.primary_side_information(),
            tier_probe_contributions(tier),
        );
        for side_information in SideInformationKind::ALL {
            if side_information == SideInformationKind::ActiveSupport {
                continue;
            }

            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget.clone(),
                Some(ActiveSupportBudget::zero(side_information)),
                tier.primary_falsifier(),
                "Zero active-support budgets with wrong witnesses stay invalid.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidActiveSupportSideInformation),
                "{} accepted all-zero active support with {side_information:?}",
                tier.canonical_name()
            );
            checked += 1;
        }
    }

    let allowed_tiers = ResidencyTier::ALL
        .iter()
        .filter(|tier| tier.allows_active_support_budget())
        .count();
    let non_active_side_information = SideInformationKind::ALL
        .iter()
        .filter(|kind| **kind != SideInformationKind::ActiveSupport)
        .count();
    assert_eq!(checked, allowed_tiers * non_active_side_information);
}

#[test]
fn active_support_budget_partial_zero_axis_rejection_matrix_counts_are_pinned() {
    let active_support_cases = [
        ActiveSupportBudget::new(0, 8, 4 * 1024 * 1024, SideInformationKind::ActiveSupport),
        ActiveSupportBudget::new(256, 0, 4 * 1024 * 1024, SideInformationKind::ActiveSupport),
        ActiveSupportBudget::new(256, 8, 0, SideInformationKind::ActiveSupport),
    ];
    let mut checked = 0;
    for tier in ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.allows_active_support_budget())
    {
        let budget = LatticeBudget::new(
            tier.primary_coder(),
            tier.primary_rate_milli_bits_per_symbol(),
            tier.primary_side_information(),
            tier_probe_contributions(tier),
        );
        for active_support in active_support_cases {
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget.clone(),
                Some(active_support),
                tier.primary_falsifier(),
                "Every active-support axis must be nonzero.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidActiveSupportSideInformation),
                "{} accepted partial-zero active support {:?}",
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
    assert_eq!(allowed_tiers, 2);
    assert_eq!(active_support_cases.len(), 3);
    assert_eq!(checked, 6);
    assert_eq!(checked, allowed_tiers * active_support_cases.len());
}

#[test]
fn ledger_validation_rejects_combined_malformed_active_support_budget() {
    let partial_axes: [(u32, u32, u64); 3] = [
        (0, 8, 4 * 1024 * 1024),
        (256, 0, 4 * 1024 * 1024),
        (256, 8, 0),
    ];
    let mut checked = 0;
    for tier in ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.allows_active_support_budget())
    {
        let budget = LatticeBudget::new(
            tier.primary_coder(),
            tier.primary_rate_milli_bits_per_symbol(),
            tier.primary_side_information(),
            tier_probe_contributions(tier),
        );
        for (tokens, pages, bytes) in partial_axes {
            for side_information in SideInformationKind::ALL
                .iter()
                .copied()
                .filter(|kind| *kind != SideInformationKind::ActiveSupport)
            {
                let entry = WboLedgerEntry::new_for_tier(
                    tier,
                    budget.clone(),
                    Some(ActiveSupportBudget::new(
                        tokens,
                        pages,
                        bytes,
                        side_information,
                    )),
                    tier.primary_falsifier(),
                    "Malformed active-support budgets stay invalid even when defects combine.",
                );

                assert_eq!(
                    entry.validate(),
                    Err(LatticeWboError::InvalidActiveSupportSideInformation),
                    "{} accepted active-support axes ({tokens}, {pages}, {bytes}) with {side_information:?}",
                    tier.canonical_name()
                );
                checked += 1;
            }
        }
    }
    let allowed_tiers = ResidencyTier::ALL
        .iter()
        .filter(|tier| tier.allows_active_support_budget())
        .count();
    let non_active_side_information = SideInformationKind::ALL
        .iter()
        .filter(|kind| **kind != SideInformationKind::ActiveSupport)
        .count();
    assert_eq!(
        checked,
        allowed_tiers * partial_axes.len() * non_active_side_information
    );
}

#[test]
fn active_support_budget_disallowed_tier_rejection_matrix_counts_are_pinned() {
    let mut checked = 0;
    let active_support_cases = [
        ActiveSupportBudget::new(1, 1, 1, SideInformationKind::ActiveSupport),
        ActiveSupportBudget::new(
            u32::MAX,
            u32::MAX,
            u64::MAX,
            SideInformationKind::ActiveSupport,
        ),
    ];
    for support in active_support_cases {
        for tier in ResidencyTier::ALL
            .iter()
            .copied()
            .filter(|tier| !tier.allows_active_support_budget())
        {
            checked += 1;
            let contribution = LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "numerics",
                0.0,
            )
            .expect("valid contribution");
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_rate_milli_bits_per_symbol(),
                tier.primary_side_information(),
                vec![contribution],
            );
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                Some(support),
                tier.primary_falsifier(),
                "Rows outside L2 and L3 cannot carry active-support side budgets.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidActiveSupportSideInformation),
                "{}",
                tier.canonical_name()
            );
        }
    }
    let expected = ResidencyTier::ALL
        .iter()
        .filter(|tier| !tier.allows_active_support_budget())
        .count();
    assert_eq!(expected, 5);
    assert_eq!(checked, 10);
    assert_eq!(checked, expected * active_support_cases.len());
}

#[test]
fn residency_tier_round_trips_from_canonical_name() {
    for tier in ResidencyTier::ALL {
        assert_eq!(
            ResidencyTier::from_canonical_name(tier.canonical_name()),
            Some(tier)
        );
    }
    for alias in [
        "L6 Unknown",
        " L0 RAM hot",
        "L0 RAM hot ",
        "l0 RAM hot",
        "LSE Self-Evolving",
        "L_SE self-evolving",
        "L4 Network Cascade",
    ] {
        assert_eq!(ResidencyTier::from_canonical_name(alias), None);
    }
}

#[test]
fn residency_tier_canonical_names_are_trimmed_and_display_safe() {
    for tier in ResidencyTier::ALL {
        let name = tier.canonical_name();
        assert!(!name.is_empty(), "{tier:?}");
        assert_eq!(name.trim(), name, "{tier:?}");
        assert!(name.is_ascii(), "{tier:?}");
        assert!(!name.contains("  "), "{tier:?}");
        assert_ne!(name, format!("{tier:?}"), "{tier:?}");
        assert_eq!(ResidencyTier::from_canonical_name(name), Some(tier));
    }
}

#[test]
fn residency_tier_canonical_names_use_l_prefix_lane_label() {
    for tier in ResidencyTier::ALL {
        let name = tier.canonical_name();
        assert!(name.starts_with('L'), "{tier:?} canonical name {name}");
        let after_prefix = &name[1..];
        let first_after_prefix = after_prefix.chars().next().expect("nonempty body");
        assert!(
            first_after_prefix.is_ascii_digit() || first_after_prefix == '_',
            "{tier:?} canonical name {name} must use digit or `_` after the `L` prefix"
        );
        let (lane_label, rest) = name
            .split_once(' ')
            .expect("residency canonical name must include a lane label after the L code");
        assert!(!lane_label.is_empty(), "{tier:?} lane label is empty");
        assert!(
            !rest.trim().is_empty(),
            "{tier:?} must name a lane after the L code"
        );
        assert!(
            lane_label
                .chars()
                .all(|ch| ch == 'L' || ch == '_' || ch.is_ascii_alphanumeric()),
            "{tier:?} lane label {lane_label} must be ASCII alphanumeric or `_`"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`residency_tier_canonical_names_use_l_prefix_lane_label`"),
        "register doc must cross-link residency lane label format"
    );
}

#[test]
fn ledger_validation_rejects_unknown_residency_tier() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution],
    );
    let entry = WboLedgerEntry::new(
        "L6 Unknown",
        budget,
        None,
        "F-WBO-DriftLedger",
        "Only canonical T17B tiers are valid.",
    );

    assert_eq!(entry.validate(), Err(LatticeWboError::UnknownResidencyTier));
}

#[test]
fn ledger_validation_rejects_residency_debug_labels() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution],
    );

    for tier in ResidencyTier::ALL {
        let debug_label = format!("{tier:?}");
        let entry = WboLedgerEntry::new(
            debug_label.as_str(),
            budget.clone(),
            None,
            "F-WBO-DriftLedger; F-ULP-Oracle",
            "Only canonical T17B tier names are valid.",
        );

        assert_ne!(debug_label, tier.canonical_name());
        assert_eq!(ResidencyTier::from_canonical_name(&debug_label), None);
        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::UnknownResidencyTier),
            "{debug_label}"
        );
    }
}

#[test]
fn ledger_entry_can_be_created_from_typed_residency_tier() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution],
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L0RamHot,
        budget,
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle",
        "Exact path still pays numerics.",
    );

    assert_eq!(entry.memory_tier, "L0 RAM hot");
    assert_eq!(entry.validate(), Ok(()));
}

#[test]
fn ledger_entry_reports_unique_wbo_terms_in_order() {
    let residual_a =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual a", 0.01)
            .expect("valid residual contribution");
    let quantization =
        LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.02)
            .expect("valid quantization contribution");
    let residual_b =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual b", 0.03)
            .expect("valid residual contribution");
    let numerics_a =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics a", 0.0)
            .expect("valid numerical contribution");
    let numerics_b =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics b", 0.0)
            .expect("valid numerical contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![residual_a, quantization, numerics_a, residual_b, numerics_b],
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L1CompressedResidual,
        budget,
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle; residual KL slice; layerwise reconstruction/logit drift witness",
        "Duplicate contribution terms are reported once for ledger accounting.",
    );

    assert_eq!(
        entry.wbo_terms(),
        vec![
            WboTermCode::ResidualWynerZiv,
            WboTermCode::Quantization,
            WboTermCode::NumericalPostCorrection
        ]
    );
    assert_eq!(entry.validate(), Ok(()));
}

#[test]
fn ledger_entry_wbo_terms_deduplicates_every_codec_catalog() {
    for coder in LatticeCoderKind::ALL {
        let mut contributions = coder
            .canonical_wbo_terms()
            .iter()
            .copied()
            .enumerate()
            .map(|(index, term)| {
                LatticeErrorContribution::new(
                    term,
                    format!("{coder:?} first {}", term.code()),
                    (index + 1) as f64 / 32.0,
                )
                .expect("valid contribution")
            })
            .collect::<Vec<_>>();
        contributions.extend(
            coder
                .canonical_wbo_terms()
                .iter()
                .rev()
                .copied()
                .enumerate()
                .map(|(index, term)| {
                    LatticeErrorContribution::new(
                        term,
                        format!("{coder:?} duplicate {}", term.code()),
                        (index + 1) as f64 / 64.0,
                    )
                    .expect("valid duplicate contribution")
                }),
        );
        let entry = WboLedgerEntry::new(
            "catalog probe",
            LatticeBudget::new(
                coder,
                coder.allows_rate_parameter().then_some(1250),
                coder.canonical_side_information()[0],
                contributions,
            ),
            None,
            "F-WBO-DriftLedger",
            "Summary probe only.",
        );

        assert_eq!(
            entry.wbo_terms(),
            coder.canonical_wbo_terms(),
            "{coder:?} leaked duplicate terms or changed first-seen order"
        );
    }
}
