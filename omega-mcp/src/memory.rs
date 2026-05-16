//! Memory MCP executor for `epistemos.{soul,skill,episode,semantic}.v1`.
//!
//! Source: `agent_core/schemas/epistemos.soul.v1.schema.json`
//! Source: `agent_core/schemas/epistemos.skill.v1.schema.json`
//! Source: `agent_core/schemas/epistemos.episode.v1.schema.json`
//! Source: `agent_core/schemas/epistemos.semantic.v1.schema.json`

use crate::types::ToolResult;
use serde_json::Value;
use std::fs;
use std::path::PathBuf;
use std::time::Instant;

const MAX_RECORD_BYTES: usize = 256 * 1024;
const DEFAULT_LIMIT: usize = 50;
const MAX_LIMIT: usize = 100;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum MemorySchema {
    Soul,
    Skill,
    Episode,
    Semantic,
}

impl MemorySchema {
    const ALL: [Self; 4] = [Self::Soul, Self::Skill, Self::Episode, Self::Semantic];

    fn parse(value: &str) -> Result<Self, String> {
        match value {
            "epistemos.soul.v1" => Ok(Self::Soul),
            "epistemos.skill.v1" => Ok(Self::Skill),
            "epistemos.episode.v1" => Ok(Self::Episode),
            "epistemos.semantic.v1" => Ok(Self::Semantic),
            _ => Err(format!(
                "unknown schema_rev `{value}`; expected epistemos.soul.v1, epistemos.skill.v1, epistemos.episode.v1, or epistemos.semantic.v1"
            )),
        }
    }

    fn name(self) -> &'static str {
        match self {
            Self::Soul => "epistemos.soul.v1",
            Self::Skill => "epistemos.skill.v1",
            Self::Episode => "epistemos.episode.v1",
            Self::Semantic => "epistemos.semantic.v1",
        }
    }

    fn filename(self) -> &'static str {
        match self {
            Self::Soul => "soul.jsonl",
            Self::Skill => "skill.jsonl",
            Self::Episode => "episode.jsonl",
            Self::Semantic => "semantic.jsonl",
        }
    }

    fn id_key(self) -> &'static str {
        match self {
            Self::Soul => "soul_id",
            Self::Skill => "skill_id",
            Self::Episode => "episode_id",
            Self::Semantic => "fact_id",
        }
    }

    fn required_keys(self) -> &'static [&'static str] {
        match self {
            Self::Soul => &[
                "schema_rev",
                "soul_id",
                "model_id",
                "identity",
                "preferences",
                "updated_at",
            ],
            Self::Skill => &[
                "schema_rev",
                "skill_id",
                "name",
                "description",
                "body",
                "created_at",
            ],
            Self::Episode => &["schema_rev", "episode_id", "occurred_at", "kind", "content"],
            Self::Semantic => &[
                "schema_rev",
                "fact_id",
                "predicate",
                "subject",
                "object",
                "confidence",
                "claim_kind",
            ],
        }
    }

    fn allowed_keys(self) -> &'static [&'static str] {
        match self {
            Self::Soul => &[
                "schema_rev",
                "soul_id",
                "model_id",
                "identity",
                "preferences",
                "instructions",
                "knowledge_profile",
                "updated_at",
                "updated_by",
            ],
            Self::Skill => &[
                "schema_rev",
                "skill_id",
                "name",
                "description",
                "body",
                "tags",
                "requires_capabilities",
                "created_at",
                "updated_at",
                "discovered_via",
                "execution_count",
                "success_count",
            ],
            Self::Episode => &[
                "schema_rev",
                "episode_id",
                "occurred_at",
                "recorded_at",
                "kind",
                "actor",
                "content",
                "context",
                "salience",
                "tags",
                "linked_episodes",
            ],
            Self::Semantic => &[
                "schema_rev",
                "fact_id",
                "predicate",
                "subject",
                "object",
                "confidence",
                "claim_kind",
                "evidence",
                "established_at",
                "updated_at",
                "retracted_at",
                "retracts",
                "derives_from",
                "tags",
            ],
        }
    }

    fn append_only(self) -> bool {
        matches!(self, Self::Episode | Self::Semantic)
    }
}

