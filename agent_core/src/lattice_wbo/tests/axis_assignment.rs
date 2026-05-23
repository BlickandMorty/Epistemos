//! Per-axis WBO-term ownership invariants across codec catalogs.

use super::*;

#[test]
fn typed_catalogs_assign_every_wbo_term_to_codec_and_residency_rows() {
    for term in WboTermCode::ALL {
        assert!(
            LatticeCoderKind::ALL
                .iter()
                .any(|coder| coder.canonical_wbo_terms().contains(&term)),
            "missing codec owner for {}",
            term.code()
        );
        assert!(
            ResidencyTier::ALL
                .iter()
                .any(|tier| tier.canonical_register_terms().contains(&term)),
            "missing residency owner for {}",
            term.code()
        );
    }
}

#[test]
fn wbo_term_falsifiers_name_wbo_drift_ledger_for_every_axis() {
    for term in WboTermCode::ALL {
        let hooks = f_hooks_in(term.falsifier());
        assert!(
            hooks.iter().any(|hook| *hook == "F-WBO-DriftLedger"),
            "{:?} falsifier must name F-WBO-DriftLedger: {}",
            term,
            term.falsifier()
        );
    }
    let hooks = f_hooks_in(WboTermCode::NumericalPostCorrection.falsifier());
    assert!(
        hooks.iter().any(|hook| *hook == "F-ULP-Oracle"),
        "T_num falsifier must keep F-ULP-Oracle as the numerical oracle witness"
    );

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`wbo_term_falsifiers_name_wbo_drift_ledger_for_every_axis`"),
        "register doc must cross-link WBO term drift-ledger falsifier coverage"
    );
}

#[test]
fn lattice_coder_falsifiers_name_ulp_oracle_and_wbo_drift_ledger_for_every_codec() {
    for coder in LatticeCoderKind::ALL {
        let hooks = f_hooks_in(coder.falsifier());
        assert!(
            hooks.iter().any(|hook| *hook == "F-ULP-Oracle"),
            "{coder:?} falsifier must name F-ULP-Oracle: {}",
            coder.falsifier()
        );
        assert!(
            hooks.iter().any(|hook| *hook == "F-WBO-DriftLedger"),
            "{coder:?} falsifier must name F-WBO-DriftLedger: {}",
            coder.falsifier()
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains(
            "`lattice_coder_falsifiers_name_ulp_oracle_and_wbo_drift_ledger_for_every_codec`"
        ),
        "register doc must cross-link codec ULP+drift-ledger falsifier coverage"
    );
}

#[test]
fn numerical_post_correction_axis_is_owned_by_every_codec() {
    for coder in LatticeCoderKind::ALL {
        assert!(
            coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::NumericalPostCorrection),
            "{coder:?} must always claim T_num"
        );
    }
    for tier in ResidencyTier::ALL {
        assert!(
            tier.canonical_register_terms()
                .contains(&WboTermCode::NumericalPostCorrection),
            "{} must always claim T_num",
            tier.canonical_name()
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`numerical_post_correction_axis_is_owned_by_every_codec`"),
        "register doc must cross-link T_num universal ownership"
    );
}

#[test]
fn substrate_boundary_axis_is_owned_only_by_boundary_codecs() {
    let owners = [
        LatticeCoderKind::LatticeWynerZivResidual,
        LatticeCoderKind::ShadowKvSketch,
        LatticeCoderKind::EngramHashRecall,
        LatticeCoderKind::Nf4SsdOracle,
        LatticeCoderKind::ResidualSketch,
        LatticeCoderKind::NetworkCascade,
    ];
    for coder in owners {
        assert!(
            coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::SubstrateBoundary),
            "{coder:?} must claim T_S"
        );
    }
    for coder in LatticeCoderKind::ALL {
        if owners.contains(&coder) {
            continue;
        }
        assert!(
            !coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::SubstrateBoundary),
            "{coder:?} must never claim T_S; only side-information and substrate-bound codecs own boundary accounting"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`substrate_boundary_axis_is_owned_only_by_boundary_codecs`"),
        "register doc must cross-link T_S ownership invariant"
    );
}

