//! Support code for `web_extract_schema`. Kept separate from the public
//! handler so the web tool modules stay reviewable.

use std::collections::{BTreeMap, HashSet};

use serde_json::{json, Map, Value};

use super::registry::ToolError;
use super::web::{extract_main_region, extract_title};
use super::web_fetch::html_to_text;

pub(super) const MAX_WEB_URL_CHARS: usize = 4_096;
const MAX_BACKEND_CHARS: usize = 64;
const MAX_EXTRACT_CONTENT_CHARS: usize = 32_000;
const MAX_SCHEMA_JSON_CHARS: usize = 16_384;
const MAX_SCHEMA_FIELDS: usize = 32;
const MAX_SCHEMA_FIELD_NAME_CHARS: usize = 128;
const MAX_SCHEMA_FIELD_KEY_CHARS: usize = 128;
const MAX_SCHEMA_PATTERN_CHARS: usize = 512;
const MAX_SCHEMA_OUTPUT_VALUE_CHARS: usize = 8_000;
const MAX_JSON_LD_DOCUMENTS: usize = 8;

pub(super) fn required_string<'a>(
    input: &'a Value,
    field: &str,
    max_chars: usize,
) -> Result<&'a str, ToolError> {
    let value = input
        .get(field)
        .ok_or_else(|| ToolError::InvalidArguments(format!("missing '{field}'")))?;
    let Some(text) = value.as_str() else {
        return Err(ToolError::InvalidArguments(format!(
            "'{field}' must be a string"
        )));
    };
    if text.trim().is_empty() {
        return Err(ToolError::InvalidArguments(format!(
            "'{field}' cannot be blank"
        )));
    }
    if text.chars().count() > max_chars {
        return Err(ToolError::InvalidArguments(format!(
            "'{field}' is too long (max {max_chars} chars)"
        )));
    }
    Ok(text)
}

fn optional_string<'a>(
    input: &'a Value,
    field: &str,
    max_chars: usize,
) -> Result<Option<&'a str>, ToolError> {
    let Some(value) = input.get(field) else {
        return Ok(None);
    };
    let Some(text) = value.as_str() else {
        return Err(ToolError::InvalidArguments(format!(
            "'{field}' must be a string"
        )));
    };
    if text.chars().count() > max_chars {
        return Err(ToolError::InvalidArguments(format!(
            "'{field}' is too long (max {max_chars} chars)"
        )));
    }
    Ok(Some(text))
}

