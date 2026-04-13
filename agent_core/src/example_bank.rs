use std::fs;
use std::path::Path;

// ---------------------------------------------------------------------------
// Example Bank — Few-Shot Retrieval + Quality Ranking
// ---------------------------------------------------------------------------
//
// Manages a bank of few-shot examples stored as markdown files in the
// vault's `examples/` directory. Examples are ranked by relevance to
// the current query using term overlap + recency + quality score.
//
// Each example file has optional frontmatter with metadata:
// ---
// quality: 0.95
// tags: [code, rust, testing]
// created: 2026-03-15
// ---

/// A few-shot example with quality metadata.
#[derive(Debug, Clone)]
pub struct Example {
    pub title: String,
    pub content: String,
    pub quality: f64,
    pub tags: Vec<String>,
    pub file_path: String,
}

/// A ranked example match.
#[derive(Debug, Clone)]
pub struct ExampleMatch {
    pub example: Example,
    pub relevance: f64,
}

/// Manages and retrieves few-shot examples from the vault.
pub struct ExampleBank {
    examples: Vec<Example>,
}

impl ExampleBank {
    /// Load examples from a vault's `examples/` directory.
    pub fn load(vault_path: &Path) -> Self {
        let examples_dir = vault_path.join("examples");
        let examples = if examples_dir.exists() {
            load_examples_from_dir(&examples_dir)
        } else {
            Vec::new()
        };
        Self { examples }
    }

