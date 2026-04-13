use std::collections::HashMap;
use std::fs;
use std::path::Path;

// ---------------------------------------------------------------------------
// Skill Router — Embedding-Based Skill Selection
// ---------------------------------------------------------------------------
//
// Routes incoming queries to the most relevant skills in the vault.
// Uses TF-IDF cosine similarity for lightweight, zero-latency matching
// (no external embedding model required).
//
// Skills are SKILL.md files in the vault's `skills/` directory.
// Each skill has a name, description, trigger patterns, and a body.

/// A parsed skill definition from a SKILL.md file.
#[derive(Debug, Clone)]
pub struct SkillEntry {
    pub name: String,
    pub description: String,
    pub triggers: Vec<String>,
    pub file_path: String,
    pub body: String,
}

/// Skill match with relevance score.
#[derive(Debug, Clone)]
pub struct SkillMatch {
    pub skill: SkillEntry,
    pub score: f64,
    pub matched_trigger: Option<String>,
}

/// Routes queries to skills using TF-IDF cosine similarity.
pub struct SkillRouter {
    skills: Vec<SkillEntry>,
    /// IDF weights for terms across all skill documents.
    idf: HashMap<String, f64>,
}

impl SkillRouter {
    /// Load skills from a vault's `skills/` directory.
    pub fn load(vault_path: &Path) -> Self {
        let skills_dir = vault_path.join("skills");
        let skills = if skills_dir.exists() {
            load_skills(&skills_dir)
        } else {
            Vec::new()
        };

        let idf = compute_idf(&skills);
        Self { skills, idf }
    }

    /// Find the top-k skills most relevant to the query.
    pub fn route(&self, query: &str, top_k: usize) -> Vec<SkillMatch> {
        if self.skills.is_empty() {
            return Vec::new();
        }

        let query_terms = tokenize(query);
        let query_vec = tfidf_vector(&query_terms, &self.idf);

        let mut matches: Vec<SkillMatch> = self
            .skills
            .iter()
            .map(|skill| {
                // Check explicit trigger patterns first (exact match → high score).
                let trigger_match = skill.triggers.iter().find(|t| {
                    let t_lower = t.to_lowercase();
                    query.to_lowercase().contains(&t_lower)
                });

                if let Some(trigger) = trigger_match {
                    return SkillMatch {
                        skill: skill.clone(),
                        score: 1.0,
                        matched_trigger: Some(trigger.clone()),
                    };
                }

                // TF-IDF cosine similarity on skill description + name.
                let skill_text = format!(
                    "{} {} {}",
                    skill.name,
                    skill.description,
                    skill.triggers.join(" ")
                );
                let skill_terms = tokenize(&skill_text);
                let skill_vec = tfidf_vector(&skill_terms, &self.idf);
                let score = cosine_similarity(&query_vec, &skill_vec);

                SkillMatch {
                    skill: skill.clone(),
                    score,
                    matched_trigger: None,
                }
            })
            .filter(|m| m.score > 0.05)
            .collect();

        matches.sort_by(|a, b| {
            b.score
                .partial_cmp(&a.score)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        matches.truncate(top_k);
        matches
    }

    /// Number of loaded skills.
    pub fn skill_count(&self) -> usize {
        self.skills.len()
    }
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

fn load_skills(dir: &Path) -> Vec<SkillEntry> {
    let mut skills = Vec::new();
    let entries = match fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return skills,
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

        if let Some(skill) = parse_skill(&content, &path) {
            skills.push(skill);
        }
    }

    skills
}

fn parse_skill(content: &str, path: &Path) -> Option<SkillEntry> {
    let mut name = String::new();
    let mut description = String::new();
    let mut triggers = Vec::new();
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
            if let Some(val) = line.strip_prefix("name:") {
                name = val.trim().trim_matches('"').to_string();
            } else if let Some(val) = line.strip_prefix("description:") {
                description = val.trim().trim_matches('"').to_string();
            } else if let Some(val) = line.strip_prefix("triggers:") {
                triggers = val
                    .trim()
                    .trim_start_matches('[')
                    .trim_end_matches(']')
                    .split(',')
                    .map(|t| t.trim().trim_matches('"').trim_matches('\'').to_string())
                    .filter(|t| !t.is_empty())
                    .collect();
            }
        } else {
            // Extract name from first heading if not in frontmatter.
            if name.is_empty() && line.starts_with("# ") {
                name = line.trim_start_matches('#').trim().to_string();
            }
            body_lines.push(line);
        }
    }

    if name.is_empty() {
        name = path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("unnamed")
            .to_string();
    }

    Some(SkillEntry {
        name,
        description,
        triggers,
        file_path: path.to_string_lossy().to_string(),
        body: body_lines.join("\n"),
    })
}

