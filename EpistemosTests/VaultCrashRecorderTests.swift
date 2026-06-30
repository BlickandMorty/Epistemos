import Foundation
import Testing

@testable import Epistemos

@Suite("Vault crash recorder")
nonisolated struct VaultCrashRecorderTests {
    @Test("vault diagnostics are written under epcache diagnostics")
    func vaultDiagnosticsDirectoryUsesEpcacheDiagnostics() throws {
        let vaultURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultURL.deletingLastPathComponent()) }

        let diagnosticsURL = try VaultCrashRecorder.diagnosticsDirectory(vaultURL: vaultURL)

        #expect(diagnosticsURL == vaultURL
            .appendingPathComponent(".epcache", isDirectory: true)
            .appendingPathComponent("diagnostics", isDirectory: true))
    }

    @Test("prepare writes ready marker into vault diagnostics")
    func prepareWritesReadyMarkerIntoVaultDiagnostics() throws {
        let vaultURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultURL.deletingLastPathComponent()) }

        let diagnosticsURL = try VaultCrashRecorder.prepareDiagnosticsDirectory(
            vaultURL: vaultURL,
            now: Date(timeIntervalSince1970: 1_782_828_000)
        )
        let markerURL = diagnosticsURL.appendingPathComponent("crash-recorder-ready.json", isDirectory: false)

        #expect(FileManager.default.fileExists(atPath: markerURL.path))

        let payload = try JSONSerialization.jsonObject(with: Data(contentsOf: markerURL)) as? [String: Any]
        #expect(payload?["signalLog"] as? String == "fatal-signals.log")
        #expect(payload?["vaultPath"] as? String == vaultURL.path)
    }

    @Test("launch and vault switch wiring stay installed")
    func launchAndVaultSwitchWiringStayInstalled() throws {
        let appSource = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")
        let vaultSource = try loadMirroredSourceTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(appSource.contains("VaultCrashRecorder.install(vaultURL: bootstrap.vaultSync.vaultURL)"))
        #expect(appSource.contains("VaultCrashRecorder.recordUncaughtException("))
        #expect(vaultSource.contains("VaultCrashRecorder.updateVaultURL(vaultURL)"))
        #expect(vaultSource.contains("VaultCrashRecorder.updateVaultURL(nil)"))
    }

    private func makeTemporaryVault() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-crash-recorder-tests-\(UUID().uuidString)", isDirectory: true)
        let vaultURL = root.appendingPathComponent("Vault", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        return vaultURL
    }
}
