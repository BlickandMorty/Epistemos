use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};

use cozo::{DataValue, DbInstance, NamedRows, ScriptMutability};
use memchr::memmem;
use rkyv::{Archive, Deserialize, Serialize};

use crate::block_kernel::block_tree::BlockTree;
use crate::block_kernel::op::{Op, PropertyValue};
use crate::block_kernel::op_log::OpLog;

#[derive(Clone, Debug, PartialEq, Eq)]
struct MaterializedBlock {
    page_id: String,
    block_id: String,
    parent_id: String,
    depth: u16,
    order_key: String,
    content: String,
    task_marker: String,
    task_done: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
struct MaterializedLink {
    page_id: String,
    block_id: String,
    target_id: String,
    ref_type: u8,
}

#[derive(Clone, Debug, Default)]
struct MaterializedPage {
    blocks: HashMap<String, MaterializedBlock>,
    properties: HashMap<(String, String), String>,
    links: HashSet<MaterializedLink>,
}

impl MaterializedPage {
    fn from_tree(page_id: &str, tree: &BlockTree, log: &OpLog) -> Self {
        Self::from_entries(page_id, tree, log.entries())
    }

    fn from_entries(page_id: &str, tree: &BlockTree, entries: &[(u64, Op)]) -> Self {
        let mut page = Self::default();
        let mut inline_links = HashSet::new();

        for block in tree.walk() {
            let block_id = block.id.to_uuid_string();
            let parent_id = block
                .parent_id
                .map_or_else(String::new, |parent| parent.to_uuid_string());
            let (task_marker, task_done) = parse_task_state(&block.content);
            page.blocks.insert(
                block_id.clone(),
                MaterializedBlock {
                    page_id: page_id.to_string(),
                    block_id: block_id.clone(),
                    parent_id,
                    depth: block.depth,
                    order_key: format!("{:010}", block.order),
                    content: block.content.clone(),
                    task_marker,
                    task_done,
                },
            );

            for (key, value) in &block.properties {
                page.properties.insert(
                    (block_id.clone(), key.clone()),
                    property_value_string(value),
                );
            }

            for target_id in parse_inline_links(&block.content) {
                inline_links.insert(MaterializedLink {
                    page_id: page_id.to_string(),
                    block_id: block_id.clone(),
                    target_id,
                    ref_type: 0,
                });
            }
        }

        page.links = inline_links;
        for (_, op) in entries {
            if let Op::SetRef {
                block_id,
                target_id,
                ref_type,
            } = op
            {
                page.links.insert(MaterializedLink {
                    page_id: page_id.to_string(),
                    block_id: block_id.to_uuid_string(),
                    target_id: target_id.to_uuid_string(),
                    ref_type: *ref_type,
                });
            }
        }

        page
    }
}

#[derive(Clone, Debug, Default)]
struct ChangedFacts {
    structure: bool,
    content: bool,
    links: bool,
    tasks: bool,
    block_ids: HashSet<String>,
    property_keys: HashSet<String>,
    property_rows: HashSet<(String, String)>,
}

impl ChangedFacts {
    fn between(old: Option<&MaterializedPage>, new: &MaterializedPage) -> Self {
        let Some(old) = old else {
            let mut property_keys = HashSet::new();
            property_keys.extend(new.properties.keys().map(|(_, key)| key.clone()));
            return Self {
                structure: !new.blocks.is_empty(),
                content: !new.blocks.is_empty(),
                links: !new.links.is_empty(),
                tasks: new
                    .blocks
                    .values()
                    .any(|block| !block.task_marker.is_empty() || block.task_done),
                block_ids: new.blocks.keys().cloned().collect(),
                property_keys,
                property_rows: new
                    .properties
                    .keys()
                    .map(|(block_id, key)| (block_id.clone(), key.clone()))
                    .collect(),
            };
        };

        let mut changed = Self::default();
        let block_ids: HashSet<String> = old
            .blocks
            .keys()
            .chain(new.blocks.keys())
            .cloned()
            .collect();
        for block_id in block_ids {
            match (old.blocks.get(&block_id), new.blocks.get(&block_id)) {
                (Some(before), Some(after)) => {
                    if before.parent_id != after.parent_id
                        || before.depth != after.depth
                        || before.order_key != after.order_key
                    {
                        changed.structure = true;
                        changed.block_ids.insert(block_id.clone());
                    }
                    if before.content != after.content {
                        changed.content = true;
                        changed.block_ids.insert(block_id.clone());
                    }
                    if before.task_marker != after.task_marker
                        || before.task_done != after.task_done
                    {
                        changed.tasks = true;
                        changed.block_ids.insert(block_id.clone());
                    }
                }
                _ => {
                    changed.structure = true;
                    changed.content = true;
                    changed.tasks = true;
                    changed.block_ids.insert(block_id.clone());
                }
            }
        }

        let property_keys: HashSet<String> = old
            .properties
            .keys()
            .chain(new.properties.keys())
            .map(|(_, key)| key.clone())
            .collect();
        for key in property_keys {
            let before: BTreeSet<(String, String)> = old
                .properties
                .iter()
                .filter_map(|((block_id, property_key), value)| {
                    (property_key == &key).then_some((block_id.clone(), value.clone()))
                })
                .collect();
            let after: BTreeSet<(String, String)> = new
                .properties
                .iter()
                .filter_map(|((block_id, property_key), value)| {
                    (property_key == &key).then_some((block_id.clone(), value.clone()))
                })
                .collect();
            if before != after {
                changed.property_keys.insert(key.clone());
                changed.property_rows.extend(
                    before
                        .iter()
                        .map(|(block_id, _)| (block_id.clone(), key.clone()))
                        .chain(
                            after
                                .iter()
                                .map(|(block_id, _)| (block_id.clone(), key.clone())),
                        ),
                );
            }
        }

        if old.links != new.links {
            changed.links = true;
        }

        changed
    }

