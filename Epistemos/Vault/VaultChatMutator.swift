import Foundation
import Observation
import OSLog
import SwiftUI

nonisolated enum VaultChatMutatorDiagnostics {
    static let log = Logger(
        subsystem: "com.epistemos",
        category: "VaultChatMutator"
    )
}

nonisolated enum VaultIdentity: Hashable, Codable, Sendable {
    case model(String)
    case agent(String)
    case team([String])
    case useCase(String)
    case personal

    var displayName: String {
        switch self {
        case .model(let name):
            return name
        case .agent(let name):
            return name
        case .team(let names):
            return names.joined(separator: ", ")
        case .useCase(let name):
            return name
        case .personal:
            return "Personal"
        }
    }

    var relativeMemoryPath: String {
        switch self {
        case .model(let name):
            return ".omega-vaults/models/\(Self.slug(from: name))/MEMORY.md"
        case .agent(let name):
            return ".omega-vaults/agents/\(Self.slug(from: name))/MEMORY.md"
        case .team(let names):
            return ".omega-vaults/teams/\(Self.slug(from: names.joined(separator: "-")))/MEMORY.md"
        case .useCase(let name):
            return ".omega-vaults/use-cases/\(Self.slug(from: name))/MEMORY.md"
        case .personal:
            return "MEMORY.md"
        }
    }

    private static func slug(from value: String) -> String {
        let slug = value
            .lowercased()
            .map { character -> Character in
                character.isLetter || character.isNumber ? character : "-"
            }
        let normalized = String(slug)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return normalized.isEmpty ? "default" : normalized
    }
}

nonisolated enum VaultMutationOperation: String, Codable, Sendable {
    case add = "ADD"
    case update = "UPDATE"
    case delete = "DELETE"
    case noop = "NOOP"
}

nonisolated struct DiffResult: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var targetVault: VaultIdentity
    var repositoryRootURL: URL
    var fileURL: URL
    var relativePath: String
    var operation: VaultMutationOperation
    var summary: String
    var rationale: String
    var before: String
    var after: String
    var unifiedDiff: String
    var commitMessage: String
    var requiresApproval: Bool

    init(
        id: UUID = UUID(),
        targetVault: VaultIdentity,
        repositoryRootURL: URL,
        fileURL: URL,
        relativePath: String,
        operation: VaultMutationOperation,
        summary: String,
        rationale: String,
        before: String,
        after: String,
        unifiedDiff: String,
        commitMessage: String,
        requiresApproval: Bool
    ) {
        self.id = id
        self.targetVault = targetVault
        self.repositoryRootURL = repositoryRootURL
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.operation = operation
        self.summary = summary
        self.rationale = rationale
        self.before = before
        self.after = after
        self.unifiedDiff = unifiedDiff
        self.commitMessage = commitMessage
        self.requiresApproval = requiresApproval
    }
}

enum VaultChatMutatorError: LocalizedError {
    case emptyMessage
    case vaultUnavailable
    case nothingStaged
    case fileOutsideRepositoryRoot
    case writeVerificationFailed(path: String)
    case gitCommandFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Vault mutations need a non-empty message."
        case .vaultUnavailable:
            return "No vault is available for mutation."
        case .nothingStaged:
            return "There is no staged diff to approve."
        case .fileOutsideRepositoryRoot:
            return "Vault mutations must stay inside the attached vault root."
        case .writeVerificationFailed(let path):
            return "Vault mutation write did not match readback at \(path)."
        case .gitCommandFailed(let output):
            return output.isEmpty ? "Git command failed." : output
        }
    }
}

nonisolated enum VaultVerifiedFileWriter {
    typealias ReadBack = (URL) throws -> String

    static func writeUTF8(
        _ content: String,
        to fileURL: URL,
        readBack: ReadBack = { try String(contentsOf: $0, encoding: .utf8) }
    ) throws {
        // Phase 0/S.5 signpost: covers the verified-write contract used
        // by `VaultMutationIO.commit(diff:)` for every approved staged
        // vault mutation -- atomic UTF-8 write + readback verification.
        // Lets Instruments / signpost analysis attribute time to this
        // path so a future regression in either the write or the
        // readback is visible.
        let writeInterval = Log.notesPerf.beginInterval("notes.save.vaultVerifiedWrite.ms")
        defer { Log.notesPerf.endInterval("notes.save.vaultVerifiedWrite.ms", writeInterval) }

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        let persistedContent = try readBack(fileURL)
        guard persistedContent == content else {
            throw VaultChatMutatorError.writeVerificationFailed(path: fileURL.path)
        }
    }
}

