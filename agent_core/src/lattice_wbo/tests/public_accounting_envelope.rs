//! Public accounting envelope rejection matrix: unknown / nested-unknown / duplicate / missing / wrong-type field tests.

use super::*;

#[test]
fn public_accounting_json_rejects_unknown_fields() {
    let contribution = serde_json::json!({
        "term": "T_num",
        "source": "exact ULP guard",
        "budget": 0.0,
        "measured": null,
        "debug": "ignored field",
    });
    assert_json_unknown_field_rejected::<LatticeErrorContribution>(contribution, "debug");

    let budget = serde_json::json!({
        "coder": "exact-hot",
        "rate_milli_bits_per_symbol": null,
        "side_information": "None",
        "contributions": [{
            "term": "T_num",
            "source": "exact ULP guard",
            "budget": 0.0,
            "measured": null,
        }],
        "memory_tier": "L0 RAM hot",
    });
    assert_json_unknown_field_rejected::<LatticeBudget>(budget, "memory_tier");

    let support = serde_json::json!({
        "max_active_tokens": 1,
        "max_active_pages": 1,
        "max_resident_bytes": 1,
        "side_information": "ActiveSupport",
        "codec": "shadow-kv-sketch",
    });
    assert_json_unknown_field_rejected::<ActiveSupportBudget>(support, "codec");

    let entry = serde_json::json!({
        "memory_tier": "L0 RAM hot",
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
        "falsifier": "F-WBO-DriftLedger + F-ULP-Oracle",
        "caveat": "Exact hot rows still need numerical post-correction.",
        "residency_tier": "L0RamHot",
    });
    assert_json_unknown_field_rejected::<WboLedgerEntry>(entry, "residency_tier");

    let owner = serde_json::json!({
        "hook": "F-ULP-Oracle",
        "owner": "agent_core/src/research/eml/ulp_oracle.rs",
        "debug": "borrowed owner",
    });
    assert_json_unknown_field_rejected::<FalsifierHookOwner>(owner, "debug");
}

#[test]
fn public_accounting_json_rejects_nested_unknown_fields() {
    let budget = serde_json::json!({
        "coder": "exact-hot",
        "rate_milli_bits_per_symbol": null,
        "side_information": "None",
        "contributions": [{
            "term": "T_num",
            "source": "exact ULP guard",
            "budget": 0.0,
            "measured": null,
            "debug": "nested field",
        }],
    });
    assert_json_unknown_field_rejected::<LatticeBudget>(budget, "debug");

    let ledger_contribution = serde_json::json!({
        "memory_tier": "L0 RAM hot",
        "budget": {
            "coder": "exact-hot",
            "rate_milli_bits_per_symbol": null,
            "side_information": "None",
            "contributions": [{
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": null,
                "debug": "nested field",
            }],
        },
        "active_support": null,
        "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
        "caveat": "Exact hot rows still need numerical post-correction.",
    });
    assert_json_unknown_field_rejected::<WboLedgerEntry>(ledger_contribution, "debug");

    let entry = serde_json::json!({
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
        "active_support": {
            "max_active_tokens": 1,
            "max_active_pages": 1,
            "max_resident_bytes": 1,
            "side_information": "ActiveSupport",
            "codec": "shadow-kv-sketch",
        },
        "falsifier": "F-WBO-DriftLedger; F-ACS-AnchorLookup; F-ULP-Oracle",
        "caveat": "Active support must be explicitly budgeted.",
    });
    assert_json_unknown_field_rejected::<WboLedgerEntry>(entry, "codec");
}