    fn is_empty(&self) -> bool {
        !self.structure
            && !self.content
            && !self.links
            && !self.tasks
            && self.property_keys.is_empty()
    }
}

#[derive(Clone, Debug)]
struct QueryDependencies {
    page_filter: Option<String>,
    structure: bool,
    content: bool,
    links: bool,
    tasks: bool,
    property_keys: HashSet<String>,
}

impl QueryDependencies {
    fn matches(&self, page_id: &str, changed: &ChangedFacts) -> bool {
        if let Some(filter) = &self.page_filter {
            if filter != page_id {
                return false;
            }
        }
        (self.structure && changed.structure)
            || (self.content && changed.content)
            || (self.links && changed.links)
            || (self.tasks && changed.tasks)
            || !self.property_keys.is_disjoint(&changed.property_keys)
    }
}

#[derive(Clone, Debug)]
enum ReactiveQuerySpec {
    Outline { page_id: String },
    PropertyEquals { key: String, value: Option<String> },
    LinkedReferences { block_id: String, max_depth: u8 },
}

impl ReactiveQuerySpec {
    fn dependencies(&self) -> QueryDependencies {
        match self {
            Self::Outline { page_id } => QueryDependencies {
                page_filter: Some(page_id.clone()),
                structure: true,
                content: true,
                links: false,
                tasks: true,
                property_keys: HashSet::new(),
            },
            Self::PropertyEquals { key, .. } => QueryDependencies {
                page_filter: None,
                structure: false,
                content: false,
                links: false,
                tasks: false,
                property_keys: HashSet::from([key.clone()]),
            },
            Self::LinkedReferences { .. } => QueryDependencies {
                page_filter: None,
                structure: false,
                content: false,
                links: true,
                tasks: false,
                property_keys: HashSet::new(),
            },
        }
    }

    fn kind(&self) -> u8 {
        match self {
            Self::Outline { .. } => 0,
            Self::PropertyEquals { .. } => 1,
            Self::LinkedReferences { .. } => 2,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Archive, Serialize, Deserialize)]
#[rkyv(compare(PartialEq), derive(Debug))]
pub struct QueryResultRow {
    pub page_id: String,
    pub block_id: String,
    pub parent_id: String,
    pub target_id: String,
    pub content: String,
    pub property_key: String,
    pub property_value: String,
    pub task_marker: String,
    pub order_key: String,
    pub depth: u16,
    pub ref_type: u8,
    pub task_done: bool,
    pub hop_count: u8,
}

impl QueryResultRow {
    fn identity(&self) -> String {
        format!(
            "{}|{}|{}|{}|{}|{}",
            self.page_id,
            self.block_id,
            self.parent_id,
            self.target_id,
            self.property_key,
            self.hop_count
        )
    }
}

#[derive(Clone, Debug, Archive, Serialize, Deserialize)]
#[rkyv(derive(Debug))]
pub struct SubscriptionPayload {
    pub version: u64,
    pub kind: u8,
    pub added: Vec<QueryResultRow>,
    pub updated: Vec<QueryResultRow>,
    pub removed: Vec<QueryResultRow>,
}

#[derive(Clone, Debug)]
struct ReactiveSubscription {
    spec: ReactiveQuerySpec,
    dependencies: QueryDependencies,
    last_rows: HashMap<String, QueryResultRow>,
    pending_update: Option<Vec<u8>>,
}

#[derive(Clone, Debug)]
struct TxBoundary {
    global_seq: u64,
    page_id: String,
    page_log_seq: u64,
}

pub struct BtkQueryKernel {
    pages: HashMap<String, MaterializedPage>,
    subscriptions: HashMap<u64, ReactiveSubscription>,
    tx_boundaries: Vec<TxBoundary>,
    next_subscription_id: u64,
    global_seq: u64,
    query_runs: u64,
}

impl Default for BtkQueryKernel {
    fn default() -> Self {
        Self::new()
    }
}

impl BtkQueryKernel {
    /// Create an empty BTK query kernel with no materialized pages or subscriptions.
    pub fn new() -> Self {
        Self {
            pages: HashMap::new(),
            subscriptions: HashMap::new(),
            tx_boundaries: Vec::new(),
            next_subscription_id: 1,
            global_seq: 0,
            query_runs: 0,
        }
    }

