import Foundation

// MARK: - Research Evidence Scorer

/// Deterministic URL-to-confidence-tier mapping for research sources.
/// No LLM call required. Called by the `scoreevidence` tool in NotesAgent.
///
/// Preserves the old EnrichmentController evidence hierarchy (Tier 1-5)
/// as a pure struct with no external dependencies.
struct ResearchEvidenceScorer {

    enum Tier: String, Sendable {
        case primaryData
        case peerReviewed
        case arxivPreprint
        case news
        case blog
        case unknown

        var confidence: Double {
            switch self {
            case .primaryData:    0.95
            case .peerReviewed:   0.85
            case .arxivPreprint:  0.70
            case .news:           0.50
            case .blog:           0.30
            case .unknown:        0.20
            }
        }
    }

    static func tier(for url: String) -> Tier {
        let lowered = url.lowercased()

        // Peer-reviewed (check before .gov since pubmed.ncbi.nlm.nih.gov contains .gov)
        if lowered.contains("doi.org") || lowered.contains("pubmed") ||
           lowered.contains("nature.com") || lowered.contains("science.org") ||
           lowered.contains("springer.com") || lowered.contains("wiley.com") ||
           lowered.contains("cell.com") || lowered.contains("thelancet.com") ||
           lowered.contains("pnas.org") || lowered.contains("pmc.ncbi") ||
           (lowered.contains(".edu") && lowered.contains("/publications")) {
            return .peerReviewed
        }

        // Primary data sources (after peer-reviewed to avoid misclassifying pubmed)
        if lowered.contains(".gov") || lowered.contains("who.int") {
            return .primaryData
        }

        // Preprints
        if lowered.contains("arxiv.org") || lowered.contains("biorxiv.org") ||
           lowered.contains("medrxiv.org") || lowered.contains("ssrn.com") ||
           lowered.contains("openreview.net") {
            return .arxivPreprint
        }

        // News
        if lowered.contains("nytimes.com") || lowered.contains("reuters.com") ||
           lowered.contains("bbc.com") || lowered.contains("bbc.co.uk") ||
           lowered.contains("apnews.com") || lowered.contains("washingtonpost.com") ||
           lowered.contains("economist.com") || lowered.contains("theguardian.com") {
            return .news
        }

        // Blogs
        if lowered.contains("medium.com") || lowered.contains("substack.com") ||
           lowered.contains("wordpress.com") || lowered.contains("blogspot.com") ||
           lowered.contains("dev.to") || lowered.contains("hashnode.") {
            return .blog
        }

        return .unknown
    }

    /// Score a URL with optional source type override.
    static func score(url: String, sourceType: String? = nil) -> (tier: Tier, confidence: Double) {
        if let typeStr = sourceType?.lowercased() {
            switch typeStr {
            case "arxiv":          return (.arxivPreprint, Tier.arxivPreprint.confidence)
            case "peer_reviewed":  return (.peerReviewed, Tier.peerReviewed.confidence)
            case "news":           return (.news, Tier.news.confidence)
            case "blog":           return (.blog, Tier.blog.confidence)
            case "primary":        return (.primaryData, Tier.primaryData.confidence)
            default: break
            }
        }
        let t = tier(for: url)
        return (t, t.confidence)
    }
}
