//! Register doc row-order tests across codec, side-information, error-variant tables.

use super::*;

#[test]
fn register_doc_keeps_nested_lattice_codec_rows_standalone() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

    for row_prefix in ["| QuIP/E8 |", "| Nested E8 |", "| Nested Leech24 |"] {
        let row_count = register
            .lines()
            .filter(|line| line.starts_with(row_prefix))
            .count();
        assert_eq!(row_count, 1, "{row_prefix} must name one standalone row");
    }
}

#[test]
fn register_doc_names_every_codec_and_side_information_kind() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

    assert!(
        register.contains("## Codec-to-Falsifier / Side-Information Coverage"),
        "codec coverage section must name both falsifiers and side information"
    );

    for coder in LatticeCoderKind::ALL {
        let needle = format!("| `{:?}` |", coder);
        assert!(register.contains(&needle), "missing doc row for {coder:?}");
        let row_count = register
            .lines()
            .filter(|line| line.starts_with(&needle))
            .count();
        assert_eq!(row_count, 1, "{coder:?} must name one codec doc row");
        let row = register
            .lines()
            .find(|line| line.starts_with(&needle))
            .expect("codec falsifier row should exist");
        let cells = row
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .collect::<Vec<_>>();
        let term_cell = cells
            .get(2)
            .unwrap_or_else(|| panic!("{coder:?} doc row must have WBO term cell"));
        let actual_terms = term_cell
            .split('`')
            .skip(1)
            .step_by(2)
            .filter_map(WboTermCode::from_code)
            .collect::<Vec<_>>();
        assert_eq!(
            actual_terms,
            coder.canonical_wbo_terms(),
            "{coder:?} doc row term cell must preserve canonical_wbo_terms() order"
        );
        for term in WboTermCode::ALL {
            let term_name = format!("`{}`", term.code());
            let expected = coder.canonical_wbo_terms().contains(&term);
            assert_eq!(
                term_cell.contains(&term_name),
                expected,
                "{coder:?} doc row term cell must exactly match {term_name} ownership"
            );
        }
        let falsifier_cell = cells
            .get(3)
            .unwrap_or_else(|| panic!("{coder:?} doc row must have falsifier cell"));
        for clause in coder.falsifier().split(';').map(str::trim) {
            assert!(
                falsifier_cell.contains(clause),
                "{coder:?} doc falsifier cell must name typed falsifier clause {clause}"
            );
        }
        let expected_hooks = f_hooks_in(coder.falsifier());
        let mut expected_hook_set = expected_hooks.clone();
        expected_hook_set.sort_unstable();
        expected_hook_set.dedup();
        let mut actual_hook_set = f_hooks_in(falsifier_cell);
        actual_hook_set.sort_unstable();
        actual_hook_set.dedup();
        assert_eq!(
            actual_hook_set, expected_hook_set,
            "{coder:?} doc falsifier cell must exactly match typed F-* hooks"
        );
        for hook in f_hooks_in(falsifier_cell) {
            assert!(
                expected_hooks.contains(&hook),
                "{coder:?} doc falsifier cell must not name unowned hook {hook}"
            );
        }
        let side_information_cell = cells
            .get(4)
            .unwrap_or_else(|| panic!("{coder:?} doc row must have side-information cell"));
        for side_information in SideInformationKind::ALL {
            let side_information_name = format!("`{side_information:?}`");
            let expected = coder
                .canonical_side_information()
                .contains(&side_information);
            assert_eq!(
                side_information_cell.contains(&side_information_name),
                expected,
                "{coder:?} doc row side-information cell must exactly match {side_information_name} ownership"
            );
        }
    }

    for side_information in SideInformationKind::ALL {
        let needle = format!("| `{:?}` |", side_information);
        assert!(
            register.contains(&needle),
            "missing side-information doc row for {side_information:?}"
        );
        let row_count = register
            .lines()
            .filter(|line| line.starts_with(&needle))
            .count();
        assert_eq!(
            row_count, 1,
            "{side_information:?} must name one side-information doc row"
        );
        let row = register
            .lines()
            .find(|line| line.starts_with(&needle))
            .expect("side-information row should exist");
        let cells = row
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .collect::<Vec<_>>();
        let owner_cell = cells
            .get(2)
            .unwrap_or_else(|| panic!("{side_information:?} doc row must have owner cell"));
        let actual_owners = owner_cell
            .split('`')
            .skip(1)
            .step_by(2)
            .filter_map(|owner| {
                LatticeCoderKind::ALL
                    .iter()
                    .copied()
                    .find(|coder| format!("{coder:?}") == owner)
            })
            .collect::<Vec<_>>();
        let expected_owners = LatticeCoderKind::ALL
            .iter()
            .copied()
            .filter(|coder| {
                coder
                    .canonical_side_information()
                    .contains(&side_information)
            })
            .collect::<Vec<_>>();
        assert_eq!(
            actual_owners, expected_owners,
            "{side_information:?} doc owner cell must preserve LatticeCoderKind::ALL order"
        );
        for coder in LatticeCoderKind::ALL {
            let coder_name = format!("`{coder:?}`");
            let expected_owner = coder
                .canonical_side_information()
                .contains(&side_information);
            assert_eq!(
                owner_cell.contains(&coder_name),
                expected_owner,
                "{side_information:?} doc owner cell must exactly match {coder_name} ownership"
            );
        }
        let caveat = match side_information {
            SideInformationKind::None => "L0 still pays `T_num`",
            SideInformationKind::DecoderLmState => {
                "Calibration Hessian or runtime KV curvature"
            }
            SideInformationKind::ResidualStream => "Weight-only quantization evidence",
            SideInformationKind::CalibrationHessian => "Runtime KV Hessian",
            SideInformationKind::RuntimeKvHessian => "Offline calibration Hessian",
            SideInformationKind::ActiveSupport => "active support must still pay `T_S`",
            SideInformationKind::SsdOracle => "Proof that NF4 pages are exact",
            SideInformationKind::StaticFactKey => "Dynamic reasoning, residual reconstruction",
            SideInformationKind::NetworkTeacher => "Local lattice decoding",
            SideInformationKind::SurpriseGradient => "KV/cache compression",
        };
        assert!(
            cells.get(3).is_some_and(|cell| cell.contains(caveat)),
            "{side_information:?} doc row must preserve caveat {caveat}"
        );
    }
}