    /// Re-materialize one BTK page from the current tree and operation log.
    ///
    /// Any subscription whose watched attributes overlap the changed facts receives a
    /// new archived diff payload in its pending slot.
    pub fn sync_page(&mut self, page_id: &str, tree: &BlockTree, log: &OpLog) {
        let new_page = MaterializedPage::from_tree(page_id, tree, log);
        let changed = ChangedFacts::between(self.pages.get(page_id), &new_page);
        self.pages.insert(page_id.to_string(), new_page);

        if changed.is_empty() {
            return;
        }

        self.global_seq += 1;
        self.tx_boundaries.push(TxBoundary {
            global_seq: self.global_seq,
            page_id: page_id.to_string(),
            page_log_seq: log.latest_seq(),
        });

        let scheduled = self
            .subscriptions
            .iter()
            .filter_map(|(subscription_id, subscription)| {
                subscription
                    .dependencies
                    .matches(page_id, &changed)
                    .then_some(*subscription_id)
            })
            .collect::<Vec<_>>();
        let current_page = self
            .pages
            .get(page_id)
            .expect("synced page should remain materialized");

        for subscription_id in scheduled {
            let Some(mut subscription) = self.subscriptions.remove(&subscription_id) else {
                continue;
            };

            let payload = if let Some(payload) = refresh_subscription_incrementally(
                self.global_seq,
                page_id,
                current_page,
                &subscription.spec,
                &changed,
                &mut subscription.last_rows,
            ) {
                payload
            } else {
                self.query_runs += 1;
                let next_rows = execute_query(&subscription.spec, &self.pages);
                let next_map = next_rows
                    .into_iter()
                    .map(|row| (row.identity(), row))
                    .collect::<HashMap<_, _>>();
                let payload = diff_rows(
                    self.global_seq,
                    subscription.spec.kind(),
                    &subscription.last_rows,
                    &next_map,
                );
                subscription.last_rows = next_map;
                payload
            };

            if let Some(bytes) = serialize_payload(&payload) {
                subscription.pending_update = Some(bytes);
            }
            self.subscriptions.insert(subscription_id, subscription);
        }
    }

    /// Register a page-outline subscription.
    ///
    /// Returns a stable subscription id whose pending buffer initially contains a full snapshot.
    pub fn subscribe_outline(&mut self, page_id: &str) -> u64 {
        self.register_subscription(ReactiveQuerySpec::Outline {
            page_id: page_id.to_string(),
        })
    }

    /// Register a property query subscription.
    ///
    /// If `value` is `None`, all rows with the matching property key are tracked.
    pub fn subscribe_property_equals(&mut self, key: &str, value: Option<&str>) -> u64 {
        self.register_subscription(ReactiveQuerySpec::PropertyEquals {
            key: key.to_string(),
            value: value.map(str::to_string),
        })
    }

    /// Register a link traversal subscription rooted at `block_id`.
    pub fn subscribe_links(&mut self, block_id: &str, max_depth: u8) -> u64 {
        self.register_subscription(ReactiveQuerySpec::LinkedReferences {
            block_id: block_id.to_string(),
            max_depth: max_depth.max(1),
        })
    }

    /// Remove a subscription and its pending archived payload, returning whether it existed.
    pub fn unsubscribe(&mut self, subscription_id: u64) -> bool {
        self.subscriptions.remove(&subscription_id).is_some()
    }

    /// Take the latest archived diff payload for a subscription.
    ///
    /// Ownership of the returned bytes transfers to the caller.
    pub fn take_update(&mut self, subscription_id: u64) -> Option<Vec<u8>> {
        self.subscriptions
            .get_mut(&subscription_id)
            .and_then(|subscription| subscription.pending_update.take())
    }

    /// Materialize a historical snapshot for a subscription at a transaction `version`.
    ///
    /// Ownership of the returned bytes transfers to the caller.
    pub fn snapshot_bytes(
        &self,
        subscription_id: u64,
        version: u64,
        logs: &HashMap<String, OpLog>,
    ) -> Option<Vec<u8>> {
        let subscription = self.subscriptions.get(&subscription_id)?;
        let pages = self.replay_pages_at(version, logs);
        let rows = execute_query(&subscription.spec, &pages);
        let payload = SubscriptionPayload {
            version,
            kind: subscription.spec.kind(),
            added: rows,
            updated: Vec::new(),
            removed: Vec::new(),
        };
        serialize_payload(&payload)
    }

    /// Return the latest query-kernel transaction sequence.
    pub fn latest_seq(&self) -> u64 {
        self.global_seq
    }

    fn register_subscription(&mut self, spec: ReactiveQuerySpec) -> u64 {
        self.query_runs += 1;
        let rows = execute_query(&spec, &self.pages);
        let last_rows = rows
            .iter()
            .cloned()
            .map(|row| (row.identity(), row))
            .collect::<HashMap<_, _>>();
        let payload = SubscriptionPayload {
            version: self.global_seq,
            kind: spec.kind(),
            added: rows,
            updated: Vec::new(),
            removed: Vec::new(),
        };
        let subscription_id = self.next_subscription_id;
        self.next_subscription_id += 1;
        self.subscriptions.insert(
            subscription_id,
            ReactiveSubscription {
                dependencies: spec.dependencies(),
                spec,
                last_rows,
                pending_update: serialize_payload(&payload),
            },
        );
        subscription_id
    }

    #[cfg(test)]
    fn query_runs(&self) -> u64 {
        self.query_runs
    }

