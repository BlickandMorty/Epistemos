//! WboLedgerEntry residency rejection-matrix tests: non-primary codecs, foreign terms, and non-primary side-information.

use super::*;

#[test]
fn ledger_validation_rejects_residency_codec_mismatch() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::SubstrateBoundary, "teacher boundary", 0.01)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::NetworkCascade,
        None,
        SideInformationKind::NetworkTeacher,
        vec![contribution],
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L4Engram,
        budget,
        None,
        "provider/provenance replay",
        "Network teacher rows must not be hidden under L4 Engram accounting.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::ResidencyCodecMismatch)
    );
}

#[test]
fn ledger_validation_rejects_every_nonprimary_codec_for_every_residency_tier() {
    let mut checked = 0;
    for tier in ResidencyTier::ALL {
        for coder in LatticeCoderKind::ALL {
            if coder == tier.primary_coder() {
                continue;
            }

            let budget =
                side_information_probe_budget(coder, coder.canonical_side_information()[0]);
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                None,
                coder.falsifier(),
                "Residency rows cannot borrow another tier's codec lane.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::ResidencyCodecMismatch),
                "{} accepted nonprimary codec {:?}",
                tier.canonical_name(),
                coder
            );
            checked += 1;

            let borrowed_tier_budget = LatticeBudget::new(
                coder,
                coder.allows_rate_parameter().then_some(1250),
                tier.primary_side_information(),
                tier_probe_contributions(tier),
            );
            let borrowed_tier_entry = WboLedgerEntry::new_for_tier(
                tier,
                borrowed_tier_budget,
                None,
                tier.primary_falsifier(),
                "Residency rows cannot borrow a tier-owned witness for a nonprimary codec.",
            );

            assert_eq!(
                borrowed_tier_entry.validate(),
                Err(LatticeWboError::ResidencyCodecMismatch),
                "{} accepted nonprimary codec {:?} with tier-owned witnesses",
                tier.canonical_name(),
                coder
            );
            checked += 1;
        }
    }

    assert_eq!(
        checked,
        2 * ResidencyTier::ALL.len() * (LatticeCoderKind::ALL.len() - 1)
    );
}

#[test]
fn ledger_validation_rejects_standalone_codecs_for_every_residency_tier() {
    let mut checked = 0;
    for tier in ResidencyTier::ALL {
        for coder in LatticeCoderKind::ALL
            .into_iter()
            .filter(|coder| coder.primary_residency_tier().is_none())
        {
            let budget =
                side_information_probe_budget(coder, coder.canonical_side_information()[0]);
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                None,
                coder.falsifier(),
                "Standalone codec rows cannot promote into product residency lanes.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::ResidencyCodecMismatch),
                "{} accepted standalone codec {:?}",
                tier.canonical_name(),
                coder
            );
            checked += 1;
        }
    }

    assert_eq!(checked, ResidencyTier::ALL.len() * 6);
    let register = include_str!("../../../../docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md");
    assert!(
        register.contains("`ledger_validation_rejects_standalone_codecs_for_every_residency_tier`"),
        "register doc must cross-link standalone product-lane rejection"
    );
}

#[test]
fn residency_nonprimary_codec_rejection_matrix_counts_are_pinned() {
    let rows = ResidencyTier::ALL
        .iter()
        .map(|tier| {
            let rejected_codecs = LatticeCoderKind::ALL
                .iter()
                .filter(|coder| **coder != tier.primary_coder())
                .count();
            let tier_side_information_borrowers = LatticeCoderKind::ALL
                .iter()
                .filter(|coder| {
                    **coder != tier.primary_coder()
                        && coder
                            .canonical_side_information()
                            .contains(&tier.primary_side_information())
                })
                .count();
            (
                tier.canonical_name(),
                rejected_codecs,
                tier_side_information_borrowers,
            )
        })
        .collect::<Vec<_>>();

    assert_eq!(
        rows,
        vec![
            ("L0 RAM hot", 12, 0),
            ("L1 Compressed Residual", 12, 3),
            ("L2 Shadow Sketch", 12, 2),
            ("L3 SSD Oracle", 12, 1),
            ("L4 Engram", 12, 0),
            ("L5 Network Cascade", 12, 0),
            ("L_SE Self-Evolving", 12, 0),
        ]
    );
    let rejected = rows.iter().map(|(_, count, _)| count).sum::<usize>();
    assert_eq!(rejected, 84);
    assert_eq!(2 * rejected, 168);
    assert_eq!(
        rows.iter()
            .map(|(_, _, side_information_borrowers)| side_information_borrowers)
            .sum::<usize>(),
        6
    );
}

