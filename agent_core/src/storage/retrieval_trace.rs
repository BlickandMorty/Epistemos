//! Typed retrieval-trace surface for the Epistemos vault.
//!
//! The T21 Vault Recall Contract demands that every retrieval emit a
//! `RetrievalTrace` carrying the **five canonical signals** —
//! `Lexical`, `Semantic`, `Graph`, `Recency`, `Mmr` — rather than
//! collapsing them into a single ranked list. The trace is the proof-
//! object that the "first 7 irrelevant notes" failure is structurally
//! impossible: a retrieval that cannot name what it consulted has not
//! consulted anything.
//!
//! This module ships **the types only**. The production emission seam
//! (vault.rs / vault_search_ladder.rs / ChatCoordinator) lands in
//! follow-on iters. Pure-additive; zero impact on existing retrievers.
//!
//! Cross-references:
//! - `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` — Defect 3
//!   names the floor-system signal that the trace makes legible.
//! - `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T21
//!   ("every vault retrieval … emits lexical, semantic, graph, recency,
//!   and MMR trace").
//! - `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` W-19
//!   (ChatCoordinator vault-context-injection seam) and W-20
//!   (provenance cards rendered in ≥ 3 surfaces).

use serde::{Deserialize, Serialize};

/// The five canonical retrieval signals. **Do not collapse.** Each
/// retrieval must score every retained candidate against every applicable
/// signal so downstream consumers (Brain Panel, ChatCoordinator, W-21
/// diagnostics) can render "Retrieved by …" without re-deriving the
/// signal breakdown.
///
/// `Lexical` and `Semantic` are always emitted by the hybrid path;
/// `Graph`, `Recency`, and `Mmr` are emitted when their respective
/// pipelines are wired (graph: link/cluster edges; recency: time-decay
/// reweighting; MMR: diversity-aware reranking).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RetrievalSignal {
    /// BM25 / Tantivy keyword score. Raw, unclamped (see Fix C in the
    /// F-VaultRecall-50 diagnosis).
    Lexical,
    /// Cosine / inner-product score over an embedding (Model2Vec / HNSW
    /// in `epistemos-shadow`, or a future agent-side embedding seam).
    ///
    /// **T21 Q2 — INTEGRATION PATH PENDING.** No `VaultBackend` impl
    /// populates this signal today because `epistemos-shadow` lives as
    /// a separate `cdylib` crate for Swift FFI; its public Rust API
    /// isn't exposed for non-Swift in-process callers. Three integration
    /// options under consideration (cargo dep / FFI from Rust /
    /// pure-Rust core carve-out) — see
    /// `docs/F_VAULT_RECALL_50_2026_05_18.md` §8 Q2 for the full
    /// research-question writeup. Until resolved, the 5-signal
    /// retrieval trace ships Lexical-only.
    Semantic,
    /// Reachability / link-edge score over the note graph (e.g. a note
    /// linked from a high-confidence hit gets a bump).
    Graph,
    /// Exponential time-decay reweighting; newer notes outrank stale
    /// matches at equal lexical / semantic confidence.
    Recency,
    /// Maximal-Marginal-Relevance diversification — penalizes near-
    /// duplicates so the top-N covers distinct sub-topics.
    Mmr,
}

impl RetrievalSignal {
    /// Canonical iteration order. Used by `RetrievalTrace` builders to
    /// render trace rows in a deterministic order regardless of map
    /// insertion sequence.
    pub const ALL: [RetrievalSignal; 5] = [
        RetrievalSignal::Lexical,
        RetrievalSignal::Semantic,
        RetrievalSignal::Graph,
        RetrievalSignal::Recency,
        RetrievalSignal::Mmr,
    ];

    /// Lowercase string slug — used in JSON serialization (matches the
    /// `#[serde(rename_all = "lowercase")]` derive) and as the W-20
    /// provenance-card chip label.
    pub fn slug(&self) -> &'static str {
        match self {
            RetrievalSignal::Lexical => "lexical",
            RetrievalSignal::Semantic => "semantic",
            RetrievalSignal::Graph => "graph",
            RetrievalSignal::Recency => "recency",
            RetrievalSignal::Mmr => "mmr",
        }
    }
}

