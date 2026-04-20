import Foundation
import Testing
@testable import Epistemos

@Suite("Project Inclusion")
struct ProjectInclusionTests {
    @Test("project config uses synced folders for auto-managed source roots")
    func projectConfigUsesSyncedFoldersForAutoManagedSourceRoots() throws {
        let projectYAML = try loadMirroredSourceTextFile("project.yml")
        let appSection = try sourceSection(in: projectYAML, path: "Epistemos")
        let testsSection = try sourceSection(in: projectYAML, path: "EpistemosTests")
        let bindingsSection = try sourceSection(in: projectYAML, path: "build-rust/swift-bindings")

        #expect(appSection.contains("type: syncedFolder"))
        #expect(appSection.contains("Engine/ClaudeManagedRuntime.swift"))
        #expect(appSection.contains("Engine/LocalRustRuntime.swift"))
        #expect(appSection.contains("KnowledgeFusion/MOHAWK/**"))
        #expect(appSection.contains("Omega/Knowledge/ODIATraceGenerator.swift"))
        #expect(appSection.contains("Omega/Knowledge/TraceDataMixer.swift"))
        #expect(appSection.contains("Vault/KnowledgeGraphService.swift"))

        #expect(testsSection.contains("type: syncedFolder"))

        #expect(bindingsSection.contains("type: syncedFolder"))
        #expect(bindingsSection.contains("includes:"))
        #expect(bindingsSection.contains("*.swift"))

        for path in try currentGeneratedBindingSwiftFiles() {
            #expect(!bindingsSection.contains(path))
        }
    }

    @Test("generated project includes every live app, test, and binding source file via synced roots")
    func generatedProjectIncludesEveryLiveSourceFileViaSyncedRoots() throws {
        let pbxproj = try loadMirroredSourceTextFile("Epistemos.xcodeproj/project.pbxproj")
        #expect(pbxproj.contains("PBXFileSystemSynchronizedRootGroup"))

        let appExceptions = try membershipExceptions(in: pbxproj, rootPath: "Epistemos")
        let testExceptions = try membershipExceptions(in: pbxproj, rootPath: "EpistemosTests")
        let bindingExceptions = try membershipExceptions(in: pbxproj, rootPath: "build-rust/swift-bindings")

        let missing = try expectedProjectRelativePaths().filter { relativePath in
            if let relativeToRoot = relativePath.removingPrefix("Epistemos/") {
                return appExceptions.contains(relativeToRoot)
            }

            if let relativeToRoot = relativePath.removingPrefix("EpistemosTests/") {
                return testExceptions.contains(relativeToRoot)
            }

            if let relativeToRoot = relativePath.removingPrefix("build-rust/swift-bindings/") {
                return bindingExceptions.contains(relativeToRoot)
            }

            return true
        }

        #expect(missing.isEmpty)
    }

    private func expectedProjectRelativePaths() throws -> [String] {
        let includedExtensions = Set(["swift", "m", "mm", "h", "metal", "plist", "xcprivacy"])

        var results: [String] = []

        for base in ["Epistemos", "EpistemosTests"] {
            let mirroredURLs = try mirroredSourceFileURLs(
                under: base,
                includingExtensions: includedExtensions
            )

            for fileURL in mirroredURLs {
                let relativePath = normalizedProjectRelativePath(for: fileURL)
                if shouldExcludeFromProject(relativePath) {
                    continue
                }
                results.append(relativePath)
            }
        }

        results.append(contentsOf: try currentGeneratedBindingSwiftFiles())
        return results.sorted()
    }

    private func currentGeneratedBindingSwiftFiles() throws -> [String] {
        let urls = try mirroredSourceFileURLs(
            under: "build-rust/swift-bindings",
            includingExtensions: ["swift"]
        )

        return urls
            .map(normalizedProjectRelativePath(for:))
            .sorted()
    }