pub struct MemoryExecutor {
    root: PathBuf,
}

impl MemoryExecutor {
    pub fn new(vault_root: &str) -> Option<Self> {
        let root = PathBuf::from(vault_root).canonicalize().ok()?;
        if root.is_dir() {
            Some(Self { root })
        } else {
            None
        }
    }

    fn put(&self, payload: Value, replace: bool) -> ToolResult {
        let start = Instant::now();
        let schema = match validate_payload(&payload) {
            Ok(schema) => schema,
            Err(error) => {
                return ToolResult::err(
                    error,
                    crate::types::error_codes::INVALID_INPUT,
                    start.elapsed().as_millis() as u64,
                )
            }
        };
        let id = match payload_id(schema, &payload) {
            Ok(id) => id,
            Err(error) => {
                return ToolResult::err(
                    error,
                    crate::types::error_codes::INVALID_INPUT,
                    start.elapsed().as_millis() as u64,
                )
            }
        };

        let mut records = match self.read_records(schema) {
            Ok(records) => records,
            Err(result) => return result,
        };
        let existing = records
            .iter()
            .position(|record| payload_id(schema, record).ok().as_deref() == Some(id.as_str()));
        let replaced = existing.is_some();

        match existing {
            Some(_) if schema.append_only() => {
                return ToolResult::err(
                    format!(
                        "{} is append-only; write a new id and use retracts/linked records instead",
                        schema.name()
                    ),
                    crate::types::error_codes::INVALID_INPUT,
                    start.elapsed().as_millis() as u64,
                )
            }
            Some(_) if !replace => {
                return ToolResult::err(
                    format!(
                        "memory id `{id}` already exists; pass replace=true for mutable schemas"
                    ),
                    crate::types::error_codes::INVALID_INPUT,
                    start.elapsed().as_millis() as u64,
                )
            }
            Some(index) => records[index] = payload,
            None => records.push(payload),
        }

        if let Err(result) = self.write_records(schema, &records, start) {
            return result;
        }

        ToolResult::ok(
            serde_json::json!({
                "tool": "memory.put",
                "schema_rev": schema.name(),
                "id": id,
                "replaced": replaced,
                "count": records.len(),
            })
            .to_string(),
            start.elapsed().as_millis() as u64,
        )
    }

    fn get(&self, schema: MemorySchema, id: &str) -> ToolResult {
        let start = Instant::now();
        if !valid_id(id) {
            return ToolResult::err(
                format!(
                    "{} must be a 12-char lowercase alphanumeric id",
                    schema.id_key()
                ),
                crate::types::error_codes::INVALID_INPUT,
                start.elapsed().as_millis() as u64,
            );
        }

        match self.read_records(schema) {
            Ok(records) => match records
                .into_iter()
                .find(|record| payload_id(schema, record).ok().as_deref() == Some(id))
            {
                Some(payload) => ToolResult::ok(
                    serde_json::json!({
                        "tool": "memory.get",
                        "schema_rev": schema.name(),
                        "id": id,
                        "payload": payload,
                    })
                    .to_string(),
                    start.elapsed().as_millis() as u64,
                ),
                None => ToolResult::err(
                    format!("memory id `{id}` not found in {}", schema.name()),
                    crate::types::error_codes::NOT_FOUND,
                    start.elapsed().as_millis() as u64,
                ),
            },
            Err(result) => result,
        }
    }

