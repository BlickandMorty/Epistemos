//! Source: https://api-dashboard.search.brave.com/app/documentation/web-search/get-started
//! Source: https://api-dashboard.search.brave.com/documentation/guides/authentication
//! Source: https://help.kagi.com/kagi/api/search.html
//! Source: https://help.kagi.com/kagi/api/intro/auth.html
//! HTTPS-only web-search MCP executor for Brave Search and Kagi Search.
//! Credentials must be host-injected through the environment; tool
//! arguments are never allowed to carry API keys.

use crate::types::ToolResult;
use reqwest::blocking::Client;
use reqwest::header::{HeaderMap, HeaderValue, ACCEPT, AUTHORIZATION, USER_AGENT};
use serde_json::{json, Value};
use std::time::{Duration, Instant};

const BRAVE_SEARCH_URL: &str = "https://api.search.brave.com/res/v1/web/search";
const KAGI_SEARCH_URL: &str = "https://kagi.com/api/v0/search";
const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);
const DEFAULT_LIMIT: usize = 10;
const MAX_LIMIT: usize = 20;
const MAX_QUERY_CHARS: usize = 400;
const MAX_FILTER_CHARS: usize = 64;
const MAX_TEXT_CHARS: usize = 2_048;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SearchProvider {
    Brave,
    Kagi,
}

#[derive(Debug)]
struct SearchArgs {
    provider: SearchProvider,
    query: String,
    limit: usize,
    offset: usize,
    country: Option<String>,
    search_lang: Option<String>,
    ui_lang: Option<String>,
    freshness: Option<String>,
    safe_search: Option<String>,
    extra_snippets: bool,
}

#[derive(Debug)]
struct SearchResponse {
    body: Value,
    duration_ms: u64,
}

pub fn execute_web_search_tool(tool_name: String, args_json: String) -> String {
    let result = execute_web_search_tool_inner(&tool_name, &args_json);
    serde_json::to_string(&result).unwrap_or_default()
}

fn execute_web_search_tool_inner(tool_name: &str, args_json: &str) -> ToolResult {
    match tool_name {
        "web.search" | "web_search" => {}
        _ => {
            return ToolResult::err(
                format!("Unknown web-search tool: {tool_name}"),
                crate::types::error_codes::NOT_FOUND,
                0,
            )
        }
    }

    let args = match parse_args(args_json) {
        Ok(args) => args,
        Err(result) => return result,
    };
    if let Err(result) = reject_secret_args(&args) {
        return result;
    }
    let args = match search_args(&args) {
        Ok(args) => args,
        Err(result) => return result,
    };

    match args.provider {
        SearchProvider::Brave => execute_brave_search(&args),
        SearchProvider::Kagi => execute_kagi_search(&args),
    }
}

fn execute_brave_search(args: &SearchArgs) -> ToolResult {
    let token = match brave_key() {
        Some(token) => token,
        None => return ToolResult::err(
            "Brave Search is selected but BRAVE_SEARCH_API_KEY or BRAVE_API_KEY is not configured"
                .to_string(),
            crate::types::error_codes::PERMISSION_DENIED,
            0,
        ),
    };

    match request_brave(args, &token) {
        Ok(response) => ToolResult::ok(
            json!({
                "tool": "web.search",
                "provider": "brave",
                "endpoint": BRAVE_SEARCH_URL,
                "query": args.query,
                "items": normalize_brave_results(&response.body, args.limit),
            })
            .to_string(),
            response.duration_ms,
        ),
        Err(result) => result,
    }
}

fn execute_kagi_search(args: &SearchArgs) -> ToolResult {
    let token =
        match kagi_key() {
            Some(token) => token,
            None => return ToolResult::err(
                "Kagi Search is selected but KAGI_API_KEY or KAGI_SEARCH_API_KEY is not configured"
                    .to_string(),
                crate::types::error_codes::PERMISSION_DENIED,
                0,
            ),
        };

    match request_kagi(args, &token) {
        Ok(response) => ToolResult::ok(
            json!({
                "tool": "web.search",
                "provider": "kagi",
                "endpoint": KAGI_SEARCH_URL,
                "query": args.query,
                "items": normalize_kagi_results(&response.body, args.limit),
            })
            .to_string(),
            response.duration_ms,
        ),
        Err(result) => result,
    }
}

