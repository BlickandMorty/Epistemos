const MAX_BROWSER_ERROR_CHARS: usize = 512;

pub(crate) fn redact_browser_error_detail(raw: &str) -> String {
    let mut redact_next = false;
    let mut redact_assignment_separator = false;
    let collapsed = raw
        .split_whitespace()
        .map(|token| {
            let lower = token.to_ascii_lowercase();
            if redact_assignment_separator && starts_with_assignment_separator_token(&lower) {
                let separator_only = is_assignment_separator_token(&lower);
                redact_assignment_separator = false;
                redact_next = separator_only;
                return "[redacted]".to_string();
            }

            let should_redact = redact_next;
            redact_next = redacts_following_auth_value(&lower);
            redact_assignment_separator = false;
            if should_redact {
                "[redacted]".to_string()
            } else if redacts_split_secret_assignment_key(&lower) {
                redact_assignment_separator = true;
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
        || contains_secret_assignment(&lower, "client_secret")
        || contains_secret_assignment(&lower, "id_token")
        || contains_secret_assignment(&lower, "auth_code")
        || contains_secret_assignment(&lower, "authorization_code")
        || contains_secret_assignment(&lower, "password")
        || contains_secret_assignment(&lower, "secret")
        || lower.contains("bearer")
        || lower.contains("sk-")
        || lower.contains("ghp_")
        || lower.contains("xoxb-")
    {
        return "[redacted]".to_string();
    }

    if let Some(redacted_url) = redact_url_token(token) {
        return redacted_url;
    }

    token.to_string()
}

fn redact_url_token(token: &str) -> Option<String> {
    if let Some(scheme_index) = token.find("://") {
        let rest = &token[scheme_index + 3..];
        if rest.contains('@') || rest.contains('?') || rest.contains('#') {
            return Some(format!("{}://[redacted-url]", &token[..scheme_index]));
        }
    }
    None
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
        "authorization:" | "proxy-authorization:" | "bearer" | "basic"
    ) || bare_secret_assignment_marker(token)
}

fn redacts_split_secret_assignment_key(lower_token: &str) -> bool {
    let token = lower_token.trim_matches(|value: char| {
        matches!(value, '"' | '\'' | ',' | ';' | '[' | ']' | '(' | ')')
    });
    is_secret_key_token(token)
}

fn bare_secret_assignment_marker(token: &str) -> bool {
    [":", "=", "%3d", "%3a"].iter().any(|separator| {
        token
            .strip_suffix(separator)
            .is_some_and(is_secret_key_token)
    })
}

fn is_secret_key_token(token: &str) -> bool {
    matches!(
        token,
        "token"
            | "access_token"
            | "refresh_token"
            | "api-key"
            | "x-api-key"
            | "api_key"
            | "apikey"
            | "client_secret"
            | "id_token"
            | "auth_code"
            | "authorization_code"
            | "password"
            | "secret"
    )
}

fn is_assignment_separator_token(lower_token: &str) -> bool {
    let token = lower_token.trim_matches(|value: char| {
        matches!(value, '"' | '\'' | ',' | ';' | '[' | ']' | '(' | ')')
    });
    matches!(token, "=" | ":" | "%3d" | "%3a")
}

fn starts_with_assignment_separator_token(lower_token: &str) -> bool {
    let token = lower_token.trim_matches(|value: char| {
        matches!(value, '"' | '\'' | ',' | ';' | '[' | ']' | '(' | ')')
    });
    token.starts_with('=')
        || token.starts_with(':')
        || token.starts_with("%3d")
        || token.starts_with("%3a")
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
             api-key=key x-api-key:key api_key%3Dencoded client_secret=client id_token:jwt auth_code=oauth-code \
             api_key = split-api-key client_secret : split-client-secret id_token =split-id-token password= split-password \
             password:pw secret%3Ahidden https://user:pass@example.com/path \
             https://example.com/callback?code=oauth-code#id_token=jwt",
        );

        assert!(detail.contains("[redacted]"));
        for leaked in [
            "Bearer",
            "access_token",
            "refresh_token",
            "api-key",
            "x-api-key",
            "api_key",
            "client_secret",
            "id_token",
            "password",
            "secret",
            "user:pass",
            "oauth-code",
            "opaqueBearerValue",
            "basic-secret",
            "compact-bearer",
            "compact-basic",
            "split-key",
            "tok",
            "refresh",
            "hidden",
            "split-api-key",
            "split-client-secret",
            "split-id-token",
            "split-password",
            "callback?code",
        ] {
            assert!(
                !detail.contains(leaked),
                "browser error detail leaked {leaked}: {detail}"
            );
        }
    }
}