/// One signal's contribution to a candidate's selection.
///
/// `raw` is the signal's native unit (BM25 score, cosine similarity,
/// graph-walk score, etc.) — unclamped, unnormalized, exactly the
/// number the underlying pipeline produced. `normalized` is the
/// `[0.0, 1.0]` rank-fused value used by the RRF / weighted-sum
/// reranker. Keeping both lets the diagnostics surface show "BM25
/// 4.21 → rrf 0.83" without re-deriving either side.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RetrievalSignalScore {
    pub signal: RetrievalSignal,
    pub raw: f64,
    pub normalized: f64,
}

impl RetrievalSignalScore {
    /// Build a signal score record. Callers may pass `normalized` ==
    /// `raw` when the signal pipeline is already in `[0, 1]` (e.g.
    /// cosine similarity).
    pub fn new(signal: RetrievalSignal, raw: f64, normalized: f64) -> Self {
        Self {
            signal,
            raw,
            normalized,
        }
    }
}

/// A retained candidate plus its per-signal score breakdown.
///
/// `selection_reason` is a human-readable summary — short enough to
/// render as a provenance-card subtitle, long enough to give the user
/// a one-line "why this note?" answer. The trace MUST cite the
/// canonical vault path (a `UasAddress` typed version lands when W-22
/// is wired and the T3 + T4 branches are merged).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RetrievalCandidate {
    pub path: String,
    pub title: Option<String>,
    pub snippet: Option<String>,
    pub fused_score: f64,
    pub signals: Vec<RetrievalSignalScore>,
    pub selection_reason: String,
}

impl RetrievalCandidate {
    pub fn new(path: impl Into<String>, fused_score: f64) -> Self {
        Self {
            path: path.into(),
            title: None,
            snippet: None,
            fused_score,
            signals: Vec::new(),
            selection_reason: String::new(),
        }
    }

    pub fn with_signal(mut self, score: RetrievalSignalScore) -> Self {
        self.signals.push(score);
        self
    }

    pub fn with_title(mut self, title: impl Into<String>) -> Self {
        self.title = Some(title.into());
        self
    }

    pub fn with_snippet(mut self, snippet: impl Into<String>) -> Self {
        self.snippet = Some(snippet.into());
        self
    }

    pub fn with_selection_reason(mut self, reason: impl Into<String>) -> Self {
        self.selection_reason = reason.into();
        self
    }

    /// T21 iter-41: human-readable one-line render of the candidate.
    /// Completes the per-type render quartet:
    /// `RetrievalCandidate::summary_line` (this iter),
    /// `RetrievalTrace::summary_line` (iter-38),
    /// `FVaultRecallSummary::verdict_line` (iter-35), and
    /// `FVaultRecallRowOutcome::verdict_line` (iter-7).
    ///
    /// Format: `"<path> (fused: <fused_score:.2>, signals: <N>) —
    /// <selection_reason>"`. Empty `selection_reason` renders as
    /// `"(no reason)"`. Used by Brain Panel provenance-card tooltips
    /// and CLI verbose mode.
    pub fn summary_line(&self) -> String {
        let reason = if self.selection_reason.is_empty() {
            "(no reason)"
        } else {
            self.selection_reason.as_str()
        };
        format!(
            "{} (fused: {:.2}, signals: {}) — {}",
            self.path,
            self.fused_score,
            self.signals.len(),
            reason
        )
    }
}

