import Foundation

// MARK: - EpistemicStatus
// Metadata for vault notes tracking certainty and evidence quality.
// Reference: CMS-X Claim Ledger pattern — claims are tiered as validated/supported/theoretical/speculative.
//
// YAML frontmatter fields:
//   certainty: 0.85
//   evidence_robustness: medium
//   event_time: 2026-03-15T00:00:00Z
//   recording_time: 2026-04-08T14:00:00Z

/// Epistemic metadata attached to a vault note or fact.
struct EpistemicStatus: Codable, Sendable, Equatable {
    /// Confidence in the fact's truth (0.0–1.0).
    /// 1.0 = user explicitly stated, 0.3 = agent speculation.
    var certainty: Double

    /// Quality of supporting evidence.
    var evidenceRobustness: EvidenceRobustness

    /// When the fact became true in the world (bi-temporal: event time).
    var eventTime: Date?

    /// When the agent learned this fact (bi-temporal: recording time).
    var recordingTime: Date

    init(
        certainty: Double = 0.5,
        evidenceRobustness: EvidenceRobustness = .medium,
        eventTime: Date? = nil,
        recordingTime: Date = .now
    ) {
        self.certainty = certainty.clamped(to: 0.0...1.0)
        self.evidenceRobustness = evidenceRobustness
        self.eventTime = eventTime
        self.recordingTime = recordingTime
    }
}

/// Quality of evidence supporting a fact.
enum EvidenceRobustness: String, Codable, Sendable, CaseIterable {
    /// Multiple independent sources, user confirmation, or peer-reviewed citation.
    case high
    /// Single authoritative source or strong inference.
    case medium
    /// Single web result or agent reasoning without verification.
    case low
    /// Agent hypothesis, not yet checked.
    case speculative

    var displayName: String {
        switch self {
        case .high:        return "Well-evidenced"
        case .medium:      return "Medium evidence"
        case .low:         return "Low evidence"
        case .speculative: return "Speculative"
        }
    }

    var icon: String {
        switch self {
        case .high:        return "checkmark.shield.fill"
        case .medium:      return "checkmark.shield"
        case .low:         return "exclamationmark.triangle"
        case .speculative: return "questionmark.diamond"
        }
    }
}

// MARK: - Factory Methods

extension EpistemicStatus {
    /// User explicitly stated this fact.
    static func userStatement(eventTime: Date? = nil) -> EpistemicStatus {
        EpistemicStatus(certainty: 1.0, evidenceRobustness: .high, eventTime: eventTime)
    }

    /// User confirmed agent's inference.
    static func userConfirmed(eventTime: Date? = nil) -> EpistemicStatus {
        EpistemicStatus(certainty: 0.9, evidenceRobustness: .high, eventTime: eventTime)
    }

    /// Agent inferred from multiple vault sources.
    static func crossReferenced(eventTime: Date? = nil) -> EpistemicStatus {
        EpistemicStatus(certainty: 0.7, evidenceRobustness: .medium, eventTime: eventTime)
    }

    /// Agent inferred from single source or web search.
    static func singleSource(eventTime: Date? = nil) -> EpistemicStatus {
        EpistemicStatus(certainty: 0.5, evidenceRobustness: .low, eventTime: eventTime)
    }

    /// Agent speculation or tentative conclusion.
    static func speculation(eventTime: Date? = nil) -> EpistemicStatus {
        EpistemicStatus(certainty: 0.3, evidenceRobustness: .speculative, eventTime: eventTime)
    }

    /// Formatted display string for note metadata sidebar.
    var displayString: String {
        let certPercent = Int(certainty * 100)
        return "Certainty: \(certPercent)% | \(evidenceRobustness.displayName)"
    }
}

// MARK: - Comparable Double Extension

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
