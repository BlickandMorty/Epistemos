pub mod archived;
pub mod crdt;
pub mod oplog;
pub mod parser;
pub mod ring;
pub mod store;

use std::collections::HashMap;

pub use parser::DocumentFormat;
pub use ring::{DEFAULT_SLOT_COUNT, DEFAULT_SLOT_PAYLOAD_BYTES, RingLayout, SharedRegionView};

use self::archived::QueryDiffEnvelope;
use self::crdt::{OutlineCrdt, OutlineError};
use self::parser::{NormalizedBlock, parse_document};
use self::ring::{RingError, SharedRingBuffer};
use self::oplog::{MutationCommand, OpLog};
use self::store::{DatalogStore, StoreError, SubscriptionSpec};

#[repr(u8)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum KnowledgeCoreErrorCode {
    #[default]
    None = 0,
    InvalidArgument = 1,
    RingFull = 2,
    RingPayloadTooLarge = 3,
    Ring = 4,
    MissingBlock = 5,
    MissingNode = 6,
    Store = 7,
    Outline = 8,
    Serialization = 9,
}

#[repr(u8)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum KnowledgeCoreBackpressurePolicy {
    #[default]
    FailFast = 0,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct KnowledgeCoreTransportStats {
    pub published_frames: u64,
    pub dropped_frames: u64,
    pub coalesced_frames: u64,
    pub ring_full_failures: u64,
}

#[derive(Debug)]
pub enum KnowledgeCoreError {
    Ring(RingError),
    Store(StoreError),
    Outline(OutlineError),
    Serialization(String),
}

impl KnowledgeCoreError {
    fn code(&self) -> KnowledgeCoreErrorCode {
        match self {
            Self::Ring(RingError::Full) => KnowledgeCoreErrorCode::RingFull,
            Self::Ring(RingError::PayloadTooLarge { .. }) => {
                KnowledgeCoreErrorCode::RingPayloadTooLarge
            }
            Self::Ring(_) => KnowledgeCoreErrorCode::Ring,
            Self::Store(StoreError::MissingBlock(_)) => KnowledgeCoreErrorCode::MissingBlock,
            Self::Store(_) => KnowledgeCoreErrorCode::Store,
            Self::Outline(OutlineError::MissingNode(_)) => KnowledgeCoreErrorCode::MissingNode,
            Self::Outline(_) => KnowledgeCoreErrorCode::Outline,
            Self::Serialization(_) => KnowledgeCoreErrorCode::Serialization,
        }
    }

    fn message(&self) -> String {
        match self {
            Self::Ring(RingError::MapFailed) => "shared-memory map failed".to_string(),
            Self::Ring(RingError::InvalidCapacity) => {
                "invalid shared-memory ring capacity".to_string()
            }
            Self::Ring(RingError::PayloadTooLarge { len, max }) => {
                format!("archived payload of {len} bytes exceeds slot capacity {max}")
            }
            Self::Ring(RingError::Full) => "shared-memory ring is full".to_string(),
            Self::Ring(RingError::Serialization(message)) => {
                format!("ring serialization failed: {message}")
            }
            Self::Store(StoreError::Query(message)) => format!("store query failed: {message}"),
            Self::Store(StoreError::MissingBlock(block_id)) => {
                format!("missing block: {block_id}")
            }
            Self::Outline(OutlineError::Loro(message)) => {
                format!("outline operation failed: {message}")
            }
            Self::Outline(OutlineError::MissingNode(block_id)) => {
                format!("missing outline node: {block_id}")
            }
            Self::Serialization(message) => format!("serialization failed: {message}"),
        }
    }
}

impl From<RingError> for KnowledgeCoreError {
    fn from(value: RingError) -> Self {
        Self::Ring(value)
    }
}

impl From<StoreError> for KnowledgeCoreError {
    fn from(value: StoreError) -> Self {
        Self::Store(value)
    }
}

impl From<OutlineError> for KnowledgeCoreError {
    fn from(value: OutlineError) -> Self {
        Self::Outline(value)
    }
}

pub struct KnowledgeCore {
    ring: SharedRingBuffer,
    store: DatalogStore,
    outlines: HashMap<String, OutlineCrdt>,
    peer_id: u64,
    backpressure_policy: KnowledgeCoreBackpressurePolicy,
    transport_stats: KnowledgeCoreTransportStats,
    last_error_code: KnowledgeCoreErrorCode,
    last_error_message: String,
    oplog: Option<OpLog>,
}

