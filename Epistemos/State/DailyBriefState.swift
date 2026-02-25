import Foundation
import Observation
import SwiftUI

// MARK: - Daily Brief State
// Manages the daily brief overlay: generation, loading, "Go Deeper" pass, and auto-save.
// Extracted from UIState to keep UI state focused on navigation and chrome.

@MainActor @Observable
final class DailyBriefState {
    /// When true, the Daily Brief overlay is presented (blurred background + animated answer).
    var showDailyBrief = false

    /// The LLM's response to the daily brief prompt. Empty while loading.
    var dailyBriefContent = ""

    /// True while the LLM is generating the daily brief answer.
    var isDailyBriefLoading = false

    /// True when the user tapped "Go Deeper" — drives UI (loading text, button visibility).
    var isDeepBrief = false

    /// Callback wired by AppBootstrap — calls the triage service to generate the brief.
    var onDailyBriefGenerate: (@MainActor @Sendable (String) async -> String?)?

    /// Callback for the deeper synthesis — uses a richer system prompt via AppBootstrap.
    var onGoDeepGenerate: (@MainActor @Sendable (String) async -> String?)?

    /// Callback wired by AppBootstrap — persists daily brief content as a note in the "Daily Briefs" folder.
    var onDailyBriefSave: (@MainActor @Sendable (String, Bool) async -> Void)?

    private var dailyBriefTask: Task<Void, Never>?

    func requestDailyBrief(prompt: String) {
        showDailyBrief = true
        isDailyBriefLoading = true
        dailyBriefContent = ""

        dailyBriefTask?.cancel()
        dailyBriefTask = Task {
            if let result = await onDailyBriefGenerate?(prompt) {
                guard !Task.isCancelled else { return }
                withAnimation(Motion.smooth) {
                    dailyBriefContent = result
                    isDailyBriefLoading = false
                }
                // Auto-save to notes
                await onDailyBriefSave?(result, false)
            } else {
                isDailyBriefLoading = false
                dailyBriefContent = "Unable to generate your daily brief. Check your API key in Settings."
            }
        }
    }

    /// Trigger a deeper synthesis pass on the daily brief data.
    /// Reuses the same loading/content state but calls the richer `onGoDeepGenerate` callback.
    func requestGoDeep(prompt: String) {
        isDeepBrief = true
        isDailyBriefLoading = true
        dailyBriefContent = ""

        dailyBriefTask?.cancel()
        dailyBriefTask = Task {
            if let result = await onGoDeepGenerate?(prompt) {
                guard !Task.isCancelled else { return }
                withAnimation(Motion.smooth) {
                    dailyBriefContent = result
                    isDailyBriefLoading = false
                }
                // Auto-save to notes (deep variant)
                await onDailyBriefSave?(result, true)
            } else {
                isDailyBriefLoading = false
                dailyBriefContent = "Unable to generate deep analysis. Check your API key in Settings."
            }
        }
    }

    func dismissDailyBrief() {
        dailyBriefTask?.cancel()
        dailyBriefTask = nil
        withAnimation(Motion.smooth) {
            showDailyBrief = false
        }
        // Cleanup after animation completes
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            dailyBriefContent = ""
            isDailyBriefLoading = false
            isDeepBrief = false
        }
    }
}
