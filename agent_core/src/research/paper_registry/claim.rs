//! Source: see `super::` rustdoc. This module owns the claim struct +
//! registry + query surface.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum Venue {
    ArXiv,
    Iclr,
    NeurIps,
    MlSys,
    Icml,
    JournalArticle,
    AppleFramework,
    DoctrineDoc,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ClaimStatus {
    /// Substrate floor only — types + trait surface; no real
    /// kernels / training pipeline / model integration yet.
    SubstrateFloor,
    /// Kernels + tests landed; dispatch wire-in pending.
    SubstrateLanded,
    /// End-to-end wired + validated against the paper's threshold.
    Validated,
    /// Referenced for context only; not on the implementation path.
    Referenced,
    /// Deferred per HARDWARE-BUDGET (e.g. needs M2 Max 64 GB).
    Deferred,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PaperClaim {
    /// Stable identifier the rest of the registry uses internally.
    /// Format: lowercase-kebab-case, e.g. "bitnet-b158".
    pub key: String,
    pub title: String,
    pub venue: Venue,
    pub year: u16,
    /// arXiv ID (`YYMM.NNNNN` or `YYMM.NNNNNN`) when applicable;
    /// `None` for journal articles, Apple framework refs, doctrine
    /// docs.
    pub arxiv_id: Option<String>,
    /// One-line summary of the paper's load-bearing claim.
    pub claim: String,
    /// Path / module / kernel that realizes the claim.
    pub realized_at: String,
    pub status: ClaimStatus,
}

#[derive(Clone, Debug, PartialEq, Default, Serialize, Deserialize)]
pub struct PaperRegistry {
    pub claims: Vec<PaperClaim>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum RegistryError {
    /// `arxiv_id` did not match `YYMM.NNNNN` / `YYMM.NNNNNN` shape.
    InvalidArxivId { key: String, arxiv_id: String },
    /// Two claims shared the same `key`.
    DuplicateKey { key: String },
    /// `year` was outside `[1900, 2100]`.
    YearOutOfRange { key: String, year: u16 },
}

fn is_valid_arxiv(id: &str) -> bool {
    let bytes = id.as_bytes();
    if bytes.len() < 10 || bytes.len() > 11 {
        return false;
    }
    let dot_pos = match bytes.iter().position(|&b| b == b'.') {
        Some(p) => p,
        None => return false,
    };
    if dot_pos != 4 {
        return false;
    }
    let yymm = &bytes[..4];
    let nnnn = &bytes[5..];
    if !yymm.iter().all(|b| b.is_ascii_digit()) {
        return false;
    }
    if !nnnn.iter().all(|b| b.is_ascii_digit()) {
        return false;
    }
    if nnnn.len() != 5 && nnnn.len() != 6 {
        return false;
    }
    true
}

impl PaperRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add(&mut self, claim: PaperClaim) -> Result<(), RegistryError> {
        if let Some(ref id) = claim.arxiv_id {
            if !is_valid_arxiv(id) {
                return Err(RegistryError::InvalidArxivId {
                    key: claim.key,
                    arxiv_id: id.clone(),
                });
            }
        }
        if claim.year < 1900 || claim.year > 2100 {
            return Err(RegistryError::YearOutOfRange {
                key: claim.key,
                year: claim.year,
            });
        }
        if self.claims.iter().any(|c| c.key == claim.key) {
            return Err(RegistryError::DuplicateKey { key: claim.key });
        }
        self.claims.push(claim);
        Ok(())
    }

    pub fn len(&self) -> usize {
        self.claims.len()
    }

    pub fn is_empty(&self) -> bool {
        self.claims.is_empty()
    }

    pub fn by_key(&self, key: &str) -> Option<&PaperClaim> {
        self.claims.iter().find(|c| c.key == key)
    }

    pub fn filter_by_venue(&self, venue: Venue) -> Vec<&PaperClaim> {
        self.claims.iter().filter(|c| c.venue == venue).collect()
    }

    pub fn filter_by_status(&self, status: ClaimStatus) -> Vec<&PaperClaim> {
        self.claims.iter().filter(|c| c.status == status).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_claim() -> PaperClaim {
        PaperClaim {
            key: "bitnet-b158".into(),
            title: "The Era of 1-bit LLMs: All LLMs are in 1.58 Bits".into(),
            venue: Venue::ArXiv,
            year: 2024,
            arxiv_id: Some("2402.17764".into()),
            claim: "Ternary {−1, 0, +1} LLM weights match fp16 perplexity within 0.5 nats".into(),
            realized_at: "agent_core/src/research/ternary/".into(),
            status: ClaimStatus::SubstrateFloor,
        }
    }

    #[test]
    fn registry_new_is_empty() {
        let r = PaperRegistry::new();
        assert!(r.is_empty());
        assert_eq!(r.len(), 0);
    }

    #[test]
    fn add_one_claim_succeeds() {
        let mut r = PaperRegistry::new();
        r.add(sample_claim()).unwrap();
        assert_eq!(r.len(), 1);
    }

    #[test]
    fn duplicate_key_rejected() {
        let mut r = PaperRegistry::new();
        r.add(sample_claim()).unwrap();
        let err = r.add(sample_claim()).unwrap_err();
        assert_eq!(
            err,
            RegistryError::DuplicateKey { key: "bitnet-b158".to_string() }
        );
    }

    #[test]
    fn invalid_arxiv_id_rejected_no_dot() {
        let mut r = PaperRegistry::new();
        let mut c = sample_claim();
        c.arxiv_id = Some("240217764".into());
        let err = r.add(c).unwrap_err();
        assert!(matches!(err, RegistryError::InvalidArxivId { .. }));
    }

    #[test]
    fn invalid_arxiv_id_rejected_wrong_yymm() {
        let mut r = PaperRegistry::new();
        let mut c = sample_claim();
        c.arxiv_id = Some("240a.17764".into());
        let err = r.add(c).unwrap_err();
        assert!(matches!(err, RegistryError::InvalidArxivId { .. }));
    }

    #[test]
    fn arxiv_id_with_six_digit_suffix_accepted() {
        let mut r = PaperRegistry::new();
        let mut c = sample_claim();
        c.arxiv_id = Some("2402.177640".into());
        r.add(c).unwrap();
        assert_eq!(r.len(), 1);
    }

    #[test]
    fn missing_arxiv_id_ok_for_doctrine_doc_or_journal() {
        let mut r = PaperRegistry::new();
        let c = PaperClaim {
            key: "collier-1996".into(),
            title: "Pattern formation by lateral inhibition".into(),
            venue: Venue::JournalArticle,
            year: 1996,
            arxiv_id: None,
            claim: "Notch-Delta dynamics produce bimodal pattern".into(),
            realized_at: "agent_core/src/research/acs/notch_delta.rs".into(),
            status: ClaimStatus::SubstrateFloor,
        };
        r.add(c).unwrap();
        assert_eq!(r.len(), 1);
    }

    #[test]
    fn year_out_of_range_rejected() {
        let mut r = PaperRegistry::new();
        let mut c = sample_claim();
        c.year = 1500;
        let err = r.add(c).unwrap_err();
        assert!(matches!(err, RegistryError::YearOutOfRange { .. }));
    }

    #[test]
    fn by_key_finds_added_claim() {
        let mut r = PaperRegistry::new();
        r.add(sample_claim()).unwrap();
        let found = r.by_key("bitnet-b158").unwrap();
        assert_eq!(found.year, 2024);
    }

    #[test]
    fn by_key_returns_none_for_unknown() {
        let r = PaperRegistry::new();
        assert!(r.by_key("nonexistent").is_none());
    }

    #[test]
    fn filter_by_venue_returns_matching() {
        let mut r = PaperRegistry::new();
        r.add(sample_claim()).unwrap();
        let arxiv_only = r.filter_by_venue(Venue::ArXiv);
        assert_eq!(arxiv_only.len(), 1);
        let mlsys_only = r.filter_by_venue(Venue::MlSys);
        assert!(mlsys_only.is_empty());
    }

    #[test]
    fn filter_by_status_returns_matching() {
        let mut r = PaperRegistry::new();
        r.add(sample_claim()).unwrap();
        let floor = r.filter_by_status(ClaimStatus::SubstrateFloor);
        assert_eq!(floor.len(), 1);
        let validated = r.filter_by_status(ClaimStatus::Validated);
        assert!(validated.is_empty());
    }

    #[test]
    fn registry_roundtrips_through_serde_json() {
        let mut r = PaperRegistry::new();
        r.add(sample_claim()).unwrap();
        let json = serde_json::to_string(&r).unwrap();
        let back: PaperRegistry = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn arxiv_format_check_rejects_short_suffix() {
        let mut r = PaperRegistry::new();
        let mut c = sample_claim();
        c.arxiv_id = Some("2402.1776".into());
        let err = r.add(c).unwrap_err();
        assert!(matches!(err, RegistryError::InvalidArxivId { .. }));
    }
}
