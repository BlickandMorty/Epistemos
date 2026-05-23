//! JSON round-trip and wire-format tests for the public accounting types.

use super::*;

#[test]
fn falsifier_hook_matching_rejects_substring_collisions() {
    assert!(contains_falsifier_hook(
        "F-ULP-Oracle; F-WBO-DriftLedger",
        "F-ULP-Oracle"
    ));
    assert!(contains_falsifier_hook(
        "residual slice of F-KV-Direct-Gate",
        "F-KV-Direct-Gate"
    ));
    assert!(contains_falsifier_hook(
        "`F-ULP-Oracle`, F-WBO-DriftLedger",
        "F-ULP-Oracle"
    ));
    assert!(contains_falsifier_hook(
        "(F-KV-Direct-Gate)",
        "F-KV-Direct-Gate"
    ));
    assert!(!contains_falsifier_hook("not-F-ULP-Oracle", "F-ULP-Oracle"));
    assert!(!contains_falsifier_hook("F-ULP-Oracle-v2", "F-ULP-Oracle"));
    assert!(!contains_falsifier_hook(
        "not-F-WBO-DriftLedger",
        "F-WBO-DriftLedger"
    ));
    assert!(!contains_falsifier_hook(
        "F-WBO-DriftLedger/v2",
        "F-WBO-DriftLedger"
    ));
    assert!(!contains_falsifier_hook(
        "Provider/provenance replay",
        "provider/provenance replay"
    ));
    assert!(!contains_falsifier_hook("βF-ULP-Oracle", "F-ULP-Oracle"));
    assert!(!contains_falsifier_hook("F-ULP-Oracleβ", "F-ULP-Oracle"));
    assert!(!contains_falsifier_hook("_F-ULP-Oracle", "F-ULP-Oracle"));
    assert!(!contains_falsifier_hook("F-ULP-Oracle_", "F-ULP-Oracle"));
    assert_eq!(f_hooks_in("F-ULP-Oracle/v2"), vec!["F-ULP-Oracle/v2"]);
    assert_eq!(
        f_hooks_in("F-WBO-DriftLedger/v2"),
        vec!["F-WBO-DriftLedger/v2"]
    );
    assert_eq!(f_hooks_in("F-ULP-Oracleβ"), vec!["F-ULP-Oracleβ"]);
    assert!(f_hooks_in("_F-ULP-Oracle").is_empty());
    assert_eq!(f_hooks_in("F-ULP-Oracle_"), vec!["F-ULP-Oracle_"]);
    assert!(!falsifier_hooks_are_owned("F-ULP-Oracle/v2"));
    assert!(!falsifier_hooks_are_owned("F-WBO-DriftLedger/v2"));
    assert!(!falsifier_hooks_are_owned("F-ULP-Oracleβ"));
    assert!(!falsifier_hooks_are_owned("_F-ULP-Oracle"));
    assert!(!falsifier_hooks_are_owned("F-ULP-Oracle_"));
    assert!(!falsifier_hooks_are_owned("f-ulp-oracle"));
    assert!(!falsifier_hooks_are_owned("f-wbo-driftledger"));
    assert!(!falsifier_hooks_are_owned("residual KL slice"));
}

#[test]
fn falsifier_hook_extraction_accepts_markdown_punctuation_boundaries() {
    let candidate =
        "[`F-ULP-Oracle`], (F-KV-Direct-Gate); {F-ACS-AnchorLookup}. <F-WBO-DriftLedger>";
    assert_eq!(
        f_hooks_in(candidate),
        vec![
            "F-ULP-Oracle",
            "F-KV-Direct-Gate",
            "F-ACS-AnchorLookup",
            "F-WBO-DriftLedger"
        ]
    );
    assert!(falsifier_hooks_are_owned(candidate));
    for hook in [
        "F-ULP-Oracle",
        "F-KV-Direct-Gate",
        "F-ACS-AnchorLookup",
        "F-WBO-DriftLedger",
    ] {
        assert!(contains_falsifier_hook(candidate, hook));
    }

    assert!(f_hooks_in("xF-ULP-Oracle").is_empty());
    assert!(!contains_falsifier_hook("xF-ULP-Oracle", "F-ULP-Oracle"));
    assert!(!contains_falsifier_hook("F-ULP-Oraclex", "F-ULP-Oracle"));
}

