//! Measured-total composition tests and ledger-side falsifier-hook obligations.

use super::*;

#[test]
fn contribution_reports_measured_budget_status() {
    let missing_measurement =
        LatticeErrorContribution::new(WboTermCode::Quantization, "unmeasured", 0.1)
            .expect("valid contribution");
    let within_budget = LatticeErrorContribution::new(WboTermCode::Quantization, "within", 0.1)
        .expect("valid contribution")
        .with_measured(0.1)
        .expect("valid measurement");
    let over_budget = LatticeErrorContribution::new(WboTermCode::Quantization, "over", 0.1)
        .expect("valid contribution")
        .with_measured(0.1001)
        .expect("valid measurement");

    assert_eq!(missing_measurement.measured_within_budget(), None);
    assert_eq!(within_budget.measured_within_budget(), Some(true));
    assert_eq!(over_budget.measured_within_budget(), Some(false));
}

#[test]
fn contribution_measured_status_returns_none_for_invalid_public_fields() {
    let signed_contribution = LatticeErrorContribution {
        term: WboTermCode::NumericalPostCorrection,
        source: "signed contribution".to_string(),
        budget: -0.25,
        measured: Some(-0.5),
    };
    let nonfinite_contribution = LatticeErrorContribution {
        term: WboTermCode::NumericalPostCorrection,
        source: "nonfinite contribution".to_string(),
        budget: f64::INFINITY,
        measured: Some(0.0),
    };
    let empty_source_contribution = LatticeErrorContribution {
        term: WboTermCode::NumericalPostCorrection,
        source: " ".to_string(),
        budget: 0.0,
        measured: Some(0.0),
    };

    for contribution in [
        signed_contribution,
        nonfinite_contribution,
        empty_source_contribution,
    ] {
        assert_eq!(contribution.measured_within_budget(), None);
    }
}

#[test]
fn lattice_budget_composes_measured_totals_only_when_complete() {
    let measured_residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.2)
            .expect("valid contribution")
            .with_measured(0.12)
            .expect("valid measurement");
    let measured_quantization =
        LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.1)
            .expect("valid contribution")
            .with_measured(0.05)
            .expect("valid measurement");
    let measured_numerics =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution")
            .with_measured(0.0)
            .expect("valid measurement");
    let complete_budget = LatticeBudget::new(
        LatticeCoderKind::ResidualSketch,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![
            measured_residual.clone(),
            measured_quantization,
            measured_numerics.clone(),
        ],
    );

    assert_eq!(complete_budget.pre_softmax_budget(), 0.30000000000000004);
    assert_eq!(
        complete_budget.measured_pre_softmax_total(),
        Some(0.16999999999999998)
    );
    assert_eq!(
        complete_budget.measured_softmax_half_corrected_total(),
        Some(0.08499999999999999)
    );
    assert_eq!(complete_budget.measured_within_budget(), Some(true));

    let unmeasured_quantization =
        LatticeErrorContribution::new(WboTermCode::Quantization, "unmeasured", 0.1)
            .expect("valid contribution");
    let incomplete_budget = LatticeBudget::new(
        LatticeCoderKind::ResidualSketch,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![
            measured_residual,
            unmeasured_quantization,
            measured_numerics,
        ],
    );

    assert_eq!(incomplete_budget.measured_pre_softmax_total(), None);
    assert_eq!(
        incomplete_budget.measured_semantic_wbo6_pre_softmax_total(),
        None
    );
    assert_eq!(
        incomplete_budget.measured_numerical_post_correction_total(),
        None
    );
    assert_eq!(
        incomplete_budget.measured_softmax_half_corrected_total(),
        None
    );
    assert_eq!(incomplete_budget.measured_within_budget(), None);
}

#[test]
fn lattice_budget_measured_total_includes_numerical_post_correction() {
    let residual = LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.20)
        .expect("valid contribution")
        .with_measured(0.18)
        .expect("valid residual measurement");
    let numerics = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "softmax half correction",
        0.04,
    )
    .expect("valid numerical contribution")
    .with_measured(0.06)
    .expect("valid numerical measurement");
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![residual, numerics],
    );

    assert_eq!(budget.semantic_wbo6_pre_softmax_budget(), 0.20);
    assert_eq!(budget.numerical_post_correction_budget(), 0.04);
    assert_eq!(budget.measured_pre_softmax_total(), Some(0.24));
    assert_eq!(budget.measured_softmax_half_corrected_total(), Some(0.12));
    assert_eq!(budget.measured_within_budget(), Some(true));
}