pub(super) fn optional_bool(input: &Value, field: &str, default: bool) -> Result<bool, ToolError> {
    let Some(value) = input.get(field) else {
        return Ok(default);
    };
    value
        .as_bool()
        .ok_or_else(|| ToolError::InvalidArguments(format!("'{field}' must be a boolean")))
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum SchemaSource {
    Auto,
    Title,
    Meta,
    Text,
    JsonLd,
}

impl SchemaSource {
    fn as_str(self) -> &'static str {
        match self {
            Self::Auto => "auto",
            Self::Title => "title",
            Self::Meta => "meta",
            Self::Text => "text",
            Self::JsonLd => "json_ld",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(super) struct SchemaFieldSpec {
    name: String,
    source: SchemaSource,
    key: Option<String>,
    pattern: Option<String>,
    required: bool,
}

#[derive(Debug)]
struct PageSignals {
    title: String,
    meta: BTreeMap<String, String>,
    json_ld: Vec<Value>,
    text: String,
    content_truncated: bool,
}

#[derive(Debug)]
struct ExtractedField {
    value: Value,
    source: String,
}

pub(super) fn parse_target_schema(input: &Value) -> Result<Value, ToolError> {
    let schema = input
        .get("schema")
        .ok_or_else(|| ToolError::InvalidArguments("missing 'schema'".into()))?;
    if !schema.is_object() {
        return Err(ToolError::InvalidArguments(
            "'schema' must be a JSON Schema object".into(),
        ));
    }
    let schema_len = serde_json::to_string(schema)
        .map_err(|e| ToolError::InvalidArguments(format!("schema serialize failed: {e}")))?
        .chars()
        .count();
    if schema_len > MAX_SCHEMA_JSON_CHARS {
        return Err(ToolError::InvalidArguments(format!(
            "'schema' is too large (max {MAX_SCHEMA_JSON_CHARS} chars)"
        )));
    }
    jsonschema::validator_for(schema)
        .map_err(|e| ToolError::InvalidArguments(format!("schema compile failed: {e}")))?;
    Ok(schema.clone())
}

pub(super) fn parse_schema_fields(
    input: &Value,
    schema: &Value,
) -> Result<Vec<SchemaFieldSpec>, ToolError> {
    let required_names = schema_required_names(schema);
    let mut specs: BTreeMap<String, SchemaFieldSpec> = BTreeMap::new();

    if let Some(properties) = schema.get("properties").and_then(Value::as_object) {
        for name in properties.keys() {
            if name.chars().count() > MAX_SCHEMA_FIELD_NAME_CHARS {
                return Err(ToolError::InvalidArguments(format!(
                    "schema property '{name}' is too long (max {MAX_SCHEMA_FIELD_NAME_CHARS} chars)"
                )));
            }
            specs.insert(
                name.clone(),
                SchemaFieldSpec {
                    name: name.clone(),
                    source: SchemaSource::Auto,
                    key: None,
                    pattern: None,
                    required: required_names.contains(name),
                },
            );
        }
    }

    if let Some(fields_value) = input.get("fields") {
        let Some(fields) = fields_value.as_array() else {
            return Err(ToolError::InvalidArguments(
                "'fields' must be an array".into(),
            ));
        };
        if fields.len() > MAX_SCHEMA_FIELDS {
            return Err(ToolError::InvalidArguments(format!(
                "'fields' accepts at most {MAX_SCHEMA_FIELDS} entries"
            )));
        }
        for field_value in fields {
            let field = parse_schema_field_spec(field_value, &required_names)?;
            specs.insert(field.name.clone(), field);
        }
    }

    if specs.is_empty() {
        return Err(ToolError::InvalidArguments(
            "'schema.properties' or 'fields' must define at least one field".into(),
        ));
    }
    if specs.len() > MAX_SCHEMA_FIELDS {
        return Err(ToolError::InvalidArguments(format!(
            "schema extraction accepts at most {MAX_SCHEMA_FIELDS} fields"
        )));
    }

    Ok(specs.into_values().collect())
}

fn parse_schema_field_spec(
    input: &Value,
    schema_required_names: &HashSet<String>,
) -> Result<SchemaFieldSpec, ToolError> {
    if !input.is_object() {
        return Err(ToolError::InvalidArguments(
            "each 'fields' entry must be an object".into(),
        ));
    }
    let name = required_string(input, "name", MAX_SCHEMA_FIELD_NAME_CHARS)?.to_string();
    let source = parse_schema_source(optional_string(input, "source", MAX_BACKEND_CHARS)?)?;
    let key = optional_nonempty_string(input, "key", MAX_SCHEMA_FIELD_KEY_CHARS)?;
    let pattern = optional_nonempty_string(input, "pattern", MAX_SCHEMA_PATTERN_CHARS)?;
    if let Some(pattern) = &pattern {
        regex::Regex::new(pattern).map_err(|e| {
            ToolError::InvalidArguments(format!("field '{name}' has invalid regex pattern: {e}"))
        })?;
    }
    let required = optional_bool(input, "required", schema_required_names.contains(&name))?;
    Ok(SchemaFieldSpec {
        name,
        source,
        key,
        pattern,
        required,
    })
}

fn parse_schema_source(source: Option<&str>) -> Result<SchemaSource, ToolError> {
    let Some(source) = source else {
        return Ok(SchemaSource::Auto);
    };
    match source.to_ascii_lowercase().as_str() {
        "auto" => Ok(SchemaSource::Auto),
        "title" => Ok(SchemaSource::Title),
        "meta" => Ok(SchemaSource::Meta),
        "text" => Ok(SchemaSource::Text),
        "json_ld" | "json-ld" | "jsonld" => Ok(SchemaSource::JsonLd),
        other => Err(ToolError::InvalidArguments(format!(
            "unknown field source '{other}' (expected auto|title|meta|text|json_ld)"
        ))),
    }
}

fn optional_nonempty_string(
    input: &Value,
    field: &str,
    max_chars: usize,
) -> Result<Option<String>, ToolError> {
    let Some(value) = optional_string(input, field, max_chars)? else {
        return Ok(None);
    };
    if value.trim().is_empty() {
        return Err(ToolError::InvalidArguments(format!(
            "'{field}' cannot be blank"
        )));
    }
    Ok(Some(value.to_string()))
}

pub(super) fn extract_schema_payload_from_html(
    url: &str,
    html: &str,
    schema: &Value,
    fields: &[SchemaFieldSpec],
    include_content: bool,
) -> Result<Value, ToolError> {
    let signals = extract_page_signals(html);
    let mut extracted = Map::new();
    let mut evidence = Vec::with_capacity(fields.len());
    let required_names = schema_required_names(schema);

    for field in fields {
        let property_schema = schema_property(schema, &field.name);
        match extract_value_for_field(field, &signals, url)? {
            Some(raw) => {
                let value = coerce_schema_value(raw.value, property_schema);
                if has_meaningful_value(&value) {
                    evidence.push(json!({
                        "field": field.name,
                        "matched": true,
                        "source": raw.source,
                        "value_preview": value_preview(&value),
                    }));
                    extracted.insert(field.name.clone(), value);
                } else {
                    evidence.push(json!({
                        "field": field.name,
                        "matched": false,
                        "source": raw.source,
                    }));
                }
            }
            None => evidence.push(json!({
                "field": field.name,
                "matched": false,
                "source": field.source.as_str(),
            })),
        }
    }

    let mut missing_required = Vec::new();
    for field in fields {
        if (field.required || required_names.contains(&field.name))
            && !extracted.contains_key(&field.name)
        {
            missing_required.push(field.name.clone());
        }
    }
    for required in required_names {
        if !extracted.contains_key(&required) && !missing_required.contains(&required) {
            missing_required.push(required);
        }
    }
    missing_required.sort();

    let extracted_value = Value::Object(extracted);
    let validator = crate::tools_v2::runner::JsonSchemaValidator;
    let validation_error =
        crate::tools_v2::SchemaValidator::validate(&validator, schema, &extracted_value).err();
    let schema_valid = validation_error.is_none();

    let mut payload = json!({
        "success": true,
        "url": url,
        "title": signals.title,
        "schema_valid": schema_valid,
        "validation_error": validation_error,
        "missing_required": missing_required,
        "content_truncated": signals.content_truncated,
        "extracted": extracted_value,
        "evidence": evidence,
    });

    if include_content {
        payload["content"] = json!(signals.text);
    }

    Ok(payload)
}

fn extract_page_signals(html: &str) -> PageSignals {
    let title = decode_basic_html_entities(&extract_title(html));
    let main_region = extract_main_region(html);
    let mut text = html_to_text(main_region.as_deref().unwrap_or(html));
    let content_truncated = text.chars().count() > MAX_EXTRACT_CONTENT_CHARS;
    if content_truncated {
        text = text.chars().take(MAX_EXTRACT_CONTENT_CHARS).collect();
    }
    PageSignals {
        title,
        meta: extract_meta_tags(html),
        json_ld: extract_json_ld_documents(html),
        text,
        content_truncated,
    }
}

fn extract_value_for_field(
    field: &SchemaFieldSpec,
    signals: &PageSignals,
    page_url: &str,
) -> Result<Option<ExtractedField>, ToolError> {
    if let Some(pattern) = &field.pattern {
        let haystack = pattern_haystack(field, signals);
        if let Some(value) = apply_field_pattern(pattern, &haystack)? {
            return Ok(Some(ExtractedField {
                value: Value::String(value),
                source: format!("pattern:{}", field.source.as_str()),
            }));
        }
    }

    let value = match field.source {
        SchemaSource::Title => string_field(&signals.title, "title"),
        SchemaSource::Meta => {
            let key = field.key.as_deref().unwrap_or(&field.name);
            meta_lookup(signals, key).map(|value| ExtractedField {
                value: Value::String(value),
                source: format!("meta:{key}"),
            })
        }
        SchemaSource::Text => text_field(field, signals),
        SchemaSource::JsonLd => {
            let key = field.key.as_deref().unwrap_or(&field.name);
            json_ld_lookup(signals, key).map(|value| ExtractedField {
                value,
                source: format!("json_ld:{key}"),
            })
        }
        SchemaSource::Auto => auto_extract_field(field, signals, page_url),
    };

    Ok(value)
}

fn pattern_haystack(field: &SchemaFieldSpec, signals: &PageSignals) -> String {
    match field.source {
        SchemaSource::Title => signals.title.clone(),
        SchemaSource::Meta => field
            .key
            .as_deref()
            .and_then(|key| meta_lookup(signals, key))
            .unwrap_or_else(|| {
                signals
                    .meta
                    .values()
                    .cloned()
                    .collect::<Vec<_>>()
                    .join("\n")
            }),
        SchemaSource::JsonLd => serde_json::to_string(&signals.json_ld).unwrap_or_default(),
        SchemaSource::Auto | SchemaSource::Text => signals.text.clone(),
    }
}

fn apply_field_pattern(pattern: &str, haystack: &str) -> Result<Option<String>, ToolError> {
    let re = regex::Regex::new(pattern)
        .map_err(|e| ToolError::InvalidArguments(format!("invalid regex pattern: {e}")))?;
    let Some(captures) = re.captures(haystack) else {
        return Ok(None);
    };
    let matched = captures
        .get(1)
        .or_else(|| captures.get(0))
        .map(|m| m.as_str())
        .unwrap_or("");
    Ok(nonempty_bounded_string(matched))
}

fn auto_extract_field(
    field: &SchemaFieldSpec,
    signals: &PageSignals,
    page_url: &str,
) -> Option<ExtractedField> {
    let key = field.key.as_deref().unwrap_or(&field.name);
    let normalized = normalize_schema_key(key);

    if matches!(normalized.as_str(), "title" | "name" | "headline") {
        return string_field(&signals.title, "title")
            .or_else(|| meta_lookup(signals, key).map(|value| meta_field(value, key)))
            .or_else(|| json_ld_lookup(signals, key).map(|value| json_ld_field(value, key)));
    }
    if matches!(normalized.as_str(), "description" | "summary" | "abstract") {
        return meta_lookup(signals, key)
            .map(|value| meta_field(value, key))
            .or_else(|| json_ld_lookup(signals, key).map(|value| json_ld_field(value, key)))
            .or_else(|| text_summary_field(signals));
    }
    if matches!(normalized.as_str(), "author" | "byline") {
        return meta_lookup(signals, key)
            .map(|value| meta_field(value, key))
            .or_else(|| json_ld_lookup(signals, key).map(|value| json_ld_field(value, key)));
    }
    if matches!(
        normalized.as_str(),
        "date" | "published" | "datepublished" | "publishedat" | "published_at"
    ) {
        return meta_lookup(signals, key)
            .map(|value| meta_field(value, key))
            .or_else(|| json_ld_lookup(signals, key).map(|value| json_ld_field(value, key)));
    }
    if matches!(normalized.as_str(), "image" | "thumbnail") {
        return meta_lookup(signals, key)
            .map(|value| meta_field(value, key))
            .or_else(|| json_ld_lookup(signals, key).map(|value| json_ld_field(value, key)));
    }
    if matches!(normalized.as_str(), "url" | "canonical") {
        return meta_lookup(signals, key)
            .map(|value| meta_field(value, key))
            .or_else(|| {
                Some(ExtractedField {
                    value: Value::String(page_url.to_string()),
                    source: "url".to_string(),
                })
            });
    }
    if matches!(normalized.as_str(), "content" | "text" | "body") {
        return text_field(field, signals);
    }

    meta_lookup(signals, key)
        .map(|value| meta_field(value, key))
        .or_else(|| json_ld_lookup(signals, key).map(|value| json_ld_field(value, key)))
}

fn string_field(value: &str, source: &str) -> Option<ExtractedField> {
    nonempty_bounded_string(value).map(|value| ExtractedField {
        value: Value::String(value),
        source: source.to_string(),
    })
}

fn meta_field(value: String, key: &str) -> ExtractedField {
    ExtractedField {
        value: Value::String(value),
        source: format!("meta:{key}"),
    }
}

fn json_ld_field(value: Value, key: &str) -> ExtractedField {
    ExtractedField {
        value,
        source: format!("json_ld:{key}"),
    }
}

fn text_field(field: &SchemaFieldSpec, signals: &PageSignals) -> Option<ExtractedField> {
    let normalized = normalize_schema_key(field.key.as_deref().unwrap_or(&field.name));
    if matches!(normalized.as_str(), "content" | "text" | "body") {
        return nonempty_bounded_string(&signals.text).map(|value| ExtractedField {
            value: Value::String(value),
            source: "text".to_string(),
        });
    }
    text_summary_field(signals)
}

fn text_summary_field(signals: &PageSignals) -> Option<ExtractedField> {
    let summary = collapse_whitespace(&signals.text);
    nonempty_bounded_string(&summary.chars().take(700).collect::<String>()).map(|value| {
        ExtractedField {
            value: Value::String(value),
            source: "text:summary".to_string(),
        }
    })
}

fn meta_lookup(signals: &PageSignals, key: &str) -> Option<String> {
    for candidate in meta_candidates(key) {
        if let Some(value) = signals.meta.get(&candidate) {
            if let Some(value) = nonempty_bounded_string(value) {
                return Some(value);
            }
        }
    }
    None
}

fn meta_candidates(key: &str) -> Vec<String> {
    let normalized = normalize_schema_key(key);
    let mut candidates = vec![key.to_ascii_lowercase(), normalized.clone()];
    match normalized.as_str() {
        "title" | "name" | "headline" => candidates.extend(
            ["og:title", "twitter:title", "dc.title"]
                .into_iter()
                .map(str::to_string),
        ),
        "description" | "summary" | "abstract" => candidates.extend(
            [
                "description",
                "og:description",
                "twitter:description",
                "dc.description",
            ]
            .into_iter()
            .map(str::to_string),
        ),
        "author" | "byline" => candidates.extend(
            ["author", "article:author", "dc.creator", "twitter:creator"]
                .into_iter()
                .map(str::to_string),
        ),
        "date" | "published" | "datepublished" | "publishedat" | "published_at" => candidates
            .extend(
                [
                    "article:published_time",
                    "date",
                    "dc.date",
                    "dc.date.created",
                    "publication_date",
                ]
                .into_iter()
                .map(str::to_string),
            ),
        "image" | "thumbnail" => candidates.extend(
            ["og:image", "twitter:image", "thumbnail"]
                .into_iter()
                .map(str::to_string),
        ),
        "url" | "canonical" => candidates.extend(
            ["og:url", "twitter:url", "canonical"]
                .into_iter()
                .map(str::to_string),
        ),
        "site" | "sitename" | "site_name" => candidates.push("og:site_name".to_string()),
        _ => {}
    }
    candidates.sort();
    candidates.dedup();
    candidates
}

fn json_ld_lookup(signals: &PageSignals, key: &str) -> Option<Value> {
    for doc in &signals.json_ld {
        if let Some(value) = find_json_value(doc, key) {
            return Some(value);
        }
    }
    None
}

fn find_json_value(value: &Value, key: &str) -> Option<Value> {
    if key.contains('.') {
        return find_json_path_value(value, key);
    }
    match value {
        Value::Object(map) => {
            for (candidate, candidate_value) in map {
                if candidate.eq_ignore_ascii_case(key)
                    || normalize_schema_key(candidate) == normalize_schema_key(key)
                {
                    return Some(candidate_value.clone());
                }
            }
            for candidate_value in map.values() {
                if let Some(found) = find_json_value(candidate_value, key) {
                    return Some(found);
                }
            }
            None
        }
        Value::Array(items) => items.iter().find_map(|item| find_json_value(item, key)),
        _ => None,
    }
}

fn find_json_path_value(value: &Value, path: &str) -> Option<Value> {
    let parts = path.split('.').collect::<Vec<_>>();
    find_json_path_parts(value, &parts)
}

fn find_json_path_parts(value: &Value, parts: &[&str]) -> Option<Value> {
    let Some((part, rest)) = parts.split_first() else {
        return Some(value.clone());
    };
    match value {
        Value::Object(map) => {
            let (_, next) = map
                .iter()
                .find(|(key, _)| key.eq_ignore_ascii_case(part))
                .or_else(|| {
                    map.iter()
                        .find(|(key, _)| normalize_schema_key(key) == normalize_schema_key(part))
                })?;
            find_json_path_parts(next, rest)
        }
        Value::Array(items) => items
            .iter()
            .find_map(|item| find_json_path_parts(item, parts)),
        _ => None,
    }
}

fn extract_meta_tags(html: &str) -> BTreeMap<String, String> {
    let mut meta = BTreeMap::new();
    for tag in extract_open_tags(html, "meta") {
        let attrs = extract_attrs(&tag);
        let Some(content) = attrs
            .get("content")
            .and_then(|value| nonempty_bounded_string(value))
        else {
            continue;
        };
        for key_attr in ["name", "property", "itemprop", "http-equiv"] {
            if let Some(key) = attrs
                .get(key_attr)
                .and_then(|value| nonempty_bounded_string(value))
            {
                meta.entry(key.to_ascii_lowercase())
                    .or_insert(content.clone());
            }
        }
    }
    meta
}

fn extract_json_ld_documents(html: &str) -> Vec<Value> {
    let lower = html.to_ascii_lowercase();
    let mut documents = Vec::new();
    let mut index = 0;
    while documents.len() < MAX_JSON_LD_DOCUMENTS {
        let Some(found) = lower[index..].find("<script") else {
            break;
        };
        let open_start = index + found;
        let Some(open_end_rel) = lower[open_start..].find('>') else {
            break;
        };
        let open_end = open_start + open_end_rel;
        let open_tag = &html[open_start..=open_end];
        let attrs = extract_attrs(open_tag);
        let is_json_ld = attrs
            .get("type")
            .map(|value| value.to_ascii_lowercase().contains("ld+json"))
            .unwrap_or(false);
        let body_start = open_end + 1;
        let Some(close_rel) = lower[body_start..].find("</script>") else {
            break;
        };
        let body_end = body_start + close_rel;
        if is_json_ld {
            if let Ok(value) = serde_json::from_str::<Value>(html[body_start..body_end].trim()) {
                match value {
                    Value::Array(items) => {
                        for item in items {
                            if documents.len() >= MAX_JSON_LD_DOCUMENTS {
                                break;
                            }
                            documents.push(item);
                        }
                    }
                    other => documents.push(other),
                }
            }
        }
        index = body_end + "</script>".len();
    }
    documents
}

fn extract_open_tags(html: &str, tag: &str) -> Vec<String> {
    let lower = html.to_ascii_lowercase();
    let needle = format!("<{tag}");
    let mut tags = Vec::new();
    let mut index = 0;
    while let Some(found) = lower[index..].find(&needle) {
        let start = index + found;
        let after_name = start + needle.len();
        if lower
            .as_bytes()
            .get(after_name)
            .is_some_and(|byte| byte.is_ascii_alphanumeric() || *byte == b'-')
        {
            index = after_name;
            continue;
        }
        let Some(end_rel) = lower[start..].find('>') else {
            break;
        };
        let end = start + end_rel;
        tags.push(html[start..=end].to_string());
        index = end + 1;
    }
    tags
}

fn extract_attrs(tag: &str) -> BTreeMap<String, String> {
    let bytes = tag.as_bytes();
    let mut attrs = BTreeMap::new();
    let mut index = tag.find(char::is_whitespace).unwrap_or(tag.len());

    while index < bytes.len() {
        index = skip_ascii_whitespace(bytes, index);
        while matches!(bytes.get(index), Some(b'/' | b'>')) {
            index += 1;
        }
        if index >= bytes.len() {
            break;
        }
        let name_start = index;
        while index < bytes.len()
            && (bytes[index].is_ascii_alphanumeric()
                || matches!(bytes[index], b'-' | b':' | b'_' | b'@'))
        {
            index += 1;
        }
        if index == name_start {
            index += 1;
            continue;
        }
        let name = tag[name_start..index].to_ascii_lowercase();
        index = skip_ascii_whitespace(bytes, index);
        if bytes.get(index) != Some(&b'=') {
            attrs.entry(name).or_insert_with(String::new);
            continue;
        }
        index += 1;
        index = skip_ascii_whitespace(bytes, index);
        let Some(first) = bytes.get(index).copied() else {
            break;
        };
        let (value_start, value_end) = if first == b'"' || first == b'\'' {
            index += 1;
            let quote = first;
            let value_start = index;
            while index < bytes.len() && bytes[index] != quote {
                index += 1;
            }
            (value_start, index)
        } else {
            let value_start = index;
            while index < bytes.len()
                && !bytes[index].is_ascii_whitespace()
                && !matches!(bytes[index], b'>' | b'/')
            {
                index += 1;
            }
            (value_start, index)
        };
        let value = decode_basic_html_entities(&tag[value_start..value_end]);
        attrs.entry(name).or_insert(value);
        if matches!(bytes.get(index), Some(b'"' | b'\'')) {
            index += 1;
        }
    }

    attrs
}

fn skip_ascii_whitespace(bytes: &[u8], mut index: usize) -> usize {
    while index < bytes.len() && bytes[index].is_ascii_whitespace() {
        index += 1;
    }
    index
}

fn coerce_schema_value(value: Value, property_schema: Option<&Value>) -> Value {
    let Some(expected_type) = schema_type(property_schema) else {
        return normalize_json_value(value);
    };
    match expected_type {
        "string" => json_value_to_string(&value)
            .and_then(|value| nonempty_bounded_string(&value))
            .map(Value::String)
            .unwrap_or(Value::Null),
        "integer" => json_value_to_i64(&value)
            .map(|value| Value::Number(value.into()))
            .unwrap_or(Value::Null),
        "number" => json_value_to_f64(&value)
            .and_then(serde_json::Number::from_f64)
            .map(Value::Number)
            .unwrap_or(Value::Null),
        "boolean" => json_value_to_bool(&value)
            .map(Value::Bool)
            .unwrap_or(Value::Null),
        "array" => match value {
            Value::Array(items) => {
                Value::Array(items.into_iter().map(normalize_json_value).collect())
            }
            other => Value::Array(vec![normalize_json_value(other)]),
        },
        "object" => match value {
            Value::Object(_) => value,
            _ => Value::Null,
        },
        _ => normalize_json_value(value),
    }
}

fn normalize_json_value(value: Value) -> Value {
    match value {
        Value::String(text) => nonempty_bounded_string(&text)
            .map(Value::String)
            .unwrap_or(Value::Null),
        Value::Array(items) => Value::Array(items.into_iter().map(normalize_json_value).collect()),
        other => other,
    }
}

fn schema_type(schema: Option<&Value>) -> Option<&str> {
    let schema = schema?;
    match schema.get("type")? {
        Value::String(value) => Some(value.as_str()),
        Value::Array(values) => values.iter().find_map(Value::as_str),
        _ => None,
    }
}

fn schema_property<'a>(schema: &'a Value, field: &str) -> Option<&'a Value> {
    schema
        .get("properties")
        .and_then(Value::as_object)
        .and_then(|properties| properties.get(field))
}

fn schema_required_names(schema: &Value) -> HashSet<String> {
    schema
        .get("required")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::to_string)
        .collect()
}

