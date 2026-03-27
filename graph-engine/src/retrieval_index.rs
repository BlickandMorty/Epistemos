use rustc_hash::{FxHashMap, FxHashSet};
use serde::Deserialize;
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};
use usearch::{
    Index,
    ffi::{IndexOptions, Matches, MetricKind, ScalarKind},
};

const HNSW_CONNECTIVITY: usize = 16;
const HNSW_EXPANSION_ADD: usize = 128;
const HNSW_EXPANSION_SEARCH: usize = 64;

#[derive(Deserialize)]
struct IndexManifest {
    #[serde(alias = "embeddingDimension")]
    embedding_dimension: usize,
    #[serde(alias = "documentCount")]
    document_count: usize,
    #[serde(alias = "embeddingsFile")]
    embeddings_file: String,
    #[serde(alias = "documentsFile")]
    documents_file: String,
}

#[derive(Deserialize)]
struct DocumentRecord {
    page_id: String,
}

pub struct PreparedRetrievalStore {
    manifest_path: String,
    manifest_signature: u64,
    dimension: usize,
    index: Index,
    embeddings: Vec<f32>,
    row_page_ids: Vec<String>,
    page_rows: FxHashMap<String, Vec<usize>>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct PreparedRetrievalHit {
    pub page_id: String,
    pub similarity: f32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PreparedRetrievalQueryError {
    DimensionMismatch { expected: usize, got: usize },
    NonFiniteValue,
    ZeroVector,
}

impl PreparedRetrievalStore {
    pub fn load(manifest_path: &str) -> Option<Self> {
        let manifest_path = PathBuf::from(manifest_path);
        let manifest_data = fs::read(&manifest_path).ok()?;
        let manifest: IndexManifest = serde_json::from_slice(&manifest_data).ok()?;
        if manifest.embedding_dimension == 0 || manifest.document_count == 0 {
            return None;
        }

        let index_root = manifest_path.parent()?;
        let documents_path = index_root.join(manifest.documents_file);
        let embeddings_path = index_root.join(manifest.embeddings_file);
        let manifest_signature = source_signature(
            &manifest_path,
            &manifest_data,
            &documents_path,
            &embeddings_path,
        )?;

        let row_page_ids = load_page_ids(&documents_path)?;
        if row_page_ids.len() != manifest.document_count {
            return None;
        }

        let embeddings = load_embeddings(
            &embeddings_path,
            manifest.embedding_dimension,
            manifest.document_count,
        )?;
        let index_path = persisted_index_path(&manifest_path);
        let index = build_or_load_index(
            &index_path,
            &persisted_index_signature_path(&manifest_path),
            manifest_signature,
            manifest.embedding_dimension,
            &embeddings,
        )
        .ok()?;
        let page_rows = build_page_rows(&row_page_ids);

        Some(Self {
            manifest_path: manifest_path.to_string_lossy().into_owned(),
            manifest_signature,
            dimension: manifest.embedding_dimension,
            index,
            embeddings,
            row_page_ids,
            page_rows,
        })
    }

    pub fn manifest_signature_for_path(manifest_path: &str) -> Option<u64> {
        let manifest_path = PathBuf::from(manifest_path);
        let manifest_data = fs::read(&manifest_path).ok()?;
        let manifest: IndexManifest = serde_json::from_slice(&manifest_data).ok()?;
        let index_root = manifest_path.parent()?;
        let documents_path = index_root.join(manifest.documents_file);
        let embeddings_path = index_root.join(manifest.embeddings_file);
        source_signature(
            &manifest_path,
            &manifest_data,
            &documents_path,
            &embeddings_path,
        )
    }

    pub fn matches_manifest_cache_key(&self, manifest_path: &str, manifest_signature: u64) -> bool {
        self.manifest_path == manifest_path && self.manifest_signature == manifest_signature
    }

    pub fn dimension(&self) -> usize {
        self.dimension
    }

    /// Approximate nearest-neighbor search over the full HNSW index.
    ///
    /// Dimension mismatches and zero vectors return no hits instead of panicking so
    /// higher layers can treat an incompatible or degenerate query as "no semantic context".
    pub fn search(&self, query: &[f32], limit: usize, threshold: f32) -> Vec<PreparedRetrievalHit> {
        self.search_checked(query, limit, threshold)
            .unwrap_or_default()
    }

    /// Checked variant of [`search`] for callers that need explicit validation errors.
    pub fn search_checked(
        &self,
        query: &[f32],
        limit: usize,
        threshold: f32,
    ) -> Result<Vec<PreparedRetrievalHit>, PreparedRetrievalQueryError> {
        self.validate_query(query)?;
        if !self.can_score_query(query) || limit == 0 {
            return Ok(Vec::new());
        }

        let total_rows = self.index.size();
        if total_rows == 0 {
            return Ok(Vec::new());
        }

        let mut request_count = limit.max(1).saturating_mul(4).min(total_rows.max(limit));
        let mut best_hits = Vec::new();

        loop {
            let Ok(matches) = self.index.search::<f32>(query, request_count) else {
                return Ok(best_hits);
            };
            let hits = self.hits_from_matches(matches, threshold, limit);
            if hits.len() >= limit || request_count == total_rows {
                return Ok(hits);
            }

            best_hits = hits;
            let next_request_count = request_count.saturating_mul(2).min(total_rows);
            if next_request_count == request_count {
                return Ok(best_hits);
            }
            request_count = next_request_count;
        }
    }

    /// Rescores only an explicitly requested subset of page IDs.
    ///
    /// This path intentionally stays linear in the requested subset size. It is not the
    /// primary recall path; it exists for targeted follow-up reranking when the caller has
    /// already narrowed the candidate set to a small list of page IDs.
    pub fn score_page_ids(&self, query: &[f32], page_ids: &[String]) -> Vec<PreparedRetrievalHit> {
        self.score_page_ids_checked(query, page_ids)
            .unwrap_or_default()
    }

    /// Checked variant of [`score_page_ids`] for callers that need explicit validation errors.
    pub fn score_page_ids_checked(
        &self,
        query: &[f32],
        page_ids: &[String],
    ) -> Result<Vec<PreparedRetrievalHit>, PreparedRetrievalQueryError> {
        self.validate_query(query)?;
        if page_ids.is_empty() {
            return Ok(Vec::new());
        }

        let query_norm = l2_norm(query);

        let mut requested_page_ids: FxHashSet<&str> = FxHashSet::default();
        requested_page_ids.reserve(page_ids.len());
        let mut best_by_page: FxHashMap<&str, f32> = FxHashMap::default();
        best_by_page.reserve(page_ids.len());

        for page_id in page_ids {
            let page_id = page_id.as_str();
            if !requested_page_ids.insert(page_id) {
                continue;
            }

            let Some(row_indices) = self.page_rows.get(page_id) else {
                continue;
            };

            let mut best_similarity: Option<f32> = None;
            for &row_index in row_indices {
                let start = row_index * self.dimension;
                let row = &self.embeddings[start..(start + self.dimension)];
                let row_norm = l2_norm(row);
                if row_norm == 0.0 {
                    continue;
                }

                let similarity = dot_product(query, row) / (query_norm * row_norm);
                best_similarity = Some(match best_similarity {
                    Some(best) => best.max(similarity),
                    None => similarity,
                });
            }

            if let Some(similarity) = best_similarity {
                best_by_page.insert(page_id, similarity);
            }
        }

        let mut hits: Vec<PreparedRetrievalHit> = best_by_page
            .into_iter()
            .map(|(page_id, similarity)| PreparedRetrievalHit {
                page_id: page_id.to_owned(),
                similarity,
            })
            .collect();

        hits.sort_unstable_by(|a, b| {
            b.similarity
                .partial_cmp(&a.similarity)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| a.page_id.cmp(&b.page_id))
        });
        Ok(hits)
    }

    fn can_score_query(&self, query: &[f32]) -> bool {
        query.len() == self.dimension && l2_norm(query) != 0.0
    }

    fn validate_query(&self, query: &[f32]) -> Result<(), PreparedRetrievalQueryError> {
        if query.len() != self.dimension {
            return Err(PreparedRetrievalQueryError::DimensionMismatch {
                expected: self.dimension,
                got: query.len(),
            });
        }
        if query.iter().any(|value| !value.is_finite()) {
            return Err(PreparedRetrievalQueryError::NonFiniteValue);
        }
        if l2_norm(query) == 0.0 {
            return Err(PreparedRetrievalQueryError::ZeroVector);
        }
        Ok(())
    }

    fn hits_from_matches(
        &self,
        matches: Matches,
        threshold: f32,
        limit: usize,
    ) -> Vec<PreparedRetrievalHit> {
        let mut best_by_page: FxHashMap<&str, f32> = FxHashMap::default();
        best_by_page.reserve(limit.min(matches.keys.len()));

        for (&key, &distance) in matches.keys.iter().zip(matches.distances.iter()) {
            let row_index = key as usize;
            let Some(page_id) = self.row_page_ids.get(row_index) else {
                continue;
            };

            let similarity = similarity_from_distance(distance);
            if similarity < threshold {
                continue;
            }

            let entry = best_by_page.entry(page_id.as_str()).or_insert(similarity);
            if similarity > *entry {
                *entry = similarity;
            }
        }

        let mut hits: Vec<PreparedRetrievalHit> = best_by_page
            .into_iter()
            .map(|(page_id, similarity)| PreparedRetrievalHit {
                page_id: page_id.to_owned(),
                similarity,
            })
            .collect();

        hits.sort_unstable_by(|a, b| {
            b.similarity
                .partial_cmp(&a.similarity)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| a.page_id.cmp(&b.page_id))
        });
        hits.truncate(limit);
        hits
    }

