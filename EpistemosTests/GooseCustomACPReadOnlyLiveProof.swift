import Foundation
@testable import Epistemos

@MainActor
func proveLiveGooseCustomACPReadOnlySubset(
    binary: URL,
    connection: GooseRuntimeConnection,
    client: GooseACPClient,
    progressURL: URL,
    proofURL: URL,
    session: GooseACPNewSessionResponse
) async throws {
    func read<T: Sendable>(
        _ description: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withLiveTimeout(seconds: 20, description: description, onTimeout: { await client.close() }, operation: operation)
    }

    let repoPath = liveRepoRootURL().path
    let providers = try await read("Goose providers list custom ACP response") { try await client.listGooseProviders() }
    let extensions = try await read("Goose config extensions custom ACP response") { try await client.listGooseConfigExtensions() }
    let preferences = try await read("Goose preferences custom ACP response") { try await client.readGoosePreferences() }
    let defaults = try await read("Goose defaults custom ACP response") { try await client.readGooseDefaults() }
    let sessionInfo = try await read("Goose session info custom ACP response") { try await client.readGooseSessionInfo(sessionId: session.sessionId) }
    let diagnostics = try await read("Goose diagnostics custom ACP response") { try await client.readGooseDiagnostics(sessionId: session.sessionId, level: .summary) }
    let projectSkills = try await read("Goose project skill sources custom ACP response") { try await client.listGooseSources(type: .skill, projectDir: repoPath) }
    let builtInSkills = try await read("Goose built-in skill sources custom ACP response") { try await client.listGooseSources(type: .builtinSkill, projectDir: repoPath) }
    appendLiveProgress(
        "after custom ACP reads providers=\(providers.entries.count) extensions=\(extensions.extensions.count) preferences=\(preferences.values.count) project_skills=\(projectSkills.sources.count) builtin_skills=\(builtInSkills.sources.count)",
        to: progressURL
    )

    let sessionInfoSessionID = stringValue(for: "sessionId", in: sessionInfo.session) ?? "<missing>"
    let projectSkillTypesOK = projectSkills.sources.allSatisfy { $0.sourceType == .skill }
    let builtInSkillTypesOK = builtInSkills.sources.allSatisfy { $0.sourceType == .builtinSkill }
    let proof = [
        "phase0_live_acp_custom_readonly=pass",
        "goose_binary=\(binary.lastPathComponent)",
        "goose_base_url=\(connection.baseURL.absoluteString)",
        "session_id=\(session.sessionId)",
        "provider_entry_count=\(providers.entries.count)",
        "config_extension_count=\(extensions.extensions.count)",
        "config_extension_warning_count=\(extensions.warnings.count)",
        "preference_value_count=\(preferences.values.count)",
        "defaults_provider_set=\(defaults.providerId != nil)",
        "defaults_model_set=\(defaults.modelId != nil)",
        "session_info_session_id=\(sessionInfoSessionID)",
        "diagnostics_report_kind=\(jsonValueKind(diagnostics.report))",
        "project_skill_source_count=\(projectSkills.sources.count)",
        "project_skill_source_type_ok=\(projectSkillTypesOK)",
        "builtin_skill_source_count=\(builtInSkills.sources.count)",
        "builtin_skill_source_type_ok=\(builtInSkillTypesOK)",
    ].joined(separator: "\n") + "\n"
    try proof.write(to: proofURL, atomically: true, encoding: .utf8)

    guard !providers.entries.isEmpty else {
        throw GooseLiveIntegrationError.runtimeFailed("Custom ACP provider list returned no providers.")
    }
    guard sessionInfoSessionID == session.sessionId else {
        throw GooseLiveIntegrationError.runtimeFailed("Custom ACP session info did not echo the live session id.")
    }
    guard case .object = diagnostics.report else {
        throw GooseLiveIntegrationError.runtimeFailed("Custom ACP diagnostics did not return an object report.")
    }
    guard !projectSkills.sources.isEmpty, projectSkillTypesOK else {
        throw GooseLiveIntegrationError.runtimeFailed("Custom ACP skill sources did not return project skill entries.")
    }
    guard !builtInSkills.sources.isEmpty, builtInSkillTypesOK else {
        throw GooseLiveIntegrationError.runtimeFailed("Custom ACP skill sources did not return built-in skill entries.")
    }
    guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_acp_custom_readonly=pass") else {
        throw GooseLiveIntegrationError.runtimeFailed("Live custom ACP proof log was not written.")
    }
}

private func stringValue(for key: String, in value: JSONValue) -> String? {
    guard case .object(let object) = value,
          case .string(let string)? = object[key] else {
        return nil
    }
    return string
}
