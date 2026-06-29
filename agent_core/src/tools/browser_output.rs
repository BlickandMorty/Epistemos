use reqwest::Url;
use serde_json::{json, Map, Value};

const MAX_BROWSER_IMAGES: usize = 50;
const MAX_BROWSER_IMAGE_TEXT_CHARS: usize = 512;
const MAX_BROWSER_SNAPSHOT_REFS: usize = 500;
const MAX_BROWSER_CONSOLE_ITEMS: usize = 100;
const MAX_BROWSER_CONSOLE_OBJECT_FIELDS: usize = 40;
const MAX_BROWSER_CONSOLE_KEY_CHARS: usize = 128;
const MAX_BROWSER_CONSOLE_TEXT_CHARS: usize = 2_000;
const MAX_BROWSER_CONSOLE_DEPTH: usize = 4;
const MAX_BROWSER_URL_CHARS: usize = 2_048;

pub(crate) fn normalize_image_results(raw_images: Value) -> (Value, usize, bool) {
    let Some(items) = raw_images.as_array() else {
        return (json!([]), 0, false);
    };

    let mut truncated = items.len() > MAX_BROWSER_IMAGES;
    let normalized = items
        .iter()
        .take(MAX_BROWSER_IMAGES)
        .filter_map(|item| {
            let object = item.as_object()?;
            let src = object.get("src").and_then(Value::as_str)?;
            let Some((src, src_truncated)) = sanitize_image_src(src) else {
                return None;
            };

            let (alt, alt_truncated) = object
                .get("alt")
                .and_then(Value::as_str)
                .map(truncate_image_text)
                .unwrap_or_else(|| (String::new(), false));
            truncated |= src_truncated || alt_truncated;

            let mut normalized = Map::new();
            normalized.insert("src".to_string(), Value::String(src));
            normalized.insert("alt".to_string(), Value::String(alt));
            if let Some(width) = object.get("width").filter(|value| value.is_number()) {
                normalized.insert("width".to_string(), width.clone());
            }
            if let Some(height) = object.get("height").filter(|value| value.is_number()) {
                normalized.insert("height".to_string(), height.clone());
            }
            Some(Value::Object(normalized))
        })
        .collect::<Vec<_>>();

    (Value::Array(normalized), items.len(), truncated)
}

fn sanitize_image_src(src: &str) -> Option<(String, bool)> {
    if src.is_empty() || src.starts_with("data:") {
        return None;
    }
    let (src, redacted) = sanitize_url_text(src);
    let (src, truncated) = truncate_image_text(&src);
    Some((src, redacted || truncated))
}

pub(crate) fn normalize_console_items(raw_items: Value) -> (Value, usize, bool) {
    let Some(items) = raw_items.as_array() else {
        return (json!([]), 0, false);
    };

    let mut truncated = items.len() > MAX_BROWSER_CONSOLE_ITEMS;
    let normalized = items
        .iter()
        .take(MAX_BROWSER_CONSOLE_ITEMS)
        .map(|item| {
            let (value, item_truncated) = bound_console_value_ref(item, MAX_BROWSER_CONSOLE_DEPTH);
            truncated |= item_truncated;
            value
        })
        .collect::<Vec<_>>();

    (Value::Array(normalized), items.len(), truncated)
}

pub(crate) fn normalize_snapshot_refs(raw_refs: Value) -> (Value, usize, bool) {
    let Some(refs) = raw_refs.as_object() else {
        return (json!({}), 0, false);
    };

    let mut truncated = refs.len() > MAX_BROWSER_SNAPSHOT_REFS;
    let mut normalized = Map::new();
    for (key, value) in refs.iter().take(MAX_BROWSER_SNAPSHOT_REFS) {
        let (key, key_truncated) = truncate_console_text(key, MAX_BROWSER_CONSOLE_KEY_CHARS);
        let (value, value_truncated) = bound_console_value_ref(value, 2);
        truncated |= key_truncated || value_truncated;
        normalized.insert(key, value);
    }

    (Value::Object(normalized), refs.len(), truncated)
}

pub(crate) fn bound_console_value(value: Value) -> (Value, bool) {
    bound_console_value_ref(&value, MAX_BROWSER_CONSOLE_DEPTH)
}

pub(crate) fn sanitize_url_for_output(raw_url: Option<&str>) -> (Value, bool) {
    let Some(raw_url) = raw_url else {
        return (Value::Null, false);
    };
    let (url, redacted) = sanitize_url_text(raw_url);
    (Value::String(url), redacted)
}

