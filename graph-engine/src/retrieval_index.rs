use rustc_hash::FxHashMap;
use serde::Deserialize;
use std::fs;
use std::path::{Path, PathBuf};

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
    dimension: usize,
    embeddings: Vec<f32>,
    page_ids: Vec<String>,
}

#[derive(Clone)]
pub struct PreparedRetrievalHit {
    pub page_id: String,
    pub similarity: f32,
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

        let page_ids = load_page_ids(&documents_path)?;
        if page_ids.len() != manifest.document_count {
            return None;
        }

        let embeddings = load_embeddings(
            &embeddings_path,
            manifest.embedding_dimension,
            manifest.document_count,
        )?;

        Some(Self {
            manifest_path: manifest_path.to_string_lossy().into_owned(),
            dimension: manifest.embedding_dimension,
            embeddings,
            page_ids,
        })
    }

    pub fn matches_manifest_path(&self, manifest_path: &str) -> bool {
        self.manifest_path == manifest_path
    }

    pub fn dimension(&self) -> usize {
        self.dimension
    }

    pub fn search(&self, query: &[f32], limit: usize, threshold: f32) -> Vec<PreparedRetrievalHit> {
        if query.len() != self.dimension || limit == 0 {
            return Vec::new();
        }

        let query_norm = l2_norm(query);
        if query_norm == 0.0 {
            return Vec::new();
        }

        let mut best_by_page: FxHashMap<&str, f32> = FxHashMap::default();
        for (row_index, page_id) in self.page_ids.iter().enumerate() {
            let start = row_index * self.dimension;
            let row = &self.embeddings[start..(start + self.dimension)];
            let row_norm = l2_norm(row);
            if row_norm == 0.0 {
                continue;
            }

            let similarity = dot_product(query, row) / (query_norm * row_norm);
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

    pub fn score_page_ids(&self, query: &[f32], page_ids: &[String]) -> Vec<PreparedRetrievalHit> {
        if query.len() != self.dimension || page_ids.is_empty() {
            return Vec::new();
        }

        let query_norm = l2_norm(query);
        if query_norm == 0.0 {
            return Vec::new();
        }

        let mut requested_page_ids = FxHashMap::default();
        requested_page_ids.reserve(page_ids.len());
        for page_id in page_ids {
            requested_page_ids.insert(page_id.as_str(), ());
        }

        let mut best_by_page: FxHashMap<&str, f32> = FxHashMap::default();
        best_by_page.reserve(page_ids.len());

        for (row_index, page_id) in self.page_ids.iter().enumerate() {
            if !requested_page_ids.contains_key(page_id.as_str()) {
                continue;
            }

            let start = row_index * self.dimension;
            let row = &self.embeddings[start..(start + self.dimension)];
            let row_norm = l2_norm(row);
            if row_norm == 0.0 {
                continue;
            }

            let similarity = dot_product(query, row) / (query_norm * row_norm);
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
        hits
    }
}

fn load_page_ids(documents_path: &Path) -> Option<Vec<String>> {
    let contents = fs::read_to_string(documents_path).ok()?;
    let mut page_ids = Vec::new();
    page_ids.reserve(contents.lines().count());

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

    let mut embeddings = Vec::with_capacity(document_count * dimension);
    for chunk in bytes.chunks_exact(std::mem::size_of::<f32>()) {
        embeddings.push(f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]));
    }
    Some(embeddings)
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
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn prepared_retrieval_store_deduplicates_page_hits() {
        let store = PreparedRetrievalStore {
            manifest_path: "/tmp/index/manifest.json".to_string(),
            dimension: 2,
            embeddings: vec![
                1.0, 0.0,
                0.8, 0.2,
                0.0, 1.0,
            ],
            page_ids: vec![
                "page-a".to_string(),
                "page-a".to_string(),
                "page-b".to_string(),
            ],
        };

        let hits = store.search(&[1.0, 0.0], 10, 0.0);

        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].page_id, "page-a");
        assert!(hits[0].similarity > hits[1].similarity);
        assert_eq!(hits[1].page_id, "page-b");
    }

    #[test]
    fn prepared_retrieval_store_scores_requested_page_ids() {
        let store = PreparedRetrievalStore {
            manifest_path: "/tmp/index/manifest.json".to_string(),
            dimension: 2,
            embeddings: vec![
                1.0, 0.0,
                0.2, 0.8,
                0.0, 1.0,
            ],
            page_ids: vec![
                "page-a".to_string(),
                "page-b".to_string(),
                "page-c".to_string(),
            ],
        };

        let hits = store.score_page_ids(
            &[1.0, 0.0],
            &["page-c".to_string(), "page-a".to_string()],
        );

        assert_eq!(hits.len(), 2);
        assert_eq!(hits[0].page_id, "page-a");
        assert_eq!(hits[1].page_id, "page-c");
        assert!(hits[0].similarity > hits[1].similarity);
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

        let mut embeddings_bytes = Vec::new();
        for value in [0.0f32, 1.0, 1.0, 0.0] {
            embeddings_bytes.extend_from_slice(&value.to_le_bytes());
        }
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
}