#[test]
fn ledger_validation_rejects_nonprimary_codec_before_foreign_terms() {
    let mut checked = 0;

    for tier in ResidencyTier::ALL {
        let coder = LatticeCoderKind::ALL
            .into_iter()
            .find(|coder| *coder != tier.primary_coder())
            .expect("each tier must have a nonprimary codec fixture");
        let foreign_term = WboTermCode::ALL
            .into_iter()
            .find(|term| !tier.canonical_register_terms().contains(term))
            .expect("each tier must have at least one foreign register term");
        let contribution = LatticeErrorContribution::new(
            foreign_term,
            format!("{} foreign {}", tier.canonical_name(), foreign_term.code()),
            0.01,
        )
        .expect("valid foreign residency contribution");
        let budget = LatticeBudget::new(
            coder,
            coder.allows_rate_parameter().then_some(1250),
            coder.canonical_side_information()[0],
            vec![contribution],
        );
        let entry = WboLedgerEntry::new_for_tier(
            tier,
            budget,
            None,
            coder.falsifier(),
            "Residency codec mismatch must win before term borrowing.",
        );

        assert!(
            entry
                .budget
                .contributions
                .iter()
                .any(|contribution| !tier.canonical_register_terms().contains(&contribution.term)),
            "{} fixture must carry a real residency-term mismatch",
            tier.canonical_name()
        );
        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::ResidencyCodecMismatch),
            "{} must reject nonprimary codec before foreign register terms",
            tier.canonical_name()
        );
        checked += 1;
    }

    assert_eq!(checked, ResidencyTier::ALL.len());
}

#[test]
fn ledger_validation_rejects_terms_outside_residency_tier_map() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::WeightRuntime, "Sherry weight lane", 0.01)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::ResidualStream,
        vec![contribution],
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L1CompressedResidual,
        budget,
        None,
        "F-WBO-DriftLedger",
        "L1 residual rows cannot hide a weight-runtime term.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::InvalidWboTermForResidencyTier)
    );
}

#[test]
fn ledger_validation_rejects_every_term_outside_residency_tier_map() {
    let mut checked = 0;
    let mut primary_codec_owned_but_tier_foreign = 0;
    for tier in ResidencyTier::ALL {
        for term in WboTermCode::ALL {
            if tier.canonical_register_terms().contains(&term) {
                continue;
            }
            if tier.primary_coder().canonical_wbo_terms().contains(&term) {
                primary_codec_owned_but_tier_foreign += 1;
            }

            let mut contributions = tier_probe_contributions(tier);
            contributions.push(
                LatticeErrorContribution::new(term, format!("foreign term {}", term.code()), 0.0)
                    .expect("foreign probe contribution should be valid"),
            );
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_coder().allows_rate_parameter().then_some(1250),
                tier.primary_side_information(),
                contributions,
            );
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                None,
                tier.primary_falsifier(),
                "Residency rows cannot borrow another tier's WBO term.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidWboTermForResidencyTier),
                "{} accepted foreign term {}",
                tier.canonical_name(),
                term.code()
            );
            checked += 1;
        }
    }

    let expected = ResidencyTier::ALL
        .iter()
        .map(|tier| {
            WboTermCode::ALL
                .iter()
                .filter(|term| !tier.canonical_register_terms().contains(term))
                .count()
        })
        .sum::<usize>();
    assert_eq!(checked, expected);
    assert!(
        primary_codec_owned_but_tier_foreign > 0,
        "term fixture must include terms owned by a primary codec but foreign to its residency tier"
    );
}

