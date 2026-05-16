//! Source:
//! - `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md`
//!   — "Honest boundaries: cannot see ANE SRAM / per-core /
//!   instruction trace / firmware". Telemetry path: IOKit/SMC via
//!   `macmon` / `asitop` channels (power, frequency, derived utilization).
//! - Apple `_ANEClient` private framework — binding requires the
//!   `com.apple.security.cs.disable-library-validation` entitlement
//!   (Pro/Developer-ID only; MAS builds cannot ship this).
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.1 J8 row.
//!
//! # Wave J8 — ANE Direct (substrate floor)
//!
//! The substrate floor owns the **types** + **trait surface** the
//! future `_ANEClient` binding will satisfy. The trait is implementable
//! today under `feature = "research"`; the real Pro-gated binding adds
//! a `pro-build` impl that links against the private framework.
//!
//! ## Honest boundaries (per the assessment doc)
//!
//! Things this substrate CANNOT expose, by hardware design:
//! - ANE SRAM contents.
//! - Per-core utilization or per-instruction trace.
//! - ANE firmware state.
//! - Per-op latency below the IOKit reporting cadence.
//!
//! What IS observable via IOKit / SMC:
//! - Aggregate power (watts) via SMC `PSTR` channel family.
//! - Clock frequency (Hz) via IOKit `AppleARMIODevice` properties.
//! - Derived utilization = power / max_power (rough; suitable for
//!   "ANE busy?" UI, not for performance attribution).
//!
//! Reproductions of `macmon` and `asitop`'s telemetry surface go
//! behind `pro-build` (subprocess + IOKit binding) — substrate floor
//! ships only the wire types so cross-process consumers can speak
//! the same vocabulary.

pub mod client;

pub use client::{
    AneCapabilities, AneClient, AneDirectError, AneStatus, AneTelemetry, MockAneClient,
};