fn json_value_to_string(value: &Value) -> Option<String> {
    match value {
        Value::String(text) => Some(text.clone()),
        Value::Number(number) => Some(number.to_string()),
        Value::Bool(value) => Some(value.to_string()),
        Value::Array(items) => {
            let joined = items
                .iter()
                .filter_map(json_value_to_string)
                .filter(|value| !value.trim().is_empty())
                .collect::<Vec<_>>()
                .join(", ");
            (!joined.trim().is_empty()).then_some(joined)
        }
        Value::Object(map) => ["name", "headline", "title", "description", "text", "@value"]
            .into_iter()
            .find_map(|key| map.get(key).and_then(json_value_to_string)),
        Value::Null => None,
    }
}

fn json_value_to_i64(value: &Value) -> Option<i64> {
    match value {
        Value::Number(number) => number
            .as_i64()
            .or_else(|| number.as_u64().map(|value| value as i64)),
        Value::String(text) => numeric_text(text)?.parse::<i64>().ok(),
        _ => None,
    }
}

fn json_value_to_f64(value: &Value) -> Option<f64> {
    match value {
        Value::Number(number) => number.as_f64(),
        Value::String(text) => numeric_text(text)?.parse::<f64>().ok(),
        _ => None,
    }
}

fn json_value_to_bool(value: &Value) -> Option<bool> {
    match value {
        Value::Bool(value) => Some(*value),
        Value::String(text) => match text.trim().to_ascii_lowercase().as_str() {
            "true" | "yes" | "1" => Some(true),
            "false" | "no" | "0" => Some(false),
            _ => None,
        },
        _ => None,
    }
}