    fn search(&self, schema: Option<MemorySchema>, query: &str, limit: usize) -> ToolResult {
        let start = Instant::now();
        let query = query.trim();
        if query.is_empty() {
            return ToolResult::err(
                "query is required".to_string(),
                crate::types::error_codes::INVALID_INPUT,
                start.elapsed().as_millis() as u64,
            );
        }

        let query_lower = query.to_lowercase();
        let limit = limit.clamp(1, MAX_LIMIT);
        let mut hits = Vec::with_capacity(limit);
        for current_schema in
            schema.map_or_else(|| MemorySchema::ALL.to_vec(), |schema| vec![schema])
        {
            let records = match self.read_records(current_schema) {
                Ok(records) => records,
                Err(result) => return result,
            };
            for payload in records {
                if hits.len() >= limit {
                    break;
                }
                if payload.to_string().to_lowercase().contains(&query_lower) {
                    let id = payload_id(current_schema, &payload).unwrap_or_default();
                    hits.push(serde_json::json!({
                        "schema_rev": current_schema.name(),
                        "id": id,
                        "payload": payload,
                    }));
                }
            }
        }

        ToolResult::ok(
            serde_json::json!({
                "tool": "memory.search",
                "query": query,
                "count": hits.len(),
                "hits": hits,
            })
            .to_string(),
            start.elapsed().as_millis() as u64,
        )
    }

    fn list(&self, schema: Option<MemorySchema>, limit: usize) -> ToolResult {
        let start = Instant::now();
        let limit = limit.clamp(1, MAX_LIMIT);
        let mut entries = Vec::with_capacity(limit);

        for current_schema in
            schema.map_or_else(|| MemorySchema::ALL.to_vec(), |schema| vec![schema])
        {
            let records = match self.read_records(current_schema) {
                Ok(records) => records,
                Err(result) => return result,
            };
            for payload in records {
                if entries.len() >= limit {
                    break;
                }
                let id = payload_id(current_schema, &payload).unwrap_or_default();
                entries.push(serde_json::json!({
                    "schema_rev": current_schema.name(),
                    "id": id,
                    "payload": payload,
                }));
            }
        }

        ToolResult::ok(
            serde_json::json!({
                "tool": "memory.list",
                "count": entries.len(),
                "entries": entries,
            })
            .to_string(),
            start.elapsed().as_millis() as u64,
        )
    }

    fn memory_dir(&self) -> PathBuf {
        self.root.join(".epistemos").join("memory")
    }

    fn memory_file(&self, schema: MemorySchema) -> PathBuf {
        self.memory_dir().join(schema.filename())
    }

    fn read_records(&self, schema: MemorySchema) -> Result<Vec<Value>, ToolResult> {
        let path = self.memory_file(schema);
        let content = match fs::read_to_string(&path) {
            Ok(content) => content,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
            Err(error) => {
                return Err(ToolResult::err(
                    format!("Cannot read memory store {}: {error}", path.display()),
                    crate::types::error_codes::EXECUTION_ERROR,
                    0,
                ))
            }
        };

        let mut records = Vec::new();
        for (index, line) in content.lines().enumerate() {
            if line.trim().is_empty() {
                continue;
            }
            let value: Value = serde_json::from_str(line).map_err(|error| {
                ToolResult::err(
                    format!(
                        "Malformed memory record in {} line {}: {error}",
                        path.display(),
                        index + 1
                    ),
                    crate::types::error_codes::EXECUTION_ERROR,
                    0,
                )
            })?;
            if let Err(error) = validate_payload(&value) {
                return Err(ToolResult::err(
                    format!(
                        "Invalid memory record in {} line {}: {error}",
                        path.display(),
                        index + 1
                    ),
                    crate::types::error_codes::EXECUTION_ERROR,
                    0,
                ));
            }
            records.push(value);
        }
        Ok(records)
    }

    fn write_records(
        &self,
        schema: MemorySchema,
        records: &[Value],
        start: Instant,
    ) -> Result<(), ToolResult> {
        let dir = self.memory_dir();
        fs::create_dir_all(&dir).map_err(|error| {
            ToolResult::err(
                format!("Cannot create memory store {}: {error}", dir.display()),
                crate::types::error_codes::EXECUTION_ERROR,
                start.elapsed().as_millis() as u64,
            )
        })?;

        let path = self.memory_file(schema);
        let tmp_path = path.with_extension("tmp");
        let mut out = String::new();
        for record in records {
            let line = serde_json::to_string(record).map_err(|error| {
                ToolResult::err(
                    format!("Cannot serialize memory record: {error}"),
                    crate::types::error_codes::EXECUTION_ERROR,
                    start.elapsed().as_millis() as u64,
                )
            })?;
            out.push_str(&line);
            out.push('\n');
        }

        fs::write(&tmp_path, out).map_err(|error| {
            ToolResult::err(
                format!(
                    "Cannot write memory temp file {}: {error}",
                    tmp_path.display()
                ),
                crate::types::error_codes::EXECUTION_ERROR,
                start.elapsed().as_millis() as u64,
            )
        })?;
        fs::rename(&tmp_path, &path).map_err(|error| {
            ToolResult::err(
                format!(
                    "Cannot commit memory store {} from {}: {error}",
                    path.display(),
                    tmp_path.display()
                ),
                crate::types::error_codes::EXECUTION_ERROR,
                start.elapsed().as_millis() as u64,
            )
        })?;
        Ok(())
    }
}

