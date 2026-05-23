//! LatticeBudget validation, measured-status, and composition-total invariants.

use super::*;

#[test]
fn lattice_budget_validation_requires_numerical_post_correction_term() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::WeightRuntime, "weight delta", 0.01)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::BabaiGptqNearestPlane,
        None,
        SideInformationKind::CalibrationHessian,
        vec![contribution],
    );

    assert_eq!(
        budget.validate(),
        Err(LatticeWboError::MissingNumericalPostCorrectionTerm)
    );
}

#[test]
fn lattice_budget_composition_requires_numerical_post_correction_term() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::WeightRuntime, "weight delta", 0.01)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::BabaiGptqNearestPlane,
        None,
        SideInformationKind::CalibrationHessian,
        vec![contribution],
    );

    assert_eq!(
        budget.validate_composition(),
        Err(LatticeWboError::MissingNumericalPostCorrectionTerm)
    );
}

#[test]
fn lattice_budget_composition_rejects_empty_source_public_contributions() {
    let contribution = LatticeErrorContribution {
        term: WboTermCode::NumericalPostCorrection,
        source: " ".to_string(),
        budget: 0.0,
        measured: Some(0.0),
    };
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution],
    );

    assert_eq!(
        budget.validate_composition(),
        Err(LatticeWboError::EmptySource)
    );
    assert_eq!(budget.validate(), Err(LatticeWboError::EmptySource));
}

#[test]
fn lattice_budget_measured_status_requires_numerical_post_correction_term() {
    let residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual codec", 0.1)
            .expect("valid contribution")
            .with_measured(0.1)
            .expect("valid measurement");
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![residual],
    );

    assert_eq!(
        budget.validate(),
        Err(LatticeWboError::MissingNumericalPostCorrectionTerm)
    );
    assert_eq!(
        budget.validate_composition(),
        Err(LatticeWboError::MissingNumericalPostCorrectionTerm)
    );
    assert_budget_measurements_pending(&budget);
}

#[test]
fn lattice_budget_measured_status_returns_none_for_invalid_side_information() {
    let residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual codec", 0.1)
            .expect("valid contribution")
            .with_measured(0.1)
            .expect("valid measurement");
    let numerics = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "softmax half correction",
        0.0,
    )
    .expect("valid contribution")
    .with_measured(0.0)
    .expect("valid measurement");
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::CalibrationHessian,
        vec![residual, numerics],
    );

    assert_eq!(
        budget.validate(),
        Err(LatticeWboError::InvalidSideInformation)
    );
    assert_eq!(
        budget.validate_composition(),
        Err(LatticeWboError::InvalidSideInformation)
    );
    assert_budget_measurements_pending(&budget);
}

#[test]
fn lattice_budget_measured_status_returns_none_for_every_noncanonical_side_information() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL {
        let allowed = coder.canonical_side_information();
        for side_information in SideInformationKind::ALL {
            if allowed.contains(&side_information) {
                continue;
            }

            let budget = measured_probe_budget(
                coder,
                coder.allows_rate_parameter().then_some(1250),
                side_information,
            );

            assert_eq!(
                budget.validate(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} measured status accepted noncanonical side information {side_information:?}"
            );
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} measured composition accepted noncanonical side information {side_information:?}"
            );
            assert_budget_measurements_pending(&budget);
            checked += 1;
        }
    }

    let expected = LatticeCoderKind::ALL
        .iter()
        .map(|coder| SideInformationKind::ALL.len() - coder.canonical_side_information().len())
        .sum::<usize>();
    assert_eq!(checked, expected);
}