#[test]
fn lattice_budget_measured_total_sums_duplicate_semantic_and_numerical_axes() {
    let residual_a =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual a", 0.25)
            .expect("valid residual contribution")
            .with_measured(0.125)
            .expect("valid residual measurement");
    let residual_b =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual b", 0.125)
            .expect("valid residual contribution")
            .with_measured(0.0625)
            .expect("valid residual measurement");
    let numerics_a =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics a", 0.0625)
            .expect("valid numerical contribution")
            .with_measured(0.03125)
            .expect("valid numerical measurement");
    let numerics_b =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics b", 0.03125)
            .expect("valid numerical contribution")
            .with_measured(0.015625)
            .expect("valid numerical measurement");
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![residual_a, numerics_a, residual_b, numerics_b],
    );

    assert_eq!(
        budget.measured_semantic_wbo6_pre_softmax_total(),
        Some(0.1875)
    );
    assert_eq!(
        budget.measured_numerical_post_correction_total(),
        Some(0.046875)
    );
    assert_eq!(budget.measured_pre_softmax_total(), Some(0.234375));
    assert_eq!(
        budget.measured_softmax_half_corrected_total(),
        Some(0.1171875)
    );
    assert_eq!(budget.measured_within_budget(), Some(true));
}

#[test]
fn lattice_budget_duplicate_axis_measured_totals_are_order_invariant() {
    let residual_a =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual a", 0.25)
            .expect("valid residual contribution")
            .with_measured(0.125)
            .expect("valid residual measurement");
    let residual_b =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual b", 0.125)
            .expect("valid residual contribution")
            .with_measured(0.0625)
            .expect("valid residual measurement");
    let numerics_a =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics a", 0.0625)
            .expect("valid numerical contribution")
            .with_measured(0.03125)
            .expect("valid numerical measurement");
    let numerics_b =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics b", 0.03125)
            .expect("valid numerical contribution")
            .with_measured(0.015625)
            .expect("valid numerical measurement");

    for contributions in [
        vec![
            residual_a.clone(),
            residual_b.clone(),
            numerics_a.clone(),
            numerics_b.clone(),
        ],
        vec![
            numerics_b.clone(),
            residual_b.clone(),
            numerics_a.clone(),
            residual_a.clone(),
        ],
        vec![residual_b, numerics_a, residual_a, numerics_b],
    ] {
        let budget = LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            contributions,
        );

        assert_eq!(
            budget.measured_semantic_wbo6_pre_softmax_total(),
            Some(0.1875)
        );
        assert_eq!(
            budget.measured_numerical_post_correction_total(),
            Some(0.046875)
        );
        assert_eq!(budget.measured_pre_softmax_total(), Some(0.234375));
        assert_eq!(
            budget.measured_softmax_half_corrected_total(),
            Some(0.1171875)
        );
        assert_eq!(budget.measured_within_budget(), Some(true));
    }
}

#[test]
fn lattice_budget_measured_slices_partition_complete_total() {
    let residual = LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.25)
        .expect("valid residual contribution")
        .with_measured(0.125)
        .expect("valid residual measurement");
    let quantization =
        LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.5)
            .expect("valid quantization contribution")
            .with_measured(0.25)
            .expect("valid quantization measurement");
    let numerics_a =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics a", 0.0625)
            .expect("valid numerical contribution")
            .with_measured(0.03125)
            .expect("valid numerical measurement");
    let numerics_b =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics b", 0.03125)
            .expect("valid numerical contribution")
            .with_measured(0.015625)
            .expect("valid numerical measurement");
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![residual.clone(), numerics_a, quantization, numerics_b],
    );

    let semantic = budget.measured_semantic_wbo6_pre_softmax_total();
    let numerical = budget.measured_numerical_post_correction_total();
    assert_eq!(semantic, Some(0.375));
    assert_eq!(numerical, Some(0.046875));
    assert_eq!(budget.measured_pre_softmax_total(), Some(0.421875));
    assert_eq!(
        semantic.zip(numerical).map(|(lhs, rhs)| lhs + rhs),
        Some(0.421875)
    );

    let incomplete_budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![
            residual,
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "unmeasured numerics",
                0.03125,
            )
            .expect("valid numerical contribution"),
        ],
    );

    assert_eq!(
        incomplete_budget.measured_semantic_wbo6_pre_softmax_total(),
        None
    );
    assert_eq!(
        incomplete_budget.measured_numerical_post_correction_total(),
        None
    );
}

