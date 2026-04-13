use std::path::{Path, PathBuf};

use git2::{DiffFormat, Oid, Signature};
use serde::{Deserialize, Serialize};

use crate::storage::diff_engine::{apply_text_patch, DiffError, UnifiedDiff};
use crate::storage::memory_classifier::MemoryOperation;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CommitInfo {
    pub oid: String,
    pub message: String,
    pub timestamp: i64,
}

pub struct VaultGit {
    repo: git2::Repository,
    vault_root: PathBuf,
}

#[derive(Debug, thiserror::Error)]
pub enum VaultGitError {
    #[error("git error: {0}")]
    Git(#[from] git2::Error),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("diff application error: {0}")]
    Diff(#[from] DiffError),
    #[error("path is outside the vault root: {0}")]
    PathOutsideVault(PathBuf),
    #[error("no diffs provided for commit")]
    NoDiffs,
}

impl VaultGit {
    pub fn open(vault_root: &Path) -> Result<Self, VaultGitError> {
        std::fs::create_dir_all(vault_root)?;
        let repo =
            git2::Repository::open(vault_root).or_else(|_| git2::Repository::init(vault_root))?;
        Ok(Self {
            repo,
            vault_root: vault_root.to_path_buf(),
        })
    }

    pub fn commit_diffs(
        &self,
        diffs: &[(PathBuf, UnifiedDiff)],
        message: &str,
        operation: MemoryOperation,
    ) -> Result<Oid, VaultGitError> {
        if diffs.is_empty() {
            return Err(VaultGitError::NoDiffs);
        }

        let mut originals = Vec::with_capacity(diffs.len());
        let mut applied_paths = Vec::with_capacity(diffs.len());
        for (path, diff) in diffs {
            let absolute_path = self.absolute_path(path)?;
            let original = std::fs::read_to_string(&absolute_path).unwrap_or_default();
            let updated = match apply_text_patch(&original, diff) {
                Ok(updated) => updated,
                Err(error) => {
                    rollback_files(&originals)?;
                    return Err(VaultGitError::Diff(error));
                }
            };

            originals.push((absolute_path.clone(), original));
            if let Some(parent) = absolute_path.parent() {
                std::fs::create_dir_all(parent)?;
            }
            if updated.is_empty() {
                if absolute_path.exists() {
                    std::fs::remove_file(&absolute_path)?;
                }
            } else {
                std::fs::write(&absolute_path, updated)?;
            }
            applied_paths.push(absolute_path);
        }

        let mut index = self.repo.index()?;
        for path in &applied_paths {
            let relative_path = self.relative_path(path)?;
            if path.exists() {
                index.add_path(&relative_path)?;
            } else {
                index.remove_path(&relative_path)?;
            }
        }
        index.write()?;

        let tree_id = index.write_tree()?;
        let tree = self.repo.find_tree(tree_id)?;
        let signature = self.signature()?;
        let commit_message = self.format_commit_message(diffs, message, &operation)?;
        let oid = if let Ok(head) = self.repo.head() {
            if let Some(parent_oid) = head.target() {
                let parent = self.repo.find_commit(parent_oid)?;
                self.repo.commit(
                    Some("HEAD"),
                    &signature,
                    &signature,
                    &commit_message,
                    &tree,
                    &[&parent],
                )?
            } else {
                self.repo.commit(
                    Some("HEAD"),
                    &signature,
                    &signature,
                    &commit_message,
                    &tree,
                    &[],
                )?
            }
        } else {
            self.repo.commit(
                Some("HEAD"),
                &signature,
                &signature,
                &commit_message,
                &tree,
                &[],
            )?
        };

        Ok(oid)
    }

    pub fn history(
        &self,
        file_path: &Path,
        limit: usize,
    ) -> Result<Vec<CommitInfo>, VaultGitError> {
        let relative_path = self.relative_path(&self.absolute_path(file_path)?)?;
        let mut revwalk = self.repo.revwalk()?;
        revwalk.push_head()?;
        let mut commits = Vec::new();

        for oid in revwalk {
            let oid = oid?;
            let commit = self.repo.find_commit(oid)?;
            if !self.commit_touches_path(&commit, &relative_path)? {
                continue;
            }

            commits.push(CommitInfo {
                oid: oid.to_string(),
                message: commit.message().unwrap_or_default().to_string(),
                timestamp: commit.time().seconds(),
            });

            if commits.len() >= limit {
                break;
            }
        }

        Ok(commits)
    }

    pub fn diff_between(&self, old_commit: Oid, new_commit: Oid) -> Result<String, VaultGitError> {
        let old_commit = self.repo.find_commit(old_commit)?;
        let new_commit = self.repo.find_commit(new_commit)?;
        let old_tree = old_commit.tree()?;
        let new_tree = new_commit.tree()?;
        let diff = self
            .repo
            .diff_tree_to_tree(Some(&old_tree), Some(&new_tree), None)?;
        let mut rendered = String::new();
        diff.print(DiffFormat::Patch, |_delta, _hunk, line| {
            rendered.push_str(std::str::from_utf8(line.content()).unwrap_or_default());
            true
        })?;
        Ok(rendered)
    }

    fn absolute_path(&self, path: &Path) -> Result<PathBuf, VaultGitError> {
        let absolute = if path.is_absolute() {
            path.to_path_buf()
        } else {
            self.vault_root.join(path)
        };
        if absolute.starts_with(&self.vault_root) {
            Ok(absolute)
        } else {
            Err(VaultGitError::PathOutsideVault(path.to_path_buf()))
        }
    }

    fn relative_path(&self, path: &Path) -> Result<PathBuf, VaultGitError> {
        path.strip_prefix(&self.vault_root)
            .map(Path::to_path_buf)
            .map_err(|_| VaultGitError::PathOutsideVault(path.to_path_buf()))
    }

    fn signature(&self) -> Result<Signature<'_>, VaultGitError> {
        self.repo
            .signature()
            .or_else(|_| Signature::now("Epistemos Omega", "omega@epistemos.local"))
            .map_err(VaultGitError::from)
    }

    fn format_commit_message(
        &self,
        diffs: &[(PathBuf, UnifiedDiff)],
        message: &str,
        operation: &MemoryOperation,
    ) -> Result<String, VaultGitError> {
        let first_path = self.relative_path(&self.absolute_path(&diffs[0].0)?)?;
        let summary = message
            .lines()
            .find(|line| {
                !line.trim().is_empty()
                    && !line.trim_start().starts_with("source:")
                    && !line.trim_start().starts_with("strength:")
            })
            .map(str::trim)
            .unwrap_or("vault mutation");
        let source = message
            .lines()
            .find_map(|line| line.trim().strip_prefix("source:").map(str::trim))
            .unwrap_or("operator");
        let strength = message
            .lines()
            .find_map(|line| line.trim().strip_prefix("strength:").map(str::trim))
            .unwrap_or("1.00");
        Ok(format!(
            "[MEMORY:{operation}] {}\n  - {summary}\n  - source: {source}\n  - strength: {strength}",
            first_path.display()
        ))
    }

    fn commit_touches_path(
        &self,
        commit: &git2::Commit<'_>,
        relative_path: &Path,
    ) -> Result<bool, VaultGitError> {
        let tree = commit.tree()?;
        if commit.parent_count() == 0 {
            return Ok(tree.get_path(relative_path).is_ok());
        }

        let parent = commit.parent(0)?;
        let parent_tree = parent.tree()?;
        let diff = self
            .repo
            .diff_tree_to_tree(Some(&parent_tree), Some(&tree), None)?;

        for delta in diff.deltas() {
            if delta.new_file().path() == Some(relative_path)
                || delta.old_file().path() == Some(relative_path)
            {
                return Ok(true);
            }
        }

        Ok(false)
    }
}

fn rollback_files(originals: &[(PathBuf, String)]) -> Result<(), std::io::Error> {
    for (path, content) in originals {
        if content.is_empty() {
            if path.exists() {
                std::fs::remove_file(path)?;
            }
        } else {
            if let Some(parent) = path.parent() {
                std::fs::create_dir_all(parent)?;
            }
            std::fs::write(path, content)?;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::diff_engine::generate_text_diff;
    use uuid::Uuid;

    fn temp_repo_root() -> PathBuf {
        let root = std::env::temp_dir().join(format!("epistemos-vault-git-{}", Uuid::new_v4()));
        std::fs::create_dir_all(&root).unwrap();
        root
    }

    #[test]
    fn vault_git_commits_diffs_and_returns_history() {
        let root = temp_repo_root();
        let file_path = root.join("pricing.md");
        std::fs::write(&file_path, "Claude costs $15 per month.\n").unwrap();
        let git = VaultGit::open(&root).unwrap();

        let oid = git
            .commit_diffs(
                &[(
                    file_path.clone(),
                    generate_text_diff(
                        "Claude costs $15 per month.\n",
                        "Claude costs $20 per month.\n",
                    ),
                )],
                "Updated provider pricing",
                MemoryOperation::Update {
                    target_file: "pricing.md".to_string(),
                    target_section: "pricing".to_string(),
                },
            )
            .unwrap();

        let history = git.history(&file_path, 5).unwrap();

        assert!(!oid.is_zero());
        assert_eq!(history.len(), 1);
        assert!(history[0].message.contains("[MEMORY:UPDATE]"));

        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn vault_git_diff_between_commits_shows_patch() {
        let root = temp_repo_root();
        let file_path = root.join("pricing.md");
        let git = VaultGit::open(&root).unwrap();

        let first = git
            .commit_diffs(
                &[(
                    file_path.clone(),
                    generate_text_diff("", "Claude costs $15 per month.\n"),
                )],
                "Seed pricing memory",
                MemoryOperation::Add,
            )
            .unwrap();
        let second = git
            .commit_diffs(
                &[(
                    file_path.clone(),
                    generate_text_diff(
                        "Claude costs $15 per month.\n",
                        "Claude costs $20 per month.\n",
                    ),
                )],
                "Raise pricing memory",
                MemoryOperation::Update {
                    target_file: "pricing.md".to_string(),
                    target_section: "pricing".to_string(),
                },
            )
            .unwrap();

        let diff = git.diff_between(first, second).unwrap();

        assert!(diff.contains("Claude costs $20 per month."));
        assert!(diff.contains("Claude costs $15 per month."));

        std::fs::remove_dir_all(root).unwrap();
    }
}
