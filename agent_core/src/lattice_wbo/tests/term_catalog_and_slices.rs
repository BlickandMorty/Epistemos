//! WboTermCode catalog and LatticeBudget semantic/numerical slice partition tests.

use super::*;

#[test]
fn wbo_term_codes_are_trimmed_ascii_axis_keys() {
    for term in WboTermCode::ALL {
        let code = term.code();
        let debug = format!("{term:?}");
        assert!(!code.is_empty(), "{term:?}");
        assert_eq!(code.trim(), code, "{term:?}");
        assert!(code.is_ascii(), "{term:?}");
        assert!(code.starts_with("T_"), "{term:?}");
        assert!(!code.contains("  "), "{term:?}");
        assert_ne!(code, debug.as_str(), "{term:?}");

        if term == WboTermCode::NumericalPostCorrection {
            assert_eq!(code, "T_num");
        } else {
            assert!(
                !code.chars().any(|ch| ch.is_ascii_lowercase()),
                "{term:?} code {code}"
            );
            assert!(
                code.chars()
                    .all(|ch| ch == '_' || ch.is_ascii_uppercase() || ch.is_ascii_digit()),
                "{term:?} code {code}"
            );
        }
    }
}

#[test]
fn wbo_term_catalog_names_obligations_for_every_axis() {
    for term in WboTermCode::ALL {
        assert!(!term.obligation().is_empty());
    }
    assert_eq!(
        WboTermCode::ALL
            .iter()
            .map(|term| (term.code(), term.obligation()))
            .collect::<Vec<_>>(),
        vec![
            ("T_W", "lattice/weight/runtime perturbation"),
            ("T_K", "KV/cache compression and restore drift"),
            ("T_R", "residual reconstruction gap"),
            ("T_Q", "quantization approximation"),
            ("T_S", "side-information and active-support boundary"),
            ("T_SE", "self-evolving or security enforcement"),
            ("T_num", "numerical guard before softmax half-contraction"),
        ]
    );
}

#[test]
fn wbo_term_catalog_names_falsifiers_for_every_axis() {
    for term in WboTermCode::ALL {
        assert!(!term.falsifier().is_empty());
    }
    assert_eq!(
        WboTermCode::ALL
            .iter()
            .map(|term| (term.code(), term.falsifier()))
            .collect::<Vec<_>>(),
        vec![
            (
                "T_W",
                "F-WBO-DriftLedger; layerwise reconstruction/logit drift witness",
            ),
            ("T_K", "F-KV-Direct-Gate; F-WBO-DriftLedger"),
            ("T_R", "F-WBO-DriftLedger; residual KL slice"),
            (
                "T_Q",
                "F-WBO-DriftLedger; layerwise reconstruction/logit drift witness",
            ),
            (
                "T_S",
                "F-ACS-AnchorLookup; provider/provenance replay; F-WBO-DriftLedger",
            ),
            (
                "T_SE",
                "adapter replay/provenance verifier; provider/provenance replay; F-WBO-DriftLedger",
            ),
            ("T_num", "F-ULP-Oracle; F-WBO-DriftLedger"),
        ]
    );
}

#[test]
fn wbo_term_catalog_requires_drift_ledger_for_every_axis() {
    for term in WboTermCode::ALL {
        assert!(
            contains_falsifier_hook(term.falsifier(), "F-WBO-DriftLedger"),
            "{} must carry F-WBO-DriftLedger in its term falsifier",
            term.code()
        );
    }
}

#[test]
fn term_falsifier_catalogs_name_owned_f_hooks_for_every_axis() {
    let owners = falsifier_hook_owners();

    for term in WboTermCode::ALL {
        let hooks = f_hooks_in(term.falsifier());
        assert!(
            !hooks.is_empty(),
            "{} must name at least one F-* hook",
            term.code()
        );
        for hook in hooks {
            assert!(
                owners.iter().any(|owner| owner.hook == hook),
                "{} names unowned falsifier hook {hook}",
                term.code()
            );
        }
    }
}

#[test]
fn term_falsifier_catalogs_cover_every_owned_f_hook() {
    let mut term_hooks = Vec::new();
    for term in WboTermCode::ALL {
        term_hooks.extend(f_hooks_in(term.falsifier()));
    }
    term_hooks.sort_unstable();
    term_hooks.dedup();

    for owner in falsifier_hook_owners() {
        assert!(
            term_hooks.contains(&owner.hook),
            "{} owner hook must be emitted by at least one WBO term falsifier",
            owner.hook
        );
    }
}

#[test]
fn wbo_term_catalog_keeps_t_num_outside_semantic_wbo6() {
    assert_eq!(
        WboTermCode::SEMANTIC_WBO6
            .iter()
            .map(|term| term.code())
            .collect::<Vec<_>>(),
        vec!["T_W", "T_K", "T_R", "T_Q", "T_S", "T_SE"]
    );

    assert!(!WboTermCode::NumericalPostCorrection.is_semantic_wbo6());
    for term in WboTermCode::SEMANTIC_WBO6 {
        assert!(term.is_semantic_wbo6());
    }
}

