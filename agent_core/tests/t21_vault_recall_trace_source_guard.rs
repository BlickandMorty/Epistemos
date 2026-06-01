//! Source guard for the T21 VaultRecall/PageGather trace contract.
//!
//! Rust already emits packetized PageGather caller fields on the retrieval
//! trace. The Swift mirror must keep those fields typed so product surfaces can
//! distinguish packet consumption from dense PageGather performance claims.

const RUST_RETRIEVAL_TRACE_SOURCE: &str = include_str!("../src/storage/retrieval_trace.rs");
const SWIFT_QUERY_RUNTIME_SOURCE: &str = include_str!("../../Epistemos/Engine/QueryRuntime.swift");
const SWIFT_EIDOS_WIRING_SOURCE: &str =
    include_str!("../../Epistemos/Eidos/EidosWiring.swift");
const SWIFT_EIDOS_WIRING_TEST_SOURCE: &str =
    include_str!("../../EpistemosTests/EidosWiringTests.swift");
const SWIFT_VAULT_RECALL_WIRING_SOURCE: &str =
    include_str!("../../Epistemos/VaultRecall/VaultRecallWiring.swift");
const SWIFT_VAULT_RECALL_TEST_SOURCE: &str =
    include_str!("../../EpistemosTests/VaultRecallWiringTests.swift");

#[test]
fn swift_page_gather_trace_mirrors_packetized_rust_fields() {
    for rust_field in [
        "pub packetized_caller_consumed: bool",
        "pub packets_emitted: usize",
        "pub dense_restore_deferred: bool",
        "pub fn with_packetized_caller",
    ] {
        assert!(
            RUST_RETRIEVAL_TRACE_SOURCE.contains(rust_field),
            "Rust RetrievalTrace must keep PageGather packetized field `{rust_field}`"
        );
    }

    for swift_field in [
        "public let packetizedCallerConsumed: Bool",
        "public let packetsEmitted: Int",
        "public let denseRestoreDeferred: Bool",
        "case packetizedCallerConsumed = \"packetized_caller_consumed\"",
        "case packetsEmitted = \"packets_emitted\"",
        "case denseRestoreDeferred = \"dense_restore_deferred\"",
    ] {
        assert!(
            SWIFT_VAULT_RECALL_WIRING_SOURCE.contains(swift_field),
            "Swift VaultRecall PageGather mirror must expose `{swift_field}`"
        );
    }

    for default_decode in [
        "decodeIfPresent(Bool.self, forKey: .packetizedCallerConsumed) ?? false",
        "decodeIfPresent(Int.self, forKey: .packetsEmitted) ?? 0",
        "decodeIfPresent(Bool.self, forKey: .denseRestoreDeferred) ?? false",
    ] {
        assert!(
            SWIFT_VAULT_RECALL_WIRING_SOURCE.contains(default_decode),
            "Swift VaultRecall PageGather decode must preserve older traces with `{default_decode}`"
        );
    }
}

#[test]
fn swift_decode_fixture_exercises_packetized_page_gather_fields() {
    for fixture_fragment in [
        "\"packetized_caller_consumed\": true",
        "\"packets_emitted\": 4",
        "\"dense_restore_deferred\": true",
        "#expect(pageGather.packetizedCallerConsumed)",
        "#expect(pageGather.packetsEmitted == 4)",
        "#expect(pageGather.denseRestoreDeferred)",
    ] {
        assert!(
            SWIFT_VAULT_RECALL_TEST_SOURCE.contains(fixture_fragment),
            "VaultRecallWiringTests should exercise `{fixture_fragment}`"
        );
    }
}

#[test]
fn swift_retrieval_backend_honesty_keeps_scaffolds_distinct_from_real_vaults() {
    for eidos_fragment in [
        "case fixture",
        "case real",
        "case unknown",
        "if manifest.hasPrefix(\"eidos-fixture-\") { return .fixture }",
        "if manifest.hasPrefix(\"vault-\")         { return .real }",
        "lastBackendValue: EidosBackend = .unknown",
    ] {
        assert!(
            SWIFT_EIDOS_WIRING_SOURCE.contains(eidos_fragment),
            "Eidos backend honesty surface must keep `{eidos_fragment}`"
        );
    }

    for vault_recall_fragment in [
        "case stub",
        "case real",
        "case unknown",
        "if tier == \"scaffold-lexical\" { return .stub }",
        "if tier.hasPrefix(\"vault-\")   { return .real }",
        "if tier.hasPrefix(\"helios-\")  { return .real }",
        "lastBackendValue: VaultRecallBackend = .unknown",
    ] {
        assert!(
            SWIFT_VAULT_RECALL_WIRING_SOURCE.contains(vault_recall_fragment),
            "VaultRecall backend honesty surface must keep `{vault_recall_fragment}`"
        );
    }
}

#[test]
fn swift_backend_honesty_tests_cover_fixture_stub_and_real_prefixes() {
    for eidos_test_fragment in [
        "#expect(backend == .fixture",
        "#expect(EidosBridge.detectedBackend(from: packet) == .real)",
        "#expect(after.lastBackend == .fixture",
    ] {
        assert!(
            SWIFT_EIDOS_WIRING_TEST_SOURCE.contains(eidos_test_fragment),
            "EidosWiringTests must cover `{eidos_test_fragment}`"
        );
    }

    for vault_recall_test_fragment in [
        "#expect(backend == .stub",
        "#expect(VaultRecallBridge.detectedBackend(from: trace) == .real)",
        "#expect(after.lastBackend == .stub",
    ] {
        assert!(
            SWIFT_VAULT_RECALL_TEST_SOURCE.contains(vault_recall_test_fragment),
            "VaultRecallWiringTests must cover `{vault_recall_test_fragment}`"
        );
    }
}

#[test]
fn query_runtime_prefers_real_eidos_vault_before_fixture_fallback() {
    for route_fragment in [
        "if EidosFlags.isEnabled,",
        "if EidosBridge.vaultStatus()?.isOpen == true {",
        "return EidosBridge.retrieve(query: query, topK: topK)",
        "return EidosBridge.search(query: query, topK: topK)",
    ] {
        assert!(
            SWIFT_QUERY_RUNTIME_SOURCE.contains(route_fragment),
            "QueryRuntime Eidos route order must keep `{route_fragment}`"
        );
    }
}
