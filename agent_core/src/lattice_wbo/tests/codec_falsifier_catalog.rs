//! Codec falsifier-catalog tests: hook coverage and falsifier registry surface.

use super::*;

#[test]
fn budget_validation_rejects_crossed_hessian_domains() {
    let quantization =
        LatticeErrorContribution::new(WboTermCode::Quantization, "quantization", 0.01)
            .expect("valid contribution");
    let weight_budget = LatticeBudget::new(
        LatticeCoderKind::QuipE8,
        Some(2000),
        SideInformationKind::RuntimeKvHessian,
        vec![quantization.clone()],
    );
    let kv_budget = LatticeBudget::new(
        LatticeCoderKind::ShadowKvSketch,
        None,
        SideInformationKind::CalibrationHessian,
        vec![quantization],
    );

    assert_eq!(
        weight_budget.validate_side_information(),
        Err(LatticeWboError::InvalidSideInformation)
    );
    assert_eq!(
        kv_budget.validate_side_information(),
        Err(LatticeWboError::InvalidSideInformation)
    );
}

#[test]
fn lattice_coder_catalog_names_falsifiers_for_every_codec() {
    for coder in LatticeCoderKind::ALL {
        assert!(!coder.falsifier().is_empty());
    }
    assert_eq!(
        LatticeCoderKind::Nf4SsdOracle.falsifier(),
        "F-KV-Direct-Gate; F-ULP-Oracle; F-WBO-DriftLedger; layerwise reconstruction/logit drift witness; F-ACS-AnchorLookup"
    );
    assert_eq!(
        LatticeCoderKind::EngramHashRecall.falsifier(),
        "F-ACS-AnchorLookup; F-ULP-Oracle; F-WBO-DriftLedger"
    );
    assert_eq!(
        LatticeCoderKind::SelfEvolvingAdapter.falsifier(),
        "adapter replay/provenance verifier; F-ULP-Oracle; F-WBO-DriftLedger; layerwise reconstruction/logit drift witness"
    );
}

#[test]
fn lattice_coder_catalog_includes_babai_gptq_nearest_plane() {
    assert_eq!(
        LatticeCoderKind::BabaiGptqNearestPlane.canonical_name(),
        "babai-gptq-nearest-plane"
    );
    assert_eq!(
        LatticeCoderKind::BabaiGptqNearestPlane.canonical_wbo_terms(),
        &[
            WboTermCode::WeightRuntime,
            WboTermCode::NumericalPostCorrection
        ]
    );
    assert_eq!(
        LatticeCoderKind::BabaiGptqNearestPlane.canonical_side_information(),
        &[SideInformationKind::CalibrationHessian]
    );
    assert!(!LatticeCoderKind::BabaiGptqNearestPlane.allows_rate_parameter());
}

