pub mod archived;
pub mod crdt;
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
            Self::Ring(RingError::InvalidCapacity) => "invalid shared-memory ring capacity".to_string(),
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

    pub fn set_last_error(
        &mut self,
        code: KnowledgeCoreErrorCode,
        message: impl Into<String>,
    ) {
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

    pub fn subscribe_tasks(
        &mut self,
        page_id: Option<&str>,
    ) -> Result<u64, KnowledgeCoreError> {
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
        let diffs = self
            .store
            .move_block(page_id, block_id, Some(&placement.parent_id), &placement.order_key)?;
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
        self.publish_diffs(diffs)
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
            self.outlines.insert(
                page_id.to_string(),
                OutlineCrdt::new(self.peer_id, 1)?,
            );
        }
        Ok(self
            .outlines
            .get_mut(page_id)
            .expect("outline must exist after insertion"))
    }
}