    fn replay_pages_at(
        &self,
        version: u64,
        logs: &HashMap<String, OpLog>,
    ) -> HashMap<String, MaterializedPage> {
        let mut page_limits = HashMap::<String, u64>::new();
        for boundary in &self.tx_boundaries {
            if boundary.global_seq > version {
                break;
            }
            page_limits.insert(boundary.page_id.clone(), boundary.page_log_seq);
        }

        let mut pages = HashMap::new();
        for (page_id, up_to_seq) in page_limits {
            let Some(log) = logs.get(&page_id) else {
                continue;
            };
            let mut tree = BlockTree::new();
            let entries = log
                .entries()
                .iter()
                .take_while(|(seq, _)| *seq <= up_to_seq)
                .cloned()
                .collect::<Vec<_>>();
            for (_, op) in &entries {
                tree.apply(op);
            }
            pages.insert(
                page_id.clone(),
                MaterializedPage::from_entries(&page_id, &tree, &entries),
            );
        }
        pages
    }
}

fn execute_query(
    spec: &ReactiveQuerySpec,
    pages: &HashMap<String, MaterializedPage>,
) -> Vec<QueryResultRow> {
    match spec {
        ReactiveQuerySpec::Outline { page_id } => execute_outline_query(page_id, pages),
        ReactiveQuerySpec::PropertyEquals { key, value } => {
            execute_property_query(key, value.as_deref(), pages)
        }
        ReactiveQuerySpec::LinkedReferences {
            block_id,
            max_depth,
        } => execute_links_query(block_id, *max_depth, pages),
    }
}

fn execute_outline_query(
    page_id: &str,
    pages: &HashMap<String, MaterializedPage>,
) -> Vec<QueryResultRow> {
    let Some(page) = pages.get(page_id) else {
        return Vec::new();
    };
    let rows = page
        .blocks
        .values()
        .map(|block| {
            vec![
                DataValue::from(block.page_id.clone()),
                DataValue::from(block.block_id.clone()),
                DataValue::from(block.parent_id.clone()),
                DataValue::from(i64::from(block.depth)),
                DataValue::from(block.order_key.clone()),
                DataValue::from(block.content.clone()),
                DataValue::from(block.task_marker.clone()),
                DataValue::from(block.task_done),
            ]
        })
        .collect::<Vec<_>>();
    let db = outline_db(rows);
    let result = db.run_script(
        "?[page, block, parent, depth, ord, content, marker, done] := *block{page, block, parent, depth, ord, content, marker, done}, page = $page :order ord",
        BTreeMap::from([("page".to_string(), DataValue::from(page_id.to_string()))]),
        ScriptMutability::Immutable,
    );
    rows_from_outline(result.ok())
}

fn execute_property_query(
    key: &str,
    value: Option<&str>,
    pages: &HashMap<String, MaterializedPage>,
) -> Vec<QueryResultRow> {
    let rows = pages
        .values()
        .flat_map(|page| {
            page.properties
                .iter()
                .map(|((block_id, property_key), property_value)| {
                    vec![
                        DataValue::from(page.blocks[block_id].page_id.clone()),
                        DataValue::from(block_id.clone()),
                        DataValue::from(property_key.clone()),
                        DataValue::from(property_value.clone()),
                    ]
                })
        })
        .collect::<Vec<_>>();
    let db = property_db(rows);
    let mut params = BTreeMap::from([("prop_key".to_string(), DataValue::from(key.to_string()))]);
    let script = if let Some(value) = value {
        params.insert("prop_value".to_string(), DataValue::from(value.to_string()));
        "?[page, block, prop_key, prop_value] := *prop{page, block, prop_key, prop_value}, prop_key = $prop_key, prop_value = $prop_value"
    } else {
        "?[page, block, prop_key, prop_value] := *prop{page, block, prop_key, prop_value}, prop_key = $prop_key"
    };
    let result = db.run_script(script, params, ScriptMutability::Immutable);
    rows_from_property(result.ok())
}

fn execute_links_query(
    block_id: &str,
    max_depth: u8,
    pages: &HashMap<String, MaterializedPage>,
) -> Vec<QueryResultRow> {
    if max_depth == 0 {
        return Vec::new();
    }

    let mut adjacency = HashMap::<&str, Vec<&MaterializedLink>>::new();
    for page in pages.values() {
        for link in &page.links {
            adjacency
                .entry(link.block_id.as_str())
                .or_default()
                .push(link);
        }
    }

    let mut frontier = vec![block_id.to_string()];
    let mut results = Vec::new();
    let mut seen = HashSet::<(String, u8, u8)>::new();

    for hop in 1..=max_depth {
        if frontier.is_empty() {
            break;
        }

        let mut next_frontier = Vec::new();
        for source in frontier {
            let Some(links) = adjacency.get(source.as_str()) else {
                continue;
            };
            for link in links {
                let dedupe_key = (link.target_id.clone(), hop, link.ref_type);
                if !seen.insert(dedupe_key) {
                    continue;
                }
                next_frontier.push(link.target_id.clone());
                results.push(QueryResultRow {
                    target_id: link.target_id.clone(),
                    hop_count: hop,
                    ref_type: link.ref_type,
                    page_id: String::new(),
                    block_id: String::new(),
                    parent_id: String::new(),
                    content: String::new(),
                    property_key: String::new(),
                    property_value: String::new(),
                    task_marker: String::new(),
                    order_key: String::new(),
                    depth: 0,
                    task_done: false,
                });
            }
        }
        frontier = next_frontier;
    }

    results.sort_by(|left, right| {
        left.hop_count
            .cmp(&right.hop_count)
            .then_with(|| left.target_id.cmp(&right.target_id))
            .then_with(|| left.ref_type.cmp(&right.ref_type))
    });
    results
}

fn outline_db(rows: Vec<Vec<DataValue>>) -> DbInstance {
    let db = DbInstance::new("mem", "", "").expect("Cozo mem DB should initialize");
    db.run_default(
        ":create block {page: String, block: String => parent: String, depth: Int, ord: String, content: String, marker: String, done: Bool}",
    )
    .expect("outline relation should create");
    if !rows.is_empty() {
        let mut to_import = BTreeMap::new();
        to_import.insert(
            "block".to_string(),
            NamedRows {
                headers: vec![
                    "page".to_string(),
                    "block".to_string(),
                    "parent".to_string(),
                    "depth".to_string(),
                    "ord".to_string(),
                    "content".to_string(),
                    "marker".to_string(),
                    "done".to_string(),
                ],
                rows,
                next: None,
            },
        );
        db.import_relations(to_import)
            .expect("outline relation should import");
    }
    db
}

fn property_db(rows: Vec<Vec<DataValue>>) -> DbInstance {
    let db = DbInstance::new("mem", "", "").expect("Cozo mem DB should initialize");
    db.run_default(
        ":create prop {page: String, block: String, prop_key: String => prop_value: String}",
    )
    .expect("property relation should create");
    if !rows.is_empty() {
        let mut to_import = BTreeMap::new();
        to_import.insert(
            "prop".to_string(),
            NamedRows {
                headers: vec![
                    "page".to_string(),
                    "block".to_string(),
                    "prop_key".to_string(),
                    "prop_value".to_string(),
                ],
                rows,
                next: None,
            },
        );
        db.import_relations(to_import)
            .expect("property relation should import");
    }
    db
}

fn refresh_subscription_incrementally(
    version: u64,
    page_id: &str,
    current_page: &MaterializedPage,
    spec: &ReactiveQuerySpec,
    changed: &ChangedFacts,
    last_rows: &mut HashMap<String, QueryResultRow>,
) -> Option<SubscriptionPayload> {
    match spec {
        ReactiveQuerySpec::Outline {
            page_id: filter_page_id,
        } => (filter_page_id == page_id).then(|| {
            let mut added = Vec::new();
            let mut updated = Vec::new();
            let mut removed = Vec::new();
            for block_id in &changed.block_ids {
                let previous_identity = last_rows.iter().find_map(|(identity, row)| {
                    (row.block_id == *block_id).then_some(identity.clone())
                });
                let previous = previous_identity
                    .as_ref()
                    .and_then(|identity| last_rows.remove(identity));
                let next = current_page.blocks.get(block_id).map(outline_result_row);
                apply_incremental_query_row_change(
                    last_rows,
                    previous,
                    next,
                    &mut added,
                    &mut updated,
                    &mut removed,
                );
            }
            Some(payload_from_delta(
                version,
                spec.kind(),
                added,
                updated,
                removed,
            ))
        })?,
        ReactiveQuerySpec::PropertyEquals { key, value } => {
            let mut added = Vec::new();
            let mut updated = Vec::new();
            let mut removed = Vec::new();
            for (block_id, property_key) in &changed.property_rows {
                if property_key != key {
                    continue;
                }
                let identity = property_identity(page_id, block_id, property_key);
                let previous = last_rows.remove(&identity);
                let next = current_page
                    .properties
                    .get(&(block_id.clone(), property_key.clone()))
                    .and_then(|property_value| {
                        value.as_deref().map_or(
                            Some(property_result_row(
                                page_id,
                                block_id,
                                property_key,
                                property_value,
                            )),
                            |filter_value| {
                                (property_value == filter_value).then(|| {
                                    property_result_row(
                                        page_id,
                                        block_id,
                                        property_key,
                                        property_value,
                                    )
                                })
                            },
                        )
                    });
                apply_incremental_query_row_change(
                    last_rows,
                    previous,
                    next,
                    &mut added,
                    &mut updated,
                    &mut removed,
                );
            }
            Some(payload_from_delta(
                version,
                spec.kind(),
                added,
                updated,
                removed,
            ))
        }
        ReactiveQuerySpec::LinkedReferences { .. } => None,
    }
}

fn payload_from_delta(
    version: u64,
    kind: u8,
    mut added: Vec<QueryResultRow>,
    mut updated: Vec<QueryResultRow>,
    mut removed: Vec<QueryResultRow>,
) -> SubscriptionPayload {
    added.sort_by_key(QueryResultRow::identity);
    updated.sort_by_key(QueryResultRow::identity);
    removed.sort_by_key(QueryResultRow::identity);
    SubscriptionPayload {
        version,
        kind,
        added,
        updated,
        removed,
    }
}

fn apply_incremental_query_row_change(
    last_rows: &mut HashMap<String, QueryResultRow>,
    previous: Option<QueryResultRow>,
    next: Option<QueryResultRow>,
    added: &mut Vec<QueryResultRow>,
    updated: &mut Vec<QueryResultRow>,
    removed: &mut Vec<QueryResultRow>,
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
            if previous_row != next_row {
                updated.push(next_row.clone());
            }
            last_rows.insert(next_row.identity(), next_row);
        }
    }
}