#[test]
fn lattice_coder_catalog_maps_every_codec_to_wbo_terms() {
    for coder in LatticeCoderKind::ALL {
        assert!(!coder.canonical_wbo_terms().is_empty());
        for (index, term) in coder.canonical_wbo_terms().iter().enumerate() {
            assert!(
                !coder.canonical_wbo_terms()[index + 1..].contains(term),
                "{coder:?} must not duplicate {} in canonical WBO terms",
                term.code()
            );
        }
    }
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
        LatticeCoderKind::ResidualSketch.canonical_wbo_terms(),
        &[
            WboTermCode::ResidualWynerZiv,
            WboTermCode::Quantization,
            WboTermCode::SubstrateBoundary,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::SherryTernary3Of4.canonical_wbo_terms(),
        &[
            WboTermCode::WeightRuntime,
            WboTermCode::Quantization,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::EngramHashRecall.canonical_wbo_terms(),
        &[
            WboTermCode::SubstrateBoundary,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::NetworkCascade.canonical_wbo_terms(),
        &[
            WboTermCode::SubstrateBoundary,
            WboTermCode::SelfEvolvingSecurity,
            WboTermCode::NumericalPostCorrection,
        ]
    );
    assert_eq!(
        LatticeCoderKind::SelfEvolvingAdapter.canonical_wbo_terms(),
        &[
            WboTermCode::WeightRuntime,
            WboTermCode::SelfEvolvingSecurity,
            WboTermCode::NumericalPostCorrection,
        ]
    );
}

#[test]
fn lattice_coder_catalog_attaches_numerical_guard_to_every_codec() {
    for coder in LatticeCoderKind::ALL {
        assert!(
            coder
                .canonical_wbo_terms()
                .contains(&WboTermCode::NumericalPostCorrection),
            "{coder:?} must carry T_num as a numerical post-correction guard"
        );
    }
}

#[test]
fn codec_falsifiers_cover_every_canonical_term_falsifier() {
    for coder in LatticeCoderKind::ALL {
        for term in coder.canonical_wbo_terms() {
            assert!(
                contains_any_falsifier_hook(coder.falsifier(), term.falsifier()),
                "{coder:?} falsifier must cover {}",
                term.code()
            );
        }
    }
}

#[test]
fn codec_falsifiers_name_ulp_oracle_when_owning_t_num() {
    for coder in LatticeCoderKind::ALL {
        if coder
            .canonical_wbo_terms()
            .contains(&WboTermCode::NumericalPostCorrection)
        {
            assert!(
                contains_falsifier_hook(coder.falsifier(), "F-ULP-Oracle"),
                "{coder:?} owns T_num and must name F-ULP-Oracle"
            );
        }
    }
}

#[test]
fn falsifier_hook_registry_owns_every_f_hook_named_by_catalogs() {
    let owners = falsifier_hook_owners();
    let owner_rows = owners
        .iter()
        .map(|owner| (owner.hook, owner.owner))
        .collect::<Vec<_>>();
    assert_eq!(
        owner_rows,
        vec![
            (
                "F-WBO-DriftLedger",
                "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md",
            ),
            ("F-ULP-Oracle", "agent_core/src/research/eml/ulp_oracle.rs"),
            (
                "F-KV-Direct-Gate",
                "agent_core/src/scope_rex/kv/direct_gate.rs",
            ),
            ("F-ACS-AnchorLookup", "agent_core/src/research/acs/mod.rs"),
        ]
    );
    for owner in owners {
        assert!(owner.hook.starts_with("F-"));
        assert!(
            !owner.owner.trim().is_empty(),
            "{} must name a concrete owner",
            owner.hook
        );
    }

    let mut hooks = Vec::new();
    for coder in LatticeCoderKind::ALL {
        hooks.extend(f_hooks_in(coder.falsifier()));
    }
    for term in WboTermCode::ALL {
        hooks.extend(f_hooks_in(term.falsifier()));
    }
    for tier in ResidencyTier::ALL {
        hooks.extend(f_hooks_in(tier.primary_falsifier()));
    }
    hooks.sort_unstable();
    hooks.dedup();

    for hook in &hooks {
        assert!(
            owners.iter().any(|owner| owner.hook == *hook),
            "missing falsifier owner for {hook}"
        );
    }
    for owner in owners {
        assert!(
            hooks.contains(&owner.hook),
            "{} owner is stale; no catalog row names it",
            owner.hook
        );
    }
}

#[test]
fn falsifier_hook_owner_registry_hook_keys_are_trimmed_ascii_dash_format() {
    for owner in falsifier_hook_owners() {
        let hook = owner.hook;
        assert!(!hook.is_empty(), "{hook}");
        assert_eq!(hook.trim(), hook, "{hook}");
        assert!(hook.is_ascii(), "{hook}");
        assert!(hook.starts_with("F-"), "{hook} must use the F- prefix");
        assert!(!hook.contains(' '), "{hook} must not contain whitespace");
        assert!(!hook.contains('_'), "{hook} must not contain underscores");
        assert!(!hook.contains("--"), "{hook} must not double-dash");
        assert!(!hook.ends_with('-'), "{hook} must not end with a dash");
        assert!(
            hook.chars()
                .all(|ch| ch == '-' || ch.is_ascii_alphanumeric()),
            "{hook} must use ASCII alphanumerics and dashes only"
        );
        assert!(
            hook[2..].chars().any(|ch| ch.is_ascii_alphanumeric()),
            "{hook} must name a body after the F- prefix"
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register
            .contains("`falsifier_hook_owner_registry_hook_keys_are_trimmed_ascii_dash_format`"),
        "register doc must cross-link falsifier hook key format safety"
    );
}

#[test]
fn falsifier_hook_owner_registry_has_unique_public_hooks() {
    assert_unique_catalog_keys(
        falsifier_hook_owners()
            .iter()
            .map(|owner| owner.hook.to_owned())
            .collect(),
        "falsifier hook owner registry",
    );
}

#[test]
fn falsifier_hook_registry_owner_rows_follow_canonical_order() {
    let hooks = falsifier_hook_owners()
        .iter()
        .map(|owner| owner.hook)
        .collect::<Vec<_>>();

    assert_eq!(
        hooks,
        vec![
            "F-WBO-DriftLedger",
            "F-ULP-Oracle",
            "F-KV-Direct-Gate",
            "F-ACS-AnchorLookup",
        ],
        "falsifier owner rows must stay in canonical owner order"
    );
}

#[test]
fn falsifier_hook_owner_registry_serializes_public_keys() {
    let encoded =
        serde_json::to_value(falsifier_hook_owners()).expect("serialize falsifier owners");
    let rows = encoded
        .as_array()
        .expect("owner registry serializes as rows");
    assert_eq!(rows.len(), falsifier_hook_owners().len());

    for row in rows {
        let object = row.as_object().expect("owner row must serialize as object");
        let mut keys = object.keys().map(String::as_str).collect::<Vec<_>>();
        keys.sort_unstable();
        assert_eq!(keys, vec!["hook", "owner"]);
        assert!(object["hook"]
            .as_str()
            .expect("hook must serialize as string")
            .starts_with("F-"));
        assert!(!object["owner"]
            .as_str()
            .expect("owner must serialize as string")
            .trim()
            .is_empty());
    }
}

#[test]
fn falsifier_hook_owner_json_rejects_unknown_fields() {
    let error = serde_json::from_str::<FalsifierHookOwner>(
        r#"{
            "hook": "F-WBO-DriftLedger",
            "owner": "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md",
            "debug": "ignored field"
        }"#,
    )
    .expect_err("unknown falsifier owner JSON field must be rejected");
    let message = error.to_string();
    assert!(message.contains("unknown field"), "{message}");
    assert!(message.contains("debug"), "{message}");
}

#[test]
fn falsifier_hook_owner_json_rejects_unregistered_public_rows() {
    for (label, row) in [
        (
            "unowned hook",
            r#"{
                "hook": "F-NOT-OWNED",
                "owner": "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md"
            }"#,
        ),
        (
            "unicode-adjacent hook suffix",
            r#"{
                "hook": "F-ULP-Oracleβ",
                "owner": "agent_core/src/research/eml/ulp_oracle.rs"
            }"#,
        ),
        (
            "unicode-adjacent hook prefix",
            r#"{
                "hook": "βF-ULP-Oracle",
                "owner": "agent_core/src/research/eml/ulp_oracle.rs"
            }"#,
        ),
        (
            "blank owner",
            r#"{
                "hook": "F-WBO-DriftLedger",
                "owner": " "
            }"#,
        ),
        (
            "mismatched owner",
            r#"{
                "hook": "F-WBO-DriftLedger",
                "owner": "agent_core/src/research/eml/ulp_oracle.rs"
            }"#,
        ),
    ] {
        assert!(
            serde_json::from_str::<FalsifierHookOwner>(row).is_err(),
            "{label} must not deserialize as a falsifier owner row"
        );
    }

    let ulp_owner = serde_json::from_str::<FalsifierHookOwner>(
        r#"{
            "hook": "F-ULP-Oracle",
            "owner": "agent_core/src/research/eml/ulp_oracle.rs"
        }"#,
    )
    .expect("canonical falsifier owner row should deserialize");
    assert_eq!(ulp_owner, FALSIFIER_HOOK_OWNERS[1]);
}