#[test]
fn codec_noncanonical_side_information_rejection_matrix_counts_are_pinned() {
    let counts = LatticeCoderKind::ALL
        .iter()
        .map(|coder| {
            (
                *coder,
                SideInformationKind::ALL.len() - coder.canonical_side_information().len(),
            )
        })
        .collect::<Vec<_>>();

    assert_eq!(
        counts,
        vec![
            (LatticeCoderKind::ExactHot, 9),
            (LatticeCoderKind::LatticeWynerZivResidual, 6),
            (LatticeCoderKind::BabaiGptqNearestPlane, 9),
            (LatticeCoderKind::SherryTernary3Of4, 9),
            (LatticeCoderKind::ShadowKvSketch, 7),
            (LatticeCoderKind::EngramHashRecall, 9),
            (LatticeCoderKind::NestedE8, 9),
            (LatticeCoderKind::NestedLeech24, 9),
            (LatticeCoderKind::QuipE8, 9),
            (LatticeCoderKind::Nf4SsdOracle, 7),
            (LatticeCoderKind::ResidualSketch, 7),
            (LatticeCoderKind::NetworkCascade, 9),
            (LatticeCoderKind::SelfEvolvingAdapter, 9),
        ]
    );
    assert_eq!(counts.iter().map(|(_, count)| count).sum::<usize>(), 108);
}

#[test]
fn lattice_budget_measured_status_returns_none_for_invalid_rate() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| coder.allows_rate_parameter())
    {
        for invalid_rate in [None, Some(0)] {
            let budget = measured_probe_budget(
                coder,
                invalid_rate,
                coder.canonical_side_information()[0],
            );

            assert_eq!(budget.validate(), Err(LatticeWboError::InvalidRate));
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidRate)
            );
            assert_budget_measurements_pending(&budget);
            checked += 1;
        }
    }
    for coder in LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| !coder.allows_rate_parameter())
    {
        let budget =
            measured_probe_budget(coder, Some(1250), coder.canonical_side_information()[0]);

        assert_eq!(budget.validate(), Err(LatticeWboError::InvalidRate));
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidRate)
        );
        assert_budget_measurements_pending(&budget);
        checked += 1;
    }

    let rate_codec_count = LatticeCoderKind::ALL
        .iter()
        .filter(|coder| coder.allows_rate_parameter())
        .count();
    let non_rate_codec_count = LatticeCoderKind::ALL.len() - rate_codec_count;
    assert_eq!(checked, (2 * rate_codec_count) + non_rate_codec_count);
}

#[test]
fn lattice_budget_validation_rejects_terms_outside_codec_map() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL {
        let canonical_terms = coder.canonical_wbo_terms();
        for term in WboTermCode::ALL {
            if canonical_terms.contains(&term) {
                continue;
            }

            let invalid_term =
                LatticeErrorContribution::new(term, format!("invalid {}", term.code()), 0.01)
                    .expect("valid contribution");
            let numerical = LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution");
            let invalid = LatticeBudget::new(
                coder,
                coder.allows_rate_parameter().then_some(1250),
                coder.canonical_side_information()[0],
                vec![invalid_term, numerical],
            );
            assert_eq!(
                invalid.validate(),
                Err(LatticeWboError::InvalidWboTermForCodec),
                "{coder:?} accepted noncanonical WBO term {term:?}"
            );
            assert_eq!(
                invalid.validate_composition(),
                Err(LatticeWboError::InvalidWboTermForCodec),
                "{coder:?} composition accepted noncanonical WBO term {term:?}"
            );
            checked += 1;
        }
    }

    let valid_term = LatticeErrorContribution::new(
        WboTermCode::SelfEvolvingSecurity,
        "adapter replay",
        0.01,
    )
    .expect("valid contribution");
    let numerical = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "softmax half correction",
        0.0,
    )
    .expect("valid numerical contribution");
    let valid = LatticeBudget::new(
        LatticeCoderKind::SelfEvolvingAdapter,
        None,
        SideInformationKind::SurpriseGradient,
        vec![valid_term, numerical],
    );
    assert_eq!(valid.validate(), Ok(()));
    let expected = LatticeCoderKind::ALL
        .iter()
        .map(|coder| WboTermCode::ALL.len() - coder.canonical_wbo_terms().len())
        .sum::<usize>();
    assert_eq!(checked, expected);
}