#[test]
fn lattice_coder_kind_round_trips_json() {
    let encoded =
        serde_json::to_string(&LatticeCoderKind::ALL).expect("serialize lattice coder kinds");
    let decoded: [LatticeCoderKind; 13] =
        serde_json::from_str(&encoded).expect("deserialize lattice coder kind");

    assert_eq!(decoded, LatticeCoderKind::ALL);
    assert_eq!(
        LatticeCoderKind::LatticeWynerZivResidual.canonical_name(),
        "lattice-wyner-ziv-residual"
    );
}

#[test]
fn lattice_coder_json_uses_canonical_keys_and_rejects_debug_labels() {
    let encoded =
        serde_json::to_string(&LatticeCoderKind::ALL).expect("serialize lattice coder kinds");
    let expected_keys = LatticeCoderKind::ALL
        .iter()
        .map(|coder| coder.canonical_name())
        .collect::<Vec<_>>();
    let expected_json = serde_json::to_string(&expected_keys).expect("serialize codec keys");
    assert_eq!(encoded, expected_json);

    for coder in LatticeCoderKind::ALL {
        let public_json = format!(r#""{}""#, coder.canonical_name());
        assert_eq!(
            serde_json::from_str::<LatticeCoderKind>(&public_json).expect("public codec key"),
            coder
        );

        let debug_json = format!(r#""{coder:?}""#);
        assert!(
            serde_json::from_str::<LatticeCoderKind>(&debug_json).is_err(),
            "{debug_json} must not deserialize"
        );
    }

    for spoof in [
        r#""LATTICE-WYNER-ZIV-RESIDUAL""#,
        r#""lattice_wyner_ziv_residual""#,
        r#"" lattice-wyner-ziv-residual""#,
        r#""lattice-wyner-ziv-residual ""#,
        r#""nested-e8/quip""#,
    ] {
        assert!(
            serde_json::from_str::<LatticeCoderKind>(spoof).is_err(),
            "{spoof} must not deserialize"
        );
    }
}

#[test]
fn lattice_coder_canonical_names_are_trimmed_kebab_case_keys() {
    for coder in LatticeCoderKind::ALL {
        let name = coder.canonical_name();
        assert!(!name.is_empty(), "{coder:?}");
        assert_eq!(name.trim(), name, "{coder:?}");
        assert!(name.is_ascii(), "{coder:?}");
        assert_eq!(name, name.to_ascii_lowercase(), "{coder:?}");
        assert!(!name.starts_with('-'), "{coder:?}");
        assert!(!name.ends_with('-'), "{coder:?}");
        assert!(name
            .chars()
            .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '-'));
        assert_ne!(name, format!("{coder:?}"), "{coder:?}");
    }
}

#[test]
fn residency_tier_round_trips_json() {
    let encoded =
        serde_json::to_string(&ResidencyTier::ALL).expect("serialize residency tiers");
    let decoded: [ResidencyTier; 7] =
        serde_json::from_str(&encoded).expect("deserialize residency tier");

    assert_eq!(decoded, ResidencyTier::ALL);
    assert_eq!(
        ResidencyTier::LSeSelfEvolving.canonical_name(),
        "L_SE Self-Evolving"
    );
}

#[test]
fn residency_tier_json_uses_canonical_names_and_rejects_debug_labels() {
    let encoded =
        serde_json::to_string(&ResidencyTier::ALL).expect("serialize residency tiers");
    let expected_keys = ResidencyTier::ALL
        .iter()
        .map(|tier| tier.canonical_name())
        .collect::<Vec<_>>();
    let expected_json = serde_json::to_string(&expected_keys).expect("serialize tier keys");
    assert_eq!(encoded, expected_json);

    for tier in ResidencyTier::ALL {
        let public_json = format!(r#""{}""#, tier.canonical_name());
        assert_eq!(
            serde_json::from_str::<ResidencyTier>(&public_json).expect("public residency key"),
            tier
        );

        let debug_json = format!(r#""{tier:?}""#);
        assert!(
            serde_json::from_str::<ResidencyTier>(&debug_json).is_err(),
            "{debug_json} must not deserialize"
        );
    }

    for spoof in [
        r#""L0RamHot""#,
        r#"" L0 RAM hot""#,
        r#""L0 RAM hot ""#,
        r#""l0 RAM hot""#,
        r#""LSE Self-Evolving""#,
    ] {
        assert!(
            serde_json::from_str::<ResidencyTier>(spoof).is_err(),
            "{spoof} must not deserialize"
        );
    }
}

#[test]
fn lattice_wbo_error_round_trips_json() {
    let encoded =
        serde_json::to_string(&LatticeWboError::ALL).expect("serialize lattice wbo errors");
    let decoded: [LatticeWboError; 18] =
        serde_json::from_str(&encoded).expect("deserialize lattice wbo error");

    assert_eq!(decoded, LatticeWboError::ALL);
    assert_eq!(
        decoded
            .iter()
            .map(|error| format!("{error:?}"))
            .collect::<Vec<_>>(),
        vec![
            "InvalidBudget",
            "EmptySource",
            "EmptyMemoryTier",
            "EmptyContributions",
            "EmptyFalsifier",
            "EmptyCaveat",
            "MissingActiveSupportBudget",
            "MissingSubstrateBoundaryTerm",
            "MissingNumericalPostCorrectionTerm",
            "InvalidSideInformation",
            "InvalidActiveSupportSideInformation",
            "UnknownResidencyTier",
            "InvalidRate",
            "MissingCanonicalFalsifier",
            "InvalidWboTermForCodec",
            "InvalidBudgetComposition",
            "ResidencyCodecMismatch",
            "InvalidWboTermForResidencyTier",
        ]
    );
    assert!(decoded.contains(&LatticeWboError::InvalidActiveSupportSideInformation));
    assert!(decoded.contains(&LatticeWboError::MissingSubstrateBoundaryTerm));
    assert!(decoded.contains(&LatticeWboError::MissingNumericalPostCorrectionTerm));
}

#[test]
fn lattice_wbo_error_json_uses_explicit_public_keys() {
    let encoded =
        serde_json::to_string(&LatticeWboError::ALL).expect("serialize lattice wbo errors");
    let expected_keys = LatticeWboError::ALL
        .iter()
        .map(|error| error.key())
        .collect::<Vec<_>>();
    let expected_json = serde_json::to_string(&expected_keys).expect("serialize error keys");
    assert_eq!(encoded, expected_json);

    for error in LatticeWboError::ALL {
        let public_json = format!(r#""{}""#, error.key());
        assert_eq!(
            serde_json::from_str::<LatticeWboError>(&public_json).expect("public error key"),
            error
        );
    }

    for spoof in [
        r#""invalidbudget""#,
        r#""Invalid Budget""#,
        r#""Invalid-Budget""#,
        r#"" InvalidBudget""#,
        r#""InvalidBudget ""#,
    ] {
        assert!(
            serde_json::from_str::<LatticeWboError>(spoof).is_err(),
            "{spoof} must not deserialize"
        );
    }
}

#[test]
fn side_information_kind_keeps_hessian_domains_separate() {
    let weight = SideInformationKind::CalibrationHessian;
    let kv = SideInformationKind::RuntimeKvHessian;

    let encoded =
        serde_json::to_string(&SideInformationKind::ALL).expect("serialize side information");
    let decoded: [SideInformationKind; 10] =
        serde_json::from_str(&encoded).expect("deserialize side information");

    assert_eq!(decoded, SideInformationKind::ALL);
    assert!(weight.uses_calibration_hessian());
    assert!(!weight.uses_runtime_kv_hessian());
    assert!(kv.uses_runtime_kv_hessian());
    assert!(!kv.uses_calibration_hessian());
}

#[test]
fn side_information_json_uses_explicit_public_keys() {
    let encoded =
        serde_json::to_string(&SideInformationKind::ALL).expect("serialize side information");
    let expected_keys = SideInformationKind::ALL
        .iter()
        .map(|kind| kind.key())
        .collect::<Vec<_>>();
    let expected_json =
        serde_json::to_string(&expected_keys).expect("serialize side-information keys");
    assert_eq!(encoded, expected_json);

    for kind in SideInformationKind::ALL {
        let public_json = format!(r#""{}""#, kind.key());
        assert_eq!(
            serde_json::from_str::<SideInformationKind>(&public_json)
                .expect("public side-information key"),
            kind
        );
    }

    for spoof in [
        r#""ActiveSupport ""#,
        r#"" active-support""#,
        r#""active-support""#,
        r#""RuntimeKVHessian""#,
        r#""Calibration Hessian""#,
    ] {
        assert!(
            serde_json::from_str::<SideInformationKind>(spoof).is_err(),
            "{spoof} must not deserialize"
        );
    }
}

#[test]
fn wbo_term_code_round_trips_json() {
    let encoded = serde_json::to_string(&WboTermCode::ALL).expect("serialize wbo terms");
    let decoded: [WboTermCode; 7] =
        serde_json::from_str(&encoded).expect("deserialize wbo terms");

    assert_eq!(decoded, WboTermCode::ALL);
    assert_eq!(decoded[6].code(), "T_num");
}

#[test]
fn wbo_term_code_json_uses_public_axis_keys_and_rejects_debug_labels() {
    let encoded = serde_json::to_string(&WboTermCode::ALL).expect("serialize wbo terms");
    assert_eq!(encoded, r#"["T_W","T_K","T_R","T_Q","T_S","T_SE","T_num"]"#);

    for term in WboTermCode::ALL {
        let public_json = format!(r#""{}""#, term.code());
        assert_eq!(
            serde_json::from_str::<WboTermCode>(&public_json).expect("public term code"),
            term
        );

        let debug_json = format!(r#""{term:?}""#);
        assert!(
            serde_json::from_str::<WboTermCode>(&debug_json).is_err(),
            "{debug_json} must not deserialize"
        );
    }

    for spoof in [
        r#""t_w""#,
        r#""T_NUM""#,
        r#"" T_W""#,
        r#""T_W ""#,
        r#""T-SE""#,
    ] {
        assert!(
            serde_json::from_str::<WboTermCode>(spoof).is_err(),
            "{spoof} must not deserialize"
        );
    }
}

#[test]
fn lattice_error_contribution_round_trips_json() {
    let value =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "L1 residual gap", 0.05)
            .expect("valid residual contribution")
            .with_measured(0.02)
            .expect("valid measured contribution");

    let encoded = serde_json::to_string(&value).expect("serialize contribution");
    let decoded: LatticeErrorContribution =
        serde_json::from_str(&encoded).expect("deserialize contribution");

    assert_eq!(decoded, value);
    assert_eq!(decoded.term.code(), "T_R");
}

#[test]
fn lattice_error_contribution_serializes_public_accounting_keys() {
    let value =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "L1 residual gap", 0.05)
            .expect("valid residual contribution")
            .with_measured(0.02)
            .expect("valid measured contribution");
    let encoded = serde_json::to_value(&value).expect("serialize contribution");
    let object = encoded
        .as_object()
        .expect("contribution must serialize as an object");
    let mut keys = object.keys().map(String::as_str).collect::<Vec<_>>();
    keys.sort_unstable();

    assert_eq!(keys, vec!["budget", "measured", "source", "term"]);
    assert_eq!(object["term"], serde_json::json!("T_R"));
    assert_eq!(object["source"], serde_json::json!("L1 residual gap"));
    assert_eq!(object["budget"], serde_json::json!(0.05));
    assert_eq!(object["measured"], serde_json::json!(0.02));
}

#[test]
fn lattice_error_contribution_serializes_pending_measurement_as_null() {
    let value =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "L1 residual gap", 0.05)
            .expect("valid residual contribution");
    let encoded = serde_json::to_value(&value).expect("serialize contribution");
    let object = encoded
        .as_object()
        .expect("contribution must serialize as an object");

    assert!(object.contains_key("measured"));
    assert_eq!(object["measured"], serde_json::Value::Null);
    assert_eq!(value.measured_within_budget(), None);
}

#[test]
fn lattice_error_contribution_json_rejects_invalid_public_fields() {
    for (label, contribution) in [
        (
            "negative budget",
            serde_json::json!({
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": -0.01,
                "measured": null,
            }),
        ),
        (
            "negative measured value",
            serde_json::json!({
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": -0.01,
            }),
        ),
        (
            "blank source",
            serde_json::json!({
                "term": "T_num",
                "source": " ",
                "budget": 0.0,
                "measured": null,
            }),
        ),
        (
            "string budget",
            serde_json::json!({
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": "0.0",
                "measured": null,
            }),
        ),
        (
            "boolean budget",
            serde_json::json!({
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": true,
                "measured": null,
            }),
        ),
        (
            "object budget",
            serde_json::json!({
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": { "value": 0.0 },
                "measured": null,
            }),
        ),
        (
            "array budget",
            serde_json::json!({
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": [0.0],
                "measured": null,
            }),
        ),
        (
            "string measured value",
            serde_json::json!({
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": "0.0",
            }),
        ),
        (
            "boolean measured value",
            serde_json::json!({
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": false,
            }),
        ),
        (
            "object measured value",
            serde_json::json!({
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": { "value": 0.0 },
            }),
        ),
        (
            "array measured value",
            serde_json::json!({
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": [0.0],
            }),
        ),
    ] {
        assert!(
            serde_json::from_value::<LatticeErrorContribution>(contribution).is_err(),
            "{label} must not deserialize as a public contribution"
        );
    }

    let pending_measurement = serde_json::json!({
        "term": "T_num",
        "source": "exact ULP guard",
        "budget": 0.0,
        "measured": null,
    });
    assert!(
        serde_json::from_value::<LatticeErrorContribution>(pending_measurement).is_ok(),
        "null measured remains the public pending-measurement form"
    );
}

#[test]
fn lattice_budget_round_trips_json() {
    let residual_contribution = LatticeErrorContribution::new(
        WboTermCode::ResidualWynerZiv,
        "LWZ residual codec",
        0.04,
    )
    .expect("valid contribution");
    let numerical_contribution = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "exact ULP guard",
        0.0,
    )
    .expect("valid numerical contribution");
    let value = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![residual_contribution, numerical_contribution],
    );

    let encoded = serde_json::to_string(&value).expect("serialize budget");
    let decoded: LatticeBudget = serde_json::from_str(&encoded).expect("deserialize budget");

    assert_eq!(decoded, value);
    assert_eq!(decoded.pre_softmax_budget(), 0.04);
    assert_eq!(decoded.softmax_half_corrected_budget(), 0.02);
}

#[test]
fn lattice_budget_serializes_public_accounting_keys() {
    let contribution = LatticeErrorContribution::new(
        WboTermCode::ResidualWynerZiv,
        "LWZ residual codec",
        0.04,
    )
    .expect("valid contribution");
    let value = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![contribution],
    );
    let encoded = serde_json::to_value(&value).expect("serialize budget");
    let object = encoded
        .as_object()
        .expect("budget must serialize as an object");
    let mut keys = object.keys().map(String::as_str).collect::<Vec<_>>();
    keys.sort_unstable();

    assert_eq!(
        keys,
        vec![
            "coder",
            "contributions",
            "rate_milli_bits_per_symbol",
            "side_information",
        ]
    );
    assert_eq!(
        object["coder"],
        serde_json::json!("lattice-wyner-ziv-residual")
    );
    assert_eq!(
        object["rate_milli_bits_per_symbol"],
        serde_json::json!(1250)
    );
    assert_eq!(
        object["side_information"],
        serde_json::json!("ResidualStream")
    );
    assert!(object["contributions"].is_array());
}

#[test]
fn lattice_budget_serializes_non_rate_rate_field_as_null() {
    let contribution = LatticeErrorContribution::new(
        WboTermCode::NumericalPostCorrection,
        "exact ULP guard",
        0.0,
    )
    .expect("valid numerical contribution");
    let value = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution],
    );
    let encoded = serde_json::to_value(&value).expect("serialize budget");
    let object = encoded
        .as_object()
        .expect("budget must serialize as an object");

    assert!(object.contains_key("rate_milli_bits_per_symbol"));
    assert_eq!(
        object["rate_milli_bits_per_symbol"],
        serde_json::Value::Null
    );
    assert!(value.validate().is_ok());
}

