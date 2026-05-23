//! Public-key registry tests: catalog uniqueness, ordering, and JSON sanitization.

use super::*;

#[test]
fn typed_catalogs_cover_all_wbo_and_side_information_rows() {
    assert_eq!(
        WboTermCode::ALL
            .iter()
            .map(|term| term.code())
            .collect::<Vec<_>>(),
        vec!["T_W", "T_K", "T_R", "T_Q", "T_S", "T_SE", "T_num"]
    );
    assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::SherryTernary3Of4));
    assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::ShadowKvSketch));
    assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::EngramHashRecall));
    assert!(LatticeCoderKind::ALL.contains(&LatticeCoderKind::QuipE8));
    assert_eq!(
        LatticeCoderKind::ALL
            .iter()
            .map(|coder| coder.canonical_name())
            .collect::<Vec<_>>(),
        vec![
            "exact-hot",
            "lattice-wyner-ziv-residual",
            "babai-gptq-nearest-plane",
            "sherry-3-of-4-ternary",
            "shadow-kv-sketch",
            "engram-hash-recall",
            "nested-e8",
            "nested-leech-24",
            "quip-e8",
            "nf4-ssd-oracle",
            "residual-sketch",
            "network-cascade",
            "self-evolving-adapter",
        ]
    );
    assert_eq!(
        SideInformationKind::ALL
            .iter()
            .map(|side_information| format!("{side_information:?}"))
            .collect::<Vec<_>>(),
        vec![
            "None",
            "DecoderLmState",
            "ResidualStream",
            "CalibrationHessian",
            "RuntimeKvHessian",
            "ActiveSupport",
            "SsdOracle",
            "StaticFactKey",
            "NetworkTeacher",
            "SurpriseGradient",
        ]
    );
    assert!(SideInformationKind::ALL.contains(&SideInformationKind::CalibrationHessian));
    assert!(SideInformationKind::ALL.contains(&SideInformationKind::RuntimeKvHessian));
    assert!(SideInformationKind::ALL.contains(&SideInformationKind::ActiveSupport));
    assert!(SideInformationKind::ALL.contains(&SideInformationKind::StaticFactKey));
}

#[test]
fn typed_all_catalogs_have_unique_public_keys() {
    assert_unique_catalog_keys(
        ResidencyTier::CODES
            .iter()
            .map(|key| (*key).to_owned())
            .collect(),
        "ResidencyTier::CODES public keys",
    );
    assert_unique_catalog_keys(
        LatticeCoderKind::ALL
            .iter()
            .map(|coder| coder.canonical_name().to_owned())
            .collect(),
        "LatticeCoderKind::ALL canonical names",
    );
    assert_unique_catalog_keys(
        LatticeCoderKind::CODES
            .iter()
            .map(|key| (*key).to_owned())
            .collect(),
        "LatticeCoderKind::CODES public keys",
    );
    assert_unique_catalog_keys(
        LatticeCoderKind::ALL
            .iter()
            .map(|coder| format!("{coder:?}"))
            .collect(),
        "LatticeCoderKind::ALL debug row keys",
    );
    assert_unique_catalog_keys(
        SideInformationKind::CODES
            .iter()
            .map(|key| (*key).to_owned())
            .collect(),
        "SideInformationKind::CODES public keys",
    );
    assert_unique_catalog_keys(
        WboTermCode::CODES
            .iter()
            .map(|key| (*key).to_owned())
            .collect(),
        "WboTermCode::CODES public keys",
    );
    assert_unique_catalog_keys(
        LatticeWboError::CODES
            .iter()
            .map(|key| (*key).to_owned())
            .collect(),
        "LatticeWboError::CODES public keys",
    );
}

#[test]
fn explicit_public_key_tables_follow_all_catalog_order() {
    assert_eq!(
        ResidencyTier::CODES.to_vec(),
        ResidencyTier::ALL
            .iter()
            .map(|tier| tier.canonical_name())
            .collect::<Vec<_>>()
    );
    assert_eq!(
        LatticeCoderKind::CODES.to_vec(),
        LatticeCoderKind::ALL
            .iter()
            .map(|coder| coder.canonical_name())
            .collect::<Vec<_>>()
    );
    assert_eq!(
        SideInformationKind::CODES.to_vec(),
        SideInformationKind::ALL
            .iter()
            .map(|kind| kind.key())
            .collect::<Vec<_>>()
    );
    assert_eq!(
        WboTermCode::CODES.to_vec(),
        WboTermCode::ALL
            .iter()
            .map(|term| term.code())
            .collect::<Vec<_>>()
    );
    assert_eq!(
        LatticeWboError::CODES.to_vec(),
        LatticeWboError::ALL
            .iter()
            .map(|error| error.key())
            .collect::<Vec<_>>()
    );
}