@MainActor @Observable
final class VaultChatMutator {
    typealias VaultResolver = @Sendable (VaultIdentity) async throws -> URL
    typealias ApprovalHandler = @MainActor (DiffResult) async throws -> Void

    var stagedDiff: DiffResult?
    var lastCommittedDiff: DiffResult?
    var lastCommitReference: String?
    var lastError: String?
    var isMutating = false
    var isCommitting = false
    var autoCommitInAgentMode: Bool
    var agentReasoning: String?

    private let vaultResolver: VaultResolver
    private let io = VaultMutationIO()
    @ObservationIgnored
    private var stagedApprovalHandler: ApprovalHandler?

    init(
        vaultSync: VaultSyncService? = nil,
        vaultResolver: VaultResolver? = nil,
        autoCommitInAgentMode: Bool = false,
        agentReasoning: String? = nil
    ) {
        self.autoCommitInAgentMode = autoCommitInAgentMode
        self.agentReasoning = agentReasoning
        if let vaultResolver {
            self.vaultResolver = vaultResolver
        } else {
            let initialVaultRootURL = vaultSync?.vaultURL
            self.vaultResolver = { _ in
                guard let root = initialVaultRootURL else {
                    throw VaultChatMutatorError.vaultUnavailable
                }
                return root
            }
        }
    }

    @discardableResult
    func mutate(message: String, targetVault: VaultIdentity) async throws -> DiffResult {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            throw VaultChatMutatorError.emptyMessage
        }

        isMutating = true
        defer { isMutating = false }

