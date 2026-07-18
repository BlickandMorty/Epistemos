import Foundation

func freeV1RetiredPathExists(
    _ retiredPath: String,
    sourceFilePath: String
) -> Bool {
    let repositoryRoot = URL(fileURLWithPath: sourceFilePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return FileManager.default.fileExists(
        atPath: repositoryRoot.appendingPathComponent(retiredPath).path
    )
}
