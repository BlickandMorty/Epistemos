//! CodeSymbol retrieval mode — exact symbol-table lookup over code.
//!
//! Unlike [`super::lexical`] (substring match anywhere in body),
//! CodeSymbol matches against a controlled vocabulary of indexed code
//! symbols — function names, struct names, file names, trait names — with
//! **case-sensitive exact** semantics. Code identifiers care about case;
//! a query for `Foo` must not return `foo` or `FOO`.
//!
//! Each indexed symbol can occur in multiple documents (a function named
//! `retrieve` might appear in `eidos/lexical.rs`, `eidos/semantic.rs`,
//! etc.). The retriever surfaces every occurrence as a distinct hit so the
//! chat layer can cite the specific definition site.
//!
//! Deterministic ordering: `document_id ascending`. Closed-citation
//! contract holds end-to-end; the per-occurrence source_id encodes the
//! byte offset to disambiguate multiple occurrences within one document.

use std::collections::BTreeMap;

use super::retriever::EidosRetriever;
use super::types::{
    is_blank_query_text, EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit,
    EidosIndexManifestId, EidosProvenance, EidosQuery, EidosRetrievalMode,
    EidosScoreComponents, EidosSourceKind, EidosSpan,
};

/// One occurrence of a symbol in a document. The (`document_id`, `byte_start`)
/// pair is the dedup key used to mint a stable chunk id.
#[derive(Clone, Debug, PartialEq, Eq)]
struct SymbolOccurrence {
    document_id: EidosDocumentId,
    byte_start: u32,
    byte_end: u32,
}

/// In-memory symbol-table retriever. Production wiring routes through the
/// tree-sitter LSP runtime (`agent_core::lsp_runtime`), but Eidos V0 stays
/// independent — the LSP integration is a later W-row.
#[derive(Clone, Debug)]
pub struct InMemoryCodeSymbolIndex {
    manifest_id: EidosIndexManifestId,
    /// symbol_name → all occurrences. BTreeMap keeps iteration deterministic.
    symbols: BTreeMap<String, Vec<SymbolOccurrence>>,
}

impl InMemoryCodeSymbolIndex {
    pub fn new(manifest_id: EidosIndexManifestId) -> Self {
        Self {
            manifest_id,
            symbols: BTreeMap::new(),
        }
    }

    /// Index one occurrence of `symbol_name` at `(byte_start, byte_end)`
    /// within `document_id`. Duplicate `(document_id, byte_start)` entries
    /// are coalesced — re-indexing the same symbol at the same offset is a
    /// no-op.
    pub fn insert(
        &mut self,
        symbol_name: impl Into<String>,
        document_id: EidosDocumentId,
        byte_start: u32,
        byte_end: u32,
    ) {
        let name = symbol_name.into();
        let occurrences = self.symbols.entry(name).or_default();
        let new_occ = SymbolOccurrence {
            document_id,
            byte_start,
            byte_end,
        };
        if !occurrences.iter().any(|o| {
            o.document_id == new_occ.document_id && o.byte_start == new_occ.byte_start
        }) {
            occurrences.push(new_occ);
        }
    }
}

impl EidosRetriever for InMemoryCodeSymbolIndex {
    fn mode(&self) -> EidosRetrievalMode {
        EidosRetrievalMode::CodeSymbol
    }

    fn manifest_id(&self) -> &EidosIndexManifestId {
        &self.manifest_id
    }