#[test]
fn lattice_budget_json_rejects_unsigned_rate_spoofs() {
    fn budget_with_rate(rate: serde_json::Value) -> serde_json::Value {
        serde_json::json!({
            "coder": "nested-e8",
            "rate_milli_bits_per_symbol": rate,
            "side_information": "CalibrationHessian",
            "contributions": [
                {
                    "term": "T_W",
                    "source": "NestedE8 weight lattice",
                    "budget": 0.01,
                    "measured": null,
                },
                {
                    "term": "T_Q",
                    "source": "NestedE8 quantization lattice",
                    "budget": 0.01,
                    "measured": null,
                },
                {
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null,
                },
            ],
        })
    }

    for (label, rate) in [
        ("negative rate", serde_json::json!(-1)),
        ("fractional rate", serde_json::json!(1250.5)),
        ("string rate", serde_json::json!("1250")),
        ("boolean rate", serde_json::json!(true)),
        ("object rate", serde_json::json!({ "milli_bits": 1250 })),
        ("array rate", serde_json::json!([1250])),
        ("oversized rate", serde_json::json!((u32::MAX as u64) + 1)),
    ] {
        assert!(
            serde_json::from_value::<LatticeBudget>(budget_with_rate(rate)).is_err(),
            "{label} must not deserialize as a lattice budget rate"
        );
    }
}

