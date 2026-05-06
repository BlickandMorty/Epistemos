//! HELIOS V5 retrieval substrate (chat-boundary retrieval surface).
//!
//! Hosts the Tier-2 retrieval primitives gated behind the
//! "Verified Research Mode" Settings toggle (W9). The Modern
//! Hopfield retrieval (W15) is the first substrate; future slices
//! add additional retrieval families under the same VRM toggle.

pub mod hopfield;