#[test]
fn lattice_budget_reports_semantic_and_numerical_budget_slices() {
    let residual =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "residual", 0.20)
            .expect("valid residual contribution");
    let quantization =
        LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.10)
            .expect("valid quantization contribution");
    let numerics =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.04)
            .expect("valid numerical contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ResidualSketch,
        None,
        SideInformationKind::ResidualStream,
        vec![residual, quantization, numerics],
    );

    assert_eq!(
        budget.semantic_wbo6_pre_softmax_budget(),
        0.30000000000000004
    );
    assert_eq!(budget.numerical_post_correction_budget(), 0.04);
    assert_eq!(budget.pre_softmax_budget(), 0.34);
    assert_eq!(budget.softmax_half_corrected_budget(), 0.17);
}

#[test]
fn lattice_budget_semantic_and_numerical_slices_conserve_total_budget() {
    let contributions = WboTermCode::ALL
        .iter()
        .enumerate()
        .map(|(index, term)| {
            LatticeErrorContribution::new(
                *term,
                format!("term {}", term.code()),
                index as f64 + 1.0,
            )
            .expect("valid contribution")
        })
        .collect::<Vec<_>>();
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::DecoderLmState,
        contributions,
    );

    assert_eq!(budget.semantic_wbo6_pre_softmax_budget(), 21.0);
    assert_eq!(budget.numerical_post_correction_budget(), 7.0);
    assert_eq!(
        budget.semantic_wbo6_pre_softmax_budget() + budget.numerical_post_correction_budget(),
        budget.pre_softmax_budget()
    );
}

#[test]
fn lattice_budget_slice_partition_is_order_invariant_across_all_axes() {
    let forward = WboTermCode::ALL
        .iter()
        .copied()
        .enumerate()
        .map(|(index, term)| {
            LatticeErrorContribution::new(
                term,
                format!("forward {}", term.code()),
                index as f64 + 1.0,
            )
            .expect("valid contribution")
        })
        .collect::<Vec<_>>();
    let mut reversed = forward.clone();
    reversed.reverse();
    let mut duplicated_numerics = reversed.clone();
    duplicated_numerics.push(
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "second numerical guard",
            0.5,
        )
        .expect("valid duplicate numerical contribution"),
    );
    let mut duplicated_semantic = reversed.clone();
    duplicated_semantic.push(
        LatticeErrorContribution::new(
            WboTermCode::WeightRuntime,
            "second runtime weight guard",
            0.25,
        )
        .expect("valid duplicate semantic contribution"),
    );
    let mut mixed_duplicates = duplicated_semantic.clone();
    mixed_duplicates.push(
        LatticeErrorContribution::new(
            WboTermCode::NumericalPostCorrection,
            "mixed duplicate numerical guard",
            0.75,
        )
        .expect("valid mixed duplicate numerical contribution"),
    );

    for contributions in [
        forward,
        reversed,
        duplicated_numerics,
        duplicated_semantic,
        mixed_duplicates,
    ] {
        let budget = LatticeBudget::new(
            LatticeCoderKind::ExactHot,
            None,
            SideInformationKind::None,
            contributions,
        );
        let semantic = budget.semantic_wbo6_pre_softmax_budget();
        let numerical = budget.numerical_post_correction_budget();

        assert_eq!(semantic + numerical, budget.pre_softmax_budget());
        assert_eq!(
            numerical,
            budget
                .contributions
                .iter()
                .filter(|contribution| {
                    contribution.term == WboTermCode::NumericalPostCorrection
                })
                .map(|contribution| contribution.budget)
                .sum::<f64>()
        );
    }
}

#[test]
fn lattice_budget_slice_partition_conserves_every_codec_catalog() {
    for coder in LatticeCoderKind::ALL {
        let contributions = coder
            .canonical_wbo_terms()
            .iter()
            .copied()
            .enumerate()
            .map(|(index, term)| {
                LatticeErrorContribution::new(
                    term,
                    format!("{coder:?} {}", term.code()),
                    (index + 1) as f64 / 16.0,
                )
                .expect("valid contribution")
            })
            .collect::<Vec<_>>();
        let budget = LatticeBudget::new(
            coder,
            coder.allows_rate_parameter().then_some(1250),
            coder.canonical_side_information()[0],
            contributions,
        );

        assert_eq!(budget.validate(), Ok(()), "{coder:?}");
        assert_eq!(
            budget.semantic_wbo6_pre_softmax_budget()
                + budget.numerical_post_correction_budget(),
            budget.pre_softmax_budget(),
            "{coder:?} failed reserved slice conservation"
        );
    }
}

#[test]
fn budget_validation_accepts_canonical_side_information_by_codec() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL {
        for side_information in coder.canonical_side_information() {
            let budget = side_information_probe_budget(coder, *side_information);
            assert_eq!(
                budget.validate(),
                Ok(()),
                "{coder:?} rejected canonical side information {side_information:?}"
            );
            checked += 1;
        }
    }

    let expected = LatticeCoderKind::ALL
        .iter()
        .map(|coder| coder.canonical_side_information().len())
        .sum::<usize>();
    assert_eq!(checked, expected);
}