#[test]
fn lattice_budget_validation_rejects_foreign_terms_before_missing_t_num() {
    let mut checked = 0;

    for coder in LatticeCoderKind::ALL {
        let canonical_terms = coder.canonical_wbo_terms();
        for term in WboTermCode::ALL {
            if canonical_terms.contains(&term) {
                continue;
            }

            let invalid_term = LatticeErrorContribution::new(
                term,
                format!("{coder:?} foreign {}", term.code()),
                0.01,
            )
            .expect("valid foreign contribution shape");
            let budget = LatticeBudget::new(
                coder,
                coder.allows_rate_parameter().then_some(1250),
                coder.canonical_side_information()[0],
                vec![invalid_term],
            );

            assert!(
                !budget.contributions.iter().any(|contribution| {
                    contribution.term == WboTermCode::NumericalPostCorrection
                }),
                "{coder:?} fixture must also omit T_num"
            );
            assert_eq!(
                budget.validate_terms(),
                Err(LatticeWboError::InvalidWboTermForCodec),
                "{coder:?} fixture must carry a real foreign term {term:?}"
            );
            assert_eq!(
                budget.validate(),
                Err(LatticeWboError::InvalidWboTermForCodec),
                "{coder:?} full validation let missing T_num hide {term:?}"
            );
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidWboTermForCodec),
                "{coder:?} composition let missing T_num hide {term:?}"
            );
            checked += 1;
        }
    }

    let expected = LatticeCoderKind::ALL
        .iter()
        .map(|coder| WboTermCode::ALL.len() - coder.canonical_wbo_terms().len())
        .sum::<usize>();
    assert_eq!(checked, expected);
}

#[test]
fn lattice_budget_measured_status_returns_none_for_invalid_terms() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL {
        let canonical_terms = coder.canonical_wbo_terms();
        for term in WboTermCode::ALL {
            if canonical_terms.contains(&term) {
                continue;
            }

            let invalid_term =
                LatticeErrorContribution::new(term, format!("invalid {}", term.code()), 0.01)
                    .expect("valid contribution")
                    .with_measured(0.01)
                    .expect("valid measurement");
            let numerical = LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution")
            .with_measured(0.0)
            .expect("valid numerical measurement");
            let budget = LatticeBudget::new(
                coder,
                coder.allows_rate_parameter().then_some(1250),
                coder.canonical_side_information()[0],
                vec![invalid_term, numerical],
            );

            assert_eq!(
                budget.validate(),
                Err(LatticeWboError::InvalidWboTermForCodec),
                "{coder:?} measured status accepted noncanonical WBO term {term:?}"
            );
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidWboTermForCodec),
                "{coder:?} measured composition accepted noncanonical WBO term {term:?}"
            );
            assert_budget_measurements_pending(&budget);
            checked += 1;
        }
    }

    let expected = LatticeCoderKind::ALL
        .iter()
        .map(|coder| WboTermCode::ALL.len() - coder.canonical_wbo_terms().len())
        .sum::<usize>();
    assert_eq!(checked, expected);
}

#[test]
fn lattice_budget_validation_rejects_nonfinite_composed_totals() {
    let contribution_a =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "a", f64::MAX)
            .expect("finite contribution")
            .with_measured(f64::MAX)
            .expect("finite measurement");
    let contribution_b =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "b", f64::MAX)
            .expect("finite contribution")
            .with_measured(f64::MAX)
            .expect("finite measurement");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution_a, contribution_b],
    );

    assert_eq!(
        budget.validate_composition(),
        Err(LatticeWboError::InvalidBudgetComposition)
    );
    assert_eq!(
        budget.validate(),
        Err(LatticeWboError::InvalidBudgetComposition)
    );
}