    private func normalizedProjectRelativePath(for fileURL: URL) -> String {
        let path = fileURL.path

        for root in ["Epistemos/", "EpistemosTests/", "build-rust/swift-bindings/"] {
            if let range = path.range(of: root) {
                return String(path[range.lowerBound...])
            }
            if let range = path.range(of: "/\(root)") {
                return String(path[path.index(after: range.lowerBound)...])
            }
        }

        return fileURL.lastPathComponent
    }

    private func sourceSection(in projectYAML: String, path: String) throws -> String {
        let lines = projectYAML.components(separatedBy: .newlines)

        guard let startIndex = lines.firstIndex(where: { $0.contains("- path: \(path)") }) else {
            throw InclusionError.missingSourcePath(path)
        }

        let endIndex = lines[(startIndex + 1)...].firstIndex(where: {
            $0.hasPrefix("      - path:") || $0.hasPrefix("    resources:") || $0.hasPrefix("    settings:") || $0.hasPrefix("    dependencies:")
        }) ?? lines.endIndex
        return lines[startIndex..<endIndex].joined(separator: "\n")
    }

    private func membershipExceptions(in pbxproj: String, rootPath: String) throws -> Set<String> {
        let rootBlock = try pbxprojBlock(
            in: pbxproj,
            pattern: #"[A-F0-9]+ /\* .*? \*/ = \{\s*isa = PBXFileSystemSynchronizedRootGroup;.*?path = \#(NSRegularExpression.escapedPattern(for: quotedIfNeeded(rootPath)));\s*sourceTree = "<group>";\s*\};"#
        )
        guard let exceptionsRange = rootBlock.range(of: "exceptions = (") else {
            return []
        }

        let exceptionList = rootBlock[exceptionsRange.upperBound...]
        guard let endRange = exceptionList.range(of: ");") else {
            return []
        }

        let exceptionIDs = exceptionList[..<endRange.lowerBound]
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else { return nil }
                return trimmed.components(separatedBy: .whitespaces).first
            }

        var entries: Set<String> = []
        for exceptionID in exceptionIDs {
            let block = try pbxprojBlock(
                in: pbxproj,
                pattern: #"\#(NSRegularExpression.escapedPattern(for: exceptionID)) /\* .*? \*/ = \{\s*isa = PBXFileSystemSynchronizedBuildFileExceptionSet;.*?\};"#
            )
            guard let membershipRange = block.range(of: "membershipExceptions = (") else {
                continue
            }

            let membershipList = block[membershipRange.upperBound...]
            guard let membershipEndRange = membershipList.range(of: ");") else {
                continue
            }

            let members = membershipList[..<membershipEndRange.lowerBound]
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
                .map { $0.replacingOccurrences(of: ",", with: "") }

            entries.formUnion(members)
        }

        return entries
    }

    private func pbxprojBlock(in pbxproj: String, pattern: String) throws -> String {
        let expression = try NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        )
        let range = NSRange(pbxproj.startIndex..<pbxproj.endIndex, in: pbxproj)

        guard let match = expression.firstMatch(in: pbxproj, options: [], range: range),
              let matchRange = Range(match.range, in: pbxproj) else {
            throw InclusionError.missingProjectEntry(pattern)
        }

        return String(pbxproj[matchRange])
    }

    private func quotedIfNeeded(_ path: String) -> String {
        path.contains("/") ? "\"\(path)\"" : path
    }

    private func shouldExcludeFromProject(_ relativePath: String) -> Bool {
        if relativePath.hasPrefix("Epistemos/KnowledgeFusion/MOHAWK/") {
            return true
        }

        return [
            "Epistemos/Engine/ClaudeManagedRuntime.swift",
            "Epistemos/Engine/LocalRustRuntime.swift",
            "Epistemos/Omega/Knowledge/ODIATraceGenerator.swift",
            "Epistemos/Omega/Knowledge/TraceDataMixer.swift",
            "Epistemos/Vault/KnowledgeGraphService.swift",
        ].contains(relativePath)
    }

}

private enum InclusionError: Error {
    case missingSourcePath(String)
    case missingProjectEntry(String)
    case malformedProjectBlock(String)
}

private extension String {
    func removingPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}