fn sanitize_url_text(raw_url: &str) -> (String, bool) {
    if let Ok(mut parsed) = Url::parse(raw_url) {
        if !matches!(parsed.scheme(), "http" | "https") {
            return ("[redacted-url]".to_string(), true);
        }
        let mut redacted = false;
        if !parsed.username().is_empty() {
            let _ = parsed.set_username("");
            redacted = true;
        }
        if parsed.password().is_some() {
            let _ = parsed.set_password(None);
            redacted = true;
        }
        if parsed.query().is_some() {
            parsed.set_query(None);
            redacted = true;
        }
        if parsed.fragment().is_some() {
            parsed.set_fragment(None);
            redacted = true;
        }
        let (url, truncated) = truncate_url_text(parsed.as_str());
        return (url, redacted || truncated);
    }

    if raw_url.contains('@') || raw_url.contains('?') || raw_url.contains('#') {
        return ("[redacted-url]".to_string(), true);
    }
    if raw_url
        .split_once(':')
        .is_some_and(|(scheme, _)| scheme.chars().all(|ch| ch.is_ascii_alphabetic()))
    {
        return ("[redacted-url]".to_string(), true);
    }
    let (url, truncated) = truncate_url_text(raw_url);
    (url, truncated)
}

fn bound_console_value_ref(value: &Value, depth: usize) -> (Value, bool) {
    if depth == 0 {
        return match value {
            Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => {
                bound_console_scalar(value)
            }
            _ => (
                Value::String("[Truncated nested browser value]".to_string()),
                true,
            ),
        };
    }

    match value {
        Value::Array(items) => {
            let mut truncated = items.len() > MAX_BROWSER_CONSOLE_ITEMS;
            let values = items
                .iter()
                .take(MAX_BROWSER_CONSOLE_ITEMS)
                .map(|item| {
                    let (value, item_truncated) = bound_console_value_ref(item, depth - 1);
                    truncated |= item_truncated;
                    value
                })
                .collect::<Vec<_>>();
            (Value::Array(values), truncated)
        }
        Value::Object(object) => {
            let mut truncated = object.len() > MAX_BROWSER_CONSOLE_OBJECT_FIELDS;
            let mut normalized = Map::new();
            for (key, value) in object.iter().take(MAX_BROWSER_CONSOLE_OBJECT_FIELDS) {
                let (key, key_truncated) = truncate_console_key(key);
                let (value, value_truncated) = bound_console_value_ref(value, depth - 1);
                truncated |= key_truncated || value_truncated;
                normalized.insert(key, value);
            }
            (Value::Object(normalized), truncated)
        }
        _ => bound_console_scalar(value),
    }
}

fn bound_console_scalar(value: &Value) -> (Value, bool) {
    match value {
        Value::String(text) => {
            let (text, truncated) = truncate_console_text(text, MAX_BROWSER_CONSOLE_TEXT_CHARS);
            (Value::String(text), truncated)
        }
        _ => (value.clone(), false),
    }
}

fn truncate_image_text(text: &str) -> (String, bool) {
    let total_chars = text.chars().count();
    if total_chars <= MAX_BROWSER_IMAGE_TEXT_CHARS {
        return (text.to_string(), false);
    }

    (
        text.chars().take(MAX_BROWSER_IMAGE_TEXT_CHARS).collect(),
        true,
    )
}

fn truncate_console_key(text: &str) -> (String, bool) {
    truncate_console_text(text, MAX_BROWSER_CONSOLE_KEY_CHARS)
}

fn truncate_console_text(text: &str, cap: usize) -> (String, bool) {
    let total_chars = text.chars().count();
    if total_chars <= cap {
        return (text.to_string(), false);
    }

    let truncated: String = text.chars().take(cap).collect();
    (
        format!("{truncated}\n[Truncated: {total_chars} total chars]"),
        true,
    )
}

