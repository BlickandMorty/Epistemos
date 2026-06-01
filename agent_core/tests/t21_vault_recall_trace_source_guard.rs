//! Source guard for the T21 VaultRecall/PageGather trace contract.
//!
//! Rust already emits packetized PageGather caller fields on the retrieval
//! trace. The Swift mirror must keep those fields typed so product surfaces can
//! distinguish packet consumption from dense PageGather performance claims.

const RUST_RETRIEVAL_TRACE_SOURCE: &str = include_str!("../src/storage/retrieval_trace.rs");
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