#[test]
fn lattice_budget_json_rejects_invalid_public_envelopes() {
    let cases = [
        (
            "empty contributions",
            serde_json::json!({
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [],
            }),
        ),
        (
            "missing numerical guard",
            serde_json::json!({
                "coder": "nested-e8",
                "rate_milli_bits_per_symbol": 1250,
                "side_information": "CalibrationHessian",
                "contributions": [
                    {
                        "term": "T_W",
                        "source": "NestedE8 weight lattice",
                        "budget": 0.01,
                        "measured": null,
                    },
                    {
                        "term": "T_Q",
                        "source": "NestedE8 quantization lattice",
                        "budget": 0.01,
                        "measured": null,
                    },
                ],
            }),
        ),
        (
            "wrong side information",
            serde_json::json!({
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "ActiveSupport",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null,
                }],
            }),
        ),
    ];

    for (label, budget) in cases {
        assert!(
            serde_json::from_value::<LatticeBudget>(budget).is_err(),
            "{label} must not deserialize as a public lattice budget"
        );
    }
}

#[test]
fn lattice_budget_json_rejects_every_codec_wrong_side_information_fixture() {
    let mut checked = 0;
    for coder in LatticeCoderKind::ALL {
        let allowed = coder.canonical_side_information();
        for side_information in SideInformationKind::ALL {
            if allowed.contains(&side_information) {
                continue;
            }

            let budget = side_information_probe_budget(coder, side_information);
            let encoded =
                serde_json::to_value(&budget).expect("serialize wrong side-info budget");

            assert!(
                serde_json::from_value::<LatticeBudget>(encoded).is_err(),
                "{coder:?} public JSON accepted wrong side information {side_information:?}"
            );
            checked += 1;
        }
    }

    let expected = LatticeCoderKind::ALL
        .iter()
        .map(|coder| SideInformationKind::ALL.len() - coder.canonical_side_information().len())
        .sum::<usize>();
    assert_eq!(checked, expected);
    assert_eq!(checked, 108);

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains(
            "`lattice_budget_json_rejects_every_codec_wrong_side_information_fixture`"
        ),
        "register doc must cross-link JSON wrong-side-information adversarial matrix"
    );
}