#[test]
fn public_accounting_json_rejects_duplicate_public_keys() {
    assert_json_duplicate_field_rejected::<LatticeErrorContribution>(
        r#"{
            "term": "T_num",
            "source": "exact ULP guard",
            "source": "shadowed source",
            "budget": 0.0,
            "measured": null
        }"#,
        "source",
    );
    assert_json_duplicate_field_rejected::<LatticeErrorContribution>(
        r#"{
            "term": "T_num",
            "source": "exact ULP guard",
            "budget": 0.0,
            "measured": null,
            "measured": 0.0
        }"#,
        "measured",
    );
    assert_json_duplicate_field_rejected::<LatticeBudget>(
        r#"{
            "coder": "exact-hot",
            "coder": "shadow-kv-sketch",
            "rate_milli_bits_per_symbol": null,
            "side_information": "None",
            "contributions": [{
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": null
            }]
        }"#,
        "coder",
    );
    assert_json_duplicate_field_rejected::<LatticeBudget>(
        r#"{
            "coder": "exact-hot",
            "rate_milli_bits_per_symbol": null,
            "rate_milli_bits_per_symbol": 1,
            "side_information": "None",
            "contributions": [{
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": null
            }]
        }"#,
        "rate_milli_bits_per_symbol",
    );
    assert_json_duplicate_field_rejected::<ActiveSupportBudget>(
        r#"{
            "max_active_tokens": 1,
            "max_active_pages": 1,
            "max_active_pages": 2,
            "max_resident_bytes": 1,
            "side_information": "ActiveSupport"
        }"#,
        "max_active_pages",
    );
    assert_json_duplicate_field_rejected::<WboLedgerEntry>(
        r#"{
            "memory_tier": "L0 RAM hot",
            "budget": {
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null
                }]
            },
            "active_support": null,
            "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
            "falsifier": "F-WBO-DriftLedger",
            "caveat": "Exact hot rows still need numerical post-correction."
        }"#,
        "falsifier",
    );
    assert_json_duplicate_field_rejected::<WboLedgerEntry>(
        r#"{
            "memory_tier": "L0 RAM hot",
            "budget": {
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null
                }]
            },
            "active_support": null,
            "active_support": {
                "max_active_tokens": 1,
                "max_active_pages": 1,
                "max_resident_bytes": 1,
                "side_information": "ActiveSupport"
            },
            "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
            "caveat": "Exact hot rows still need numerical post-correction."
        }"#,
        "active_support",
    );
    assert_json_duplicate_field_rejected::<FalsifierHookOwner>(
        r#"{
            "hook": "F-ULP-Oracle",
            "hook": "F-WBO-DriftLedger",
            "owner": "agent_core/src/research/eml/ulp_oracle.rs"
        }"#,
        "hook",
    );
    assert_json_duplicate_field_rejected::<FalsifierHookOwner>(
        r#"{
            "hook": "F-ULP-Oracle",
            "owner": "agent_core/src/research/eml/ulp_oracle.rs",
            "owner": "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md"
        }"#,
        "owner",
    );
}

#[test]
fn public_accounting_json_rejects_missing_required_keys() {
    let contribution = serde_json::json!({
        "term": "T_num",
        "source": "exact ULP guard",
        "budget": 0.0,
        "measured": null,
    });
    for field in ["term", "source", "budget", "measured"] {
        assert_json_missing_field_value_rejected::<LatticeErrorContribution>(
            contribution.clone(),
            field,
        );
    }

    let budget = serde_json::json!({
        "coder": "exact-hot",
        "rate_milli_bits_per_symbol": null,
        "side_information": "None",
        "contributions": [contribution.clone()],
    });
    for field in [
        "coder",
        "rate_milli_bits_per_symbol",
        "side_information",
        "contributions",
    ] {
        assert_json_missing_field_value_rejected::<LatticeBudget>(budget.clone(), field);
    }

    let active_support = serde_json::json!({
        "max_active_tokens": 1,
        "max_active_pages": 1,
        "max_resident_bytes": 1,
        "side_information": "ActiveSupport",
    });
    for field in [
        "max_active_tokens",
        "max_active_pages",
        "max_resident_bytes",
        "side_information",
    ] {
        assert_json_missing_field_value_rejected::<ActiveSupportBudget>(
            active_support.clone(),
            field,
        );
    }

    let ledger_entry = serde_json::json!({
        "memory_tier": "L0 RAM hot",
        "budget": budget,
        "active_support": null,
        "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
        "caveat": "Exact hot rows still need numerical post-correction.",
    });
    for field in [
        "memory_tier",
        "budget",
        "active_support",
        "falsifier",
        "caveat",
    ] {
        assert_json_missing_field_value_rejected::<WboLedgerEntry>(ledger_entry.clone(), field);
    }

    let owner = serde_json::json!({
        "hook": "F-ULP-Oracle",
        "owner": "agent_core/src/research/eml/ulp_oracle.rs",
    });
    for field in ["hook", "owner"] {
        assert_json_missing_field_value_rejected::<FalsifierHookOwner>(owner.clone(), field);
    }
}