#[test]
fn falsifier_hook_owner_json_rejects_cross_owner_borrowing() {
    for owner in falsifier_hook_owners() {
        for other in falsifier_hook_owners() {
            if owner == other {
                continue;
            }

            let borrowed_owner = serde_json::json!({
                "hook": owner.hook,
                "owner": other.owner,
            });
            assert!(
                serde_json::from_value::<FalsifierHookOwner>(borrowed_owner).is_err(),
                "{} must not borrow {}",
                owner.hook,
                other.owner
            );

            let borrowed_hook = serde_json::json!({
                "hook": other.hook,
                "owner": owner.owner,
            });
            assert!(
                serde_json::from_value::<FalsifierHookOwner>(borrowed_hook).is_err(),
                "{} must not borrow {}",
                owner.owner,
                other.hook
            );
        }
    }
}

#[test]
fn codec_falsifier_catalogs_name_owned_f_hooks_for_every_codec() {
    let owners = falsifier_hook_owners();

    for coder in LatticeCoderKind::ALL {
        let hooks = f_hooks_in(coder.falsifier());
        assert!(
            !hooks.is_empty(),
            "{coder:?} must name at least one F-* hook"
        );
        for hook in hooks {
            assert!(
                owners.iter().any(|owner| owner.hook == hook),
                "{coder:?} names unowned falsifier hook {hook}"
            );
        }
    }
}

