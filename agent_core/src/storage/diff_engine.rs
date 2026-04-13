use serde::{Deserialize, Serialize};
use serde_json::Value;
use similar::{ChangeTag, TextDiff};
use std::collections::BTreeSet;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct UnifiedDiff {
    pub hunks: Vec<DiffHunk>,
    pub has_trailing_newline: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiffHunk {
    pub old_start: usize,
    pub old_count: usize,
    pub new_start: usize,
    pub new_count: usize,
    pub lines: Vec<DiffLine>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum DiffLine {
    Context(String),
    Add(String),
    Remove(String),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JsonPatch {
    pub op: JsonPatchOperation,
    pub path: String,
    pub value: Option<Value>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum JsonPatchOperation {
    Add,
    Remove,
    Replace,
}

#[derive(Debug, thiserror::Error)]
pub enum DiffError {
    #[error("patch hunk did not match target text near line {expected_line}")]
    ContextMismatch { expected_line: usize },
}

pub fn generate_text_diff(old: &str, new: &str) -> UnifiedDiff {
    if old == new {
        return UnifiedDiff {
            hunks: Vec::new(),
            has_trailing_newline: new.ends_with('\n'),
        };
    }

    let diff = TextDiff::from_lines(old, new);
    let mut hunks = Vec::new();

    for group in diff.grouped_ops(3) {
        let Some(first) = group.first() else {
            continue;
        };
        let Some(last) = group.last() else {
            continue;
        };

        let old_range = first.old_range().start..last.old_range().end;
        let new_range = first.new_range().start..last.new_range().end;
        let old_count = old_range.end.saturating_sub(old_range.start);
        let new_count = new_range.end.saturating_sub(new_range.start);
        let mut lines = Vec::new();

        for op in group {
            for change in diff.iter_changes(&op) {
                let line = normalize_diff_line(change.to_string());
                let diff_line = match change.tag() {
                    ChangeTag::Equal => DiffLine::Context(line),
                    ChangeTag::Insert => DiffLine::Add(line),
                    ChangeTag::Delete => DiffLine::Remove(line),
                };
                lines.push(diff_line);
            }
        }

        hunks.push(DiffHunk {
            old_start: to_unified_start(old_range.start, old_count),
            old_count,
            new_start: to_unified_start(new_range.start, new_count),
            new_count,
            lines,
        });
    }

    UnifiedDiff {
        hunks,
        has_trailing_newline: new.ends_with('\n'),
    }
}

pub fn generate_json_diff(old: &Value, new: &Value) -> Vec<JsonPatch> {
    let mut patches = Vec::new();
    diff_json_value("", old, new, &mut patches);
    patches
}

pub fn apply_text_patch(original: &str, diff: &UnifiedDiff) -> Result<String, DiffError> {
    let mut lines = split_text_lines(original);
    let mut line_offset = 0_isize;

    for hunk in &diff.hunks {
        let target_lines = old_lines_from_hunk(hunk);
        let replacement_lines = new_lines_from_hunk(hunk);
        let base_index = from_unified_start(hunk.old_start, hunk.old_count);
        let expected_index = apply_offset(base_index, line_offset, lines.len());
        let matched_index = locate_hunk(&lines, &target_lines, expected_index).ok_or(
            DiffError::ContextMismatch {
                expected_line: hunk.old_start,
            },
        )?;

        lines.splice(
            matched_index..matched_index + target_lines.len(),
            replacement_lines.into_iter(),
        );
        line_offset += hunk.new_count as isize - hunk.old_count as isize;
    }

    Ok(join_text_lines(&lines, diff.has_trailing_newline))
}

fn normalize_diff_line(line: String) -> String {
    line.trim_end_matches('\n')
        .trim_end_matches('\r')
        .to_string()
}

fn to_unified_start(start: usize, count: usize) -> usize {
    if count == 0 {
        start
    } else {
        start + 1
    }
}

fn from_unified_start(start: usize, count: usize) -> usize {
    if count == 0 {
        start
    } else {
        start.saturating_sub(1)
    }
}

fn split_text_lines(text: &str) -> Vec<String> {
    if text.is_empty() {
        Vec::new()
    } else {
        text.lines().map(ToString::to_string).collect()
    }
}

fn join_text_lines(lines: &[String], has_trailing_newline: bool) -> String {
    let mut joined = lines.join("\n");
    if has_trailing_newline && (!joined.is_empty() || lines.is_empty()) {
        joined.push('\n');
    }
    joined
}

fn old_lines_from_hunk(hunk: &DiffHunk) -> Vec<String> {
    hunk.lines
        .iter()
        .filter_map(|line| match line {
            DiffLine::Context(text) | DiffLine::Remove(text) => Some(text.clone()),
            DiffLine::Add(_) => None,
        })
        .collect()
}

fn new_lines_from_hunk(hunk: &DiffHunk) -> Vec<String> {
    hunk.lines
        .iter()
        .filter_map(|line| match line {
            DiffLine::Context(text) | DiffLine::Add(text) => Some(text.clone()),
            DiffLine::Remove(_) => None,
        })
        .collect()
}

fn apply_offset(index: usize, offset: isize, max_len: usize) -> usize {
    let shifted = index as isize + offset;
    shifted.clamp(0, max_len as isize) as usize
}

fn locate_hunk(lines: &[String], target_lines: &[String], expected_index: usize) -> Option<usize> {
    if target_lines.is_empty() {
        return Some(expected_index.min(lines.len()));
    }

    let max_start = lines.len().checked_sub(target_lines.len())?;
    for delta in [0_isize, -1, 1, -2, 2, -3, 3] {
        let candidate = expected_index as isize + delta;
        if !(0..=max_start as isize).contains(&candidate) {
            continue;
        }
        let candidate = candidate as usize;
        if lines[candidate..candidate + target_lines.len()] == *target_lines {
            return Some(candidate);
        }
    }

    None
}

fn diff_json_value(path: &str, old: &Value, new: &Value, patches: &mut Vec<JsonPatch>) {
    if old == new {
        return;
    }

    match (old, new) {
        (Value::Object(old_map), Value::Object(new_map)) => {
            let mut keys = BTreeSet::new();
            keys.extend(old_map.keys().cloned());
            keys.extend(new_map.keys().cloned());

            for key in keys {
                let child_path = join_json_pointer(path, &key);
                match (old_map.get(&key), new_map.get(&key)) {
                    (Some(old_value), Some(new_value)) => {
                        diff_json_value(&child_path, old_value, new_value, patches);
                    }
                    (None, Some(new_value)) => patches.push(JsonPatch {
                        op: JsonPatchOperation::Add,
                        path: child_path,
                        value: Some(new_value.clone()),
                    }),
                    (Some(_), None) => patches.push(JsonPatch {
                        op: JsonPatchOperation::Remove,
                        path: child_path,
                        value: None,
                    }),
                    (None, None) => {}
                }
            }
        }
        (Value::Array(old_items), Value::Array(new_items)) => {
            let max_len = old_items.len().max(new_items.len());
            for index in 0..max_len {
                let child_path = join_json_pointer(path, &index.to_string());
                match (old_items.get(index), new_items.get(index)) {
                    (Some(old_value), Some(new_value)) => {
                        diff_json_value(&child_path, old_value, new_value, patches);
                    }
                    (None, Some(new_value)) => patches.push(JsonPatch {
                        op: JsonPatchOperation::Add,
                        path: child_path,
                        value: Some(new_value.clone()),
                    }),
                    (Some(_), None) => patches.push(JsonPatch {
                        op: JsonPatchOperation::Remove,
                        path: child_path,
                        value: None,
                    }),
                    (None, None) => {}
                }
            }
        }
        _ => patches.push(JsonPatch {
            op: JsonPatchOperation::Replace,
            path: path.to_string(),
            value: Some(new.clone()),
        }),
    }
}

fn join_json_pointer(base: &str, segment: &str) -> String {
    let escaped = segment.replace('~', "~0").replace('/', "~1");
    if base.is_empty() {
        format!("/{escaped}")
    } else {
        format!("{base}/{escaped}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn diff_engine_round_trips_text_changes() {
        let old = "alpha\nbeta\ngamma\n";
        let new = "alpha\nbeta updated\ngamma\ndelta\n";

        let diff = generate_text_diff(old, new);
        assert!(!diff.hunks.is_empty(), "expected at least one hunk");

        let applied = apply_text_patch(old, &diff).expect("patch should apply");
        assert_eq!(applied, new);
    }

    #[test]
    fn diff_engine_generates_nested_json_patches() {
        let old = json!({
            "model": {
                "pricing": { "input": 15, "output": 60 }
            }
        });
        let new = json!({
            "model": {
                "pricing": { "input": 12, "output": 60 },
                "cache": true
            }
        });

        let patches = generate_json_diff(&old, &new);
        assert!(patches.iter().any(|patch| {
            patch.path == "/model/pricing/input"
                && patch.op == JsonPatchOperation::Replace
                && patch.value == Some(json!(12))
        }));
        assert!(patches.iter().any(|patch| {
            patch.path == "/model/cache"
                && patch.op == JsonPatchOperation::Add
                && patch.value == Some(json!(true))
        }));
    }

    #[test]
    fn diff_engine_applies_patch_when_context_shifted_by_three_lines() {
        let old = "header\nalpha\nbeta\ngamma\n";
        let new = "header\nalpha\nbeta revised\ngamma\n";
        let shifted_original =
            "preamble one\npreamble two\npreamble three\nheader\nalpha\nbeta\ngamma\n";
        let shifted_expected =
            "preamble one\npreamble two\npreamble three\nheader\nalpha\nbeta revised\ngamma\n";

        let diff = generate_text_diff(old, new);
        let applied = apply_text_patch(shifted_original, &diff).expect("fuzzy patch should apply");
        assert_eq!(applied, shifted_expected);
    }

    #[test]
    fn diff_engine_returns_empty_diff_for_identical_inputs() {
        let text = "same\ncontent\n";
        let diff = generate_text_diff(text, text);
        assert!(diff.hunks.is_empty());
        assert_eq!(apply_text_patch(text, &diff).unwrap(), text);
    }
}
