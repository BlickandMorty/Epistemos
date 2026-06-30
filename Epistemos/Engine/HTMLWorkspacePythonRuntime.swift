import CryptoKit
import Foundation

nonisolated enum HTMLWorkspacePythonRuntime {
    static let bundleDirectoryName = "Pyodide"
    static let urlPathPrefix = "runtime/python"
    static let entryScriptName = "pyodide.js"
    static let moduleScriptName = "pyodide.mjs"
    static let wasmModuleScriptName = "pyodide.asm.mjs"
    static let wasmName = "pyodide.asm.wasm"
    static let stdlibName = "python_stdlib.zip"
    static let lockFileName = "pyodide-lock.json"

    private static let requiredResourceNames: Set<String> = [
        entryScriptName,
        moduleScriptName,
        wasmModuleScriptName,
        wasmName,
        stdlibName,
        lockFileName,
    ]

    private static let allowedResourceNames: Set<String> = requiredResourceNames.union([
        "package.json",
        "README.md",
    ])

    static var isAvailable: Bool {
        requiredResourceNames.allSatisfy { resourceURL(for: $0) != nil }
    }

    static var baseURLString: String {
        "\(HTMLWorkspaceLocalResourceScheme.scheme)://workspace/\(urlPathPrefix)/"
    }

    static var assetFingerprint: String {
        var data = Data()
        for name in allowedResourceNames.sorted() {
            guard let url = resourceURL(for: name),
                  let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
                continue
            }
            data.append(Data(name.utf8))
            data.append(0)
            if let size = attributes[.size] as? NSNumber {
                data.append(Data(size.stringValue.utf8))
            }
            data.append(0)
            if let modifiedAt = attributes[.modificationDate] as? Date {
                data.append(Data(String(Int64(modifiedAt.timeIntervalSince1970 * 1_000)).utf8))
            }
            data.append(0)
        }
        guard !data.isEmpty else { return "missing" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func resource(for fileName: String) -> HTMLWorkspacePackageResource? {
        guard allowedResourceNames.contains(fileName),
              let url = resourceURL(for: fileName),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        let mimeType = mimeType(for: fileName)
        return HTMLWorkspacePackageResource(
            data: data,
            mimeType: mimeType,
            textEncodingName: HTMLWorkspacePackageResources.textEncodingName(for: mimeType)
        )
    }

    private static func resourceURL(for fileName: String) -> URL? {
        guard allowedResourceNames.contains(fileName),
              let runtimeDirectory = Bundle.main.url(
                forResource: bundleDirectoryName,
                withExtension: nil
              ) else {
            return nil
        }
        let directory = runtimeDirectory.standardizedFileURL
        let candidate = directory.appendingPathComponent(fileName, isDirectory: false).standardizedFileURL
        guard candidate.deletingLastPathComponent() == directory,
              FileManager.default.fileExists(atPath: candidate.path) else {
            return nil
        }
        return candidate
    }

    private static func mimeType(for fileName: String) -> String {
        switch fileName.split(separator: ".").last?.lowercased() {
        case "wasm": "application/wasm"
        case "zip": "application/zip"
        case "mjs": "text/javascript"
        default: HTMLWorkspacePackageResources.mimeType(for: fileName)
        }
    }
}