#[test]
fn active_support_budget_round_trips_json() {
    let value = ActiveSupportBudget::new(
        4096,
        64,
        256 * 1024 * 1024,
        SideInformationKind::ActiveSupport,
    );

    let encoded = serde_json::to_string(&value).expect("serialize active support budget");
    let decoded: ActiveSupportBudget =
        serde_json::from_str(&encoded).expect("deserialize active support budget");

    assert_eq!(decoded, value);
    assert!(!decoded.is_zero());
    assert!(ActiveSupportBudget::zero(SideInformationKind::None).is_zero());
}

#[test]
fn active_support_budget_serializes_public_accounting_keys() {
    let value = ActiveSupportBudget::new(
        4096,
        64,
        256 * 1024 * 1024,
        SideInformationKind::ActiveSupport,
    );
    let encoded = serde_json::to_value(value).expect("serialize active support budget");
    let object = encoded
        .as_object()
        .expect("active support budget must serialize as an object");
    let mut keys = object.keys().map(String::as_str).collect::<Vec<_>>();
    keys.sort_unstable();

    assert_eq!(
        keys,
        vec![
            "max_active_pages",
            "max_active_tokens",
            "max_resident_bytes",
            "side_information",
        ]
    );
    assert_eq!(object["max_active_tokens"], serde_json::json!(4096));
    assert_eq!(object["max_active_pages"], serde_json::json!(64));
    assert_eq!(object["max_resident_bytes"], serde_json::json!(268_435_456));
    assert_eq!(
        object["side_information"],
        serde_json::json!("ActiveSupport")
    );
}

