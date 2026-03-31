import Foundation
import SwiftData

// MARK: - Model Profile (v2 Multi-Model System)

/// A persistent model profile representing a local or cloud AI model
/// with its attached vault, trained adapters, and graph settings.
///
/// Models are the primary entity in Epistemos v2:
/// - Local models get fine-tuning + vault + graph visualization
/// - Cloud models (Claude, Perplexity) get vault + graph but no fine-tuning
///
/// Each profile owns a vault scope: when active, the graph shows only
/// that model's knowledge, and inference uses only that model's adapters.
@Model
final class SDModelProfile {
    // MARK: - Identity

    var id: String = UUID().uuidString
    var displayName: String = ""
    var modelIdentifier: String = "" // LocalTextModelID.rawValue or cloud provider ID
    var profileType: String = "local" // "local" or "cloud"

    // MARK: - Vault Association

    /// The vault identity this model is trained on / operates within.
    /// Encoded as VaultIdentity string (e.g., "model:qwen-personal").
    var vaultIdentityKey: String = "personal"

    /// Human-readable vault name for display.
    var vaultDisplayName: String = "Personal"

    // MARK: - Adapter Tracking (local models only)

    /// UUIDs of AdapterRecords trained for this model profile.
    var adapterIds: [String] = []

    /// The currently active adapter UUID (nil = base model only).
    var activeAdapterId: String?

    // MARK: - Inference Settings

    /// Temperature for this profile's inference.
    var temperature: Double = 0.7

    /// Top-p sampling parameter.
    var topP: Double = 0.9

    /// Max output tokens.
    var maxOutputTokens: Int = 4096

    /// Whether thinking mode is enabled for this profile.
    var thinkingEnabled: Bool = true

    // MARK: - Graph Settings (persisted per-profile)

    /// Which node types are visible when this profile is active.
    /// Encoded as comma-separated GraphNodeType raw values.
    var graphNodeTypeFilter: String = ""

    /// Which edge types are visible when this profile is active.
    var graphEdgeTypeFilter: String = ""

    /// Pinned node IDs in the graph for this profile.
    var pinnedNodeIds: [String] = []

    // MARK: - Cloud Model Settings (cloud profiles only)

    /// Cloud provider name (e.g., "claude_sonnet", "perplexity").
    var cloudProvider: String?

    /// Whether this is a cloud model (no fine-tuning available).
    var isCloudModel: Bool = false

    // MARK: - Metadata

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// Number of conversations held with this profile.
    var conversationCount: Int = 0

    /// Total tokens processed by this profile.
    var totalTokensProcessed: Int = 0

    // MARK: - Init

    init() {}

    // MARK: - Convenience

    /// Whether this profile supports fine-tuning (local models only).
    var supportsFinetuning: Bool {
        !isCloudModel
    }
}
