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

#[derive(Clone, Debug)]
pub enum SubscriptionSpec {
    Outline { page_id: String },
    Tasks { page_id: Option<String> },
    Properties { page_id: Option<String>, key: Option<String> },
    Links { page_id: Option<String>, block_id: Option<String> },
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
                changed.pages.contains(page_id)
                    && changed.relations.contains(&RelationKind::Blocks)
            }
            Self::Tasks { page_id } => {
                changed.relations.contains(&RelationKind::Tasks)
                    && page_id
                        .as_ref()
                        .map_or(true, |page_id| changed.pages.contains(page_id))
            }
            Self::Properties { page_id, key } => {
                changed.relations.contains(&RelationKind::Properties)
                    && page_id
                        .as_ref()
                        .map_or(true, |page_id| changed.pages.contains(page_id))
                    && key
                        .as_ref()
                        .map_or(true, |key| changed.property_keys.contains(key))
            }
            Self::Links { page_id, block_id } => {
                changed.relations.contains(&RelationKind::Links)
                    && page_id
                        .as_ref()
                        .map_or(true, |page_id| changed.pages.contains(page_id))
                    && block_id
                        .as_ref()
                        .map_or(true, |block_id| changed.block_ids.contains(block_id))
            }
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
    relations: BTreeSet<RelationKind>,
    property_keys: BTreeSet<String>,
    block_ids: BTreeSet<String>,
}