fn outline_result_row(block: &MaterializedBlock) -> QueryResultRow {
    QueryResultRow {
        page_id: block.page_id.clone(),
        block_id: block.block_id.clone(),
        parent_id: block.parent_id.clone(),
        target_id: String::new(),
        content: block.content.clone(),
        property_key: String::new(),
        property_value: String::new(),
        task_marker: block.task_marker.clone(),
        order_key: block.order_key.clone(),
        depth: block.depth,
        ref_type: 0,
        task_done: block.task_done,
        hop_count: 0,
    }
}

fn property_identity(page_id: &str, block_id: &str, property_key: &str) -> String {
    format!("{page_id}|{block_id}|||{property_key}|0")
}

fn property_result_row(
    page_id: &str,
    block_id: &str,
    property_key: &str,
    property_value: &str,
) -> QueryResultRow {
    QueryResultRow {
        page_id: page_id.to_string(),
        block_id: block_id.to_string(),
        parent_id: String::new(),
        target_id: String::new(),
        content: String::new(),
        property_key: property_key.to_string(),
        property_value: property_value.to_string(),
        task_marker: String::new(),
        order_key: String::new(),
        depth: 0,
        ref_type: 0,
        task_done: false,
        hop_count: 0,
    }
}

fn rows_from_outline(result: Option<NamedRows>) -> Vec<QueryResultRow> {
    let Some(result) = result else {
        return Vec::new();
    };
    result
        .rows
        .into_iter()
        .filter_map(|row| {
            Some(QueryResultRow {
                page_id: row.first()?.get_str()?.to_string(),
                block_id: row.get(1)?.get_str()?.to_string(),
                parent_id: row.get(2)?.get_str()?.to_string(),
                depth: row.get(3)?.get_int()? as u16,
                order_key: row.get(4)?.get_str()?.to_string(),
                content: row.get(5)?.get_str()?.to_string(),
                task_marker: row.get(6)?.get_str()?.to_string(),
                task_done: row.get(7)?.get_bool()?,
                target_id: String::new(),
                property_key: String::new(),
                property_value: String::new(),
                ref_type: 0,
                hop_count: 0,
            })
        })
        .collect()
}