/// Top-level retrieval trace. One emitted per `VaultBackend::hybrid_search`
/// call once the emission seam lands. The trace is the W-19 / W-20 / W-21
/// payload: ChatCoordinator's "Retrieved by …" surface, the Brain Panel
/// provenance cards, and the Settings diagnostics "Vault recall health"
/// row all consume this single shape.
///
/// `candidate_pool_size` records the full count Tantivy returned before
/// any culling, so the T21 acceptance-bar requirement "retrieves 50–200
/// candidates before final context packing" is auditable from the trace
/// alone — index-order LIMIT-N retrievals show up as a small pool here.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RetrievalTrace {
    pub query: String,
    pub effective_query: String,
    pub ladder_tier: Option<String>,
    pub candidate_pool_size: usize,
    pub candidates_retained: usize,
    pub candidates: Vec<RetrievalCandidate>,
    pub signal_summary: Vec<RetrievalSignal>,
    pub generated_at_ms: u64,
    pub notes: Vec<String>,
    /// T21 iter-10 (2026-05-18): set by the retrieval backend when
    /// `strip_query_chatter` reduced the query to the empty string
    /// (e.g. user typed "show me my notes" — every token is chatter).
    /// The backend then falls back to the raw input, which means
    /// downstream candidates are matching against noise. Consumers
    /// MUST treat the trace as weak evidence regardless of candidate
    /// count; `evidence_strength()` enforces this.
    /// `#[serde(default)]` so older serialized traces deserialize cleanly.
    #[serde(default)]
    pub all_chatter_fallback: bool,
}

impl RetrievalTrace {
    /// Open a new trace with just the query strings populated. Callers
    /// fill `candidates` / `signal_summary` / `notes` as the retrieval
    /// pipeline runs. The `effective_query` records the chatter-stripped
    /// form so a reader can see the Fix-B transformation that fed Tantivy.
    pub fn new(query: impl Into<String>, effective_query: impl Into<String>) -> Self {
        Self {
            query: query.into(),
            effective_query: effective_query.into(),
            ladder_tier: None,
            candidate_pool_size: 0,
            candidates_retained: 0,
            candidates: Vec::new(),
            signal_summary: Vec::new(),
            generated_at_ms: 0,
            notes: Vec::new(),
            all_chatter_fallback: false,
        }
    }

    /// T21 iter-10: mark this trace as having fallen back to the raw
    /// (chatter-laden) query because the chatter-strip emptied the
    /// query. Downstream consumers MUST treat this trace as weak
    /// evidence; `evidence_strength()` returns
    /// [`EvidenceStrength::Weak`] when this flag is set regardless
    /// of retained candidate count.
    pub fn record_all_chatter_fallback(&mut self) {
        self.all_chatter_fallback = true;
    }

    pub fn with_ladder_tier(mut self, tier: impl Into<String>) -> Self {
        self.ladder_tier = Some(tier.into());
        self
    }

    pub fn with_pool_size(mut self, pool: usize) -> Self {
        self.candidate_pool_size = pool;
        self
    }

    pub fn push_candidate(&mut self, candidate: RetrievalCandidate) {
        self.candidates.push(candidate);
        self.candidates_retained = self.candidates.len();
    }

    pub fn record_signal(&mut self, signal: RetrievalSignal) {
        if !self.signal_summary.contains(&signal) {
            self.signal_summary.push(signal);
        }
    }

    pub fn add_note(&mut self, note: impl Into<String>) {
        self.notes.push(note.into());
    }

    /// T21 iter-38: human-readable one-line render of the trace, useful
    /// for log / CLI verbose / W-21 trace-detail tooltips. Completes the
    /// symmetric helper set (`FVaultRecallRowOutcome::verdict_line` from
    /// iter-7, `FVaultRecallSummary::verdict_line` from iter-35, this
    /// from iter-38).
    ///
    /// Format:
    /// `"query: '<q>' / effective: '<eq>' / pool: <N> / retained: <M>
    ///   / signals: <slug,slug,…> / verdict: <Weak|Moderate|Strong>
    ///   / notes: <K>"`.
    pub fn summary_line(&self) -> String {
        let signals: Vec<&str> = self.signal_summary.iter().map(|s| s.slug()).collect();
        let signals_str = if signals.is_empty() {
            String::from("none")
        } else {
            signals.join(",")
        };
        let verdict = self.evidence_strength().slug();
        format!(
            "query: '{}' / effective: '{}' / pool: {} / retained: {} \
             / signals: {} / verdict: {} / notes: {}",
            self.query,
            self.effective_query,
            self.candidate_pool_size,
            self.candidates_retained,
            signals_str,
            verdict,
            self.notes.len()
        )
    }

