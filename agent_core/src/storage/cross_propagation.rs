use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::schema::Value;
use tantivy::{Index, TantivyDocument};

use crate::storage::diff_engine::{
    apply_text_patch, generate_text_diff, DiffError, DiffHunk, DiffLine, UnifiedDiff,
};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PropagationResult {
    pub primary_diff: UnifiedDiff,
    pub secondary_diffs: Vec<(PathBuf, UnifiedDiff)>,
    pub all_atomic: bool,
}

#[derive(Debug, thiserror::Error)]
pub enum PropagationError {
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("diff application error: {0}")]
    Diff(#[from] DiffError),
    #[error("atomic propagation requires all_atomic=true")]
    NonAtomicBatch,
}

pub fn scan_for_references(
    changed_entity: &str,
    vault_root: &Path,
    exclude: &Path,
) -> Vec<(PathBuf, String, usize)> {
    let mut references = scan_with_tantivy(changed_entity, vault_root, exclude).unwrap_or_default();
    if references.is_empty() {
        references = scan_with_filesystem(changed_entity, vault_root, exclude);
    }
    references
}

pub fn generate_propagation_diffs(
    primary_diff: &UnifiedDiff,
    references: &[(PathBuf, String, usize)],
) -> Vec<(PathBuf, UnifiedDiff)> {
    let replacements = extract_replacements(primary_diff);
    let mut diffs = Vec::new();

    for (path, matched_line, line_number) in references {
        let mut updated_line = matched_line.clone();
        for (old_text, new_text) in &replacements {
            if old_text.is_empty() || old_text == new_text || !updated_line.contains(old_text) {
                continue;
            }
            updated_line = updated_line.replace(old_text, new_text);
        }

        if updated_line == *matched_line {
            continue;
        }

        let mut diff = generate_text_diff(
            &format!("{matched_line}\n"),
            &format!("{updated_line}\n"),
        );
        rebase_diff_to_line(&mut diff, *line_number);
        diffs.push((path.clone(), diff));
    }

    diffs
}

pub fn apply_atomic_propagation(
    primary_path: &Path,
    result: &PropagationResult,
) -> Result<(), PropagationError> {
    if !result.all_atomic {
        return Err(PropagationError::NonAtomicBatch);
    }

    let mut originals = Vec::with_capacity(result.secondary_diffs.len() + 1);
    originals.push((primary_path.to_path_buf(), std::fs::read_to_string(primary_path)?));
    for (path, _) in &result.secondary_diffs {
        originals.push((path.clone(), std::fs::read_to_string(path)?));
    }

    let primary_original = originals[0].1.clone();
    let primary_updated = apply_text_patch(&primary_original, &result.primary_diff)?;
    std::fs::write(primary_path, primary_updated)?;

    for (path, diff) in &result.secondary_diffs {
        let original = originals
            .iter()
            .find(|(original_path, _)| original_path == path)
            .map(|(_, content)| content.clone())
            .unwrap_or_default();
        let updated = match apply_text_patch(&original, diff) {
            Ok(updated) => updated,
            Err(error) => {
                rollback_originals(&originals)?;
                return Err(PropagationError::Diff(error));
            }
        };

        if let Err(error) = std::fs::write(path, updated) {
            rollback_originals(&originals)?;
            return Err(PropagationError::Io(error));
        }
    }

    Ok(())
}

fn rollback_originals(originals: &[(PathBuf, String)]) -> Result<(), std::io::Error> {
    for (path, content) in originals {
        std::fs::write(path, content)?;
    }
    Ok(())
}

fn scan_with_tantivy(changed_entity: &str, vault_root: &Path, exclude: &Path) -> Option<Vec<(PathBuf, String, usize)>> {
    let index_path = vault_root.join(".epistemos").join("tantivy");
    if !index_path.exists() {
        return None;
    }

    let directory = tantivy::directory::MmapDirectory::open(&index_path).ok()?;
    let index = Index::open(directory).ok()?;
    let schema = index.schema();
    let field_path = schema.get_field("path").ok()?;
    let field_content = schema.get_field("content").ok()?;
    let reader = index.reader().ok()?;
    let searcher = reader.searcher();
    let parser = QueryParser::for_index(&index, vec![field_content]);
    let query_text = format!("\"{}\"", changed_entity.replace('"', "\\\""));
    let query = parser.parse_query(&query_text).ok()?;
    let top_docs = searcher.search(&query, &TopDocs::with_limit(256)).ok()?;
    let mut references = Vec::new();

    for (_, address) in top_docs {
        let document: TantivyDocument = searcher.doc(address).ok()?;
        let relative_path = document
            .get_first(field_path)
            .and_then(|value| value.as_str())
            .unwrap_or("");
        if relative_path.is_empty() {
            continue;
        }

        let absolute_path = vault_root.join(relative_path);
        if paths_match(&absolute_path, exclude) {
            continue;
        }

        let content = document
            .get_first(field_content)
            .and_then(|value| value.as_str())
            .unwrap_or("");
        collect_matching_lines(changed_entity, &absolute_path, content, &mut references);
    }

    Some(references)
}

fn scan_with_filesystem(changed_entity: &str, vault_root: &Path, exclude: &Path) -> Vec<(PathBuf, String, usize)> {
    let mut references = Vec::new();
    let mut stack = vec![vault_root.to_path_buf()];

    while let Some(directory) = stack.pop() {
        let entries = match std::fs::read_dir(&directory) {
            Ok(entries) => entries,
            Err(_) => continue,
        };

        for entry in entries.flatten() {
            let path = entry.path();
            let name = path.file_name().and_then(|value| value.to_str()).unwrap_or("");
            if name.starts_with('.') {
                continue;
            }

            if path.is_dir() {
                stack.push(path);
                continue;
            }

            if path.extension().and_then(|value| value.to_str()) != Some("md") || paths_match(&path, exclude) {
                continue;
            }

            if let Ok(content) = std::fs::read_to_string(&path) {
                collect_matching_lines(changed_entity, &path, &content, &mut references);
            }
        }
    }

    references
}

