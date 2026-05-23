//! Integration smoke test for the Wiring #1 (T10 Eidos → QueryRuntime)
//! FFI entry point `bridge::eidos_search_lexical_json`.
//!
//! Lives in `tests/` (separate test binary) so the broken pre-existing
//! lib-test compilation in `cache/`, `tools_v2/`, `skill_discovery/`
//! (unrelated to this wiring) does not block verification of the bridge
//! function. The lib (cargo check --lib) compiles cleanly; only the
//! lib-internal test build is broken on origin/main.

use agent_core::bridge::eidos_search_lexical_json;
use agent_core::eidos::EidosContextPacket;

#[test]
fn eidos_search_lexical_json_returns_citation_bearing_packet_for_seeded_query() {
    let raw = eidos_search_lexical_json("welcome".to_string(), 5)
        .expect("eidos_search_lexical_json should not error on a seeded query");
    let packet: EidosContextPacket =
        serde_json::from_str(&raw).expect("packet JSON should decode against the Eidos mirror");

    assert_eq!(
        packet.manifest_id.as_str(),
        "eidos-fixture-2026-05-23",
        "packet manifest must match the fixture index manifest"
    );
    assert!(
        !packet.hits.is_empty(),
        "seeded query 'welcome' should produce at least one hit (got 0)"
    );
    let welcome_hit = packet
        .hits
        .iter()
        .find(|h| h.source_id.as_str() == "eidos-fixture-welcome::lex")
        .expect("welcome fixture document should appear in hits");
    assert_eq!(welcome_hit.provenance.manifest_id, packet.manifest_id);
}

#[test]
fn eidos_search_lexical_json_returns_empty_hits_for_unmatched_query() {
    let raw = eidos_search_lexical_json("zzzzz_unmatchable_zzzzz".to_string(), 5)
        .expect("eidos_search_lexical_json should succeed even with no matches");
    let packet: EidosContextPacket =
        serde_json::from_str(&raw).expect("packet JSON should decode");
    assert!(
        packet.hits.is_empty(),
        "unmatched query should produce zero hits, got {}",
        packet.hits.len()
    );
}

#[test]
fn eidos_search_lexical_json_hit_source_id_validates_under_closed_citation_contract() {
    let raw = eidos_search_lexical_json("eidos".to_string(), 3)
        .expect("seeded fixture corpus matches 'eidos'");
    let packet: EidosContextPacket =
        serde_json::from_str(&raw).expect("packet decodes");
    assert!(!packet.hits.is_empty(), "expected at least one hit");

    // Each emitted hit's source_id must validate as a legitimate citation
    // against the packet that produced it — the Wiring #1 closed-citation
    // floor.
    for hit in &packet.hits {
        let citation = agent_core::eidos::EidosCitation {
            source_id: hit.source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(
            packet.validate_citation(&citation).is_ok(),
            "hit source_id {} should validate under closed-citation contract",
            hit.source_id.as_str()
        );
    }
}