fn register_codec_rows(register: &str) -> Vec<String> {
    register
        .lines()
        .skip_while(|line| *line != "## Codec-to-Falsifier / Side-Information Coverage")
        .skip(1)
        .take_while(|line| !line.starts_with("## "))
        .filter_map(|line| {
            line.strip_prefix("| `")
                .and_then(|tail| tail.split_once("` |"))
                .map(|(name, _)| name.to_owned())
        })
        .collect::<Vec<_>>()
}

#[test]
fn register_doc_codec_rows_follow_catalog_order() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let expected = LatticeCoderKind::ALL
        .iter()
        .map(|coder| format!("{coder:?}"))
        .collect::<Vec<_>>();

    assert_eq!(
        register_codec_rows(register),
        expected,
        "codec coverage rows must stay in LatticeCoderKind::ALL order"
    );
}

fn register_side_information_rows(register: &str) -> Vec<String> {
    register
        .lines()
        .skip_while(|line| *line != "## Side-Information Decoding Kinds")
        .skip(1)
        .take_while(|line| !line.starts_with("## "))
        .filter_map(|line| {
            line.strip_prefix("| `")
                .and_then(|tail| tail.split_once("` |"))
                .map(|(name, _)| name.to_owned())
        })
        .collect::<Vec<_>>()
}

#[test]
fn register_doc_side_information_rows_follow_catalog_order() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let expected = SideInformationKind::ALL
        .iter()
        .map(|side_information| format!("{side_information:?}"))
        .collect::<Vec<_>>();

    assert_eq!(
        register_side_information_rows(register),
        expected,
        "side-information rows must stay in SideInformationKind::ALL order"
    );
}

fn register_error_rows(register: &str) -> Vec<String> {
    assert!(
        register.contains("## Error Variant Register"),
        "register must include a dedicated LatticeWboError section"
    );
    register
        .lines()
        .skip_while(|line| *line != "## Error Variant Register")
        .skip(1)
        .take_while(|line| !line.starts_with("## "))
        .filter_map(|line| {
            line.strip_prefix("| `")
                .and_then(|tail| tail.split_once("` |"))
                .map(|(name, _)| name.to_owned())
        })
        .collect::<Vec<_>>()
}

#[test]
fn register_doc_names_every_lattice_wbo_error_variant() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");

    let expected = LatticeWboError::ALL
        .iter()
        .map(|error| format!("{error:?}"))
        .collect::<Vec<_>>();
    let actual_rows = register_error_rows(register);

    assert_eq!(
        actual_rows.len(),
        expected.len(),
        "error register must not keep stale or missing rows"
    );
    for row in &actual_rows {
        assert!(
            expected.contains(row),
            "error register row {row} is not in LatticeWboError::ALL"
        );
    }
    for error in LatticeWboError::ALL {
        let needle = format!("| `{:?}` |", error);
        let row_count = register
            .lines()
            .filter(|line| line.starts_with(&needle))
            .count();
        assert_eq!(row_count, 1, "{error:?} must name one register error row");
    }
}

#[test]
fn register_doc_error_variant_rows_follow_lattice_wbo_error_all_order() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let expected = LatticeWboError::ALL
        .iter()
        .map(|error| format!("{error:?}"))
        .collect::<Vec<_>>();

    assert_eq!(
        register_error_rows(register),
        expected,
        "error register rows must stay in LatticeWboError::ALL order"
    );
}

#[test]
fn register_doc_names_tier_specific_security_verifier_clauses() {
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    let expected = [
        (
            ResidencyTier::L5NetworkCascade,
            "provider/provenance replay",
        ),
        (
            ResidencyTier::LSeSelfEvolving,
            "adapter replay/provenance verifier",
        ),
    ];

    for (tier, verifier) in expected {
        let needle = format!("| {} |", tier.canonical_name());
        let row = register
            .lines()
            .find(|line| line.starts_with(&needle))
            .unwrap_or_else(|| {
                panic!("missing register doc row for {}", tier.canonical_name())
            });
        let cells = row
            .trim_matches('|')
            .split('|')
            .map(str::trim)
            .collect::<Vec<_>>();
        let falsifier_cell = cells.get(4).unwrap_or_else(|| {
            panic!("{} doc row must have falsifier cell", tier.canonical_name())
        });
        let clauses = falsifier_cell.split(';').map(str::trim).collect::<Vec<_>>();
        assert!(
            clauses.contains(&verifier),
            "{} doc row must name exact security verifier clause {verifier}",
            tier.canonical_name()
        );
    }
}