#[test]
fn residency_foreign_wbo_term_rejection_matrix_counts_are_pinned() {
    let rows = ResidencyTier::ALL
        .iter()
        .map(|tier| {
            let rejected = WboTermCode::ALL
                .iter()
                .filter(|term| !tier.canonical_register_terms().contains(term))
                .count();
            let codec_owned_foreign = WboTermCode::ALL
                .iter()
                .filter(|term| {
                    !tier.canonical_register_terms().contains(term)
                        && tier.primary_coder().canonical_wbo_terms().contains(term)
                })
                .count();
            (tier.canonical_name(), rejected, codec_owned_foreign)
        })
        .collect::<Vec<_>>();

    assert_eq!(
        rows,
        vec![
            ("L0 RAM hot", 6, 0),
            ("L1 Compressed Residual", 4, 2),
            ("L2 Shadow Sketch", 4, 0),
            ("L3 SSD Oracle", 3, 0),
            ("L4 Engram", 5, 0),
            ("L5 Network Cascade", 4, 0),
            ("L_SE Self-Evolving", 4, 0),
        ]
    );
    assert_eq!(
        rows.iter().map(|(_, rejected, _)| rejected).sum::<usize>(),
        30
    );
    assert_eq!(
        rows.iter()
            .map(|(_, _, codec_owned)| codec_owned)
            .sum::<usize>(),
        2
    );
}

#[test]
fn ledger_validation_rejects_missing_non_numerical_residency_terms() {
    let mut checked = 0;

    for tier in ResidencyTier::ALL {
        for omitted_term in tier.canonical_register_terms() {
            if *omitted_term == WboTermCode::NumericalPostCorrection
                || (tier.allows_active_support_budget()
                    && *omitted_term == WboTermCode::SubstrateBoundary)
            {
                continue;
            }

            let contributions = tier
                .canonical_register_terms()
                .iter()
                .filter(|term| *term != omitted_term)
                .map(|term| {
                    LatticeErrorContribution::new(
                        *term,
                        format!("{} sparse row kept {}", tier.canonical_name(), term.code()),
                        0.01,
                    )
                    .expect("sparse residency contribution should be valid")
                })
                .collect::<Vec<_>>();
            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_rate_milli_bits_per_symbol(),
                tier.primary_side_information(),
                contributions,
            );
            let active_support = tier.requires_active_support_budget().then(|| {
                ActiveSupportBudget::new(
                    2048,
                    32,
                    64 * 1024 * 1024,
                    SideInformationKind::ActiveSupport,
                )
            });
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                active_support,
                tier.primary_falsifier(),
                "Residency rows must not omit tier-owned WBO axes.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidWboTermForResidencyTier),
                "{} accepted sparse residency row missing {}",
                tier.canonical_name(),
                omitted_term.code()
            );
            checked += 1;
        }
    }

    assert_eq!(checked, 10);
}

#[test]
fn ledger_validation_rejects_foreign_terms_before_nonprimary_side_information() {
    let mut checked = 0;

    for tier in ResidencyTier::ALL {
        let foreign_term = WboTermCode::ALL
            .into_iter()
            .find(|term| !tier.canonical_register_terms().contains(term))
            .expect("each tier must have at least one foreign register term");
        let side_information = SideInformationKind::ALL
            .into_iter()
            .find(|side_information| *side_information != tier.primary_side_information())
            .expect("each tier must have a nonprimary side-information fixture");
        let mut contributions = tier_probe_contributions(tier);
        contributions.push(
            LatticeErrorContribution::new(
                foreign_term,
                format!("{} foreign {}", tier.canonical_name(), foreign_term.code()),
                0.01,
            )
            .expect("valid foreign residency contribution"),
        );
        let budget = LatticeBudget::new(
            tier.primary_coder(),
            tier.primary_coder().allows_rate_parameter().then_some(1250),
            side_information,
            contributions,
        );
        let entry = WboLedgerEntry::new_for_tier(
            tier,
            budget,
            None,
            tier.primary_falsifier(),
            "Residency term mismatch must win before side-information borrowing.",
        );

        assert_ne!(
            entry.budget.side_information,
            tier.primary_side_information(),
            "{} fixture must carry a real side-information mismatch",
            tier.canonical_name()
        );
        assert!(
            entry
                .budget
                .contributions
                .iter()
                .any(|contribution| !tier.canonical_register_terms().contains(&contribution.term)),
            "{} fixture must carry a real residency-term mismatch",
            tier.canonical_name()
        );
        assert_eq!(
            entry.validate(),
            Err(LatticeWboError::InvalidWboTermForResidencyTier),
            "{} must reject foreign register terms before nonprimary side information",
            tier.canonical_name()
        );
        checked += 1;
    }

    assert_eq!(checked, ResidencyTier::ALL.len());
}