#[test]
fn codec_falsifier_catalogs_cover_every_owned_f_hook() {
    let mut codec_hooks = Vec::new();
    for coder in LatticeCoderKind::ALL {
        codec_hooks.extend(f_hooks_in(coder.falsifier()));
    }
    codec_hooks.sort_unstable();
    codec_hooks.dedup();

    for owner in falsifier_hook_owners() {
        assert!(
            codec_hooks.contains(&owner.hook),
            "{} owner hook must be emitted by at least one codec falsifier row",
            owner.hook
        );
    }
}

#[test]
fn codec_falsifier_hook_sets_are_pinned_to_owner_registry() {
    let rows = LatticeCoderKind::ALL
        .iter()
        .map(|coder| (coder.canonical_name(), f_hooks_in(coder.falsifier())))
        .collect::<Vec<_>>();

    assert_eq!(
        rows,
        vec![
            ("exact-hot", vec!["F-WBO-DriftLedger", "F-ULP-Oracle"]),
            (
                "lattice-wyner-ziv-residual",
                vec!["F-WBO-DriftLedger", "F-ULP-Oracle", "F-ACS-AnchorLookup"],
            ),
            (
                "babai-gptq-nearest-plane",
                vec!["F-WBO-DriftLedger", "F-ULP-Oracle"],
            ),
            (
                "sherry-3-of-4-ternary",
                vec!["F-WBO-DriftLedger", "F-ULP-Oracle"],
            ),
            (
                "shadow-kv-sketch",
                vec![
                    "F-WBO-DriftLedger",
                    "F-ULP-Oracle",
                    "F-KV-Direct-Gate",
                    "F-ACS-AnchorLookup",
                ],
            ),
            (
                "engram-hash-recall",
                vec!["F-ACS-AnchorLookup", "F-ULP-Oracle", "F-WBO-DriftLedger"],
            ),
            ("nested-e8", vec!["F-WBO-DriftLedger", "F-ULP-Oracle"]),
            ("nested-leech-24", vec!["F-WBO-DriftLedger", "F-ULP-Oracle"],),
            ("quip-e8", vec!["F-WBO-DriftLedger", "F-ULP-Oracle"]),
            (
                "nf4-ssd-oracle",
                vec![
                    "F-KV-Direct-Gate",
                    "F-ULP-Oracle",
                    "F-WBO-DriftLedger",
                    "F-ACS-AnchorLookup",
                ],
            ),
            (
                "residual-sketch",
                vec!["F-WBO-DriftLedger", "F-ULP-Oracle", "F-ACS-AnchorLookup"],
            ),
            (
                "network-cascade",
                vec!["F-ULP-Oracle", "F-WBO-DriftLedger", "F-ACS-AnchorLookup"],
            ),
            (
                "self-evolving-adapter",
                vec!["F-ULP-Oracle", "F-WBO-DriftLedger"],
            ),
        ]
    );

    let owners = falsifier_hook_owners();
    for (_, hooks) in rows {
        for hook in hooks {
            assert!(
                owners.iter().any(|owner| owner.hook == hook),
                "{hook} must resolve through FALSIFIER_HOOK_OWNERS"
            );
        }
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`codec_falsifier_hook_sets_are_pinned_to_owner_registry`"),
        "register doc must cross-link codec falsifier owner hook matrix"
    );
}

#[test]
fn residency_primary_falsifiers_name_owned_f_hooks_for_every_tier() {
    let owners = falsifier_hook_owners();

    for tier in ResidencyTier::ALL {
        let hooks = f_hooks_in(tier.primary_falsifier());
        assert!(
            !hooks.is_empty(),
            "{} must name at least one F-* hook",
            tier.canonical_name()
        );
        for hook in hooks {
            assert!(
                owners.iter().any(|owner| owner.hook == hook),
                "{} names unowned falsifier hook {hook}",
                tier.canonical_name()
            );
        }
    }
}

#[test]
fn residency_primary_falsifiers_cover_every_owned_f_hook() {
    let mut residency_hooks = Vec::new();
    for tier in ResidencyTier::ALL {
        residency_hooks.extend(f_hooks_in(tier.primary_falsifier()));
    }
    residency_hooks.sort_unstable();
    residency_hooks.dedup();

    for owner in falsifier_hook_owners() {
        assert!(
            residency_hooks.contains(&owner.hook),
            "{} owner hook must be emitted by at least one residency primary falsifier",
            owner.hook
        );
    }
}

