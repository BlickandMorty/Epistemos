use serde_json::Value;

use super::registry::ToolError;

const SNAPSHOT_CHAR_CAP: usize = 8_000;
const MAX_BROWSER_REF_CHARS: usize = 64;

pub(crate) fn optional_bool_field(input: &Value, field: &str) -> Result<Option<bool>, ToolError> {
    let Some(value) = input.get(field) else {
        return Ok(None);
    };
    value
        .as_bool()
        .map(Some)
        .ok_or_else(|| ToolError::InvalidArguments(format!("'{field}' must be a boolean")))
}

pub(crate) fn optional_string_field<'a>(
    input: &'a Value,
    field: &str,
) -> Result<Option<&'a str>, ToolError> {
    let Some(value) = input.get(field) else {
        return Ok(None);
    };
    value
        .as_str()
        .map(Some)
        .ok_or_else(|| ToolError::InvalidArguments(format!("'{field}' must be a string")))
}

pub(crate) fn normalize_ref(raw_ref: &str) -> Result<String, ToolError> {
    let trimmed = raw_ref.trim();
    if trimmed.is_empty() {
        return Err(ToolError::InvalidArguments("ref cannot be empty".into()));
    }
    let value = trimmed.strip_prefix('@').unwrap_or(trimmed);
    if value.is_empty() || value.len() > MAX_BROWSER_REF_CHARS {
        return Err(ToolError::InvalidArguments("invalid ref".into()));
    }
    if !value
        .chars()
        .all(|ch| ch.is_ascii_alphanumeric() || ch == '_' || ch == '-')
    {
        return Err(ToolError::InvalidArguments("invalid ref".into()));
    }
    if trimmed.starts_with('@') {
        Ok(trimmed.to_string())
    } else {
        Ok(format!("@{trimmed}"))
    }
}

pub(crate) fn truncate_snapshot(snapshot: &str) -> (String, bool) {
    let total_chars = snapshot.chars().count();
    if total_chars <= SNAPSHOT_CHAR_CAP {
        return (snapshot.to_string(), false);
    }

    let truncated: String = snapshot.chars().take(SNAPSHOT_CHAR_CAP).collect();
    (
        format!("{truncated}\n\n[Truncated: {} total chars]", total_chars),
        true,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn browser_input_normalizes_refs_and_truncates_snapshots() {
        assert_eq!(normalize_ref("e1").unwrap(), "@e1");
        assert_eq!(normalize_ref(" @e2 ").unwrap(), "@e2");
        assert!(format!("{}", normalize_ref("   ").unwrap_err()).contains("ref cannot be empty"));
        assert!(format!("{}", normalize_ref("../secret").unwrap_err()).contains("invalid ref"));
        assert!(format!(
            "{}",
            normalize_ref(&"a".repeat(MAX_BROWSER_REF_CHARS + 1)).unwrap_err()
        )
        .contains("invalid ref"));

        let (short, short_truncated) = truncate_snapshot("hello");
        assert_eq!(short, "hello");
        assert!(!short_truncated);

        let long = "x".repeat(SNAPSHOT_CHAR_CAP + 1);
        let (truncated, long_truncated) = truncate_snapshot(&long);
        assert!(long_truncated);
        assert!(truncated.contains("Truncated"));
        assert!(!truncated.contains(&"x".repeat(SNAPSHOT_CHAR_CAP + 1)));
    }
}