#[test]
fn active_support_budget_json_rejects_unsigned_axis_spoofs() {
    let cases = [
        (
            "negative token axis",
            serde_json::json!({
                "max_active_tokens": -1,
                "max_active_pages": 1,
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport",
            }),
        ),
        (
            "fractional page axis",
            serde_json::json!({
                "max_active_tokens": 1,
                "max_active_pages": 1.5,
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport",
            }),
        ),
        (
            "string resident-byte axis",
            serde_json::json!({
                "max_active_tokens": 1,
                "max_active_pages": 1,
                "max_resident_bytes": "1",
                "side_information": "ActiveSupport",
            }),
        ),
        (
            "boolean token axis",
            serde_json::json!({
                "max_active_tokens": true,
                "max_active_pages": 1,
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport",
            }),
        ),
        (
            "object resident-byte axis",
            serde_json::json!({
                "max_active_tokens": 1,
                "max_active_pages": 1,
                "max_resident_bytes": { "bytes": 1 },
                "side_information": "ActiveSupport",
            }),
        ),
        (
            "array page axis",
            serde_json::json!({
                "max_active_tokens": 1,
                "max_active_pages": [1],
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport",
            }),
        ),
        (
            "oversized token axis",
            serde_json::json!({
                "max_active_tokens": (u32::MAX as u64) + 1,
                "max_active_pages": 1,
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport",
            }),
        ),
        (
            "oversized page axis",
            serde_json::json!({
                "max_active_tokens": 1,
                "max_active_pages": (u32::MAX as u64) + 1,
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport",
            }),
        ),
    ];

    for (label, value) in cases {
        assert!(
            serde_json::from_value::<ActiveSupportBudget>(value).is_err(),
            "{label} must not deserialize as an active-support budget"
        );
    }

    let oversized_resident_bytes = r#"{
        "max_active_tokens": 1,
        "max_active_pages": 1,
        "max_resident_bytes": 18446744073709551616,
        "side_information": "ActiveSupport"
    }"#;
    assert!(
        serde_json::from_str::<ActiveSupportBudget>(oversized_resident_bytes).is_err(),
        "oversized resident-byte axis must not deserialize as an active-support budget"
    );
}