pub fn execute_memory_tool(vault_root: String, tool_name: String, args_json: String) -> String {
    let start = Instant::now();
    let executor = match MemoryExecutor::new(&vault_root) {
        Some(executor) => executor,
        None => {
            let result = ToolResult::err(
                format!("Invalid vault root: {vault_root}"),
                crate::types::error_codes::INVALID_INPUT,
                start.elapsed().as_millis() as u64,
            );
            return serde_json::to_string(&result).unwrap_or_default();
        }
    };

    let args = match parse_args(&args_json, start) {
        Ok(args) => args,
        Err(result) => return serde_json::to_string(&result).unwrap_or_default(),
    };

    let result = match tool_name.as_str() {
        "memory.put" | "memory_put" => {
            let payload = args.get("payload").cloned().unwrap_or_else(|| args.clone());
            let replace = optional_bool(&args, "replace").unwrap_or(false);
            executor.put(payload, replace)
        }
        "memory.get" | "memory_get" => match schema_arg(&args)
            .and_then(|schema| required_str(&args, "id").map(|id| (schema, id.to_string())))
        {
            Ok((schema, id)) => executor.get(schema, &id),
            Err(error) => invalid_input(error, start),
        },
        "memory.search" | "memory_search" => {
            let schema = match optional_schema_arg(&args) {
                Ok(schema) => schema,
                Err(error) => {
                    return serde_json::to_string(&invalid_input(error, start)).unwrap_or_default()
                }
            };
            match required_str(&args, "query") {
                Ok(query) => executor.search(schema, query, limit_arg(&args)),
                Err(error) => invalid_input(error, start),
            }
        }
        "memory.list" | "memory_list" => match optional_schema_arg(&args) {
            Ok(schema) => executor.list(schema, limit_arg(&args)),
            Err(error) => invalid_input(error, start),
        },
        _ => ToolResult::err(
            format!("Unknown memory tool: {tool_name}"),
            crate::types::error_codes::NOT_FOUND,
            start.elapsed().as_millis() as u64,
        ),
    };

    serde_json::to_string(&result).unwrap_or_default()
}

fn parse_args(args_json: &str, start: Instant) -> Result<Value, ToolResult> {
    serde_json::from_str(args_json).map_err(|error| {
        ToolResult::err(
            format!("Invalid JSON arguments: {error}"),
            crate::types::error_codes::INVALID_INPUT,
            start.elapsed().as_millis() as u64,
        )
    })
}

fn schema_arg(args: &Value) -> Result<MemorySchema, String> {
    let schema = required_str(args, "schema_rev")?;
    MemorySchema::parse(schema)
}

fn optional_schema_arg(args: &Value) -> Result<Option<MemorySchema>, String> {
    match args.get("schema_rev") {
        Some(Value::String(value)) => MemorySchema::parse(value).map(Some),
        Some(_) => Err("schema_rev must be a string".to_string()),
        None => Ok(None),
    }
}

fn required_str<'a>(args: &'a Value, key: &str) -> Result<&'a str, String> {
    args.get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| format!("{key} string is required"))
}

fn optional_bool(args: &Value, key: &str) -> Option<bool> {
    args.get(key).and_then(Value::as_bool)
}

fn limit_arg(args: &Value) -> usize {
    args.get("limit")
        .and_then(Value::as_u64)
        .map(|limit| limit as usize)
        .unwrap_or(DEFAULT_LIMIT)
        .clamp(1, MAX_LIMIT)
}