impl KnowledgeCore {
    pub fn new(
        slot_count: usize,
        slot_payload_bytes: usize,
        peer_id: u64,
    ) -> Result<Self, KnowledgeCoreError> {
        let ring = SharedRingBuffer::new(
            if slot_count == 0 {
                DEFAULT_SLOT_COUNT
            } else {
                slot_count
            },
            if slot_payload_bytes == 0 {
                DEFAULT_SLOT_PAYLOAD_BYTES
            } else {
                slot_payload_bytes
            },
        )?;
        Ok(Self {
            ring,
            store: DatalogStore::new(),
            outlines: HashMap::new(),
            peer_id,
            backpressure_policy: KnowledgeCoreBackpressurePolicy::FailFast,
            transport_stats: KnowledgeCoreTransportStats::default(),
            last_error_code: KnowledgeCoreErrorCode::None,
            last_error_message: String::new(),
            oplog: None,
        })
    }

    pub fn shared_region(&self) -> SharedRegionView {
        self.ring.shared_region()
    }

    pub fn ring_layout(&self) -> RingLayout {
        self.ring.layout()
    }

    pub fn load_head(&self) -> u64 {
        self.ring.load_head()
    }

    pub fn load_tail(&self) -> u64 {
        self.ring.load_tail()
    }

    pub fn store_tail(&self, tail: u64) {
        self.ring.store_tail(tail);
    }

    pub fn backpressure_policy(&self) -> KnowledgeCoreBackpressurePolicy {
        self.backpressure_policy
    }

    pub fn transport_stats(&self) -> KnowledgeCoreTransportStats {
        self.transport_stats
    }

    pub fn clear_last_error(&mut self) {
        self.last_error_code = KnowledgeCoreErrorCode::None;
        self.last_error_message.clear();
    }

    pub fn set_last_error(&mut self, code: KnowledgeCoreErrorCode, message: impl Into<String>) {
        self.last_error_code = code;
        self.last_error_message = message.into();
    }

    pub fn set_last_error_from(&mut self, error: &KnowledgeCoreError) {
        self.last_error_code = error.code();
        self.last_error_message = error.message();
    }

    pub fn last_error_code(&self) -> u8 {
        self.last_error_code as u8
    }

    pub fn last_error_message(&self) -> &str {
        &self.last_error_message
    }

    pub fn subscribe_outline(&mut self, page_id: &str) -> Result<u64, KnowledgeCoreError> {
        self.subscribe(SubscriptionSpec::Outline {
            page_id: page_id.to_string(),
        })
    }

    pub fn subscribe_tasks(&mut self, page_id: Option<&str>) -> Result<u64, KnowledgeCoreError> {
        self.subscribe(SubscriptionSpec::Tasks {
            page_id: page_id.map(std::string::ToString::to_string),
        })
    }

    pub fn subscribe_properties(
        &mut self,
        page_id: Option<&str>,
        key: Option<&str>,
    ) -> Result<u64, KnowledgeCoreError> {
        self.subscribe(SubscriptionSpec::Properties {
            page_id: page_id.map(std::string::ToString::to_string),
            key: key.map(std::string::ToString::to_string),
        })
    }

    pub fn unsubscribe(&mut self, subscription_id: u64) -> bool {
        self.store.unsubscribe(subscription_id)
    }

    pub fn ingest_document(
        &mut self,
        page_id: &str,
        format: DocumentFormat,
        text: &str,
    ) -> Result<(), KnowledgeCoreError> {
        let document = parse_document(page_id, format, text);
        let diffs = self.store.replace_page(document)?;
        self.log_command(&MutationCommand::IngestDocument {
            page_id: page_id.to_string(),
            format: format as u8,
            text: text.to_string(),
        });
        self.publish_diffs(diffs)
    }

    pub fn insert_block(
        &mut self,
        page_id: &str,
        block_id: &str,
        parent_id: Option<&str>,
        index: usize,
        content: &str,
    ) -> Result<(), KnowledgeCoreError> {
        let outline = self.outline_mut(page_id)?;
        let placement = outline.insert_block(block_id, parent_id, index)?;
        let parsed = parse_document(page_id, DocumentFormat::Markdown, content);
        let Some(parsed_block) = parsed.blocks.first().cloned() else {
            return Ok(());
        };
        let block = NormalizedBlock {
            page_id: page_id.to_string(),
            block_id: block_id.to_string(),
            parent_id: placement.parent_id.clone(),
            order_key: placement.order_key,
            depth: parent_id.map_or(0, |_| 1),
            content: parsed_block.content.clone(),
        };
        let task = parsed.tasks.first().cloned().map(|mut task| {
            task.block_id = block_id.to_string();
            task
        });
        let properties = parsed
            .properties
            .into_iter()
            .map(|mut property| {
                property.block_id = block_id.to_string();
                property
            })
            .collect::<Vec<_>>();
        let links = parsed
            .links
            .into_iter()
            .map(|mut link| {
                link.block_id = block_id.to_string();
                link
            })
            .collect::<Vec<_>>();
        let diffs = self.store.upsert_block(block, task, properties, links)?;
        self.log_command(&MutationCommand::InsertBlock {
            page_id: page_id.to_string(),
            block_id: block_id.to_string(),
            parent_id: parent_id.map(str::to_string),
            index,
            content: content.to_string(),
        });
        self.publish_diffs(diffs)
    }

