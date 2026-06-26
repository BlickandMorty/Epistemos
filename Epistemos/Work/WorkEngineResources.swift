import Foundation

// Native model for the OpenGUI `loadResources` bundle (the compact engine/model + agent picker + slash-commands data).
// Decoded from the sidecar's `loadResources` reply, whose shape was runtime-verified (og-loadresources-probe.mjs) and
// typed against `@opengui/runtime` harness-types.ts:
//   HarnessResourceBundle = { providersData: { providers: Provider[], default: Record<providerID,modelID> },
//                             agentsData: Agent[], commandsData: Command[] }
//   Provider = { id, name, models: Record<string, Model{ id?, name }> }
//   Agent = { name, mode?, hidden?, description? } ; Command = { name, description? }
// Lenient JSONSerialization decode (ignores unknown fields, converts the models Record → array) so harness/version
// drift can't crash the picker. Pure value types (Sendable/Identifiable for SwiftUI pickers). NO raw JSON reaches UI.

struct WorkEngineModel: Sendable, Hashable, Identifiable {
    let id: String      // model id (falls back to the Record key / name)
    let name: String
}

struct WorkEngineProvider: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let models: [WorkEngineModel]
}

struct WorkEngineAgent: Sendable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let mode: String?
    let description: String?
}

struct WorkEngineCommand: Sendable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
}

struct WorkEngineResources: Sendable, Equatable {
    var providers: [WorkEngineProvider]
    var agents: [WorkEngineAgent]
    var commands: [WorkEngineCommand]
    /// providerID → default modelID (preselects the model picker).
    var defaultModelByProvider: [String: String]

    static let empty = WorkEngineResources(providers: [], agents: [], commands: [], defaultModelByProvider: [:])

    /// All models flattened with their provider, for a single compact picker (provider · model).
    var flatModels: [(provider: WorkEngineProvider, model: WorkEngineModel)] {
        providers.flatMap { p in p.models.map { (p, $0) } }
    }

    /// Picker options keyed by the COMPOSITE `providerID/modelID` selection id. opencode's prompt API expects a
    /// `SelectedModel { providerID, modelID }` (verified: opencode-bridge promptAsync passes the object straight to
    /// `session.promptAsync`; only `sendCommand` stringifies it). The composite id carries the provider through the
    /// picker so `send` can rebuild the object — a bare model id loses the provider and opencode silently ignores the
    /// pick / falls back to its default model. The composite also disambiguates same-named models across providers.
    var flatModelOptions: [(id: String, name: String)] {
        let showProvider = providers.count > 1
        return flatModels.map {
            let label = showProvider ? "\($0.provider.name) · \($0.model.name)" : $0.model.name
            return (id: WorkEngineResources.selectionID(providerID: $0.provider.id, modelID: $0.model.id), name: label)
        }
    }

    /// Build the composite picker-selection id (`providerID/modelID`).
    static func selectionID(providerID: String, modelID: String) -> String { "\(providerID)/\(modelID)" }

    /// Split a composite picker-selection id back into `(providerID, modelID)` (split on the FIRST `/` so model ids
    /// that themselves contain a slash survive). Returns nil for a malformed/empty id.
    static func splitSelectionID(_ composite: String) -> (providerID: String, modelID: String)? {
        guard let slash = composite.firstIndex(of: "/") else { return nil }
        let providerID = String(composite[..<slash])
        let modelID = String(composite[composite.index(after: slash)...])
        guard !providerID.isEmpty, !modelID.isEmpty else { return nil }
        return (providerID, modelID)
    }
}

enum WorkEngineResourcesDecoder {
    /// Decode the sidecar `loadResources` reply data. Accepts either the `{resources:{…}}` envelope (sidecar) or the
    /// bare bundle. Never throws — returns `.empty` on anything unexpected.
    static func decode(_ data: Data?) -> WorkEngineResources {
        guard let data, let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .empty
        }
        let bundle = (root["resources"] as? [String: Any]) ?? root

        var providers: [WorkEngineProvider] = []
        var defaults: [String: String] = [:]
        if let providersData = bundle["providersData"] as? [String: Any] {
            if let list = providersData["providers"] as? [[String: Any]] {
                providers = list.compactMap { provider in
                    guard let id = nonEmptyString(provider["id"]),
                          let name = nonEmptyString(provider["name"]) else { return nil }
                    let modelsDict = (provider["models"] as? [String: [String: Any]]) ?? [:]
                    let models = modelsDict.compactMap { key, model -> WorkEngineModel? in
                        guard let id = nonEmptyString(model["id"]) ?? nonEmptyString(key),
                              let name = nonEmptyString(model["name"]) ?? nonEmptyString(key) else { return nil }
                        return WorkEngineModel(id: id, name: name)
                    }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    return WorkEngineProvider(id: id, name: name, models: models)
                }
            }
            let rawDefaults = (providersData["default"] as? [String: String]) ?? [:]
            defaults = rawDefaults.filter { providerID, modelID in
                providers.contains { provider in
                    provider.id == providerID && provider.models.contains { $0.id == modelID }
                }
            }
        }

        let agents = ((bundle["agentsData"] as? [[String: Any]]) ?? []).compactMap { agent -> WorkEngineAgent? in
            guard let name = nonEmptyString(agent["name"]) else { return nil }
            if (agent["hidden"] as? Bool) == true { return nil }   // hidden agents never reach the picker
            return WorkEngineAgent(name: name, mode: agent["mode"] as? String, description: agent["description"] as? String)
        }

        let commands = ((bundle["commandsData"] as? [[String: Any]]) ?? []).compactMap { command -> WorkEngineCommand? in
            guard let name = nonEmptyString(command["name"]) else { return nil }
            return WorkEngineCommand(name: name, description: command["description"] as? String)
        }

        return WorkEngineResources(
            providers: providers, agents: agents, commands: commands, defaultModelByProvider: defaults)
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