impl ChangedPatterns {
    fn touch_page(&mut self, page_id: &str) {
        self.pages.insert(page_id.to_string());
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

pub struct DatalogStore {
    blocks: BTreeMap<(String, String), BlockFact>,
    tasks: BTreeMap<(String, String), TaskFact>,
    properties: BTreeMap<(String, String, String), PropertyFact>,
    links: BTreeMap<(String, String, String, u8), LinkFact>,
    tx_id: u64,
    next_subscription_id: u64,
    subscriptions: HashMap<u64, SubscriptionState>,
}

impl DatalogStore {
    pub fn new() -> Self {
        Self {
            blocks: BTreeMap::new(),
            tasks: BTreeMap::new(),
            properties: BTreeMap::new(),
            links: BTreeMap::new(),
            tx_id: 0,
            next_subscription_id: 1,
            subscriptions: HashMap::new(),
        }
    }

    pub fn replace_page(
        &mut self,
        document: NormalizedDocument,
    ) -> Result<Vec<QueryDiffEnvelope>, StoreError> {
        let mut changed = ChangedPatterns::default();
        self.evict_page(&document.page_id, &mut changed);
        for block in document.blocks {
            changed.touch_page(&block.page_id);
            changed.touch_block(&block.block_id);
            changed.touch_relation(RelationKind::Blocks);
            self.blocks.insert(
                (block.page_id.clone(), block.block_id.clone()),
                BlockFact::from(block),
            );
        }
        for task in document.tasks {
            changed.touch_page(&task.page_id);
            changed.touch_block(&task.block_id);
            changed.touch_relation(RelationKind::Tasks);
            self.tasks.insert(
                (task.page_id.clone(), task.block_id.clone()),
                TaskFact::from(task),
            );
        }
        for property in document.properties {
            changed.touch_page(&property.page_id);
            changed.touch_block(&property.block_id);
            changed.touch_relation(RelationKind::Properties);
            changed.touch_property_key(&property.key);
            self.properties.insert(
                (
                    property.page_id.clone(),
                    property.block_id.clone(),
                    property.key.clone(),
                ),
                PropertyFact::from(property),
            );
        }
        for link in document.links {
            changed.touch_page(&link.page_id);
            changed.touch_block(&link.block_id);
            changed.touch_relation(RelationKind::Links);
            self.links.insert(
                (
                    link.page_id.clone(),
                    link.block_id.clone(),
                    link.target_id.clone(),
                    link.ref_type,
                ),
                LinkFact::from(link),
            );
        }
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
        self.purge_block(&block.page_id, &block.block_id, &mut changed);
        changed.touch_page(&block.page_id);
        changed.touch_block(&block.block_id);
        changed.touch_relation(RelationKind::Blocks);
        self.blocks.insert(
            (block.page_id.clone(), block.block_id.clone()),
            BlockFact::from(block),
        );
        if let Some(task) = task {
            changed.touch_relation(RelationKind::Tasks);
            self.tasks.insert(
                (task.page_id.clone(), task.block_id.clone()),
                TaskFact::from(task),
            );
        }
        for property in properties {
            changed.touch_relation(RelationKind::Properties);
            changed.touch_property_key(&property.key);
            self.properties.insert(
                (
                    property.page_id.clone(),
                    property.block_id.clone(),
                    property.key.clone(),
                ),
                PropertyFact::from(property),
            );
        }
        for link in links {
            changed.touch_relation(RelationKind::Links);
            self.links.insert(
                (
                    link.page_id.clone(),
                    link.block_id.clone(),
                    link.target_id.clone(),
                    link.ref_type,
                ),
                LinkFact::from(link),
            );
        }
        self.advance_tx_and_refresh(changed)
    }

    pub fn move_block(
        &mut self,
        page_id: &str,
        block_id: &str,
        parent_id: Option<&str>,
        order_key: &str,
    ) -> Result<Vec<QueryDiffEnvelope>, StoreError> {
        let Some(block) = self
            .blocks
            .get_mut(&(page_id.to_string(), block_id.to_string()))
        else {
            return Err(StoreError::MissingBlock(block_id.to_string()));
        };
        block.parent_id = parent_id.unwrap_or_default().to_string();
        block.order_key = order_key.to_string();
        let mut changed = ChangedPatterns::default();
        changed.touch_page(page_id);
        changed.touch_block(block_id);
        changed.touch_relation(RelationKind::Blocks);
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
        self.purge_block(page_id, block_id, &mut changed);
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
            let next_rows = self.run_query(&spec)?;
            let next_map = next_rows
                .iter()
                .cloned()
                .map(|row| (row.identity(), row))
                .collect::<HashMap<_, _>>();
            let Some(subscription) = self.subscriptions.get_mut(&subscription_id) else {
                continue;
            };
            let envelope = diff_rows(
                self.tx_id,
                subscription_id,
                spec.kind(),
                &subscription.last_rows,
                &next_map,
            );
            subscription.last_rows = next_map;
            if !envelope.added.is_empty()
                || !envelope.updated.is_empty()
                || !envelope.removed.is_empty()
            {
                envelopes.push(envelope);
            }
        }
        Ok(envelopes)
    }

    fn evict_page(&mut self, page_id: &str, changed: &mut ChangedPatterns) {
        self.blocks.retain(|(stored_page_id, block_id), _| {
            let keep = stored_page_id != page_id;
            if !keep {
                changed.touch_page(page_id);
                changed.touch_block(block_id);
                changed.touch_relation(RelationKind::Blocks);
            }
            keep
        });
        self.tasks.retain(|(stored_page_id, block_id), _| {
            let keep = stored_page_id != page_id;
            if !keep {
                changed.touch_page(page_id);
                changed.touch_block(block_id);
                changed.touch_relation(RelationKind::Tasks);
            }
            keep
        });
        self.properties
            .retain(|(stored_page_id, block_id, key), _| {
                let keep = stored_page_id != page_id;
                if !keep {
                    changed.touch_page(page_id);
                    changed.touch_block(block_id);
                    changed.touch_relation(RelationKind::Properties);
                    changed.touch_property_key(key);
                }
                keep
            });
        self.links
            .retain(|(stored_page_id, block_id, _, _), _| {
                let keep = stored_page_id != page_id;
                if !keep {
                    changed.touch_page(page_id);
                    changed.touch_block(block_id);
                    changed.touch_relation(RelationKind::Links);
                }
                keep
            });
    }

    fn purge_block(&mut self, page_id: &str, block_id: &str, changed: &mut ChangedPatterns) {
        self.blocks
            .remove(&(page_id.to_string(), block_id.to_string()));
        changed.touch_page(page_id);
        changed.touch_block(block_id);
        changed.touch_relation(RelationKind::Blocks);
        self.tasks
            .remove(&(page_id.to_string(), block_id.to_string()));
        changed.touch_relation(RelationKind::Tasks);
        self.properties
            .retain(|(stored_page_id, stored_block_id, key), _| {
                let keep = !(stored_page_id == page_id && stored_block_id == block_id);
                if !keep {
                    changed.touch_relation(RelationKind::Properties);
                    changed.touch_property_key(key);
                }
                keep
            });
        self.links.retain(|(stored_page_id, stored_block_id, _, _), _| {
            let keep = !(stored_page_id == page_id && stored_block_id == block_id);
            if !keep {
                changed.touch_relation(RelationKind::Links);
            }
            keep
        });
    }

    fn run_query(&self, spec: &SubscriptionSpec) -> Result<Vec<QueryRow>, StoreError> {
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
        let db = DbInstance::new("mem", "", "")
            .map_err(|error| StoreError::Query(error.to_string()))?;
        db.run_default(
            ":create block {page: String, block: String => parent: String, ord: String, depth: Int, content: String}",
        )
        .map_err(|error| StoreError::Query(error.to_string()))?;
        let rows = self
            .blocks
            .values()
            .map(|block| {
                vec![
                    DataValue::from(block.page_id.clone()),
                    DataValue::from(block.block_id.clone()),
                    DataValue::from(block.parent_id.clone()),
                    DataValue::from(block.order_key.clone()),
                    DataValue::from(i64::from(block.depth)),
                    DataValue::from(block.content.clone()),
                ]
            })
            .collect::<Vec<_>>();
        if !rows.is_empty() {
            import_rows(
                &db,
                "block",
                vec![
                    "page".to_string(),
                    "block".to_string(),
                    "parent".to_string(),
                    "ord".to_string(),
                    "depth".to_string(),
                    "content".to_string(),
                ],
                rows,
            )?;
        }
        let result = db.run_script(
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
        let db = DbInstance::new("mem", "", "")
            .map_err(|error| StoreError::Query(error.to_string()))?;
        db.run_default(":create task {page: String, block: String => marker: String, done: Bool}")
            .map_err(|error| StoreError::Query(error.to_string()))?;
        let rows = self
            .tasks
            .values()
            .map(|task| {
                vec![
                    DataValue::from(task.page_id.clone()),
                    DataValue::from(task.block_id.clone()),
                    DataValue::from(task.marker.clone()),
                    DataValue::from(task.done),
                ]
            })
            .collect::<Vec<_>>();
        if !rows.is_empty() {
            import_rows(
                &db,
                "task",
                vec![
                    "page".to_string(),
                    "block".to_string(),
                    "marker".to_string(),
                    "done".to_string(),
                ],
                rows,
            )?;
        }
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
        let result = db
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
        let db = DbInstance::new("mem", "", "")
            .map_err(|error| StoreError::Query(error.to_string()))?;
        db.run_default(":create prop {page: String, block: String, key: String => value: String}")
            .map_err(|error| StoreError::Query(error.to_string()))?;
        let rows = self
            .properties
            .values()
            .map(|property| {
                vec![
                    DataValue::from(property.page_id.clone()),
                    DataValue::from(property.block_id.clone()),
                    DataValue::from(property.key.clone()),
                    DataValue::from(property.value.clone()),
                ]
            })
            .collect::<Vec<_>>();
        if !rows.is_empty() {
            import_rows(
                &db,
                "prop",
                vec![
                    "page".to_string(),
                    "block".to_string(),
                    "key".to_string(),
                    "value".to_string(),
                ],
                rows,
            )?;
        }
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
        let result = db
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
        let db = DbInstance::new("mem", "", "")
            .map_err(|error| StoreError::Query(error.to_string()))?;
        db.run_default(":create link {page: String, block: String, target: String => ref_type: Int}")
            .map_err(|error| StoreError::Query(error.to_string()))?;
        let rows = self
            .links
            .values()
            .map(|link| {
                vec![
                    DataValue::from(link.page_id.clone()),
                    DataValue::from(link.block_id.clone()),
                    DataValue::from(link.target_id.clone()),
                    DataValue::from(i64::from(link.ref_type)),
                ]
            })
            .collect::<Vec<_>>();
        if !rows.is_empty() {
            import_rows(
                &db,
                "link",
                vec![
                    "page".to_string(),
                    "block".to_string(),
                    "target".to_string(),
                    "ref_type".to_string(),
                ],
                rows,
            )?;
        }
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
        let mut script =
            String::from("?[page, block, target, ref_type] := *link{page, block, target, ref_type}");
        if !filters.is_empty() {
            script.push_str(", ");
            script.push_str(&filters.join(", "));
        }
        script.push_str(" :order block");
        let result = db
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

#[cfg(test)]
mod tests {
    use super::{DatalogStore, SubscriptionSpec};
    use crate::knowledge_core::parser::{DocumentFormat, parse_document};

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
        let diffs = store.replace_page(page_b).expect("page replace should work");
        assert!(diffs.is_empty());

        let page_a = parse_document("page-a", DocumentFormat::Markdown, "- A");
        let diffs = store.replace_page(page_a).expect("page replace should work");
        assert_eq!(diffs.len(), 1);
        assert_eq!(diffs[0].added.len(), 1);
    }
}