#[test]
fn quantization_axis_is_owned_only_by_quantization_codecs() {
    let owners = [
        LatticeCoderKind::LatticeWynerZivResidual,
        LatticeCoderKind::SherryTernary3Of4,
        LatticeCoderKind::NestedE8,
        LatticeCoderKind::NestedLeech24,
        LatticeCoderKind::QuipE8,
        LatticeCoderKind::Nf4SsdOracle,
        LatticeCoderKind::ResidualSketch,
    ];
    for coder in owners {
        assert!(
            coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::Quantization),
            "{coder:?} must claim T_Q"
        );
    }
    for coder in LatticeCoderKind::ALL {
        if owners.contains(&coder) {
            continue;
        }
        assert!(
            !coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::Quantization),
            "{coder:?} must never claim T_Q; quantization belongs to codecs that fold an approximation lattice"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`quantization_axis_is_owned_only_by_quantization_codecs`"),
        "register doc must cross-link T_Q ownership invariant"
    );
}

#[test]
fn kv_cache_axis_is_owned_only_by_kv_and_residual_codecs() {
    let owners = [
        LatticeCoderKind::LatticeWynerZivResidual,
        LatticeCoderKind::ShadowKvSketch,
        LatticeCoderKind::Nf4SsdOracle,
    ];
    for coder in owners {
        assert!(
            coder.canonical_wbo_terms().contains(&WboTermCode::KvCache),
            "{coder:?} must claim T_K"
        );
    }
    for coder in LatticeCoderKind::ALL {
        if owners.contains(&coder) {
            continue;
        }
        assert!(
            !coder.canonical_wbo_terms().contains(&WboTermCode::KvCache),
            "{coder:?} must never claim T_K; only LWZ residual, ShadowKV, and NF4 SSD oracle own cache/offload"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`kv_cache_axis_is_owned_only_by_kv_and_residual_codecs`"),
        "register doc must cross-link T_K ownership invariant"
    );
}

#[test]
fn self_evolving_security_axis_is_owned_only_by_network_and_adapter_codecs() {
    let owners = [
        LatticeCoderKind::NetworkCascade,
        LatticeCoderKind::SelfEvolvingAdapter,
    ];
    for coder in owners {
        assert!(
            coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::SelfEvolvingSecurity),
            "{coder:?} must claim T_SE"
        );
    }
    for coder in LatticeCoderKind::ALL {
        if owners.contains(&coder) {
            continue;
        }
        assert!(
            !coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::SelfEvolvingSecurity),
            "{coder:?} must never claim T_SE; only L5 cascade and L_SE adapter own self-evolving security"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains(
            "`self_evolving_security_axis_is_owned_only_by_network_and_adapter_codecs`"
        ),
        "register doc must cross-link T_SE network and adapter ownership invariant"
    );
}

#[test]
fn residual_wyner_ziv_axis_is_owned_only_by_residual_codecs() {
    let residual_codecs = [
        LatticeCoderKind::LatticeWynerZivResidual,
        LatticeCoderKind::ResidualSketch,
    ];
    for coder in residual_codecs {
        assert!(
            coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::ResidualWynerZiv),
            "{coder:?} residual codec must claim T_R"
        );
    }
    for coder in LatticeCoderKind::ALL {
        if residual_codecs.contains(&coder) {
            continue;
        }
        assert!(
            !coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::ResidualWynerZiv),
            "{coder:?} must never claim T_R; only residual codecs own residual transfer"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`residual_wyner_ziv_axis_is_owned_only_by_residual_codecs`"),
        "register doc must cross-link T_R residual ownership invariant"
    );
}