#[test]
fn ledger_validation_rejects_side_information_outside_residency_primary() {
    let contribution =
        LatticeErrorContribution::new(WboTermCode::ResidualWynerZiv, "LWZ residual transfer", 0.01)
            .expect("valid contribution");
    let budget = LatticeBudget::new(
        LatticeCoderKind::LatticeWynerZivResidual,
        Some(1250),
        SideInformationKind::DecoderLmState,
        vec![contribution],
    );
    let entry = WboLedgerEntry::new_for_tier(
        ResidencyTier::L1CompressedResidual,
        budget,
        None,
        "F-WBO-DriftLedger",
        "L1 residual rows must use residual-stream primary side information.",
    );

    assert_eq!(
        entry.validate(),
        Err(LatticeWboError::InvalidSideInformation)
    );
}

#[test]
fn ledger_validation_rejects_every_nonprimary_side_information_for_every_residency_tier() {
    let mut checked = 0;
    let mut primary_codec_accepted_but_tier_nonprimary = 0;
    for tier in ResidencyTier::ALL {
        for side_information in SideInformationKind::ALL {
            if side_information == tier.primary_side_information() {
                continue;
            }
            if tier
                .primary_coder()
                .canonical_side_information()
                .contains(&side_information)
            {
                primary_codec_accepted_but_tier_nonprimary += 1;
            }

            let budget = LatticeBudget::new(
                tier.primary_coder(),
                tier.primary_coder().allows_rate_parameter().then_some(1250),
                side_information,
                tier_probe_contributions(tier),
            );
            let entry = WboLedgerEntry::new_for_tier(
                tier,
                budget,
                None,
                tier.primary_falsifier(),
                "Residency rows cannot borrow another tier's side information.",
            );

            assert_eq!(
                entry.validate(),
                Err(LatticeWboError::InvalidSideInformation),
                "{} accepted nonprimary side information {:?}",
                tier.canonical_name(),
                side_information
            );
            checked += 1;
        }
    }

    assert_eq!(
        checked,
        ResidencyTier::ALL.len() * (SideInformationKind::ALL.len() - 1)
    );
    assert!(
        primary_codec_accepted_but_tier_nonprimary > 0,
        "side-information fixture must include witnesses accepted by a primary codec but nonprimary for its residency tier"
    );
}

#[test]
fn residency_nonprimary_side_information_rejection_matrix_counts_are_pinned() {
    let rows = ResidencyTier::ALL
        .iter()
        .map(|tier| {
            let rejected = SideInformationKind::ALL
                .iter()
                .filter(|side_information| **side_information != tier.primary_side_information())
                .count();
            let codec_accepted_borrowed = SideInformationKind::ALL
                .iter()
                .filter(|side_information| {
                    **side_information != tier.primary_side_information()
                        && tier
                            .primary_coder()
                            .canonical_side_information()
                            .contains(side_information)
                })
                .count();
            (tier.canonical_name(), rejected, codec_accepted_borrowed)
        })
        .collect::<Vec<_>>();

    assert_eq!(
        rows,
        vec![
            ("L0 RAM hot", 9, 0),
            ("L1 Compressed Residual", 9, 3),
            ("L2 Shadow Sketch", 9, 2),
            ("L3 SSD Oracle", 9, 2),
            ("L4 Engram", 9, 0),
            ("L5 Network Cascade", 9, 0),
            ("L_SE Self-Evolving", 9, 0),
        ]
    );
    assert_eq!(
        rows.iter().map(|(_, rejected, _)| rejected).sum::<usize>(),
        63
    );
    assert_eq!(
        rows.iter()
            .map(|(_, _, codec_accepted)| codec_accepted)
            .sum::<usize>(),
        7
    );
}
