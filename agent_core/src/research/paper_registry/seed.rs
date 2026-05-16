//! Source: This module hand-curates the J1-J8 citations into a
//! single [`PaperRegistry`]. The keys match the `//! Source:` comments
//! across the sibling modules; future iters extend this list as new
//! claims land. Acts as the programmatic counterpart to
//! `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`.

use super::claim::{ClaimStatus, PaperClaim, PaperRegistry, RegistryError, Venue};

/// Seed the registry with every paper cited across Wave J substrate.
/// Returns the populated registry on success; aborts on the first
/// per-claim validation failure so a malformed entry can be fixed
/// at compile time.
pub fn seed_wave_j_registry() -> Result<PaperRegistry, RegistryError> {
    let mut r = PaperRegistry::new();

    r.add(PaperClaim {
        key: "bitnet-b158".into(),
        title: "The Era of 1-bit LLMs: All Large Language Models are in 1.58 Bits".into(),
        venue: Venue::ArXiv,
        year: 2024,
        arxiv_id: Some("2402.17764".into()),
        claim: "Ternary {−1, 0, +1} weights with absmean per-group scale match fp16 perplexity".into(),
        realized_at: "agent_core/src/research/ternary/".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "t-mac".into(),
        title: "T-MAC: CPU Renaissance via Table Lookup for Low-Bit LLM Deployment".into(),
        venue: Venue::ArXiv,
        year: 2024,
        arxiv_id: Some("2407.00088".into()),
        claim: "LUT-centric ternary GEMM achieves 30-71 tok/s on BitNet-b1.58-3B on M2 Ultra".into(),
        realized_at: "Epistemos/Shaders/tmac_lut.metal (W12)".into(),
        status: ClaimStatus::Referenced,
    })?;

    r.add(PaperClaim {
        key: "kirkpatrick-ewc".into(),
        title: "Overcoming catastrophic forgetting in neural networks".into(),
        venue: Venue::ArXiv,
        year: 2016,
        arxiv_id: Some("1612.00796".into()),
        claim: "Fisher-weighted quadratic penalty anchors important parameters across tasks".into(),
        realized_at: "agent_core/src/research/continual_learning/ewc.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "qiu-oftv2".into(),
        title: "Orthogonal Finetuning Made Scalable".into(),
        venue: Venue::ArXiv,
        year: 2025,
        arxiv_id: Some("2506.19847".into()),
        claim: "Input-centric R·(Wx) avoids materializing R·W; 10× faster, 3× lower GPU memory".into(),
        realized_at: "agent_core/src/research/continual_learning/oftv2.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "wang-dsc".into(),
        title: "Dynamic Orthogonal Continual Fine-tuning for Mitigating Catastrophic Forgettings".into(),
        venue: Venue::ArXiv,
        year: 2025,
        arxiv_id: Some("2509.23893".into()),
        claim: "Online PCA tracking reduces forgetting by ~40% vs fixed-direction methods over 100+ conversations".into(),
        realized_at: "agent_core/src/research/continual_learning/dsc.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "behrouz-titans".into(),
        title: "Titans: Learning to Memorize at Test Time".into(),
        venue: Venue::ArXiv,
        year: 2025,
        arxiv_id: Some("2501.00663".into()),
        claim: "Surprise-gradient-driven inner-loop update to a learned memory module; streaming DMD interpretation".into(),
        realized_at: "agent_core/src/research/continual_learning/titans_mac.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "zweiger-seal".into(),
        title: "Self-Edited Active Learning (SEAL)".into(),
        venue: Venue::ArXiv,
        year: 2026,
        arxiv_id: Some("2506.10943".into()),
        claim: "Outer-RL nightly self-edits compiled into per-user adapter; pairs with DoRA".into(),
        realized_at: "agent_core/src/research/continual_learning/seal_dora.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "liu-dora".into(),
        title: "DoRA: Weight-Decomposed Low-Rank Adaptation".into(),
        venue: Venue::Icml,
        year: 2024,
        arxiv_id: Some("2402.09353".into()),
        claim: "Magnitude + normalized direction decomposition; LoRA delta on direction only".into(),
        realized_at: "agent_core/src/research/continual_learning/seal_dora.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "kuramoto-1975".into(),
        title: "Self-entrainment of a population of coupled non-linear oscillators".into(),
        venue: Venue::JournalArticle,
        year: 1975,
        arxiv_id: None,
        claim: "Mean-field coupling synchronizes oscillators when K > K_c = 2/(π·g(0))".into(),
        realized_at: "agent_core/src/research/acs/kuramoto.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "collier-1996".into(),
        title: "Pattern formation by lateral inhibition with feedback".into(),
        venue: Venue::JournalArticle,
        year: 1996,
        arxiv_id: None,
        claim: "Notch-Delta Hill-up/Hill-down dynamics produce bimodal pattern from homogeneous initial conditions".into(),
        realized_at: "agent_core/src/research/acs/notch_delta.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "tarjan-1972".into(),
        title: "Depth-first search and linear graph algorithms".into(),
        venue: Venue::JournalArticle,
        year: 1972,
        arxiv_id: None,
        claim: "Strongly-connected components in O(V+E)".into(),
        realized_at: "agent_core/src/research/acs/autopoiesis.rs".into(),
        status: ClaimStatus::Referenced,
    })?;

    r.add(PaperClaim {
        key: "beer-vsm".into(),
        title: "Brain of the Firm".into(),
        venue: Venue::JournalArticle,
        year: 1972,
        arxiv_id: None,
        claim: "Viable Systems Model: S1 ops · S2 coord · S3 control · S4 intel · S5 policy".into(),
        realized_at: "agent_core/src/research/acs/vsm.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "huang-sherry".into(),
        title: "Sherry: Hardware-Efficient 1.25-Bit Ternary Quantization".into(),
        venue: Venue::ArXiv,
        year: 2026,
        arxiv_id: Some("2601.07892".into()),
        claim: "3:4 sparse ternary pattern: 1 zero + 3 ternary values per 4-weight group; ≈1.19 bits/weight".into(),
        realized_at: "agent_core/src/research/sherry_lattice/sparse_ternary.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "conway-sloane-1988".into(),
        title: "Sphere Packings, Lattices and Groups".into(),
        venue: Venue::JournalArticle,
        year: 1988,
        arxiv_id: None,
        claim: "E8 = D8 ∪ (D8 + (½)^8) nearest-point algorithm (Ch. 20 Alg. 5)".into(),
        realized_at: "agent_core/src/research/sherry_lattice/e8.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "ane-client".into(),
        title: "Apple _ANEClient private framework".into(),
        venue: Venue::AppleFramework,
        year: 2023,
        arxiv_id: None,
        claim: "Direct ANE access via cs.disable-library-validation entitlement; no SRAM visibility, IOKit-only telemetry".into(),
        realized_at: "agent_core/src/research/ane_direct/".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    r.add(PaperClaim {
        key: "hanley-mcneil-1982".into(),
        title: "The Meaning and Use of the Area under a ROC Curve".into(),
        venue: Venue::JournalArticle,
        year: 1982,
        arxiv_id: None,
        claim: "AUC = (S_pos - n_pos*(n_pos+1)/2) / (n_pos * n_neg) via Mann-Whitney rank sum".into(),
        realized_at: "agent_core/src/research/cognition_observatory/sae.rs".into(),
        status: ClaimStatus::SubstrateFloor,
    })?;

    Ok(r)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn seed_succeeds() {
        let r = seed_wave_j_registry().unwrap();
        assert!(r.len() >= 15);
    }

    #[test]
    fn seed_contains_bitnet() {
        let r = seed_wave_j_registry().unwrap();
        let c = r.by_key("bitnet-b158").unwrap();
        assert_eq!(c.year, 2024);
        assert_eq!(c.arxiv_id.as_deref(), Some("2402.17764"));
    }

    #[test]
    fn seed_contains_classical_papers_without_arxiv() {
        let r = seed_wave_j_registry().unwrap();
        let classical = r.filter_by_venue(Venue::JournalArticle);
        assert!(!classical.is_empty());
        assert!(classical.iter().all(|c| c.arxiv_id.is_none()));
    }

    #[test]
    fn seed_has_at_least_three_substrate_floor_claims() {
        let r = seed_wave_j_registry().unwrap();
        let floor = r.filter_by_status(ClaimStatus::SubstrateFloor);
        assert!(floor.len() >= 3);
    }

    #[test]
    fn every_seeded_arxiv_id_is_valid_format() {
        let r = seed_wave_j_registry().unwrap();
        for c in &r.claims {
            if let Some(id) = &c.arxiv_id {
                let bytes = id.as_bytes();
                assert!(bytes.len() == 10 || bytes.len() == 11,
                    "claim {} has odd-length arxiv id {}", c.key, id);
                assert_eq!(bytes[4], b'.', "claim {} arxiv id {} missing dot at pos 4", c.key, id);
            }
        }
    }

    #[test]
    fn realized_at_paths_all_under_research_or_shaders() {
        let r = seed_wave_j_registry().unwrap();
        for c in &r.claims {
            let p = &c.realized_at;
            assert!(
                p.starts_with("agent_core/src/research/")
                    || p.starts_with("Epistemos/Shaders/"),
                "claim {} realized_at outside Terminal-B scope: {}",
                c.key,
                p
            );
        }
    }

    #[test]
    fn every_claim_has_a_title() {
        let r = seed_wave_j_registry().unwrap();
        for c in &r.claims {
            assert!(!c.title.is_empty(), "claim {} missing title", c.key);
        }
    }

    #[test]
    fn no_duplicate_keys_in_seed() {
        let _r = seed_wave_j_registry().unwrap();
    }
}