fn request_brave(args: &SearchArgs, token: &str) -> Result<SearchResponse, ToolResult> {
    let start = Instant::now();
    let client = search_client(start)?;
    let mut url = reqwest::Url::parse(BRAVE_SEARCH_URL).map_err(|error| {
        ToolResult::err(
            format!("Invalid Brave Search URL: {error}"),
            crate::types::error_codes::INVALID_INPUT,
            start.elapsed().as_millis() as u64,
        )
    })?;
    {
        let mut pairs = url.query_pairs_mut();
        pairs.append_pair("q", &args.query);
        pairs.append_pair("count", &args.limit.to_string());
        if args.offset > 0 {
            pairs.append_pair("offset", &args.offset.to_string());
        }
        if let Some(country) = args.country.as_deref() {
            pairs.append_pair("country", country);
        }
        if let Some(search_lang) = args.search_lang.as_deref() {
            pairs.append_pair("search_lang", search_lang);
        }
        if let Some(ui_lang) = args.ui_lang.as_deref() {
            pairs.append_pair("ui_lang", ui_lang);
        }
        if let Some(freshness) = args.freshness.as_deref() {
            pairs.append_pair("freshness", freshness);
        }
        if let Some(safe_search) = args.safe_search.as_deref() {
            pairs.append_pair("safesearch", safe_search);
        }
        if args.extra_snippets {
            pairs.append_pair("extra_snippets", "true");
        }
    }

    let mut headers = search_headers();
    let token = HeaderValue::from_str(token).map_err(|_| {
        ToolResult::err(
            "Brave Search token contains invalid header characters".to_string(),
            crate::types::error_codes::INVALID_INPUT,
            start.elapsed().as_millis() as u64,
        )
    })?;
    headers.insert("X-Subscription-Token", token);

    request_json(client.get(url).headers(headers), "Brave Search", start)
}

fn request_kagi(args: &SearchArgs, token: &str) -> Result<SearchResponse, ToolResult> {
    let start = Instant::now();
    let client = search_client(start)?;
    let mut url = reqwest::Url::parse(KAGI_SEARCH_URL).map_err(|error| {
        ToolResult::err(
            format!("Invalid Kagi Search URL: {error}"),
            crate::types::error_codes::INVALID_INPUT,
            start.elapsed().as_millis() as u64,
        )
    })?;
    {
        let mut pairs = url.query_pairs_mut();
        pairs.append_pair("q", &args.query);
        pairs.append_pair("limit", &args.limit.to_string());
    }

    let auth = format!("Bot {token}");
    let auth = HeaderValue::from_str(&auth).map_err(|_| {
        ToolResult::err(
            "Kagi Search token contains invalid header characters".to_string(),
            crate::types::error_codes::INVALID_INPUT,
            start.elapsed().as_millis() as u64,
        )
    })?;
    let mut headers = search_headers();
    headers.insert(AUTHORIZATION, auth);

    request_json(client.get(url).headers(headers), "Kagi Search", start)
}

fn search_client(start: Instant) -> Result<Client, ToolResult> {
    Client::builder()
        .timeout(DEFAULT_TIMEOUT)
        .build()
        .map_err(|error| {
            ToolResult::err(
                format!("Web-search HTTP client init failed: {error}"),
                crate::types::error_codes::EXECUTION_ERROR,
                start.elapsed().as_millis() as u64,
            )
        })
}

fn search_headers() -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.insert(USER_AGENT, HeaderValue::from_static("Epistemos/1.0"));
    headers.insert(ACCEPT, HeaderValue::from_static("application/json"));
    headers
}