fn rows_from_property(result: Option<NamedRows>) -> Vec<QueryResultRow> {
    let Some(result) = result else {
        return Vec::new();
    };
    result
        .rows
        .into_iter()
        .filter_map(|row| {
            Some(QueryResultRow {
                page_id: row.first()?.get_str()?.to_string(),
                block_id: row.get(1)?.get_str()?.to_string(),
                property_key: row.get(2)?.get_str()?.to_string(),
                property_value: row.get(3)?.get_str()?.to_string(),
                parent_id: String::new(),
                target_id: String::new(),
                content: String::new(),
                task_marker: String::new(),
                order_key: String::new(),
                depth: 0,
                ref_type: 0,
                task_done: false,
                hop_count: 0,
            })
        })
        .collect()
}

fn diff_rows(
    version: u64,
    kind: u8,
    previous: &HashMap<String, QueryResultRow>,
    next: &HashMap<String, QueryResultRow>,
) -> SubscriptionPayload {
    let mut added = Vec::new();
    let mut updated = Vec::new();
    let mut removed = Vec::new();

    for (identity, row) in next {
        match previous.get(identity) {
            None => added.push(row.clone()),
            Some(previous_row) if previous_row != row => updated.push(row.clone()),
            _ => {}
        }
    }
    for (identity, row) in previous {
        if !next.contains_key(identity) {
            removed.push(row.clone());
        }
    }

    added.sort_by_key(QueryResultRow::identity);
    updated.sort_by_key(QueryResultRow::identity);
    removed.sort_by_key(QueryResultRow::identity);

    SubscriptionPayload {
        version,
        kind,
        added,
        updated,
        removed,
    }
}

fn serialize_payload(payload: &SubscriptionPayload) -> Option<Vec<u8>> {
    rkyv::to_bytes::<rkyv::rancor::Error>(payload)
        .ok()
        .map(|bytes| bytes.to_vec())
}

fn parse_task_state(content: &str) -> (String, bool) {
    let trimmed = content.trim_start();
    if let Some(rest) = trimmed.strip_prefix("TODO ") {
        return ("TODO".to_string(), rest.is_empty() && false);
    }
    if trimmed.starts_with("DONE ") {
        return ("DONE".to_string(), true);
    }
    if trimmed.starts_with("- [ ]") {
        return ("TODO".to_string(), false);
    }
    if trimmed.starts_with("- [x]") || trimmed.starts_with("- [X]") {
        return ("DONE".to_string(), true);
    }
    (String::new(), false)
}

fn parse_inline_links(content: &str) -> Vec<String> {
    let bytes = content.as_bytes();
    let mut start = 0usize;
    let mut targets = Vec::new();
    while let Some(open) = memmem::find(&bytes[start..], b"[[") {
        let link_start = start + open + 2;
        let Some(close) = memmem::find(&bytes[link_start..], b"]]") else {
            break;
        };
        let link_end = link_start + close;
        if link_end > link_start {
            targets.push(String::from_utf8_lossy(&bytes[link_start..link_end]).to_string());
        }
        start = link_end + 2;
    }
    targets
}