fn numeric_text(text: &str) -> Option<String> {
    let cleaned: String = text
        .chars()
        .filter(|ch| ch.is_ascii_digit() || matches!(ch, '.' | '-' | '+'))
        .collect();
    (!cleaned.trim().is_empty()).then_some(cleaned)
}

fn has_meaningful_value(value: &Value) -> bool {
    match value {
        Value::Null => false,
        Value::String(text) => !text.trim().is_empty(),
        Value::Array(items) => !items.is_empty(),
        Value::Object(map) => !map.is_empty(),
        Value::Bool(_) | Value::Number(_) => true,
    }
}

fn value_preview(value: &Value) -> String {
    match value {
        Value::String(text) => bound_chars(&collapse_whitespace(text), 160),
        other => bound_chars(&other.to_string(), 160),
    }
}

fn nonempty_bounded_string(value: &str) -> Option<String> {
    let compact = collapse_whitespace(&decode_basic_html_entities(value));
    (!compact.trim().is_empty()).then_some(bound_chars(&compact, MAX_SCHEMA_OUTPUT_VALUE_CHARS))
}

fn bound_chars(value: &str, max_chars: usize) -> String {
    if value.chars().count() <= max_chars {
        value.to_string()
    } else {
        value.chars().take(max_chars).collect()
    }
}

fn collapse_whitespace(value: &str) -> String {
    value.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn decode_basic_html_entities(value: &str) -> String {
    value
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&nbsp;", " ")
}

fn normalize_schema_key(key: &str) -> String {
    key.chars()
        .filter(|ch| ch.is_ascii_alphanumeric())
        .flat_map(char::to_lowercase)
        .collect()
}
