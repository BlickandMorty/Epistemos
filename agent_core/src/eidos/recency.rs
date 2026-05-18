//! Recency retrieval mode — time-ordered retrieval.
//!
//! Unlike the other retrievers, Recency treats an **empty** `query.text` as
//! a meaningful query ("no substring filter, give me top_k most recent
//! documents") rather than the empty-defer convention used elsewhere. The
//! reason: "what did I most recently capture?" is a real closed-citation
//! query, and forcing the chat layer to invent a substring just to use the
//! mode would make Recency hostile to use.
//!
//! Non-empty `query.text` is a case-insensitive Unicode-aware substring
//! filter (same shape as Lexical) — documents whose body does not contain
//! the substring are dropped before recency sort.
//!
//! Deterministic ordering: `(created_at_unix_ms desc, source_id asc)`. The
//! source_id tie-break is what keeps replay byte-equal when two documents
//! share an exact timestamp.
//!
//! Recency score is `1.0 / (1.0 + age_days)` where `age_days =
//! (retrieved_at - created_at).saturating_sub(0) / 86_400_000`. A document
//! created exactly at `retrieved_at` scores 1.0; one day old scores 0.5; one
//! week old scores ~0.125. Saturating subtraction guards against clock
//! skew (created_at > retrieved_at): the score in that case is 1.0, which
//! is safe because Recency never claims to verify timestamps — that's
//! Provenance's job.

use super::retriever::EidosRetriever;
use super::types::{
    EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit, EidosIndexManifestId,
    EidosProvenance, EidosQuery, EidosRetrievalMode, EidosScoreComponents, EidosSourceKind,
};

const ONE_DAY_MS: u64 = 86_400_000;

#[derive(Clone, Debug)]
struct RecencyDocument {
    document_id: EidosDocumentId,
    body: String,
    body_lower: String,
    created_at_unix_ms: u64,
    kind: EidosSourceKind,
}

#[derive(Clone, Debug)]
pub struct InMemoryRecencyIndex {
    manifest_id: EidosIndexManifestId,
    documents: Vec<RecencyDocument>,
}

impl InMemoryRecencyIndex {
    pub fn new(manifest_id: EidosIndexManifestId) -> Self {
        Self {
            manifest_id,
            documents: Vec::new(),
        }
    }

    pub fn insert(
        &mut self,
        document_id: EidosDocumentId,
        body: impl Into<String>,
        created_at_unix_ms: u64,
        kind: EidosSourceKind,
    ) {
        let body = body.into();
        let body_lower = body.to_lowercase();
        if let Some(slot) = self
            .documents
            .iter_mut()
            .find(|d| d.document_id == document_id)
        {
            slot.body = body;
            slot.body_lower = body_lower;
            slot.created_at_unix_ms = created_at_unix_ms;
            slot.kind = kind;
        } else {
            self.documents.push(RecencyDocument {
                document_id,
                body,
                body_lower,
                created_at_unix_ms,
                kind,
            });
        }
    }

    fn score(retrieved_at_unix_ms: u64, created_at_unix_ms: u64) -> f32 {
        let age_ms = retrieved_at_unix_ms.saturating_sub(created_at_unix_ms);
        let age_days = age_ms as f32 / ONE_DAY_MS as f32;
        1.0 / (1.0 + age_days)
    }
}

impl EidosRetriever for InMemoryRecencyIndex {
    fn mode(&self) -> EidosRetrievalMode {
        EidosRetrievalMode::Recency
    }

    fn manifest_id(&self) -> &EidosIndexManifestId {
        &self.manifest_id
    }

