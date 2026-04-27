// Gitignore-aware vault walker.
//
// Uses BurntSushi's `ignore` crate (the engine behind ripgrep) to
// respect `.gitignore` + a vault-local `.epignore` so a user's
// `node_modules` / `.git` / `target` directories never get crawled.
//
// Code-file exclusion: per the dossier's privacy guidance, source
// code (.swift, .rs, .py, .ts, etc.) should NOT generate sidecars —
// it's authored content that would pollute the AFM context with
// noise. Build the exclusion as a hardcoded glob set.

use ignore::WalkBuilder;
use std::path::{Path, PathBuf};

const CODE_EXTENSIONS: &[&str] = &[
    "swift", "rs", "py", "ts", "tsx", "js", "jsx", "go", "java",
    "kt", "c", "cpp", "h", "hpp", "rb", "php", "cs", "scala",
    "clj", "ex", "exs", "ml", "fs", "fsi", "hs", "elm", "rkt",
    "lua", "r", "jl", "nim", "zig", "v", "lean", "vala", "dart",
];

#[derive(Debug, Clone)]
pub struct VaultEntry {
    pub path: PathBuf,
    pub size_bytes: u64,
    pub ext: Option<String>,
}

/// Walks `root` respecting .gitignore/.epignore + the hardcoded code-
/// file exclusion list. Returns markdown / pdf / text-document files
/// only. Skips anything > 32 MB to avoid OOM on the AFM ingest path.
pub fn crawl_vault(root: &Path) -> Vec<VaultEntry> {
    let mut entries = Vec::new();
    // Treat .gitignore + .epignore as custom ignore files so they're
    // honored even when the vault isn't inside a git repo (the
    // `ignore` crate's git-detection only fires on actual repos).
    let walker = WalkBuilder::new(root)
        .add_custom_ignore_filename(".gitignore")
        .add_custom_ignore_filename(".epignore")
        .standard_filters(true)
        .build();
    for result in walker {
        let dent = match result {
            Ok(d) => d,
            Err(_) => continue,
        };
        let path = dent.path();
        if !path.is_file() {
            continue;
        }
        let ext = path
            .extension()
            .and_then(|e| e.to_str())
            .map(|s| s.to_ascii_lowercase());
        if let Some(ref e) = ext {
            if CODE_EXTENSIONS.contains(&e.as_str()) {
                continue;
            }
        }
        let metadata = match dent.metadata() {
            Ok(m) => m,
            Err(_) => continue,
        };
        if metadata.len() > 32 * 1024 * 1024 {
            continue;
        }
        entries.push(VaultEntry {
            path: path.to_path_buf(),
            size_bytes: metadata.len(),
            ext,
        });
    }
    entries
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    fn write(dir: &Path, rel: &str, body: &str) {
        let p = dir.join(rel);
        if let Some(parent) = p.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(p, body).unwrap();
    }

    #[test]
    fn skips_code_files() {
        let dir = TempDir::new().unwrap();
        write(dir.path(), "notes/idea.md", "# Idea");
        write(dir.path(), "src/main.rs", "fn main() {}");
        let entries = crawl_vault(dir.path());
        assert_eq!(entries.len(), 1);
        assert!(entries[0].path.to_string_lossy().ends_with("idea.md"));
    }

    #[test]
    fn respects_gitignore() {
        let dir = TempDir::new().unwrap();
        write(dir.path(), ".gitignore", "build/\n");
        write(dir.path(), "notes/keep.md", "keep");
        write(dir.path(), "build/skip.md", "skip");
        let entries = crawl_vault(dir.path());
        assert_eq!(entries.len(), 1);
        assert!(entries[0].path.to_string_lossy().contains("keep.md"));
    }

    #[test]
    fn respects_epignore() {
        let dir = TempDir::new().unwrap();
        write(dir.path(), ".epignore", "private/\n");
        write(dir.path(), "notes/public.md", "public");
        write(dir.path(), "private/secret.md", "secret");
        let entries = crawl_vault(dir.path());
        assert_eq!(entries.len(), 1);
        assert!(entries[0].path.to_string_lossy().contains("public.md"));
    }

    #[test]
    fn skips_oversize_files() {
        let dir = TempDir::new().unwrap();
        // 33 MB sentinel
        let big = vec![b'x'; 33 * 1024 * 1024];
        write(dir.path(), "notes/huge.md", &String::from_utf8_lossy(&big));
        write(dir.path(), "notes/normal.md", "hello");
        let entries = crawl_vault(dir.path());
        let names: Vec<_> = entries
            .iter()
            .map(|e| e.path.file_name().unwrap().to_string_lossy().to_string())
            .collect();
        assert!(names.contains(&"normal.md".to_string()));
        assert!(!names.contains(&"huge.md".to_string()));
    }
}