#[test]
fn lattice_budget_measured_slices_require_complete_cross_axis_measurements() {
    let measured_residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.25)
            .expect("valid residual contribution")
            .with_measured(0.125)
            .expect("valid residual measurement");
    let unmeasured_residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.25)
            .expect("valid residual contribution");
    let measured_numerics =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.03125)
            .expect("valid numerical contribution")
            .with_measured(0.015625)
            .expect("valid numerical measurement");
    let unmeasured_numerics =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.03125)
            .expect("valid numerical contribution");

    for budget in [
        LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![unmeasured_residual, measured_numerics],
        ),
        LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![measured_residual, unmeasured_numerics],
        ),
    ] {
        assert_eq!(budget.validate(), Ok(()));
        assert_budget_measurements_pending(&budget);
    }
}

#[test]
fn lattice_budget_measured_slices_require_complete_duplicate_axis_measurements() {
    let measured_residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "measured residual", 0.25)
            .expect("valid residual contribution")
            .with_measured(0.125)
            .expect("valid residual measurement");
    let unmeasured_residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "unmeasured residual", 0.125)
            .expect("valid residual contribution");
    let measured_numerics = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "measured numerics",
        0.03125,
    )
    .expect("valid numerical contribution")
    .with_measured(0.015625)
    .expect("valid numerical measurement");
    let unmeasured_numerics = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "unmeasured numerics",
        0.03125,
    )
    .expect("valid numerical contribution");

    for budget in [
        LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![
                measured_residual.clone(),
                unmeasured_residual,
                measured_numerics.clone(),
            ],
        ),
        LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![measured_residual, measured_numerics, unmeasured_numerics],
        ),
    ] {
        assert_eq!(budget.validate(), Ok(()));
        assert_budget_measurements_pending(&budget);
    }
}

#[test]
fn lattice_budget_measured_status_handles_zero_and_over_budget_edges() {
    let zero_numerics =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "zero numerics", 0.0)
            .expect("valid zero contribution")
            .with_measured(0.0)
            .expect("valid zero measurement");
    let zero_budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![zero_numerics],
    );

    assert_eq!(zero_budget.measured_pre_softmax_total(), Some(0.0));
    assert_eq!(
        zero_budget.measured_softmax_half_corrected_total(),
        Some(0.0)
    );
    assert_eq!(zero_budget.measured_within_budget(), Some(true));

    let residual = LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.1)
        .expect("valid contribution")
        .with_measured(0.15)
        .expect("valid measurement");
    let quantization =
        LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.2)
            .expect("valid contribution")
            .with_measured(0.2)
            .expect("valid measurement");
    let numerics =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution")
            .with_measured(0.0)
            .expect("valid measurement");
    let over_budget = LatticeBudget::new(
        LatticeCoderKind::ResidualSketch,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![residual, quantization, numerics],
    );

    assert_eq!(over_budget.pre_softmax_budget(), 0.30000000000000004);
    assert_eq!(over_budget.measured_pre_softmax_total(), Some(0.35));
    assert_eq!(
        over_budget.measured_softmax_half_corrected_total(),
        Some(0.175)
    );
    assert_eq!(over_budget.measured_within_budget(), Some(false));
}

#[test]
fn budget_validation_rejects_noncanonical_exact_engram_network_and_adapter_side_info() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let cases = [
        (
            LatticeCoderKind::ExactHot,
            SideInformationKind::ActiveSupport,
        ),
        (
            LatticeCoderKind::NetworkCascade,
            SideInformationKind::DecoderLmState,
        ),
        (
            LatticeCoderKind::SelfEvolvingAdapter,
            SideInformationKind::ResidualStream,
        ),
        (
            LatticeCoderKind::EngramHashRecall,
            SideInformationKind::NetworkTeacher,
        ),
    ];

    for (coder, side_information) in cases {
        let budget = LatticeBudget::new(coder, None, side_information, vec![contribution.clone()]);
        assert_eq!(
            budget.validate_side_information(),
            Err(LatticeWboError::InvalidSideInformation)
        );
    }
}