fn truncate_url_text(text: &str) -> (String, bool) {
    let total_chars = text.chars().count();
    if total_chars <= MAX_BROWSER_URL_CHARS {
        return (text.to_string(), false);
    }
    (text.chars().take(MAX_BROWSER_URL_CHARS).collect(), true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn browser_get_images_normalizes_and_bounds_page_controlled_results() {
        let long_suffix = "a".repeat(MAX_BROWSER_IMAGE_TEXT_CHARS + 20);
        let long_alt = "b".repeat(MAX_BROWSER_IMAGE_TEXT_CHARS + 1);
        let mut items = Vec::new();
        items.push(json!({
            "src": format!("https://user:pass@example.com/{long_suffix}?token=image-token#frag"),
            "alt": long_alt,
            "width": 640,
            "height": 480,
            "ignored": "drop me"
        }));
        for index in 1..(MAX_BROWSER_IMAGES + 2) {
            items.push(json!({
                "src": format!("https://example.com/image-{index}.png"),
                "alt": format!("image {index}"),
                "width": index,
                "height": index + 1,
            }));
        }

        let (images, count, truncated) = normalize_image_results(Value::Array(items));
        let images = images.as_array().unwrap();
        assert_eq!(count, MAX_BROWSER_IMAGES + 2);
        assert_eq!(images.len(), MAX_BROWSER_IMAGES);
        assert!(truncated);
        assert_eq!(
            images[0]["src"].as_str().unwrap().chars().count(),
            MAX_BROWSER_IMAGE_TEXT_CHARS
        );
        let serialized = images[0].to_string();
        assert!(!serialized.contains("user:pass"));
        assert!(!serialized.contains("image-token"));
        assert!(!serialized.contains("#frag"));
        assert_eq!(
            images[0]["alt"].as_str().unwrap().chars().count(),
            MAX_BROWSER_IMAGE_TEXT_CHARS
        );
        assert!(images[0].get("ignored").is_none());
    }

    #[test]
    fn browser_snapshot_refs_are_bounded() {
        let mut refs = Map::new();
        for index in 0..(MAX_BROWSER_SNAPSHOT_REFS + 2) {
            refs.insert(
                format!("@e{index}"),
                json!({
                    "role": "button",
                    "label": "x".repeat(MAX_BROWSER_CONSOLE_TEXT_CHARS + 1),
                }),
            );
        }

        let (refs, count, truncated) = normalize_snapshot_refs(Value::Object(refs));
        let refs = refs.as_object().unwrap();
        assert_eq!(count, MAX_BROWSER_SNAPSHOT_REFS + 2);
        assert_eq!(refs.len(), MAX_BROWSER_SNAPSHOT_REFS);
        assert!(truncated);
        assert!(refs.values().next().unwrap()["label"]
            .as_str()
            .unwrap()
            .contains("[Truncated:"));
    }

    #[test]
    fn browser_console_output_bounds_page_controlled_values() {
        let long_text = "x".repeat(MAX_BROWSER_CONSOLE_TEXT_CHARS + 1);
        let mut items = Vec::new();
        for index in 0..(MAX_BROWSER_CONSOLE_ITEMS + 2) {
            items.push(json!({
                "text": long_text,
                "index": index,
                "nested": {
                    "value": ["ok", { "deep": long_text }]
                }
            }));
        }

        let (messages, count, truncated) = normalize_console_items(Value::Array(items));
        let messages = messages.as_array().unwrap();
        assert_eq!(count, MAX_BROWSER_CONSOLE_ITEMS + 2);
        assert_eq!(messages.len(), MAX_BROWSER_CONSOLE_ITEMS);
        assert!(truncated);
        assert!(messages[0]["text"]
            .as_str()
            .unwrap()
            .contains("[Truncated:"));

        let (bounded, value_truncated) =
            bound_console_value(json!({ "result": long_text, "items": messages }));
        assert!(value_truncated);
        assert!(bounded["result"].as_str().unwrap().contains("[Truncated:"));
    }

    #[test]
    fn browser_url_output_drops_credentials_query_and_fragment() {
        let (url, redacted) = sanitize_url_for_output(Some(
            "https://user:pass@example.com/callback?code=oauth-code#id-token",
        ));
        assert_eq!(url, json!("https://example.com/callback"));
        assert!(redacted);
        let serialized = url.to_string();
        assert!(!serialized.contains("user:pass"));
        assert!(!serialized.contains("oauth-code"));
        assert!(!serialized.contains("id-token"));

        let (url, redacted) = sanitize_url_for_output(None);
        assert_eq!(url, Value::Null);
        assert!(!redacted);

        let (url, redacted) = sanitize_url_for_output(Some("not a url?token=secret"));
        assert_eq!(url, json!("[redacted-url]"));
        assert!(redacted);

        let (url, redacted) = sanitize_url_for_output(Some("data:text/html,inline-secret"));
        assert_eq!(url, json!("[redacted-url]"));
        assert!(redacted);

        let (url, redacted) = sanitize_url_for_output(Some("javascript:alert('inline-secret')"));
        assert_eq!(url, json!("[redacted-url]"));
        assert!(redacted);
    }
}