#[test]
fn budget_validation_rejects_side_information_outside_codec_map() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "numerics", 0.0)
            .expect("valid contribution");
    let cases = [
        (
            LatticeCoderKind::QuipE8,
            SideInformationKind::NetworkTeacher,
        ),
        (
            LatticeCoderKind::ResidualSketch,
            SideInformationKind::SurpriseGradient,
        ),
        (
            LatticeCoderKind::ShadowKvSketch,
            SideInformationKind::CalibrationHessian,
        ),
        (
            LatticeCoderKind::LatticeWynerZivResidual,
            SideInformationKind::NetworkTeacher,
        ),
        (
            LatticeCoderKind::SherryTernary3Of4,
            SideInformationKind::ResidualStream,
        ),
    ];

    for (coder, side_information) in cases {
        let budget =
            LatticeBudget::new(coder, None, side_information, vec![contribution.clone()]);
        assert_eq!(
            budget.validate_side_information(),
            Err(LatticeWboError::InvalidSideInformation)
        );
    }
}

#[test]
fn budget_validation_rejects_every_noncanonical_side_information_for_every_codec() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL {
        let allowed = coder.canonical_side_information();
        for side_information in SideInformationKind::ALL {
            if allowed.contains(&side_information) {
                continue;
            }

            let budget = side_information_probe_budget(coder, side_information);
            assert_eq!(
                budget.validate_side_information(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} direct side-information validator accepted {side_information:?}"
            );
            assert_eq!(
                budget.validate(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} accepted noncanonical side information {side_information:?}"
            );
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} composition accepted noncanonical side information {side_information:?}"
            );
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
fn budget_validation_rejects_wrong_side_information_before_term_mismatch() {
    let mut checked = 0;

    for coder in LatticeCoderKind::ALL {
        let side_information = SideInformationKind::ALL
            .into_iter()
            .find(|side_information| {
                !coder
                    .canonical_side_information()
                    .contains(side_information)
            })
            .expect("each codec must have at least one noncanonical side-information witness");
        let foreign_term = WboTermCode::ALL
            .into_iter()
            .find(|term| !coder.canonical_wbo_terms().contains(term))
            .expect("each codec must have at least one foreign WBO term");
        let contribution = LatticeErrorContribution::new(
            foreign_term,
            format!("{coder:?} foreign {}", foreign_term.code()),
            0.0,
        )
        .expect("valid foreign contribution shape");
        let budget = LatticeBudget::new(
            coder,
            coder.allows_rate_parameter().then_some(1250),
            side_information,
            vec![contribution],
        );

        assert_eq!(
            budget.validate_terms(),
            Err(LatticeWboError::InvalidWboTermForCodec),
            "{coder:?} fixture must carry a real term mismatch"
        );
        assert_eq!(
            budget.validate_side_information(),
            Err(LatticeWboError::InvalidSideInformation),
            "{coder:?} fixture must carry a real side-information mismatch"
        );
        assert_eq!(
            budget.validate(),
            Err(LatticeWboError::InvalidSideInformation),
            "{coder:?} full validation must reject side-information before term mismatch"
        );
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidSideInformation),
            "{coder:?} composition validation must reject side-information before term mismatch"
        );
        checked += 1;
    }

    assert_eq!(checked, LatticeCoderKind::ALL.len());
}

#[test]
fn budget_validation_rejects_every_wrong_side_information_before_term_mismatch() {
    let mut checked = 0;

    for coder in LatticeCoderKind::ALL {
        let foreign_term = WboTermCode::ALL
            .into_iter()
            .find(|term| !coder.canonical_wbo_terms().contains(term))
            .expect("each codec must have at least one foreign WBO term");
        let contribution = LatticeErrorContribution::new(
            foreign_term,
            format!("{coder:?} foreign {}", foreign_term.code()),
            0.0,
        )
        .expect("valid foreign contribution shape");

        for side_information in SideInformationKind::ALL {
            if coder
                .canonical_side_information()
                .contains(&side_information)
            {
                continue;
            }

            let budget = LatticeBudget::new(
                coder,
                coder.allows_rate_parameter().then_some(1250),
                side_information,
                vec![contribution.clone()],
            );

            assert_eq!(
                budget.validate_terms(),
                Err(LatticeWboError::InvalidWboTermForCodec),
                "{coder:?} fixture must carry a real term mismatch"
            );
            assert_eq!(
                budget.validate_side_information(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} fixture must carry side-information mismatch {side_information:?}"
            );
            assert_eq!(
                budget.validate(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} full validation let term mismatch hide {side_information:?}"
            );
            assert_eq!(
                budget.validate_composition(),
                Err(LatticeWboError::InvalidSideInformation),
                "{coder:?} composition let term mismatch hide {side_information:?}"
            );
            checked += 1;
        }
    }

    let expected = LatticeCoderKind::ALL
        .iter()
        .map(|coder| SideInformationKind::ALL.len() - coder.canonical_side_information().len())
        .sum::<usize>();
    assert_eq!(checked, expected);
}
