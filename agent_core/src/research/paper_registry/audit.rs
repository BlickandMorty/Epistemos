//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 J9 row — "control room UI can render which papers does this
//!   substrate actually implement" + "§8 audit-of-audit verifies
//!   every cited paper still resolves".
//! - Companions: [`super::claim`] (PaperRegistry surface),
//!   [`super::seed`] (Wave-J registry seed).
//!
//! # Wave J9 — Paper-registry audit
//!
//! Walks a `PaperRegistry` and emits a structured `RegistryAuditReport`
//! covering the integrity properties the rest of the codebase cares
//! about:
//!
//! - `arxiv-or-doctrine` — every claim has an arXiv ID OR is tagged
//!   as a Venue that doesn't require one (`JournalArticle`,
//!   `AppleFramework`, `DoctrineDoc`).
//! - `realized-at` — every claim names a path / module / kernel; the
//!   audit can't verify the path *resolves* (filesystem walk lives
//!   one layer up) but it can verify the field is non-empty.
//! - `venue-coverage` — count claims per venue so the control room
//!   can show distribution.
//! - `status-coverage` — count claims per `ClaimStatus` so the
//!   control room can show "what fraction is Validated vs
//!   SubstrateFloor".
//!
//! The audit is read-only: it does not mutate the registry. Callers
//! get a `RegistryAuditReport` they can render / log / fail-build on.

use super::claim::{ClaimStatus, PaperRegistry, Venue};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RegistryAuditReport {
    pub total_claims: usize,
    pub claims_missing_identifier: Vec<String>,
    pub claims_missing_realized_at: Vec<String>,
    pub venue_counts: Vec<(Venue, usize)>,
    pub status_counts: Vec<(ClaimStatus, usize)>,
}

impl RegistryAuditReport {
    /// True iff every claim has either an arXiv ID or a Venue that
    /// doesn't require one, AND every claim has a non-empty
    /// `realized_at`.
    pub fn is_clean(&self) -> bool {
        self.claims_missing_identifier.is_empty()
            && self.claims_missing_realized_at.is_empty()
    }

    pub fn count_in_status(&self, status: ClaimStatus) -> usize {
        self.status_counts
            .iter()
            .find_map(|(s, n)| if *s == status { Some(*n) } else { None })
            .unwrap_or(0)
    }

    pub fn count_in_venue(&self, venue: Venue) -> usize {
        self.venue_counts
            .iter()
            .find_map(|(v, n)| if *v == venue { Some(*n) } else { None })
            .unwrap_or(0)
    }

    /// Complement to [`Self::is_clean`]. Cross-surface invariant:
    /// `is_clean XOR is_dirty` for every report.
    pub fn is_dirty(&self) -> bool {
        !self.is_clean()
    }

    /// Number of claims missing an arXiv ID when their venue requires
    /// one.
    pub fn missing_identifier_count(&self) -> usize {
        self.claims_missing_identifier.len()
    }

    /// Number of claims with an empty `realized_at`.
    pub fn missing_realized_count(&self) -> usize {
        self.claims_missing_realized_at.len()
    }

    /// Sum of all venue counts. Cross-surface invariant:
    /// `venue_count_total() == total_claims` (every claim contributes
    /// exactly once to some venue).
    pub fn venue_count_total(&self) -> usize {
        self.venue_counts.iter().map(|(_, n)| n).sum()
    }

    /// Sum of all status counts. Cross-surface invariant:
    /// `status_count_total() == total_claims`.
    pub fn status_count_total(&self) -> usize {
        self.status_counts.iter().map(|(_, n)| n).sum()
    }

    /// ClaimStatus with the highest count, or `None` for an empty
    /// registry. Ties broken by ClaimStatus's PartialOrd ordering
    /// (declaration order in the enum).
    pub fn most_common_status(&self) -> Option<ClaimStatus> {
        self.status_counts
            .iter()
            .max_by_key(|(_, n)| *n)
            .map(|(s, _)| *s)
    }
}