    #[cfg(test)]
    fn from_raw_for_tests(
        dimension: usize,
        embeddings: Vec<f32>,
        row_page_ids: Vec<String>,
    ) -> Self {
        let index = build_index(dimension, &embeddings).expect("expected test index to build");
        let page_rows = build_page_rows(&row_page_ids);
        Self {
            manifest_path: "/tmp/index/manifest.json".to_string(),
            manifest_signature: 0,
            dimension,
            index,
            embeddings,
            row_page_ids,
            page_rows,
        }
    }
}

fn load_page_ids(documents_path: &Path) -> Option<Vec<String>> {
    let contents = fs::read_to_string(documents_path).ok()?;
    let mut page_ids = Vec::with_capacity(contents.lines().count());

    for line in contents.lines() {
        if line.is_empty() {
            continue;
        }
        let record: DocumentRecord = serde_json::from_str(line).ok()?;
        page_ids.push(record.page_id);
    }

    Some(page_ids)
}

fn load_embeddings(path: &Path, dimension: usize, document_count: usize) -> Option<Vec<f32>> {
    let bytes = fs::read(path).ok()?;
    let expected_bytes = dimension
        .checked_mul(document_count)?
        .checked_mul(std::mem::size_of::<f32>())?;
    if bytes.len() != expected_bytes {
        return None;
    }

    if let Ok(values) = bytemuck::try_cast_slice::<u8, f32>(&bytes) {
        return Some(values.iter().copied().map(decode_little_endian_f32).collect());
    }

    Some(
        bytes.chunks_exact(std::mem::size_of::<f32>())
            .map(bytemuck::pod_read_unaligned::<f32>)
            .map(decode_little_endian_f32)
            .collect(),
    )
}