#[test]
fn lattice_budget_composition_rejects_empty_public_contributions() {
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        Vec::new(),
    );

    assert_eq!(
        budget.validate_composition(),
        Err(LatticeWboError::EmptyContributions)
    );
}

#[test]
fn lattice_budget_measured_status_returns_none_for_empty_public_contributions() {
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        Vec::new(),
    );

    assert_eq!(budget.validate(), Err(LatticeWboError::EmptyContributions));
    assert_eq!(
        budget.validate_composition(),
        Err(LatticeWboError::EmptyContributions)
    );
    assert_budget_measurements_pending(&budget);
}

#[test]
fn lattice_budget_measured_status_returns_none_for_overflowed_totals() {
    let contribution_a =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "a", f64::MAX)
            .expect("finite contribution")
            .with_measured(f64::MAX)
            .expect("finite measurement");
    let contribution_b =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "b", f64::MAX)
            .expect("finite contribution")
            .with_measured(f64::MAX)
            .expect("finite measurement");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution_a, contribution_b],
    );

    assert_eq!(
        budget.validate_composition(),
        Err(LatticeWboError::InvalidBudgetComposition)
    );
    assert_eq!(
        budget.validate(),
        Err(LatticeWboError::InvalidBudgetComposition)
    );
    assert_budget_measurements_pending(&budget);
}

#[test]
fn lattice_budget_validation_rejects_signed_contribution_fields_even_when_totals_cancel() {
    let negative_budget = LatticeErrorContribution {
        term: WboTermCode::NumericalPostCorrection,
        source: "signed numerics".to_string(),
        budget: -1.0,
        measured: Some(0.0),
    };
    let offsetting_budget = LatticeErrorContribution {
        term: WboTermCode::NumericalPostCorrection,
        source: "offsetting numerics".to_string(),
        budget: 1.0,
        measured: Some(0.0),
    };
    let negative_measurement = LatticeErrorContribution {
        term: WboTermCode::NumericalPostCorrection,
        source: "signed measurement".to_string(),
        budget: 0.0,
        measured: Some(-0.25),
    };
    let offsetting_measurement = LatticeErrorContribution {
        term: WboTermCode::NumericalPostCorrection,
        source: "offsetting measurement".to_string(),
        budget: 0.0,
        measured: Some(0.25),
    };

    for contributions in [
        vec![negative_budget, offsetting_budget],
        vec![negative_measurement, offsetting_measurement],
    ] {
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            contributions,
        );

        assert_eq!(budget.validate(), Err(LatticeWboError::InvalidBudget));
    }
}

#[test]
fn lattice_budget_composition_rejects_nan_axes_before_totals() {
    let nan_budget_axis = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: "nan budget axis".to_string(),
            budget: f64::NAN,
            measured: Some(0.0),
        }],
    );
    let nan_measured_axis = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![LatticeErrorContribution {
            term: WboTermCode::NumericalPostCorrection,
            source: "nan measured axis".to_string(),
            budget: 0.0,
            measured: Some(f64::NAN),
        }],
    );

    for budget in [nan_budget_axis, nan_measured_axis] {
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidBudget)
        );
        assert_eq!(budget.validate(), Err(LatticeWboError::InvalidBudget));
        assert_budget_measurements_pending(&budget);
    }
}

