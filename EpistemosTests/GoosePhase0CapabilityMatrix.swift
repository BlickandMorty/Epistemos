import CryptoKit
import Foundation
@testable import Epistemos

enum GoosePhase0CapabilityRow: String, CaseIterable, Sendable {
    case conversationLoop = "conversation loop"
    case providerCatalog = "provider catalog"
    case addProvider = "add-provider"
    case setKey = "set-key"
    case modelSwitchPersistence = "model-switch persistence"
    case skillsCRUD = "skills CRUD"
    case mcpExtensionsAddEnable = "MCP/extensions add+enable"
    case recipesRunSaveExport = "recipes run+save/export"
    case schedulesCreateRunMutate = "schedules create/run/mutate"
    case sessionsListResumeFork = "sessions list/resume/fork"
    case gooseHintsEdit = ".goosehints edit"
    case mcpApps = "MCP apps"
    case confirmDialogs = "confirm dialogs"
    case hostIOSurface = "host-IO shims"
    case recipeTrustPersistence = "recipe-trust persistence"
    case portableSurfaceAssets = "portable Goose surface assets"
}

enum GoosePhase0CapabilityMatrix {
    nonisolated static let url = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-capability-matrix.jsonl")
    nonisolated private static let lock = NSLock()

    nonisolated static func record(
        _ rows: [GoosePhase0CapabilityRow],
        proofURL: URL,
        via: String,
        details: [String: String] = [:]
    ) throws {
        let proofText = try String(contentsOf: proofURL, encoding: .utf8)
        guard proofText.contains("=pass") else {
            throw GooseLiveIntegrationError.runtimeFailed("Capability proof did not contain a pass marker: \(proofURL.path)")
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let proofDigest = SHA256Hex.digest(Data(proofText.utf8))
        let lines = rows.map { row -> String in
            var object: [String: Any] = [
                "row": row.rawValue,
                "status": "WORKS",
                "via": via,
                "proof": proofURL.path,
                "proof_sha256": proofDigest,
                "recorded_at": timestamp,
            ]
            for (key, value) in details.sorted(by: { $0.key < $1.key }) {
                object[key] = value
            }
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
                  let json = String(data: data, encoding: .utf8) else {
                return #"{"status":"ERROR"}"#
            }
            return json
        }.joined(separator: "\n") + "\n"

        lock.lock()
        defer { lock.unlock() }
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try (existing + lines).write(to: url, atomically: true, encoding: .utf8)
    }
}

private enum SHA256Hex {
    nonisolated static func digest(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