fn property_value_string(value: &PropertyValue) -> String {
    match value {
        PropertyValue::String(value) => value.clone(),
        PropertyValue::Float(value) => format!("{value}"),
        PropertyValue::Int(value) => value.to_string(),
        PropertyValue::Bool(value) => value.to_string(),
        PropertyValue::Null => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;
    use std::time::Instant;

    use super::{BtkQueryKernel, QueryResultRow, ReactiveQuerySpec, SubscriptionPayload};
    use crate::block_kernel::op::{BlockId, Op, PropertyValue};
    use crate::block_kernel::{BlockTree, OpLog};

    fn seed_page() -> (BlockTree, OpLog, BlockId, BlockId) {
        let page = BlockId::new();
        let child = BlockId::new();
        let mut tree = BlockTree::new();
        let mut log = OpLog::new();

        for op in [
            Op::InsertBlock {
                block_id: page,
                parent_id: None,
                position: 0,
                content: "TODO Root [[child-ref]]".into(),
                depth: 0,
            },
            Op::InsertBlock {
                block_id: child,
                parent_id: Some(page),
                position: 0,
                content: "child @tag=research".into(),
                depth: 1,
            },
            Op::SetProperty {
                block_id: child,
                key: "priority".into(),
                value: PropertyValue::String("high".into()),
            },
            Op::SetRef {
                block_id: child,
                target_id: BlockId::new(),
                ref_type: 4,
            },
        ] {
            tree.apply(&op);
            log.append(op);
        }

        (tree, log, page, child)
    }

    fn decode(bytes: &[u8]) -> SubscriptionPayload {
        let archived =
            rkyv::access::<rkyv::Archived<SubscriptionPayload>, rkyv::rancor::Error>(bytes)
                .expect("archived payload should decode");
        rkyv::deserialize::<SubscriptionPayload, rkyv::rancor::Error>(archived)
            .expect("payload should deserialize")
    }

    fn seed_large_page(block_count: usize) -> (BlockTree, OpLog, BlockId, BlockId) {
        let page = BlockId::new();
        let target = BlockId::new();
        let mut tree = BlockTree::new();
        let mut log = OpLog::new();

        let root = Op::InsertBlock {
            block_id: page,
            parent_id: None,
            position: 0,
            content: "Root".into(),
            depth: 0,
        };
        tree.apply(&root);
        log.append(root);

        for idx in 0..block_count {
            let block_id = if idx == 0 { target } else { BlockId::new() };
            let insert = Op::InsertBlock {
                block_id,
                parent_id: Some(page),
                position: idx as u32,
                content: format!("Child {idx}"),
                depth: 1,
            };
            tree.apply(&insert);
            log.append(insert);

            let property = Op::SetProperty {
                block_id,
                key: "priority".into(),
                value: PropertyValue::String(if idx % 2 == 0 { "high" } else { "low" }.into()),
            };
            tree.apply(&property);
            log.append(property);
        }

        (tree, log, page, target)
    }

    #[test]
    fn property_subscription_only_reruns_for_matching_keys() {
        let (mut tree, mut log, _, child) = seed_page();
        let mut kernel = BtkQueryKernel::new();
        kernel.sync_page("page-a", &tree, &log);
        let sub_id = kernel.subscribe_property_equals("priority", Some("high"));
        let initial = kernel
            .take_update(sub_id)
            .expect("initial subscription payload should exist");
        let initial_payload = decode(&initial);
        assert_eq!(initial_payload.added.len(), 1);

        let unrelated = Op::SetProperty {
            block_id: child,
            key: "owner".into(),
            value: PropertyValue::String("jojo".into()),
        };
        tree.apply(&unrelated);
        log.append(unrelated);
        kernel.sync_page("page-a", &tree, &log);
        assert!(kernel.take_update(sub_id).is_none());

        let related = Op::SetProperty {
            block_id: child,
            key: "priority".into(),
            value: PropertyValue::String("low".into()),
        };
        tree.apply(&related);
        log.append(related);
        kernel.sync_page("page-a", &tree, &log);
        let updated = kernel
            .take_update(sub_id)
            .expect("matching property update should rerun subscription");
        let updated_payload = decode(&updated);
        assert_eq!(updated_payload.removed.len(), 1);
    }

    #[test]
    fn matching_property_updates_do_not_reexecute_full_query() {
        let (mut tree, mut log, _, child) = seed_page();
        let mut kernel = BtkQueryKernel::new();
        kernel.sync_page("page-a", &tree, &log);
        let sub_id = kernel.subscribe_property_equals("priority", Some("high"));
        let _ = kernel.take_update(sub_id);
        let query_runs_before = kernel.query_runs();

        let related = Op::SetProperty {
            block_id: child,
            key: "priority".into(),
            value: PropertyValue::String("low".into()),
        };
        tree.apply(&related);
        log.append(related);
        kernel.sync_page("page-a", &tree, &log);

        assert_eq!(kernel.query_runs(), query_runs_before);
        let updated = kernel
            .take_update(sub_id)
            .expect("matching property update should still emit diff");
        let updated_payload = decode(&updated);
        assert_eq!(updated_payload.removed.len(), 1);
    }

    #[test]
    fn snapshot_replays_historical_property_state() {
        let (mut tree, mut log, _, child) = seed_page();
        let mut kernel = BtkQueryKernel::new();
        kernel.sync_page("page-a", &tree, &log);
        let version_one = kernel.latest_seq();
        let sub_id = kernel.subscribe_property_equals("priority", None);
        let _ = kernel.take_update(sub_id);

        let update = Op::SetProperty {
            block_id: child,
            key: "priority".into(),
            value: PropertyValue::String("critical".into()),
        };
        tree.apply(&update);
        log.append(update);
        kernel.sync_page("page-a", &tree, &log);

        let snapshot = kernel
            .snapshot_bytes(
                sub_id,
                version_one,
                &HashMap::from([("page-a".into(), log)]),
            )
            .expect("snapshot bytes should exist");
        let payload = decode(&snapshot);
        assert_eq!(payload.added.len(), 1);
        assert_eq!(payload.added[0].property_value, "high");
    }

    #[test]
    fn link_subscription_emits_diff_when_references_change() {
        let (mut tree, mut log, page, _) = seed_page();
        let mut kernel = BtkQueryKernel::new();
        kernel.sync_page("page-a", &tree, &log);
        let sub_id = kernel.subscribe_links(&page.to_uuid_string(), 2);
        let initial = kernel
            .take_update(sub_id)
            .expect("initial link payload should exist");
        let initial_payload = decode(&initial);
        assert!(!initial_payload.added.is_empty());

        let new_target = BlockId::new();
        let link = Op::SetRef {
            block_id: page,
            target_id: new_target,
            ref_type: 1,
        };
        tree.apply(&link);
        log.append(link);
        kernel.sync_page("page-a", &tree, &log);

        let updated = kernel
            .take_update(sub_id)
            .expect("link update should rerun subscription");
        let payload = decode(&updated);
        assert!(
            payload
                .added
                .iter()
                .any(|row| row.target_id == new_target.to_uuid_string())
        );
    }

    #[test]
    fn snapshot_replays_historical_link_state() {
        let (mut tree, mut log, page, _) = seed_page();
        let mut kernel = BtkQueryKernel::new();
        kernel.sync_page("page-a", &tree, &log);
        let version_one = kernel.latest_seq();
        let sub_id = kernel.subscribe_links(&page.to_uuid_string(), 2);
        let _ = kernel.take_update(sub_id);

        let new_target = BlockId::new();
        let update = Op::SetRef {
            block_id: page,
            target_id: new_target,
            ref_type: 2,
        };
        tree.apply(&update);
        log.append(update);
        kernel.sync_page("page-a", &tree, &log);

        let snapshot = kernel
            .snapshot_bytes(
                sub_id,
                version_one,
                &HashMap::from([("page-a".into(), log)]),
            )
            .expect("snapshot bytes should exist");
        let payload = decode(&snapshot);
        assert!(
            payload
                .added
                .iter()
                .all(|row| row.target_id != new_target.to_uuid_string())
        );
    }

    #[test]
    #[ignore = "benchmark"]
    fn benchmark_link_subscription_refresh() {
        const BLOCK_COUNT: usize = 400;
        const ITERATIONS: usize = 300;

        let (mut tree, mut log, page, target) = seed_large_page(BLOCK_COUNT);
        let mut kernel = BtkQueryKernel::new();
        kernel.sync_page("page-a", &tree, &log);
        let sub_id = kernel.subscribe_links(&page.to_uuid_string(), 2);
        let _ = kernel.take_update(sub_id);

        let start = Instant::now();
        for idx in 0..ITERATIONS {
            let update = Op::SetRef {
                block_id: target,
                target_id: BlockId::new(),
                ref_type: (idx % 4) as u8,
            };
            tree.apply(&update);
            log.append(update);
            kernel.sync_page("page-a", &tree, &log);
            let _ = kernel.take_update(sub_id);
        }
        let elapsed = start.elapsed();
        let ns_per_tx = elapsed.as_nanos() as f64 / ITERATIONS as f64;
        println!(
            "btk_link_subscription_refresh ns_per_tx={}",
            ns_per_tx.round() as u64
        );
    }

    #[test]
    #[ignore = "benchmark"]
    fn benchmark_property_subscription_incremental_refresh() {
        const BLOCK_COUNT: usize = 400;
        const ITERATIONS: usize = 300;

        let (mut tree, mut log, _, target) = seed_large_page(BLOCK_COUNT);
        let mut kernel = BtkQueryKernel::new();
        kernel.sync_page("page-a", &tree, &log);
        let sub_id = kernel.subscribe_property_equals("priority", Some("high"));
        let _ = kernel.take_update(sub_id);

        let incremental_start = Instant::now();
        for idx in 0..ITERATIONS {
            let value = if idx % 2 == 0 { "low" } else { "high" };
            let op = Op::SetProperty {
                block_id: target,
                key: "priority".into(),
                value: PropertyValue::String(value.into()),
            };
            tree.apply(&op);
            log.append(op);
            kernel.sync_page("page-a", &tree, &log);
            let _ = kernel.take_update(sub_id);
        }
        let incremental_elapsed = incremental_start.elapsed();

        let (mut tree, mut log, _, target) = seed_large_page(BLOCK_COUNT);
        let mut control = BtkQueryKernel::new();
        control.sync_page("page-a", &tree, &log);
        let spec = ReactiveQuerySpec::PropertyEquals {
            key: "priority".to_string(),
            value: Some("high".to_string()),
        };
        let initial_rows = super::execute_query(&spec, &control.pages);
        let mut last_rows = initial_rows
            .into_iter()
            .map(|row| (row.identity(), row))
            .collect::<HashMap<String, QueryResultRow>>();

        let full_rerun_start = Instant::now();
        for idx in 0..ITERATIONS {
            let value = if idx % 2 == 0 { "low" } else { "high" };
            let op = Op::SetProperty {
                block_id: target,
                key: "priority".into(),
                value: PropertyValue::String(value.into()),
            };
            tree.apply(&op);
            log.append(op);
            control.sync_page("page-a", &tree, &log);
            let next_rows = super::execute_query(&spec, &control.pages);
            let next_map = next_rows
                .into_iter()
                .map(|row| (row.identity(), row))
                .collect::<HashMap<_, _>>();
            let _ = super::diff_rows(control.global_seq, spec.kind(), &last_rows, &next_map);
            last_rows = next_map;
        }
        let full_rerun_elapsed = full_rerun_start.elapsed();

        let incremental_ns = incremental_elapsed.as_nanos() as f64 / ITERATIONS as f64;
        let full_rerun_ns = full_rerun_elapsed.as_nanos() as f64 / ITERATIONS as f64;
        println!(
            "btk_property_watcher incremental_ns_per_tx={} full_rerun_ns_per_tx={} speedup_x={:.2}",
            incremental_ns.round() as u64,
            full_rerun_ns.round() as u64,
            full_rerun_ns / incremental_ns
        );
    }
}
