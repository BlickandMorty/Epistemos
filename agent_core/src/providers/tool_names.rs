//! Provider wire-name mapping for canonical Tools V2 names.
//!
//! The app's canonical model/runtime contract uses dotted names such as
//! `vault.search`, but several provider APIs reject dots in function names.
//! Use a reversible `__` wire spelling at provider boundaries and convert back
//! before dispatch.

pub fn api_safe_tool_name(name: &str) -> String {
    let canonical = crate::tools::registry::v2_name_for_legacy(name).unwrap_or(name);
    let mut out = String::with_capacity(canonical.len() + 4);
    for ch in canonical.chars() {
        match ch {
            '.' => out.push_str("__"),
            'A'..='Z' | 'a'..='z' | '0'..='9' | '_' | '-' => out.push(ch),
            _ => out.push('_'),
        }
    }
    if out.is_empty() {
        "tool".to_string()
    } else {
        out
    }
}

pub fn canonical_tool_name_from_api(name: &str) -> String {
    if name.contains("__") {
        name.replace("__", ".")
    } else {
        crate::tools::registry::v2_name_for_legacy(name)
            .unwrap_or(name)
            .to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn api_safe_tool_names_preserve_tools_v2_without_dots() {
        assert_eq!(api_safe_tool_name("vault.search"), "vault__search");
        assert_eq!(api_safe_tool_name("vault_search"), "vault__search");
        assert_eq!(
            canonical_tool_name_from_api("vault__search"),
            "vault.search"
        );
        assert_eq!(canonical_tool_name_from_api("vault_search"), "vault.search");
    }
}