fn build_page_rows(row_page_ids: &[String]) -> FxHashMap<String, Vec<usize>> {
    let mut page_rows: FxHashMap<String, Vec<usize>> = FxHashMap::default();
    page_rows.reserve(row_page_ids.len());

    for (row_index, page_id) in row_page_ids.iter().enumerate() {
        page_rows
            .entry(page_id.clone())
            .or_default()
            .push(row_index);
    }

    page_rows
}

fn persisted_index_path(manifest_path: &Path) -> PathBuf {
    manifest_path.with_extension("usearch")
}

fn persisted_index_signature_path(manifest_path: &Path) -> PathBuf {
    manifest_path.with_extension("usearch.sig")
}

fn new_index(dimension: usize) -> Result<Index, String> {
    let options = IndexOptions {
        dimensions: dimension,
        metric: MetricKind::Cos,
        quantization: ScalarKind::F16,
        connectivity: HNSW_CONNECTIVITY,
        expansion_add: HNSW_EXPANSION_ADD,
        expansion_search: HNSW_EXPANSION_SEARCH,
        multi: false,
    };
    Index::new(&options).map_err(|error| format!("failed to create HNSW index: {error}"))
}

fn build_index(dimension: usize, embeddings: &[f32]) -> Result<Index, String> {
    if dimension == 0 || embeddings.len() % dimension != 0 {
        return Err("embedding matrix dimensions are invalid".to_string());
    }

    let row_count = embeddings.len() / dimension;
    let index = new_index(dimension)?;
    index
        .reserve(row_count)
        .map_err(|error| format!("failed to reserve HNSW capacity: {error}"))?;

    for (row_index, row) in embeddings.chunks_exact(dimension).enumerate() {
        index
            .add::<f32>(row_index as u64, row)
            .map_err(|error| format!("failed to add embedding row {row_index}: {error}"))?;
    }
    index.change_expansion_search(HNSW_EXPANSION_SEARCH);
    Ok(index)
}