fn invalid_input(error: String, start: Instant) -> ToolResult {
    ToolResult::err(
        error,
        crate::types::error_codes::INVALID_INPUT,
        start.elapsed().as_millis() as u64,
    )
}

fn validate_payload(payload: &Value) -> Result<MemorySchema, String> {
    let object = payload
        .as_object()
        .ok_or_else(|| "payload must be a JSON object".to_string())?;
    let schema_value = object
        .get("schema_rev")
        .and_then(Value::as_str)
        .ok_or_else(|| "payload.schema_rev string is required".to_string())?;
    let schema = MemorySchema::parse(schema_value)?;

    for key in schema.required_keys() {
        if !object.contains_key(*key) {
            return Err(format!("payload missing required key `{key}`"));
        }
    }
    for key in object.keys() {
        if !schema.allowed_keys().contains(&key.as_str()) {
            return Err(format!(
                "payload key `{key}` is not allowed by {}",
                schema.name()
            ));
        }
    }

    let id = payload_id(schema, payload)?;
    if !valid_id(&id) {
        return Err(format!("{} must match ^[a-z0-9]{{12}}$", schema.id_key()));
    }

    let record_len = serde_json::to_vec(payload)
        .map_err(|error| format!("payload cannot be serialized: {error}"))?
        .len();
    if record_len > MAX_RECORD_BYTES {
        return Err(format!(
            "payload is too large: {record_len} bytes exceeds {MAX_RECORD_BYTES}"
        ));
    }

    if schema == MemorySchema::Semantic {
        match payload.get("confidence").and_then(Value::as_f64) {
            Some(confidence) if confidence.is_finite() && (0.0..=1.0).contains(&confidence) => {}
            _ => return Err("semantic confidence must be a finite number in [0,1]".to_string()),
        }
    }

    Ok(schema)
}

fn payload_id(schema: MemorySchema, payload: &Value) -> Result<String, String> {
    payload
        .get(schema.id_key())
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .ok_or_else(|| format!("{} string is required", schema.id_key()))
}

