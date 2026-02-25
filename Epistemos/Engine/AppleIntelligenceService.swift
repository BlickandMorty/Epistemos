import Foundation
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Apple Intelligence Service
// Uses FoundationModels framework (macOS 26+) for on-device LLM tasks.
// Falls back to a clear error on older OS versions so the caller can handle gracefully.

@MainActor
final class AppleIntelligenceService {
    static let shared = AppleIntelligenceService()

    private init() {}

    func generate(prompt: String, systemPrompt: String? = nil) async throws -> String {
        if #available(macOS 26.0, *) {
            return try await generateWithFoundationModels(prompt: prompt, systemPrompt: systemPrompt)
        } else {
            throw AppleIntelligenceError.unavailable("Apple Intelligence requires macOS 26 or later.")
        }
    }

    @available(macOS 26.0, *)
    private func generateWithFoundationModels(prompt: String, systemPrompt: String?) async throws -> String {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            let reason: String
            switch model.availability {
            case .available:
                reason = "Unknown"
            case .unavailable(.deviceNotEligible):
                reason = "This device is not eligible for Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled):
                reason = "Apple Intelligence is not enabled. Turn it on in System Settings → Apple Intelligence & Siri."
            case .unavailable(.modelNotReady):
                reason = "The on-device model is still downloading. Please try again later."
            case .unavailable(_):
                reason = "Apple Intelligence is currently unavailable."
            @unknown default:
                reason = "Apple Intelligence is currently unavailable."
            }
            throw AppleIntelligenceError.unavailable(reason)
        }

        let session: LanguageModelSession
        if let systemPrompt, !systemPrompt.isEmpty {
            session = LanguageModelSession(instructions: systemPrompt)
        } else {
            session = LanguageModelSession()
        }
        let response = try await session.respond(to: prompt)
        return response.content
        #else
        throw AppleIntelligenceError.unavailable("FoundationModels framework not available on this build machine.")
        #endif
    }

    /// Check if Apple Intelligence is available on this device.
    func checkAvailability() -> (available: Bool, reason: String?) {
        if #available(macOS 26.0, *) {
            #if canImport(FoundationModels)
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return (true, nil)
            case .unavailable(.deviceNotEligible):
                return (false, "This device is not eligible for Apple Intelligence.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return (false, "Apple Intelligence is not enabled. Turn it on in System Settings → Apple Intelligence & Siri.")
            case .unavailable(.modelNotReady):
                return (false, "The on-device model is still downloading. Try again later.")
            case .unavailable(_):
                return (false, "Apple Intelligence is currently unavailable.")
            @unknown default:
                return (false, "Apple Intelligence is currently unavailable.")
            }
            #else
            return (false, "FoundationModels framework not available on this build.")
            #endif
        } else {
            return (false, "Apple Intelligence requires macOS 26 or later.")
        }
    }
}

enum AppleIntelligenceError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): "Apple Intelligence unavailable: \(reason)"
        }
    }
}