fn build_or_load_index(
    index_path: &Path,
    signature_path: &Path,
    source_signature: u64,
    dimension: usize,
    embeddings: &[f32],
) -> Result<Index, String> {
    let expected_rows = embeddings.len() / dimension;
    let index_path_string = index_path.to_string_lossy().into_owned();

    if index_path.exists() {
        let index = new_index(dimension)?;
        if persisted_index_signature_matches(signature_path, source_signature)
            && index.load(&index_path_string).is_ok()
            && index.size() == expected_rows
        {
            index.change_expansion_search(HNSW_EXPANSION_SEARCH);
            return Ok(index);
        }
    }

    let index = build_index(dimension, embeddings)?;
    if index.save(&index_path_string).is_ok() {
        let _ = fs::write(signature_path, source_signature.to_string());
    }
    Ok(index)
}

fn manifest_signature(data: &[u8]) -> u64 {
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    data.hash(&mut hasher);
    hasher.finish()
}

fn source_signature(
    manifest_path: &Path,
    manifest_data: &[u8],
    documents_path: &Path,
    embeddings_path: &Path,
) -> Option<u64> {
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    manifest_path.to_string_lossy().hash(&mut hasher);
    manifest_signature(manifest_data).hash(&mut hasher);
    file_signature(documents_path)?.hash(&mut hasher);
    file_signature(embeddings_path)?.hash(&mut hasher);
    Some(hasher.finish())
}

fn file_signature(path: &Path) -> Option<u64> {
    let metadata = fs::metadata(path).ok()?;
    let modified = metadata
        .modified()
        .ok()
        .and_then(|time| time.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|duration| duration.as_nanos())
        .unwrap_or_default();

    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    path.to_string_lossy().hash(&mut hasher);
    metadata.len().hash(&mut hasher);
    modified.hash(&mut hasher);
    Some(hasher.finish())
}

fn persisted_index_signature_matches(signature_path: &Path, source_signature: u64) -> bool {
    let Ok(saved_signature) = fs::read_to_string(signature_path) else {
        return false;
    };
    saved_signature.trim().parse::<u64>().ok() == Some(source_signature)
}

fn decode_little_endian_f32(value: f32) -> f32 {
    #[cfg(target_endian = "little")]
    {
        value
    }

    #[cfg(target_endian = "big")]
    {
        f32::from_bits(u32::from_le(value.to_bits()))
    }
}

fn similarity_from_distance(distance: f32) -> f32 {
    (1.0 - distance).clamp(-1.0, 1.0)
}

fn l2_norm(values: &[f32]) -> f32 {
    dot_product(values, values).sqrt()
}