    /// T21 evidence-strength classifier (iter-9 base, iter-10 refined).
    ///
    /// Returns a structural verdict on whether this trace carries enough
    /// retained evidence to inject a context pack into a chat reply.
    /// **Structural, not threshold-based** — based on retained candidate
    /// count, not BM25 magnitude — so the verdict is corpus-size-
    /// independent and matches the T21 acceptance bar's "ask or broaden
    /// when evidence is weak" rule.
    ///
    /// The chatter-strip note (Fix-B activation) is NOT a weakness signal;
    /// it's the canonical pre-processor doing its job. However, the
    /// **all-chatter fallback** (`self.all_chatter_fallback`) IS a
    /// weakness signal — it means the backend matched against the raw
    /// chatter-laden query because every token was chatter, so retained
    /// candidates are noise regardless of count.
    ///
    /// The W-19 ChatCoordinator wiring consumes this verdict to decide
    /// between (a) inject context and answer, (b) ask the user to
    /// clarify, or (c) widen the query.
    pub fn evidence_strength(&self) -> EvidenceStrength {
        if self.all_chatter_fallback {
            return EvidenceStrength::Weak;
        }
        match self.candidates_retained {
            0 => EvidenceStrength::Weak,
            1 | 2 => EvidenceStrength::Moderate,
            _ => EvidenceStrength::Strong,
        }
    }
}

/// Verdict for the evidence-strength classifier. See
/// [`RetrievalTrace::evidence_strength`] for the contract.
///
/// Variants are ordered (`Weak < Moderate < Strong`) so callers can
/// compare verdicts with `<` / `>` — useful for "max of two traces'
/// verdicts" or "threshold-gated" patterns. The declaration order
/// drives the derived `Ord` impl.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum EvidenceStrength {
    /// No retained candidates. Consumers MUST ask the user to clarify
    /// or broaden the query — never inject a context pack from this
    /// trace.
    Weak,
    /// 1–2 retained candidates. Some signal, but not enough to
    /// confidently answer a multi-source synthesis question. Consumers
    /// SHOULD widen the query or annotate the response as low-
    /// confidence.
    Moderate,
    /// ≥ 3 retained candidates. Sufficient coverage to inject a context
    /// pack; the response can cite the candidates with full confidence
    /// in coverage breadth (per-citation accuracy is still bounded by
    /// the underlying signal quality).
    Strong,
}