fn collect_matching_lines(
    changed_entity: &str,
    path: &Path,
    content: &str,
    references: &mut Vec<(PathBuf, String, usize)>,
) {
    for (index, line) in content.lines().enumerate() {
        if line.contains(changed_entity) {
            references.push((path.to_path_buf(), line.to_string(), index + 1));
        }
    }
}

fn extract_replacements(diff: &UnifiedDiff) -> Vec<(String, String)> {
    let mut replacements = Vec::new();

    for hunk in &diff.hunks {
        let mut removed = Vec::new();
        let mut added = Vec::new();
        for line in &hunk.lines {
            match line {
                DiffLine::Remove(text) => removed.push(text.clone()),
                DiffLine::Add(text) => added.push(text.clone()),
                DiffLine::Context(_) => flush_replacement(&mut replacements, &mut removed, &mut added),
            }
        }
        flush_replacement(&mut replacements, &mut removed, &mut added);
    }

    replacements
}

fn flush_replacement(
    replacements: &mut Vec<(String, String)>,
    removed: &mut Vec<String>,
    added: &mut Vec<String>,
) {
    if removed.is_empty() && added.is_empty() {
        return;
    }

    replacements.push((removed.join("\n"), added.join("\n")));
    removed.clear();
    added.clear();
}

fn rebase_diff_to_line(diff: &mut UnifiedDiff, line_number: usize) {
    for hunk in &mut diff.hunks {
        rebase_hunk(hunk, line_number);
    }
}

fn rebase_hunk(hunk: &mut DiffHunk, line_number: usize) {
    hunk.old_start = if hunk.old_count == 0 {
        line_number.saturating_sub(1)
    } else {
        line_number
    };
    hunk.new_start = if hunk.new_count == 0 {
        line_number.saturating_sub(1)
    } else {
        line_number
    };
}

fn paths_match(left: &Path, right: &Path) -> bool {
    left == right
        || left
            .canonicalize()
            .ok()
            .zip(right.canonicalize().ok())
            .map(|(left, right)| left == right)
            .unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::diff_engine::{apply_text_patch, generate_text_diff};
    use uuid::Uuid;

    fn temp_vault() -> PathBuf {
        let root = std::env::temp_dir().join(format!("epistemos-cross-prop-{}", Uuid::new_v4()));
        std::fs::create_dir_all(&root).unwrap();
        root
    }

    #[test]
    fn cross_propagation_updates_referencing_files() {
        let vault_root = temp_vault();
        let primary_path = vault_root.join("pricing.md");
        let reference_path = vault_root.join("summary.md");
        std::fs::write(&primary_path, "Claude costs $15 per month.\n").unwrap();
        std::fs::write(
            &reference_path,
            "Provider summary\nClaude costs $15 per month.\n",
        )
        .unwrap();

        let primary_diff = generate_text_diff(
            "Claude costs $15 per month.\n",
            "Claude costs $20 per month.\n",
        );
        let references = scan_for_references("Claude costs $15 per month.", &vault_root, &primary_path);
        let diffs = generate_propagation_diffs(&primary_diff, &references);

        assert_eq!(diffs.len(), 1);
        let (_, diff) = &diffs[0];
        let patched = apply_text_patch(
            &std::fs::read_to_string(&reference_path).unwrap(),
            diff,
        )
        .unwrap();
        assert!(patched.contains("Claude costs $20 per month."));

        std::fs::remove_dir_all(vault_root).unwrap();
    }

    #[test]
    fn cross_propagation_skips_files_without_references() {
        let vault_root = temp_vault();
        let primary_path = vault_root.join("pricing.md");
        let unrelated_path = vault_root.join("notes.md");
        std::fs::write(&primary_path, "Claude costs $15 per month.\n").unwrap();
        std::fs::write(&unrelated_path, "Hermes is managed as a subprocess.\n").unwrap();

        let references = scan_for_references("Claude costs $15 per month.", &vault_root, &primary_path);

        assert!(references.is_empty());
        std::fs::remove_dir_all(vault_root).unwrap();
    }

    #[test]
    fn cross_propagation_rolls_back_when_secondary_apply_fails() {
        let vault_root = temp_vault();
        let primary_path = vault_root.join("pricing.md");
        let secondary_path = vault_root.join("summary.md");
        std::fs::write(&primary_path, "Claude costs $15 per month.\n").unwrap();
        std::fs::write(&secondary_path, "Provider summary only.\n").unwrap();

        let result = PropagationResult {
            primary_diff: generate_text_diff(
                "Claude costs $15 per month.\n",
                "Claude costs $20 per month.\n",
            ),
            secondary_diffs: vec![(
                secondary_path.clone(),
                generate_text_diff("Claude costs $15 per month.\n", "Claude costs $20 per month.\n"),
            )],
            all_atomic: true,
        };

        let apply_result = apply_atomic_propagation(&primary_path, &result);

        assert!(apply_result.is_err());
        assert_eq!(
            std::fs::read_to_string(&primary_path).unwrap(),
            "Claude costs $15 per month.\n"
        );

        std::fs::remove_dir_all(vault_root).unwrap();
    }
}