    fn retrieve(
        &self,
        query: &EidosQuery,
        retrieved_at_unix_ms: u64,
    ) -> EidosContextPacket {
        if query.top_k == 0 {
            return empty_packet(query, &self.manifest_id);
        }

        // Empty filter text is meaningful — "no substring filter, give me
        // top_k most recent". Non-empty filters as case-insensitive
        // substring (matching Lexical's semantics).
        let filter: Option<String> = if query.text.is_empty() {
            None
        } else {
            Some(query.text.to_lowercase())
        };

        let since_floor = query.since_unix_ms;
        let mut sorted: Vec<&RecencyDocument> = self
            .documents
            .iter()
            .filter(|d| match &filter {
                None => true,
                Some(needle) => d.body_lower.contains(needle),
            })
            .filter(|d| match since_floor {
                None => true,
                Some(floor) => d.created_at_unix_ms >= floor,
            })
            .collect();

        sorted.sort_by(|a, b| {
            b.created_at_unix_ms
                .cmp(&a.created_at_unix_ms)
                .then_with(|| a.document_id.as_str().cmp(b.document_id.as_str()))
        });

        let top_k = query.top_k as usize;
        let hits: Vec<EidosHit> = sorted
            .into_iter()
            .take(top_k)
            .map(|doc| {
                let chunk_id =
                    EidosChunkId::new(format!("{}::recency", doc.document_id.as_str()))
                        .expect("document_id non-empty by construction");
                let recency_score = Self::score(retrieved_at_unix_ms, doc.created_at_unix_ms);
                EidosHit {
                    source_id: chunk_id,
                    document_id: doc.document_id.clone(),
                    kind: doc.kind,
                    span: None,
                    confidence: recency_score.clamp(0.0, 1.0),
                    score: EidosScoreComponents {
                        lexical: 0.0,
                        semantic: 0.0,
                        recency: recency_score.clamp(0.0, 1.0),
                        graph: 0.0,
                    },
                    provenance: EidosProvenance {
                        manifest_id: self.manifest_id.clone(),
                        mode: EidosRetrievalMode::Recency,
                        retrieved_at_unix_ms,
                    },
                }
            })
            .collect();

        EidosContextPacket {
            query: query.clone(),
            manifest_id: self.manifest_id.clone(),
            hits,
        }
    }
}