#[test]
fn residency_primary_falsifier_hook_sets_are_pinned_to_owner_registry() {
    let rows = ResidencyTier::ALL
        .iter()
        .map(|tier| (tier.canonical_name(), f_hooks_in(tier.primary_falsifier())))
        .collect::<Vec<_>>();

    assert_eq!(
        rows,
        vec![
            ("L0 RAM hot", vec!["F-WBO-DriftLedger", "F-ULP-Oracle"]),
            (
                "L1 Compressed Residual",
                vec!["F-WBO-DriftLedger", "F-ULP-Oracle", "F-ACS-AnchorLookup"],
            ),
            (
                "L2 Shadow Sketch",
                vec![
                    "F-WBO-DriftLedger",
                    "F-ULP-Oracle",
                    "F-KV-Direct-Gate",
                    "F-ACS-AnchorLookup",
                ],
            ),
            (
                "L3 SSD Oracle",
                vec![
                    "F-KV-Direct-Gate",
                    "F-ULP-Oracle",
                    "F-WBO-DriftLedger",
                    "F-ACS-AnchorLookup",
                ],
            ),
            (
                "L4 Engram",
                vec!["F-ACS-AnchorLookup", "F-ULP-Oracle", "F-WBO-DriftLedger"],
            ),
            (
                "L5 Network Cascade",
                vec!["F-ULP-Oracle", "F-WBO-DriftLedger", "F-ACS-AnchorLookup"],
            ),
            (
                "L_SE Self-Evolving",
                vec!["F-ULP-Oracle", "F-WBO-DriftLedger"],
            ),
        ]
    );

    let owners = falsifier_hook_owners();
    for (_, hooks) in rows {
        for hook in hooks {
            assert!(
                owners.iter().any(|owner| owner.hook == hook),
                "{hook} must resolve through FALSIFIER_HOOK_OWNERS"
            );
        }
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`residency_primary_falsifier_hook_sets_are_pinned_to_owner_registry`"),
        "register doc must cross-link residency falsifier owner hook matrix"
    );
}

fn lattice_wbo_repo_root() -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("agent_core should have a repository parent")
        .to_path_buf()
}

#[test]
fn falsifier_hook_registry_owner_paths_exist() {
    let repo_root = lattice_wbo_repo_root();

    for owner in falsifier_hook_owners() {
        let owner_path = std::path::Path::new(owner.owner);
        assert!(
            owner_path.is_relative()
                && !owner_path
                    .components()
                    .any(|component| matches!(component, std::path::Component::ParentDir)),
            "{} owner path must be relative to the repository without `..`: {}",
            owner.hook,
            owner.owner
        );
        let path = repo_root.join(owner.owner);
        assert!(
            path.is_file(),
            "{} owner path must resolve to an existing repo file: {}",
            owner.hook,
            owner.owner
        );
    }
}

#[test]
fn falsifier_hook_registry_owner_paths_are_trimmed_ascii_unix_source_files() {
    for owner in falsifier_hook_owners() {
        let owner_path = owner.owner;
        assert!(!owner_path.is_empty(), "{}", owner.hook);
        assert_eq!(owner_path.trim(), owner_path, "{}", owner.hook);
        assert!(owner_path.is_ascii(), "{}", owner.hook);
        assert!(
            !owner_path.contains('\\'),
            "{} owner must use unix forward slashes: {owner_path}",
            owner.hook
        );
        assert!(
            !owner_path.contains(' '),
            "{} owner must not contain whitespace: {owner_path}",
            owner.hook
        );
        assert!(
            !owner_path.starts_with('/'),
            "{} owner must be a relative repo path: {owner_path}",
            owner.hook
        );
        assert!(
            !owner_path.contains("//"),
            "{} owner must not double-slash: {owner_path}",
            owner.hook
        );
        assert!(
            owner_path.ends_with(".rs") || owner_path.ends_with(".md"),
            "{} owner must end with .rs or .md: {owner_path}",
            owner.hook
        );
    }

    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register
            .contains("`falsifier_hook_registry_owner_paths_are_trimmed_ascii_unix_source_files`"),
        "register doc must cross-link falsifier owner path format safety"
    );
}

#[test]
fn falsifier_hook_registry_owner_paths_are_unique_files() {
    assert_unique_catalog_keys(
        falsifier_hook_owners()
            .iter()
            .map(|owner| owner.owner.to_owned())
            .collect(),
        "falsifier hook owner path registry",
    );
}