#[test]
fn ledger_validation_accepts_canonical_active_support_budget() {
    let budget = LatticeBudget::new(
        LatticeCoderKind::ShadowKvSketch,
        None,
        SideInformationKind::ActiveSupport,
        tier_probe_contributions(ResidencyTier::L2ShadowSketch),
    );
    for support in [
        ActiveSupportBudget::new(
            2048,
            32,
            64 * 1024 * 1024,
            SideInformationKind::ActiveSupport,
        ),
        ActiveSupportBudget::new(
            u32::MAX,
            u32::MAX,
            u64::MAX,
            SideInformationKind::ActiveSupport,
        ),
    ] {
        let entry = WboLedgerEntry::new_for_tier(
            ResidencyTier::L2ShadowSketch,
            budget.clone(),
            Some(support),
            "F-WBO-DriftLedger; F-ULP-Oracle; F-KV-Direct-Gate; F-ACS-AnchorLookup",
            "Active support is accounting metadata, not a speed claim.",
        );

        assert_eq!(entry.validate(), Ok(()));
    }
}

#[test]
fn budget_validation_rejects_zero_explicit_rate() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| coder.allows_rate_parameter())
    {
        checked += 1;
        let contribution =
            LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
                .expect("valid contribution");
        let budget = LatticeBudget::new(
            coder,
            Some(0),
            coder.canonical_side_information()[0],
            vec![contribution],
        );

        assert_eq!(budget.validate(), Err(LatticeWboError::InvalidRate));
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidRate)
        );
    }
    let expected = LatticeCoderKind::ALL
        .iter()
        .filter(|coder| coder.allows_rate_parameter())
        .count();
    assert_eq!(checked, expected);
}

#[test]
fn budget_validation_rejects_missing_rate_on_rate_codecs() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| coder.allows_rate_parameter())
    {
        checked += 1;
        let budget = LatticeBudget::new(
            coder,
            None,
            coder.canonical_side_information()[0],
            vec![LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution")],
        );

        assert_eq!(budget.validate(), Err(LatticeWboError::InvalidRate));
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidRate)
        );
    }
    let expected = LatticeCoderKind::ALL
        .iter()
        .filter(|coder| coder.allows_rate_parameter())
        .count();
    assert_eq!(checked, expected);
}

#[test]
fn budget_validation_rejects_rate_on_non_rate_codecs() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| !coder.allows_rate_parameter())
    {
        checked += 1;
        let contribution = LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "non-rate codec",
            0.0,
        )
        .expect("valid contribution");
        let budget = LatticeBudget::new(
            coder,
            Some(1250),
            coder.canonical_side_information()[0],
            vec![contribution],
        );
        assert_eq!(budget.validate(), Err(LatticeWboError::InvalidRate));
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidRate)
        );
    }
    let expected = LatticeCoderKind::ALL
        .iter()
        .filter(|coder| !coder.allows_rate_parameter())
        .count();
    assert_eq!(checked, expected);
}

#[test]
fn budget_validation_accepts_nonzero_rate_on_rate_codecs() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| coder.allows_rate_parameter())
    {
        checked += 1;
        let canonical = side_information_probe_budget(coder, coder.canonical_side_information()[0]);
        assert_eq!(canonical.validate(), Ok(()), "{coder:?}");

        let max_rate = LatticeBudget::new(
            coder,
            Some(u32::MAX),
            coder.canonical_side_information()[0],
            vec![LatticeErrorContribution::new(
                coder.canonical_wbo_terms()[0],
                "max rate edge",
                0.0,
            )
            .expect("valid contribution")],
        );

        assert_eq!(max_rate.validate_rate(), Ok(()), "{coder:?}");
    }
    let expected = LatticeCoderKind::ALL
        .iter()
        .filter(|coder| coder.allows_rate_parameter())
        .count();
    assert_eq!(checked, expected);
}

#[test]
fn contribution_rejects_empty_source() {
    assert_eq!(
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "", 0.0),
        Err(LatticeWboError::EmptySource)
    );
}

