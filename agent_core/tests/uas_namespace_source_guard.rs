//! Source guard for the active UAS namespace contract.
//!
//! UAS is now the Unified Address Space. Cold residency is ColdStore, while
//! AcsAnchor remains the anchored coordinate/provenance object.

const UAS_MOD_SOURCE: &str = include_str!("../src/uas/mod.rs");
const AGENT_RUNTIME_V2_MOD_SOURCE: &str = include_str!("../src/agent_runtime_v2/mod.rs");
const MISSION_RUN_SOURCE: &str = include_str!("../src/agent_runtime_v2/mission_run.rs");

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

#[test]
fn agent_runtime_v2_header_uses_mas_pro_status_grammar() {
    assert!(
        AGENT_RUNTIME_V2_MOD_SOURCE.contains("## Build/status behaviour"),
        "System G docs should describe MAS/Pro build and ProStatus behaviour"
    );
    assert!(
        AGENT_RUNTIME_V2_MOD_SOURCE.contains("Pro Research status"),
        "System G docs should keep Research as a Pro status, not a separate build"
    );
    assert!(
        !AGENT_RUNTIME_V2_MOD_SOURCE.contains("## Tier behaviour"),
        "System G docs must not describe current build policy as tier behaviour"
    );
}

#[test]
fn mission_run_uses_scope_rex_admission_for_visible_denials() {
    assert!(
        MISSION_RUN_SOURCE.contains("requires SCOPE-Rex Admission"),
        "MissionRun raw tool-call denial must use SCOPE-Rex Admission wording"
    );
    assert!(
        !MISSION_RUN_SOURCE.contains("requires ACS admission"),
        "MissionRun must not expose stale ACS admission wording in visible denial strings"
    );
}
