import Foundation
import Testing
@testable import Epistemos

@Suite("Goose custom capability live integration", .serialized)
struct GooseCustomCapabilityLiveIntegrationTests {
    @Test(
        "live Goose serve handles recipes, schedules, and extension mutations through dynamic custom ACP"
    )
    @MainActor
    func liveGooseServeHandlesRecipesSchedulesAndExtensionsThroughDynamicCustomACP() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-acp-custom-capabilities.log")
        try? FileManager.default.removeItem(at: proofURL)

        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-goose-custom-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        try await withLiveGooseRuntime(
            proofName: "acp-custom-capabilities",
            homeDirectory: home,
            disableKeyring: true
        ) { binary, connection, progressURL in
            guard let acpURL = connection.acpWebSocketURL else {
                throw GooseLiveIntegrationError.runtimeFailed("Live Goose runtime did not produce an ACP WebSocket URL.")
            }
            let client = GooseACPClient(
                transport: GooseACPURLSessionWebSocketTransport(url: acpURL),
                clientVersion: "phase0-custom-capabilities"
            )
            defer { Task { await client.close() } }

            _ = try await withLiveTimeout(
                seconds: 12,
                description: "ACP initialize response",
                onTimeout: { await client.close() },
                operation: { try await client.initialize() }
            )

            let recipe = phase0Recipe()
            appendLiveProgress("before recipe save", to: progressURL)
            let savedRecipe = try await client.sendGooseCustomRequest(
                method: "_goose/unstable/recipes/save",
                params: .object(["recipe": recipe])
            )
            let recipeId = try requiredString(savedRecipe, path: ["id"], label: "recipe save id")
            defer {
                Task {
                    _ = try? await client.sendGooseCustomRequest(
                        method: "_goose/unstable/recipes/delete",
                        params: .object(["id": .string(recipeId)])
                    )
                }
            }

            appendLiveProgress("before recipe list/export", to: progressURL)
            let recipeList = try await client.sendGooseCustomRequest(
                method: "_goose/unstable/recipes/list",
                params: .object([:])
            )
            let recipeYAML = try await client.sendGooseCustomRequest(
                method: "_goose/unstable/recipes/to-yaml",
                params: .object(["recipe": recipe])
            )
            let recipeYAMLText = try requiredString(recipeYAML, path: ["yaml"], label: "recipe yaml")

            let scheduleId = "phase0-\(UUID().uuidString.lowercased())"
            appendLiveProgress("before schedule create", to: progressURL)
            let schedule = try await client.sendGooseCustomRequest(
                method: "_goose/unstable/schedules/create",
                params: .object([
                    "id": .string(scheduleId),
                    "recipe": recipe,
                    "cron": .string("0 0 9 * * *"),
                ])
            )
            defer {
                Task {
                    _ = try? await client.sendGooseCustomRequest(
                        method: "_goose/unstable/schedules/delete",
                        params: .object(["scheduleId": .string(scheduleId)])
                    )
                }
            }
            let createdScheduleId = try requiredString(schedule, path: ["job", "id"], label: "created schedule id")

            appendLiveProgress("before schedule mutations", to: progressURL)
            _ = try await client.sendGooseCustomRequest(
                method: "_goose/unstable/schedules/pause",
                params: .object(["scheduleId": .string(scheduleId)])
            )
            _ = try await client.sendGooseCustomRequest(
                method: "_goose/unstable/schedules/unpause",
                params: .object(["scheduleId": .string(scheduleId)])
            )
            let updatedSchedule = try await client.sendGooseCustomRequest(
                method: "_goose/unstable/schedules/update",
                params: .object([
                    "scheduleId": .string(scheduleId),
                    "cron": .string("0 0 10 * * *"),
                ])
            )
            let updatedCron = try requiredString(updatedSchedule, path: ["job", "cron"], label: "updated schedule cron")

            appendLiveProgress("before extension mutation", to: progressURL)
            let extensionConfigKey = "phase0-acp-\(UUID().uuidString.lowercased())"
            _ = try await client.sendGooseCustomRequest(
                method: "_goose/unstable/config/extensions/add",
                params: .object([
                    "extension": .object([
                        "type": .string("mcp"),
                        "description": .string("Epistemos Phase 0 custom ACP extension proof"),
                        "server": .object([
                            "type": .string("stdio"),
                            "name": .string(extensionConfigKey),
                            "command": .string("test-command"),
                            "args": .array([.string("--phase0")]),
                            "env": .array([]),
                        ]),
                    ]),
                    "enabled": .bool(false),
                ])
            )
            defer {
                Task {
                    _ = try? await client.sendGooseCustomRequest(
                        method: "_goose/unstable/config/extensions/remove",
                        params: .object(["configKey": .string(extensionConfigKey)])
                    )
                }
            }
            let afterAdd = try await client.sendGooseCustomRequest(
                method: "_goose/unstable/config/extensions/list",
                params: .object([:])
            )
            let addedExtension = try requiredExtensionEntry(named: extensionConfigKey, in: afterAdd)
            _ = try await client.sendGooseCustomRequest(
                method: "_goose/unstable/config/extensions/set-enabled",
                params: .object([
                    "configKey": .string(extensionConfigKey),
                    "enabled": .bool(true),
                ])
            )

            let proof = [
                "phase0_live_acp_custom_capabilities=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "recipe_id=\(recipeId)",
                "recipe_list_count=\(recipeList.objectValue?["recipes"]?.arrayValue?.count ?? -1)",
                "recipe_yaml_chars=\(recipeYAMLText.count)",
                "schedule_id=\(createdScheduleId)",
                "schedule_updated_cron=\(updatedCron)",
                "extension_config_key=\(extensionConfigKey)",
                "extension_listed_config_key=\(addedExtension.configKey)",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard recipeYAMLText.contains("phase0-custom-capability-recipe") else {
                throw GooseLiveIntegrationError.runtimeFailed("Recipe export YAML did not include the saved recipe title.")
            }
            guard createdScheduleId == scheduleId else {
                throw GooseLiveIntegrationError.runtimeFailed("Schedule create returned \(createdScheduleId), expected \(scheduleId).")
            }
            guard updatedCron == "0 0 10 * * *" else {
                throw GooseLiveIntegrationError.runtimeFailed("Schedule update did not round-trip the updated cron.")
            }
            guard !extensionConfigKey.isEmpty else {
                throw GooseLiveIntegrationError.runtimeFailed("Extension mutation did not return a config key.")
            }
            guard addedExtension.configKey == extensionConfigKey else {
                throw GooseLiveIntegrationError.runtimeFailed("Extension list returned \(addedExtension.configKey), expected \(extensionConfigKey).")
            }
            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_acp_custom_capabilities=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live custom capability proof log was not written.")
            }
        }
    }
}