#[test]
fn weight_codec_catalogs_claim_t_w_axis() {
    let weight_codecs = [
        LatticeCoderKind::BabaiGptqNearestPlane,
        LatticeCoderKind::SherryTernary3Of4,
        LatticeCoderKind::NestedE8,
        LatticeCoderKind::NestedLeech24,
        LatticeCoderKind::QuipE8,
    ];

    for coder in weight_codecs {
        assert!(
            coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::WeightRuntime),
            "{coder:?} weight codec must claim T_W"
        );
        assert!(
            !coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::ResidualWynerZiv),
            "{coder:?} weight codec must never claim T_R; residual transfer lives on Wyner-Ziv rows"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`weight_codec_catalogs_claim_t_w_axis`"),
        "register doc must cross-link weight codec T_W ownership"
    );
}

#[test]
fn weight_codec_catalogs_do_not_claim_kv_cache_terms() {
    let weight_codecs = [
        LatticeCoderKind::BabaiGptqNearestPlane,
        LatticeCoderKind::SherryTernary3Of4,
        LatticeCoderKind::NestedE8,
        LatticeCoderKind::NestedLeech24,
        LatticeCoderKind::QuipE8,
    ];

    for coder in weight_codecs {
        assert!(
            !coder.canonical_wbo_terms().contains(&WboTermCode::KvCache),
            "{coder:?} must not collapse T_K into a weight-codec lane"
        );
    }
    assert!(LatticeCoderKind::ShadowKvSketch
        .canonical_wbo_terms()
        .contains(&WboTermCode::KvCache));
    assert!(LatticeCoderKind::Nf4SsdOracle
        .canonical_wbo_terms()
        .contains(&WboTermCode::KvCache));
}

#[test]
fn cache_offload_codecs_pin_kv_boundary_quantization_and_numerical_terms() {
    assert_eq!(
        LatticeCoderKind::ShadowKvSketch.canonical_wbo_terms(),
        &[
            WboTermCode::KvCache,
            WboTermCode::SubstrateBoundary,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::Nf4SsdOracle.canonical_wbo_terms(),
        &[
            WboTermCode::KvCache,
            WboTermCode::Quantization,
            WboTermCode::SubstrateBoundary,
            WboTermCode::NumericalPostCorrection,
        ]
    );
}

#[test]
fn exact_hot_codec_pins_reference_term_and_side_information() {
    assert_eq!(
        LatticeCoderKind::ExactHot.canonical_wbo_terms(),
        &[WboTermCode::NumericalPostCorrection]
    );
    assert_eq!(
        LatticeCoderKind::ExactHot.canonical_side_information(),
        &[SideInformationKind::None]
    );
    assert!(!LatticeCoderKind::ExactHot.allows_rate_parameter());
    assert_eq!(
        LatticeCoderKind::ExactHot.falsifier(),
        "F-WBO-DriftLedger; F-ULP-Oracle"
    );
}

#[test]
fn nested_lattice_codecs_pin_weight_quantization_terms_and_rate() {
    for coder in [LatticeCoderKind::NestedE8, LatticeCoderKind::NestedLeech24] {
        assert!(
            coder.allows_rate_parameter(),
            "{coder:?} must keep explicit rate ownership"
        );
        assert_eq!(
            coder.canonical_wbo_terms(),
            &[
                WboTermCode::WeightRuntime,
                WboTermCode::Quantization,
                WboTermCode::NumericalPostCorrection,
            ],
            "{coder:?} must stay a weight plus quantization lane"
        );
        assert_eq!(
            coder.canonical_side_information(),
            &[SideInformationKind::CalibrationHessian],
            "{coder:?} must use calibration-side weight evidence only"
        );
    }
}

#[test]
fn nested_lattice_codecs_are_not_quip_subfamilies() {
    let quip_key = LatticeCoderKind::QuipE8.canonical_name();
    for coder in [LatticeCoderKind::NestedE8, LatticeCoderKind::NestedLeech24] {
        let nested_key = coder.canonical_name();
        assert_ne!(nested_key, quip_key, "{coder:?} must keep a distinct key");
        assert!(
            !nested_key.contains("quip"),
            "{coder:?} must not encode QuIP ancestry in its public key"
        );
        assert_eq!(
            coder.primary_residency_tier(),
            None,
            "{coder:?} must remain standalone without product residency promotion"
        );
    }
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`nested_lattice_codecs_are_not_quip_subfamilies`"),
        "register doc must cross-link the nested-vs-QuIP identity guard"
    );
}

