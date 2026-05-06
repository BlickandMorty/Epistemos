//! HELIOS V5 W8 — KV-cache Tier-1 gate module.
//!
//! Hosts the Tier-1 KV-Direct gate that bypasses paged-attention
//! quantization when bit-equivalent. Pro-tier KV optimizations
//! (HCache / KVCrush) live in the `epistemos-vault` crate per
//! `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W22.

pub mod direct_gate;