#[test]
fn falsifier_hook_registry_owner_paths_stay_in_canonical_surfaces() {
    let allowed_prefixes = [
        "docs/fusion/",
        "agent_core/src/research/",
        "agent_core/src/scope_rex/",
    ];

    for owner in falsifier_hook_owners() {
        assert!(
            allowed_prefixes
                .iter()
                .any(|prefix| owner.owner.starts_with(prefix)),
            "{} owner path must stay in a canonical falsifier surface: {}",
            owner.hook,
            owner.owner
        );
    }
}

#[test]
fn falsifier_hook_owner_files_name_their_hooks() {
    let repo_root = lattice_wbo_repo_root();

    for owner in falsifier_hook_owners() {
        let path = repo_root.join(owner.owner);
        let contents = std::fs::read_to_string(&path)
            .unwrap_or_else(|error| panic!("failed to read {}: {error}", path.display()));
        assert!(
            contents.contains(owner.hook),
            "{} owner file must name owned hook {}",
            owner.owner,
            owner.hook
        );
    }
}

#[test]
fn register_doc_f_hooks_are_owned_by_registry() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let owners = falsifier_hook_owners();
    let mut hooks = f_hooks_in(register)
        .into_iter()
        .filter(|hook| hook.len() > "F-".len())
        .collect::<Vec<_>>();
    hooks.sort_unstable();
    hooks.dedup();
    let mut owner_hooks = owners.iter().map(|owner| owner.hook).collect::<Vec<_>>();
    owner_hooks.sort_unstable();

    for hook in &hooks {
        assert!(
            owners.iter().any(|owner| owner.hook == *hook),
            "register hook {hook} must have a falsifier owner"
        );
    }
    assert_eq!(
        hooks, owner_hooks,
        "register F-* hook set must match falsifier owner registry"
    );
}

#[test]
fn register_doc_cross_links_falsifier_owner_path_uniqueness() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("falsifier_hook_registry_owner_paths_are_unique_files"),
        "register must cross-link the owner-path uniqueness guard"
    );
}

#[test]
fn register_doc_cross_links_duplicate_axis_order_invariance() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("lattice_budget_duplicate_axis_measured_totals_are_order_invariant"),
        "register must cross-link duplicate-axis measured order invariance"
    );
}

#[test]
fn register_doc_cross_links_codec_wrong_side_information_matrix_counts() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("codec_noncanonical_side_information_rejection_matrix_counts_are_pinned"),
        "register must cross-link codec wrong-side-information matrix counts"
    );
}

#[test]
fn register_doc_cross_links_residency_wrong_side_information_matrix_counts() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register
            .contains("residency_nonprimary_side_information_rejection_matrix_counts_are_pinned"),
        "register must cross-link residency wrong-side-information matrix counts"
    );
}

#[test]
fn register_doc_cross_links_residency_foreign_term_matrix_counts() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("residency_foreign_wbo_term_rejection_matrix_counts_are_pinned"),
        "register must cross-link residency foreign-term matrix counts"
    );
}

#[test]
fn register_doc_cross_links_residency_nonprimary_codec_matrix_counts() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("residency_nonprimary_codec_rejection_matrix_counts_are_pinned"),
        "register must cross-link residency nonprimary-codec matrix counts"
    );
}

#[test]
fn register_doc_cross_links_rate_ownership_matrix_counts() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("rate_parameter_ownership_matrix_counts_are_pinned"),
        "register must cross-link rate-ownership matrix counts"
    );
}

#[test]
fn register_doc_cross_links_active_support_residency_matrix_counts() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("active_support_budget_residency_matrix_counts_are_pinned"),
        "register must cross-link active-support residency matrix counts"
    );
}

#[test]
fn register_doc_cross_links_active_support_disallowed_rejection_matrix_counts() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register
            .contains("active_support_budget_disallowed_tier_rejection_matrix_counts_are_pinned"),
        "register must cross-link active-support disallowed-tier rejection matrix counts"
    );
}

#[test]
fn register_doc_cross_links_active_support_wrong_tag_rejection_matrix_counts() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("active_support_budget_wrong_tag_rejection_matrix_counts_are_pinned"),
        "register must cross-link active-support wrong-tag rejection matrix counts"
    );
}

#[test]
fn register_doc_cross_links_active_support_partial_zero_axis_matrix_counts() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register
            .contains("active_support_budget_partial_zero_axis_rejection_matrix_counts_are_pinned"),
        "register must cross-link active-support partial-zero axis matrix counts"
    );
}