#[test]
fn ledger_validation_rejects_empty_contributions_falsifier_and_caveat() {
    let empty_contributions = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        Vec::new(),
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L0RamHot,
        empty_contributions,
        None,
        "F-WBO-DriftLedger",
        "Exact path still pays numerics.",
    );
    assert_eq!(entry.validate(), Err(LatticeWboError::EmptyContributions));

    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution.clone()],
    );
    let missing_falsifier = WboLedgerEntry::new_for_tier(
        ResidencyTier::L0RamHot,
        budget,
        None,
        "",
        "Exact path still pays numerics.",
    );
    assert_eq!(
        missing_falsifier.validate(),
        Err(LatticeWboError::EmptyFalsifier)
    );

    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution],
    );
    let missing_caveat = WboLedgerEntry::new_for_tier(
        ResidencyTier::L0RamHot,
        budget,
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle",
        "",
    );
    assert_eq!(missing_caveat.validate(), Err(LatticeWboError::EmptyCaveat));
}

#[test]
fn ledger_string_guards_reject_whitespace_only_fields() {
    assert_eq!(
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "   ", 0.0),
        Err(LatticeWboError::EmptySource)
    );

    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution.clone()],
    );
    let missing_tier = WboLedgerEntry::new(
        "   ",
        budget.clone(),
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle",
        "Exact path still pays numerics.",
    );
    assert_eq!(
        missing_tier.validate(),
        Err(LatticeWboError::EmptyMemoryTier)
    );

    let missing_falsifier = WboLedgerEntry::new_for_tier(
        ResidencyTier::L0RamHot,
        budget,
        None,
        "   ",
        "Exact path still pays numerics.",
    );
    assert_eq!(
        missing_falsifier.validate(),
        Err(LatticeWboError::EmptyFalsifier)
    );

    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution],
    );
    let missing_caveat = WboLedgerEntry::new_for_tier(
        ResidencyTier::L0RamHot,
        budget,
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle",
        "   ",
    );
    assert_eq!(missing_caveat.validate(), Err(LatticeWboError::EmptyCaveat));
}

#[test]
fn ledger_validation_requires_codec_falsifier_hook() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution.clone()],
    );
    let unrelated_falsifier = WboLedgerEntry::new_for_tier(
        ResidencyTier::L0RamHot,
        budget,
        None,
        "adapter replay/provenance verifier",
        "Exact path still pays numerics.",
    );
    assert_eq!(
        unrelated_falsifier.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );

    let boundary_contribution =
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "provider boundary", 0.0)
            .expect("valid boundary contribution");
    let security_contribution = LatticeErrorContribution::new(
        WboTermCode::SelfEvolvingSecurity,
        "provider replay boundary",
        0.0,
    )
    .expect("valid security contribution");
    let numerics =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid numerical contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::NetworkCascade,
        None,
        SideInformationKind::NetworkTeacher,
        vec![boundary_contribution, security_contribution, numerics],
    );
    let lower_case_provider_hook = WboLedgerEntry::new_for_tier(
        ResidencyTier::L5NetworkCascade,
        budget,
        None,
        "provider/provenance replay; F-ULP-Oracle; F-WBO-DriftLedger; F-ACS-AnchorLookup",
        "Provider evidence must replay.",
    );
    assert_eq!(lower_case_provider_hook.validate(), Ok(()));
}

#[test]
fn ledger_validation_requires_term_falsifier_hook_for_each_contribution() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::NetworkCascade,
        None,
        SideInformationKind::NetworkTeacher,
        vec![contribution],
    );
    let provider_only = WboLedgerEntry::new_for_tier(
        ResidencyTier::L5NetworkCascade,
        budget,
        None,
        "provider/provenance replay",
        "Provider replay alone does not witness the numerical guard.",
    );

    assert_eq!(
        provider_only.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
}

#[test]
fn ledger_validation_requires_wbo_drift_ledger_for_every_row() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid numerical contribution");
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
        "F-ULP-Oracle",
        "Numerical oracle without drift ledger is incomplete.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
}

#[test]
fn ledger_validation_requires_ulp_oracle_for_numerical_post_correction() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution],
    );
    let wbo_only = WboLedgerEntry::new_for_tier(
        ResidencyTier::L0RamHot,
        budget,
        None,
        "F-WBO-DriftLedger",
        "Numerical correction must name the ULP oracle.",
    );

    assert_eq!(
        wbo_only.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
}