fn dot_product(a: &[f32], b: &[f32]) -> f32 {
    debug_assert_eq!(a.len(), b.len());
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Instant, SystemTime, UNIX_EPOCH};

    fn temp_test_root(prefix: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "{prefix}-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_nanos()
        ))
    }

    fn write_fixture_files(
        root: &Path,
        dimension: usize,
        rows: &[f32],
        page_ids: &[String],
    ) -> PathBuf {
        fs::create_dir_all(root).unwrap();
        let manifest_path = root.join("manifest.json");
        fs::write(
            &manifest_path,
            format!(
                r#"{{
  "embeddingDimension": {dimension},
  "documentCount": {},
  "embeddingsFile": "block-embeddings.f32",
  "documentsFile": "documents.jsonl"
}}"#,
                page_ids.len()
            ),
        )
        .unwrap();

        let embeddings_bytes = rows
            .iter()
            .flat_map(|value| value.to_le_bytes())
            .collect::<Vec<_>>();
        fs::write(root.join("block-embeddings.f32"), embeddings_bytes).unwrap();

        let documents = page_ids
            .iter()
            .map(|page_id| format!(r#"{{"page_id":"{page_id}"}}"#))
            .collect::<Vec<_>>()
            .join("\n");
        fs::write(root.join("documents.jsonl"), format!("{documents}\n")).unwrap();
        manifest_path
    }

    fn deterministic_vectors(count: usize, dims: usize) -> Vec<f32> {
        let mut values = Vec::with_capacity(count * dims);
        for row in 0..count {
            for dim in 0..dims {
                let seed = (row * dims + dim + 1) as f32;
                values.push(((seed * 0.01357).sin() + (seed * 0.00731).cos()) * 0.5);
            }
        }
        values
    }

    #[test]
    fn prepared_retrieval_store_deduplicates_page_hits() {
        let store = PreparedRetrievalStore::from_raw_for_tests(
            2,
            vec![1.0, 0.0, 0.8, 0.2, 0.0, 1.0],
            vec![
                "page-a".to_string(),
                "page-a".to_string(),
                "page-b".to_string(),
            ],
        );

        let hits = store.search(&[1.0, 0.0], 10, 0.0);

        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].page_id, "page-a");
        assert!(hits[0].similarity > hits[1].similarity);
        assert_eq!(hits[1].page_id, "page-b");
    }

    #[test]
    fn prepared_retrieval_store_scores_requested_page_ids() {
        let store = PreparedRetrievalStore::from_raw_for_tests(
            2,
            vec![1.0, 0.0, 0.2, 0.8, 0.0, 1.0],
            vec![
                "page-a".to_string(),
                "page-b".to_string(),
                "page-c".to_string(),
            ],
        );

        let hits = store.score_page_ids(&[1.0, 0.0], &["page-c".to_string(), "page-a".to_string()]);

        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].page_id, "page-a");
        assert_eq!(hits[1].page_id, "page-c");
        assert!(hits[0].similarity > hits[1].similarity);
    }

    #[test]
    fn prepared_retrieval_store_returns_empty_for_dimension_mismatch() {
        let store = PreparedRetrievalStore::from_raw_for_tests(
            2,
            vec![1.0, 0.0, 0.0, 1.0],
            vec!["page-a".to_string(), "page-b".to_string()],
        );

        assert!(store.search(&[1.0, 0.0, 0.0], 5, 0.0).is_empty());
        assert!(
            store
                .score_page_ids(&[1.0, 0.0, 0.0], &["page-a".to_string()])
                .is_empty()
        );
    }

    #[test]
    fn prepared_retrieval_store_checked_queries_report_validation_errors() {
        let store = PreparedRetrievalStore::from_raw_for_tests(
            2,
            vec![1.0, 0.0, 0.0, 1.0],
            vec!["page-a".to_string(), "page-b".to_string()],
        );

        assert_eq!(
            store.search_checked(&[1.0, 0.0, 0.0], 5, 0.0),
            Err(PreparedRetrievalQueryError::DimensionMismatch {
                expected: 2,
                got: 3,
            })
        );
        assert_eq!(
            store.score_page_ids_checked(&[0.0, 0.0], &["page-a".to_string()]),
            Err(PreparedRetrievalQueryError::ZeroVector)
        );
        assert_eq!(
            store.search_checked(&[f32::NAN, 0.0], 5, 0.0),
            Err(PreparedRetrievalQueryError::NonFiniteValue)
        );
    }

    #[test]
    fn load_embeddings_decodes_little_endian_f32_rows() {
        let root = temp_test_root("prepared-retrieval-load-embeddings");
        fs::create_dir_all(&root).unwrap();

        let expected = vec![1.5f32, -2.25, 0.0, 3.75];
        let bytes = expected
            .iter()
            .flat_map(|value| value.to_le_bytes())
            .collect::<Vec<_>>();
        let path = root.join("block-embeddings.f32");
        fs::write(&path, bytes).unwrap();

        let loaded = load_embeddings(&path, 2, 2).expect("expected embeddings to load");
        let _ = fs::remove_dir_all(&root);

        assert_eq!(loaded, expected);
    }

    #[test]
    fn prepared_retrieval_store_load_accepts_camel_case_manifest_keys() {
        let root = std::env::temp_dir().join(format!(
            "prepared-retrieval-store-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_nanos()
        ));
        fs::create_dir_all(&root).unwrap();

        let manifest_path = root.join("manifest.json");
        fs::write(
            &manifest_path,
            r#"{
  "embeddingDimension": 2,
  "documentCount": 2,
  "embeddingsFile": "block-embeddings.f32",
  "documentsFile": "documents.jsonl"
}"#,
        )
        .unwrap();

        let embeddings_bytes = [0.0f32, 1.0, 1.0, 0.0]
            .iter()
            .flat_map(|value| value.to_le_bytes())
            .collect::<Vec<_>>();
        fs::write(root.join("block-embeddings.f32"), embeddings_bytes).unwrap();
        fs::write(
            root.join("documents.jsonl"),
            "{\"page_id\":\"page-b\"}\n{\"page_id\":\"page-a\"}\n",
        )
        .unwrap();

        let store = PreparedRetrievalStore::load(manifest_path.to_str().unwrap());
        let _ = fs::remove_dir_all(&root);

        let store = store.expect("expected prepared retrieval store to load");
        let hits = store.search(&[1.0, 0.0], 2, 0.0);
        assert_eq!(hits[0].page_id, "page-a");
        assert_eq!(hits[1].page_id, "page-b");
    }

    #[test]
    fn prepared_retrieval_store_cache_key_changes_when_manifest_changes() {
        let root = temp_test_root("prepared-retrieval-cache-key");
        fs::create_dir_all(&root).unwrap();

        let manifest_path = root.join("manifest.json");
        let initial_manifest = r#"{
  "embeddingDimension": 2,
  "documentCount": 2,
  "embeddingsFile": "block-embeddings.f32",
  "documentsFile": "documents.jsonl"
}"#;
        fs::write(&manifest_path, initial_manifest).unwrap();

        let embeddings_bytes = [0.0f32, 1.0, 1.0, 0.0]
            .iter()
            .flat_map(|value| value.to_le_bytes())
            .collect::<Vec<_>>();
        fs::write(root.join("block-embeddings.f32"), embeddings_bytes).unwrap();
        fs::write(
            root.join("documents.jsonl"),
            "{\"page_id\":\"page-b\"}\n{\"page_id\":\"page-a\"}\n",
        )
        .unwrap();

        let store = PreparedRetrievalStore::load(manifest_path.to_str().unwrap())
            .expect("expected prepared retrieval store to load");
        let initial_signature =
            PreparedRetrievalStore::manifest_signature_for_path(manifest_path.to_str().unwrap())
                .expect("expected manifest signature");
        assert!(
            store.matches_manifest_cache_key(manifest_path.to_str().unwrap(), initial_signature)
        );

        let updated_manifest = r#"{
  "embeddingDimension": 2,
  "documentCount": 2,
  "embeddingsFile": "block-embeddings.f32",
  "documentsFile": "documents.jsonl",
  "rebuiltAt": 42
}"#;
        fs::write(&manifest_path, updated_manifest).unwrap();

        let updated_signature =
            PreparedRetrievalStore::manifest_signature_for_path(manifest_path.to_str().unwrap())
                .expect("expected updated manifest signature");
        let _ = fs::remove_dir_all(&root);

        assert_ne!(initial_signature, updated_signature);
        assert!(
            !store.matches_manifest_cache_key(manifest_path.to_str().unwrap(), updated_signature)
        );
    }

    #[test]
    fn prepared_retrieval_store_returns_empty_for_empty_index() {
        let store = PreparedRetrievalStore::from_raw_for_tests(2, Vec::new(), Vec::new());
        let hits = store.search(&[1.0, 0.0], 5, 0.0);
        assert!(hits.is_empty());
    }

    #[test]
    fn prepared_retrieval_store_persists_and_reuses_hnsw_index() {
        let dimension = 4;
        let root = temp_test_root("prepared-retrieval-persist");
        let rows = vec![
            1.0f32, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
        ];
        let page_ids = vec![
            "page-a".to_string(),
            "page-b".to_string(),
            "page-c".to_string(),
        ];
        let manifest_path = write_fixture_files(&root, dimension, &rows, &page_ids);

        let first = PreparedRetrievalStore::load(manifest_path.to_str().unwrap())
            .expect("expected first load to build an index");
        let persisted_path = persisted_index_path(&manifest_path);
        assert!(
            persisted_path.exists(),
            "expected persisted .usearch sidecar to exist"
        );

        let first_hits = first.search(&[1.0, 0.0, 0.0, 0.0], 3, 0.0);
        let second = PreparedRetrievalStore::load(manifest_path.to_str().unwrap())
            .expect("expected second load to reuse the persisted index");
        let second_hits = second.search(&[1.0, 0.0, 0.0, 0.0], 3, 0.0);

        assert_eq!(first_hits.len(), second_hits.len());
        assert_eq!(first_hits[0].page_id, "page-a");
        assert_eq!(second_hits[0].page_id, "page-a");
        assert_eq!(first_hits[0].page_id, second_hits[0].page_id);

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn prepared_retrieval_store_rebuilds_when_embeddings_change_without_manifest_changes() {
        let dimension = 4;
        let root = temp_test_root("prepared-retrieval-rebuild");
        let original_rows = vec![1.0f32, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0];
        let page_ids = vec!["page-a".to_string(), "page-b".to_string()];
        let manifest_path = write_fixture_files(&root, dimension, &original_rows, &page_ids);

        let first = PreparedRetrievalStore::load(manifest_path.to_str().unwrap())
            .expect("expected first load to build an index");
        let first_hits = first.search(&[1.0, 0.0, 0.0, 0.0], 2, 0.0);
        assert_eq!(
            first_hits.first().map(|hit| hit.page_id.as_str()),
            Some("page-a")
        );

        let updated_rows = vec![0.0f32, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0];
        let embeddings_bytes = updated_rows
            .iter()
            .flat_map(|value| value.to_le_bytes())
            .collect::<Vec<_>>();
        fs::write(root.join("block-embeddings.f32"), embeddings_bytes).unwrap();

        let second = PreparedRetrievalStore::load(manifest_path.to_str().unwrap())
            .expect("expected second load to rebuild the stale sidecar");
        let second_hits = second.search(&[1.0, 0.0, 0.0, 0.0], 2, 0.0);

        assert_eq!(
            second_hits.first().map(|hit| hit.page_id.as_str()),
            Some("page-b")
        );

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn prepared_retrieval_store_search_latency_stays_sub_10ms_at_10k() {
        let dimension = 384;
        let count = 10_000;
        let rows = deterministic_vectors(count, dimension);
        let page_ids = (0..count)
            .map(|index| format!("page-{index}"))
            .collect::<Vec<_>>();
        let store = PreparedRetrievalStore::from_raw_for_tests(dimension, rows.clone(), page_ids);
        let query = rows[..dimension].to_vec();

        let iterations = 100usize;
        let start = Instant::now();
        for _ in 0..iterations {
            let hits = store.search(&query, 10, -1.0);
            assert!(!hits.is_empty());
            assert_eq!(hits[0].page_id, "page-0");
        }
        let average_micros = start.elapsed().as_micros() / iterations as u128;

        assert!(
            average_micros < 10_000,
            "average HNSW search latency was {average_micros}µs"
        );
    }
}