        do {
            let repositoryRootURL = try await vaultResolver(targetVault)
            let diff = try await io.prepareMutation(
                message: trimmedMessage,
                targetVault: targetVault,
                repositoryRootURL: repositoryRootURL,
                agentReasoning: agentReasoning
            )
            stagePreparedDiff(diff, approvalHandler: nil)

            if autoCommitInAgentMode && diff.operation != .noop {
                _ = try await approvePendingDiff()
            }

            return diff
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    @discardableResult
    func approvePendingDiff() async throws -> String {
        guard let stagedDiff else {
            throw VaultChatMutatorError.nothingStaged
        }

        if stagedDiff.operation == .noop {
            lastCommittedDiff = stagedDiff
            lastCommitReference = "noop"
            self.stagedDiff = nil
            stagedApprovalHandler = nil
            return "noop"
        }

        isCommitting = true
        defer { isCommitting = false }

        do {
            if let stagedApprovalHandler {
                try await stagedApprovalHandler(stagedDiff)
            }
            let commitReference = try await io.commit(diff: stagedDiff)
            lastCommittedDiff = stagedDiff
            lastCommitReference = commitReference
            lastError = nil
            self.stagedDiff = nil
            stagedApprovalHandler = nil
            return commitReference
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func rejectPendingDiff() {
        stagedDiff = nil
        stagedApprovalHandler = nil
    }

    @discardableResult
    func stageFileMutation(
        targetVault: VaultIdentity,
        repositoryRootURL: URL,
        fileURL: URL,
        before: String,
        after: String,
        summary: String,
        rationale: String,
        source: String,
        scope: String = "VAULT",
        approvalHandler: ApprovalHandler? = nil
    ) async throws -> DiffResult {
        isMutating = true
        defer { isMutating = false }

        do {
            let diff = try await io.prepareFileMutation(
                targetVault: targetVault,
                repositoryRootURL: repositoryRootURL,
                fileURL: fileURL,
                before: before,
                after: after,
                summary: summary,
                rationale: rationale,
                source: source,
                scope: scope,
                agentReasoning: agentReasoning
            )
            stagePreparedDiff(diff, approvalHandler: approvalHandler)
            return diff
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    private func stagePreparedDiff(
        _ diff: DiffResult,
        approvalHandler: ApprovalHandler?
    ) {
        stagedDiff = diff
        stagedApprovalHandler = approvalHandler
        lastError = nil
    }
}

private actor VaultMutationIO {
    private func stagedMemoryBodyIfPresent(
        at fileURL: URL,
        targetVault: VaultIdentity
    ) throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return defaultMemoryBody(for: targetVault)
        }

        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            VaultChatMutatorDiagnostics.log.error(
                "VaultChatMutator: failed to read staged memory file at \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    func prepareMutation(
        message: String,
        targetVault: VaultIdentity,
        repositoryRootURL: URL,
        agentReasoning: String?
    ) throws -> DiffResult {
        try FileManager.default.createDirectory(
            at: repositoryRootURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let relativePath = targetVault.relativeMemoryPath
        let fileURL = repositoryRootURL.appendingPathComponent(relativePath, isDirectory: false)
        let before = try stagedMemoryBodyIfPresent(at: fileURL, targetVault: targetVault)
        let proposal = proposeMutation(message: message, original: before, targetVault: targetVault)
        let unifiedDiff = makeUnifiedDiff(
            old: before,
            new: proposal.updatedContent,
            relativePath: relativePath
        )
        let commitMessage = makeCommitMessage(
            operation: proposal.operation,
            scope: "MEMORY",
            relativePath: relativePath,
            summary: proposal.summary,
            source: "vault-chat",
            reasoning: agentReasoning
        )

        return DiffResult(
            targetVault: targetVault,
            repositoryRootURL: repositoryRootURL,
            fileURL: fileURL,
            relativePath: relativePath,
            operation: proposal.operation,
            summary: proposal.summary,
            rationale: proposal.rationale,
            before: before,
            after: proposal.updatedContent,
            unifiedDiff: unifiedDiff,
            commitMessage: commitMessage,
            requiresApproval: proposal.operation != .noop
        )
    }

    func prepareFileMutation(
        targetVault: VaultIdentity,
        repositoryRootURL: URL,
        fileURL: URL,
        before: String,
        after: String,
        summary: String,
        rationale: String,
        source: String,
        scope: String,
        agentReasoning: String?
    ) throws -> DiffResult {
        try FileManager.default.createDirectory(
            at: repositoryRootURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let relativePath = try relativePath(for: fileURL, in: repositoryRootURL)
        let operation = mutationOperation(old: before, new: after)
        let unifiedDiff = makeUnifiedDiff(
            old: before,
            new: after,
            relativePath: relativePath
        )
        let commitMessage = makeCommitMessage(
            operation: operation,
            scope: scope,
            relativePath: relativePath,
            summary: summary,
            source: source,
            reasoning: agentReasoning
        )

        return DiffResult(
            targetVault: targetVault,
            repositoryRootURL: repositoryRootURL,
            fileURL: fileURL,
            relativePath: relativePath,
            operation: operation,
            summary: summary,
            rationale: rationale,
            before: before,
            after: after,
            unifiedDiff: unifiedDiff,
            commitMessage: commitMessage,
            requiresApproval: operation != .noop
        )
    }

    func commit(diff: DiffResult) async throws -> String {
        let parentURL = diff.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try VaultVerifiedFileWriter.writeUTF8(diff.after, to: diff.fileURL)

        #if !EPISTEMOS_APP_STORE
        try await ensureGitRepository(at: diff.repositoryRootURL)
        _ = try await runGitOffMain(arguments: ["-C", diff.repositoryRootURL.path, "add", diff.relativePath], in: diff.repositoryRootURL)
        _ = try await runGitOffMain(arguments: ["-C", diff.repositoryRootURL.path, "commit", "-m", diff.commitMessage], in: diff.repositoryRootURL)
        return try await runGitOffMain(arguments: ["-C", diff.repositoryRootURL.path, "rev-parse", "HEAD"], in: diff.repositoryRootURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        // The App Store sandbox cannot spawn /usr/bin/git. The verified
        // file write above is the durable user-facing effect of approving
        // the staged mutation -- VaultVerifiedFileWriter has already
        // landed the new bytes on disk and validated the readback. The
        // git audit-log layer is a Pro/direct extra; in MAS we skip it
        // honestly and return a placeholder reference so callers
        // (`VaultChatMutator.approvePendingDiff` -> stored in
        // `lastCommitReference`) record the approval without faking a
        // git SHA. Existing call sites discard the reference (see
        // `EpistemosApp.swift` -> `_ = try await ... approvePendingDiff()`).
        return "mas-skipped-\(UUID().uuidString)"
        #endif
    }

    private func proposeMutation(
        message: String,
        original: String,
        targetVault: VaultIdentity
    ) -> (operation: VaultMutationOperation, updatedContent: String, summary: String, rationale: String) {
        let normalizedMessage = normalizeFact(message)
        let existingFacts = extractFacts(from: original)

        if existingFacts.contains(where: { normalizeFact($0) == normalizedMessage }) {
            return (
                .noop,
                original,
                "No change for \(targetVault.displayName)",
                "The requested memory already exists verbatim in the target vault."
            )
        }

        if let query = deleteQuery(from: message) {
            let retainedFacts = existingFacts.filter { !normalizeFact($0).contains(normalizeFact(query)) }
            guard retainedFacts.count != existingFacts.count else {
                return (
                    .noop,
                    original,
                    "No matching memory to delete",
                    "No existing fact matched the requested delete query."
                )
            }
            return (
                .delete,
                renderMemoryBody(facts: retainedFacts, targetVault: targetVault),
                "Delete memory from \(targetVault.displayName)",
                "The request explicitly asked to remove a matching fact from the vault."
            )
        }

        if let update = updatePair(from: message),
           let index = existingFacts.firstIndex(where: { normalizeFact($0).contains(normalizeFact(update.oldValue)) }) {
            var updatedFacts = existingFacts
            updatedFacts[index] = update.newValue
            return (
                .update,
                renderMemoryBody(facts: updatedFacts, targetVault: targetVault),
                "Update memory in \(targetVault.displayName)",
                "The request included an explicit old→new replacement."
            )
        }

        var updatedFacts = existingFacts
        updatedFacts.append(message)
        return (
            .add,
            renderMemoryBody(facts: updatedFacts, targetVault: targetVault),
            "Add memory to \(targetVault.displayName)",
            "The request is novel relative to the current vault facts, so it is staged as an add."
        )
    }

    private func extractFacts(from body: String) -> [String] {
        body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("- ") else { return nil }
                return String(trimmed.dropFirst(2))
            }
    }

    private func renderMemoryBody(facts: [String], targetVault: VaultIdentity) -> String {
        var lines = [
            "# \(targetVault.displayName) Memory",
            "",
            "## Durable Facts",
            ""
        ]
        lines.append(contentsOf: facts.map { "- \($0)" })
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func defaultMemoryBody(for targetVault: VaultIdentity) -> String {
        renderMemoryBody(facts: [], targetVault: targetVault)
    }

    private func deleteQuery(from message: String) -> String? {
        let prefixes = ["delete:", "remove:", "forget:"]
        let lowered = message.lowercased()
        guard let prefix = prefixes.first(where: { lowered.hasPrefix($0) }) else {
            return nil
        }
        return message.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updatePair(from message: String) -> (oldValue: String, newValue: String)? {
        let components = message.components(separatedBy: "->")
        guard components.count == 2 else {
            return nil
        }
        let oldValue = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldValue.isEmpty, !newValue.isEmpty else {
            return nil
        }
        return (oldValue, newValue)
    }

    private func normalizeFact(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "- ", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func makeUnifiedDiff(old: String, new: String, relativePath: String) -> String {
        let diff = LineDiff.compute(old: old, new: new)
        var lines = [
            "--- a/\(relativePath)",
            "+++ b/\(relativePath)",
            "@@"
        ]

        for line in diff.lines {
            switch line {
            case .unchanged(let content):
                lines.append(" \(content)")
            case .added(let content):
                lines.append("+\(content)")
            case .removed(let content):
                lines.append("-\(content)")
            case .modified(let oldValue, let newValue):
                lines.append("-\(oldValue)")
                lines.append("+\(newValue)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func makeCommitMessage(
        operation: VaultMutationOperation,
        scope: String,
        relativePath: String,
        summary: String,
        source: String,
        reasoning: String?
    ) -> String {
        var lines = [
            "[\(scope):\(operation.rawValue)] \(relativePath)",
            "  - \(summary)",
            "  - source: \(source)",
            "  - strength: 1.0"
        ]

        if let reasoning, !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("  - reasoning: \(reasoning.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        return lines.joined(separator: "\n")
    }

    private func mutationOperation(old: String, new: String) -> VaultMutationOperation {
        if old == new {
            return .noop
        }
        if old.isEmpty && !new.isEmpty {
            return .add
        }
        if !old.isEmpty && new.isEmpty {
            return .delete
        }
        return .update
    }

    private func relativePath(for fileURL: URL, in repositoryRootURL: URL) throws -> String {
        let rootPath = repositoryRootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        guard filePath.hasPrefix(prefix) else {
            throw VaultChatMutatorError.fileOutsideRepositoryRoot
        }

        return String(filePath.dropFirst(prefix.count))
    }

    private func ensureGitRepository(at rootURL: URL) async throws {
        let gitDirectory = rootURL.appendingPathComponent(".git", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: gitDirectory.path) else {
            return
        }
        _ = try await runGitOffMain(arguments: ["-C", rootURL.path, "init"], in: rootURL)
    }

    private nonisolated func runGitOffMain(arguments: [String], in currentDirectoryURL: URL) async throws -> String {
        #if !EPISTEMOS_APP_STORE
        let timeoutSeconds = 15.0
        let state = ThrowingProcessContinuationState<String>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    let process = Process.init()
                    let outputPipe = Pipe()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = ["git"] + arguments
                    process.currentDirectoryURL = currentDirectoryURL
                    process.standardOutput = outputPipe
                    process.standardError = outputPipe

                    var environment = ProcessInfo.processInfo.environment
                    environment["GIT_AUTHOR_NAME"] = environment["GIT_AUTHOR_NAME"] ?? "Epistemos"
                    environment["GIT_AUTHOR_EMAIL"] = environment["GIT_AUTHOR_EMAIL"] ?? "omega@epistemos.local"
                    environment["GIT_COMMITTER_NAME"] = environment["GIT_COMMITTER_NAME"] ?? "Epistemos"
                    environment["GIT_COMMITTER_EMAIL"] = environment["GIT_COMMITTER_EMAIL"] ?? "omega@epistemos.local"
                    process.environment = environment

                    guard state.store(process: process, continuation: continuation) else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    let timeoutTask = Task.detached(priority: .utility) {
                        do {
                            try await Task.sleep(for: .seconds(timeoutSeconds))
                        } catch is CancellationError {
                            return
                        } catch {
                            VaultChatMutatorDiagnostics.log.error(
                                "VaultChatMutator: failed while waiting for git timeout: \(error.localizedDescription, privacy: .public)"
                            )
                            return
                        }
                        state.terminate()
                        state.resume(throwing: TimeoutError(seconds: timeoutSeconds))
                    }

                    process.terminationHandler = { proc in
                        timeoutTask.cancel()
                        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let text = String(decoding: data, as: UTF8.self)
                        guard proc.terminationStatus == 0 else {
                            state.resume(throwing: VaultChatMutatorError.gitCommandFailed(text))
                            return
                        }
                        state.resume(returning: text)
                    }

                    do {
                        try process.run()
                    } catch {
                        timeoutTask.cancel()
                        state.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            state.terminate()
            state.resume(throwing: CancellationError())
        }
        #else
        // Defense-in-depth. The MAS branch of `commit(diff:)` skips
        // the git layer entirely and returns a placeholder reference,
        // so this helper is never called in MAS production. Throwing
        // here protects against a future caller that wires up a path
        // bypassing the early skip.
        _ = arguments
        _ = currentDirectoryURL
        throw VaultChatMutatorError.gitCommandFailed(
            "git is not available in the App Store sandbox build; staged vault mutations are committed file-only without a git audit trail."
        )
        #endif
    }
}

struct DiffApprovalSheet: View {
    let diffResult: DiffResult
    let onApprove: () -> Void
    let onReject: () -> Void

    private var stats: DiffStats {
        LineDiff.compute(old: diffResult.before, new: diffResult.after).stats
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(diffResult.summary)
                    .font(.title3.weight(.semibold))
                Text(diffResult.relativePath)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                Text(diffResult.rationale)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label("\(stats.added) added", systemImage: "plus.circle.fill")
                    .foregroundStyle(.green)
                Label("\(stats.removed) removed", systemImage: "minus.circle.fill")
                    .foregroundStyle(.red)
                Label("\(stats.modified) modified", systemImage: "pencil.circle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.callout.weight(.medium))

            ScrollView {
                Text(diffResult.unifiedDiff)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
            }

            HStack {
                Button("Discard", role: .cancel, action: onReject)
                Spacer()
                Button("Commit Diff", action: onApprove)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 420)
    }
}