    pub fn move_block(
        &mut self,
        page_id: &str,
        block_id: &str,
        parent_id: Option<&str>,
        index: usize,
    ) -> Result<(), KnowledgeCoreError> {
        let outline = self.outline_mut(page_id)?;
        let placement = outline.move_block(block_id, parent_id, index)?;
        let diffs = self.store.move_block(
            page_id,
            block_id,
            Some(&placement.parent_id),
            &placement.order_key,
        )?;
        self.log_command(&MutationCommand::MoveBlock {
            page_id: page_id.to_string(),
            block_id: block_id.to_string(),
            parent_id: parent_id.map(str::to_string),
            index,
        });
        self.publish_diffs(diffs)
    }

    pub fn delete_block(
        &mut self,
        page_id: &str,
        block_id: &str,
    ) -> Result<(), KnowledgeCoreError> {
        let outline = self.outline_mut(page_id)?;
        outline.delete_block(block_id)?;
        let diffs = self.store.delete_block(page_id, block_id)?;
        self.log_command(&MutationCommand::DeleteBlock {
            page_id: page_id.to_string(),
            block_id: block_id.to_string(),
        });
        self.publish_diffs(diffs)
    }

    // MARK: - Slice 2 persistence (replay log)

    /// Enable durable command logging to `path` (append mode). Call AFTER any
    /// replay so the replay itself is not re-logged. Flag-gated at the call site.
    pub fn enable_oplog(&mut self, path: impl Into<std::path::PathBuf>) {
        self.oplog = Some(OpLog::new(path));
    }

    /// Rebuild state by replaying a command-log file with logging disabled.
    /// Missing/corrupt logs roll back to a clean prefix (best-effort). Returns
    /// the number of commands applied.
    pub fn replay_from_oplog(&mut self, path: impl AsRef<std::path::Path>) -> usize {
        let mut applied = 0usize;
        for command in OpLog::read_all(path) {
            if self.apply_command(&command).is_ok() {
                applied += 1;
            }
        }
        applied
    }

    /// Compact the durable oplog in place to its minimal state-equivalent form,
    /// dropping commands a later full-page ingest superseded. Bounds long-run log
    /// growth from per-edit re-ingests (N edits of one page collapse to one
    /// ingest). No-op unless persistence is enabled and the log actually shrinks;
    /// the rewrite is atomic (temp + rename). Returns (before, after) counts.
    pub fn compact_oplog(&mut self) -> (usize, usize) {
        let Some(path) = self.oplog.as_ref().map(|oplog| oplog.path().to_path_buf()) else {
            return (0, 0);
        };
        let original = OpLog::read_all(&path);
        let compacted = OpLog::compact(&original);
        if compacted.len() < original.len() {
            if let Err(error) = OpLog::new(&path).rewrite(&compacted) {
                self.last_error_message =
                    format!("knowledge-core oplog compaction failed: {error}");
                return (original.len(), original.len());
            }
        }
        (original.len(), compacted.len())
    }

    /// Re-apply a logged command (replay path). Dispatches to the live mutation
    /// methods; does not itself log (oplog must be None during replay).
    pub fn apply_command(&mut self, command: &MutationCommand) -> Result<(), KnowledgeCoreError> {
        match command {
            MutationCommand::IngestDocument {
                page_id,
                format,
                text,
            } => {
                let fmt = DocumentFormat::from_ffi(*format).unwrap_or(DocumentFormat::Markdown);
                self.ingest_document(page_id, fmt, text)
            }
            MutationCommand::InsertBlock {
                page_id,
                block_id,
                parent_id,
                index,
                content,
            } => self.insert_block(page_id, block_id, parent_id.as_deref(), *index, content),
            MutationCommand::MoveBlock {
                page_id,
                block_id,
                parent_id,
                index,
            } => self.move_block(page_id, block_id, parent_id.as_deref(), *index),
            MutationCommand::DeleteBlock { page_id, block_id } => {
                self.delete_block(page_id, block_id)
            }
        }
    }

    fn log_command(&mut self, command: &MutationCommand) {
        if let Some(oplog) = &self.oplog {
            if let Err(error) = oplog.append(command) {
                self.last_error_message = format!("knowledge-core oplog append failed: {error}");
            }
        }
    }

    /// (blocks, tasks, properties, links) fact counts — for replay-parity tests.
    pub fn fact_counts(&self) -> (usize, usize, usize, usize) {
        self.store.fact_counts()
    }

