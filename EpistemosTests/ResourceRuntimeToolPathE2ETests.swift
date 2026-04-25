import Foundation
import Testing
@testable import Epistemos

// MARK: - Phase R.4-R.7 -- End-to-End Tool-Path Runtime Regressions
//
// Real-runtime E2E proofs for the Swift side of the tool pipeline:
// - I-004 / I-005 / I-006: Live attachment writes through the actual
//   tool execution path, not a direct ResourceService.write() call.
// - I-007 / I-008: "AI lies about writes" / "success before durable
//   commit" -- proven at the tool-execute surface by asserting the
//   returned payload has `"verified": true` and the disk bytes match.
// - I-014: post-revoke denial smoke. Grant -> tool call succeeds ->
//   revoke -> the NEXT tool call on the same resource is denied.
//   This is a sequential check, not a true concurrent in-flight
//   cancellation test. A separate concurrency test could later prove
//   revocation seen by an already-executing call; that is out of
//   scope for this regression.
//
// Why a separate file from ResourceRuntimeRegressionTests:
// R.9 covers the 8 canonical ResourceService-level assertions. This
// file covers the tool execution path: `execute_tool_call` reaching
// `ToolRegistry::execute` reaching the R.5 gate reaching
// `write_file` / `patch` / `vault_write` handlers reaching the Phase
// R.6 verified_write pipeline. A future refactor of the tool
// registry should surface here, not inside R.9.
//
// Plan refs: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md Phase R.4-R.7,
// docs/KNOWN_ISSUES_REGISTER.md I-004, I-005, I-006, I-007, I-008, I-014.
//
// Note: the permission store is a process-local singleton. Every test
// here seeds a unique vault dir and unique resource URI so its grants
// do not collide with residue from other suites running in the same
// xctest process. Revoke at the end of every test so subsequent
// r5_gate / default-enforcement assertions remain stable.

@Suite("Phase R.4-R.7 -- Tool Path E2E")
struct ResourceRuntimeToolPathE2ETests {

    // MARK: - Scratch vault helper

    /// Matches the Rust pattern in `agent_core/src/tools/registry.rs`
    /// tests: the vault_id baked into the grant URI is the last
    /// component of vault_root. `VaultStore::open` derives the same
    /// value, so the URI format stays stable across Rust and Swift.
    private struct ScratchVault {
        let rootURL: URL
        let vaultId: String
    }

    enum E2EError: Error {
        case grantFailed
        case jsonEncodingFailed(String)
    }

    private func makeScratchVault(label: String) throws -> ScratchVault {
        let vaultDirName = "e2e-\(label)-\(UUID().uuidString)"
        let parent = FileManager.default.temporaryDirectory
        let rootURL = parent.appendingPathComponent(vaultDirName)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let inbox = rootURL.appendingPathComponent("Inbox")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        return ScratchVault(rootURL: rootURL, vaultId: vaultDirName)
    }

    private func cleanup(_ vault: ScratchVault) {
        try? FileManager.default.removeItem(at: vault.rootURL)
    }

    private func vaultNoteURI(_ vault: ScratchVault, relativePath: String) -> String {
        "vault://\(vault.vaultId)/note/\(relativePath)"
    }

    /// Safely encode a JSON object to a UTF-8 string. Throws instead
    /// of force-unwrapping so a future dictionary shape that cannot be
    /// serialized surfaces as a test failure message, not a crash.
    private func encodeJSONObject(_ obj: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
        guard let str = String(data: data, encoding: .utf8) else {
            throw E2EError.jsonEncodingFailed("JSON data was not valid UTF-8")
        }
        return str
    }

    private func vaultWriteInputJSON(relativePath: String, content: String) throws -> String {
        // Matches the shape the Rust tool handler accepts in
        // `agent_core/src/tools/registry.rs` (fn vault_write_input at
        // about L3068). `skip_contradiction_check` avoids wiring the
        // learning protocol into this plain E2E regression.
        let obj: [String: Any] = [
            "path": relativePath,
            "content": content,
            "skip_contradiction_check": true,
        ]
        return try encodeJSONObject(obj)
    }

    private func writeFileInputJSON(path: String, content: String) throws -> String {
        let obj: [String: Any] = [
            "path": path,
            "content": content,
        ]
        return try encodeJSONObject(obj)
    }

    private func seedGrant(uri: String, capabilities: [String]) async throws -> String {
        guard let grantID = await permissionStoreRecordUserGrantFromStatement(
            statement: "You have my permission to edit this note.",
            resourceUri: uri,
            capabilityNames: capabilities,
            scopeName: "Session"
        ) else {
            Issue.record("grant statement should mint a stored grant")
            throw E2EError.grantFailed
        }
        return grantID
    }