// ---------------------------------------------------------------------------
// TF-IDF
// ---------------------------------------------------------------------------

fn tokenize(text: &str) -> Vec<String> {
    text.to_lowercase()
        .split(|c: char| !c.is_alphanumeric())
        .filter(|w| w.len() > 2)
        .map(String::from)
        .collect()
}

fn compute_idf(skills: &[SkillEntry]) -> HashMap<String, f64> {
    let n = skills.len().max(1) as f64;
    let mut doc_freq: HashMap<String, usize> = HashMap::new();

    for skill in skills {
        let text = format!(
            "{} {} {}",
            skill.name,
            skill.description,
            skill.triggers.join(" ")
        );
        let terms: std::collections::HashSet<String> = tokenize(&text).into_iter().collect();
        for term in terms {
            *doc_freq.entry(term).or_insert(0) += 1;
        }
    }

    doc_freq
        .into_iter()
        .map(|(term, df)| (term, (n / (1.0 + df as f64)).ln() + 1.0))
        .collect()
}

fn tfidf_vector(terms: &[String], idf: &HashMap<String, f64>) -> HashMap<String, f64> {
    let mut tf: HashMap<String, f64> = HashMap::new();
    let total = terms.len().max(1) as f64;

    for term in terms {
        *tf.entry(term.clone()).or_insert(0.0) += 1.0;
    }

    tf.into_iter()
        .map(|(term, count)| {
            let idf_val = idf.get(&term).copied().unwrap_or(1.0);
            (term, (count / total) * idf_val)
        })
        .collect()
}

fn cosine_similarity(a: &HashMap<String, f64>, b: &HashMap<String, f64>) -> f64 {
    let dot: f64 = a
        .iter()
        .filter_map(|(k, v)| b.get(k).map(|bv| v * bv))
        .sum();
    let mag_a: f64 = a.values().map(|v| v * v).sum::<f64>().sqrt();
    let mag_b: f64 = b.values().map(|v| v * v).sum::<f64>().sqrt();

    if mag_a == 0.0 || mag_b == 0.0 {
        return 0.0;
    }
    dot / (mag_a * mag_b)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tokenize() {
        let tokens = tokenize("Hello, World! This is a test.");
        assert!(tokens.contains(&"hello".to_string()));
        assert!(tokens.contains(&"world".to_string()));
        assert!(tokens.contains(&"this".to_string()));
        assert!(tokens.contains(&"test".to_string()));
        // Short words filtered out
        assert!(!tokens.contains(&"is".to_string()));
    }

    #[test]
    fn test_cosine_same_vector() {
        let v: HashMap<String, f64> = [("a".into(), 1.0), ("b".into(), 2.0)].into();
        let sim = cosine_similarity(&v, &v);
        assert!((sim - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_cosine_orthogonal() {
        let a: HashMap<String, f64> = [("a".into(), 1.0)].into();
        let b: HashMap<String, f64> = [("b".into(), 1.0)].into();
        let sim = cosine_similarity(&a, &b);
        assert!(sim.abs() < 0.001);
    }

    #[test]
    fn test_parse_skill_frontmatter() {
        let content = r#"---
name: "git-commit"
description: "Create a git commit with a message"
triggers: ["commit", "git commit"]
---
# Git Commit
Run `git add . && git commit -m "message"`.
"#;
        let skill = parse_skill(content, Path::new("test.md")).unwrap();
        assert_eq!(skill.name, "git-commit");
        assert_eq!(skill.triggers.len(), 2);
        assert!(skill.body.contains("Git Commit"));
    }

    #[test]
    fn test_parse_skill_heading_only() {
        let content = "# My Skill\nDo something cool.";
        let skill = parse_skill(content, Path::new("my_skill.md")).unwrap();
        assert_eq!(skill.name, "My Skill");
    }

    #[test]
    fn test_router_empty() {
        let router = SkillRouter {
            skills: vec![],
            idf: HashMap::new(),
        };
        assert!(router.route("anything", 5).is_empty());
    }

    #[test]
    fn test_router_trigger_match() {
        let skills = vec![SkillEntry {
            name: "deploy".into(),
            description: "Deploy the app".into(),
            triggers: vec!["deploy".into(), "ship it".into()],
            file_path: "skills/deploy.md".into(),
            body: "Run deploy script".into(),
        }];
        let idf = compute_idf(&skills);
        let router = SkillRouter { skills, idf };

        let matches = router.route("deploy the app to production", 3);
        assert!(!matches.is_empty());
        assert_eq!(matches[0].score, 1.0);
        assert_eq!(matches[0].matched_trigger, Some("deploy".into()));
    }
}