fn request_json(
    request: reqwest::blocking::RequestBuilder,
    provider: &str,
    start: Instant,
) -> Result<SearchResponse, ToolResult> {
    let response = request.send().map_err(|error| {
        ToolResult::err(
            describe_request_error(provider, error),
            crate::types::error_codes::EXECUTION_ERROR,
            start.elapsed().as_millis() as u64,
        )
    })?;

    let status = response.status();
    let body = response.text().map_err(|error| {
        ToolResult::err(
            format!("{provider} response read failed: {error}"),
            crate::types::error_codes::EXECUTION_ERROR,
            start.elapsed().as_millis() as u64,
        )
    })?;
    let duration_ms = start.elapsed().as_millis() as u64;

    if !status.is_success() {
        let message = provider_error_message(&body).unwrap_or_else(|| status.to_string());
        return Err(ToolResult::err(
            format!("{provider} API request failed ({status}): {message}"),
            crate::types::error_codes::EXECUTION_ERROR,
            duration_ms,
        ));
    }

    let body = serde_json::from_str::<Value>(&body).map_err(|error| {
        ToolResult::err(
            format!("{provider} response was not JSON: {error}"),
            crate::types::error_codes::EXECUTION_ERROR,
            duration_ms,
        )
    })?;

    Ok(SearchResponse { body, duration_ms })
}

fn provider_error_message(body: &str) -> Option<String> {
    let value = serde_json::from_str::<Value>(body).ok()?;
    value
        .get("message")
        .or_else(|| value.get("error"))
        .and_then(|error| {
            error.as_str().map(ToString::to_string).or_else(|| {
                error
                    .get("message")
                    .and_then(Value::as_str)
                    .map(ToString::to_string)
            })
        })
}