#[test]
fn active_support_budget_json_rejects_invalid_public_budget() {
    let cases = [
        (
            "zero token axis",
            serde_json::json!({
                "max_active_tokens": 0,
                "max_active_pages": 1,
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport",
            }),
        ),
        (
            "zero page axis",
            serde_json::json!({
                "max_active_tokens": 1,
                "max_active_pages": 0,
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport",
            }),
        ),
        (
            "zero resident-byte axis",
            serde_json::json!({
                "max_active_tokens": 1,
                "max_active_pages": 1,
                "max_resident_bytes": 0,
                "side_information": "ActiveSupport",
            }),
        ),
        (
            "wrong side information",
            serde_json::json!({
                "max_active_tokens": 1,
                "max_active_pages": 1,
                "max_resident_bytes": 1,
                "side_information": "ResidualStream",
            }),
        ),
    ];

    for (label, value) in cases {
        assert!(
            serde_json::from_value::<ActiveSupportBudget>(value).is_err(),
            "{label} must not deserialize as a public active-support budget"
        );
    }
}

#[test]
fn active_support_budget_json_rejects_combined_zero_axes_and_wrong_side_information() {
    let partial_axes = [
        ("zero token axis", 0, 1, 1),
        ("zero page axis", 1, 0, 1),
        ("zero resident-byte axis", 1, 1, 0),
    ];
    let mut checked = 0;

    for (label, tokens, pages, bytes) in partial_axes {
        for side_information in SideInformationKind::ALL
            .iter()
            .copied()
            .filter(|kind| *kind != SideInformationKind::ActiveSupport)
        {
            let value = serde_json::json!({
                "max_active_tokens": tokens,
                "max_active_pages": pages,
                "max_resident_bytes": bytes,
                "side_information": side_information,
            });

            assert!(
                serde_json::from_value::<ActiveSupportBudget>(value).is_err(),
                "{label} with {side_information:?} must not deserialize as a public active-support budget"
            );
            checked += 1;
        }
    }

    assert_eq!(
        checked,
        partial_axes.len() * (SideInformationKind::ALL.len() - 1)
    );
}