#[test]
fn ledger_validation_requires_kv_direct_gate_for_kv_cache_term() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::KvCache, "ShadowKV restore", 0.01)
            .expect("valid KV contribution"),
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
            .expect("valid substrate contribution"),
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
        "F-WBO-DriftLedger; F-ULP-Oracle; F-ACS-AnchorLookup",
        "KV/cache rows must name the direct K/V gate.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
}

#[test]
fn ledger_validation_requires_anchor_lookup_for_substrate_boundary_term() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "engram lookup", 0.01)
            .expect("valid substrate contribution"),
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution"),
    ];
    let budget = LatticeBudget::new(
        LatticeCoderKind::EngramHashRecall,
        None,
        SideInformationKind::StaticFactKey,
        contributions,
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L4Engram,
        budget,
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle",
        "Substrate-boundary rows must name the anchor lookup verifier.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
}

#[test]
fn ledger_validation_requires_term_specific_security_verifier_for_t_se() {
    let network_contributions = vec![
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "teacher boundary", 0.01)
            .expect("valid substrate contribution"),
        LatticeErrorContribution::new(
            WboTermCode::SelfEvolvingSecurity,
            "network teacher security",
            0.01,
        )
        .expect("valid security contribution"),
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution"),
    ];
    let network_budget = LatticeBudget::new(
        LatticeCoderKind::NetworkCascade,
        None,
        SideInformationKind::NetworkTeacher,
        network_contributions,
    );
    let network_without_replay = WboLedgerEntry::new_for_tier(
        ResidencyTier::L5NetworkCascade,
        network_budget.clone(),
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle; F-ACS-AnchorLookup",
        "Network security rows must replay provider provenance.",
    );
    let network_with_adapter_replay = WboLedgerEntry::new_for_tier(
        ResidencyTier::L5NetworkCascade,
        network_budget.clone(),
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle; F-ACS-AnchorLookup; adapter replay/provenance verifier",
        "Network security rows cannot borrow adapter replay provenance.",
    );
    let network_with_capitalized_replay = WboLedgerEntry::new_for_tier(
        ResidencyTier::L5NetworkCascade,
        network_budget,
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle; F-ACS-AnchorLookup; Provider/provenance replay",
        "Network security verifier spelling must match the canonical clause.",
    );

    assert_eq!(
        network_without_replay.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
    assert_eq!(
        network_with_adapter_replay.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
    assert_eq!(
        network_with_capitalized_replay.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );

    let adapter_contributions = vec![
        LatticeErrorContribution::new(WboTermCode::WeightRuntime, "adapter weight delta", 0.01)
            .expect("valid weight contribution"),
        LatticeErrorContribution::new(WboTermCode::SelfEvolvingSecurity, "adapter promotion", 0.01)
            .expect("valid security contribution"),
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution"),
    ];
    let adapter_budget = LatticeBudget::new(
        LatticeCoderKind::SelfEvolvingAdapter,
        None,
        SideInformationKind::SurpriseGradient,
        adapter_contributions,
    );
    let adapter_without_replay = WboLedgerEntry::new_for_tier(
        ResidencyTier::LSeSelfEvolving,
        adapter_budget.clone(),
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle; layerwise reconstruction/logit drift witness",
        "Adapter security rows must replay adapter provenance.",
    );
    let adapter_with_provider_replay = WboLedgerEntry::new_for_tier(
        ResidencyTier::LSeSelfEvolving,
        adapter_budget.clone(),
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle; provider/provenance replay; layerwise reconstruction/logit drift witness",
        "Adapter security rows cannot borrow provider replay provenance.",
    );
    let adapter_with_capitalized_replay = WboLedgerEntry::new_for_tier(
        ResidencyTier::LSeSelfEvolving,
        adapter_budget,
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle; Adapter replay/provenance verifier; layerwise reconstruction/logit drift witness",
        "Adapter security verifier spelling must match the canonical clause.",
    );

    assert_eq!(
        adapter_without_replay.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
    assert_eq!(
        adapter_with_provider_replay.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
    assert_eq!(
        adapter_with_capitalized_replay.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
}

#[test]
fn ledger_validation_requires_residual_kl_slice_for_residual_term() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.01)
            .expect("valid residual contribution"),
        LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.01)
            .expect("valid quantization contribution"),
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution"),
    ];
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        contributions,
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L1CompressedResidual,
        budget,
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle; layerwise reconstruction/logit drift witness",
        "Residual rows must include the residual KL witness.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
}

