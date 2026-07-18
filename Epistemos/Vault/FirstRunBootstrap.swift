import Darwin
import Foundation
import OSLog

/// Neutral first-run vault scaffold.
///
/// The bootstrap owns only a bounded vault-directory and metadata transaction.
/// It neither resolves models nor interprets historical model pins.
public enum FirstRunBootstrap {

    public static let metadataRelativePath = ".epistemos/vault.json"
    public static let schemaVersion: UInt32 = 1
    public static let maxMetadataBytes = 16 * 1024
    public static let scaffoldFolders: [String] = [
        "_inbox",
        "_inbox/review",
        "daily",
        "notes"
    ]

    private static let supportedSchemaVersions: Set<UInt32> = [schemaVersion]
    private static let maxHistoricalPinBytes = 512
    private static let maxHistoricalPinScalars = 256
    private static let earliestSupportedCreationDate = Date(timeIntervalSince1970: 946_684_800)
    private static let latestSupportedCreationDate = Date(timeIntervalSince1970: 4_102_444_800)

    public struct Metadata: Codable, Equatable, Sendable {
        public let schemaVersion: UInt32
        public let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case createdAt = "created_at"
        }
    }

    private struct LegacyMetadataEnvelope: Decodable {
        let schemaVersion: UInt32
        let createdAt: Date
        let embeddingModelPin: String?
        let routerModelPin: String?

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case createdAt = "created_at"
            case embeddingModelPin = "embedding_model_pin"
            case routerModelPin = "router_model_pin"
        }
    }

    public struct Receipt: Sendable {
        public let vaultURL: URL
        public let metadataURL: URL
        public let createdFolders: [URL]
        public let wasFresh: Bool
        public let metadata: Metadata
    }

    public enum BootstrapError: Error, Equatable {
        case invalidVaultRoot
        case unsafeFilesystemObject
        case invalidMetadata
        case unsupportedMetadata
        case metadataTooLarge
        case metadataRace
        case metadataPublicationFailed
    }

    private final class DirectoryDescriptor {
        let fileDescriptor: Int32

        init(_ fileDescriptor: Int32) {
            self.fileDescriptor = fileDescriptor
        }

        deinit {
            close(fileDescriptor)
        }

        static func filesystemRoot() throws -> DirectoryDescriptor {
            let descriptor = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard descriptor >= 0 else { throw BootstrapError.unsafeFilesystemObject }
            return DirectoryDescriptor(descriptor)
        }

        func existingDirectory(named component: String) throws -> DirectoryDescriptor? {
            guard FirstRunBootstrap.isSafePathComponent(component) else {
                throw BootstrapError.invalidVaultRoot
            }
            let opened = component.withCString {
                let descriptor = openat(fileDescriptor, $0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                return (descriptor: descriptor, errorCode: errno)
            }
            if opened.descriptor >= 0 {
                let directory = DirectoryDescriptor(opened.descriptor)
                _ = try directory.directoryStatus()
                return directory
            }
            if opened.errorCode == ENOENT { return nil }
            throw BootstrapError.unsafeFilesystemObject
        }

        func ensureDirectory(named component: String) throws -> (directory: DirectoryDescriptor, created: Bool) {
            if let existing = try existingDirectory(named: component) {
                return (existing, false)
            }
            let creation = component.withCString {
                let result = mkdirat(fileDescriptor, $0, mode_t(0o700))
                return (created: result == 0, errorCode: errno)
            }
            if !creation.created, creation.errorCode != EEXIST {
                throw BootstrapError.unsafeFilesystemObject
            }
            guard let directory = try existingDirectory(named: component) else {
                throw BootstrapError.unsafeFilesystemObject
            }
            return (directory, creation.created)
        }

        func verifyDirectory(named component: String, matches expected: DirectoryDescriptor) throws {
            guard let observed = try existingDirectory(named: component),
                  try observed.hasSameIdentity(as: expected)
            else {
                throw BootstrapError.unsafeFilesystemObject
            }
        }

        func openRegularFile(named component: String) throws -> Int32? {
            guard FirstRunBootstrap.isSafePathComponent(component) else {
                throw BootstrapError.invalidVaultRoot
            }
            var expected = stat()
            let inspection = component.withCString {
                let result = fstatat(fileDescriptor, $0, &expected, AT_SYMLINK_NOFOLLOW)
                return (result: result, errorCode: errno)
            }
            if inspection.result != 0 {
                if inspection.errorCode == ENOENT { return nil }
                throw BootstrapError.unsafeFilesystemObject
            }
            guard (expected.st_mode & S_IFMT) == S_IFREG,
                  expected.st_nlink == 1,
                  expected.st_size > 0,
                  expected.st_size <= off_t(FirstRunBootstrap.maxMetadataBytes)
            else {
                throw BootstrapError.unsafeFilesystemObject
            }
            let descriptor = component.withCString {
                openat(fileDescriptor, $0, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
            }
            guard descriptor >= 0 else { throw BootstrapError.unsafeFilesystemObject }

            var observed = stat()
            guard fstat(descriptor, &observed) == 0,
                  observed.st_dev == expected.st_dev,
                  observed.st_ino == expected.st_ino,
                  (observed.st_mode & S_IFMT) == S_IFREG,
                  observed.st_nlink == 1
            else {
                close(descriptor)
                throw BootstrapError.unsafeFilesystemObject
            }
            return descriptor
        }

        func createRegularFile(named component: String) throws -> Int32? {
            guard FirstRunBootstrap.isSafePathComponent(component) else {
                throw BootstrapError.invalidVaultRoot
            }
            let creation = component.withCString {
                let descriptor = openat(fileDescriptor, $0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
                return (descriptor: descriptor, errorCode: errno)
            }
            if creation.descriptor >= 0 { return creation.descriptor }
            if creation.errorCode == EEXIST { return nil }
            throw BootstrapError.metadataPublicationFailed
        }

        private func directoryStatus() throws -> stat {
            var status = stat()
            guard fstat(fileDescriptor, &status) == 0,
                  (status.st_mode & S_IFMT) == S_IFDIR
            else {
                throw BootstrapError.unsafeFilesystemObject
            }
            return status
        }

        private func hasSameIdentity(as other: DirectoryDescriptor) throws -> Bool {
            let lhs = try directoryStatus()
            let rhs = try other.directoryStatus()
            return lhs.st_dev == rhs.st_dev && lhs.st_ino == rhs.st_ino
        }
    }

    private struct AdmittedVault {
        let url: URL
        let parent: DirectoryDescriptor
        let root: DirectoryDescriptor
        let rootName: String

        func verify() throws {
            try parent.verifyDirectory(named: rootName, matches: root)
        }
    }

    private enum FreshMetadataPublicationTestHook {
        @TaskLocal static var beforePublication: (@Sendable () throws -> Void)?
        @TaskLocal static var shouldFailPublication = false
    }

    /// Internal test-only dynamic scope for adversarial publication timing.
    /// `TaskLocal.withValue` restores the hook on normal and throwing exits.
    static func withFreshMetadataPublicationHook<Value>(
        _ hook: @escaping @Sendable () throws -> Void,
        operation: () throws -> Value
    ) throws -> Value {
        try FreshMetadataPublicationTestHook.$beforePublication.withValue(hook) {
            try operation()
        }
    }

    /// Internal test-only failure scope for a post-scaffold receipt fault.
    /// `TaskLocal.withValue` resets this value on normal and throwing exits.
    static func withFreshMetadataPublicationFailure<Value>(
        operation: () throws -> Value
    ) throws -> Value {
        try FreshMetadataPublicationTestHook.$shouldFailPublication.withValue(true) {
            try operation()
        }
    }

    private static func admittedVault(
        at vaultURL: URL,
        createIfMissing: Bool
    ) throws -> AdmittedVault? {
        let (url, components) = try absolutePathComponents(for: vaultURL)
        var parent = try DirectoryDescriptor.filesystemRoot()
        for component in components.dropLast() {
            guard let child = try parent.existingDirectory(named: component) else {
                throw BootstrapError.invalidVaultRoot
            }
            parent = child
        }
        guard let rootName = components.last else { throw BootstrapError.invalidVaultRoot }
        let root: DirectoryDescriptor
        if let existing = try parent.existingDirectory(named: rootName) {
            root = existing
        } else if createIfMissing {
            root = try parent.ensureDirectory(named: rootName).directory
        } else {
            return nil
        }
        return AdmittedVault(url: url, parent: parent, root: root, rootName: rootName)
    }

    private static func openExistingDirectory(at url: URL) throws -> DirectoryDescriptor {
        let (_, components) = try absolutePathComponents(for: url)
        var directory = try DirectoryDescriptor.filesystemRoot()
        for component in components {
            guard let child = try directory.existingDirectory(named: component) else {
                throw BootstrapError.invalidVaultRoot
            }
            directory = child
        }
        return directory
    }

    private static func absolutePathComponents(for url: URL) throws -> (URL, [String]) {
        guard url.isFileURL else { throw BootstrapError.invalidVaultRoot }
        let path = url.path
        guard path.hasPrefix("/"), path != "/" else {
            throw BootstrapError.invalidVaultRoot
        }
        var rawComponents = Array(path.dropFirst().split(separator: "/", omittingEmptySubsequences: false))
        if path.hasSuffix("/") {
            _ = rawComponents.popLast()
        }
        guard !rawComponents.isEmpty,
              rawComponents.allSatisfy({ !$0.isEmpty && isSafePathComponent(String($0)) })
        else {
            throw BootstrapError.invalidVaultRoot
        }
        return (url, rawComponents.map(String.init))
    }

    private static func relativeComponents(_ path: String) throws -> [String] {
        let components = path.split(separator: "/").map(String.init)
        guard !components.isEmpty, components.allSatisfy(isSafePathComponent) else {
            throw BootstrapError.invalidVaultRoot
        }
        return components
    }

    private static func isSafePathComponent(_ component: String) -> Bool {
        !component.isEmpty && component != "." && component != ".." && !component.contains("/")
    }

    /// Default vault location: `~/Documents/Epistemos` when available. A fully
    /// isolated runtime audit uses its disposable Application Support root.
    public static func defaultVaultURL(
        fileManager: FileManager = .default,
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        switch FoundationSafety.auditRuntimeIsolationRequestState(
            fileManager: fileManager,
            processInfoEnvironment: processInfoEnvironment
        ) {
        case .active:
            return FoundationSafety.runtimeApplicationSupportDirectory(
                fileManager: fileManager,
                processInfoEnvironment: processInfoEnvironment
            ).appendingPathComponent("Runtime Audit Vault", isDirectory: true).standardizedFileURL
        case .requestedButInvalid:
            preconditionFailure("Runtime-audit default-vault isolation is incomplete or invalid")
        case .notRequested:
            break
        }

        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documents.appendingPathComponent("Epistemos", isDirectory: true).standardizedFileURL
        }
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Epistemos", isDirectory: true)
            .standardizedFileURL
    }

    /// Returns `false` for unsafe or malformed states and `true` only when an
    /// admitted root has no receipt.
    public static func isFresh(at vaultURL: URL, fileManager _: FileManager = .default) -> Bool {
        do {
            guard let vault = try admittedVault(at: vaultURL, createIfMissing: false) else {
                return true
            }
            return try existingMetadata(in: vault) == nil
        } catch {
            return false
        }
    }

    /// Idempotent first-run transaction. Every filesystem operation below is
    /// anchored to an admitted directory descriptor rather than a path string.
    public static func bootstrap(
        at vaultURL: URL,
        fileManager _: FileManager = .default
    ) throws -> Receipt {
        do {
            guard let vault = try admittedVault(at: vaultURL, createIfMissing: true) else {
                throw BootstrapError.invalidVaultRoot
            }
            let existing = try existingMetadata(in: vault)
            try preflightScaffold(in: vault)

            var createdFolders: [URL] = []
            for relativePath in scaffoldFolders {
                let created = try ensureDirectory(relativePath, in: vault.root).created
                if created {
                    createdFolders.append(vault.url.appendingPathComponent(relativePath, isDirectory: true))
                }
            }

            let metadataDirectory = try vault.root.ensureDirectory(named: ".epistemos").directory
            let metadataURL = vault.url.appendingPathComponent(metadataRelativePath)
            if let existing {
                return Receipt(
                    vaultURL: vault.url,
                    metadataURL: metadataURL,
                    createdFolders: createdFolders,
                    wasFresh: false,
                    metadata: existing
                )
            }
            if let winner = try readMetadata(in: metadataDirectory) {
                return Receipt(
                    vaultURL: vault.url,
                    metadataURL: metadataURL,
                    createdFolders: createdFolders,
                    wasFresh: false,
                    metadata: winner
                )
            }

            let fresh = Metadata(
                schemaVersion: schemaVersion,
                createdAt: Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
            )
            switch try publishFreshMetadata(fresh, in: metadataDirectory, vault: vault) {
            case .winner(let winner):
                return Receipt(
                    vaultURL: vault.url,
                    metadataURL: metadataURL,
                    createdFolders: createdFolders,
                    wasFresh: false,
                    metadata: winner
                )
            case .published:
                try vault.verify()
                try vault.root.verifyDirectory(named: ".epistemos", matches: metadataDirectory)
                guard try readMetadata(in: metadataDirectory) == fresh else {
                    throw BootstrapError.metadataRace
                }
                log.info("Published neutral first-run vault receipt")
                return Receipt(
                    vaultURL: vault.url,
                    metadataURL: metadataURL,
                    createdFolders: createdFolders,
                    wasFresh: true,
                    metadata: fresh
                )
            }
        } catch let error as BootstrapError {
            throw error
        } catch {
            throw BootstrapError.unsafeFilesystemObject
        }
    }

    public static func readMetadata(
        at url: URL,
        fileManager _: FileManager = .default
    ) throws -> Metadata {
        guard url.lastPathComponent == "vault.json" else {
            throw BootstrapError.invalidVaultRoot
        }
        let directory = try openExistingDirectory(at: url.deletingLastPathComponent())
        guard let data = try boundedRegularFileData(in: directory, named: "vault.json") else {
            throw BootstrapError.unsafeFilesystemObject
        }
        return try decodeMetadata(data)
    }

    private static func existingMetadata(in vault: AdmittedVault) throws -> Metadata? {
        try vault.verify()
        guard let directory = try vault.root.existingDirectory(named: ".epistemos"),
              let data = try boundedRegularFileData(in: directory, named: "vault.json")
        else {
            return nil
        }
        try vault.verify()
        try vault.root.verifyDirectory(named: ".epistemos", matches: directory)
        return try decodeMetadata(data)
    }

    private static func decodeMetadata(_ data: Data) throws -> Metadata {
        try validateMetadataEnvelope(data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope: LegacyMetadataEnvelope
        do {
            envelope = try decoder.decode(LegacyMetadataEnvelope.self, from: data)
        } catch {
            throw BootstrapError.invalidMetadata
        }
        guard supportedSchemaVersions.contains(envelope.schemaVersion) else {
            throw BootstrapError.unsupportedMetadata
        }
        guard envelope.createdAt >= earliestSupportedCreationDate,
              envelope.createdAt <= latestSupportedCreationDate
        else {
            throw BootstrapError.invalidMetadata
        }
        try validateHistoricalPin(envelope.embeddingModelPin)
        try validateHistoricalPin(envelope.routerModelPin)
        return Metadata(schemaVersion: envelope.schemaVersion, createdAt: envelope.createdAt)
    }

    private static func preflightScaffold(in vault: AdmittedVault) throws {
        try vault.verify()
        for relativePath in scaffoldFolders {
            _ = try existingDirectory(relativePath, in: vault.root)
        }
    }

    private static func existingDirectory(
        _ relativePath: String,
        in root: DirectoryDescriptor
    ) throws -> DirectoryDescriptor? {
        var current = root
        for component in try relativeComponents(relativePath) {
            guard let next = try current.existingDirectory(named: component) else {
                return nil
            }
            current = next
        }
        return current
    }

    private static func ensureDirectory(
        _ relativePath: String,
        in root: DirectoryDescriptor
    ) throws -> (directory: DirectoryDescriptor, created: Bool) {
        var current = root
        var createdFinal = false
        let components = try relativeComponents(relativePath)
        for (index, component) in components.enumerated() {
            let result = try current.ensureDirectory(named: component)
            current = result.directory
            if index == components.indices.last {
                createdFinal = result.created
            }
        }
        return (current, createdFinal)
    }

    private static func boundedRegularFileData(
        in directory: DirectoryDescriptor,
        named name: String
    ) throws -> Data? {
        guard let descriptor = try directory.openRegularFile(named: name) else { return nil }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }

        var before = stat()
        guard fstat(descriptor, &before) == 0,
              (before.st_mode & S_IFMT) == S_IFREG,
              before.st_nlink == 1,
              before.st_size > 0,
              before.st_size <= off_t(maxMetadataBytes)
        else {
            throw BootstrapError.unsafeFilesystemObject
        }
        let data: Data
        do {
            data = try handle.read(upToCount: maxMetadataBytes + 1) ?? Data()
        } catch {
            throw BootstrapError.invalidMetadata
        }
        var after = stat()
        guard fstat(descriptor, &after) == 0,
              before.st_dev == after.st_dev,
              before.st_ino == after.st_ino,
              before.st_size == after.st_size,
              after.st_nlink == 1,
              data.count == Int(after.st_size),
              data.count <= maxMetadataBytes
        else {
            throw BootstrapError.metadataRace
        }
        return data
    }

    private static func validateMetadataEnvelope(_ data: Data) throws {
        guard !data.isEmpty, data.count <= maxMetadataBytes,
              let text = String(data: data, encoding: .utf8)
        else {
            throw BootstrapError.metadataTooLarge
        }
        let keys = try topLevelObjectKeys(in: text)
        let allowedKeys: Set<String> = [
            "schema_version",
            "created_at",
            "embedding_model_pin",
            "router_model_pin",
        ]
        let requiredKeys: Set<String> = ["schema_version", "created_at"]
        guard keys.isSubset(of: allowedKeys), requiredKeys.isSubset(of: keys) else {
            throw BootstrapError.unsupportedMetadata
        }
    }

    private static func validateHistoricalPin(_ pin: String?) throws {
        guard let pin else { return }
        guard pin.utf8.count <= maxHistoricalPinBytes,
              pin.unicodeScalars.count <= maxHistoricalPinScalars,
              !pin.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F })
        else {
            throw BootstrapError.invalidMetadata
        }
    }

    /// Parses only the shallow metadata envelope. Nested values and escaped key
    /// aliases are intentionally rejected so duplicate/unknown-key policy is
    /// deterministic before `JSONDecoder` receives the bytes.
    private static func topLevelObjectKeys(in text: String) throws -> Set<String> {
        let scalars = Array(text.unicodeScalars)
        var index = 0
        var keys = Set<String>()

        func skipWhitespace() {
            while index < scalars.count, CharacterSet.whitespacesAndNewlines.contains(scalars[index]) {
                index += 1
            }
        }
        func require(_ scalar: UnicodeScalar) throws {
            guard index < scalars.count, scalars[index] == scalar else {
                throw BootstrapError.invalidMetadata
            }
            index += 1
        }
        func readKey() throws -> String {
            try require("\"")
            let start = index
            while index < scalars.count, scalars[index] != "\"" {
                guard scalars[index] != "\\", scalars[index].value >= 0x20 else {
                    throw BootstrapError.invalidMetadata
                }
                index += 1
            }
            guard index < scalars.count else { throw BootstrapError.invalidMetadata }
            let key = String(String.UnicodeScalarView(scalars[start..<index]))
            index += 1
            return key
        }
        func skipString() throws {
            try require("\"")
            while index < scalars.count {
                let scalar = scalars[index]
                index += 1
                if scalar == "\"" { return }
                guard scalar.value >= 0x20 else { throw BootstrapError.invalidMetadata }
                if scalar == "\\" {
                    guard index < scalars.count else { throw BootstrapError.invalidMetadata }
                    let escape = scalars[index]
                    index += 1
                    guard "\"\\/bfnrtu".unicodeScalars.contains(escape) else {
                        throw BootstrapError.invalidMetadata
                    }
                    if escape == "u" {
                        for _ in 0..<4 {
                            guard index < scalars.count,
                                  "0123456789abcdefABCDEF".unicodeScalars.contains(scalars[index])
                            else { throw BootstrapError.invalidMetadata }
                            index += 1
                        }
                    }
                }
            }
            throw BootstrapError.invalidMetadata
        }
        func skipPrimitive() throws {
            let start = index
            while index < scalars.count, scalars[index] != ",", scalars[index] != "}" {
                let scalar = scalars[index]
                guard scalar != "{", scalar != "[", scalar != "]",
                      scalar.value >= 0x20 || CharacterSet.whitespacesAndNewlines.contains(scalar)
                else {
                    throw BootstrapError.invalidMetadata
                }
                index += 1
            }
            guard String(String.UnicodeScalarView(scalars[start..<index]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false
            else { throw BootstrapError.invalidMetadata }
        }

        skipWhitespace()
        try require("{")
        skipWhitespace()
        if index < scalars.count, scalars[index] == "}" {
            index += 1
            skipWhitespace()
            guard index == scalars.count else { throw BootstrapError.invalidMetadata }
            return keys
        }

        while true {
            skipWhitespace()
            let key = try readKey()
            guard keys.insert(key).inserted else { throw BootstrapError.invalidMetadata }
            skipWhitespace()
            try require(":")
            skipWhitespace()
            guard index < scalars.count else { throw BootstrapError.invalidMetadata }
            if scalars[index] == "\"" {
                try skipString()
            } else {
                try skipPrimitive()
            }
            skipWhitespace()
            guard index < scalars.count else { throw BootstrapError.invalidMetadata }
            if scalars[index] == "}" {
                index += 1
                skipWhitespace()
                guard index == scalars.count else { throw BootstrapError.invalidMetadata }
                return keys
            }
            try require(",")
        }
    }

    private enum FreshPublication {
        case published
        case winner(Metadata)
    }

    private static func publishFreshMetadata(
        _ metadata: Metadata,
        in directory: DirectoryDescriptor,
        vault: AdmittedVault
    ) throws -> FreshPublication {
        let bytes = try encodedMetadata(metadata)
        if let hook = FreshMetadataPublicationTestHook.beforePublication {
            try hook()
        }
        if FreshMetadataPublicationTestHook.shouldFailPublication {
            throw BootstrapError.metadataPublicationFailed
        }
        try vault.verify()
        try vault.root.verifyDirectory(named: ".epistemos", matches: directory)

        guard let descriptor = try directory.createRegularFile(named: "vault.json") else {
            guard let winner = try readMetadata(in: directory) else {
                throw BootstrapError.metadataRace
            }
            return .winner(winner)
        }
        defer { close(descriptor) }

        var before = stat()
        guard fstat(descriptor, &before) == 0,
              (before.st_mode & S_IFMT) == S_IFREG,
              before.st_nlink == 1,
              before.st_size == 0
        else {
            throw BootstrapError.metadataPublicationFailed
        }
        let didWrite = bytes.withUnsafeBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return bytes.isEmpty }
            var offset = 0
            while offset < bytes.count {
                let written = write(descriptor, baseAddress.advanced(by: offset), bytes.count - offset)
                guard written > 0 else { return false }
                offset += Int(written)
            }
            return true
        }
        guard didWrite, fsync(descriptor) == 0 else {
            throw BootstrapError.metadataPublicationFailed
        }
        var after = stat()
        guard fstat(descriptor, &after) == 0,
              after.st_dev == before.st_dev,
              after.st_ino == before.st_ino,
              after.st_nlink == 1,
              after.st_size == off_t(bytes.count),
              fsync(directory.fileDescriptor) == 0
        else {
            throw BootstrapError.metadataPublicationFailed
        }
        return .published
    }

    private static func readMetadata(in directory: DirectoryDescriptor) throws -> Metadata? {
        guard let data = try boundedRegularFileData(in: directory, named: "vault.json") else {
            return nil
        }
        return try decodeMetadata(data)
    }

    private static func encodedMetadata(_ value: Metadata) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(value)
        guard bytes.count <= maxMetadataBytes else { throw BootstrapError.metadataTooLarge }
        return bytes
    }

    fileprivate static let log = Logger(subsystem: "com.epistemos", category: "FirstRunBootstrap")
}
