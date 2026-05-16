//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.8 — Run Ledger per-token attestation. Distinct from
//!   the 4 existing provenance primitives (ClaimLedger / ReplayBundle /
//!   AgentEvent ring / typed Merkle DAG). Doctrine row frozen;
//!   substrate floor here.
//! - Companion to [`crate::provenance`] — that owns the claim-level
//!   ledger; this module owns the token-level chain.
//!
//! # Wave J B.6.8 — Run Ledger substrate
//!
//! Per-token attestation chain. Each generated token gets a ledger
//! entry that hashes:
//! - the previous entry's hash (chain link),
//! - the token id + position,
//! - the model + provider identity at the time of generation.
//!
//! Verifying the chain re-derives each hash and checks that every
//! entry's recorded hash matches.
//!
//! Substrate floor uses the std-lib `DefaultHasher` (a SipHash-1-3
//! variant) — not cryptographic, but enough to detect non-malicious
//! corruption + structural chain breaks. Production replaces with
//! BLAKE3 (already used by ReplayBundle in `crate::provenance::replay`).

use serde::{Deserialize, Serialize};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RunLedgerEntry {
    pub token_id: u32,
    pub position: u64,
    pub provider_id: String,
    pub model_hash: u64,
    pub prev_hash: u64,
    pub this_hash: u64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum RunLedgerError {
    EmptyChain,
    ChainBreak { index: usize, expected: u64, actual: u64 },
    PrevHashMismatch { index: usize, expected: u64, actual: u64 },
}

pub fn hash_entry(
    prev_hash: u64,
    token_id: u32,
    position: u64,
    provider_id: &str,
    model_hash: u64,
) -> u64 {
    let mut h = DefaultHasher::new();
    prev_hash.hash(&mut h);
    token_id.hash(&mut h);
    position.hash(&mut h);
    provider_id.hash(&mut h);
    model_hash.hash(&mut h);
    h.finish()
}

#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct RunLedger {
    pub entries: Vec<RunLedgerEntry>,
}

impl RunLedger {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    pub fn tail_hash(&self) -> u64 {
        self.entries.last().map(|e| e.this_hash).unwrap_or(0)
    }

    /// Append a new token attestation, chaining from the previous
    /// entry's hash. Returns the new entry's hash.
    pub fn append(
        &mut self,
        token_id: u32,
        position: u64,
        provider_id: &str,
        model_hash: u64,
    ) -> u64 {
        let prev = self.tail_hash();
        let h = hash_entry(prev, token_id, position, provider_id, model_hash);
        self.entries.push(RunLedgerEntry {
            token_id,
            position,
            provider_id: provider_id.to_string(),
            model_hash,
            prev_hash: prev,
            this_hash: h,
        });
        h
    }