/// Predicate: this venue requires an arXiv ID per the audit rules.
/// Exposed as `pub` so callers can reproduce the audit's logic
/// without re-deriving the rule from the source. The audit's
/// `claims_missing_identifier` is computed using this predicate.
pub const fn venue_requires_identifier_pub(v: Venue) -> bool {
    !matches!(
        v,
        Venue::JournalArticle | Venue::AppleFramework | Venue::DoctrineDoc
    )
}

fn venue_requires_identifier(v: Venue) -> bool {
    !matches!(
        v,
        Venue::JournalArticle | Venue::AppleFramework | Venue::DoctrineDoc
    )
}

pub fn audit_registry(registry: &PaperRegistry) -> RegistryAuditReport {
    let mut missing_id = Vec::new();
    let mut missing_realized = Vec::new();
    let mut venue_map: Vec<(Venue, usize)> = Vec::new();
    let mut status_map: Vec<(ClaimStatus, usize)> = Vec::new();

    for c in &registry.claims {
        if c.arxiv_id.is_none() && venue_requires_identifier(c.venue) {
            missing_id.push(c.key.clone());
        }
        if c.realized_at.is_empty() {
            missing_realized.push(c.key.clone());
        }

        match venue_map.iter_mut().find(|(v, _)| *v == c.venue) {
            Some((_, n)) => *n += 1,
            None => venue_map.push((c.venue, 1)),
        }
        match status_map.iter_mut().find(|(s, _)| *s == c.status) {
            Some((_, n)) => *n += 1,
            None => status_map.push((c.status, 1)),
        }
    }

    venue_map.sort_by_key(|(v, _)| *v);
    status_map.sort_by_key(|(s, _)| *s);

    RegistryAuditReport {
        total_claims: registry.claims.len(),
        claims_missing_identifier: missing_id,
        claims_missing_realized_at: missing_realized,
        venue_counts: venue_map,
        status_counts: status_map,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::claim::PaperClaim;
    use super::super::seed::seed_wave_j_registry;

    fn arxiv_claim(key: &str) -> PaperClaim {
        PaperClaim {
            key: key.into(),
            title: format!("Sample claim {}", key),
            venue: Venue::ArXiv,
            year: 2024,
            arxiv_id: Some("2402.17764".into()),
            claim: "Test claim".into(),
            realized_at: "agent_core/src/research/test.rs".into(),
            status: ClaimStatus::SubstrateFloor,
        }
    }

    #[test]
    fn empty_registry_audit_is_clean() {
        let r = PaperRegistry::new();
        let rep = audit_registry(&r);
        assert_eq!(rep.total_claims, 0);
        assert!(rep.is_clean());
    }

    #[test]
    fn well_formed_arxiv_claim_passes_audit() {
        let mut r = PaperRegistry::new();
        r.add(arxiv_claim("test-1")).unwrap();
        let rep = audit_registry(&r);
        assert!(rep.is_clean());
        assert_eq!(rep.total_claims, 1);
    }

    #[test]
    fn arxiv_venue_without_id_is_flagged() {
        let mut r = PaperRegistry::new();
        let mut c = arxiv_claim("missing-id");
        c.arxiv_id = None;
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert!(!rep.is_clean());
        assert_eq!(rep.claims_missing_identifier, vec!["missing-id".to_string()]);
    }

    #[test]
    fn journal_article_without_id_is_not_flagged() {
        let mut r = PaperRegistry::new();
        let c = PaperClaim {
            key: "collier-1996".into(),
            title: "Pattern formation".into(),
            venue: Venue::JournalArticle,
            year: 1996,
            arxiv_id: None,
            claim: "Notch-Delta bimodal pattern".into(),
            realized_at: "agent_core/src/research/acs/notch_delta.rs".into(),
            status: ClaimStatus::SubstrateFloor,
        };
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert!(rep.is_clean());
    }

    #[test]
    fn apple_framework_without_id_is_not_flagged() {
        let mut r = PaperRegistry::new();
        let c = PaperClaim {
            key: "ane-client".into(),
            title: "_ANEClient private framework".into(),
            venue: Venue::AppleFramework,
            year: 2024,
            arxiv_id: None,
            claim: "Pro-tier ANE direct binding".into(),
            realized_at: "agent_core/src/research/ane_direct/".into(),
            status: ClaimStatus::Deferred,
        };
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert!(rep.is_clean());
    }

    #[test]
    fn doctrine_doc_without_id_is_not_flagged() {
        let mut r = PaperRegistry::new();
        let c = PaperClaim {
            key: "master-fusion".into(),
            title: "MASTER_FUSION_NO_COMPROMISE doctrine".into(),
            venue: Venue::DoctrineDoc,
            year: 2026,
            arxiv_id: None,
            claim: "Doctrine consolidates research strands".into(),
            realized_at: "docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md".into(),
            status: ClaimStatus::Referenced,
        };
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert!(rep.is_clean());
    }

    #[test]
    fn empty_realized_at_flagged() {
        let mut r = PaperRegistry::new();
        let mut c = arxiv_claim("test-2");
        c.realized_at = String::new();
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert!(!rep.is_clean());
        assert_eq!(rep.claims_missing_realized_at, vec!["test-2".to_string()]);
    }

    #[test]
    fn venue_counts_distribute_correctly() {
        let mut r = PaperRegistry::new();
        r.add(arxiv_claim("a-1")).unwrap();
        r.add(arxiv_claim("a-2")).unwrap();
        let mut c = arxiv_claim("j-1");
        c.venue = Venue::JournalArticle;
        c.arxiv_id = None;
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert_eq!(rep.count_in_venue(Venue::ArXiv), 2);
        assert_eq!(rep.count_in_venue(Venue::JournalArticle), 1);
        assert_eq!(rep.count_in_venue(Venue::MlSys), 0);
    }

    #[test]
    fn status_counts_distribute_correctly() {
        let mut r = PaperRegistry::new();
        r.add(arxiv_claim("a-1")).unwrap();
        let mut c = arxiv_claim("a-2");
        c.status = ClaimStatus::Validated;
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert_eq!(rep.count_in_status(ClaimStatus::SubstrateFloor), 1);
        assert_eq!(rep.count_in_status(ClaimStatus::Validated), 1);
        assert_eq!(rep.count_in_status(ClaimStatus::Deferred), 0);
    }

    #[test]
    fn seeded_wave_j_registry_passes_audit() {
        // The substrate-floor seeded registry should itself be clean —
        // this is the smoke test that catches any future seed-entry
        // that forgets a realized_at or an arxiv_id.
        let r = seed_wave_j_registry().unwrap();
        let rep = audit_registry(&r);
        assert!(
            rep.is_clean(),
            "seeded Wave-J registry audit failed: missing_id={:?}, missing_realized={:?}",
            rep.claims_missing_identifier,
            rep.claims_missing_realized_at
        );
        assert!(rep.total_claims > 0);
    }

    #[test]
    fn report_roundtrips_through_serde_json() {
        let r = seed_wave_j_registry().unwrap();
        let rep = audit_registry(&r);
        let json = serde_json::to_string(&rep).unwrap();
        let back: RegistryAuditReport = serde_json::from_str(&json).unwrap();
        assert_eq!(rep, back);
    }

    #[test]
    fn venue_counts_sorted_stable() {
        let mut r = PaperRegistry::new();
        let mut c1 = arxiv_claim("a");
        c1.venue = Venue::MlSys;
        r.add(c1).unwrap();
        let mut c2 = arxiv_claim("b");
        c2.venue = Venue::ArXiv;
        r.add(c2).unwrap();
        let rep1 = audit_registry(&r);
        let rep2 = audit_registry(&r);
        assert_eq!(rep1.venue_counts, rep2.venue_counts);
    }

    // ── diagnostic surface (iter 185) ────────────────────────────────────────

    #[test]
    fn is_dirty_complement_of_is_clean() {
        // Cross-surface invariant: is_clean XOR is_dirty.
        let r = PaperRegistry::new();
        let rep = audit_registry(&r);
        assert_ne!(rep.is_clean(), rep.is_dirty());

        let mut r = PaperRegistry::new();
        let mut c = arxiv_claim("test");
        c.arxiv_id = None;
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert!(rep.is_dirty());
        assert_ne!(rep.is_clean(), rep.is_dirty());
    }

    #[test]
    fn missing_counts_match_vec_lengths() {
        let mut r = PaperRegistry::new();
        let mut c = arxiv_claim("k1");
        c.arxiv_id = None;
        r.add(c).unwrap();
        let mut c = arxiv_claim("k2");
        c.realized_at = String::new();
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert_eq!(rep.missing_identifier_count(), rep.claims_missing_identifier.len());
        assert_eq!(rep.missing_realized_count(), rep.claims_missing_realized_at.len());
        assert_eq!(rep.missing_identifier_count(), 1);
        assert_eq!(rep.missing_realized_count(), 1);
    }

    #[test]
    fn venue_count_total_equals_total_claims() {
        // Cross-surface invariant.
        let mut r = PaperRegistry::new();
        r.add(arxiv_claim("a")).unwrap();
        r.add(arxiv_claim("b")).unwrap();
        let mut c = arxiv_claim("c");
        c.venue = Venue::JournalArticle;
        c.arxiv_id = None;
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert_eq!(rep.venue_count_total(), rep.total_claims);
        assert_eq!(rep.venue_count_total(), 3);
    }

    #[test]
    fn status_count_total_equals_total_claims() {
        // Cross-surface invariant.
        let mut r = PaperRegistry::new();
        r.add(arxiv_claim("a")).unwrap();
        let mut c = arxiv_claim("b");
        c.status = ClaimStatus::Validated;
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert_eq!(rep.status_count_total(), rep.total_claims);
        assert_eq!(rep.status_count_total(), 2);
    }

    #[test]
    fn most_common_status_none_on_empty() {
        let r = PaperRegistry::new();
        let rep = audit_registry(&r);
        assert_eq!(rep.most_common_status(), None);
    }

    #[test]
    fn most_common_status_picks_majority() {
        let mut r = PaperRegistry::new();
        r.add(arxiv_claim("a")).unwrap(); // SubstrateFloor
        r.add(arxiv_claim("b")).unwrap(); // SubstrateFloor
        let mut c = arxiv_claim("c");
        c.status = ClaimStatus::Validated;
        r.add(c).unwrap();
        let rep = audit_registry(&r);
        assert_eq!(rep.most_common_status(), Some(ClaimStatus::SubstrateFloor));
    }

    #[test]
    fn venue_requires_identifier_pub_matches_audit_logic() {
        // Cross-surface invariant: the pub predicate's verdict agrees
        // with whether the audit flags a venue's missing arxiv_id.
        for v in Venue::ALL.iter().copied() {
            let mut r = PaperRegistry::new();
            let c = PaperClaim {
                key: format!("k-{}", v.code()),
                title: "test".into(),
                venue: v,
                year: 2024,
                arxiv_id: None,
                claim: "test".into(),
                realized_at: "agent_core/src/research/test.rs".into(),
                status: ClaimStatus::SubstrateFloor,
            };
            r.add(c).unwrap();
            let rep = audit_registry(&r);
            let flagged = !rep.claims_missing_identifier.is_empty();
            assert_eq!(flagged, venue_requires_identifier_pub(v), "venue={:?}", v);
        }
    }

    #[test]
    fn seeded_registry_venue_status_totals_match_total() {
        // Cross-surface invariant: even on the real seeded registry,
        // the totals match.
        let r = seed_wave_j_registry().unwrap();
        let rep = audit_registry(&r);
        assert_eq!(rep.venue_count_total(), rep.total_claims);
        assert_eq!(rep.status_count_total(), rep.total_claims);
    }
}
