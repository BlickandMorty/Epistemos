use std::collections::{BTreeMap, BTreeSet, HashMap};

use cozo::{DataValue, DbInstance, NamedRows, ScriptMutability};

use super::archived::{
    BlockRow, LinkRow, PropertyRow, QueryDiffEnvelope, QueryRow, SubscriptionKind, TaskRow,
};
use super::parser::{
    NormalizedBlock, NormalizedDocument, NormalizedLink, NormalizedProperty, NormalizedTask,
};

#[derive(Debug)]
pub enum StoreError {
    Query(String),
    MissingBlock(String),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
enum RelationKind {
    Blocks,
    Links,
    Tasks,
    Properties,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum MutationRelationKind {
    Blocks,
    Links,
    Tasks,
    Properties,
}

impl From<RelationKind> for MutationRelationKind {
    fn from(value: RelationKind) -> Self {
        match value {
            RelationKind::Blocks => Self::Blocks,
            RelationKind::Links => Self::Links,
            RelationKind::Tasks => Self::Tasks,
            RelationKind::Properties => Self::Properties,
        }
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum MutationOperationKind {
    #[default]
    Unknown,
    DocumentIngest,
    InsertBlock,
    EditBlock,
    MoveBlock,
    DeleteBlock,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MutationEnvelope {
    pub tx_id: u64,
    pub touched_artifact_ids: Vec<String>,
    pub touched_block_ids: Vec<String>,
    pub touched_relation_kinds: Vec<MutationRelationKind>,
    pub affects_summary: bool,
    pub affects_outline: bool,
    pub affects_backlinks: bool,
    pub affects_search: bool,
    pub affects_graph: bool,
    pub affects_body: bool,
    pub affects_ordering: bool,
    pub source_operation_kind: MutationOperationKind,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum QueryClass {
    Outline,
    Tasks,
    Properties,
    Links,
    Unsupported,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct QueryFingerprint {
    pub query_class: QueryClass,
    pub normalized_key: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum WatchClass {
    Summary,
    Outline,
    Backlinks,
    Search,
    Graph,
    Body,
    Ordering,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WatchPlan {
    pub subscription_id: u64,
    pub query_fingerprint: QueryFingerprint,
    pub watched_artifact_ids: Vec<String>,
    pub watched_block_ids: Vec<String>,
    pub watched_relation_kinds: Vec<MutationRelationKind>,
    pub watched_classes: Vec<WatchClass>,
    pub fallback_to_full_invalidation: bool,
}

impl WatchPlan {
    pub fn unsupported(subscription_id: u64, normalized_key: impl Into<String>) -> Self {
        Self {
            subscription_id,
            query_fingerprint: QueryFingerprint {
                query_class: QueryClass::Unsupported,
                normalized_key: normalized_key.into(),
            },
            watched_artifact_ids: Vec::new(),
            watched_block_ids: Vec::new(),
            watched_relation_kinds: Vec::new(),
            watched_classes: Vec::new(),
            fallback_to_full_invalidation: true,
        }
    }
}

pub fn mutation_intersects_watch_plan(mutation: &MutationEnvelope, watch_plan: &WatchPlan) -> bool {
    if watch_plan.fallback_to_full_invalidation {
        return true;
    }

    let has_artifact_scope = !watch_plan.watched_artifact_ids.is_empty();
    let has_block_scope = !watch_plan.watched_block_ids.is_empty();
    let artifact_overlap = has_artifact_scope
        && mutation.touched_artifact_ids.iter().any(|artifact_id| {
            watch_plan
                .watched_artifact_ids
                .iter()
                .any(|watched| watched == artifact_id)
        });
    let block_overlap = has_block_scope
        && mutation.touched_block_ids.iter().any(|block_id| {
            watch_plan
                .watched_block_ids
                .iter()
                .any(|watched| watched == block_id)
        });
    let id_overlap = artifact_overlap || block_overlap;
    if (has_artifact_scope || has_block_scope) && !id_overlap {
        return false;
    }

    let relation_overlap = mutation
        .touched_relation_kinds
        .iter()
        .any(|relation| watch_plan.watched_relation_kinds.contains(relation));
    let class_overlap = watch_plan
        .watched_classes
        .iter()
        .any(|watch_class| mutation_affects_class(mutation, *watch_class));

    relation_overlap || class_overlap
}

fn mutation_affects_class(mutation: &MutationEnvelope, watch_class: WatchClass) -> bool {
    match watch_class {
        WatchClass::Summary => mutation.affects_summary,
        WatchClass::Outline => mutation.affects_outline,
        WatchClass::Backlinks => mutation.affects_backlinks,
        WatchClass::Search => mutation.affects_search,
        WatchClass::Graph => mutation.affects_graph,
        WatchClass::Body => mutation.affects_body,
        WatchClass::Ordering => mutation.affects_ordering,
    }
}

#[derive(Clone, Debug)]
pub enum SubscriptionSpec {
    Outline {
        page_id: String,
    },
    Tasks {
        page_id: Option<String>,
    },
    Properties {
        page_id: Option<String>,
        key: Option<String>,
    },
    Links {
        page_id: Option<String>,
        block_id: Option<String>,
    },
}

impl SubscriptionSpec {
    fn kind(&self) -> SubscriptionKind {
        match self {
            Self::Outline { .. } => SubscriptionKind::Outline,
            Self::Tasks { .. } => SubscriptionKind::Tasks,
            Self::Properties { .. } => SubscriptionKind::Properties,
            Self::Links { .. } => SubscriptionKind::Links,
        }
    }

    fn matches(&self, changed: &ChangedPatterns) -> bool {
        match self {
            Self::Outline { page_id } => {
                changed.pages.contains(page_id) && changed.relations.contains(&RelationKind::Blocks)
            }
            Self::Tasks { page_id } => {
                changed.relations.contains(&RelationKind::Tasks)
                    && page_id
                        .as_ref()
                        .is_none_or(|page_id| changed.pages.contains(page_id))
            }
            Self::Properties { page_id, key } => {
                changed.relations.contains(&RelationKind::Properties)
                    && page_id
                        .as_ref()
                        .is_none_or(|page_id| changed.pages.contains(page_id))
                    && key
                        .as_ref()
                        .is_none_or(|key| changed.property_keys.contains(key))
            }
            Self::Links { page_id, block_id } => {
                changed.relations.contains(&RelationKind::Links)
                    && page_id
                        .as_ref()
                        .is_none_or(|page_id| changed.pages.contains(page_id))
                    && block_id
                        .as_ref()
                        .is_none_or(|block_id| changed.block_ids.contains(block_id))
            }
        }
    }

    pub fn query_fingerprint(&self) -> QueryFingerprint {
        match self {
            Self::Outline { page_id } => QueryFingerprint {
                query_class: QueryClass::Outline,
                normalized_key: format!("outline|page={page_id}"),
            },
            Self::Tasks { page_id } => QueryFingerprint {
                query_class: QueryClass::Tasks,
                normalized_key: format!("tasks|page={}", page_id.as_deref().unwrap_or("*")),
            },
            Self::Properties { page_id, key } => QueryFingerprint {
                query_class: QueryClass::Properties,
                normalized_key: format!(
                    "properties|page={}|key={}",
                    page_id.as_deref().unwrap_or("*"),
                    key.as_deref().unwrap_or("*")
                ),
            },
            Self::Links { page_id, block_id } => QueryFingerprint {
                query_class: QueryClass::Links,
                normalized_key: format!(
                    "links|page={}|block={}",
                    page_id.as_deref().unwrap_or("*"),
                    block_id.as_deref().unwrap_or("*")
                ),
            },
        }
    }

    pub fn watch_plan(&self, subscription_id: u64) -> WatchPlan {
        match self {
            Self::Outline { page_id } => WatchPlan {
                subscription_id,
                query_fingerprint: self.query_fingerprint(),
                watched_artifact_ids: vec![page_id.clone()],
                watched_block_ids: Vec::new(),
                watched_relation_kinds: vec![MutationRelationKind::Blocks],
                watched_classes: vec![WatchClass::Outline, WatchClass::Body, WatchClass::Ordering],
                fallback_to_full_invalidation: false,
            },
            Self::Tasks { page_id } => WatchPlan {
                subscription_id,
                query_fingerprint: self.query_fingerprint(),
                watched_artifact_ids: page_id.iter().cloned().collect(),
                watched_block_ids: Vec::new(),
                watched_relation_kinds: vec![MutationRelationKind::Tasks],
                watched_classes: vec![WatchClass::Summary, WatchClass::Body],
                fallback_to_full_invalidation: false,
            },
            Self::Properties { page_id, .. } => WatchPlan {
                subscription_id,
                query_fingerprint: self.query_fingerprint(),
                watched_artifact_ids: page_id.iter().cloned().collect(),
                watched_block_ids: Vec::new(),
                watched_relation_kinds: vec![MutationRelationKind::Properties],
                watched_classes: vec![WatchClass::Summary, WatchClass::Body],
                fallback_to_full_invalidation: false,
            },
            Self::Links { page_id, block_id } => WatchPlan {
                subscription_id,
                query_fingerprint: self.query_fingerprint(),
                watched_artifact_ids: page_id.iter().cloned().collect(),
                watched_block_ids: block_id.iter().cloned().collect(),
                watched_relation_kinds: vec![MutationRelationKind::Links],
                watched_classes: vec![WatchClass::Backlinks, WatchClass::Graph],
                fallback_to_full_invalidation: false,
            },
        }
    }
}

#[derive(Clone, Debug)]
struct SubscriptionState {
    spec: SubscriptionSpec,
    last_rows: HashMap<String, QueryRow>,
}

#[derive(Default)]
struct ChangedPatterns {
    pages: BTreeSet<String>,
    touched_artifact_ids: BTreeSet<String>,
    relations: BTreeSet<RelationKind>,
    property_keys: BTreeSet<String>,
    block_ids: BTreeSet<String>,
    block_rows: BTreeSet<(String, String)>,
    task_rows: BTreeSet<(String, String)>,
    property_rows: BTreeSet<(String, String, String)>,
    link_rows: BTreeSet<(String, String, String, u8)>,
    affects_summary: bool,
    affects_outline: bool,
    affects_backlinks: bool,
    affects_search: bool,
    affects_graph: bool,
    affects_body: bool,
    affects_ordering: bool,
    source_operation_kind: MutationOperationKind,
}

impl ChangedPatterns {
    fn set_source_operation(&mut self, source_operation_kind: MutationOperationKind) {
        self.source_operation_kind = source_operation_kind;
    }

    fn touch_page(&mut self, page_id: &str) {
        self.pages.insert(page_id.to_string());
        self.touch_artifact(page_id);
    }

    fn touch_artifact(&mut self, artifact_id: &str) {
        self.touched_artifact_ids.insert(artifact_id.to_string());
    }

    fn touch_block(&mut self, block_id: &str) {
        self.block_ids.insert(block_id.to_string());
    }

    fn touch_relation(&mut self, relation: RelationKind) {
        self.relations.insert(relation);
    }

    fn touch_property_key(&mut self, key: &str) {
        self.property_keys.insert(key.to_string());
    }

    fn touch_block_row(&mut self, page_id: &str, block_id: &str) {
        self.touch_page(page_id);
        self.touch_block(block_id);
        self.touch_relation(RelationKind::Blocks);
        self.block_rows
            .insert((page_id.to_string(), block_id.to_string()));
    }

    fn touch_task_row(&mut self, page_id: &str, block_id: &str) {
        self.touch_page(page_id);
        self.touch_block(block_id);
        self.touch_relation(RelationKind::Tasks);
        self.task_rows
            .insert((page_id.to_string(), block_id.to_string()));
    }

    fn touch_property_row(&mut self, page_id: &str, block_id: &str, key: &str) {
        self.touch_page(page_id);
        self.touch_block(block_id);
        self.touch_relation(RelationKind::Properties);
        self.touch_property_key(key);
        self.property_rows
            .insert((page_id.to_string(), block_id.to_string(), key.to_string()));
    }

    fn touch_link_row(&mut self, page_id: &str, block_id: &str, target_id: &str, ref_type: u8) {
        self.touch_page(page_id);
        self.touch_artifact(target_id);
        self.touch_block(block_id);
        self.touch_relation(RelationKind::Links);
        self.affects_backlinks = true;
        self.affects_graph = true;
        self.link_rows.insert((
            page_id.to_string(),
            block_id.to_string(),
            target_id.to_string(),
            ref_type,
        ));
    }

    fn mark_content_changed(&mut self) {
        self.affects_summary = true;
        self.affects_body = true;
        self.affects_search = true;
    }

    fn mark_outline_changed(&mut self, ordering: bool) {
        self.affects_outline = true;
        if ordering {
            self.affects_ordering = true;
        }
    }

    fn to_envelope(&self, tx_id: u64) -> MutationEnvelope {
        MutationEnvelope {
            tx_id,
            touched_artifact_ids: self.touched_artifact_ids.iter().cloned().collect(),
            touched_block_ids: self.block_ids.iter().cloned().collect(),
            touched_relation_kinds: self
                .relations
                .iter()
                .copied()
                .map(MutationRelationKind::from)
                .collect(),
            affects_summary: self.affects_summary,
            affects_outline: self.affects_outline || self.relations.contains(&RelationKind::Blocks),
            affects_backlinks: self.affects_backlinks,
            affects_search: self.affects_search,
            affects_graph: self.affects_graph,
            affects_body: self.affects_body,
            affects_ordering: self.affects_ordering,
            source_operation_kind: self.source_operation_kind,
        }
    }
}

#[derive(Clone, Debug)]
struct BlockFact {
    page_id: String,
    block_id: String,
    parent_id: String,
    order_key: String,
    depth: u16,
    content: String,
}

#[derive(Clone, Debug)]
struct TaskFact {
    page_id: String,
    block_id: String,
    marker: String,
    done: bool,
}

#[derive(Clone, Debug)]
struct PropertyFact {
    page_id: String,
    block_id: String,
    key: String,
    value: String,
}

#[derive(Clone, Debug)]
struct LinkFact {
    page_id: String,
    block_id: String,
    target_id: String,
    ref_type: u8,
}

const BLOCK_SCHEMA: &str = ":create block {page: String, block: String => parent: String, ord: String, depth: Int, content: String}";
const TASK_SCHEMA: &str =
    ":create task {page: String, block: String => marker: String, done: Bool}";
const PROPERTY_SCHEMA: &str =
    ":create prop {page: String, block: String, key: String => value: String}";
const LINK_SCHEMA: &str =
    ":create link {page: String, block: String, target: String, ref_type: Int}";

const BLOCK_HEADERS: &[&str] = &["page", "block", "parent", "ord", "depth", "content"];
const BLOCK_KEY_HEADERS: &[&str] = &["page", "block"];
const TASK_HEADERS: &[&str] = &["page", "block", "marker", "done"];
const TASK_KEY_HEADERS: &[&str] = &["page", "block"];
const PROPERTY_HEADERS: &[&str] = &["page", "block", "key", "value"];
const PROPERTY_KEY_HEADERS: &[&str] = &["page", "block", "key"];
const LINK_HEADERS: &[&str] = &["page", "block", "target", "ref_type"];

pub struct DatalogStore {
    db: DbInstance,
    blocks: BTreeMap<(String, String), BlockFact>,
    tasks: BTreeMap<(String, String), TaskFact>,
    properties: BTreeMap<(String, String, String), PropertyFact>,
    links: BTreeMap<(String, String, String, u8), LinkFact>,
    tx_id: u64,
    next_subscription_id: u64,
    subscriptions: HashMap<u64, SubscriptionState>,
    query_runs: u64,
    last_mutation_envelope: Option<MutationEnvelope>,
}

impl Default for DatalogStore {
    fn default() -> Self {
        Self::new()
    }
}

impl DatalogStore {
    pub fn new() -> Self {
        let db = DbInstance::new("mem", "", "")
            .expect("knowledge-core staged Cozo instance must initialize");
        for schema in [BLOCK_SCHEMA, TASK_SCHEMA, PROPERTY_SCHEMA, LINK_SCHEMA] {
            db.run_default(schema)
                .expect("knowledge-core staged Cozo schema must initialize");
        }
        Self {
            db,
            blocks: BTreeMap::new(),
            tasks: BTreeMap::new(),
            properties: BTreeMap::new(),
            links: BTreeMap::new(),
            tx_id: 0,
            next_subscription_id: 1,
            subscriptions: HashMap::new(),
            query_runs: 0,
            last_mutation_envelope: None,
        }
    }

    pub fn last_mutation_envelope(&self) -> Option<&MutationEnvelope> {
        self.last_mutation_envelope.as_ref()
    }

    pub fn replace_page(
        &mut self,
        document: NormalizedDocument,
    ) -> Result<Vec<QueryDiffEnvelope>, StoreError> {
        let mut changed = ChangedPatterns::default();
        changed.set_source_operation(MutationOperationKind::DocumentIngest);
        changed.touch_artifact(&document.page_id);
        changed.mark_content_changed();
        changed.mark_outline_changed(true);
        self.evict_page(&document.page_id, &mut changed)?;
        let mut block_facts = Vec::with_capacity(document.blocks.len());
        let mut task_facts = Vec::with_capacity(document.tasks.len());
        let mut property_facts = Vec::with_capacity(document.properties.len());
        let mut link_facts = Vec::with_capacity(document.links.len());
        for block in document.blocks {
            let fact = BlockFact::from(block);
            changed.touch_block_row(&fact.page_id, &fact.block_id);
            self.blocks
                .insert((fact.page_id.clone(), fact.block_id.clone()), fact.clone());
            block_facts.push(fact);
        }
        for task in document.tasks {
            let fact = TaskFact::from(task);
            changed.touch_task_row(&fact.page_id, &fact.block_id);
            self.tasks
                .insert((fact.page_id.clone(), fact.block_id.clone()), fact.clone());
            task_facts.push(fact);
        }
        for property in document.properties {
            let fact = PropertyFact::from(property);
            changed.touch_property_row(&fact.page_id, &fact.block_id, &fact.key);
            self.properties.insert(
                (
                    fact.page_id.clone(),
                    fact.block_id.clone(),
                    fact.key.clone(),
                ),
                fact.clone(),
            );
            property_facts.push(fact);
        }
        for link in document.links {
            let fact = LinkFact::from(link);
            changed.touch_link_row(
                &fact.page_id,
                &fact.block_id,
                &fact.target_id,
                fact.ref_type,
            );
            self.links.insert(
                (
                    fact.page_id.clone(),
                    fact.block_id.clone(),
                    fact.target_id.clone(),
                    fact.ref_type,
                ),
                fact.clone(),
            );
            link_facts.push(fact);
        }
        self.put_block_facts(&block_facts)?;
        self.put_task_facts(&task_facts)?;
        self.put_property_facts(&property_facts)?;
        self.put_link_facts(&link_facts)?;
        self.advance_tx_and_refresh(changed)
    }

    pub fn upsert_block(
        &mut self,
        block: NormalizedBlock,
        task: Option<NormalizedTask>,
        properties: Vec<NormalizedProperty>,
        links: Vec<NormalizedLink>,
    ) -> Result<Vec<QueryDiffEnvelope>, StoreError> {
        let mut changed = ChangedPatterns::default();
        let existed = self
            .blocks
            .contains_key(&(block.page_id.clone(), block.block_id.clone()));
        changed.set_source_operation(if existed {
            MutationOperationKind::EditBlock
        } else {
            MutationOperationKind::InsertBlock
        });
        changed.mark_content_changed();
        changed.mark_outline_changed(!existed);
        self.purge_block(&block.page_id, &block.block_id, &mut changed)?;
        let block_fact = BlockFact::from(block);
        changed.touch_block_row(&block_fact.page_id, &block_fact.block_id);
        self.blocks.insert(
            (block_fact.page_id.clone(), block_fact.block_id.clone()),
            block_fact.clone(),
        );
        self.put_block_facts(std::slice::from_ref(&block_fact))?;
        if let Some(task) = task {
            let fact = TaskFact::from(task);
            changed.touch_task_row(&fact.page_id, &fact.block_id);
            self.tasks
                .insert((fact.page_id.clone(), fact.block_id.clone()), fact.clone());
            self.put_task_facts(std::slice::from_ref(&fact))?;
        }
        let mut property_facts = Vec::with_capacity(properties.len());
        for property in properties {
            let fact = PropertyFact::from(property);
            changed.touch_property_row(&fact.page_id, &fact.block_id, &fact.key);
            self.properties.insert(
                (
                    fact.page_id.clone(),
                    fact.block_id.clone(),
                    fact.key.clone(),
                ),
                fact.clone(),
            );
            property_facts.push(fact);
        }
        self.put_property_facts(&property_facts)?;
        let mut link_facts = Vec::with_capacity(links.len());
        for link in links {
            let fact = LinkFact::from(link);
            changed.touch_link_row(
                &fact.page_id,
                &fact.block_id,
                &fact.target_id,
                fact.ref_type,
            );
            self.links.insert(
                (
                    fact.page_id.clone(),
                    fact.block_id.clone(),
                    fact.target_id.clone(),
                    fact.ref_type,
                ),
                fact.clone(),
            );
            link_facts.push(fact);
        }
        self.put_link_facts(&link_facts)?;
        self.advance_tx_and_refresh(changed)
    }

    pub fn move_block(
        &mut self,
        page_id: &str,
        block_id: &str,
        parent_id: Option<&str>,
        order_key: &str,
    ) -> Result<Vec<QueryDiffEnvelope>, StoreError> {
        let Some(updated_block) = ({
            let Some(block) = self
                .blocks
                .get_mut(&(page_id.to_string(), block_id.to_string()))
            else {
                return Err(StoreError::MissingBlock(block_id.to_string()));
            };
            block.parent_id = parent_id.unwrap_or_default().to_string();
            block.order_key = order_key.to_string();
            Some(block.clone())
        }) else {
            return Err(StoreError::MissingBlock(block_id.to_string()));
        };
        let mut changed = ChangedPatterns::default();
        changed.set_source_operation(MutationOperationKind::MoveBlock);
        changed.mark_outline_changed(true);
        changed.touch_block_row(page_id, block_id);
        self.put_block_facts(std::slice::from_ref(&updated_block))?;
        self.advance_tx_and_refresh(changed)
    }

    pub fn delete_block(
        &mut self,
        page_id: &str,
        block_id: &str,
    ) -> Result<Vec<QueryDiffEnvelope>, StoreError> {
        if !self
            .blocks
            .contains_key(&(page_id.to_string(), block_id.to_string()))
        {
            return Err(StoreError::MissingBlock(block_id.to_string()));
        }
        let mut changed = ChangedPatterns::default();
        changed.set_source_operation(MutationOperationKind::DeleteBlock);
        changed.mark_content_changed();
        changed.mark_outline_changed(true);
        self.purge_block(page_id, block_id, &mut changed)?;
        self.advance_tx_and_refresh(changed)
    }

    pub fn subscribe(
        &mut self,
        spec: SubscriptionSpec,
    ) -> Result<(u64, QueryDiffEnvelope), StoreError> {
        let rows = self.run_query(&spec)?;
        let row_map = rows
            .iter()
            .cloned()
            .map(|row| (row.identity(), row))
            .collect::<HashMap<_, _>>();
        let subscription_id = self.next_subscription_id;
        self.next_subscription_id += 1;
        self.subscriptions.insert(
            subscription_id,
            SubscriptionState {
                spec: spec.clone(),
                last_rows: row_map,
            },
        );
        Ok((
            subscription_id,
            QueryDiffEnvelope {
                tx_id: self.tx_id,
                subscription_id,
                kind: spec.kind(),
                added: rows,
                updated: Vec::new(),
                removed: Vec::new(),
            },
        ))
    }

    pub fn unsubscribe(&mut self, subscription_id: u64) -> bool {
        self.subscriptions.remove(&subscription_id).is_some()
    }

    fn advance_tx_and_refresh(
        &mut self,
        changed: ChangedPatterns,
    ) -> Result<Vec<QueryDiffEnvelope>, StoreError> {
        self.tx_id += 1;
        self.last_mutation_envelope = Some(changed.to_envelope(self.tx_id));
        let mut envelopes = Vec::new();
        let scheduled = self
            .subscriptions
            .iter()
            .filter_map(|(subscription_id, subscription)| {
                subscription
                    .spec
                    .matches(&changed)
                    .then_some((*subscription_id, subscription.spec.clone()))
            })
            .collect::<Vec<_>>();

        for (subscription_id, spec) in scheduled {
            let Some(mut subscription) = self.subscriptions.remove(&subscription_id) else {
                continue;
            };
            let envelope = if let Some(envelope) = self.refresh_subscription_incrementally(
                subscription_id,
                &spec,
                &changed,
                &mut subscription.last_rows,
            ) {
                envelope
            } else {
                let next_rows = self.run_query(&spec)?;
                let next_map = next_rows
                    .iter()
                    .cloned()
                    .map(|row| (row.identity(), row))
                    .collect::<HashMap<_, _>>();
                let envelope = diff_rows(
                    self.tx_id,
                    subscription_id,
                    spec.kind(),
                    &subscription.last_rows,
                    &next_map,
                );
                subscription.last_rows = next_map;
                envelope
            };
            self.subscriptions.insert(subscription_id, subscription);
            if !envelope.added.is_empty()
                || !envelope.updated.is_empty()
                || !envelope.removed.is_empty()
            {
                envelopes.push(envelope);
            }
        }
        Ok(envelopes)
    }

    fn evict_page(
        &mut self,
        page_id: &str,
        changed: &mut ChangedPatterns,
    ) -> Result<(), StoreError> {
        let block_keys = self
            .blocks
            .keys()
            .filter(|(stored_page_id, _)| stored_page_id == page_id)
            .cloned()
            .collect::<Vec<_>>();
        let mut removed_blocks = Vec::with_capacity(block_keys.len());
        for (stored_page_id, block_id) in block_keys {
            changed.touch_block_row(&stored_page_id, &block_id);
            if let Some(fact) = self.blocks.remove(&(stored_page_id, block_id)) {
                removed_blocks.push(fact);
            }
        }

        let task_keys = self
            .tasks
            .keys()
            .filter(|(stored_page_id, _)| stored_page_id == page_id)
            .cloned()
            .collect::<Vec<_>>();
        let mut removed_tasks = Vec::with_capacity(task_keys.len());
        for (stored_page_id, block_id) in task_keys {
            changed.touch_task_row(&stored_page_id, &block_id);
            if let Some(fact) = self.tasks.remove(&(stored_page_id, block_id)) {
                removed_tasks.push(fact);
            }
        }

        let property_keys = self
            .properties
            .keys()
            .filter(|(stored_page_id, _, _)| stored_page_id == page_id)
            .cloned()
            .collect::<Vec<_>>();
        let mut removed_properties = Vec::with_capacity(property_keys.len());
        for (stored_page_id, block_id, key) in property_keys {
            changed.touch_property_row(&stored_page_id, &block_id, &key);
            if let Some(fact) = self.properties.remove(&(stored_page_id, block_id, key)) {
                removed_properties.push(fact);
            }
        }

        let link_keys = self
            .links
            .keys()
            .filter(|(stored_page_id, _, _, _)| stored_page_id == page_id)
            .cloned()
            .collect::<Vec<_>>();
        let mut removed_links = Vec::with_capacity(link_keys.len());
        for (stored_page_id, block_id, target_id, ref_type) in link_keys {
            changed.touch_link_row(&stored_page_id, &block_id, &target_id, ref_type);
            if let Some(fact) = self
                .links
                .remove(&(stored_page_id, block_id, target_id, ref_type))
            {
                removed_links.push(fact);
            }
        }

        self.delete_block_facts(&removed_blocks)?;
        self.delete_task_facts(&removed_tasks)?;
        self.delete_property_facts(&removed_properties)?;
        self.delete_link_facts(&removed_links)?;
        Ok(())
    }

    fn purge_block(
        &mut self,
        page_id: &str,
        block_id: &str,
        changed: &mut ChangedPatterns,
    ) -> Result<(), StoreError> {
        changed.touch_block_row(page_id, block_id);
        let removed_block = self
            .blocks
            .remove(&(page_id.to_string(), block_id.to_string()));

        let removed_task = self
            .tasks
            .remove(&(page_id.to_string(), block_id.to_string()));
        if removed_task.is_some() {
            changed.touch_task_row(page_id, block_id);
        }

        let property_keys = self
            .properties
            .keys()
            .filter(|(stored_page_id, stored_block_id, _)| {
                stored_page_id == page_id && stored_block_id == block_id
            })
            .cloned()
            .collect::<Vec<_>>();
        let mut removed_properties = Vec::with_capacity(property_keys.len());
        for (stored_page_id, stored_block_id, key) in property_keys {
            changed.touch_property_row(&stored_page_id, &stored_block_id, &key);
            if let Some(fact) = self
                .properties
                .remove(&(stored_page_id, stored_block_id, key))
            {
                removed_properties.push(fact);
            }
        }

        let link_keys = self
            .links
            .keys()
            .filter(|(stored_page_id, stored_block_id, _, _)| {
                stored_page_id == page_id && stored_block_id == block_id
            })
            .cloned()
            .collect::<Vec<_>>();
        let mut removed_links = Vec::with_capacity(link_keys.len());
        for (stored_page_id, stored_block_id, target_id, ref_type) in link_keys {
            changed.touch_link_row(&stored_page_id, &stored_block_id, &target_id, ref_type);
            if let Some(fact) =
                self.links
                    .remove(&(stored_page_id, stored_block_id, target_id, ref_type))
            {
                removed_links.push(fact);
            }
        }

        if let Some(fact) = removed_block.as_ref() {
            self.delete_block_facts(std::slice::from_ref(fact))?;
        }
        if let Some(fact) = removed_task.as_ref() {
            self.delete_task_facts(std::slice::from_ref(fact))?;
        }
        self.delete_property_facts(&removed_properties)?;
        self.delete_link_facts(&removed_links)?;
        Ok(())
    }

    fn run_query(&mut self, spec: &SubscriptionSpec) -> Result<Vec<QueryRow>, StoreError> {
        self.query_runs += 1;
        match spec {
            SubscriptionSpec::Outline { page_id } => self.run_outline_query(page_id),
            SubscriptionSpec::Tasks { page_id } => self.run_tasks_query(page_id.as_deref()),
            SubscriptionSpec::Properties { page_id, key } => {
                self.run_properties_query(page_id.as_deref(), key.as_deref())
            }
            SubscriptionSpec::Links { page_id, block_id } => {
                self.run_links_query(page_id.as_deref(), block_id.as_deref())
            }
        }
    }

    fn run_outline_query(&self, page_id: &str) -> Result<Vec<QueryRow>, StoreError> {
        let result = self.db.run_script(
            "?[page, block, parent, ord, depth, content] := *block{page, block, parent, ord, depth, content}, page = $page :order ord",
            BTreeMap::from([("page".to_string(), DataValue::from(page_id.to_string()))]),
            ScriptMutability::Immutable,
        );
        let result = result.map_err(|error| StoreError::Query(error.to_string()))?;
        Ok(result
            .rows
            .into_iter()
            .filter_map(|row| {
                Some(QueryRow::Block(BlockRow {
                    page_id: row.first()?.get_str()?.to_string(),
                    block_id: row.get(1)?.get_str()?.to_string(),
                    parent_id: row.get(2)?.get_str()?.to_string(),
                    order_key: row.get(3)?.get_str()?.to_string(),
                    depth: row.get(4)?.get_int()? as u16,
                    content: row.get(5)?.get_str()?.to_string(),
                }))
            })
            .collect())
    }

    fn run_tasks_query(&self, page_id: Option<&str>) -> Result<Vec<QueryRow>, StoreError> {
        let (script, params) = if let Some(page_id) = page_id {
            (
                "?[page, block, marker, done] := *task{page, block, marker, done}, page = $page :order block",
                BTreeMap::from([("page".to_string(), DataValue::from(page_id.to_string()))]),
            )
        } else {
            (
                "?[page, block, marker, done] := *task{page, block, marker, done} :order block",
                BTreeMap::new(),
            )
        };
        let result = self
            .db
            .run_script(script, params, ScriptMutability::Immutable)
            .map_err(|error| StoreError::Query(error.to_string()))?;
        Ok(result
            .rows
            .into_iter()
            .filter_map(|row| {
                Some(QueryRow::Task(TaskRow {
                    page_id: row.first()?.get_str()?.to_string(),
                    block_id: row.get(1)?.get_str()?.to_string(),
                    marker: row.get(2)?.get_str()?.to_string(),
                    done: row.get(3)?.get_bool()?,
                }))
            })
            .collect())
    }

    fn run_properties_query(
        &self,
        page_id: Option<&str>,
        key: Option<&str>,
    ) -> Result<Vec<QueryRow>, StoreError> {
        let mut filters = Vec::new();
        let mut params = BTreeMap::new();
        if let Some(page_id) = page_id {
            filters.push("page = $page");
            params.insert("page".to_string(), DataValue::from(page_id.to_string()));
        }
        if let Some(key) = key {
            filters.push("key = $key");
            params.insert("key".to_string(), DataValue::from(key.to_string()));
        }
        let mut script =
            String::from("?[page, block, key, value] := *prop{page, block, key, value}");
        if !filters.is_empty() {
            script.push_str(", ");
            script.push_str(&filters.join(", "));
        }
        script.push_str(" :order block");
        let result = self
            .db
            .run_script(&script, params, ScriptMutability::Immutable)
            .map_err(|error| StoreError::Query(error.to_string()))?;
        Ok(result
            .rows
            .into_iter()
            .filter_map(|row| {
                Some(QueryRow::Property(PropertyRow {
                    page_id: row.first()?.get_str()?.to_string(),
                    block_id: row.get(1)?.get_str()?.to_string(),
                    key: row.get(2)?.get_str()?.to_string(),
                    value: row.get(3)?.get_str()?.to_string(),
                }))
            })
            .collect())
    }

    fn run_links_query(
        &self,
        page_id: Option<&str>,
        block_id: Option<&str>,
    ) -> Result<Vec<QueryRow>, StoreError> {
        let mut filters = Vec::new();
        let mut params = BTreeMap::new();
        if let Some(page_id) = page_id {
            filters.push("page = $page");
            params.insert("page".to_string(), DataValue::from(page_id.to_string()));
        }
        if let Some(block_id) = block_id {
            filters.push("block = $block");
            params.insert("block".to_string(), DataValue::from(block_id.to_string()));
        }
        let mut script = String::from(
            "?[page, block, target, ref_type] := *link{page, block, target, ref_type}",
        );
        if !filters.is_empty() {
            script.push_str(", ");
            script.push_str(&filters.join(", "));
        }
        script.push_str(" :order block");
        let result = self
            .db
            .run_script(&script, params, ScriptMutability::Immutable)
            .map_err(|error| StoreError::Query(error.to_string()))?;
        Ok(result
            .rows
            .into_iter()
            .filter_map(|row| {
                Some(QueryRow::Link(LinkRow {
                    page_id: row.first()?.get_str()?.to_string(),
                    block_id: row.get(1)?.get_str()?.to_string(),
                    target_id: row.get(2)?.get_str()?.to_string(),
                    ref_type: row.get(3)?.get_int()? as u8,
                }))
            })
            .collect())
    }

    fn refresh_subscription_incrementally(
        &self,
        subscription_id: u64,
        spec: &SubscriptionSpec,
        changed: &ChangedPatterns,
        last_rows: &mut HashMap<String, QueryRow>,
    ) -> Option<QueryDiffEnvelope> {
        match spec {
            SubscriptionSpec::Outline { page_id } => Some(self.refresh_outline_subscription(
                subscription_id,
                page_id,
                &changed.block_rows,
                last_rows,
            )),
            SubscriptionSpec::Tasks { page_id } => Some(self.refresh_tasks_subscription(
                subscription_id,
                page_id.as_deref(),
                &changed.task_rows,
                last_rows,
            )),
            SubscriptionSpec::Properties { page_id, key } => {
                Some(self.refresh_properties_subscription(
                    subscription_id,
                    page_id.as_deref(),
                    key.as_deref(),
                    &changed.property_rows,
                    last_rows,
                ))
            }
            SubscriptionSpec::Links { page_id, block_id } => Some(self.refresh_links_subscription(
                subscription_id,
                page_id.as_deref(),
                block_id.as_deref(),
                &changed.link_rows,
                last_rows,
            )),
        }
    }

    fn refresh_outline_subscription(
        &self,
        subscription_id: u64,
        page_id: &str,
        changed_rows: &BTreeSet<(String, String)>,
        last_rows: &mut HashMap<String, QueryRow>,
    ) -> QueryDiffEnvelope {
        let mut added = Vec::new();
        let mut updated = Vec::new();
        let mut removed = Vec::new();

        for (changed_page_id, changed_block_id) in changed_rows {
            if changed_page_id != page_id {
                continue;
            }
            let previous_identity = last_rows.iter().find_map(|(identity, row)| match row {
                QueryRow::Block(row)
                    if row.page_id == *changed_page_id && row.block_id == *changed_block_id =>
                {
                    Some(identity.clone())
                }
                _ => None,
            });
            let previous = previous_identity
                .as_ref()
                .and_then(|identity| last_rows.remove(identity));
            let next = self
                .blocks
                .get(&(changed_page_id.clone(), changed_block_id.clone()))
                .map(QueryRow::from);
            apply_incremental_row_change(
                last_rows,
                previous,
                next,
                &mut added,
                &mut updated,
                &mut removed,
            );
        }

        QueryDiffEnvelope {
            tx_id: self.tx_id,
            subscription_id,
            kind: SubscriptionKind::Outline,
            added,
            updated,
            removed,
        }
    }

    fn refresh_tasks_subscription(
        &self,
        subscription_id: u64,
        page_id: Option<&str>,
        changed_rows: &BTreeSet<(String, String)>,
        last_rows: &mut HashMap<String, QueryRow>,
    ) -> QueryDiffEnvelope {
        let mut added = Vec::new();
        let mut updated = Vec::new();
        let mut removed = Vec::new();

        for (changed_page_id, changed_block_id) in changed_rows {
            if page_id.is_some_and(|filter| filter != changed_page_id) {
                continue;
            }
            let identity = format!("task|{changed_page_id}|{changed_block_id}");
            let previous = last_rows.remove(&identity);
            let next = self
                .tasks
                .get(&(changed_page_id.clone(), changed_block_id.clone()))
                .map(QueryRow::from);
            apply_incremental_row_change(
                last_rows,
                previous,
                next,
                &mut added,
                &mut updated,
                &mut removed,
            );
        }

        QueryDiffEnvelope {
            tx_id: self.tx_id,
            subscription_id,
            kind: SubscriptionKind::Tasks,
            added,
            updated,
            removed,
        }
    }

    fn refresh_properties_subscription(
        &self,
        subscription_id: u64,
        page_id: Option<&str>,
        key: Option<&str>,
        changed_rows: &BTreeSet<(String, String, String)>,
        last_rows: &mut HashMap<String, QueryRow>,
    ) -> QueryDiffEnvelope {
        let mut added = Vec::new();
        let mut updated = Vec::new();
        let mut removed = Vec::new();

        for (changed_page_id, changed_block_id, changed_key) in changed_rows {
            if page_id.is_some_and(|filter| filter != changed_page_id)
                || key.is_some_and(|filter| filter != changed_key)
            {
                continue;
            }
            let identity = format!("prop|{changed_page_id}|{changed_block_id}|{changed_key}");
            let previous = last_rows.remove(&identity);
            let next = self
                .properties
                .get(&(
                    changed_page_id.clone(),
                    changed_block_id.clone(),
                    changed_key.clone(),
                ))
                .map(QueryRow::from);
            apply_incremental_row_change(
                last_rows,
                previous,
                next,
                &mut added,
                &mut updated,
                &mut removed,
            );
        }

        QueryDiffEnvelope {
            tx_id: self.tx_id,
            subscription_id,
            kind: SubscriptionKind::Properties,
            added,
            updated,
            removed,
        }
    }

    fn refresh_links_subscription(
        &self,
        subscription_id: u64,
        page_id: Option<&str>,
        block_id: Option<&str>,
        changed_rows: &BTreeSet<(String, String, String, u8)>,
        last_rows: &mut HashMap<String, QueryRow>,
    ) -> QueryDiffEnvelope {
        let mut added = Vec::new();
        let mut updated = Vec::new();
        let mut removed = Vec::new();

        for (changed_page_id, changed_block_id, changed_target_id, changed_ref_type) in changed_rows
        {
            if page_id.is_some_and(|filter| filter != changed_page_id)
                || block_id.is_some_and(|filter| filter != changed_block_id)
            {
                continue;
            }
            let identity = format!(
                "link|{changed_page_id}|{changed_block_id}|{changed_target_id}|{changed_ref_type}"
            );
            let previous = last_rows.remove(&identity);
            let next = self
                .links
                .get(&(
                    changed_page_id.clone(),
                    changed_block_id.clone(),
                    changed_target_id.clone(),
                    *changed_ref_type,
                ))
                .map(QueryRow::from);
            apply_incremental_row_change(
                last_rows,
                previous,
                next,
                &mut added,
                &mut updated,
                &mut removed,
            );
        }

        QueryDiffEnvelope {
            tx_id: self.tx_id,
            subscription_id,
            kind: SubscriptionKind::Links,
            added,
            updated,
            removed,
        }
    }

    fn put_block_facts(&self, facts: &[BlockFact]) -> Result<(), StoreError> {
        write_rows(
            &self.db,
            "block",
            BLOCK_HEADERS,
            facts.iter().map(BlockFact::data_row).collect(),
        )
    }

    fn delete_block_facts(&self, facts: &[BlockFact]) -> Result<(), StoreError> {
        write_rows(
            &self.db,
            "-block",
            BLOCK_KEY_HEADERS,
            facts.iter().map(BlockFact::key_row).collect(),
        )
    }

    fn put_task_facts(&self, facts: &[TaskFact]) -> Result<(), StoreError> {
        write_rows(
            &self.db,
            "task",
            TASK_HEADERS,
            facts.iter().map(TaskFact::data_row).collect(),
        )
    }

    fn delete_task_facts(&self, facts: &[TaskFact]) -> Result<(), StoreError> {
        write_rows(
            &self.db,
            "-task",
            TASK_KEY_HEADERS,
            facts.iter().map(TaskFact::key_row).collect(),
        )
    }

    fn put_property_facts(&self, facts: &[PropertyFact]) -> Result<(), StoreError> {
        write_rows(
            &self.db,
            "prop",
            PROPERTY_HEADERS,
            facts.iter().map(PropertyFact::data_row).collect(),
        )
    }

    fn delete_property_facts(&self, facts: &[PropertyFact]) -> Result<(), StoreError> {
        write_rows(
            &self.db,
            "-prop",
            PROPERTY_KEY_HEADERS,
            facts.iter().map(PropertyFact::key_row).collect(),
        )
    }

    fn put_link_facts(&self, facts: &[LinkFact]) -> Result<(), StoreError> {
        write_rows(
            &self.db,
            "link",
            LINK_HEADERS,
            facts.iter().map(LinkFact::data_row).collect(),
        )
    }

    fn delete_link_facts(&self, facts: &[LinkFact]) -> Result<(), StoreError> {
        write_rows(
            &self.db,
            "-link",
            LINK_HEADERS,
            facts.iter().map(LinkFact::data_row).collect(),
        )
    }

    #[cfg(test)]
    fn query_runs(&self) -> u64 {
        self.query_runs
    }
}

impl From<NormalizedBlock> for BlockFact {
    fn from(value: NormalizedBlock) -> Self {
        Self {
            page_id: value.page_id,
            block_id: value.block_id,
            parent_id: value.parent_id,
            order_key: value.order_key,
            depth: value.depth,
            content: value.content,
        }
    }
}

impl BlockFact {
    fn data_row(&self) -> Vec<DataValue> {
        vec![
            DataValue::from(self.page_id.clone()),
            DataValue::from(self.block_id.clone()),
            DataValue::from(self.parent_id.clone()),
            DataValue::from(self.order_key.clone()),
            DataValue::from(i64::from(self.depth)),
            DataValue::from(self.content.clone()),
        ]
    }

    fn key_row(&self) -> Vec<DataValue> {
        vec![
            DataValue::from(self.page_id.clone()),
            DataValue::from(self.block_id.clone()),
        ]
    }
}

impl From<NormalizedTask> for TaskFact {
    fn from(value: NormalizedTask) -> Self {
        Self {
            page_id: value.page_id,
            block_id: value.block_id,
            marker: value.marker,
            done: value.done,
        }
    }
}

impl TaskFact {
    fn data_row(&self) -> Vec<DataValue> {
        vec![
            DataValue::from(self.page_id.clone()),
            DataValue::from(self.block_id.clone()),
            DataValue::from(self.marker.clone()),
            DataValue::from(self.done),
        ]
    }

    fn key_row(&self) -> Vec<DataValue> {
        vec![
            DataValue::from(self.page_id.clone()),
            DataValue::from(self.block_id.clone()),
        ]
    }
}

impl From<NormalizedProperty> for PropertyFact {
    fn from(value: NormalizedProperty) -> Self {
        Self {
            page_id: value.page_id,
            block_id: value.block_id,
            key: value.key,
            value: value.value,
        }
    }
}

impl PropertyFact {
    fn data_row(&self) -> Vec<DataValue> {
        vec![
            DataValue::from(self.page_id.clone()),
            DataValue::from(self.block_id.clone()),
            DataValue::from(self.key.clone()),
            DataValue::from(self.value.clone()),
        ]
    }

    fn key_row(&self) -> Vec<DataValue> {
        vec![
            DataValue::from(self.page_id.clone()),
            DataValue::from(self.block_id.clone()),
            DataValue::from(self.key.clone()),
        ]
    }
}

impl From<NormalizedLink> for LinkFact {
    fn from(value: NormalizedLink) -> Self {
        Self {
            page_id: value.page_id,
            block_id: value.block_id,
            target_id: value.target_id,
            ref_type: value.ref_type,
        }
    }
}

impl LinkFact {
    fn data_row(&self) -> Vec<DataValue> {
        vec![
            DataValue::from(self.page_id.clone()),
            DataValue::from(self.block_id.clone()),
            DataValue::from(self.target_id.clone()),
            DataValue::from(i64::from(self.ref_type)),
        ]
    }
}

impl From<&BlockFact> for QueryRow {
    fn from(value: &BlockFact) -> Self {
        Self::Block(BlockRow {
            page_id: value.page_id.clone(),
            block_id: value.block_id.clone(),
            parent_id: value.parent_id.clone(),
            order_key: value.order_key.clone(),
            depth: value.depth,
            content: value.content.clone(),
        })
    }
}

impl From<&TaskFact> for QueryRow {
    fn from(value: &TaskFact) -> Self {
        Self::Task(TaskRow {
            page_id: value.page_id.clone(),
            block_id: value.block_id.clone(),
            marker: value.marker.clone(),
            done: value.done,
        })
    }
}

impl From<&PropertyFact> for QueryRow {
    fn from(value: &PropertyFact) -> Self {
        Self::Property(PropertyRow {
            page_id: value.page_id.clone(),
            block_id: value.block_id.clone(),
            key: value.key.clone(),
            value: value.value.clone(),
        })
    }
}

impl From<&LinkFact> for QueryRow {
    fn from(value: &LinkFact) -> Self {
        Self::Link(LinkRow {
            page_id: value.page_id.clone(),
            block_id: value.block_id.clone(),
            target_id: value.target_id.clone(),
            ref_type: value.ref_type,
        })
    }
}

fn diff_rows(
    tx_id: u64,
    subscription_id: u64,
    kind: SubscriptionKind,
    previous: &HashMap<String, QueryRow>,
    next: &HashMap<String, QueryRow>,
) -> QueryDiffEnvelope {
    let mut added = Vec::new();
    let mut updated = Vec::new();
    let mut removed = Vec::new();

    for (identity, row) in next {
        match previous.get(identity) {
            None => added.push(row.clone()),
            Some(previous_row) if previous_row != row => updated.push(row.clone()),
            Some(_) => {}
        }
    }
    for (identity, row) in previous {
        if !next.contains_key(identity) {
            removed.push(row.clone());
        }
    }

    QueryDiffEnvelope {
        tx_id,
        subscription_id,
        kind,
        added,
        updated,
        removed,
    }
}

fn import_rows(
    db: &DbInstance,
    relation: &str,
    headers: Vec<String>,
    rows: Vec<Vec<DataValue>>,
) -> Result<(), StoreError> {
    let mut imports = BTreeMap::new();
    imports.insert(
        relation.to_string(),
        NamedRows {
            headers,
            rows,
            next: None,
        },
    );
    db.import_relations(imports)
        .map_err(|error| StoreError::Query(error.to_string()))
}

fn write_rows(
    db: &DbInstance,
    relation: &str,
    headers: &[&str],
    rows: Vec<Vec<DataValue>>,
) -> Result<(), StoreError> {
    if rows.is_empty() {
        return Ok(());
    }
    import_rows(
        db,
        relation,
        headers.iter().map(|header| (*header).to_string()).collect(),
        rows,
    )
}

fn apply_incremental_row_change(
    last_rows: &mut HashMap<String, QueryRow>,
    previous: Option<QueryRow>,
    next: Option<QueryRow>,
    added: &mut Vec<QueryRow>,
    updated: &mut Vec<QueryRow>,
    removed: &mut Vec<QueryRow>,
) {
    match (previous, next) {
        (None, None) => {}
        (None, Some(next_row)) => {
            last_rows.insert(next_row.identity(), next_row.clone());
            added.push(next_row);
        }
        (Some(previous_row), None) => {
            removed.push(previous_row);
        }
        (Some(previous_row), Some(next_row)) => {
            let identity = next_row.identity();
            if previous_row != next_row {
                updated.push(next_row.clone());
            }
            last_rows.insert(identity, next_row);
        }
    }
}

#[cfg(test)]
mod tests {
    use std::{collections::BTreeSet, time::Instant};

    use super::{
        DatalogStore, MutationEnvelope, MutationOperationKind, MutationRelationKind,
        QueryDiffEnvelope, QueryRow, SubscriptionSpec, WatchClass, WatchPlan,
        mutation_intersects_watch_plan,
    };
    use crate::knowledge_core::parser::{
        DocumentFormat, NormalizedBlock, NormalizedLink, parse_document,
    };

    fn normalized_block(page_id: &str, block_id: &str, content: &str) -> NormalizedBlock {
        NormalizedBlock {
            page_id: page_id.to_string(),
            block_id: block_id.to_string(),
            parent_id: String::new(),
            order_key: "0000000001".to_string(),
            depth: 0,
            content: content.to_string(),
        }
    }

    fn normalized_link(page_id: &str, block_id: &str, target_id: &str) -> NormalizedLink {
        NormalizedLink {
            page_id: page_id.to_string(),
            block_id: block_id.to_string(),
            target_id: target_id.to_string(),
            ref_type: 0,
        }
    }

    fn latest_envelope(store: &DatalogStore) -> MutationEnvelope {
        store
            .last_mutation_envelope()
            .expect("mutation envelope should be recorded")
            .clone()
    }

    fn relation_kinds(envelope: &MutationEnvelope) -> BTreeSet<MutationRelationKind> {
        envelope.touched_relation_kinds.iter().copied().collect()
    }

    fn manual_watch_plan(
        subscription_id: u64,
        artifact_ids: Vec<&str>,
        block_ids: Vec<&str>,
        relation_kinds: Vec<MutationRelationKind>,
        watch_classes: Vec<WatchClass>,
    ) -> WatchPlan {
        WatchPlan {
            subscription_id,
            query_fingerprint: SubscriptionSpec::Outline {
                page_id: "page-a".to_string(),
            }
            .query_fingerprint(),
            watched_artifact_ids: artifact_ids.into_iter().map(str::to_string).collect(),
            watched_block_ids: block_ids.into_iter().map(str::to_string).collect(),
            watched_relation_kinds: relation_kinds,
            watched_classes: watch_classes,
            fallback_to_full_invalidation: false,
        }
    }

    #[test]
    fn subscriptions_emit_diffs_only_for_matching_pages() {
        let mut store = DatalogStore::new();
        let (subscription_id, initial) = store
            .subscribe(SubscriptionSpec::Outline {
                page_id: "page-a".to_string(),
            })
            .expect("subscription should register");
        assert_eq!(subscription_id, 1);
        assert!(initial.added.is_empty());

        let page_b = parse_document("page-b", DocumentFormat::Markdown, "- B");
        let diffs = store
            .replace_page(page_b)
            .expect("page replace should work");
        assert!(diffs.is_empty());

        let page_a = parse_document("page-a", DocumentFormat::Markdown, "- A");
        let diffs = store
            .replace_page(page_a)
            .expect("page replace should work");
        assert_eq!(diffs.len(), 1);
        assert_eq!(diffs[0].added.len(), 1);
    }

    #[test]
    fn matching_updates_refresh_outline_without_full_query_rerun() {
        let mut store = DatalogStore::new();
        let page = parse_document("page-a", DocumentFormat::Markdown, "- A");
        store.replace_page(page).expect("page replace should work");
        let (_, initial) = store
            .subscribe(SubscriptionSpec::Outline {
                page_id: "page-a".to_string(),
            })
            .expect("subscription should register");
        let block_id = match initial.added.first() {
            Some(QueryRow::Block(row)) => row.block_id.clone(),
            other => panic!("expected initial block row, got {other:?}"),
        };
        let query_runs_before = store.query_runs();

        let diffs = store
            .move_block("page-a", &block_id, None, "9999999999")
            .expect("block move should work");

        assert_eq!(store.query_runs(), query_runs_before);
        assert_eq!(diffs.len(), 1);
        assert_eq!(diffs[0].updated.len(), 1);
    }

    #[test]
    fn link_queries_keep_distinct_ref_types_for_same_target() {
        let mut store = DatalogStore::new();
        let page = parse_document(
            "page-a",
            DocumentFormat::Markdown,
            "- Source [[shared-target]]",
        );
        store.replace_page(page).expect("page replace should work");
        let first_block_id = store
            .run_query(&SubscriptionSpec::Outline {
                page_id: "page-a".to_string(),
            })
            .expect("outline query should work")
            .into_iter()
            .find_map(|row| match row {
                QueryRow::Block(row) => Some(row.block_id),
                _ => None,
            })
            .expect("expected parsed block");

        let diffs = store
            .upsert_block(
                crate::knowledge_core::parser::NormalizedBlock {
                    page_id: "page-a".to_string(),
                    block_id: first_block_id.clone(),
                    parent_id: String::new(),
                    order_key: "0000000000".to_string(),
                    depth: 0,
                    content: "Source [[shared-target]]".to_string(),
                },
                None,
                Vec::new(),
                vec![
                    crate::knowledge_core::parser::NormalizedLink {
                        page_id: "page-a".to_string(),
                        block_id: first_block_id.clone(),
                        target_id: "shared-target".to_string(),
                        ref_type: 0,
                    },
                    crate::knowledge_core::parser::NormalizedLink {
                        page_id: "page-a".to_string(),
                        block_id: first_block_id.clone(),
                        target_id: "shared-target".to_string(),
                        ref_type: 7,
                    },
                ],
            )
            .expect("upsert should work");
        assert!(diffs.is_empty());

        let (_, initial) = store
            .subscribe(SubscriptionSpec::Links {
                page_id: Some("page-a".to_string()),
                block_id: Some(first_block_id),
            })
            .expect("link subscription should register");
        assert_eq!(initial.added.len(), 2);
    }

    #[test]
    fn equivalent_subscription_specs_have_stable_fingerprints() {
        let first = SubscriptionSpec::Properties {
            page_id: Some("page-a".to_string()),
            key: Some("owner".to_string()),
        }
        .query_fingerprint();
        let second = SubscriptionSpec::Properties {
            page_id: Some("page-a".to_string()),
            key: Some("owner".to_string()),
        }
        .query_fingerprint();

        assert_eq!(first, second);
        assert_eq!(first.normalized_key, "properties|page=page-a|key=owner");
    }

    #[test]
    fn different_query_shapes_have_distinct_fingerprints() {
        let owner_properties = SubscriptionSpec::Properties {
            page_id: Some("page-a".to_string()),
            key: Some("owner".to_string()),
        }
        .query_fingerprint();
        let status_properties = SubscriptionSpec::Properties {
            page_id: Some("page-a".to_string()),
            key: Some("status".to_string()),
        }
        .query_fingerprint();
        let links = SubscriptionSpec::Links {
            page_id: Some("page-a".to_string()),
            block_id: None,
        }
        .query_fingerprint();

        assert_ne!(owner_properties, status_properties);
        assert_ne!(owner_properties, links);
    }

    #[test]
    fn watch_plan_rejects_irrelevant_artifact_mutation() {
        let mut store = DatalogStore::new();
        store
            .upsert_block(
                normalized_block("page-b", "block-b", "Beta"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block insert should work");

        let mutation = latest_envelope(&store);
        let watch_plan = SubscriptionSpec::Outline {
            page_id: "page-a".to_string(),
        }
        .watch_plan(1);

        assert!(!mutation_intersects_watch_plan(&mutation, &watch_plan));
    }

    #[test]
    fn watch_plan_accepts_relevant_block_mutation() {
        let mut store = DatalogStore::new();
        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Alpha"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block insert should work");

        let mutation = latest_envelope(&store);
        let watch_plan = manual_watch_plan(
            1,
            vec!["page-a"],
            vec!["block-a"],
            vec![],
            vec![WatchClass::Body],
        );

        assert!(mutation_intersects_watch_plan(&mutation, &watch_plan));
    }

    #[test]
    fn relation_mutation_intersects_backlink_watch_plan() {
        let mut store = DatalogStore::new();
        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Alpha [[target-a]]"),
                None,
                Vec::new(),
                vec![normalized_link("page-a", "block-a", "target-a")],
            )
            .expect("link insert should work");

        let mutation = latest_envelope(&store);
        let watch_plan = SubscriptionSpec::Links {
            page_id: Some("page-a".to_string()),
            block_id: Some("block-a".to_string()),
        }
        .watch_plan(1);

        assert!(mutation_intersects_watch_plan(&mutation, &watch_plan));
    }

    #[test]
    fn body_only_mutation_updates_body_search_but_not_unrelated_graph_watch() {
        let mut store = DatalogStore::new();
        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Alpha"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block insert should work");
        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Beta"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block edit should work");

        let mutation = latest_envelope(&store);
        let body_search_watch = manual_watch_plan(
            1,
            vec!["page-a"],
            vec!["block-a"],
            vec![],
            vec![WatchClass::Body, WatchClass::Search],
        );
        let graph_watch = manual_watch_plan(
            2,
            vec!["page-a"],
            vec!["block-a"],
            vec![MutationRelationKind::Links],
            vec![WatchClass::Graph, WatchClass::Backlinks],
        );

        assert!(mutation_intersects_watch_plan(
            &mutation,
            &body_search_watch
        ));
        assert!(!mutation_intersects_watch_plan(&mutation, &graph_watch));
    }

    #[test]
    fn ordering_only_mutation_does_not_force_body_watch() {
        let mut store = DatalogStore::new();
        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Alpha"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block insert should work");
        store
            .move_block("page-a", "block-a", None, "0000000002")
            .expect("block move should work");

        let mutation = latest_envelope(&store);
        let body_watch = manual_watch_plan(
            1,
            vec!["page-a"],
            vec!["block-a"],
            vec![],
            vec![WatchClass::Body],
        );
        let ordering_watch = manual_watch_plan(
            2,
            vec!["page-a"],
            vec!["block-a"],
            vec![],
            vec![WatchClass::Ordering],
        );

        assert!(!mutation_intersects_watch_plan(&mutation, &body_watch));
        assert!(mutation_intersects_watch_plan(&mutation, &ordering_watch));
    }

    #[test]
    fn unsupported_watch_plan_falls_back_to_invalidation() {
        let mut store = DatalogStore::new();
        store
            .upsert_block(
                normalized_block("page-b", "block-b", "Beta"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block insert should work");

        let mutation = latest_envelope(&store);
        let watch_plan = WatchPlan::unsupported(99, "external|opaque");

        assert!(mutation_intersects_watch_plan(&mutation, &watch_plan));
    }

    #[test]
    fn document_ingest_records_mutation_envelope_with_links() {
        let mut store = DatalogStore::new();
        let page = parse_document(
            "page-a",
            DocumentFormat::Markdown,
            "- [ ] Task [[target-a]] @owner=jojo",
        );

        store.replace_page(page).expect("page replace should work");

        let envelope = latest_envelope(&store);
        assert_eq!(envelope.tx_id, 1);
        assert_eq!(
            envelope.source_operation_kind,
            MutationOperationKind::DocumentIngest
        );
        assert!(
            envelope
                .touched_artifact_ids
                .contains(&"page-a".to_string())
        );
        assert!(
            envelope
                .touched_artifact_ids
                .contains(&"target-a".to_string())
        );
        assert!(!envelope.touched_block_ids.is_empty());
        assert_eq!(
            relation_kinds(&envelope),
            BTreeSet::from([
                MutationRelationKind::Blocks,
                MutationRelationKind::Links,
                MutationRelationKind::Properties,
                MutationRelationKind::Tasks,
            ])
        );
        assert!(envelope.affects_summary);
        assert!(envelope.affects_outline);
        assert!(envelope.affects_backlinks);
        assert!(envelope.affects_search);
        assert!(envelope.affects_graph);
        assert!(envelope.affects_body);
        assert!(envelope.affects_ordering);
    }

    #[test]
    fn insert_block_records_precise_body_and_ordering_effects() {
        let mut store = DatalogStore::new();

        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Alpha"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block insert should work");

        let envelope = latest_envelope(&store);
        assert_eq!(
            envelope.source_operation_kind,
            MutationOperationKind::InsertBlock
        );
        assert_eq!(envelope.touched_artifact_ids, vec!["page-a".to_string()]);
        assert_eq!(envelope.touched_block_ids, vec!["block-a".to_string()]);
        assert_eq!(
            relation_kinds(&envelope),
            BTreeSet::from([MutationRelationKind::Blocks])
        );
        assert!(envelope.affects_summary);
        assert!(envelope.affects_body);
        assert!(envelope.affects_search);
        assert!(envelope.affects_outline);
        assert!(envelope.affects_ordering);
        assert!(!envelope.affects_backlinks);
        assert!(!envelope.affects_graph);
    }

    #[test]
    fn edit_block_does_not_mark_graph_or_ordering_without_links() {
        let mut store = DatalogStore::new();
        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Alpha"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block insert should work");

        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Beta"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block edit should work");

        let envelope = latest_envelope(&store);
        assert_eq!(
            envelope.source_operation_kind,
            MutationOperationKind::EditBlock
        );
        assert_eq!(
            relation_kinds(&envelope),
            BTreeSet::from([MutationRelationKind::Blocks])
        );
        assert!(envelope.affects_summary);
        assert!(envelope.affects_body);
        assert!(envelope.affects_search);
        assert!(envelope.affects_outline);
        assert!(!envelope.affects_ordering);
        assert!(!envelope.affects_backlinks);
        assert!(!envelope.affects_graph);
    }

    #[test]
    fn move_block_records_ordering_only() {
        let mut store = DatalogStore::new();
        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Alpha"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block insert should work");

        store
            .move_block("page-a", "block-a", None, "0000000002")
            .expect("block move should work");

        let envelope = latest_envelope(&store);
        assert_eq!(
            envelope.source_operation_kind,
            MutationOperationKind::MoveBlock
        );
        assert_eq!(
            relation_kinds(&envelope),
            BTreeSet::from([MutationRelationKind::Blocks])
        );
        assert!(envelope.affects_outline);
        assert!(envelope.affects_ordering);
        assert!(!envelope.affects_summary);
        assert!(!envelope.affects_body);
        assert!(!envelope.affects_search);
        assert!(!envelope.affects_backlinks);
        assert!(!envelope.affects_graph);
    }

    #[test]
    fn link_change_records_relation_and_target_artifact() {
        let mut store = DatalogStore::new();
        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Alpha"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block insert should work");

        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Alpha [[target-a]]"),
                None,
                Vec::new(),
                vec![normalized_link("page-a", "block-a", "target-a")],
            )
            .expect("link edit should work");

        let envelope = latest_envelope(&store);
        assert_eq!(
            envelope.source_operation_kind,
            MutationOperationKind::EditBlock
        );
        assert!(
            envelope
                .touched_artifact_ids
                .contains(&"page-a".to_string())
        );
        assert!(
            envelope
                .touched_artifact_ids
                .contains(&"target-a".to_string())
        );
        assert_eq!(
            relation_kinds(&envelope),
            BTreeSet::from([MutationRelationKind::Blocks, MutationRelationKind::Links,])
        );
        assert!(envelope.affects_summary);
        assert!(envelope.affects_body);
        assert!(envelope.affects_search);
        assert!(envelope.affects_outline);
        assert!(envelope.affects_backlinks);
        assert!(envelope.affects_graph);
        assert!(!envelope.affects_ordering);
    }

