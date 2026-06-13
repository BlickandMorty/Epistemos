//! Slice 2 persistence: a durable, replayable mutation command log for the
//! knowledge-core. Each KC mutation captures a deterministic `MutationCommand`;
//! appending them to a JSON-lines file and replaying on open reconstructs state
//! — both the in-memory fact mirrors AND the Cozo db, since replay re-runs the
//! live mutation path. See the cutover plan §10.

use std::path::PathBuf;

/// A replayable mutation command. Deterministic (no timestamps / random ids /
/// clock reads), so replaying the recorded sequence on a fresh store reproduces
/// identical state.
#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum MutationCommand {
    IngestDocument {
        page_id: String,
        format: u8,
        text: String,
    },
    InsertBlock {
        page_id: String,
        block_id: String,
        parent_id: Option<String>,
        index: usize,
        content: String,
    },
    MoveBlock {
        page_id: String,
        block_id: String,
        parent_id: Option<String>,
        index: usize,
    },
    DeleteBlock {
        page_id: String,
        block_id: String,
    },
}

/// Append-only durable command log (JSON-lines). Best-effort: a write failure is
/// surfaced to the caller but never panics.
pub struct OpLog {
    path: PathBuf,
}

impl OpLog {
    pub fn new(path: impl Into<PathBuf>) -> Self {
        Self { path: path.into() }
    }

    /// Append one command as a single JSON line.
    pub fn append(&self, command: &MutationCommand) -> std::io::Result<()> {
        use std::io::Write;
        let line = serde_json::to_string(command)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)?;
        writeln!(file, "{line}")
    }

    /// Read every parseable command in recorded order. A missing file yields an
    /// empty log; unparseable lines are skipped (best-effort recovery — a corrupt
    /// tail rolls back to a clean prefix rather than failing the whole replay).
    pub fn read_all(path: impl AsRef<std::path::Path>) -> Vec<MutationCommand> {
        let Ok(contents) = std::fs::read_to_string(path.as_ref()) else {
            return Vec::new();
        };
        contents
            .lines()
            .filter(|line| !line.trim().is_empty())
            .filter_map(|line| serde_json::from_str::<MutationCommand>(line).ok())
            .collect()
    }
}