private func phase0Recipe() -> JSONValue {
    .object([
        "title": .string("phase0-custom-capability-recipe"),
        "description": .string("Epistemos Phase 0 live custom ACP recipe proof"),
        "instructions": .string("Reply with exactly: phase0 custom capability recipe ready"),
        "prompt": .string("Reply with exactly: phase0 custom capability recipe ready"),
    ])
}

private struct GooseExtensionEntryProbe {
    let configKey: String
}

private func requiredString(_ value: JSONValue, path: [String], label: String) throws -> String {
    var cursor = value
    for key in path {
        guard let next = cursor.objectValue?[key] else {
            throw GooseLiveIntegrationError.runtimeFailed("Missing \(label) at \(path.joined(separator: "."))")
        }
        cursor = next
    }
    guard let string = cursor.stringValue,
          !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw GooseLiveIntegrationError.runtimeFailed("Missing \(label) string.")
    }
    return string
}

private func requiredExtensionEntry(named name: String, in response: JSONValue) throws -> GooseExtensionEntryProbe {
    guard let entry = extensionEntry(named: name, in: response) else {
        throw GooseLiveIntegrationError.runtimeFailed("Extension list did not include \(name).")
    }
    return entry
}

private func extensionEntry(named name: String, in response: JSONValue) -> GooseExtensionEntryProbe? {
    guard let entries = response.objectValue?["extensions"]?.arrayValue else {
        return nil
    }
    for entry in entries {
        guard let object = entry.objectValue,
              let extensionObject = object["extension"]?.objectValue,
              extensionName(extensionObject) == name,
              let configKey = object["configKey"]?.stringValue,
              !configKey.isEmpty else {
            continue
        }
        return GooseExtensionEntryProbe(configKey: configKey)
    }
    return nil
}

private func extensionName(_ extensionObject: [String: JSONValue]) -> String? {
    extensionObject["name"]?.stringValue ??
        extensionObject["server"]?.objectValue?["name"]?.stringValue
}

private extension JSONValue {
    var objectValue: [String: JSONValue]? {
        guard case .object(let object) = self else { return nil }
        return object
    }

    var arrayValue: [JSONValue]? {
        guard case .array(let array) = self else { return nil }
        return array
    }

    var stringValue: String? {
        guard case .string(let string) = self else { return nil }
        return string
    }
}
