import Foundation

nonisolated enum KokoroVoicePackageInstaller {
    private static let maxInstallEntries = 250_000
    private static let maxDiagnosticCharacters = 160

    struct InstallResult: Equatable, Sendable {
        let status: KokoroVoiceGateStatus.Status
    }

    enum InstallError: Error, Equatable, LocalizedError, Sendable {
        case unavailableInAppStoreBuild
        case modelRootUnavailable
        case sourcePackageMissing(String)
        case sourcePackageInvalid(String)
        case installFailed(String)

        var errorDescription: String? {
            switch self {
            case .unavailableInAppStoreBuild:
                return "Kokoro install is unavailable in App Store builds."
            case .modelRootUnavailable:
                return "Kokoro install location is unavailable."
            case .sourcePackageMissing(let detail):
                return "Kokoro source package missing: \(detail)"
            case .sourcePackageInvalid(let detail):
                return "Kokoro source package invalid: \(detail)"
            case .installFailed(let detail):
                return "Kokoro install failed: \(detail)"
            }
        }
    }

    static func installCheckedPackage(
        from selectedURL: URL,
        modelRoot: URL? = KokoroVoiceGateStatus.defaultModelRoot(),
        fileManager: FileManager = .default
    ) throws -> InstallResult {
        do {
            return try installCheckedPackageImpl(
                from: selectedURL,
                modelRoot: modelRoot,
                fileManager: fileManager
            )
        } catch let error as InstallError {
            throw error
        } catch {
            throw InstallError.installFailed("filesystem operation failed")
        }
    }

    static func statusMessage(for error: Error) -> String {
        if let installError = error as? InstallError {
            return VoiceCapturePresentationBounds.statusMessage(
                installError.errorDescription ?? "Kokoro install failed",
                fallback: "Kokoro install failed"
            )
        }

        let nsError = error as NSError
        return VoiceCapturePresentationBounds.statusMessage(
            "Kokoro install failed (domain=\(VoiceCaptureDiagnostics.safeDomain(nsError.domain)) code=\(nsError.code))",
            fallback: "Kokoro install failed"
        )
    }

    private static func installCheckedPackageImpl(
        from selectedURL: URL,
        modelRoot: URL?,
        fileManager: FileManager
    ) throws -> InstallResult {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        throw InstallError.unavailableInAppStoreBuild
        #else
        guard let modelRoot else {
            throw InstallError.modelRootUnavailable
        }

        let sourceModelDirectory = try sourceModelDirectory(from: selectedURL, fileManager: fileManager)
        let sourceRoot = sourceModelDirectory.deletingLastPathComponent()
        let sourceStatus = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: sourceRoot,
            fileManager: fileManager
        )
        guard sourceStatus.state == .packageReady else {
            throw InstallError.sourcePackageInvalid(bounded(sourceStatus.detail))
        }
        try rejectSymlinkDescendants(in: sourceModelDirectory, fileManager: fileManager)

        try fileManager.createDirectory(at: modelRoot, withIntermediateDirectories: true)
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: modelRoot.path)

        let tempRoot = modelRoot.appendingPathComponent(".kokoro-install-\(UUID().uuidString)", isDirectory: true)
        let tempModelDirectory = tempRoot.appendingPathComponent(
            KokoroVoiceGateStatus.modelDirectoryName,
            isDirectory: true
        )
        let finalModelDirectory = modelRoot.appendingPathComponent(
            KokoroVoiceGateStatus.modelDirectoryName,
            isDirectory: true
        )
        let backupModelDirectory = modelRoot.appendingPathComponent(
            ".\(KokoroVoiceGateStatus.modelDirectoryName).backup-\(UUID().uuidString)",
            isDirectory: true
        )

        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempRoot)
            try? fileManager.removeItem(at: backupModelDirectory)
        }

        try fileManager.copyItem(at: sourceModelDirectory, to: tempModelDirectory)
        try rejectSymlinkDescendants(in: tempModelDirectory, fileManager: fileManager)

        let stagedStatus = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: tempRoot,
            fileManager: fileManager
        )
        guard stagedStatus.state == .packageReady else {
            throw InstallError.sourcePackageInvalid(bounded(stagedStatus.detail))
        }

        do {
            if fileManager.fileExists(atPath: finalModelDirectory.path) {
                try fileManager.moveItem(at: finalModelDirectory, to: backupModelDirectory)
            }
            try fileManager.moveItem(at: tempModelDirectory, to: finalModelDirectory)
        } catch {
            if fileManager.fileExists(atPath: backupModelDirectory.path),
               !fileManager.fileExists(atPath: finalModelDirectory.path) {
                try? fileManager.moveItem(at: backupModelDirectory, to: finalModelDirectory)
            }
            throw InstallError.installFailed("package could not be finalized")
        }

        let installedStatus = KokoroVoiceGateStatus.status(
            environment: [KokoroVoiceGateStatus.flagName: "1"],
            modelRoot: modelRoot,
            fileManager: fileManager
        )
        guard installedStatus.state == .packageReady else {
            throw InstallError.installFailed(bounded(installedStatus.detail))
        }
        return InstallResult(status: installedStatus)
        #endif
    }

    private static func sourceModelDirectory(
        from selectedURL: URL,
        fileManager: FileManager
    ) throws -> URL {
        let selected = selectedURL.standardizedFileURL
        if selected.lastPathComponent == KokoroVoiceGateStatus.modelDirectoryName,
           isDirectory(selected, fileManager: fileManager) {
            return selected
        }

        let nested = selected.appendingPathComponent(KokoroVoiceGateStatus.modelDirectoryName, isDirectory: true)
        if isDirectory(nested, fileManager: fileManager) {
            return nested
        }

        throw InstallError.sourcePackageMissing(
            "choose \(KokoroVoiceGateStatus.modelDirectoryName) or its parent folder"
        )
    }

    private static func rejectSymlinkDescendants(
        in rootURL: URL,
        fileManager: FileManager
    ) throws {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else {
            throw InstallError.sourcePackageInvalid("package could not be enumerated")
        }

        var visited = 0
        for case let url as URL in enumerator {
            visited += 1
            guard visited <= maxInstallEntries else {
                throw InstallError.sourcePackageInvalid("package contains too many entries")
            }

            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                throw InstallError.sourcePackageInvalid(
                    "package contains symlink \(relativeDiagnostic(url, rootURL: rootURL))"
                )
            }
            if values.isDirectory != true && values.isRegularFile != true {
                throw InstallError.sourcePackageInvalid(
                    "package contains unsupported entry \(relativeDiagnostic(url, rootURL: rootURL))"
                )
            }
        }
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory = ObjCBool(false)
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func relativeDiagnostic(_ url: URL, rootURL: URL) -> String {
        let root = rootURL.standardizedFileURL.path
        let candidate = url.standardizedFileURL.path
        if candidate.hasPrefix(root + "/") {
            return bounded(String(candidate.dropFirst(root.count + 1)))
        }
        return bounded(url.lastPathComponent)
    }

    private static func bounded(_ value: String) -> String {
        let limit = max(0, maxDiagnosticCharacters)
        let bounded = String(value.prefix(limit + 1))
        let clipped: String
        if bounded.count > limit {
            clipped = limit > 3 ? String(bounded.prefix(limit - 3)) + "..." : String(bounded.prefix(limit))
        } else {
            clipped = bounded
        }
        let trimmed = clipped.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "package validation failed" : trimmed
    }
}