    // MARK: - I-004 / I-005 / I-006 / I-007 / I-008
    //         Live vault note write succeeds and the file on disk
    //         changes and the tool payload reports verified=true.

    @Test("vault_write through executeToolCall changes real file and reports verified=true (I-004..I-008)")
    func vaultWriteThroughToolPathChangesRealFileAndReportsVerified() async throws {
        let vault = try makeScratchVault(label: "vault-write-ok")
        defer { cleanup(vault) }

        let relativePath = "Inbox/Granted-\(UUID().uuidString).md"
        let uri = vaultNoteURI(vault, relativePath: relativePath)

        // Grant Write on the exact resource the tool will target.
        let grantID = try await seedGrant(uri: uri, capabilities: ["Read", "Write"])

        // Fire the real tool path ChatCoordinator uses.
        let payload = "body written through the real runtime path"
        let result = try await executeToolCall(
            vaultPath: vault.rootURL.path,
            tier: "agent",
            toolName: "vault_write",
            inputJson: try vaultWriteInputJSON(relativePath: relativePath, content: payload)
        )

        #expect(result.success, "tool must report success for granted write, error=\(result.error ?? "nil")")
        #expect(result.error == nil, "no error on granted write")

        // Tool-payload contract: the handler returns `"verified": true`
        // after reading back the durable bytes (I-007/I-008 fix).
        if let json = result.outputJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: json) as? [String: Any] {
            #expect(parsed["path"] as? String == relativePath,
                    "output must echo the relative path")
            #expect(parsed["verified"] as? Bool == true,
                    "output must include verified=true (I-007/I-008 contract)")
        } else {
            Issue.record("outputJson must be a valid JSON object: \(result.outputJson)")
        }

        // Durable-bytes proof (I-007 anti-lying contract).
        let onDiskURL = vault.rootURL.appendingPathComponent(relativePath)
        let onDiskText = try String(contentsOf: onDiskURL, encoding: .utf8)
        #expect(onDiskText.contains(payload),
                "real file must reflect the body written by the tool")

        // Housekeeping: do not leak grants into sibling tests.
        _ = await permissionStoreRevoke(grantId: grantID)
    }

    // MARK: - I-014 post-revoke denial
    //         Grant -> tool call succeeds. Revoke. The NEXT tool call
    //         fails with a permission error and leaves disk unchanged.
    //         This is sequential, not a concurrent in-flight test.

    @Test("revoking a grant denies the next tool call on the same resource (I-014 post-revoke denial)")
    func revokingGrantDeniesNextToolCall() async throws {
        let vault = try makeScratchVault(label: "revoke-denies")
        defer { cleanup(vault) }

        let relativePath = "Inbox/Revoked-\(UUID().uuidString).md"
        let uri = vaultNoteURI(vault, relativePath: relativePath)

        // Baseline: grant and prove the tool path works.
        let grantID = try await seedGrant(uri: uri, capabilities: ["Read", "Write"])

        let firstPayload = "first body before revoke"
        let firstCall = try await executeToolCall(
            vaultPath: vault.rootURL.path,
            tier: "agent",
            toolName: "vault_write",
            inputJson: try vaultWriteInputJSON(relativePath: relativePath, content: firstPayload)
        )
        #expect(firstCall.success, "first call with grant must succeed: \(firstCall.error ?? "nil")")
        let firstOnDisk = try String(
            contentsOf: vault.rootURL.appendingPathComponent(relativePath),
            encoding: .utf8
        )
        #expect(firstOnDisk.contains(firstPayload))

        // Revoke between calls (sequential, not concurrent).
        let revoked = await permissionStoreRevoke(grantId: grantID)
        #expect(revoked, "revoke must succeed for a valid active grant id")

        // Second call: same tool, same resource, no grant.
        let secondPayload = "second body after revoke must not land"
        let secondCall = try await executeToolCall(
            vaultPath: vault.rootURL.path,
            tier: "agent",
            toolName: "vault_write",
            inputJson: try vaultWriteInputJSON(relativePath: relativePath, content: secondPayload)
        )

        #expect(!secondCall.success, "revoked grant must deny the follow-up write")
        #expect(secondCall.error != nil, "denial must surface an error string")
        if let err = secondCall.error {
            // The Rust gate emits PermissionDenied; the error string
            // should surface that clearly enough for a user-facing UI
            // to explain why the call stopped.
            #expect(err.lowercased().contains("permission") || err.lowercased().contains("denied"),
                    "error must name the permission/denial class, got: \(err)")
        }

        // Durable-bytes proof: the second payload must not be on disk.
        let finalOnDisk = try String(
            contentsOf: vault.rootURL.appendingPathComponent(relativePath),
            encoding: .utf8
        )
        #expect(!finalOnDisk.contains(secondPayload),
                "revoked write must not reach disk")
        #expect(finalOnDisk.contains(firstPayload),
                "pre-revoke content must remain intact")
    }

    // MARK: - I-014 / I-009 default-on gate
    //         Default-on enforcement: tool call denied when no grant
    //         exists for the target resource. Mirrors the Rust test
    //         r5_gate_denies_vault_write_by_default_when_grants_exist_
    //         but_not_for_this_resource at agent_core/src/tools/
    //         registry.rs:3114 so the Swift FFI path surfaces the
    //         same semantic.

    @Test("default-on enforcement denies vault_write without a matching grant (I-014 default gate)")
    func defaultEnforcementDeniesVaultWriteWithoutMatchingGrant() async throws {
        let vault = try makeScratchVault(label: "default-deny")
        defer { cleanup(vault) }

        let relativePath = "Inbox/NoGrant-\(UUID().uuidString).md"

        // Seed a grant on an unrelated resource. This is the exact
        // scenario where early drafts of the gate would incorrectly
        // allow (any grant treated as a blanket "store is not empty"
        // pass). The default-on flip fixed that.
        let unrelatedURI = "vault://e2e-unrelated-\(UUID().uuidString)/note/Inbox/Decoy.md"
        let unrelatedGrant = try await seedGrant(uri: unrelatedURI, capabilities: ["Write"])

        let result = try await executeToolCall(
            vaultPath: vault.rootURL.path,
            tier: "agent",
            toolName: "vault_write",
            inputJson: try vaultWriteInputJSON(relativePath: relativePath, content: "should not land")
        )

        #expect(!result.success,
                "ungranted write must be denied under default-on enforcement")
        if let err = result.error {
            #expect(err.lowercased().contains("permission") || err.lowercased().contains("denied"),
                    "denial error must name permission/denied, got: \(err)")
        }

        // File must not exist, or must not contain the rejected payload.
        let onDiskURL = vault.rootURL.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: onDiskURL.path) {
            let text = try String(contentsOf: onDiskURL, encoding: .utf8)
            #expect(!text.contains("should not land"),
                    "rejected write must not reach disk even as partial bytes")
        }

        _ = await permissionStoreRevoke(grantId: unrelatedGrant)
    }

    // MARK: - I-005 / I-006
    //         write_file tool (distinct from vault_write) for an
    //         attached file (Finder-drag) or code file. Proves the
    //         file:// branch of the tool-path pipeline hardens the
    //         same way as the vault-note branch.

    @Test("write_file through executeToolCall edits real file when granted (I-005/I-006)")
    func writeFileThroughToolPathEditsRealFile() async throws {
        // Scratch dir (not a vault; arbitrary file target, like a
        // Finder-attached code file the user dropped into the composer).
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-write-file-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let targetURL = tmp.appendingPathComponent("attached_code_file.swift")
        try "// original header\n".write(to: targetURL, atomically: true, encoding: .utf8)

        let fileURI = "file://\(targetURL.path)"
        let grantID = try await seedGrant(uri: fileURI, capabilities: ["Read", "Write"])

        let newContent = "// edited by the tool path -- \(UUID().uuidString)\n"
        let inputJSON = try writeFileInputJSON(path: targetURL.path, content: newContent)

        let result = try await executeToolCall(
            vaultPath: tmp.path,
            tier: "full",
            toolName: "write_file",
            inputJson: inputJSON
        )

        #expect(result.success, "granted write_file must succeed, error=\(result.error ?? "nil")")
        #expect(result.error == nil)

        // Disk-truth proof.
        let onDisk = try String(contentsOf: targetURL, encoding: .utf8)
        #expect(onDisk == newContent,
                "write_file handler must land exact bytes on disk through the tool path")

        // Tool-payload verified contract.
        if let data = result.outputJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            #expect(parsed["verified"] as? Bool == true,
                    "write_file output must include verified=true")
        } else {
            Issue.record("outputJson must be valid JSON: \(result.outputJson)")
        }

        _ = await permissionStoreRevoke(grantId: grantID)
    }
}