#[test]
fn ledger_validation_requires_layerwise_reconstruction_for_quantization_term() {
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
        "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger",
        "Quantization rows must include a reconstruction or logit-drift witness.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
}

#[test]
fn ledger_validation_requires_layerwise_reconstruction_for_weight_runtime_term() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::WeightRuntime, "adapter delta", 0.01)
            .expect("valid weight contribution"),
        LatticeErrorContribution::new(WboTermCode::SelfEvolvingSecurity, "adapter replay", 0.01)
            .expect("valid security contribution"),
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "softmax half correction",
            0.0,
        )
        .expect("valid numerical contribution"),
    ];
    let budget = LatticeBudget::new(
        LatticeCoderKind::SelfEvolvingAdapter,
        None,
        SideInformationKind::SurpriseGradient,
        contributions,
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::LSeSelfEvolving,
        budget,
        None,
        "adapter replay/provenance verifier; F-ULP-Oracle; F-WBO-DriftLedger",
        "Weight/runtime rows must include the layerwise reconstruction witness.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
}

#[test]
fn ledger_validation_requires_numerical_post_correction_contribution() {
    let contributions = vec![
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.01)
            .expect("valid residual contribution"),
        LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.01)
            .expect("valid quantization contribution"),
    ];
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        contributions,
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L1CompressedResidual,
        budget,
        None,
        "F-WBO-DriftLedger; residual KL slice; layerwise reconstruction/logit drift witness",
        "Every ledger row must reserve the numerical post-correction guard.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::MissingNumericalPostCorrectionTerm)
    );
}

#[test]
fn ledger_validation_rejects_spoofed_ulp_oracle_hook() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution],
    );
    let spoofed = WboLedgerEntry::new_for_tier(
        ResidencyTier::L0RamHot,
        budget,
        None,
        "not-F-ULP-Oracle; F-WBO-DriftLedger",
        "Numerical correction must name the canonical ULP oracle hook.",
    );

    assert_eq!(
        spoofed.validate(),
        Err(LatticeWboError::MissingCanonicalFalsifier)
    );
}

#[test]
fn ledger_validation_rejects_unowned_falsifier_hooks() {
    for falsifier in [
        "F-WBO-DriftLedger; F-ULP-Oracle; F-Imaginary-Probe",
        "F-WBO-DriftLedger; F-ULP-Oracle; f-imaginary-probe",
        "F-WBO-DriftLedger; F-ULP-Oracle; F-Imaginary-Probe/v2",
        "F-WBO-DriftLedger; F-ULP-Oracle/v2",
        "F-WBO-DriftLedger/v2; F-ULP-Oracle",
        "F-WBO-DriftLedger; F-ULP-Oracleβ",
        "βF-WBO-DriftLedger; F-ULP-Oracle",
        "f-wbo-driftledger; f-ulp-oracle",
    ] {
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
            falsifier,
            "Extra falsifier hooks must still have owners.",
        );

        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::MissingCanonicalFalsifier)
        );
    }
}

#[test]
fn lattice_budget_validate_combines_rate_and_side_information_guards() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.01)
            .expect("valid contribution");
    let empty_contributions = LatticeBudget::new(
        LatticeCoderKind::QuipE8,
        Some(2000),
        SideInformationKind::CalibrationHessian,
        Vec::new(),
    );
    let invalid_rate = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(0),
        SideInformationKind::DecoderLmState,
        vec![contribution.clone()],
    );
    let invalid_side_information = LatticeBudget::new(
        LatticeCoderKind::QuipE8,
        Some(2000),
        SideInformationKind::RuntimeKvHessian,
        vec![contribution.clone()],
    );
    let valid = LatticeBudget::new(
        LatticeCoderKind::QuipE8,
        Some(2000),
        SideInformationKind::CalibrationHessian,
        vec![
            contribution,
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ],
    );

    assert_eq!(
        empty_contributions.validate(),
        Err(LatticeWboError::EmptyContributions)
    );
    assert_eq!(invalid_rate.validate(), Err(LatticeWboError::InvalidRate));
    assert_eq!(
        invalid_side_information.validate(),
        Err(LatticeWboError::InvalidSideInformation)
    );
    assert_eq!(valid.validate(), Ok(()));
}
