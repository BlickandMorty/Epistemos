use std::collections::HashMap;

use async_trait::async_trait;

use crate::canon;

use super::{
    RouteDecision, CREATE_FOLDER_CLUSTER_COSINE, CREATE_FOLDER_CLUSTER_MIN_COUNT,
    MERGE_CONFIDENCE_GATE, MERGE_STALENESS_HOURS, VARIANT_C_CREATE_FOLDER_CONFIDENCE,
    VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE, VARIANT_C_PLACE_VIA_MAJORITY_CONFIDENCE,
};

#[derive(Debug, Clone, PartialEq)]
pub struct Concept {
    pub canonical_name: String,
    pub surface_form: String,
}

#[async_trait]
pub trait ConceptExtractor: Send + Sync {
    async fn extract(&self, text: &str) -> Result<Vec<Concept>, ExtractorError>;
}

#[derive(Debug, thiserror::Error)]
pub enum ExtractorError {
    #[error("extraction failed: {0}")]
    Inference(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Resolution {
    Found { concept_id: String },
    New,
}

#[async_trait]
pub trait EntityResolver: Send + Sync {
    async fn resolve(&self, canonical_name: &str) -> Resolution;
}

#[derive(Debug, Clone, PartialEq)]
pub struct NeighbourHit {
    pub path: String,
    pub folder: String,
    pub cosine: f64,
    pub last_edited_hours_ago: u64,
}

#[async_trait]
pub trait NeighbourFinder: Send + Sync {
    async fn find(&self, query: &str, k: usize) -> Vec<NeighbourHit>;
}

pub async fn try_concept_anchored(
    capture_text: &str,
    extractor: &dyn ConceptExtractor,
    resolver: &dyn EntityResolver,
    neighbours: &dyn NeighbourFinder,
    parent_unfit: impl Fn(&str) -> bool,
) -> Option<RouteDecision> {
    if capture_text.trim().is_empty() {
        return None;
    }

    let concepts = extractor.extract(capture_text).await.ok()?;
    let primary = concepts.first()?;
    let canonical = canon::canonicalize(&primary.canonical_name);
    if canonical.is_empty() {
        return None;
    }

    let resolution = resolver.resolve(&canonical).await;
    let hits = neighbours.find(&canonical, 12).await;
    if hits.is_empty() {
        return None;
    }

    let (top_folder, count) = group_by_folder(&hits)
        .into_iter()
        .max_by_key(|(_, count)| *count)?;
    if count < CREATE_FOLDER_CLUSTER_MIN_COUNT {
        return None;
    }

    let tight = cluster_tight(&hits, &top_folder);
    match (&resolution, tight) {
        (Resolution::Found { .. }, true) => {
            let strongest =
                hits.iter()
                    .filter(|hit| hit.folder == top_folder)
                    .max_by(|left, right| {
                        left.cosine
                            .partial_cmp(&right.cosine)
                            .unwrap_or(std::cmp::Ordering::Equal)
                    });
            if let Some(hit) = strongest {
                if hit.cosine >= MERGE_CONFIDENCE_GATE
                    && hit.last_edited_hours_ago > MERGE_STALENESS_HOURS
                {
                    return Some(RouteDecision::merge(
                        hit.path.clone(),
                        hit.cosine,
                        format!(
                            "variant_c merge: cos {:.3} >= {:.2}, staleness {}h > {}h",
                            hit.cosine,
                            MERGE_CONFIDENCE_GATE,
                            hit.last_edited_hours_ago,
                            MERGE_STALENESS_HOURS
                        ),
                    ));
                }
            }
            Some(RouteDecision::place(
                top_folder,
                VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE,
                "variant_c place via found concept; merge gate not satisfied",
            ))
        }
        (Resolution::New, true) if parent_unfit(&top_folder) => Some(RouteDecision::create_folder(
            top_folder,
            canonical.replace('_', "-"),
            VARIANT_C_CREATE_FOLDER_CONFIDENCE,
            "variant_c create_folder: new concept, tight cluster, no parent fits",
        )),
        _ => Some(RouteDecision::place(
            top_folder,
            VARIANT_C_PLACE_VIA_MAJORITY_CONFIDENCE,
            "variant_c place by neighbour majority",
        )),
    }
}

fn group_by_folder(hits: &[NeighbourHit]) -> Vec<(String, usize)> {
    let mut counts = HashMap::new();
    for hit in hits {
        *counts.entry(hit.folder.clone()).or_insert(0) += 1;
    }
    counts.into_iter().collect()
}

fn cluster_tight(hits: &[NeighbourHit], top_folder: &str) -> bool {
    let folder_hits = hits
        .iter()
        .filter(|hit| hit.folder == top_folder)
        .collect::<Vec<_>>();
    folder_hits.len() >= CREATE_FOLDER_CLUSTER_MIN_COUNT
        && folder_hits
            .iter()
            .all(|hit| hit.cosine >= CREATE_FOLDER_CLUSTER_COSINE)
}
