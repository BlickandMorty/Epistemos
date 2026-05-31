//! Source guard for the active UAS namespace contract.
//!
//! UAS is now the Unified Address Space. Cold residency is ColdStore, while
//! AcsAnchor remains the anchored coordinate/provenance object.

const UAS_MOD_SOURCE: &str = include_str!("../src/uas/mod.rs");

#[test]
fn uas_module_header_uses_current_address_space_namespace() {
    assert!(
        UAS_MOD_SOURCE.contains("UAS - Unified Address Space"),
        "agent_core/src/uas/mod.rs must name UAS as Unified Address Space"
    );
    assert!(
        !UAS_MOD_SOURCE.contains("Unified Active Substrate"),
        "UAS must not regress to the obsolete Unified Active Substrate expansion"
    );
    assert!(
        UAS_MOD_SOURCE.contains("ColdStore"),
        "UAS docs should route cold residency through ColdStore"
    );
    assert!(
        UAS_MOD_SOURCE.contains("AcsAnchor"),
        "UAS docs should preserve AcsAnchor as anchored coordinate/provenance"
    );
}