    /// Retrieve top-k examples most relevant to the query.
    /// Ranking: term_overlap * 0.6 + quality * 0.3 + tag_match * 0.1
    pub fn retrieve(&self, query: &str, tags_hint: &[String], top_k: usize) -> Vec<ExampleMatch> {
        if self.examples.is_empty() {
            return Vec::new();
        }

        let query_terms: Vec<String> = tokenize(query);

        let mut matches: Vec<ExampleMatch> = self
            .examples
            .iter()
            .map(|example| {
                let content_terms = tokenize(&format!("{} {}", example.title, example.content));
                let term_overlap = jaccard_similarity(&query_terms, &content_terms);

                let tag_match = if tags_hint.is_empty() {
                    0.0
                } else {
                    let matched = example
                        .tags
                        .iter()
                        .filter(|t| tags_hint.iter().any(|h| h.eq_ignore_ascii_case(t)))
                        .count();
                    matched as f64 / tags_hint.len().max(1) as f64
                };

                let relevance = term_overlap * 0.6 + example.quality * 0.3 + tag_match * 0.1;

                ExampleMatch {
                    example: example.clone(),
                    relevance,
                }
            })
            .filter(|m| m.relevance > 0.01)
            .collect();

        matches.sort_by(|a, b| {
            b.relevance
                .partial_cmp(&a.relevance)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        matches.truncate(top_k);
        matches
    }

    /// Number of loaded examples.
    pub fn count(&self) -> usize {
        self.examples.len()
    }

    /// Add a new example to the bank (writes to disk).
    pub fn add(
        &mut self,
        vault_path: &Path,
        title: &str,
        content: &str,
        quality: f64,
        tags: &[String],
    ) -> Result<(), std::io::Error> {
        let examples_dir = vault_path.join("examples");
        fs::create_dir_all(&examples_dir)?;

        let slug = title
            .to_lowercase()
            .chars()
            .map(|c| if c.is_alphanumeric() { c } else { '-' })
            .collect::<String>();
        let file_path = examples_dir.join(format!("{slug}.md"));

        let mut frontmatter = format!(
            "---\nquality: {quality:.2}\ntags: [{}]\ncreated: {}\n---\n",
            tags.join(", "),
            chrono::Utc::now().format("%Y-%m-%d")
        );
        frontmatter.push_str(&format!("# {title}\n\n{content}\n"));

        fs::write(&file_path, &frontmatter)?;

        self.examples.push(Example {
            title: title.to_string(),
            content: content.to_string(),
            quality,
            tags: tags.to_vec(),
            file_path: file_path.to_string_lossy().to_string(),
        });

        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

fn load_examples_from_dir(dir: &Path) -> Vec<Example> {
    let mut examples = Vec::new();
    let entries = match fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return examples,
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("md") {
            continue;
        }
        let content = match fs::read_to_string(&path) {
            Ok(c) => c,
            Err(_) => continue,
        };
        if let Some(example) = parse_example(&content, &path) {
            examples.push(example);
        }
    }

    examples
}

fn parse_example(content: &str, path: &Path) -> Option<Example> {
    let mut title = String::new();
    let mut quality = 0.5; // default quality
    let mut tags = Vec::new();
    let mut body_lines = Vec::new();
    let mut in_frontmatter = false;
    let mut past_frontmatter = false;

    for line in content.lines() {
        if line.trim() == "---" {
            if !in_frontmatter && !past_frontmatter {
                in_frontmatter = true;
                continue;
            } else if in_frontmatter {
                in_frontmatter = false;
                past_frontmatter = true;
                continue;
            }
        }

        if in_frontmatter {
            if let Some(val) = line.strip_prefix("quality:") {
                quality = val.trim().parse::<f64>().unwrap_or(0.5);
            } else if let Some(val) = line.strip_prefix("tags:") {
                tags = val
                    .trim()
                    .trim_start_matches('[')
                    .trim_end_matches(']')
                    .split(',')
                    .map(|t| t.trim().to_string())
                    .filter(|t| !t.is_empty())
                    .collect();
            }
        } else {
            if title.is_empty() && line.starts_with("# ") {
                title = line.trim_start_matches('#').trim().to_string();
            }
            body_lines.push(line);
        }
    }

    if title.is_empty() {
        title = path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("example")
            .to_string();
    }

    Some(Example {
        title,
        content: body_lines.join("\n").trim().to_string(),
        quality: quality.clamp(0.0, 1.0),
        tags,
        file_path: path.to_string_lossy().to_string(),
    })
}

// ---------------------------------------------------------------------------
// Similarity
// ---------------------------------------------------------------------------

fn tokenize(text: &str) -> Vec<String> {
    text.to_lowercase()
        .split(|c: char| !c.is_alphanumeric())
        .filter(|w| w.len() > 2)
        .map(String::from)
        .collect()
}

fn jaccard_similarity(a: &[String], b: &[String]) -> f64 {
    if a.is_empty() && b.is_empty() {
        return 0.0;
    }
    let set_a: std::collections::HashSet<&str> = a.iter().map(|s| s.as_str()).collect();
    let set_b: std::collections::HashSet<&str> = b.iter().map(|s| s.as_str()).collect();
    let intersection = set_a.intersection(&set_b).count() as f64;
    let union = set_a.union(&set_b).count() as f64;
    if union == 0.0 {
        0.0
    } else {
        intersection / union
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_example_with_frontmatter() {
        let content = r#"---
quality: 0.9
tags: [rust, testing]
created: 2026-03-15
---
# Rust Unit Test
```rust
#[test]
fn it_works() { assert!(true); }
```
"#;
        let example = parse_example(content, Path::new("test.md")).unwrap();
        assert_eq!(example.title, "Rust Unit Test");
        assert!((example.quality - 0.9).abs() < 0.001);
        assert_eq!(example.tags, vec!["rust", "testing"]);
    }

    #[test]
    fn test_parse_example_no_frontmatter() {
        let content = "# Simple Example\nJust some code.";
        let example = parse_example(content, Path::new("simple.md")).unwrap();
        assert_eq!(example.title, "Simple Example");
        assert!((example.quality - 0.5).abs() < 0.001);
    }

    #[test]
    fn test_jaccard_identical() {
        let a = vec!["hello".into(), "world".into()];
        let sim = jaccard_similarity(&a, &a);
        assert!((sim - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_jaccard_disjoint() {
        let a: Vec<String> = vec!["hello".into()];
        let b: Vec<String> = vec!["world".into()];
        let sim = jaccard_similarity(&a, &b);
        assert!(sim.abs() < 0.001);
    }

    #[test]
    fn test_retrieve_empty_bank() {
        let bank = ExampleBank { examples: vec![] };
        assert!(bank.retrieve("anything", &[], 5).is_empty());
    }

    #[test]
    fn test_retrieve_by_content() {
        let bank = ExampleBank {
            examples: vec![
                Example {
                    title: "Rust Testing".into(),
                    content: "Write unit tests with #[test]".into(),
                    quality: 0.9,
                    tags: vec!["rust".into()],
                    file_path: "test.md".into(),
                },
                Example {
                    title: "Python Flask".into(),
                    content: "Build a web server with Flask".into(),
                    quality: 0.8,
                    tags: vec!["python".into()],
                    file_path: "flask.md".into(),
                },
            ],
        };
        let matches = bank.retrieve("write a rust unit test", &[], 3);
        assert!(!matches.is_empty());
        assert_eq!(matches[0].example.title, "Rust Testing");
    }
}