#[test]
fn lattice_budget_composition_rejects_nan_axes_with_mixed_max_peer() {
    let nan_semantic_with_max_numerics = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![
            LatticeErrorContribution {
                term: WboTermCode::ResidualWynerZiv,
                source: "nan semantic budget".to_string(),
                budget: f64::NAN,
                measured: Some(0.0),
            },
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "max numerical peer",
                f64::MAX,
            )
            .expect("valid max numerical peer")
            .with_measured(f64::MAX)
            .expect("valid max numerical peer measurement"),
        ],
    );
    let max_semantic_with_nan_numerics = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![
            LatticeErrorContribution::new(
                WboTermCode::ResidualWynerZiv,
                "max semantic peer",
                f64::MAX,
            )
            .expect("valid max semantic peer")
            .with_measured(f64::MAX)
            .expect("valid max semantic peer measurement"),
            LatticeErrorContribution {
                term: WboTermCode::NumericalPostCorrection,
                source: "nan numerical measurement".to_string(),
                budget: 0.0,
                measured: Some(f64::NAN),
            },
        ],
    );

    for budget in [
        nan_semantic_with_max_numerics,
        max_semantic_with_nan_numerics,
    ] {
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidBudget)
        );
        assert_eq!(budget.validate(), Err(LatticeWboError::InvalidBudget));
        assert_budget_measurements_pending(&budget);
    }
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`lattice_budget_composition_rejects_nan_axes_with_mixed_max_peer`"),
        "register doc must cross-link mixed max/NaN composition guard"
    );
}

#[test]
fn lattice_budget_composition_property_matrix_pins_zero_max_mixed_and_nan_axes() {
    let zero_numerics = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "zero numerics",
        0.0,
    )
    .expect("valid zero numerics")
    .with_measured(0.0)
    .expect("valid zero measurement");
    let finite_residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "finite residual", 0.25)
            .expect("valid finite residual")
            .with_measured(0.125)
            .expect("valid finite residual measurement");
    let max_residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "max residual", f64::MAX)
            .expect("valid max residual")
            .with_measured(f64::MAX)
            .expect("valid max residual measurement");

    let cases = [
        (
            "zero-only",
            LatticeBudget::new(
                LatticeCoderKind::ExactHot,
                None,
                SideInformationKind::None,
                vec![zero_numerics.clone()],
            ),
            Ok(()),
            Some(0.0),
        ),
        (
            "mixed-finite-zero",
            LatticeBudget::new(
                LatticeCoderKind::LatticeWynerZivResidual,
                Some(1250),
                SideInformationKind::ResidualStream,
                vec![finite_residual, zero_numerics.clone()],
            ),
            Ok(()),
            Some(0.125),
        ),
        (
            "mixed-max-zero",
            LatticeBudget::new(
                LatticeCoderKind::LatticeWynerZivResidual,
                Some(1250),
                SideInformationKind::ResidualStream,
                vec![max_residual.clone(), zero_numerics.clone()],
            ),
            Ok(()),
            Some(f64::MAX),
        ),
        (
            "mixed-max-max-overflow",
            LatticeBudget::new(
                LatticeCoderKind::LatticeWynerZivResidual,
                Some(1250),
                SideInformationKind::ResidualStream,
                vec![
                    max_residual,
                    LatticeErrorContribution::new(
                        WboTermCode::NumericalPostCorrection,
                        "max numerics",
                        f64::MAX,
                    )
                    .expect("valid max numerics")
                    .with_measured(f64::MAX)
                    .expect("valid max numerics measurement"),
                ],
            ),
            Err(LatticeWboError::InvalidBudgetComposition),
            None,
        ),
        (
            "mixed-nan-zero",
            LatticeBudget::new(
                LatticeCoderKind::LatticeWynerZivResidual,
                Some(1250),
                SideInformationKind::ResidualStream,
                vec![
                    LatticeErrorContribution {
                        term: WboTermCode::ResidualWynerZiv,
                        source: "nan residual".to_string(),
                        budget: f64::NAN,
                        measured: Some(0.0),
                    },
                    zero_numerics,
                ],
            ),
            Err(LatticeWboError::InvalidBudget),
            None,
        ),
    ];

    for (label, budget, expected_validation, expected_measured_total) in cases {
        assert_eq!(
            budget.validate_composition(),
            expected_validation,
            "{label}"
        );
        assert_eq!(budget.validate(), expected_validation, "{label}");
        assert_eq!(
            budget.measured_pre_softmax_total(),
            expected_measured_total,
            "{label}"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains(
            "`lattice_budget_composition_property_matrix_pins_zero_max_mixed_and_nan_axes`"
        ),
        "register doc must cross-link zero/max/mixed/NaN composition matrix"
    );
}