fn parse_args(args_json: &str) -> Result<Value, ToolResult> {
    serde_json::from_str(args_json).map_err(|error| {
        ToolResult::err(
            format!("Invalid web-search tool arguments JSON: {error}"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        )
    })
}

fn reject_secret_args(args: &Value) -> Result<(), ToolResult> {
    for key in [
        "token",
        "authToken",
        "accessToken",
        "apiKey",
        "api_key",
        "braveApiKey",
        "kagiApiKey",
    ] {
        if args.get(key).is_some() {
            return Err(ToolResult::err(
                "Web-search credentials must come from Keychain-backed environment injection, not tool arguments".to_string(),
                crate::types::error_codes::INVALID_INPUT,
                0,
            ));
        }
    }
    Ok(())
}

fn search_args(args: &Value) -> Result<SearchArgs, ToolResult> {
    Ok(SearchArgs {
        provider: provider_arg(args)?,
        query: required_query(args)?,
        limit: bounded_usize(args, "limit", DEFAULT_LIMIT, 1, MAX_LIMIT),
        offset: bounded_usize(args, "offset", 0, 0, 9),
        country: optional_filter(args, "country")?,
        search_lang: optional_filter(args, "searchLang")?.or(optional_filter(args, "search_lang")?),
        ui_lang: optional_filter(args, "uiLang")?.or(optional_filter(args, "ui_lang")?),
        freshness: optional_filter(args, "freshness")?,
        safe_search: optional_filter(args, "safeSearch")?.or(optional_filter(args, "safesearch")?),
        extra_snippets: bool_arg(args, "extraSnippets") || bool_arg(args, "extra_snippets"),
    })
}

fn provider_arg(args: &Value) -> Result<SearchProvider, ToolResult> {
    let configured = args
        .get("provider")
        .or_else(|| args.get("backend"))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
        .or_else(|| {
            std::env::var("WEB_SEARCH_PROVIDER")
                .ok()
                .map(|value| value.trim().to_string())
                .filter(|value| !value.is_empty())
        });

    if let Some(provider) = configured {
        return parse_provider(&provider);
    }

    let brave = brave_key().is_some();
    let kagi = kagi_key().is_some();
    match (brave, kagi) {
        (true, false) => Ok(SearchProvider::Brave),
        (false, true) => Ok(SearchProvider::Kagi),
        (true, true) => Err(ToolResult::err(
            "Both Brave and Kagi search credentials are configured; pass provider:\"brave\" or provider:\"kagi\"".to_string(),
            crate::types::error_codes::INVALID_INPUT,
            0,
        )),
        (false, false) => Err(ToolResult::err(
            "No web-search provider is configured; set WEB_SEARCH_PROVIDER with a matching Brave or Kagi API key".to_string(),
            crate::types::error_codes::PERMISSION_DENIED,
            0,
        )),
    }
}

fn parse_provider(provider: &str) -> Result<SearchProvider, ToolResult> {
    match provider.to_ascii_lowercase().as_str() {
        "brave" | "brave_search" => Ok(SearchProvider::Brave),
        "kagi" | "kagi_search" => Ok(SearchProvider::Kagi),
        _ => Err(ToolResult::err(
            "web.search provider must be one of: brave|kagi".to_string(),
            crate::types::error_codes::INVALID_INPUT,
            0,
        )),
    }
}

fn required_query(args: &Value) -> Result<String, ToolResult> {
    let Some(value) = args
        .get("query")
        .or_else(|| args.get("q"))
        .and_then(Value::as_str)
    else {
        return Err(ToolResult::err(
            "web.search argument 'query' is required".to_string(),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    };
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(ToolResult::err(
            "web.search query must not be empty".to_string(),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    }
    if trimmed.chars().count() > MAX_QUERY_CHARS || trimmed.contains('\0') {
        return Err(ToolResult::err(
            format!("web.search query must be 1..={MAX_QUERY_CHARS} characters"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    }
    Ok(trimmed.to_string())
}

fn optional_filter(args: &Value, field: &str) -> Result<Option<String>, ToolResult> {
    let Some(value) = args.get(field) else {
        return Ok(None);
    };
    let Some(text) = value.as_str() else {
        return Err(ToolResult::err(
            format!("web.search argument '{field}' must be a string"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    };
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }
    if trimmed.chars().count() > MAX_FILTER_CHARS
        || trimmed.contains('\0')
        || trimmed.contains('\n')
        || trimmed.contains('\r')
    {
        return Err(ToolResult::err(
            format!("web.search argument '{field}' is not a safe search filter"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    }
    Ok(Some(trimmed.to_string()))
}

fn bounded_usize(args: &Value, field: &str, default: usize, min: usize, max: usize) -> usize {
    args.get(field)
        .and_then(Value::as_u64)
        .map(|value| value as usize)
        .unwrap_or(default)
        .clamp(min, max)
}

fn bool_arg(args: &Value, field: &str) -> bool {
    args.get(field).and_then(Value::as_bool).unwrap_or(false)
}

fn brave_key() -> Option<String> {
    env_key(&["BRAVE_SEARCH_API_KEY", "BRAVE_API_KEY"])
}

fn kagi_key() -> Option<String> {
    env_key(&["KAGI_API_KEY", "KAGI_SEARCH_API_KEY"])
}

fn env_key(names: &[&str]) -> Option<String> {
    names.iter().find_map(|name| {
        std::env::var(name)
            .ok()
            .map(|value| value.trim().to_string())
            .filter(|value| !value.is_empty())
    })
}

fn normalize_brave_results(value: &Value, limit: usize) -> Value {
    let Some(items) = value
        .get("web")
        .and_then(|web| web.get("results"))
        .and_then(Value::as_array)
    else {
        return Value::Array(Vec::new());
    };
    Value::Array(
        items
            .iter()
            .take(limit)
            .map(|item| {
                json!({
                    "title": text_value(item.get("title")),
                    "url": text_value(item.get("url")),
                    "snippet": text_value(item.get("description")),
                    "published": first_text_value(item, &["age", "page_age"]),
                    "source": "web",
                })
            })
            .collect(),
    )
}

fn normalize_kagi_results(value: &Value, limit: usize) -> Value {
    let Some(items) = value.get("data").and_then(Value::as_array) else {
        return Value::Array(Vec::new());
    };
    Value::Array(
        items
            .iter()
            .filter(|item| item.get("t").and_then(Value::as_i64) == Some(0))
            .take(limit)
            .map(|item| {
                json!({
                    "title": text_value(item.get("title")),
                    "url": text_value(item.get("url")),
                    "snippet": text_value(item.get("snippet")),
                    "published": text_value(item.get("published")),
                    "source": "web",
                })
            })
            .collect(),
    )
}

fn text_value(value: Option<&Value>) -> Value {
    value
        .and_then(Value::as_str)
        .map(|text| Value::String(text.chars().take(MAX_TEXT_CHARS).collect()))
        .unwrap_or(Value::Null)
}

fn first_text_value(object: &Value, fields: &[&str]) -> Value {
    fields
        .iter()
        .find_map(|field| object.get(field).and_then(Value::as_str))
        .map(|text| Value::String(text.chars().take(MAX_TEXT_CHARS).collect()))
        .unwrap_or(Value::Null)
}

fn describe_request_error(provider: &str, error: reqwest::Error) -> String {
    if error.is_timeout() {
        format!("{provider} API request timed out")
    } else if error.is_connect() {
        format!("{provider} API connection failed")
    } else {
        format!("{provider} API request failed: {error}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{json, Value};

    fn parsed(result: &str) -> Value {
        serde_json::from_str(result).expect("tool result json")
    }

    #[test]
    fn web_search_unknown_tool_returns_not_found() {
        let result = execute_web_search_tool("web.delete".to_string(), "{}".to_string());
        let json = parsed(&result);

        assert_eq!(json["success"], false);
        assert_eq!(json["error_code"], crate::types::error_codes::NOT_FOUND);
    }

    #[test]
    fn web_search_credentials_are_rejected_in_tool_args() {
        let result = execute_web_search_tool(
            "web.search".to_string(),
            r#"{"query":"rust","provider":"brave","apiKey":"secret"}"#.to_string(),
        );
        let json = parsed(&result);

        assert_eq!(json["success"], false);
        assert_eq!(json["error_code"], crate::types::error_codes::INVALID_INPUT);
        assert!(!json["error"].as_str().unwrap().contains("secret"));
    }

    #[test]
    fn web_search_rejects_unknown_provider() {
        let result = execute_web_search_tool(
            "web.search".to_string(),
            r#"{"query":"rust","provider":"bing"}"#.to_string(),
        );
        let json = parsed(&result);

        assert_eq!(json["success"], false);
        assert_eq!(json["error_code"], crate::types::error_codes::INVALID_INPUT);
    }

    #[test]
    fn brave_normalization_maps_web_results() {
        let api = json!({
            "web": {
                "results": [
                    {
                        "title": "Rust",
                        "url": "https://www.rust-lang.org/",
                        "description": "A language empowering everyone.",
                        "age": "2026-05-01"
                    }
                ]
            }
        });

        let normalized = normalize_brave_results(&api, 10);
        assert_eq!(normalized[0]["title"], "Rust");
        assert_eq!(normalized[0]["url"], "https://www.rust-lang.org/");
        assert_eq!(normalized[0]["snippet"], "A language empowering everyone.");
        assert_eq!(normalized[0]["published"], "2026-05-01");
    }

    #[test]
    fn kagi_normalization_filters_related_searches() {
        let api = json!({
            "data": [
                {
                    "t": 1,
                    "list": ["rust ownership", "rust borrow checker"]
                },
                {
                    "t": 0,
                    "title": "Rust",
                    "url": "https://www.rust-lang.org/",
                    "snippet": "A language empowering everyone.",
                    "published": "2026-05-01T00:00:00Z"
                }
            ]
        });

        let normalized = normalize_kagi_results(&api, 10);
        assert_eq!(normalized.as_array().unwrap().len(), 1);
        assert_eq!(normalized[0]["title"], "Rust");
        assert_eq!(normalized[0]["published"], "2026-05-01T00:00:00Z");
    }

    #[test]
    fn query_is_required_and_bounded() {
        let result = required_query(&json!({"query":"  rust ffi  "})).unwrap();
        assert_eq!(result, "rust ffi");

        let too_long = "x".repeat(MAX_QUERY_CHARS + 1);
        let err = required_query(&json!({"query": too_long})).unwrap_err();
        assert_eq!(
            err.error_code.as_deref(),
            Some(crate::types::error_codes::INVALID_INPUT)
        );
    }
}