fn valid_id(id: &str) -> bool {
    id.len() == 12
        && id
            .bytes()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn memory_put_get_search_roundtrip_uses_schema_id() {
        let dir = tempdir().unwrap();
        let payload = serde_json::json!({
            "schema_rev": "epistemos.semantic.v1",
            "fact_id": "abc123def456",
            "predicate": "prefers_timezone",
            "subject": "user",
            "object": "America/Chicago",
            "confidence": 0.99,
            "claim_kind": "verified_empirical",
            "evidence": [{ "kind": "user_attestation", "ref": "session:test" }]
        });

        let put = execute_memory_tool(
            dir.path().display().to_string(),
            "memory.put".to_string(),
            serde_json::json!({ "payload": payload }).to_string(),
        );
        let put_result: ToolResult = serde_json::from_str(&put).unwrap();
        assert!(put_result.success, "{put}");

        let get = execute_memory_tool(
            dir.path().display().to_string(),
            "memory.get".to_string(),
            serde_json::json!({
                "schema_rev": "epistemos.semantic.v1",
                "id": "abc123def456"
            })
            .to_string(),
        );
        let get_result: ToolResult = serde_json::from_str(&get).unwrap();
        assert!(get_result.success, "{get}");
        let data: Value = serde_json::from_str(&get_result.data_json).unwrap();
        assert_eq!(data["payload"]["object"], "America/Chicago");

        let search = execute_memory_tool(
            dir.path().display().to_string(),
            "memory.search".to_string(),
            serde_json::json!({ "query": "chicago" }).to_string(),
        );
        let search_result: ToolResult = serde_json::from_str(&search).unwrap();
        assert!(search_result.success, "{search}");
        let data: Value = serde_json::from_str(&search_result.data_json).unwrap();
        assert_eq!(data["count"], 1);
        assert_eq!(data["hits"][0]["id"], "abc123def456");
    }

    #[test]
    fn memory_rejects_unknown_schema_and_bad_id() {
        let dir = tempdir().unwrap();
        let bad = execute_memory_tool(
            dir.path().display().to_string(),
            "memory.put".to_string(),
            serde_json::json!({
                "payload": {
                    "schema_rev": "epistemos.unknown.v1",
                    "fact_id": "ABC",
                    "predicate": "p",
                    "subject": "s",
                    "object": "o",
                    "confidence": 0.5,
                    "claim_kind": "speculative"
                }
            })
            .to_string(),
        );
        let result: ToolResult = serde_json::from_str(&bad).unwrap();
        assert!(!result.success);
        assert_eq!(
            result.error_code.as_deref(),
            Some(crate::types::error_codes::INVALID_INPUT)
        );
        assert!(result.error.unwrap().contains("unknown schema_rev"));

        let bad_id = execute_memory_tool(
            dir.path().display().to_string(),
            "memory.put".to_string(),
            serde_json::json!({
                "payload": {
                    "schema_rev": "epistemos.semantic.v1",
                    "fact_id": "ABC",
                    "predicate": "p",
                    "subject": "s",
                    "object": "o",
                    "confidence": 0.5,
                    "claim_kind": "speculative"
                }
            })
            .to_string(),
        );
        let result: ToolResult = serde_json::from_str(&bad_id).unwrap();
        assert!(!result.success);
        assert!(result.error.unwrap().contains("fact_id must match"));
    }

    #[test]
    fn memory_keeps_episode_and_semantic_append_only() {
        let dir = tempdir().unwrap();
        let payload = serde_json::json!({
            "schema_rev": "epistemos.episode.v1",
            "episode_id": "abc123def456",
            "occurred_at": "2026-05-16T00:00:00Z",
            "kind": "system_event",
            "content": "Memory MCP test event"
        });

        let first = execute_memory_tool(
            dir.path().display().to_string(),
            "memory.put".to_string(),
            serde_json::json!({ "payload": payload }).to_string(),
        );
        let first_result: ToolResult = serde_json::from_str(&first).unwrap();
        assert!(first_result.success, "{first}");

        let duplicate = execute_memory_tool(
            dir.path().display().to_string(),
            "memory.put".to_string(),
            serde_json::json!({ "payload": payload, "replace": true }).to_string(),
        );
        let duplicate_result: ToolResult = serde_json::from_str(&duplicate).unwrap();
        assert!(!duplicate_result.success);
        assert!(duplicate_result.error.unwrap().contains("append-only"));
    }

    #[test]
    fn memory_allows_mutable_soul_replacement_only_when_requested() {
        let dir = tempdir().unwrap();
        let base = serde_json::json!({
            "schema_rev": "epistemos.soul.v1",
            "soul_id": "abc123def456",
            "model_id": "qwen3",
            "identity": { "name": "Jo", "voice": "direct" },
            "preferences": { "tone": "concise" },
            "updated_at": "2026-05-16T00:00:00Z"
        });
        let changed = serde_json::json!({
            "schema_rev": "epistemos.soul.v1",
            "soul_id": "abc123def456",
            "model_id": "qwen3",
            "identity": { "name": "Jo", "voice": "concise" },
            "preferences": { "tone": "neutral" },
            "updated_at": "2026-05-16T00:01:00Z"
        });

        let first = execute_memory_tool(
            dir.path().display().to_string(),
            "memory.put".to_string(),
            serde_json::json!({ "payload": base }).to_string(),
        );
        assert!(serde_json::from_str::<ToolResult>(&first).unwrap().success);

        let denied = execute_memory_tool(
            dir.path().display().to_string(),
            "memory.put".to_string(),
            serde_json::json!({ "payload": changed }).to_string(),
        );
        assert!(!serde_json::from_str::<ToolResult>(&denied).unwrap().success);

        let replaced = execute_memory_tool(
            dir.path().display().to_string(),
            "memory.put".to_string(),
            serde_json::json!({ "payload": changed, "replace": true }).to_string(),
        );
        let replaced_result: ToolResult = serde_json::from_str(&replaced).unwrap();
        assert!(replaced_result.success, "{replaced}");
        let data: Value = serde_json::from_str(&replaced_result.data_json).unwrap();
        assert_eq!(data["replaced"], true);
    }
}