#[test]
fn lattice_budget_measured_status_returns_none_for_invalid_public_fields() {
    let negative_measurement = LatticeErrorContribution {
        term: WboTermCode::NumericalPostCorrection,
        source: "signed measurement".to_string(),
        budget: 0.0,
        measured: Some(-0.25),
    };
    let offsetting_measurement = LatticeErrorContribution {
        term: WboTermCode::NumericalPostCorrection,
        source: "offsetting measurement".to_string(),
        budget: 0.0,
        measured: Some(0.25),
    };
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![negative_measurement, offsetting_measurement],
    );

    assert_eq!(budget.validate(), Err(LatticeWboError::InvalidBudget));
    assert_eq!(
        budget.validate_composition(),
        Err(LatticeWboError::InvalidBudget)
    );
    assert_budget_measurements_pending(&budget);
}

#[test]
fn lattice_budget_validation_accepts_zero_and_single_max_budget_edges() {
    let zero_contribution = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "zero numerics",
        0.0,
    )
    .expect("valid zero contribution")
    .with_measured(0.0)
    .expect("valid zero measurement");
    let zero_budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![zero_contribution],
    );

    assert_eq!(zero_budget.validate(), Ok(()));
    assert_eq!(zero_budget.pre_softmax_budget(), 0.0);
    assert_eq!(zero_budget.softmax_half_corrected_budget(), 0.0);

    let max_contribution = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "max finite numerics",
        f64::MAX,
    )
    .expect("single finite max contribution")
    .with_measured(f64::MAX)
    .expect("single finite max measurement");
    let max_budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![max_contribution],
    );

    assert_eq!(max_budget.validate(), Ok(()));
    assert!(max_budget.softmax_half_corrected_budget().is_finite());
    assert_eq!(max_budget.measured_within_budget(), Some(true));
}

#[test]
fn lattice_budget_softmax_half_pre_post_helpers_match_canonical_totals() {
    let residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.20)
            .expect("valid residual")
            .with_measured(0.18)
            .expect("valid residual measurement");
    let numerics =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.04)
            .expect("valid numerics")
            .with_measured(0.03)
            .expect("valid numerics measurement");
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![residual, numerics],
    );

    assert_eq!(budget.validate(), Ok(()));
    assert_eq!(
        budget.softmax_half_pre_correction_budget(),
        budget.pre_softmax_budget()
    );
    assert_eq!(
        budget.softmax_half_post_correction_budget(),
        budget.softmax_half_corrected_budget()
    );
    assert_eq!(budget.softmax_half_pre_correction_budget(), 0.20 + 0.04);
    assert_eq!(
        budget.softmax_half_post_correction_budget(),
        0.5 * (0.20 + 0.04)
    );
    assert_eq!(
        budget.measured_softmax_half_pre_correction_total(),
        budget.measured_pre_softmax_total()
    );
    assert_eq!(
        budget.measured_softmax_half_post_correction_total(),
        budget.measured_softmax_half_corrected_total()
    );
    assert_eq!(
        budget.measured_softmax_half_pre_correction_total(),
        Some(0.18 + 0.03)
    );
    assert_eq!(
        budget.measured_softmax_half_post_correction_total(),
        Some(0.5 * (0.18 + 0.03))
    );
}

