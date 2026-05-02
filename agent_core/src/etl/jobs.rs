use serde::{Deserialize, Serialize};
use std::path::PathBuf;

use super::{hash::fingerprint, walker::VaultEntry};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EtlInputKind {
    Markdown,
    Pdf,
    PlainText,
}

impl EtlInputKind {
    pub fn from_extension(ext: Option<&str>) -> Option<Self> {
        match ext.map(str::to_ascii_lowercase).as_deref() {
            Some("md" | "markdown") => Some(Self::Markdown),
            Some("pdf") => Some(Self::Pdf),
            Some("txt" | "text") => Some(Self::PlainText),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EtlIngestJob {
    pub path: PathBuf,
    pub size_bytes: u64,
    pub fingerprint: u64,
    pub kind: EtlInputKind,
}

impl EtlIngestJob {
    pub fn from_entry(entry: &VaultEntry, content: &[u8]) -> Option<Self> {
        let kind = EtlInputKind::from_extension(entry.ext.as_deref())?;
        let path_string = entry.path.to_string_lossy();
        Some(Self {
            path: entry.path.clone(),
            size_bytes: entry.size_bytes,
            fingerprint: fingerprint(path_string.as_bytes(), content),
            kind,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classifies_supported_inputs() {
        assert_eq!(
            EtlInputKind::from_extension(Some("md")),
            Some(EtlInputKind::Markdown)
        );
        assert_eq!(
            EtlInputKind::from_extension(Some("MARKDOWN")),
            Some(EtlInputKind::Markdown)
        );
        assert_eq!(
            EtlInputKind::from_extension(Some("pdf")),
            Some(EtlInputKind::Pdf)
        );
        assert_eq!(
            EtlInputKind::from_extension(Some("txt")),
            Some(EtlInputKind::PlainText)
        );
    }

    #[test]
    fn rejects_unsupported_inputs() {
        assert_eq!(EtlInputKind::from_extension(Some("rs")), None);
        assert_eq!(EtlInputKind::from_extension(None), None);
    }

    #[test]
    fn builds_fingerprint_from_entry_path_and_content() {
        let entry = VaultEntry {
            path: PathBuf::from("notes/idea.md"),
            size_bytes: 12,
            ext: Some("md".to_string()),
        };
        let Some(job) = EtlIngestJob::from_entry(&entry, b"hello") else {
            panic!("markdown should be supported");
        };
        let moved = VaultEntry {
            path: PathBuf::from("notes/moved.md"),
            ..entry
        };
        let Some(moved_job) = EtlIngestJob::from_entry(&moved, b"hello") else {
            panic!("markdown should be supported");
        };

        assert_eq!(job.kind, EtlInputKind::Markdown);
        assert_ne!(job.fingerprint, moved_job.fingerprint);
    }
}
