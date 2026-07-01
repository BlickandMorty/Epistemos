import Foundation
import Testing
@testable import Epistemos

@Suite("Falsifier artifacts health row hardening")
struct FalsifierArtifactsHealthRowTests {
    @Test("result reader parses bounded regular JSON artifacts")
    func resultReaderParsesBoundedRegularJSONArtifacts() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = root.appendingPathComponent("result.json")
        try """
        {"falsifier_id":"probe","overall_pass":true,"artifact_kind":"primary_witness"}
        """.write(to: result, atomically: true, encoding: .utf8)

        let json = try #require(FalsifierArtifactResultReader.jsonObject(at: result))
        #expect(json["falsifier_id"] as? String == "probe")
        #expect(json["overall_pass"] as? Bool == true)
    }

    @Test("result reader rejects oversized artifacts before JSON parsing")
    func resultReaderRejectsOversizedArtifactsBeforeJSONParsing() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = root.appendingPathComponent("result.json")
        let oversized = Data(repeating: 0x7B, count: FalsifierArtifactResultReader.maxResultBytes + 1)
        try oversized.write(to: result)

        #expect(FalsifierArtifactResultReader.resultData(at: result) == nil)
        #expect(FalsifierArtifactResultReader.jsonObject(at: result) == nil)
    }

    @Test("result reader rejects final symlink artifacts")
    func resultReaderRejectsFinalSymlinkArtifacts() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let outside = root.appendingPathComponent("outside.json")
        let result = root.appendingPathComponent("result.json")
        try #"{"overall_pass":true}"#.write(to: outside, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: result, withDestinationURL: outside)

        #expect(FalsifierArtifactResultReader.resultData(at: result) == nil)
        #expect(FalsifierArtifactResultReader.jsonObject(at: result) == nil)
    }

    @Test("result reader rejects hardlinked artifacts")
    func resultReaderRejectsHardlinkedArtifacts() throws {
        let root = try temporaryDirectory()
        let artifact = root.appendingPathComponent("artifact", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        let result = artifact.appendingPathComponent("result.json")
        let alias = root.appendingPathComponent("alias.json")
        try #"{"overall_pass":true}"#.write(to: result, atomically: true, encoding: .utf8)
        guard (try? FileManager.default.linkItem(at: result, to: alias)) != nil else {
            return
        }

        #expect(FalsifierArtifactResultReader.resultData(at: result) == nil)
        #expect(FalsifierArtifactResultReader.jsonObject(at: result) == nil)
        #expect(FalsifierArtifactResultReader.artifactDirectories(in: root).isEmpty)
    }

    @Test("artifact directory scan rejects symlinked falsifier directories")
    func artifactDirectoryScanRejectsSymlinkedFalsifierDirectories() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let real = root.appendingPathComponent("real", isDirectory: true)
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        let linked = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try #"{"overall_pass":true}"#.write(
            to: real.appendingPathComponent("result.json"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: outside)

        let dirs = FalsifierArtifactResultReader.artifactDirectories(in: root)
            .map(\.lastPathComponent)

        #expect(dirs == ["real"])
    }

    @Test("artifact directory scan requires result files and caps shallow enumeration")
    func artifactDirectoryScanRequiresResultsAndCapsEnumeration() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let missingResult = root.appendingPathComponent("missing-result", isDirectory: true)
        try FileManager.default.createDirectory(at: missingResult, withIntermediateDirectories: true)

        for index in 0..<(FalsifierArtifactResultReader.maxArtifactDirectories + 5) {
            let dir = root.appendingPathComponent("artifact-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try #"{"overall_pass":true}"#.write(
                to: dir.appendingPathComponent("result.json"),
                atomically: true,
                encoding: .utf8
            )
        }

        let dirs = FalsifierArtifactResultReader.artifactDirectories(in: root)

        #expect(dirs.count == FalsifierArtifactResultReader.maxArtifactDirectories)
        #expect(!dirs.map(\.lastPathComponent).contains("missing-result"))
    }

    @Test("falsifier artifact row source keeps no-follow bounded result reads")
    func falsifierArtifactRowSourceKeepsNoFollowBoundedResultReads() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/FalsifierArtifactsHealthRow.swift")

        for required in [
            "nonisolated enum FalsifierArtifactResultReader",
            "maxArtifactDirectories",
            "maxArtifactDirectoryCandidates",
            "maxResultBytes",
            "artifactDirectories(in: root, fileManager: fm)",
            "enumerator(",
            "inspectedCandidates < maxArtifactDirectoryCandidates",
            "dirs.count < maxArtifactDirectories",
            "hasReadableResultFile",
            "destinationOfSymbolicLink(atPath:",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "fstat(fd",
            "S_IFREG",
            "st_nlink <= 1",
            "readToEnd()",
            "data.count <= maxResultBytes"
        ] {
            #expect(source.contains(required), "missing falsifier artifact hardening marker: \(required)")
        }

        #expect(!source.contains("Data(contentsOf: resultPath)"))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("falsifier-artifact-row-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
