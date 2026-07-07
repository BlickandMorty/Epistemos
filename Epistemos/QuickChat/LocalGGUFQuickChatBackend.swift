import Foundation

/// Retired local GGUF backend.
///
/// The App Store lane must not be able to import or link a local llama runtime,
/// even if a prior build left package artifacts in DerivedData. Keep the public
/// backend seam as an honest unavailable adapter so existing quick-chat routing
/// can continue to fall through to cloud/remote engines.
nonisolated final class LocalGGUFQuickChatBackend: @unchecked Sendable {
    static let shared = LocalGGUFQuickChatBackend()

    init() {}

    var isAvailableInThisBuild: Bool { false }

    func setPreferredModel(_ id: String?) {}

    func resolvedEntry() -> GGUFCatalogEntry? { nil }

    func unavailability() -> QuickChatEngineUnavailable? {
        .noLocalModelInstalled
    }

    func stream(
        prompt: String,
        instructions: String?,
        maxNewTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuation.finish(throwing: QuickChatError.engineUnavailable(.noLocalModelInstalled))
        }
    }

    func cancel() {}

    func unloadForMemoryPressure() {}
}