    fn subscribe(&mut self, spec: SubscriptionSpec) -> Result<u64, KnowledgeCoreError> {
        let (subscription_id, initial) = self.store.subscribe(spec)?;
        self.publish_diff(&initial)?;
        Ok(subscription_id)
    }

    fn publish_diffs(&mut self, diffs: Vec<QueryDiffEnvelope>) -> Result<(), KnowledgeCoreError> {
        for diff in diffs {
            self.publish_diff(&diff)?;
        }
        Ok(())
    }

    fn publish_diff(&mut self, diff: &QueryDiffEnvelope) -> Result<(), KnowledgeCoreError> {
        match self
            .ring
            .write_archived_frame(diff.kind.code(), diff.tx_id, diff)
        {
            Ok(()) => {
                self.transport_stats.published_frames =
                    self.transport_stats.published_frames.saturating_add(1);
                Ok(())
            }
            Err(RingError::Full) => {
                self.transport_stats.ring_full_failures =
                    self.transport_stats.ring_full_failures.saturating_add(1);
                match self.backpressure_policy {
                    KnowledgeCoreBackpressurePolicy::FailFast => {
                        Err(KnowledgeCoreError::Ring(RingError::Full))
                    }
                }
            }
            Err(error) => Err(error.into()),
        }
    }

    fn outline_mut(&mut self, page_id: &str) -> Result<&mut OutlineCrdt, KnowledgeCoreError> {
        if !self.outlines.contains_key(page_id) {
            self.outlines
                .insert(page_id.to_string(), OutlineCrdt::new(self.peer_id, 1)?);
        }
        Ok(self
            .outlines
            .get_mut(page_id)
            .expect("outline must exist after insertion"))
    }
}

#[cfg(test)]
mod oplog_tests {
    use super::*;

    #[test]
    fn oplog_replay_reconstructs_fact_state() {
        let path = std::env::temp_dir()
            .join(format!("epistemos_kc_oplog_{}.jsonl", std::process::id()));
        let _ = std::fs::remove_file(&path);

        // Original session: enable the durable oplog, apply mutations (auto-logged).
        let original_counts = {
            let mut kc = KnowledgeCore::new(0, 0, 1).expect("kc");
            kc.enable_oplog(path.clone());
            kc.ingest_document("p1", DocumentFormat::Markdown, "- [ ] A [[link]]\n- B")
                .expect("ingest p1");
            kc.ingest_document("p2", DocumentFormat::Markdown, "- C")
                .expect("ingest p2");
            kc.fact_counts()
        };
        assert!(original_counts.0 > 0, "expected non-trivial block state");

        // Restart: a fresh KC replays the durable log → identical fact state.
        let mut restored = KnowledgeCore::new(0, 0, 2).expect("kc");
        let applied = restored.replay_from_oplog(&path);
        assert_eq!(applied, 2, "two ingest commands replayed");
        assert_eq!(restored.fact_counts(), original_counts);

        // Missing/corrupt log → clean empty state (rollback), no panic.
        let mut empty = KnowledgeCore::new(0, 0, 3).expect("kc");
        let applied_none =
            empty.replay_from_oplog(std::env::temp_dir().join("epistemos-kc-nope.jsonl"));
        assert_eq!(applied_none, 0);
        assert_eq!(empty.fact_counts(), (0, 0, 0, 0));

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn oplog_compaction_collapses_edits_but_preserves_state() {
        let path = std::env::temp_dir()
            .join(format!("epistemos_kc_compact_int_{}.jsonl", std::process::id()));
        let _ = std::fs::remove_file(&path);

        // Original session: "edit" p1 three times (each re-ingest replaces the
        // page) plus a separate page p2 — exactly the per-edit re-ingest pattern.
        let (final_counts, before, after) = {
            let mut kc = KnowledgeCore::new(0, 0, 1).expect("kc");
            kc.enable_oplog(path.clone());
            kc.ingest_document("p1", DocumentFormat::Markdown, "- one")
                .expect("p1 v1");
            kc.ingest_document("p1", DocumentFormat::Markdown, "- one\n- two")
                .expect("p1 v2");
            kc.ingest_document("p1", DocumentFormat::Markdown, "- final")
                .expect("p1 v3");
            kc.ingest_document("p2", DocumentFormat::Markdown, "- C")
                .expect("p2");
            let counts = kc.fact_counts();
            let (before, after) = kc.compact_oplog();
            (counts, before, after)
        };

        assert_eq!(before, 4, "four ingests recorded");
        assert_eq!(after, 2, "three p1 edits collapse to one, plus p2");

        // Restart from the COMPACTED log → identical fact state.
        let mut restored = KnowledgeCore::new(0, 0, 2).expect("kc");
        let applied = restored.replay_from_oplog(&path);
        assert_eq!(applied, 2);
        assert_eq!(restored.fact_counts(), final_counts);

        let _ = std::fs::remove_file(&path);
    }
}
