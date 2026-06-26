import Foundation

nonisolated struct LocalToolResult: Codable, Equatable, Sendable {
    let toolName: String
    let resultJson: String
    let isError: Bool
}

typealias LocalAgentToolExecutor = @Sendable (
    _ name: String,
    _ argumentsJson: String
) async -> LocalToolResult
