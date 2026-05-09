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
        #expect(appSection.contains("KnowledgeFusion/.DS_Store"))
        #expect(appSection.contains("KnowledgeFusion/MOHAWK/**"))
        #expect(appSection.contains("KnowledgeFusion/Training/.DS_Store"))
        #expect(appSection.contains("Omega/Knowledge/ODIATraceGenerator.swift"))
        #expect(appSection.contains("Omega/Knowledge/TraceDataMixer.swift"))
        #expect(appSection.contains("Vault/KnowledgeGraphService.swift"))

        #expect(testsSection.contains("type: syncedFolder"))

        #expect(bindingsSection.contains("type: syncedFolder"))
        #expect(bindingsSection.contains("includes:"))
        #expect(bindingsSection.contains("*.swift"))
        #expect(!bindingsSection.contains("agent_core.swift"))
        #expect(!bindingsSection.contains("epistemos_core.swift"))
        #expect(!bindingsSection.contains("omega_ax.swift"))
        #expect(!bindingsSection.contains("omega_mcp.swift"))
    }

    @Test("generated project keeps synced roots and excludes local metadata artifacts")
    func generatedProjectKeepsSyncedRootsAndExcludesLocalMetadataArtifacts() throws {
        let pbxproj = try loadMirroredSourceTextFile("Epistemos.xcodeproj/project.pbxproj")
        #expect(pbxproj.contains("PBXFileSystemSynchronizedRootGroup"))

        let appRoot = try synchronizedRootBlock(in: pbxproj, rootPath: "Epistemos")
        let testRoot = try synchronizedRootBlock(in: pbxproj, rootPath: "EpistemosTests")
        let bindingRoot = try synchronizedRootBlock(in: pbxproj, rootPath: "build-rust/swift-bindings")
        let appExceptions = try membershipExceptions(in: pbxproj, rootPath: "Epistemos")
        let bindingExceptions = try membershipExceptions(in: pbxproj, rootPath: "build-rust/swift-bindings")

        #expect(appRoot.contains("path = Epistemos"))
        #expect(testRoot.contains("path = EpistemosTests"))
        #expect(bindingRoot.contains("path = \"build-rust/swift-bindings\""))
        #expect(appExceptions.contains("KnowledgeFusion/.DS_Store"))
        #expect(appExceptions.contains("KnowledgeFusion/Training/.DS_Store"))
        #expect(appExceptions.contains("KnowledgeFusion/MoLoRA/__pycache__/molora_inference.cpython-312.pyc"))
        #expect(appExceptions.contains("KnowledgeFusion/MoLoRA/__pycache__/sgmm_kernel.cpython-312.pyc"))
        #expect(bindingExceptions == ["omega_ax.swift"])
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
        let rootBlock = try synchronizedRootBlock(in: pbxproj, rootPath: rootPath)
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
            let block = try exceptionSetBlock(in: pbxproj, exceptionID: exceptionID)
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
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }

            entries.formUnion(members)
        }

        return entries
    }

    private func synchronizedRootBlock(in pbxproj: String, rootPath: String) throws -> String {
        let marker = "/* \(rootPath) */ = {"
        var searchStart = pbxproj.startIndex
        while let startRange = pbxproj.range(of: marker, range: searchStart..<pbxproj.endIndex) {
            let candidate = pbxproj[startRange.lowerBound...]
            guard let endRange = candidate.range(of: "\n\t\t};") else {
                throw InclusionError.malformedProjectBlock(rootPath)
            }
            let block = String(candidate[..<endRange.upperBound])
            if block.contains("isa = PBXFileSystemSynchronizedRootGroup;") {
                return block
            }
            searchStart = startRange.upperBound
        }

        throw InclusionError.missingProjectEntry(rootPath)
    }

    private func exceptionSetBlock(in pbxproj: String, exceptionID: String) throws -> String {
        let marker = "\t\t\(exceptionID) "
        var searchStart = pbxproj.startIndex
        while let startRange = pbxproj.range(of: marker, range: searchStart..<pbxproj.endIndex) {
            let candidate = pbxproj[startRange.lowerBound...]
            guard let endRange = candidate.range(of: "\n\t\t};") else {
                throw InclusionError.malformedProjectBlock(exceptionID)
            }
            let block = String(candidate[..<endRange.upperBound])
            if block.contains("isa = PBXFileSystemSynchronizedBuildFileExceptionSet;") {
                return block
            }
            searchStart = startRange.upperBound
        }

        throw InclusionError.missingProjectEntry(exceptionID)
    }

}

private enum InclusionError: Error {
    case missingSourcePath(String)
    case missingProjectEntry(String)
    case malformedProjectBlock(String)
}