    fn retrieve(
        &self,
        query: &EidosQuery,
        retrieved_at_unix_ms: u64,
    ) -> EidosContextPacket {
        if is_blank_query_text(&query.text) || query.top_k == 0 {
            return empty_packet(query, &self.manifest_id);
        }

        let Some(occurrences) = self.symbols.get(&query.text) else {
            return empty_packet(query, &self.manifest_id);
        };

        // Deterministic order: (document_id asc, byte_start asc). The
        // byte_start tie-break disambiguates two occurrences of the same
        // symbol in the same file.
        let mut sorted: Vec<&SymbolOccurrence> = occurrences.iter().collect();
        sorted.sort_by(|a, b| {
            a.document_id
                .as_str()
                .cmp(b.document_id.as_str())
                .then_with(|| a.byte_start.cmp(&b.byte_start))
        });

        let top_k = query.top_k as usize;
        let hits: Vec<EidosHit> = sorted
            .into_iter()
            .take(top_k)
            .map(|occ| {
                let chunk_id = EidosChunkId::new(format!(
                    "{}::sym@{}",
                    occ.document_id.as_str(),
                    occ.byte_start
                ))
                .expect("document_id is non-empty by construction");
                EidosHit {
                    source_id: chunk_id,
                    document_id: occ.document_id.clone(),
                    kind: EidosSourceKind::Code,
                    span: Some(EidosSpan {
                        byte_start: occ.byte_start,
                        byte_end: occ.byte_end,
                    }),
                    confidence: 1.0,
                    score: EidosScoreComponents::default(),
                    provenance: EidosProvenance {
                        manifest_id: self.manifest_id.clone(),
                        mode: EidosRetrievalMode::CodeSymbol,
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
        EidosIndexManifestId::new("code-test-manifest").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    fn build() -> InMemoryCodeSymbolIndex {
        let mut idx = InMemoryCodeSymbolIndex::new(manifest());
        idx.insert("retrieve", doc("eidos/lexical.rs"), 1024, 1032);
        idx.insert("retrieve", doc("eidos/semantic.rs"), 2048, 2056);
        idx.insert("retrieve", doc("eidos/hybrid.rs"), 4096, 4104);
        idx.insert("EidosHit", doc("eidos/types.rs"), 512, 520);
        idx
    }

    #[test]
    fn exact_symbol_hit_returns_one_per_occurrence() {
        // Acceptance bar: "code hit" — a symbol present in three source
        // files surfaces three citable hits, each anchored to its
        // definition site.
        let idx = build();
        let q = EidosQuery::new("retrieve", EidosRetrievalMode::CodeSymbol, 16);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 3);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert!(ids.contains(&"eidos/hybrid.rs::sym@4096"));
        assert!(ids.contains(&"eidos/lexical.rs::sym@1024"));
        assert!(ids.contains(&"eidos/semantic.rs::sym@2048"));
        for hit in &packet.hits {
            assert_eq!(hit.kind, EidosSourceKind::Code);
            assert!(hit.span.is_some());
        }
    }

    #[test]
    fn missing_symbol_returns_empty_packet() {
        let idx = build();
        let q = EidosQuery::new("does_not_exist", EidosRetrievalMode::CodeSymbol, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn case_sensitive_match() {
        // Code identifiers are case-sensitive. Lowercase query must NOT
        // match "EidosHit".
        let idx = build();
        let q = EidosQuery::new("eidoshit", EidosRetrievalMode::CodeSymbol, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
        // Exact case does match.
        let q2 = EidosQuery::new("EidosHit", EidosRetrievalMode::CodeSymbol, 8);
        let packet2 = idx.retrieve(&q2, 1_700_000_000_000);
        assert_eq!(packet2.hits.len(), 1);
    }

    #[test]
    fn empty_query_text_returns_empty_packet() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::CodeSymbol, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn whitespace_only_query_text_returns_empty_packet() {
        let mut idx = InMemoryCodeSymbolIndex::new(manifest());
        idx.insert("   ", doc("invalid-symbol.rs"), 0, 3);
        let q = EidosQuery::new("   ", EidosRetrievalMode::CodeSymbol, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "whitespace-only text is not a code symbol query and must defer"
        );
    }

    #[test]
    fn invisible_only_query_text_returns_empty_packet() {
        let mut idx = InMemoryCodeSymbolIndex::new(manifest());
        idx.insert("\u{200B}", doc("invalid-symbol.rs"), 0, 3);
        let q = EidosQuery::new("\u{200B}", EidosRetrievalMode::CodeSymbol, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "invisible-only text is not a code symbol query and must defer"
        );
    }

    #[test]
    fn top_k_truncates_occurrences() {
        let idx = build();
        let q = EidosQuery::new("retrieve", EidosRetrievalMode::CodeSymbol, 2);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 2);
        // Truncation preserves document_id ascending order.
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec!["eidos/hybrid.rs::sym@4096", "eidos/lexical.rs::sym@1024"]
        );
    }

    #[test]
    fn unicode_symbol_round_trip() {
        // Swift / Rust both allow non-ASCII identifiers.
        let mut idx = InMemoryCodeSymbolIndex::new(manifest());
        idx.insert("résumé_πᵢ", doc("notes/util.rs"), 0, 12);
        let q = EidosQuery::new("résumé_πᵢ", EidosRetrievalMode::CodeSymbol, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(
            packet.hits[0].source_id.as_str(),
            "notes/util.rs::sym@0"
        );
    }

    #[test]
    fn closed_citation_contract_holds_through_code_symbol() {
        let idx = build();
        let q = EidosQuery::new("retrieve", EidosRetrievalMode::CodeSymbol, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
        // A forged source_id at a fake offset is rejected.
        let forged = EidosCitation {
            source_id: EidosChunkId::new("eidos/lexical.rs::sym@9999").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&forged).is_err());
    }

    #[test]
    fn replay_byte_equal_for_pinned_clock() {
        let a = build();
        let b = build();
        let q = EidosQuery::new("retrieve", EidosRetrievalMode::CodeSymbol, 8);
        let pa = a.retrieve(&q, 1_700_000_000_000);
        let pb = b.retrieve(&q, 1_700_000_000_000);
        assert_eq!(pa, pb);
    }

    #[test]
    fn retriever_advertises_code_symbol_mode() {
        let idx = InMemoryCodeSymbolIndex::new(manifest());
        assert_eq!(idx.mode(), EidosRetrievalMode::CodeSymbol);
        assert_eq!(idx.manifest_id(), &manifest());
    }

    #[test]
    fn idempotent_reinsertion_at_same_offset() {
        let mut idx = InMemoryCodeSymbolIndex::new(manifest());
        idx.insert("foo", doc("a.rs"), 0, 3);
        idx.insert("foo", doc("a.rs"), 0, 3);
        idx.insert("foo", doc("a.rs"), 0, 3);
        let q = EidosQuery::new("foo", EidosRetrievalMode::CodeSymbol, 8);
        let packet = idx.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 1);
    }

    #[test]
    fn dedup_key_is_doc_plus_byte_start_only_first_write_wins_on_byte_end_conflict() {
        // Audit per "audit existing claims first":
        //   - `idempotent_reinsertion_at_same_offset` covers exact-tuple
        //     re-insertion (same byte_start AND same byte_end → coalesced).
        //   - `multiple_occurrences_in_same_document_distinct` covers
        //     DISTINCT byte_starts → distinct hits.
        //
        // Gap: what happens when (document_id, byte_start) collides but
        // byte_end DIFFERS? The dedup check at insert() only matches on
        // (document_id, byte_start) — so the second insert is silently
        // dropped and the first byte_end "wins". Pin this asymmetry
        // explicitly so a future change to "last-write-wins" or
        // "reject conflicting byte_end" surfaces here.
        let mut idx = InMemoryCodeSymbolIndex::new(manifest());
        idx.insert("foo", doc("a.rs"), 0, 3); // first wins
        idx.insert("foo", doc("a.rs"), 0, 5); // silently dropped
        idx.insert("foo", doc("a.rs"), 0, 99); // also silently dropped
        let q = EidosQuery::new("foo", EidosRetrievalMode::CodeSymbol, 8);
        let packet = idx.retrieve(&q, 0);

        assert_eq!(packet.hits.len(), 1, "dedup must coalesce same-offset inserts");
        let span = packet.hits[0].span.expect("span must be present");
        assert_eq!(span.byte_start, 0);
        assert_eq!(
            span.byte_end, 3,
            "first-write-wins: byte_end from the FIRST insert must be preserved",
        );
    }

    #[test]
    fn multiple_occurrences_in_same_document_distinct() {
        let mut idx = InMemoryCodeSymbolIndex::new(manifest());
        idx.insert("helper", doc("a.rs"), 100, 106);
        idx.insert("helper", doc("a.rs"), 200, 206);
        let q = EidosQuery::new("helper", EidosRetrievalMode::CodeSymbol, 8);
        let packet = idx.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 2);
        // Sorted by byte_start ascending within the same document.
        assert_eq!(
            packet.hits[0].source_id.as_str(),
            "a.rs::sym@100"
        );
        assert_eq!(
            packet.hits[1].source_id.as_str(),
            "a.rs::sym@200"
        );
    }
}