#[test]
fn wbo_ledger_entry_round_trips_json() {
    let budget = LatticeBudget::new(
        LatticeCoderKind::ShadowKvSketch,
        None,
        SideInformationKind::ActiveSupport,
        tier_probe_contributions(ResidencyTier::L2ShadowSketch),
    );
    let support = ActiveSupportBudget::new(
        2048,
        32,
        64 * 1024 * 1024,
        SideInformationKind::ActiveSupport,
    );
    let value = WboLedgerEntry::new(
        "L2 Shadow Sketch",
        budget,
        Some(support),
        "F-WBO-DriftLedger; F-ULP-Oracle; F-KV-Direct-Gate; F-ACS-AnchorLookup",
        "Active support is accounting metadata, not a speed claim.",
    );

    let encoded = serde_json::to_string(&value).expect("serialize ledger entry");
    let decoded: WboLedgerEntry =
        serde_json::from_str(&encoded).expect("deserialize ledger entry");

    assert_eq!(decoded, value);
    assert_eq!(
        decoded.wbo_terms(),
        vec![
            WboTermCode::KvCache,
            WboTermCode::SubstrateBoundary,
            WboTermCode::NumericalPostCorrection,
        ]
    );
}

#[test]
fn wbo_ledger_entry_json_rejects_invalid_public_rows() {
    fn exact_hot_entry(memory_tier: &str, falsifier: &str, caveat: &str) -> serde_json::Value {
        serde_json::json!({
            "memory_tier": memory_tier,
            "budget": {
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null,
                }],
            },
            "active_support": null,
            "falsifier": falsifier,
            "caveat": caveat,
        })
    }

    fn shadow_entry(active_support: serde_json::Value) -> serde_json::Value {
        serde_json::json!({
            "memory_tier": "L2 Shadow Sketch",
            "budget": {
                "coder": "shadow-kv-sketch",
                "rate_milli_bits_per_symbol": null,
                "side_information": "ActiveSupport",
                "contributions": [
                    {
                        "term": "T_S",
                        "source": "ShadowKV support",
                        "budget": 0.01,
                        "measured": null,
                    },
                    {
                        "term": "T_num",
                        "source": "exact ULP guard",
                        "budget": 0.0,
                        "measured": null,
                    },
                ],
            },
            "active_support": active_support,
            "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle; F-KV-Direct-Gate; F-ACS-AnchorLookup",
            "caveat": "Active support is accounting metadata, not a speed claim.",
        })
    }

    let cases = [
        (
            "blank memory tier",
            exact_hot_entry(
                " ",
                "F-WBO-DriftLedger; F-ULP-Oracle",
                "Exact hot rows still need numerical post-correction.",
            ),
        ),
        (
            "missing ULP oracle",
            exact_hot_entry(
                "L0 RAM hot",
                "F-WBO-DriftLedger",
                "Exact hot rows still need numerical post-correction.",
            ),
        ),
        (
            "blank caveat",
            exact_hot_entry("L0 RAM hot", "F-WBO-DriftLedger; F-ULP-Oracle", " "),
        ),
        (
            "missing active support",
            shadow_entry(serde_json::Value::Null),
        ),
    ];

    for (label, entry) in cases {
        assert!(
            serde_json::from_value::<WboLedgerEntry>(entry).is_err(),
            "{label} must not deserialize as a public WBO ledger row"
        );
    }
}

#[test]
fn wbo_ledger_entry_serializes_public_accounting_keys() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "ShadowKV support", 0.01)
            .expect("valid support contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ShadowKvSketch,
        None,
        SideInformationKind::ActiveSupport,
        vec![contribution],
    );
    let support = ActiveSupportBudget::new(
        2048,
        32,
        64 * 1024 * 1024,
        SideInformationKind::ActiveSupport,
    );
    let value = WboLedgerEntry::new(
        "L2 Shadow Sketch",
        budget,
        Some(support),
        "F-WBO-DriftLedger",
        "Active support is accounting metadata, not a speed claim.",
    );
    let encoded = serde_json::to_value(&value).expect("serialize ledger entry");
    let object = encoded
        .as_object()
        .expect("ledger entry must serialize as an object");
    let mut keys = object.keys().map(String::as_str).collect::<Vec<_>>();
    keys.sort_unstable();

    assert_eq!(
        keys,
        vec![
            "active_support",
            "budget",
            "caveat",
            "falsifier",
            "memory_tier"
        ]
    );
    assert_eq!(object["memory_tier"], serde_json::json!("L2 Shadow Sketch"));
    assert!(object["budget"].is_object());
    assert!(object["active_support"].is_object());
    assert_eq!(object["falsifier"], serde_json::json!("F-WBO-DriftLedger"));
    assert_eq!(
        object["caveat"],
        serde_json::json!("Active support is accounting metadata, not a speed claim.")
    );
}