    #[test]
    fn delete_block_records_body_search_and_no_unowned_task_relation() {
        let mut store = DatalogStore::new();
        store
            .upsert_block(
                normalized_block("page-a", "block-a", "Alpha"),
                None,
                Vec::new(),
                Vec::new(),
            )
            .expect("block insert should work");

        store
            .delete_block("page-a", "block-a")
            .expect("block delete should work");

        let envelope = latest_envelope(&store);
        assert_eq!(
            envelope.source_operation_kind,
            MutationOperationKind::DeleteBlock
        );
        assert_eq!(
            relation_kinds(&envelope),
            BTreeSet::from([MutationRelationKind::Blocks])
        );
        assert!(envelope.affects_summary);
        assert!(envelope.affects_body);
        assert!(envelope.affects_search);
        assert!(envelope.affects_outline);
        assert!(envelope.affects_ordering);
        assert!(!envelope.affects_backlinks);
        assert!(!envelope.affects_graph);
    }

    #[test]
    #[ignore = "benchmark"]
    fn benchmark_knowledge_core_incremental_outline_refresh() {
        const BLOCK_COUNT: usize = 400;
        const ITERATIONS: usize = 500;

        let body = (0..BLOCK_COUNT)
            .map(|idx| format!("- Block {idx}"))
            .collect::<Vec<_>>()
            .join("\n");

        let mut incremental_store = DatalogStore::new();
        incremental_store
            .replace_page(parse_document("page-a", DocumentFormat::Markdown, &body))
            .expect("page replace should work");
        let (_, initial) = incremental_store
            .subscribe(SubscriptionSpec::Outline {
                page_id: "page-a".to_string(),
            })
            .expect("subscription should register");
        let block_id = match initial.added.first() {
            Some(QueryRow::Block(row)) => row.block_id.clone(),
            other => panic!("expected initial block row, got {other:?}"),
        };

        let incremental_start = Instant::now();
        for idx in 0..ITERATIONS {
            let order_key = format!("{idx:010}");
            let _ = incremental_store
                .move_block("page-a", &block_id, None, &order_key)
                .expect("incremental move should work");
        }
        let incremental_elapsed = incremental_start.elapsed();

        let mut control_store = DatalogStore::new();
        control_store
            .replace_page(parse_document("page-a", DocumentFormat::Markdown, &body))
            .expect("page replace should work");
        let spec = SubscriptionSpec::Outline {
            page_id: "page-a".to_string(),
        };
        let initial_rows = control_store
            .run_query(&spec)
            .expect("control initial query should work");
        let block_id = match initial_rows.first() {
            Some(QueryRow::Block(row)) => row.block_id.clone(),
            other => panic!("expected initial block row, got {other:?}"),
        };
        let mut last_rows = initial_rows
            .into_iter()
            .map(|row| (row.identity(), row))
            .collect::<std::collections::HashMap<_, _>>();

        let full_rerun_start = Instant::now();
        for idx in 0..ITERATIONS {
            let order_key = format!("{idx:010}");
            control_store
                .move_block("page-a", &block_id, None, &order_key)
                .expect("control move should work");
            let next_rows = control_store
                .run_query(&spec)
                .expect("control query should work");
            let next_map = next_rows
                .iter()
                .cloned()
                .map(|row| (row.identity(), row))
                .collect();
            let _: QueryDiffEnvelope = super::diff_rows(
                control_store.tx_id,
                1,
                super::SubscriptionKind::Outline,
                &last_rows,
                &next_map,
            );
            last_rows = next_map;
        }
        let full_rerun_elapsed = full_rerun_start.elapsed();

        let incremental_ns = incremental_elapsed.as_nanos() as f64 / ITERATIONS as f64;
        let full_rerun_ns = full_rerun_elapsed.as_nanos() as f64 / ITERATIONS as f64;
        println!(
            "knowledge_core_outline_watcher incremental_ns_per_tx={} full_rerun_ns_per_tx={} speedup_x={:.2}",
            incremental_ns.round() as u64,
            full_rerun_ns.round() as u64,
            full_rerun_ns / incremental_ns
        );
    }
}
