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

    @Test("artifact directory scan rejects symlinked falsifier directories")
    func artifactDirectoryScanRejectsSymlinkedFalsifierDirectories() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let real = root.appendingPathComponent("real", isDirectory: true)
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        let linked = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: outside)

        let dirs = FalsifierArtifactResultReader.artifactDirectories(in: root)
            .map(\.lastPathComponent)

        #expect(dirs == ["real"])
    }

    @Test("falsifier artifact row source keeps no-follow bounded result reads")
    func falsifierArtifactRowSourceKeepsNoFollowBoundedResultReads() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/FalsifierArtifactsHealthRow.swift")

        for required in [
            "nonisolated enum FalsifierArtifactResultReader",
            "maxResultBytes",
            "artifactDirectories(in: root, fileManager: fm)",
            "destinationOfSymbolicLink(atPath:",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "fstat(fd",
            "S_IFREG",
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