#[test]
fn lattice_budget_composition_handles_signed_max_and_mixed_axes() {
    let max_residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "max residual", f64::MAX)
            .expect("single finite max residual")
            .with_measured(f64::MAX)
            .expect("single finite max residual measurement");
    let zero_numerics = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "zero numerics",
        0.0,
    )
    .expect("valid zero numerical guard")
    .with_measured(0.0)
    .expect("valid zero numerical measurement");
    let single_max_mixed_axis = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![max_residual.clone(), zero_numerics.clone()],
    );

    assert_eq!(single_max_mixed_axis.validate(), Ok(()));
    assert_eq!(
        single_max_mixed_axis.measured_pre_softmax_total(),
        Some(f64::MAX)
    );
    assert_eq!(
        single_max_mixed_axis.measured_semantic_wbo6_pre_softmax_total(),
        Some(f64::MAX)
    );
    assert_eq!(
        single_max_mixed_axis.measured_numerical_post_correction_total(),
        Some(0.0)
    );
    assert_eq!(
        single_max_mixed_axis.measured_softmax_half_corrected_total(),
        Some(0.5 * f64::MAX)
    );
    assert_eq!(single_max_mixed_axis.measured_within_budget(), Some(true));

    let overflowed_mixed_axes = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![
            max_residual,
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "max numerics",
                f64::MAX,
            )
            .expect("single finite max numerical guard")
            .with_measured(f64::MAX)
            .expect("single finite max numerical measurement"),
        ],
    );

    assert_eq!(
        overflowed_mixed_axes.validate(),
        Err(LatticeWboError::InvalidBudgetComposition)
    );
    assert_budget_measurements_pending(&overflowed_mixed_axes);

    let signed_mixed_axis = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![
            LatticeErrorContribution {
                term: WboTermCode::ResidualWynerZiv,
                source: "signed residual".to_string(),
                budget: -1.0,
                measured: Some(0.0),
            },
            zero_numerics,
        ],
    );

    assert_eq!(
        signed_mixed_axis.validate_composition(),
        Err(LatticeWboError::InvalidBudget)
    );
    assert_eq!(
        signed_mixed_axis.validate(),
        Err(LatticeWboError::InvalidBudget)
    );
    assert_budget_measurements_pending(&signed_mixed_axis);
}

#[test]
fn lattice_budget_composition_rejects_axis_local_overflow_slices() {
    let zero_numerics = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "zero numerics",
        0.0,
    )
    .expect("valid zero numerical guard")
    .with_measured(0.0)
    .expect("valid zero numerical measurement");
    let finite_residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "finite residual", 1.0)
            .expect("valid finite residual")
            .with_measured(1.0)
            .expect("valid finite residual measurement");

    for budget in [
        LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![
                LatticeErrorContribution::new(
                    WboTermCode::ResidualWynerZiv,
                    "max semantic a",
                    f64::MAX,
                )
                .expect("valid max semantic contribution")
                .with_measured(f64::MAX)
                .expect("valid max semantic measurement"),
                LatticeErrorContribution::new(
                    WboTermCode::ResidualWynerZiv,
                    "max semantic b",
                    f64::MAX,
                )
                .expect("valid max semantic contribution")
                .with_measured(f64::MAX)
                .expect("valid max semantic measurement"),
                zero_numerics.clone(),
            ],
        ),
        LatticeBudget::new(
            LatticeCoderKind::LatticeWynerZivResidual,
            Some(1250),
            SideInformationKind::ResidualStream,
            vec![
                finite_residual.clone(),
                LatticeErrorContribution::new(
                    WboTermCode::NumericalPostCorrection,
                    "max numerical a",
                    f64::MAX,
                )
                .expect("valid max numerical contribution")
                .with_measured(f64::MAX)
                .expect("valid max numerical measurement"),
                LatticeErrorContribution::new(
                    WboTermCode::NumericalPostCorrection,
                    "max numerical b",
                    f64::MAX,
                )
                .expect("valid max numerical contribution")
                .with_measured(f64::MAX)
                .expect("valid max numerical measurement"),
            ],
        ),
    ] {
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidBudgetComposition)
        );
        assert_eq!(
            budget.validate(),
            Err(LatticeWboError::InvalidBudgetComposition)
        );
        assert_budget_measurements_pending(&budget);
    }
}
