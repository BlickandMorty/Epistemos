import Foundation
import OSLog

// MARK: - N1 — PromptCache
//
// Generates cache_control breakpoint hints from a typed Prompt. Per
// Anthropic's prompt-caching spec (verified via existing
// agent_core/src/prompt_caching.rs + the Apr 2026 Gemini deep research):
//
//   - Up to 4 cache_control breakpoints per request
//   - 5-minute TTL on ephemeral cache entries
//   - Minimum 1024 tokens (Sonnet) or 2048 tokens (other tiers) for the
//     prefix to actually cache; under that, caching fails silently
//   - Cache hit gives ~90% input-token discount
//   - Initial "cache write" costs ~25% MORE than uncached input — so
//     only mark subtrees that will be reused at least twice
//
// PromptRenderer applies these hints to the Anthropic Messages output;
// other providers degrade silently (OpenAI auto-caches on prefix; AFM
// + MLX local don't bill per token).
//
// Doctrine refs:
//   - 01_DOCTRINE.md §6 #1 (no silent behavior — hit-rate visible in UI)
//   - 01_DOCTRINE.md §6 #5 (no silent fallback — degradation surfaced)
//   - PLAN_V2.md §3.4 (capability honesty)

/// A single cache-breakpoint marker. Subtree identifies which part of
/// the rendered prompt this breakpoint applies to; the renderer is
/// responsible for placing the actual `cache_control` field on the
/// last content block of the matching segment.
nonisolated public struct CacheBreakpoint: Sendable, Hashable {
    public let subtree: PromptSubtree
    public let ttl: CacheTTL

    public init(subtree: PromptSubtree, ttl: CacheTTL = .ephemeral) {
        self.subtree = subtree
        self.ttl = ttl
    }
}

/// Anthropic supports an "ephemeral" 5-minute TTL today; longer TTLs
/// (1-hour) require a beta header. Default ephemeral.
nonisolated public enum CacheTTL: String, Sendable, Hashable {
    case ephemeral
    case oneHour
}

/// PromptCache is a pure helper — no I/O, no side effects. The actual
/// cached_tokens_share telemetry is recorded at the call site (provider
/// invocation in agent_core / Anthropic SSE handler) by capturing the
/// `usage.cache_read_input_tokens` field from the response.
nonisolated public enum PromptCache {

    /// Maximum cache_control breakpoints Anthropic accepts per request.
    /// Hard-capped to keep parity with the Rust prompt_caching.rs path.
    public static let maxAnthropicBreakpoints = 4

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "PromptCache"
    )

    /// Returns the cache breakpoints to apply for the given target.
    /// - Anthropic: up to 4 breakpoints from the prompt's stableSubtrees
    /// - OpenAI / AFM / MLX: empty (auto-cache or no cache)
    public static func hints(for prompt: Prompt, target: RenderTarget) -> [CacheBreakpoint] {
        switch target {
        case .anthropicMessages:
            return anthropicHints(for: prompt)
        case .openAIResponses, .afmGenerable, .mlxLocalGrammar:
            return []
        }
    }

    /// Anthropic-specific breakpoint plan. Order matters: we use the
    /// first 4 stable subtrees in priority order. Default chat plan
    /// already picks the right four (identity, tools, ontology,
    /// outputSchema) — leaving exactly the budget headroom Anthropic
    /// allows.
    static func anthropicHints(for prompt: Prompt) -> [CacheBreakpoint] {
        var requested = prompt.cacheHints.stableSubtrees

        // Filter out subtrees that aren't actually present in the
        // Prompt — marking a missing subtree as cacheable would put a
        // breakpoint on nothing.
        requested = requested.filter { isPresent($0, in: prompt) }

        if requested.count > maxAnthropicBreakpoints {
            log.warning(
                "PromptCache: \(requested.count) stable subtrees requested but Anthropic caps at \(maxAnthropicBreakpoints, privacy: .public). Truncating."
            )
            requested = Array(requested.prefix(maxAnthropicBreakpoints))
        }

        return requested.map { CacheBreakpoint(subtree: $0, ttl: .ephemeral) }
    }

    /// Returns true if the prompt actually carries content for the
    /// given subtree. Used to avoid wasted breakpoints on empty
    /// sections.
    static func isPresent(_ subtree: PromptSubtree, in prompt: Prompt) -> Bool {
        switch subtree {
        case .identity:
            return prompt.identity != nil
        case .tools:
            return !prompt.tools.isEmpty
        case .memory:
            guard let m = prompt.memory else { return false }
            return m.recentChats != nil || !m.relevantNotes.isEmpty
        case .ontology:
            guard let m = prompt.memory else { return false }
            return !m.ontology.isEmpty
        case .task:
            // Task is always present (required field on Prompt).
            return true
        case .constraints:
            return !prompt.constraints.isEmpty
        case .outputSchema:
            return prompt.outputSchema != nil
        }
    }

    // MARK: - Hit-rate telemetry

    /// Records a cache hit-rate sample for a session. Call this from
    /// the Anthropic SSE handler (Swift bridge) when the response's
    /// usage block is parsed. The recorded value flows into
    /// SessionInsight.cached_tokens_share which the W9.6 cost
    /// dashboard already surfaces.
    ///
    /// - Parameters:
    ///   - sessionID: id of the active session
    ///   - cacheReadTokens: usage.cache_read_input_tokens from response
    ///   - totalInputTokens: usage.input_tokens + cache_read + cache_creation
    public static func recordHitRate(
        sessionID: String,
        cacheReadTokens: Int,
        totalInputTokens: Int
    ) -> Double {
        guard totalInputTokens > 0 else { return 0 }
        let share = Double(cacheReadTokens) / Double(totalInputTokens)
        log.info(
            "PromptCache: session=\(sessionID, privacy: .public) cached=\(cacheReadTokens) total=\(totalInputTokens) share=\(share, format: .fixed(precision: 3))"
        )
        return share
    }
}
