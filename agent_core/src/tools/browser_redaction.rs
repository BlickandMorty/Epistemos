const MAX_BROWSER_ERROR_CHARS: usize = 512;

pub(crate) fn redact_browser_error_detail(raw: &str) -> String {
    let mut redact_next = false;
    let collapsed = raw
        .split_whitespace()
        .map(|token| {
            let lower = token.to_ascii_lowercase();
            let should_redact = redact_next;
            redact_next = redacts_following_auth_value(&lower);
            if should_redact {
                "[redacted]".to_string()
            } else {
                redact_browser_error_token(token)
            }
        })
        .collect::<Vec<_>>()
        .join(" ");
    let mut limited: String = collapsed.chars().take(MAX_BROWSER_ERROR_CHARS).collect();
    if collapsed.chars().count() > MAX_BROWSER_ERROR_CHARS {
        limited.push_str("... [error truncated]");
    }
    if limited.is_empty() {
        "agent-browser reported failure".to_string()
    } else {
        limited
    }
}

fn redact_browser_error_token(token: &str) -> String {
    let lower = token.to_ascii_lowercase();
    if lower.contains("authorization")
        || lower.contains("cookie")
        || contains_secret_assignment(&lower, "token")
        || contains_secret_assignment(&lower, "access_token")
        || contains_secret_assignment(&lower, "refresh_token")
        || contains_secret_assignment(&lower, "api_key")
        || contains_secret_assignment(&lower, "api-key")
        || contains_secret_assignment(&lower, "apikey")
        || contains_secret_assignment(&lower, "x-api-key")
        || contains_secret_assignment(&lower, "password")
        || contains_secret_assignment(&lower, "secret")
        || lower.contains("bearer")
        || lower.contains("sk-")
        || lower.contains("ghp_")
        || lower.contains("xoxb-")
    {
        return "[redacted]".to_string();
    }

    if let Some(scheme_index) = token.find("://") {
        let rest = &token[scheme_index + 3..];
        if rest.contains('@') {
            return format!(
                "{}://[redacted]@{}",
                &token[..scheme_index],
                rest.rsplit('@').next().unwrap_or("")
            );
        }
    }

    token.to_string()
}

fn contains_secret_assignment(lower_token: &str, key: &str) -> bool {
    ["=", ":", "%3d", "%3a"]
        .iter()
        .any(|separator| lower_token.contains(&format!("{key}{separator}")))
}

fn redacts_following_auth_value(lower_token: &str) -> bool {
    let token = lower_token.trim_matches(|value: char| {
        matches!(value, '"' | '\'' | ',' | ';' | '[' | ']' | '(' | ')')
    });
    if token.starts_with("authorization:")
        || token.starts_with("proxy-authorization:")
        || token.starts_with("bearer:")
        || token.starts_with("basic:")
    {
        return true;
    }
    matches!(
        token,
        "authorization:"
            | "proxy-authorization:"
            | "bearer"
            | "basic"
            | "token:"
            | "access_token:"
            | "refresh_token:"
            | "api-key:"
            | "x-api-key:"
            | "api_key:"
            | "apikey:"
            | "password:"
            | "secret:"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn browser_error_redaction_covers_secret_assignment_variants() {
        let detail = redact_browser_error_detail(
            "Authorization: Bearer opaqueBearerValue Proxy-Authorization: Basic basic-secret \
             Authorization:Bearer compact-bearer Proxy-Authorization:Basic compact-basic \
             Api-Key: split-key access_token:tok refresh_token=refresh \
             api-key=key x-api-key:key api_key%3Dencoded password:pw secret%3Ahidden \
             https://user:pass@example.com/path",
        );

        assert!(detail.contains("[redacted]"));
        for leaked in [
            "Bearer",
            "access_token",
            "refresh_token",
            "api-key",
            "x-api-key",
            "api_key",
            "password",
            "secret",
            "user:pass",
            "opaqueBearerValue",
            "basic-secret",
            "compact-bearer",
            "compact-basic",
            "split-key",
            "tok",
            "refresh",
            "hidden",
        ] {
            assert!(
                !detail.contains(leaked),
                "browser error detail leaked {leaked}: {detail}"
            );
        }
    }
}
