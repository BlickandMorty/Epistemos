//! Phase B.G.B1.a acceptance — UasAddress round-trip integration test.
//!
//! Per `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md` §2.1 iter 21.

use agent_core::uas::{UasAddress, UasKind};
use std::str::FromStr;

#[test]
fn uas_address_display_fromstr_round_trip() {
    let addr = UasAddress::new(UasKind::Placeholder, b"integration-display", 9999);
    let s = addr.to_string();
    let parsed = UasAddress::from_str(&s).expect("Display + FromStr must round-trip in integration test");
    assert_eq!(addr, parsed, "Display/FromStr must preserve equality");
}

#[test]
fn uas_address_serde_round_trip() {
    let addr = UasAddress::new(UasKind::Placeholder, b"integration-serde", 9999);
    let json = serde_json::to_string(&addr).expect("serde serialize must succeed in integration test");
    let parsed: UasAddress = serde_json::from_str(&json).expect("serde deserialize must succeed");
    assert_eq!(addr, parsed, "serde round-trip must preserve equality");
}

#[test]
fn distinct_content_distinct_address() {
    let a = UasAddress::new(UasKind::Placeholder, b"content-a", 42);
    let b = UasAddress::new(UasKind::Placeholder, b"content-b", 42);
    assert_ne!(a.hash, b.hash, "distinct content -> distinct BLAKE3 hash");
    assert_ne!(a, b, "distinct hash -> distinct UasAddress");
}

#[test]
fn identical_inputs_identical_address() {
    let a = UasAddress::new(UasKind::Placeholder, b"same-content", 42);
    let b = UasAddress::new(UasKind::Placeholder, b"same-content", 42);
    assert_eq!(a, b, "identical (kind, content, ts) -> identical address");
}