    /// Verify every entry's hash matches the recomputed value and that
    /// each entry's `prev_hash` matches the prior entry's `this_hash`.
    pub fn verify(&self) -> Result<(), RunLedgerError> {
        if self.entries.is_empty() {
            return Err(RunLedgerError::EmptyChain);
        }
        let mut prev_expected: u64 = 0;
        for (i, e) in self.entries.iter().enumerate() {
            if e.prev_hash != prev_expected {
                return Err(RunLedgerError::PrevHashMismatch {
                    index: i,
                    expected: prev_expected,
                    actual: e.prev_hash,
                });
            }
            let recomputed = hash_entry(
                e.prev_hash,
                e.token_id,
                e.position,
                &e.provider_id,
                e.model_hash,
            );
            if recomputed != e.this_hash {
                return Err(RunLedgerError::ChainBreak {
                    index: i,
                    expected: recomputed,
                    actual: e.this_hash,
                });
            }
            prev_expected = e.this_hash;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_ledger_has_zero_tail_hash() {
        let l = RunLedger::new();
        assert_eq!(l.tail_hash(), 0);
        assert!(l.is_empty());
    }

    #[test]
    fn append_increments_length() {
        let mut l = RunLedger::new();
        l.append(42, 0, "claude", 0xdeadbeef);
        assert_eq!(l.len(), 1);
    }

    #[test]
    fn second_append_chains_from_first() {
        let mut l = RunLedger::new();
        l.append(1, 0, "claude", 0xaaaa);
        let h0 = l.tail_hash();
        l.append(2, 1, "claude", 0xaaaa);
        assert_eq!(l.entries[1].prev_hash, h0);
    }

    #[test]
    fn verify_empty_ledger_errors() {
        let l = RunLedger::new();
        let err = l.verify().unwrap_err();
        assert_eq!(err, RunLedgerError::EmptyChain);
    }

    #[test]
    fn verify_clean_chain_passes() {
        let mut l = RunLedger::new();
        for i in 0..10 {
            l.append(i as u32, i, "claude", 0xbeef);
        }
        assert!(l.verify().is_ok());
    }

    #[test]
    fn verify_detects_token_id_tampering() {
        let mut l = RunLedger::new();
        for i in 0..3 {
            l.append(i as u32, i, "claude", 0xbeef);
        }
        l.entries[1].token_id = 999;
        let err = l.verify().unwrap_err();
        assert!(matches!(err, RunLedgerError::ChainBreak { index: 1, .. }));
    }

    #[test]
    fn verify_detects_provider_tampering() {
        let mut l = RunLedger::new();
        for i in 0..3 {
            l.append(i as u32, i, "claude", 0xbeef);
        }
        l.entries[2].provider_id = "openai".to_string();
        let err = l.verify().unwrap_err();
        assert!(matches!(err, RunLedgerError::ChainBreak { index: 2, .. }));
    }

    #[test]
    fn verify_detects_broken_prev_hash_link() {
        let mut l = RunLedger::new();
        l.append(1, 0, "claude", 0xbeef);
        l.append(2, 1, "claude", 0xbeef);
        l.entries[1].prev_hash = 12345;
        let err = l.verify().unwrap_err();
        assert!(matches!(err, RunLedgerError::PrevHashMismatch { index: 1, .. }));
    }

    #[test]
    fn hash_entry_is_deterministic() {
        let h1 = hash_entry(0, 42, 0, "claude", 0xbeef);
        let h2 = hash_entry(0, 42, 0, "claude", 0xbeef);
        assert_eq!(h1, h2);
    }

    #[test]
    fn hash_entry_distinguishes_token_id() {
        let h1 = hash_entry(0, 1, 0, "claude", 0xbeef);
        let h2 = hash_entry(0, 2, 0, "claude", 0xbeef);
        assert_ne!(h1, h2);
    }

    #[test]
    fn hash_entry_distinguishes_provider() {
        let h1 = hash_entry(0, 1, 0, "claude", 0xbeef);
        let h2 = hash_entry(0, 1, 0, "openai", 0xbeef);
        assert_ne!(h1, h2);
    }

    #[test]
    fn ledger_roundtrips_through_serde_json() {
        let mut l = RunLedger::new();
        l.append(1, 0, "claude", 0xaaaa);
        l.append(2, 1, "claude", 0xaaaa);
        let json = serde_json::to_string(&l).unwrap();
        let back: RunLedger = serde_json::from_str(&json).unwrap();
        assert_eq!(l, back);
        assert!(back.verify().is_ok());
    }

    #[test]
    fn append_returns_this_hash() {
        let mut l = RunLedger::new();
        let h = l.append(42, 0, "claude", 0xbeef);
        assert_eq!(l.entries[0].this_hash, h);
    }

    #[test]
    fn long_chain_verify_passes() {
        let mut l = RunLedger::new();
        for i in 0..1000 {
            l.append(i as u32, i, "claude", 0xbeef);
        }
        assert!(l.verify().is_ok());
    }
}
