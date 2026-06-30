import Foundation

@main
struct ProvenanceSmoke {
    enum Failure: Error, CustomStringConvertible {
        case missingExport
        case privatePayloadLeaked
        case wrongExtension(String)
        case unexpectedReport(MutationOpLogReplayBundleVisibilityReport)
        case missingClosedCitationRejection
        case dishonestVerifiedLabel
        case missingEditSupersessionChain

        var description: String {
            switch self {
            case .missingExport:
                return "exported .epbundle file is missing"
            case .privatePayloadLeaked:
                return "exported .epbundle leaked private source payload"
            case .wrongExtension(let ext):
                return "exported file extension was \(ext), expected epbundle"
            case .unexpectedReport(let report):
                return "unexpected export report: \(report)"
            case .missingClosedCitationRejection:
                return "closed-citation gate did not reject forged citation"
            case .dishonestVerifiedLabel:
                return "VRM honest label promoted without packet-bound ACS anchor"
            case .missingEditSupersessionChain:
                return "EventStore edit supersession chain was not projected"
            }
        }
    }

    static func main() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-provenance-smoke-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let databaseURL = tempRoot.appendingPathComponent("oplog.sqlite")
        let client = try RustOpLogFFIClient(databaseURL: databaseURL, actorID: "provenance-smoke-writer")
        _ = try client.append(.nodeAdd(id: "ignored-note", kind: "prose_note", title: "Ignored"))
        _ = try client.append(.propSet(
            nodeID: "mutation-provenance-smoke",
            key: MutationOpLogProjector.projectionKey,
            value: .object([
                "artifact_id": .string("artifact-provenance-smoke"),
                "artifact_kind": .string("prose_note"),
                "event_kind": .string("mutation_envelope"),
                "integrity_hash": .string("sha256:provenance-smoke"),
                "mutation_id": .string("mutation-provenance-smoke"),
                "recorded_at_ms": .int(12_345),
                "source_payload_json": .string("{\"body\":\"PRIVATE_NOTE_BODY\",\"cwd\":\"/Users/jojo/Vault\",\"system_prompt\":\"system prompt\"}"),
                "status": .string("committed"),
                "trace_id": .string("trace-provenance-smoke"),
            ])
        ))

        let exportURL = tempRoot.appendingPathComponent("manual-name")
        let result = try MutationOpLogReplayBundleFileExporter.exportCurrentBundle(
            to: exportURL,
            databaseURL: databaseURL,
            actorID: "provenance-smoke-exporter",
            source: "provenance-smoke"
        )
        guard FileManager.default.fileExists(atPath: result.url.path) else {
            throw Failure.missingExport
        }
        guard result.url.pathExtension == MutationOpLogReplayBundleFileExporter.fileExtension else {
            throw Failure.wrongExtension(result.url.pathExtension)
        }
        guard result.report.status == .available,
              result.report.replayedEntryCount == 2,
              result.report.recordCount == 1,
              result.report.ignoredNonProjectionCount == 1,
              result.report.latestMutationID == "mutation-provenance-smoke" else {
            throw Failure.unexpectedReport(result.report)
        }

        let exported = try String(contentsOf: result.url, encoding: .utf8)
        guard exported.contains(MutationOpLogReplayBundle.schema),
              exported.contains("mutation-provenance-smoke"),
              !exported.contains("PRIVATE_NOTE_BODY"),
              !exported.contains("/Users/jojo/Vault"),
              !exported.contains("system prompt") else {
            throw Failure.privatePayloadLeaked
        }

        let packet = AnswerPacket(
            id: "packet-provenance-smoke",
            claims: [
                Claim(
                    id: "claim-unverified",
                    text: "Unanchored empirical claim must not become Verified.",
                    status: .active,
                    createdAtMs: 1_000,
                    kind: .empirical
                ),
            ],
            residencySignals: [.neutral],
            uiLabel: .verified,
            attentionMode: .unavailable,
            interruptBucket: .unavailable,
            witnessedStateRef: "ws",
            mutationEnvelopeRef: "me"
        )
        guard VRMLabel.honestLabel(for: packet) == .plausibleButUnverified else {
            throw Failure.dishonestVerifiedLabel
        }

        guard let eventStore = EventStore(
            databaseURL: tempRoot.appendingPathComponent("eventstore.sqlite")
        ) else {
            throw Failure.missingEditSupersessionChain
        }
        let artifactID = "artifact-edit-chain-smoke"
        let firstEdit = AgentNoteEditProvenance.envelope(
            context: AgentEditProvenanceContext(
                artifactID: artifactID,
                runID: "run-edit-chain-smoke-a",
                sequence: 1,
                title: "Smoke Note"
            ),
            beforeBody: "old",
            afterBody: "new",
            createdAtMs: 2_000
        )
        let secondEdit = AgentNoteEditProvenance.envelope(
            context: AgentEditProvenanceContext(
                artifactID: artifactID,
                runID: "run-edit-chain-smoke-b",
                sequence: 2,
                title: "Smoke Note"
            ),
            beforeBody: "new",
            afterBody: "newer",
            createdAtMs: 3_000
        )
        guard eventStore.saveMutationEnvelope(
            firstEdit,
            traceId: AgentNoteEditProvenance.traceID(for: firstEdit)
        ), eventStore.saveMutationEnvelope(
            secondEdit,
            traceId: AgentNoteEditProvenance.traceID(for: secondEdit)
        ) else {
            throw Failure.missingEditSupersessionChain
        }
        let snapshot = ProvenanceConsoleProjectionService(eventStoreProvider: { eventStore }).snapshot(limit: 10)
        guard case .provenanceChain(let editEvents) = snapshot.editSupersessionPayload.body,
              let editEvent = editEvents.first,
              case .keyValues(let editRows) = editEvent.body else {
            throw Failure.missingEditSupersessionChain
        }
        let editRowMap = Dictionary(uniqueKeysWithValues: editRows.map { ($0.key, $0.value) })
        guard editRowMap["superseded"] == String(firstEdit.mutationID.prefix(12)),
              editRowMap["superseded by"] == String(secondEdit.mutationID.prefix(12)),
              editRowMap["mode"] == "EventStore-derived; no ClaimLedger write FFI" else {
            throw Failure.missingEditSupersessionChain
        }

        let eidosPacket = EidosContextPacket(
            query: EidosQuery(
                text: "provenance",
                mode: .lexical,
                topK: 1
            ),
            manifestId: EidosIndexManifestId("vault-provenance-smoke")!,
            hits: [
                EidosHit(
                    sourceId: EidosChunkId("source-real")!,
                    documentId: EidosDocumentId("doc-real")!,
                    kind: .note,
                    span: EidosSpan(byteStart: 0, byteEnd: 18),
                    confidence: 1.0,
                    score: EidosScoreComponents(lexical: 1.0),
                    provenance: EidosProvenance(
                        manifestId: EidosIndexManifestId("vault-provenance-smoke")!,
                        mode: .lexical,
                        retrievedAtUnixMs: 1_000
                    )
                ),
            ]
        )
        let forged = EidosCitation(
            sourceId: EidosChunkId("source-forged")!,
            manifestId: eidosPacket.manifestId
        )
        guard case .failure(.fabricatedSourceId) = eidosPacket.validate(citation: forged) else {
            throw Failure.missingClosedCitationRejection
        }

        print("provenance smoke OK: epbundle_bytes=\(result.byteCount) schema=\(MutationOpLogReplayBundle.schema) closed_citation_rejects=true vrm_honest=true edit_supersession=true")
    }
}