#[test]
fn quip_e8_codec_pins_weight_quantization_terms_and_rate() {
    assert!(LatticeCoderKind::QuipE8.allows_rate_parameter());
    assert_eq!(
        LatticeCoderKind::QuipE8.canonical_wbo_terms(),
        &[
            WboTermCode::WeightRuntime,
            WboTermCode::Quantization,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::QuipE8.canonical_side_information(),
        &[SideInformationKind::CalibrationHessian]
    );
}

#[test]
fn sherry_ternary_codec_pins_weight_terms_rate_and_calibration_side_information() {
    assert!(LatticeCoderKind::SherryTernary3Of4.allows_rate_parameter());
    assert_eq!(
        LatticeCoderKind::SherryTernary3Of4.canonical_wbo_terms(),
        &[
            WboTermCode::WeightRuntime,
            WboTermCode::Quantization,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::SherryTernary3Of4.canonical_side_information(),
        &[SideInformationKind::CalibrationHessian]
    );
    assert!(!LatticeCoderKind::SherryTernary3Of4
        .canonical_wbo_terms()
        .contains(&WboTermCode::ResidualWynerZiv));
    assert!(!LatticeCoderKind::SherryTernary3Of4
        .canonical_side_information()
        .contains(&SideInformationKind::ResidualStream));
}

#[test]
fn lattice_wyner_ziv_residual_codec_pins_terms_rate_and_decoder_witnesses() {
    assert!(LatticeCoderKind::LatticeWynerZivResidual.allows_rate_parameter());
    assert_eq!(
        LatticeCoderKind::LatticeWynerZivResidual.canonical_wbo_terms(),
        &[
            WboTermCode::KvCache,
            WboTermCode::ResidualWynerZiv,
            WboTermCode::Quantization,
            WboTermCode::SubstrateBoundary,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::LatticeWynerZivResidual.canonical_side_information(),
        &[
            SideInformationKind::DecoderLmState,
            SideInformationKind::ResidualStream,
            SideInformationKind::ActiveSupport,
            SideInformationKind::SsdOracle,
        ]
    );
}

#[test]
fn residual_sketch_codec_pins_correction_terms_and_side_information() {
    assert!(LatticeCoderKind::ResidualSketch.allows_rate_parameter());
    assert_eq!(
        LatticeCoderKind::ResidualSketch.canonical_wbo_terms(),
        &[
            WboTermCode::ResidualWynerZiv,
            WboTermCode::Quantization,
            WboTermCode::SubstrateBoundary,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::ResidualSketch.canonical_side_information(),
        &[
            SideInformationKind::ResidualStream,
            SideInformationKind::DecoderLmState,
            SideInformationKind::ActiveSupport,
        ]
    );
}

#[test]
fn engram_hash_recall_codec_pins_static_fact_boundary() {
    assert!(!LatticeCoderKind::EngramHashRecall.allows_rate_parameter());
    assert_eq!(
        LatticeCoderKind::EngramHashRecall.canonical_wbo_terms(),
        &[
            WboTermCode::SubstrateBoundary,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::EngramHashRecall.canonical_side_information(),
        &[SideInformationKind::StaticFactKey]
    );
    assert!(!LatticeCoderKind::EngramHashRecall
        .canonical_wbo_terms()
        .contains(&WboTermCode::KvCache));
    assert!(!LatticeCoderKind::EngramHashRecall
        .canonical_wbo_terms()
        .contains(&WboTermCode::ResidualWynerZiv));
}

#[test]
fn engram_hash_recall_rejects_dynamic_side_information_edges() {
    let substrate = LatticeErrorContribution::new(
        WboTermCode::SubstrateBoundary,
        "Engram static-fact lookup",
        0.01,
    )
    .expect("valid substrate contribution")
    .with_measured(0.005)
    .expect("valid substrate measurement");
    let numerics = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "softmax half correction",
        0.0,
    )
    .expect("valid numerical contribution")
    .with_measured(0.0)
    .expect("valid numerical measurement");

    for side_information in SideInformationKind::ALL {
        if side_information == SideInformationKind::StaticFactKey {
            continue;
        }
        let budget = LatticeBudget::new(
            LatticeCoderKind::EngramHashRecall,
            None,
            side_information,
            vec![substrate.clone(), numerics.clone()],
        );

        assert_eq!(
            budget.validate_side_information(),
            Err(LatticeWboError::InvalidSideInformation),
            "Engram accepted dynamic side information {side_information:?}"
        );
        assert_eq!(
            budget.validate(),
            Err(LatticeWboError::InvalidSideInformation),
            "Engram full validation accepted dynamic side information {side_information:?}"
        );
        assert_eq!(
            budget.validate_composition(),
            Err(LatticeWboError::InvalidSideInformation),
            "Engram composition validation accepted dynamic side information {side_information:?}"
        );
        assert_budget_measurements_pending(&budget);
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`engram_hash_recall_rejects_dynamic_side_information_edges`"),
        "register doc must cross-link Engram dynamic side-information rejection"
    );
}

#[test]
fn engram_hash_recall_json_accepts_only_static_fact_key() {
    fn engram_budget_with_side_information(side_information: &str) -> serde_json::Value {
        serde_json::json!({
            "coder": "engram-hash-recall",
            "rate_milli_bits_per_symbol": null,
            "side_information": side_information,
            "contributions": [
                {
                    "term": "T_S",
                    "source": "Engram static-fact lookup",
                    "budget": 0.01,
                    "measured": null,
                },
                {
                    "term": "T_num",
                    "source": "softmax half correction",
                    "budget": 0.0,
                    "measured": null,
                },
            ],
        })
    }

    let valid = serde_json::from_value::<LatticeBudget>(engram_budget_with_side_information(
        SideInformationKind::StaticFactKey.key(),
    ))
    .expect("StaticFactKey JSON must remain the only Engram witness");
    assert!(valid.validate().is_ok());

    for side_information in SideInformationKind::ALL {
        if side_information == SideInformationKind::StaticFactKey {
            continue;
        }
        assert!(
            serde_json::from_value::<LatticeBudget>(engram_budget_with_side_information(
                side_information.key()
            ))
            .is_err(),
            "Engram JSON accepted non-static side information {side_information:?}"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`engram_hash_recall_json_accepts_only_static_fact_key`"),
        "register doc must cross-link Engram JSON StaticFactKey boundary"
    );
}

#[test]
fn engram_hash_recall_rejects_active_support_budget_borrowing() {
    let budget = LatticeBudget::new(
        LatticeCoderKind::EngramHashRecall,
        None,
        SideInformationKind::StaticFactKey,
        vec![
            LatticeErrorContribution::new(
                WboTermCode::SubstrateBoundary,
                "Engram static-fact lookup",
                0.01,
            )
            .expect("valid substrate contribution"),
            LatticeErrorContribution::new(
                WboTermCode::NumericalPostCorrection,
                "softmax half correction",
                0.0,
            )
            .expect("valid numerical contribution"),
        ],
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L4Engram,
        budget,
        Some(ActiveSupportBudget::new(
            128,
            4,
            1024,
            SideInformationKind::ActiveSupport,
        )),
        "F-ACS-AnchorLookup; F-ULP-Oracle; F-WBO-DriftLedger",
        "Engram static facts cannot borrow active-support budgets.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::InvalidActiveSupportSideInformation)
    );

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`engram_hash_recall_rejects_active_support_budget_borrowing`"),
        "register doc must cross-link Engram active-support borrowing rejection"
    );
}

#[test]
fn network_cascade_codec_pins_teacher_boundary_terms_and_side_information() {
    assert!(!LatticeCoderKind::NetworkCascade.allows_rate_parameter());
    assert_eq!(
        LatticeCoderKind::NetworkCascade.canonical_wbo_terms(),
        &[
            WboTermCode::SubstrateBoundary,
            WboTermCode::SelfEvolvingSecurity,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::NetworkCascade.canonical_side_information(),
        &[SideInformationKind::NetworkTeacher]
    );
    assert!(LatticeCoderKind::NetworkCascade
        .falsifier()
        .contains("provider/provenance replay"));
    assert!(!LatticeCoderKind::NetworkCascade
        .canonical_wbo_terms()
        .contains(&WboTermCode::KvCache));
}

#[test]
fn self_evolving_adapter_codec_pins_mutation_terms_and_side_information() {
    assert!(!LatticeCoderKind::SelfEvolvingAdapter.allows_rate_parameter());
    assert_eq!(
        LatticeCoderKind::SelfEvolvingAdapter.canonical_wbo_terms(),
        &[
            WboTermCode::WeightRuntime,
            WboTermCode::SelfEvolvingSecurity,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::SelfEvolvingAdapter.canonical_side_information(),
        &[SideInformationKind::SurpriseGradient]
    );
    assert!(LatticeCoderKind::SelfEvolvingAdapter
        .falsifier()
        .contains("adapter replay/provenance verifier"));
    assert!(!LatticeCoderKind::SelfEvolvingAdapter
        .canonical_wbo_terms()
        .contains(&WboTermCode::KvCache));
    assert!(!LatticeCoderKind::SelfEvolvingAdapter
        .canonical_wbo_terms()
        .contains(&WboTermCode::ResidualWynerZiv));
}

#[test]
fn codec_side_information_catalog_keeps_hessian_domains_disjoint() {
    for coder in LatticeCoderKind::ALL {
        let side_information = coder.canonical_side_information();
        assert!(
            !(side_information.contains(&SideInformationKind::CalibrationHessian)
                && side_information.contains(&SideInformationKind::RuntimeKvHessian)),
            "{coder:?} must not mix calibration Hessian and runtime KV Hessian"
        );
    }

    assert!(LatticeCoderKind::QuipE8
        .canonical_side_information()
        .contains(&SideInformationKind::CalibrationHessian));
    assert!(LatticeCoderKind::ShadowKvSketch
        .canonical_side_information()
        .contains(&SideInformationKind::RuntimeKvHessian));
}

#[test]
fn lattice_coder_catalog_maps_every_codec_to_side_information() {
    for coder in LatticeCoderKind::ALL {
        assert!(!coder.canonical_side_information().is_empty());
        for (index, side_information) in coder.canonical_side_information().iter().enumerate() {
            assert!(
                !coder.canonical_side_information()[index + 1..].contains(side_information),
                "{coder:?} must not duplicate {side_information:?} in canonical side information"
            );
        }
    }
    assert_eq!(
        LatticeCoderKind::ExactHot.canonical_side_information(),
        &[SideInformationKind::None]
    );
    assert_eq!(
        LatticeCoderKind::QuipE8.canonical_side_information(),
        &[SideInformationKind::CalibrationHessian]
    );
    assert_eq!(
        LatticeCoderKind::ShadowKvSketch.canonical_side_information(),
        &[
            SideInformationKind::RuntimeKvHessian,
            SideInformationKind::ActiveSupport,
            SideInformationKind::ResidualStream,
        ]
    );
    assert_eq!(
        LatticeCoderKind::LatticeWynerZivResidual.canonical_side_information(),
        &[
            SideInformationKind::DecoderLmState,
            SideInformationKind::ResidualStream,
            SideInformationKind::ActiveSupport,
            SideInformationKind::SsdOracle,
        ]
    );
    assert_eq!(
        LatticeCoderKind::SherryTernary3Of4.canonical_side_information(),
        &[SideInformationKind::CalibrationHessian]
    );
}

#[test]
fn typed_catalogs_assign_every_side_information_to_codec_rows() {
    for side_information in SideInformationKind::ALL {
        assert!(
            LatticeCoderKind::ALL.iter().any(|coder| coder
                .canonical_side_information()
                .contains(&side_information)),
            "missing codec owner for {:?}",
            side_information
        );
    }

    for tier in ResidencyTier::ALL {
        let primary = tier.primary_side_information();
        assert!(SideInformationKind::ALL.contains(&primary));
        assert!(
            LatticeCoderKind::ALL
                .iter()
                .any(|coder| coder.canonical_side_information().contains(&primary)),
            "missing codec owner for primary side information on {}",
            tier.canonical_name()
        );
    }
}

#[test]
fn lattice_coder_catalog_marks_rate_bearing_codecs() {
    let rate_bearing = LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| coder.allows_rate_parameter())
        .collect::<Vec<_>>();

    assert_eq!(
        rate_bearing,
        vec![
            LatticeCoderKind::LatticeWynerZivResidual,
            LatticeCoderKind::SherryTernary3Of4,
            LatticeCoderKind::NestedE8,
            LatticeCoderKind::NestedLeech24,
            LatticeCoderKind::QuipE8,
            LatticeCoderKind::Nf4SsdOracle,
            LatticeCoderKind::ResidualSketch,
        ]
    );
    assert!(!LatticeCoderKind::ExactHot.allows_rate_parameter());
    assert!(!LatticeCoderKind::EngramHashRecall.allows_rate_parameter());
    assert!(!LatticeCoderKind::NetworkCascade.allows_rate_parameter());
    assert!(!LatticeCoderKind::SelfEvolvingAdapter.allows_rate_parameter());
}

#[test]
fn lattice_coder_catalog_marks_non_rate_codecs() {
    let non_rate = LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| !coder.allows_rate_parameter())
        .collect::<Vec<_>>();

    assert_eq!(
        non_rate,
        vec![
            LatticeCoderKind::ExactHot,
            LatticeCoderKind::BabaiGptqNearestPlane,
            LatticeCoderKind::ShadowKvSketch,
            LatticeCoderKind::EngramHashRecall,
            LatticeCoderKind::NetworkCascade,
            LatticeCoderKind::SelfEvolvingAdapter,
        ]
    );
}

#[test]
fn rate_parameter_ownership_matrix_counts_are_pinned() {
    let rate_bearing_codecs = LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| coder.allows_rate_parameter())
        .collect::<Vec<_>>();
    let non_rate_codecs = LatticeCoderKind::ALL
        .iter()
        .copied()
        .filter(|coder| !coder.allows_rate_parameter())
        .collect::<Vec<_>>();
    let primary_rate_rows = ResidencyTier::ALL
        .iter()
        .copied()
        .filter_map(|tier| {
            tier.primary_rate_milli_bits_per_symbol()
                .map(|rate| (tier, rate))
        })
        .collect::<Vec<_>>();
    let non_rate_rows = ResidencyTier::ALL
        .iter()
        .copied()
        .filter(|tier| tier.primary_rate_milli_bits_per_symbol().is_none())
        .collect::<Vec<_>>();

    assert_eq!(LatticeCoderKind::ALL.len(), 13);
    assert_eq!(
        rate_bearing_codecs,
        vec![
            LatticeCoderKind::LatticeWynerZivResidual,
            LatticeCoderKind::SherryTernary3Of4,
            LatticeCoderKind::NestedE8,
            LatticeCoderKind::NestedLeech24,
            LatticeCoderKind::QuipE8,
            LatticeCoderKind::Nf4SsdOracle,
            LatticeCoderKind::ResidualSketch,
        ]
    );
    assert_eq!(
        non_rate_codecs,
        vec![
            LatticeCoderKind::ExactHot,
            LatticeCoderKind::BabaiGptqNearestPlane,
            LatticeCoderKind::ShadowKvSketch,
            LatticeCoderKind::EngramHashRecall,
            LatticeCoderKind::NetworkCascade,
            LatticeCoderKind::SelfEvolvingAdapter,
        ]
    );
    assert_eq!(
        primary_rate_rows,
        vec![
            (ResidencyTier::L1CompressedResidual, 1250),
            (ResidencyTier::L3SsdOracle, 4000),
        ]
    );
    assert_eq!(non_rate_rows.len(), 5);
}