impl EvidenceStrength {
    /// Lowercase string slug (matches the `#[serde(rename_all =
    /// "lowercase")]` derive). Used as the chip label on the W-20
    /// provenance-card surface.
    pub fn slug(&self) -> &'static str {
        match self {
            EvidenceStrength::Weak => "weak",
            EvidenceStrength::Moderate => "moderate",
            EvidenceStrength::Strong => "strong",
        }
    }

    /// T21 iter-55: convenience predicate — is this verdict at the floor
    /// (Weak)? The W-19 ChatCoordinator wiring asks "below floor → ask
    /// or broaden" semantics, and this helper avoids spreading the
    /// `== Weak` literal across consumers. Future verdict levels (e.g.
    /// `VeryWeak`) could broaden this without touching every caller.
    pub fn is_at_floor(&self) -> bool {
        matches!(self, EvidenceStrength::Weak)
    }

    /// T21 iter-55: convenience predicate — is this verdict strong
    /// enough to inject a context pack? Mirror of `is_at_floor`. The
    /// W-19 ChatCoordinator uses this to gate "answer with retrieved
    /// context" vs "ask user to clarify or broaden."
    pub fn is_strong(&self) -> bool {
        matches!(self, EvidenceStrength::Strong)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// All five canonical signals must be present in `RetrievalSignal::ALL`.
    /// The "never collapse the trace into a simple ranked list" rule from
    /// the T21 prompt deck hinges on this constant.
    #[test]
    fn retrieval_signal_all_contains_the_five_canonical_signals() {
        assert_eq!(RetrievalSignal::ALL.len(), 5);
        let mut seen = std::collections::HashSet::new();
        for signal in RetrievalSignal::ALL {
            assert!(seen.insert(signal), "duplicate signal in ALL: {:?}", signal);
        }
        assert!(seen.contains(&RetrievalSignal::Lexical));
        assert!(seen.contains(&RetrievalSignal::Semantic));
        assert!(seen.contains(&RetrievalSignal::Graph));
        assert!(seen.contains(&RetrievalSignal::Recency));
        assert!(seen.contains(&RetrievalSignal::Mmr));
    }

    /// Slugs are lowercase, stable, and disjoint (no two signals share a
    /// slug). The W-20 provenance-card chip uses these as JSON keys.
    #[test]
    fn retrieval_signal_slugs_are_stable_lowercase_and_disjoint() {
        let mut slugs = std::collections::HashSet::new();
        for signal in RetrievalSignal::ALL {
            let slug = signal.slug();
            assert_eq!(
                slug,
                slug.to_lowercase(),
                "signal slug must be lowercase: {slug}"
            );
            assert!(!slug.is_empty(), "signal slug must be non-empty");
            assert!(slugs.insert(slug), "duplicate slug: {slug}");
        }
    }

    /// Builder methods stack: chained `.with_title()` / `.with_snippet()` /
    /// `.with_signal()` produce a candidate with all four fields set, and
    /// `.signals` grows by one per `.with_signal()` call.
    #[test]
    fn retrieval_candidate_builder_stacks() {
        let candidate = RetrievalCandidate::new("notes/residency.md", 4.21)
            .with_title("Residency Governance")
            .with_snippet("Tier 3 residency governance budget …")
            .with_signal(RetrievalSignalScore::new(
                RetrievalSignal::Lexical,
                4.21,
                0.83,
            ))
            .with_signal(RetrievalSignalScore::new(
                RetrievalSignal::Semantic,
                0.91,
                0.91,
            ))
            .with_selection_reason("lexical:4.21 + semantic:0.91 fused via RRF k=60");
        assert_eq!(candidate.path, "notes/residency.md");
        assert_eq!(candidate.title.as_deref(), Some("Residency Governance"));
        assert!(candidate.snippet.is_some());
        assert_eq!(candidate.signals.len(), 2);
        assert_eq!(candidate.fused_score, 4.21);
        assert!(candidate.selection_reason.contains("RRF"));
    }

    /// `RetrievalTrace::new` initializes empty collections + zero counters;
    /// `push_candidate` increments `candidates_retained`; `record_signal`
    /// dedupes; `with_ladder_tier` and `with_pool_size` set their fields.
    #[test]
    fn retrieval_trace_builders_update_state_correctly() {
        let mut trace = RetrievalTrace::new(
            "Pull my notes on residency governance",
            "residency governance",
        )
        .with_ladder_tier("T1_Lexical_Bm25")
        .with_pool_size(57);
        assert_eq!(trace.candidates_retained, 0);
        assert_eq!(trace.candidate_pool_size, 57);
        assert_eq!(trace.ladder_tier.as_deref(), Some("T1_Lexical_Bm25"));

        trace.push_candidate(RetrievalCandidate::new("a.md", 4.0));
        trace.push_candidate(RetrievalCandidate::new("b.md", 3.2));
        assert_eq!(trace.candidates_retained, 2);

        trace.record_signal(RetrievalSignal::Lexical);
        trace.record_signal(RetrievalSignal::Semantic);
        trace.record_signal(RetrievalSignal::Lexical);
        assert_eq!(trace.signal_summary.len(), 2, "signal_summary dedupes");

        trace.add_note("Tier 1 accepted after Fix-B chatter strip");
        assert_eq!(trace.notes.len(), 1);
    }

    /// T21 iter-9: empty trace classifies as Weak — there's no retained
    /// evidence to inject. Consumers MUST ask/broaden, never pretend
    /// coverage. This is the structural floor of the acceptance bar's
    /// "ask or broaden when evidence is weak" rule.
    #[test]
    fn evidence_strength_empty_trace_is_weak() {
        let trace = RetrievalTrace::new("foo", "foo");
        assert_eq!(trace.evidence_strength(), EvidenceStrength::Weak);
    }

    /// T21 iter-9: 1–2 candidates classify as Moderate. The W-19
    /// ChatCoordinator wiring should widen or annotate.
    #[test]
    fn evidence_strength_one_or_two_candidates_is_moderate() {
        let mut t1 = RetrievalTrace::new("a", "a");
        t1.push_candidate(RetrievalCandidate::new("a.md", 1.0));
        assert_eq!(t1.evidence_strength(), EvidenceStrength::Moderate);

        let mut t2 = RetrievalTrace::new("a b", "a b");
        t2.push_candidate(RetrievalCandidate::new("a.md", 1.0));
        t2.push_candidate(RetrievalCandidate::new("b.md", 0.5));
        assert_eq!(t2.evidence_strength(), EvidenceStrength::Moderate);
    }

    /// T21 iter-9: ≥ 3 candidates classify as Strong. Consumers can
    /// inject the context pack with full coverage-breadth confidence.
    #[test]
    fn evidence_strength_three_or_more_candidates_is_strong() {
        let mut trace = RetrievalTrace::new("q", "q");
        for path in ["a.md", "b.md", "c.md"] {
            trace.push_candidate(RetrievalCandidate::new(path, 1.0));
        }
        assert_eq!(trace.evidence_strength(), EvidenceStrength::Strong);

        // 5 candidates: still Strong (the threshold is ≥ 3, not exactly 3).
        let mut larger = RetrievalTrace::new("q", "q");
        for path in ["a.md", "b.md", "c.md", "d.md", "e.md"] {
            larger.push_candidate(RetrievalCandidate::new(path, 1.0));
        }
        assert_eq!(larger.evidence_strength(), EvidenceStrength::Strong);
    }

    /// T21 iter-41: a minimal `RetrievalCandidate` (path + score, no
    /// signals, no reason) renders a stable summary line with the
    /// "(no reason)" placeholder.
    #[test]
    fn candidate_summary_line_minimal() {
        let candidate = RetrievalCandidate::new("notes/foo.md", 1.23);
        let line = candidate.summary_line();
        assert!(line.contains("notes/foo.md"));
        assert!(line.contains("fused: 1.23"));
        assert!(line.contains("signals: 0"));
        assert!(line.contains("(no reason)"));
    }

    /// T21 iter-41: a fully populated candidate renders path, fused
    /// score, signal count, and the selection_reason verbatim.
    #[test]
    fn candidate_summary_line_populated() {
        let candidate = RetrievalCandidate::new("notes/residency.md", 4.93)
            .with_signal(RetrievalSignalScore::new(
                RetrievalSignal::Lexical,
                4.93,
                0.88,
            ))
            .with_signal(RetrievalSignalScore::new(
                RetrievalSignal::Semantic,
                0.91,
                0.91,
            ))
            .with_selection_reason("lexical:4.93 + semantic:0.91 via RRF k=60");
        let line = candidate.summary_line();
        assert!(line.contains("notes/residency.md"));
        assert!(line.contains("fused: 4.93"));
        assert!(line.contains("signals: 2"));
        assert!(line.contains("RRF k=60"));
    }

    /// T21 iter-38: minimal (empty) trace renders a stable summary line.
    /// The verdict is "weak" (empty trace → 0 candidates → Weak); signals
    /// shows "none"; notes count is 0.
    #[test]
    fn summary_line_empty_trace_is_stable() {
        let trace = RetrievalTrace::new("hello", "hello");
        let line = trace.summary_line();
        assert!(line.contains("query: 'hello'"));
        assert!(line.contains("effective: 'hello'"));
        assert!(line.contains("pool: 0"));
        assert!(line.contains("retained: 0"));
        assert!(line.contains("signals: none"));
        assert!(line.contains("verdict: weak"));
        assert!(line.contains("notes: 0"));
    }

    /// T21 iter-38: populated trace renders all fields. Signals join
    /// in `signal_summary` order (Lexical first per iter-4 emission seam).
    /// Verdict reflects the candidate count.
    #[test]
    fn summary_line_populated_trace_renders_all_fields() {
        let mut trace = RetrievalTrace::new(
            "Pull my notes on residency governance",
            "residency governance",
        )
        .with_ladder_tier("T1_Lexical_Bm25")
        .with_pool_size(7);
        trace.record_signal(RetrievalSignal::Lexical);
        trace.record_signal(RetrievalSignal::Semantic);
        for path in ["a.md", "b.md", "c.md"] {
            trace.push_candidate(RetrievalCandidate::new(path, 4.0));
        }
        trace.add_note("Fix-B chatter strip: …");

        let line = trace.summary_line();
        assert!(line.contains("query: 'Pull my notes on residency governance'"));
        assert!(line.contains("effective: 'residency governance'"));
        assert!(line.contains("pool: 7"));
        assert!(line.contains("retained: 3"));
        assert!(line.contains("signals: lexical,semantic"));
        assert!(line.contains("verdict: strong")); // ≥ 3 candidates, no fallback
        assert!(line.contains("notes: 1"));
    }

    /// T21 iter-38: the `all_chatter_fallback` flag forces the verdict
    /// to "weak" in `summary_line()` even when candidates were retained
    /// — same rule as the underlying `evidence_strength()`.
    #[test]
    fn summary_line_all_chatter_fallback_shows_weak_verdict() {
        let mut trace = RetrievalTrace::new("show me my notes", "show me my notes");
        for path in ["a.md", "b.md", "c.md", "d.md"] {
            trace.push_candidate(RetrievalCandidate::new(path, 1.0));
        }
        // Without flag: Strong (4 candidates).
        assert!(trace.summary_line().contains("verdict: strong"));
        trace.record_all_chatter_fallback();
        // With flag: Weak regardless of count.
        assert!(trace.summary_line().contains("verdict: weak"));
    }

    /// T21 iter-10: even with ≥ 3 candidates, `all_chatter_fallback`
    /// downgrades the verdict to Weak. The candidates were matched
    /// against the chatter-laden raw query (no signal terms survived),
    /// so they're noise regardless of count.
    #[test]
    fn evidence_strength_all_chatter_fallback_forces_weak() {
        let mut trace = RetrievalTrace::new("show me my notes", "show me my notes");
        for path in ["a.md", "b.md", "c.md", "d.md"] {
            trace.push_candidate(RetrievalCandidate::new(path, 1.0));
        }
        // Without the flag, 4 candidates ≥ 3 → Strong.
        assert_eq!(trace.evidence_strength(), EvidenceStrength::Strong);
        trace.record_all_chatter_fallback();
        // Flag flips the verdict to Weak regardless of count.
        assert_eq!(trace.evidence_strength(), EvidenceStrength::Weak);
        assert!(trace.all_chatter_fallback);
    }

    /// `record_all_chatter_fallback` is idempotent — calling it twice
    /// doesn't toggle, and the field stays observable.
    #[test]
    fn record_all_chatter_fallback_is_idempotent() {
        let mut trace = RetrievalTrace::new("q", "q");
        assert!(!trace.all_chatter_fallback);
        trace.record_all_chatter_fallback();
        assert!(trace.all_chatter_fallback);
        trace.record_all_chatter_fallback();
        assert!(trace.all_chatter_fallback);
    }

    /// T21 iter-60: `EvidenceStrength` derives `PartialOrd` / `Ord` from
    /// the variant declaration order, so `Weak < Moderate < Strong`.
    /// Pins the canonical strength ordering so consumers can use
    /// comparison operators and `max` / `min` without reinventing the
    /// total order.
    #[test]
    fn evidence_strength_orders_weak_below_moderate_below_strong() {
        assert!(EvidenceStrength::Weak < EvidenceStrength::Moderate);
        assert!(EvidenceStrength::Moderate < EvidenceStrength::Strong);
        assert!(EvidenceStrength::Weak < EvidenceStrength::Strong);

        // max picks the strongest verdict — useful when fusing two
        // traces.
        let combined = std::cmp::max(EvidenceStrength::Weak, EvidenceStrength::Strong);
        assert_eq!(combined, EvidenceStrength::Strong);
    }

    /// T21 iter-55: `is_at_floor()` returns true only for Weak; mirrors
    /// `is_strong()` which returns true only for Strong. Moderate is
    /// neither at-floor nor strong — sits in the middle. The W-19
    /// ChatCoordinator uses these predicates to decide between
    /// inject / ask-or-broaden without spreading enum-variant checks
    /// across consumers.
    #[test]
    fn evidence_strength_predicates_partition_the_three_variants() {
        assert!(EvidenceStrength::Weak.is_at_floor());
        assert!(!EvidenceStrength::Weak.is_strong());

        assert!(!EvidenceStrength::Moderate.is_at_floor());
        assert!(!EvidenceStrength::Moderate.is_strong());

        assert!(!EvidenceStrength::Strong.is_at_floor());
        assert!(EvidenceStrength::Strong.is_strong());
    }

    /// EvidenceStrength slugs are stable lowercase + disjoint. Used as
    /// W-20 provenance-card chip labels and W-21 diagnostics keys.
    #[test]
    fn evidence_strength_slugs_are_stable_lowercase_and_disjoint() {
        let strengths = [
            EvidenceStrength::Weak,
            EvidenceStrength::Moderate,
            EvidenceStrength::Strong,
        ];
        let mut slugs = std::collections::HashSet::new();
        for strength in strengths {
            let slug = strength.slug();
            assert_eq!(slug, slug.to_lowercase());
            assert!(!slug.is_empty());
            assert!(slugs.insert(slug), "duplicate slug: {slug}");
        }
    }

    /// EvidenceStrength round-trips through JSON with the lowercase
    /// serde representation. Pinned so the W-20 / W-21 surfaces can
    /// deserialize without ambiguity.
    #[test]
    fn evidence_strength_round_trips_through_json() {
        for strength in [
            EvidenceStrength::Weak,
            EvidenceStrength::Moderate,
            EvidenceStrength::Strong,
        ] {
            let encoded = serde_json::to_string(&strength).expect("serialize");
            // serde_json wraps simple enum variants in JSON strings.
            assert!(encoded.starts_with('"') && encoded.ends_with('"'));
            assert!(encoded.contains(strength.slug()));
            let decoded: EvidenceStrength =
                serde_json::from_str(&encoded).expect("deserialize");
            assert_eq!(decoded, strength);
        }
    }

    /// Full round-trip through JSON. The W-21 Settings diagnostics row will
    /// serialize traces to JSON for the Brain Panel + persistence; the
    /// shape MUST survive that round-trip byte-for-byte (semantically).
    #[test]
    fn retrieval_trace_round_trips_through_json() {
        let mut trace = RetrievalTrace::new(
            "Pull my notes on residency governance",
            "residency governance",
        )
        .with_ladder_tier("T3_Rrf_Hybrid")
        .with_pool_size(120);
        trace.push_candidate(
            RetrievalCandidate::new("MASTER_FUSION/3_2_residency_governor.md", 4.93)
                .with_title("Residency Governor §3.2")
                .with_signal(RetrievalSignalScore::new(
                    RetrievalSignal::Lexical,
                    4.93,
                    0.88,
                ))
                .with_selection_reason("lexical:4.93 → rrf 0.88"),
        );
        trace.record_signal(RetrievalSignal::Lexical);
        trace.add_note("Fix-B chatter strip applied");

        let encoded = serde_json::to_string(&trace).expect("serialize");
        let decoded: RetrievalTrace = serde_json::from_str(&encoded).expect("deserialize");
        assert_eq!(decoded, trace);
        // Slug check: signal serialized as lowercase "lexical".
        assert!(
            encoded.contains("\"lexical\""),
            "expected lowercase signal slug in JSON: {encoded}"
        );
    }
}