#[test]
fn public_accounting_json_rejects_wrong_type_public_fields() {
    assert_json_wrong_type_rejected::<LatticeErrorContribution>(
        r#"{
            "term": ["T_num"],
            "source": "exact ULP guard",
            "budget": 0.0,
            "measured": null
        }"#,
    );
    assert_json_wrong_type_rejected::<LatticeErrorContribution>(
        r#"{
            "term": "T_num",
            "source": ["exact ULP guard"],
            "budget": 0.0,
            "measured": null
        }"#,
    );
    assert_json_wrong_type_rejected::<LatticeErrorContribution>(
        r#"{
            "term": "T_num",
            "source": "exact ULP guard",
            "budget": 0.0,
            "measured": ["pending"]
        }"#,
    );
    assert_json_wrong_type_rejected::<LatticeBudget>(
        r#"{
            "coder": {"key": "exact-hot"},
            "rate_milli_bits_per_symbol": null,
            "side_information": "None",
            "contributions": [{
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": null
            }]
        }"#,
    );
    assert_json_wrong_type_rejected::<LatticeBudget>(
        r#"{
            "coder": "nested-e8",
            "rate_milli_bits_per_symbol": "1250",
            "side_information": "WeightCodebook",
            "contributions": [{
                "term": "T_W",
                "source": "NestedE8 weight lattice",
                "budget": 0.01,
                "measured": null
            }, {
                "term": "T_Q",
                "source": "NestedE8 quantization lattice",
                "budget": 0.01,
                "measured": null
            }, {
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": null
            }]
        }"#,
    );
    assert_json_wrong_type_rejected::<LatticeBudget>(
        r#"{
            "coder": "exact-hot",
            "rate_milli_bits_per_symbol": null,
            "side_information": 0,
            "contributions": [{
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": null
            }]
        }"#,
    );
    assert_json_wrong_type_rejected::<LatticeBudget>(
        r#"{
            "coder": "exact-hot",
            "rate_milli_bits_per_symbol": null,
            "side_information": "None",
            "contributions": {
                "term": "T_num",
                "source": "exact ULP guard",
                "budget": 0.0,
                "measured": null
            }
        }"#,
    );
    assert_json_wrong_type_rejected::<ActiveSupportBudget>(
        r#"{
            "max_active_tokens": 1,
            "max_active_pages": 1,
            "max_resident_bytes": 1,
            "side_information": false
        }"#,
    );
    assert_json_wrong_type_rejected::<WboLedgerEntry>(
        r#"{
            "memory_tier": ["L0 RAM hot"],
            "budget": {
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null
                }]
            },
            "active_support": null,
            "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
            "caveat": "Exact hot rows still need numerical post-correction."
        }"#,
    );
    assert_json_wrong_type_rejected::<WboLedgerEntry>(
        r#"{
            "memory_tier": "L0 RAM hot",
            "budget": true,
            "active_support": null,
            "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
            "caveat": "Exact hot rows still need numerical post-correction."
        }"#,
    );
    assert_json_wrong_type_rejected::<WboLedgerEntry>(
        r#"{
            "memory_tier": "L0 RAM hot",
            "budget": {
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null
                }]
            },
            "active_support": true,
            "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
            "caveat": "Exact hot rows still need numerical post-correction."
        }"#,
    );
    assert_json_wrong_type_rejected::<WboLedgerEntry>(
        r#"{
            "memory_tier": "L0 RAM hot",
            "budget": {
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null
                }]
            },
            "active_support": null,
            "falsifier": 1,
            "caveat": "Exact hot rows still need numerical post-correction."
        }"#,
    );
    assert_json_wrong_type_rejected::<WboLedgerEntry>(
        r#"{
            "memory_tier": "L0 RAM hot",
            "budget": {
                "coder": "exact-hot",
                "rate_milli_bits_per_symbol": null,
                "side_information": "None",
                "contributions": [{
                    "term": "T_num",
                    "source": "exact ULP guard",
                    "budget": 0.0,
                    "measured": null
                }]
            },
            "active_support": null,
            "falsifier": "F-WBO-DriftLedger; F-ULP-Oracle",
            "caveat": ["Exact hot rows still need numerical post-correction."]
        }"#,
    );
    assert_json_wrong_type_rejected::<FalsifierHookOwner>(
        r#"{
            "hook": ["F-ULP-Oracle"],
            "owner": "agent_core/src/research/eml/ulp_oracle.rs"
        }"#,
    );
    assert_json_wrong_type_rejected::<FalsifierHookOwner>(
        r#"{
            "hook": "F-ULP-Oracle",
            "owner": {"path": "agent_core/src/research/eml/ulp_oracle.rs"}
        }"#,
    );
}

#[test]
fn wbo_ledger_entry_serializes_absent_active_support_as_null() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::NumericalPostCorrection, "exact ULP guard", 0.0)
            .expect("valid numerical contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::ExactHot,
        None,
        SideInformationKind::None,
        vec![contribution],
    );
    let value = WboLedgerEntry::new(
        "L0 RAM hot",
        budget,
        None,
        "F-WBO-DriftLedger; F-ULP-Oracle",
        "Exact hot is the reference path, not a compression claim.",
    );
    let encoded = serde_json::to_value(&value).expect("serialize ledger entry");
    let object = encoded
        .as_object()
        .expect("ledger entry must serialize as an object");

    assert!(object.contains_key("active_support"));
    assert_eq!(object["active_support"], serde_json::Value::Null);
    assert!(value.validate().is_ok());
}