fn empty_packet(query: &EidosQuery, manifest: &EidosIndexManifestId) -> EidosContextPacket {
    EidosContextPacket {
        query: query.clone(),
        manifest_id: manifest.clone(),
        hits: vec![],
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::eidos::types::EidosCitation;

    fn manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("recency-test-manifest").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    const T0: u64 = 1_700_000_000_000;

    fn build() -> InMemoryRecencyIndex {
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("week-old"), "alpha content", T0 - 7 * ONE_DAY_MS, EidosSourceKind::Note);
        idx.insert(doc("yesterday"), "alpha gamma", T0 - ONE_DAY_MS, EidosSourceKind::Note);
        idx.insert(doc("today"), "alpha beta", T0, EidosSourceKind::Note);
        idx
    }

    #[test]
    fn recency_returns_top_k_most_recent_ordering() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        // Today first, then yesterday, then week-old. Source_id is suffixed
        // ::recency, so the ordering tie-break doesn't change the headline.
        assert_eq!(
            ids,
            vec![
                "today::recency",
                "yesterday::recency",
                "week-old::recency",
            ]
        );
    }

    #[test]
    fn recency_with_substring_filter_narrows_then_orders() {
        let idx = build();
        // "gamma" only matches yesterday's body. Today + week-old drop.
        let q = EidosQuery::new("gamma", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(ids, vec!["yesterday::recency"]);
    }

    #[test]
    fn recency_filter_then_rank_orders_multi_match_by_recency_desc() {
        // Audit per "audit existing claims first":
        //   - `recency_returns_top_k_most_recent_ordering` pins
        //     EMPTY-query (no filter) → 3 docs in recency-desc order.
        //   - `recency_with_substring_filter_narrows_then_orders`
        //     pins filter that narrows to exactly 1 doc.
        //   - `recency_substring_filter_is_case_insensitive` matches
        //     3 docs but only asserts top-1 source_id.
        //
        // Gap: filter-then-rank with MULTIPLE matches (>1) and
        // distinct created_at values isn't pinned. The contract is:
        // substring filter narrows first, recency-desc orders the
        // survivors. A future change to "rank-then-filter" would
        // change the top_k semantics but produce identical results
        // for the empty-query and single-match cases — only multi-
        // match ordering surfaces the bug.
        //
        // Build 3 docs all containing "tropical" with distinct
        // created_at: T0-2d ("tropical paper"), T0 ("tropical now"),
        // T0-7d ("tropical week"). Filter "tropical" → all 3 match;
        // recency desc → [now, paper, week].
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("paper"), "tropical paper", T0 - 2 * ONE_DAY_MS, EidosSourceKind::Note);
        idx.insert(doc("now"), "tropical now", T0, EidosSourceKind::Note);
        idx.insert(doc("week"), "tropical week", T0 - 7 * ONE_DAY_MS, EidosSourceKind::Note);
        let q = EidosQuery::new("tropical", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);

        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec![
                "now::recency",
                "paper::recency",
                "week::recency",
            ],
            "filter-then-rank: all 3 match 'tropical', survivors ordered created_at desc",
        );
    }

    #[test]
    fn recency_substring_filter_is_case_insensitive() {
        let idx = build();
        let q = EidosQuery::new("ALPHA", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        // All three contain "alpha"; ordering by recency.
        assert_eq!(packet.hits.len(), 3);
        assert_eq!(packet.hits[0].source_id.as_str(), "today::recency");
    }

    #[test]
    fn recency_score_decreases_with_age() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        // 3 hits: today (age 0d → 1.0), yesterday (age 1d → 0.5),
        // week-old (age 7d → 0.125).
        assert!((packet.hits[0].score.recency - 1.0).abs() < 1e-6);
        assert!((packet.hits[1].score.recency - 0.5).abs() < 1e-6);
        assert!((packet.hits[2].score.recency - 0.125).abs() < 1e-6);
    }

    #[test]
    fn empty_index_returns_empty_packet() {
        let idx = InMemoryRecencyIndex::new(manifest());
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn top_k_zero_returns_empty_packet() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 0);
        let packet = idx.retrieve(&q, T0);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn top_k_truncates_to_most_recent() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 1);
        let packet = idx.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].source_id.as_str(), "today::recency");
    }

    #[test]
    fn top_k_cuts_within_tied_timestamp_group_alphabetic_asc() {
        // Audit per "audit existing claims first":
        //   - `tie_break_on_source_id_when_timestamps_match` pins
        //     same-ts → source_id asc, but with top_k=16 (no cut).
        //   - `top_k_truncates_to_most_recent` pins truncation across
        //     DISTINCT timestamps.
        //   - The combined case — top_k cuts INTO a same-ts group —
        //     wasn't pinned. A future sort-stability or insertion-
        //     order regression could flip which docs survive the cut.
        //
        // Build three docs at the SAME timestamp (b, a, c — insertion
        // order intentionally not alphabetic). With top_k=2, the cut
        // must surface ["a", "b"] (alphabetic asc applied within the
        // tied group), NOT [b, a] or [c, b] or anything insertion-
        // order-derived.
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("b"), "x", T0, EidosSourceKind::Note);
        idx.insert(doc("a"), "x", T0, EidosSourceKind::Note);
        idx.insert(doc("c"), "x", T0, EidosSourceKind::Note);
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 2);
        let packet = idx.retrieve(&q, T0);

        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec!["a::recency", "b::recency"],
            "top_k=2 within a tied-ts group of 3 docs must keep \
             alphabetic-asc 'a' + 'b' (NOT insertion-order 'b' + 'a' \
             or any 'c'-containing variant)"
        );
    }

    #[test]
    fn tie_break_on_source_id_when_timestamps_match() {
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("b"), "x", T0, EidosSourceKind::Note);
        idx.insert(doc("a"), "x", T0, EidosSourceKind::Note);
        idx.insert(doc("c"), "x", T0, EidosSourceKind::Note);
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        // Same timestamp → source_id ascending.
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(ids, vec!["a::recency", "b::recency", "c::recency"]);
    }

    #[test]
    fn closed_citation_contract_holds_through_recency() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
        // A doc that exists in the index but didn't pass the substring
        // filter is NOT citable through the filtered packet.
        let filtered_q = EidosQuery::new("gamma", EidosRetrievalMode::Recency, 16);
        let filtered_packet = idx.retrieve(&filtered_q, T0);
        let dropped = EidosCitation {
            source_id: EidosChunkId::new("today::recency").unwrap(),
            manifest_id: filtered_packet.manifest_id.clone(),
        };
        assert!(filtered_packet.validate_citation(&dropped).is_err());
    }

    #[test]
    fn replay_byte_equal_for_pinned_clock() {
        let a = build();
        let b = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        assert_eq!(a.retrieve(&q, T0), b.retrieve(&q, T0));
    }

    #[test]
    fn retriever_advertises_recency_mode() {
        let idx = InMemoryRecencyIndex::new(manifest());
        assert_eq!(idx.mode(), EidosRetrievalMode::Recency);
        assert_eq!(idx.manifest_id(), &manifest());
    }

    #[test]
    fn clock_skew_doc_in_the_future_scores_one_no_panic() {
        // saturating_sub guards against created_at > retrieved_at. The doc
        // appears at recency 1.0 (we don't try to verify timestamps — that
        // is Provenance's job).
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("future"), "x", T0 + 10 * ONE_DAY_MS, EidosSourceKind::Note);
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1);
        assert!((packet.hits[0].score.recency - 1.0).abs() < 1e-6);
    }

    #[test]
    fn clock_skew_pins_confidence_in_unit_interval_alongside_recency() {
        // Companion to the clock-skew test above. The clock-skew path
        // asserts score.recency == 1.0; this one additionally pins:
        //
        //   1. hit.confidence is in [0, 1] for every hit (the bridge
        //      contract — Brain Panel + chat ranking read .confidence,
        //      not score.recency).
        //   2. For the Recency retriever, hit.confidence equals
        //      score.recency exactly. Catches a future refactor that
        //      stops clamping confidence (the .clamp(0.0, 1.0) call in
        //      recency.rs is what makes (1) hold even under f32 quirks).
        //   3. Both past and future docs co-exist in the same packet,
        //      with confidence still in-range for both.
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("past"), "x", T0 - 5 * ONE_DAY_MS, EidosSourceKind::Note);
        idx.insert(doc("future"), "x", T0 + 5 * ONE_DAY_MS, EidosSourceKind::Note);
        idx.insert(doc("now"), "x", T0, EidosSourceKind::Note);
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 3);

        for hit in &packet.hits {
            assert!(
                (0.0..=1.0).contains(&hit.confidence),
                "confidence {} out of [0, 1] for {}",
                hit.confidence,
                hit.source_id.as_str()
            );
            // For Recency, confidence is the clamped recency score —
            // identical to score.recency. Pin the equality so a future
            // re-normalization can't silently drift the two apart.
            assert!(
                (hit.confidence - hit.score.recency).abs() < 1e-6,
                "Recency: confidence ({}) must equal score.recency ({})",
                hit.confidence,
                hit.score.recency
            );
        }

        // The future doc and the now doc both score at the saturating
        // boundary (age == 0 ms) so both clock to confidence 1.0
        // exactly. Pin this so a future change that started
        // distinguishing "exact-now" from "future" surfaces here.
        let future_hit = packet
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "future")
            .unwrap();
        let now_hit = packet
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "now")
            .unwrap();
        assert!((future_hit.confidence - 1.0).abs() < 1e-6);
        assert!((now_hit.confidence - 1.0).abs() < 1e-6);
    }

    #[test]
    fn unicode_filter_text_works() {
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("note-1"), "École polytechnique", T0, EidosSourceKind::Note);
        idx.insert(
            doc("note-2"),
            "Привет world",
            T0 - ONE_DAY_MS,
            EidosSourceKind::Note,
        );
        let q = EidosQuery::new("привет", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].source_id.as_str(), "note-2::recency");
    }

    #[test]
    fn since_unix_ms_floor_drops_older_documents() {
        // Fixture has today, yesterday, week-old. since = T0 - 2*ONE_DAY
        // keeps today + yesterday, drops week-old.
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16)
            .with_since(T0 - 2 * ONE_DAY_MS);
        let packet = idx.retrieve(&q, T0);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(ids, vec!["today::recency", "yesterday::recency"]);
    }

    #[test]
    fn since_unix_ms_at_u64_max_is_type_boundary_safe() {
        // Sibling to `since_unix_ms_floor_in_the_future_returns_empty`,
        // hitting the extreme of the u64 domain. Existing tests cover
        // realistic future floors (T0 + ONE_DAY_MS) but the type bound
        // (u64::MAX, year 30000 trillion-ish) was never exercised.
        // Catches a future change that did anything stranger than a
        // bare `>=` compare (e.g., started widening to i64 + arithmetic,
        // or computing floor + epsilon), which could overflow at the
        // type bound. The contract: no doc has created_at == u64::MAX,
        // so since=u64::MAX must yield an empty packet without panic.
        let idx = build();
        let q =
            EidosQuery::new("", EidosRetrievalMode::Recency, 16).with_since(u64::MAX);
        let packet = idx.retrieve(&q, T0);
        assert!(
            packet.hits.is_empty(),
            "since=u64::MAX must drop every doc and not panic"
        );
    }

    #[test]
    fn since_unix_ms_floor_in_the_future_returns_empty() {
        // since = T0 + 1 day. No document satisfies it.
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16)
            .with_since(T0 + ONE_DAY_MS);
        let packet = idx.retrieve(&q, T0);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn since_unix_ms_combines_with_substring_filter() {
        // Substring "alpha" matches week-old only; since = T0 - 1*ONE_DAY
        // would otherwise admit today + yesterday. Combined: NO match.
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("week-old"), "alpha note", T0 - 7 * ONE_DAY_MS, EidosSourceKind::Note);
        idx.insert(doc("today"), "beta note", T0, EidosSourceKind::Note);
        let q = EidosQuery::new("alpha", EidosRetrievalMode::Recency, 16)
            .with_since(T0 - 2 * ONE_DAY_MS);
        let packet = idx.retrieve(&q, T0);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn since_unix_ms_is_inclusive_at_exact_floor() {
        // The since_floor filter at recency.rs:130 uses `>=` — a doc
        // whose created_at_unix_ms equals the floor exactly MUST be
        // admitted; only docs strictly below it are dropped. Existing
        // tests cover the broad floor cases (drops older / future
        // floor / since=0 no-op) but never the exact-boundary path.
        // A future flip from `>=` to `>` would silently drop boundary
        // docs and only surface here.
        //
        // Build three docs precisely at floor-1, floor, floor+1 (using
        // ONE_DAY_MS to keep them realistic units). With since=floor:
        //   - floor-1: DROPPED (strictly below)
        //   - floor:   ADMITTED (equality is admission)
        //   - floor+1: ADMITTED (above floor)
        // Order: created_at desc, so floor+1 sorts first.
        let floor = T0 - 3 * ONE_DAY_MS;
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("below"), "x", floor - 1, EidosSourceKind::Note);
        idx.insert(doc("at-floor"), "x", floor, EidosSourceKind::Note);
        idx.insert(doc("above"), "x", floor + 1, EidosSourceKind::Note);

        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16).with_since(floor);
        let packet = idx.retrieve(&q, T0);

        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec!["above::recency", "at-floor::recency"],
            "since_unix_ms must be inclusive at the exact floor (>= semantics)",
        );
        // Sanity: "below::recency" must NOT appear anywhere in the
        // packet — even if a future change broke the floor semantics
        // *and* a tie-break put below ahead, this catches it.
        assert!(
            !ids.iter().any(|s| s.starts_with("below")),
            "doc at floor-1 must be dropped",
        );
    }

    #[test]
    fn since_unix_ms_zero_is_no_op() {
        // since = 0 admits everything from the unix epoch onward.
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16).with_since(0);
        let packet = idx.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 3);
    }

    #[test]
    fn since_unix_ms_zero_yields_hit_equivalent_packet_to_none() {
        // Audit per "audit existing claims first":
        //   - `since_unix_ms_zero_is_no_op` pins that since=0 surfaces
        //     all 3 hits (count check only).
        //   - `since_unix_ms_field_omitted_from_json_when_none` pins
        //     the JSON shape distinction (Some(0) serializes vs None
        //     omits the field).
        //
        // Gap: the equivalence between `with_since(0)` and
        // no-with-since at the RETRIEVAL contract level wasn't pinned.
        // The bridge layer might emit either form ("set floor to
        // epoch" vs "no floor at all") and the contract should be
        // identical hits + manifest. Query echo intentionally NOT
        // asserted equal because Some(0) ≠ None at the field level
        // (mirrors iter 70's `Some(vec![]) ≡ None` semantic for
        // Semantic).
        let idx = build();
        let q_zero =
            EidosQuery::new("", EidosRetrievalMode::Recency, 16).with_since(0);
        let q_none = EidosQuery::new("", EidosRetrievalMode::Recency, 16);

        let p_zero = idx.retrieve(&q_zero, T0);
        let p_none = idx.retrieve(&q_none, T0);

        assert_eq!(p_zero.hits, p_none.hits, "since=0 hits must equal no-since hits");
        assert_eq!(p_zero.manifest_id, p_none.manifest_id);
        // Sanity-pin the count so the assertion isn't trivially
        // satisfied by 0==0 if a future change broke retrieval
        // entirely.
        assert_eq!(p_zero.hits.len(), 3);
    }

    #[test]
    fn since_unix_ms_field_omitted_from_json_when_none() {
        // Backwards-compat: a Recency query with no since field serializes
        // without the since_unix_ms key, so packets produced by an older
        // build deserialize cleanly.
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let json = serde_json::to_string(&q).unwrap();
        assert!(!json.contains("since_unix_ms"));
    }

    #[test]
    fn since_unix_ms_field_round_trips_through_json() {
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16).with_since(T0);
        let json = serde_json::to_string(&q).unwrap();
        let back: EidosQuery = serde_json::from_str(&json).unwrap();
        assert_eq!(back.since_unix_ms, Some(T0));
    }
}
