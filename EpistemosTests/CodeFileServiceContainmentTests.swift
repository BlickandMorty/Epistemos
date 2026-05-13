import Testing
import Foundation
@testable import Epistemos

/// RCA2-P0-002 drift gate — `CodeFileService` must canonicalize +
/// containment-check every URL it touches against the vault root.
/// Escapes (`..`, absolute paths outside the vault, symlink chains
/// pointing out of the vault) must fail closed with
/// `ServiceError.pathEscapesVault` — never produce a partial
/// filesystem mutation outside the vault.
///
/// The structural defenses are already in place (see
/// `CodeFileService.containedSourceURL(_:)` + `vaultRelativePath`)
/// since the W7 hardening pass. This suite pins the invariant so a
/// future refactor that loosens the predicate (e.g. drops the
/// `hasPrefix(rootPath)` check, or stops resolving symlinks before
/// the prefix test) trips CI before a path-traversal bug ships.
///
/// Doctrine: every test creates a sandboxed temp vault root + a
/// sibling "escape" directory, then attempts to read/update/create
/// across the boundary. Each escape vector gets one test; a future
/// commit that bypasses any one of them will fail exactly that
/// case in CI.
@Suite("RCA2-P0-002 CodeFileService Vault Containment")
@MainActor
struct CodeFileServiceContainmentTests {

    /// Build a sandboxed vault root and a sibling "escape" directory
    /// for each test. Both go inside the test's own temp folder so
    /// the cleanup `try? remove(at:)` doesn't touch anything outside.
    private func makeSandbox() throws -> (vault: URL, escape: URL, cleanup: () -> Void) {
        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("rca2-p0-002-\(UUID().uuidString)", isDirectory: true)
        let vault = testRoot.appendingPathComponent("vault", isDirectory: true)
        let escape = testRoot.appendingPathComponent("escape", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: escape, withIntermediateDirectories: true)
        return (vault, escape, {
            try? FileManager.default.removeItem(at: testRoot)
        })
    }

    @Test("readCodeFile rejects an absolute path outside the vault root")
    func readRejectsAbsoluteOutsideVault() throws {
        let sb = try makeSandbox()
        defer { sb.cleanup() }
        let service = CodeFileService(vaultRoot: sb.vault)

        // Put a real file in the escape dir so file-not-found can't
        // mask the containment check.
        let escapeFile = sb.escape.appendingPathComponent("secret.swift")
        try Data("escape contents".utf8).write(to: escapeFile)

        do {
            _ = try service.readCodeFile(at: escapeFile)
            Issue.record("Expected pathEscapesVault, got success — RCA2-P0-002 regression: a file outside the vault was readable via CodeFileService")
        } catch let error as CodeFileService.ServiceError {
            if case .pathEscapesVault = error {
                // Expected.
            } else {
                Issue.record("Expected pathEscapesVault, got \(error)")
            }
        } catch {
            Issue.record("Expected pathEscapesVault, got \(error)")
        }
    }

    @Test("readCodeFile rejects `..`-style traversal that resolves outside the vault")
    func readRejectsParentTraversal() throws {
        let sb = try makeSandbox()
        defer { sb.cleanup() }
        let service = CodeFileService(vaultRoot: sb.vault)

        let escapeFile = sb.escape.appendingPathComponent("secret.swift")
        try Data("escape contents".utf8).write(to: escapeFile)
        // Build a URL that walks out of the vault: vault/../escape/secret.swift
        let traversalURL = sb.vault
            .appendingPathComponent("..")
            .appendingPathComponent("escape")
            .appendingPathComponent("secret.swift")

        do {
            _ = try service.readCodeFile(at: traversalURL)
            Issue.record("`..` traversal must fail closed; got success — RCA2-P0-002 regression")
        } catch let error as CodeFileService.ServiceError {
            if case .pathEscapesVault = error {
                // Expected — the standardizedFileURL normalization
                // collapses `..` and the prefix check catches the
                // out-of-vault target.
            } else {
                Issue.record("Expected pathEscapesVault for `..` traversal, got \(error)")
            }
        } catch {
            Issue.record("Expected pathEscapesVault for `..` traversal, got \(error)")
        }
    }

    @Test("updateCodeFile rejects an absolute path outside the vault root")
    func updateRejectsAbsoluteOutsideVault() throws {
        let sb = try makeSandbox()
        defer { sb.cleanup() }
        let service = CodeFileService(vaultRoot: sb.vault)

        // Pre-create a file outside the vault so we'd be overwriting
        // a real target if the containment check were missing.
        let escapeFile = sb.escape.appendingPathComponent("target.swift")
        try Data("untouched".utf8).write(to: escapeFile)

        do {
            try service.updateCodeFile(at: escapeFile, body: "INJECTED")
            Issue.record("Update outside vault must fail closed; got success — RCA2-P0-002 regression")
        } catch let error as CodeFileService.ServiceError {
            if case .pathEscapesVault = error {
                // Expected.
            } else {
                Issue.record("Expected pathEscapesVault, got \(error)")
            }
        } catch {
            Issue.record("Expected pathEscapesVault, got \(error)")
        }
        // Defense check: the escape file must still hold its original
        // bytes. If a partial write happened before the predicate
        // fired, the contents would be "INJECTED".
        let body = try String(contentsOf: escapeFile, encoding: .utf8)
        #expect(body == "untouched",
            "Containment must fail closed BEFORE any filesystem mutation — see RCA2-P0-002")
    }

    @Test("readCodeFile resolves symlink that points outside the vault and rejects it")
    func readRejectsSymlinkEscape() throws {
        let sb = try makeSandbox()
        defer { sb.cleanup() }
        let service = CodeFileService(vaultRoot: sb.vault)

        // Real file in the escape dir.
        let escapeFile = sb.escape.appendingPathComponent("secret.swift")
        try Data("escape contents".utf8).write(to: escapeFile)

        // Symlink inside the vault that points OUT of the vault.
        let symlinkInVault = sb.vault.appendingPathComponent("link.swift")
        try FileManager.default.createSymbolicLink(
            at: symlinkInVault,
            withDestinationURL: escapeFile
        )

        do {
            _ = try service.readCodeFile(at: symlinkInVault)
            Issue.record("Symlink-escape read must fail closed; got success — RCA2-P0-002 regression")
        } catch let error as CodeFileService.ServiceError {
            if case .pathEscapesVault = error {
                // Expected — `resolvingSymlinksInPath` resolves the
                // symlink target before the containment check fires.
            } else {
                Issue.record("Expected pathEscapesVault for symlink escape, got \(error)")
            }
        } catch {
            Issue.record("Expected pathEscapesVault for symlink escape, got \(error)")
        }
    }

    @Test("Source-grep pin: CodeFileService retains the canonical containment helpers")
    func sourceDoctrinePin() throws {
        // If a future refactor renames or removes
        // `containedSourceURL` / `pathEscapesVault`, the structural
        // defense is gone and these tests would all start
        // false-negative. Pin the symbol names so a renaming commit
        // surfaces in code review.
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Engine/CodeFileService.swift"
        )
        #expect(source.contains("private func containedSourceURL"),
            "CodeFileService must retain the containedSourceURL containment helper — see RCA2-P0-002")
        #expect(source.contains("pathEscapesVault"),
            "CodeFileService.ServiceError must retain the pathEscapesVault case as the canonical denial signal — see RCA2-P0-002")
        #expect(source.contains("resolvingSymlinksInPath"),
            "CodeFileService must keep resolving symlinks before the containment check so symlink-escape attempts fail closed — see RCA2-P0-002")
    }
}