#[test]
fn public_key_registries_deserialize_from_owned_json_values() {
    assert_eq!(
        serde_json::from_value::<ResidencyTier>(serde_json::json!("L0 RAM hot"))
            .expect("owned residency key value"),
        ResidencyTier::L0RamHot
    );
    assert_eq!(
        serde_json::from_value::<LatticeCoderKind>(serde_json::json!(
            "lattice-wyner-ziv-residual"
        ))
        .expect("owned codec key value"),
        LatticeCoderKind::LatticeWynerZivResidual
    );
    assert_eq!(
        serde_json::from_value::<SideInformationKind>(serde_json::json!("ResidualStream"))
            .expect("owned side-information key value"),
        SideInformationKind::ResidualStream
    );
    assert_eq!(
        serde_json::from_value::<WboTermCode>(serde_json::json!("T_num"))
            .expect("owned term key value"),
        WboTermCode::NumericalPostCorrection
    );
    assert_eq!(
        serde_json::from_value::<LatticeWboError>(serde_json::json!(
            "InvalidBudgetComposition"
        ))
        .expect("owned error key value"),
        LatticeWboError::InvalidBudgetComposition
    );
}

#[test]
fn public_key_registries_reject_wrong_type_json_values() {
    assert_json_wrong_type_rejected::<ResidencyTier>(r#"["L0 RAM hot"]"#);
    assert_json_wrong_type_rejected::<LatticeCoderKind>(r#"{"codec": "exact-hot"}"#);
    assert_json_wrong_type_rejected::<SideInformationKind>(r#"0"#);
    assert_json_wrong_type_rejected::<WboTermCode>(r#"true"#);
    assert_json_wrong_type_rejected::<LatticeWboError>(r#"null"#);
}

#[test]
fn public_key_registries_reject_cross_registry_keys() {
    fn reject_keys<T>(registry: &str, keys: Vec<&'static str>)
    where
        T: for<'de> Deserialize<'de>,
    {
        for key in keys {
            assert!(
                serde_json::from_value::<T>(serde_json::json!(key)).is_err(),
                "{registry} accepted cross-registry key {key}"
            );
        }
    }

    reject_keys::<ResidencyTier>(
        "ResidencyTier",
        [
            &LatticeCoderKind::CODES[..],
            &SideInformationKind::CODES[..],
            &WboTermCode::CODES[..],
            &LatticeWboError::CODES[..],
        ]
        .concat(),
    );
    reject_keys::<LatticeCoderKind>(
        "LatticeCoderKind",
        [
            &ResidencyTier::CODES[..],
            &SideInformationKind::CODES[..],
            &WboTermCode::CODES[..],
            &LatticeWboError::CODES[..],
        ]
        .concat(),
    );
    reject_keys::<SideInformationKind>(
        "SideInformationKind",
        [
            &ResidencyTier::CODES[..],
            &LatticeCoderKind::CODES[..],
            &WboTermCode::CODES[..],
            &LatticeWboError::CODES[..],
        ]
        .concat(),
    );
    reject_keys::<WboTermCode>(
        "WboTermCode",
        [
            &ResidencyTier::CODES[..],
            &LatticeCoderKind::CODES[..],
            &SideInformationKind::CODES[..],
            &LatticeWboError::CODES[..],
        ]
        .concat(),
    );
    reject_keys::<LatticeWboError>(
        "LatticeWboError",
        [
            &ResidencyTier::CODES[..],
            &LatticeCoderKind::CODES[..],
            &SideInformationKind::CODES[..],
            &WboTermCode::CODES[..],
        ]
        .concat(),
    );
}

#[test]
fn public_key_registries_reject_unicode_adjacent_public_keys() {
    fn reject_unicode_adjacent_keys<T>(registry: &str, keys: &[&str])
    where
        T: for<'de> Deserialize<'de>,
    {
        for key in keys {
            for spoof in [format!("β{key}"), format!("{key}β")] {
                assert!(
                    serde_json::from_value::<T>(serde_json::json!(spoof)).is_err(),
                    "{registry} accepted unicode-adjacent key {key}"
                );
            }
        }
    }

    reject_unicode_adjacent_keys::<ResidencyTier>("ResidencyTier", &ResidencyTier::CODES);
    reject_unicode_adjacent_keys::<LatticeCoderKind>(
        "LatticeCoderKind",
        &LatticeCoderKind::CODES,
    );
    reject_unicode_adjacent_keys::<SideInformationKind>(
        "SideInformationKind",
        &SideInformationKind::CODES,
    );
    reject_unicode_adjacent_keys::<WboTermCode>("WboTermCode", &WboTermCode::CODES);
    reject_unicode_adjacent_keys::<LatticeWboError>("LatticeWboError", &LatticeWboError::CODES);
}

#[test]
fn public_key_registries_reject_whitespace_adjacent_public_keys() {
    fn reject_whitespace_adjacent_keys<T>(registry: &str, keys: &[&str])
    where
        T: for<'de> Deserialize<'de>,
    {
        for key in keys {
            for spoof in [
                format!(" {key}"),
                format!("{key} "),
                format!("\t{key}"),
                format!("{key}\n"),
            ] {
                assert!(
                    serde_json::from_value::<T>(serde_json::json!(spoof)).is_err(),
                    "{registry} accepted whitespace-adjacent key {key}"
                );
            }
        }
    }

    reject_whitespace_adjacent_keys::<ResidencyTier>("ResidencyTier", &ResidencyTier::CODES);
    reject_whitespace_adjacent_keys::<LatticeCoderKind>(
        "LatticeCoderKind",
        &LatticeCoderKind::CODES,
    );
    reject_whitespace_adjacent_keys::<SideInformationKind>(
        "SideInformationKind",
        &SideInformationKind::CODES,
    );
    reject_whitespace_adjacent_keys::<WboTermCode>("WboTermCode", &WboTermCode::CODES);
    reject_whitespace_adjacent_keys::<LatticeWboError>(
        "LatticeWboError",
        &LatticeWboError::CODES,
    );

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`public_key_registries_reject_whitespace_adjacent_public_keys`"),
        "register doc must cross-link whitespace-adjacent public-key rejection"
    );
}

#[test]
fn public_key_registries_reject_control_character_adjacent_public_keys() {
    fn reject_control_character_adjacent_keys<T>(registry: &str, keys: &[&str])
    where
        T: for<'de> Deserialize<'de>,
    {
        for key in keys {
            for control in ["\0", "\u{0007}", "\u{001b}"] {
                for spoof in [format!("{control}{key}"), format!("{key}{control}")] {
                    assert!(
                        serde_json::from_value::<T>(serde_json::json!(spoof)).is_err(),
                        "{registry} accepted control-character-adjacent key {key}"
                    );
                }
            }
        }
    }

    reject_control_character_adjacent_keys::<ResidencyTier>(
        "ResidencyTier",
        &ResidencyTier::CODES,
    );
    reject_control_character_adjacent_keys::<LatticeCoderKind>(
        "LatticeCoderKind",
        &LatticeCoderKind::CODES,
    );
    reject_control_character_adjacent_keys::<SideInformationKind>(
        "SideInformationKind",
        &SideInformationKind::CODES,
    );
    reject_control_character_adjacent_keys::<WboTermCode>("WboTermCode", &WboTermCode::CODES);
    reject_control_character_adjacent_keys::<LatticeWboError>(
        "LatticeWboError",
        &LatticeWboError::CODES,
    );

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register
            .contains("`public_key_registries_reject_control_character_adjacent_public_keys`"),
        "register doc must cross-link control-character-adjacent public-key rejection"
    );
}

#[test]
fn public_key_registries_reject_quoted_and_escaped_public_key_spoofs() {
    fn reject_quoted_and_escaped_keys<T>(registry: &str, keys: &[&str])
    where
        T: for<'de> Deserialize<'de>,
    {
        for key in keys {
            for spoof in [
                format!("\"{key}\""),
                format!("\\{key}"),
                format!("{key}\\"),
                format!("{key}\""),
            ] {
                assert!(
                    serde_json::from_value::<T>(serde_json::json!(spoof)).is_err(),
                    "{registry} accepted quoted or escaped key spoof {key}"
                );
            }
        }
    }

    reject_quoted_and_escaped_keys::<ResidencyTier>("ResidencyTier", &ResidencyTier::CODES);
    reject_quoted_and_escaped_keys::<LatticeCoderKind>(
        "LatticeCoderKind",
        &LatticeCoderKind::CODES,
    );
    reject_quoted_and_escaped_keys::<SideInformationKind>(
        "SideInformationKind",
        &SideInformationKind::CODES,
    );
    reject_quoted_and_escaped_keys::<WboTermCode>("WboTermCode", &WboTermCode::CODES);
    reject_quoted_and_escaped_keys::<LatticeWboError>(
        "LatticeWboError",
        &LatticeWboError::CODES,
    );

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register
            .contains("`public_key_registries_reject_quoted_and_escaped_public_key_spoofs`"),
        "register doc must cross-link quoted and escaped public-key spoof rejection"
    );
}

#[test]
fn public_key_registries_reject_percent_encoded_public_key_spoofs() {
    fn reject_percent_encoded_keys<T>(registry: &str, keys: &[&str])
    where
        T: for<'de> Deserialize<'de>,
    {
        for key in keys {
            for spoof in [
                format!("%20{key}"),
                format!("{key}%20"),
                format!("%22{key}%22"),
                format!("{key}%00"),
            ] {
                assert!(
                    serde_json::from_value::<T>(serde_json::json!(spoof)).is_err(),
                    "{registry} accepted percent-encoded key spoof {key}"
                );
            }
        }
    }

    reject_percent_encoded_keys::<ResidencyTier>("ResidencyTier", &ResidencyTier::CODES);
    reject_percent_encoded_keys::<LatticeCoderKind>(
        "LatticeCoderKind",
        &LatticeCoderKind::CODES,
    );
    reject_percent_encoded_keys::<SideInformationKind>(
        "SideInformationKind",
        &SideInformationKind::CODES,
    );
    reject_percent_encoded_keys::<WboTermCode>("WboTermCode", &WboTermCode::CODES);
    reject_percent_encoded_keys::<LatticeWboError>("LatticeWboError", &LatticeWboError::CODES);

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`public_key_registries_reject_percent_encoded_public_key_spoofs`"),
        "register doc must cross-link percent-encoded public-key spoof rejection"
    );
}

#[test]
fn public_key_registries_reject_html_entity_public_key_spoofs() {
    fn reject_html_entity_keys<T>(registry: &str, keys: &[&str])
    where
        T: for<'de> Deserialize<'de>,
    {
        for key in keys {
            for spoof in [
                format!("&quot;{key}&quot;"),
                format!("&#34;{key}&#34;"),
                format!("&#x20;{key}"),
                format!("{key}&nbsp;"),
            ] {
                assert!(
                    serde_json::from_value::<T>(serde_json::json!(spoof)).is_err(),
                    "{registry} accepted HTML-entity key spoof {key}"
                );
            }
        }
    }

    reject_html_entity_keys::<ResidencyTier>("ResidencyTier", &ResidencyTier::CODES);
    reject_html_entity_keys::<LatticeCoderKind>("LatticeCoderKind", &LatticeCoderKind::CODES);
    reject_html_entity_keys::<SideInformationKind>(
        "SideInformationKind",
        &SideInformationKind::CODES,
    );
    reject_html_entity_keys::<WboTermCode>("WboTermCode", &WboTermCode::CODES);
    reject_html_entity_keys::<LatticeWboError>("LatticeWboError", &LatticeWboError::CODES);

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`public_key_registries_reject_html_entity_public_key_spoofs`"),
        "register doc must cross-link HTML-entity public-key spoof rejection"
    );
}

#[test]
fn public_key_registries_reject_delimiter_wrapped_public_key_spoofs() {
    fn reject_delimiter_wrapped_keys<T>(registry: &str, keys: &[&str])
    where
        T: for<'de> Deserialize<'de>,
    {
        for key in keys {
            for spoof in [
                format!("({key})"),
                format!("[{key}]"),
                format!("{{{key}}}"),
                format!("<{key}>"),
            ] {
                assert!(
                    serde_json::from_value::<T>(serde_json::json!(spoof)).is_err(),
                    "{registry} accepted delimiter-wrapped key spoof {key}"
                );
            }
        }
    }

    reject_delimiter_wrapped_keys::<ResidencyTier>("ResidencyTier", &ResidencyTier::CODES);
    reject_delimiter_wrapped_keys::<LatticeCoderKind>(
        "LatticeCoderKind",
        &LatticeCoderKind::CODES,
    );
    reject_delimiter_wrapped_keys::<SideInformationKind>(
        "SideInformationKind",
        &SideInformationKind::CODES,
    );
    reject_delimiter_wrapped_keys::<WboTermCode>("WboTermCode", &WboTermCode::CODES);
    reject_delimiter_wrapped_keys::<LatticeWboError>(
        "LatticeWboError",
        &LatticeWboError::CODES,
    );

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`public_key_registries_reject_delimiter_wrapped_public_key_spoofs`"),
        "register doc must cross-link delimiter-wrapped public-key spoof rejection"
    );
}
