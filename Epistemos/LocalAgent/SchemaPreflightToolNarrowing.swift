import Foundation

/// P8.2 — RAG **preflight tool narrowing** for the LIVE local-agent path (owner 2026-06-19).
///
/// The deterministic schema engine already ships a Rust RAG preflight selector
/// (`tool_preflight.rs` → `schema_preflight_select_tools_gated_json`) and it is exposed
/// over UniFFI, but nothing in the live agent turn called it yet. This is the single
/// per-turn seam that wires it in.
///
/// Behaviour is flag-gated by `EPISTEMOS_SCHEMA_PREFLIGHT_V0` (the SAME env var the Rust
/// side reads — `SCHEMA_PREFLIGHT_FLAG`, in-process so both observe one value):
///   • **OFF (default)** → `narrow` returns the tool list UNCHANGED. No FFI round-trip,
///     no JSON build, byte-for-byte the behaviour shipping today. Chat/Act are untouched.
///   • **ON** → the Rust selector ranks the tools against THIS objective and returns the
///     ~`defaultFootprint` most relevant; a local model then sees a tight, high-fidelity
///     tool set instead of the whole suite (the §C.1 "RAG preflight → tight dispatch"
///     idea, applied to the live loop).
///
/// The narrowing is **non-stranding**: an empty or unparseable selection falls back to the
/// full list, so the agent never ends up with zero tools. Multi-turn caveat: the footprint
/// is chosen from the opening objective; the footprint default is deliberately generous so
/// follow-on tool needs are usually still covered. The flag stays OFF until the owner
/// validates the ON behaviour in-app. Mirrors the `SystemGFlags` gating shape used a few
/// lines up in `LocalAgentLoop.run`.
nonisolated enum SchemaPreflightToolNarrowing {
    /// The env-var flag — single source of truth shared with Rust `SCHEMA_PREFLIGHT_FLAG`
    /// (`agent_core/src/tool_preflight.rs`). A cross-runtime parity test pins them equal.
    static let flagName = "EPISTEMOS_SCHEMA_PREFLIGHT_V0"

    /// Tool footprint when the preflight is armed (the Rust selector caps to this many).
    static let defaultFootprint: UInt32 = 6

    /// True only when the owner has opted in via the env flag. OFF by default.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment[flagName] == "1"
    }

    /// Narrow `tools` to the preflight-selected set for `objective`.
    ///
    /// OFF → returns `tools` unchanged (early-out before any FFI/JSON work). ON → calls the
    /// Rust gated FFI, then filters `tools` to the selected names preserving original order;
    /// falls back to the full list if the selection is empty or unparseable (never zero
    /// tools). In a test host without the FFI module the `#else` branch is also a passthrough.
    static func narrow(
        _ tools: [OmegaToolDefinition],
        forObjective objective: String,
        footprint: UInt32 = defaultFootprint
    ) -> [OmegaToolDefinition] {
        guard isEnabled, !tools.isEmpty else { return tools }
        #if canImport(agent_coreFFI)
        guard let candidatesJSON = encodeCandidates(tools) else { return tools }
        let namesJSON = schemaPreflightSelectToolsGatedJson(
            query: objective,
            candidatesJson: candidatesJSON,
            max: footprint
        )
        guard let selected = decodeNames(namesJSON), !selected.isEmpty else { return tools }
        let selectedSet = Set(selected)
        let narrowed = tools.filter { selectedSet.contains($0.name) }
        return narrowed.isEmpty ? tools : narrowed
        #else
        return tools
        #endif
    }

    // MARK: - JSON helpers (internal so the regression test can exercise them directly)

    /// Encode the tool list as the Rust `PreflightToolInput` array (`name` + `description`;
    /// `keywords` defaults to `[]` on the Rust side). Returns `nil` if serialization fails,
    /// which the caller treats as a passthrough.
    static func encodeCandidates(_ tools: [OmegaToolDefinition]) -> String? {
        let payload = tools.map { ["name": $0.name, "description": $0.description] }
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }

    /// Decode the FFI's `["tool_a", "tool_b", …]` names array. Returns `nil` on garbage so
    /// the caller falls back to the full tool list rather than stranding the agent.
    static func decodeNames(_ json: String) -> [String]? {
        guard let data = json.data(using: .utf8),
              let names = try? JSONSerialization.jsonObject(with: data) as? [String] else { return nil }
        return names
    }
}
