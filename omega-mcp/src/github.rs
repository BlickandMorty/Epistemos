//! Source: https://docs.github.com/en/rest/repos/repos#get-a-repository
//! Source: https://docs.github.com/en/rest/issues/issues#list-repository-issues
//! Source: https://docs.github.com/en/rest/pulls/pulls#list-pull-requests
//! Source: https://docs.github.com/en/rest/releases/releases#list-releases
//! Read-only GitHub MCP executor for repository metadata, issues, pull
//! requests, and releases. All exposed routes are HTTP GET requests.

use crate::types::ToolResult;
use reqwest::blocking::Client;
use reqwest::header::{HeaderMap, HeaderValue, ACCEPT, AUTHORIZATION, USER_AGENT};
use serde_json::{json, Value};
use std::time::{Duration, Instant};

const API_BASE: &str = "https://api.github.com";
const API_VERSION: &str = "2026-03-10";
const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);
const DEFAULT_PER_PAGE: u64 = 30;
const MAX_PER_PAGE: u64 = 100;
const MAX_PAGE: u64 = 100;
const MAX_FILTER_CHARS: usize = 512;
const MAX_TEXT_CHARS: usize = 4_096;

#[derive(Debug)]
struct RepoArgs {
    owner: String,
    repo: String,
}

#[derive(Debug)]
struct GitHubResponse {
    body: Value,
    duration_ms: u64,
}

pub fn execute_github_tool(tool_name: String, args_json: String) -> String {
    let result = execute_github_tool_inner(&tool_name, &args_json);
    serde_json::to_string(&result).unwrap_or_default()
}

fn execute_github_tool_inner(tool_name: &str, args_json: &str) -> ToolResult {
    let args = match parse_args(args_json) {
        Ok(args) => args,
        Err(result) => return result,
    };

    if let Err(result) = reject_token_args(&args) {
        return result;
    }

    match tool_name {
        "github.repo" | "github_repository" => execute_repo(&args),
        "github.issues" | "github_issues" => execute_issues(&args),
        "github.pulls" | "github_pull_requests" | "github_prs" => execute_pulls(&args),
        "github.releases" | "github_releases" => execute_releases(&args),
        _ => ToolResult::err(
            format!("Unknown GitHub tool: {tool_name}"),
            crate::types::error_codes::NOT_FOUND,
            0,
        ),
    }
}

fn execute_repo(args: &Value) -> ToolResult {
    let repo = match repo_args(args) {
        Ok(repo) => repo,
        Err(result) => return result,
    };
    let path = format!("/repos/{}/{}", repo.owner, repo.repo);

    match request_json(&path, &[]) {
        Ok(response) => ToolResult::ok(
            json!({
                "tool": "github.repo",
                "endpoint": path,
                "repository": normalize_repo(&response.body),
            })
            .to_string(),
            response.duration_ms,
        ),
        Err(result) => result,
    }
}

fn execute_issues(args: &Value) -> ToolResult {
    let repo = match repo_args(args) {
        Ok(repo) => repo,
        Err(result) => return result,
    };
    let path = format!("/repos/{}/{}", repo.owner, repo.repo);
    let path = format!("{path}/issues");
    let state = match enum_arg(args, "state", &["open", "closed", "all"], "open") {
        Ok(value) => value,
        Err(result) => return result,
    };
    let sort = match enum_arg(args, "sort", &["created", "updated", "comments"], "created") {
        Ok(value) => value,
        Err(result) => return result,
    };
    let direction = match enum_arg(args, "direction", &["asc", "desc"], "desc") {
        Ok(value) => value,
        Err(result) => return result,
    };
    let per_page = bounded_u64(args, "perPage", DEFAULT_PER_PAGE, 1, MAX_PER_PAGE);
    let page = bounded_u64(args, "page", 1, 1, MAX_PAGE);
    let labels = match optional_filter(args, "labels") {
        Ok(value) => value,
        Err(result) => return result,
    };
    let since = match optional_filter(args, "since") {
        Ok(value) => value,
        Err(result) => return result,
    };

    let per_page_s = per_page.to_string();
    let page_s = page.to_string();
    let mut query = vec![
        ("state", state.as_str()),
        ("sort", sort.as_str()),
        ("direction", direction.as_str()),
        ("per_page", per_page_s.as_str()),
        ("page", page_s.as_str()),
    ];
    if let Some(labels) = labels.as_deref() {
        query.push(("labels", labels));
    }
    if let Some(since) = since.as_deref() {
        query.push(("since", since));
    }

    match request_json(&path, &query) {
        Ok(response) => ToolResult::ok(
            json!({
                "tool": "github.issues",
                "endpoint": path,
                "items": normalize_issues(&response.body),
            })
            .to_string(),
            response.duration_ms,
        ),
        Err(result) => result,
    }
}

fn execute_pulls(args: &Value) -> ToolResult {
    let repo = match repo_args(args) {
        Ok(repo) => repo,
        Err(result) => return result,
    };
    let path = format!("/repos/{}/{}/pulls", repo.owner, repo.repo);
    let state = match enum_arg(args, "state", &["open", "closed", "all"], "open") {
        Ok(value) => value,
        Err(result) => return result,
    };
    let sort = match enum_arg(
        args,
        "sort",
        &["created", "updated", "popularity", "long-running"],
        "created",
    ) {
        Ok(value) => value,
        Err(result) => return result,
    };
    let direction = match enum_arg(args, "direction", &["asc", "desc"], "desc") {
        Ok(value) => value,
        Err(result) => return result,
    };
    let per_page = bounded_u64(args, "perPage", DEFAULT_PER_PAGE, 1, MAX_PER_PAGE);
    let page = bounded_u64(args, "page", 1, 1, MAX_PAGE);
    let base = match optional_filter(args, "base") {
        Ok(value) => value,
        Err(result) => return result,
    };
    let head = match optional_filter(args, "head") {
        Ok(value) => value,
        Err(result) => return result,
    };

    let per_page_s = per_page.to_string();
    let page_s = page.to_string();
    let mut query = vec![
        ("state", state.as_str()),
        ("sort", sort.as_str()),
        ("direction", direction.as_str()),
        ("per_page", per_page_s.as_str()),
        ("page", page_s.as_str()),
    ];
    if let Some(base) = base.as_deref() {
        query.push(("base", base));
    }
    if let Some(head) = head.as_deref() {
        query.push(("head", head));
    }

    match request_json(&path, &query) {
        Ok(response) => ToolResult::ok(
            json!({
                "tool": "github.pulls",
                "endpoint": path,
                "items": normalize_pulls(&response.body),
            })
            .to_string(),
            response.duration_ms,
        ),
        Err(result) => result,
    }
}

fn execute_releases(args: &Value) -> ToolResult {
    let repo = match repo_args(args) {
        Ok(repo) => repo,
        Err(result) => return result,
    };
    let path = format!("/repos/{}/{}/releases", repo.owner, repo.repo);
    let per_page = bounded_u64(args, "perPage", DEFAULT_PER_PAGE, 1, MAX_PER_PAGE);
    let page = bounded_u64(args, "page", 1, 1, MAX_PAGE);
    let per_page_s = per_page.to_string();
    let page_s = page.to_string();
    let query = [("per_page", per_page_s.as_str()), ("page", page_s.as_str())];

    match request_json(&path, &query) {
        Ok(response) => ToolResult::ok(
            json!({
                "tool": "github.releases",
                "endpoint": path,
                "items": normalize_releases(&response.body),
            })
            .to_string(),
            response.duration_ms,
        ),
        Err(result) => result,
    }
}

fn request_json(path: &str, query: &[(&str, &str)]) -> Result<GitHubResponse, ToolResult> {
    let start = Instant::now();
    let client = Client::builder()
        .timeout(DEFAULT_TIMEOUT)
        .build()
        .map_err(|error| {
            ToolResult::err(
                format!("GitHub HTTP client init failed: {error}"),
                crate::types::error_codes::EXECUTION_ERROR,
                start.elapsed().as_millis() as u64,
            )
        })?;

    let mut url = reqwest::Url::parse(API_BASE)
        .and_then(|base| base.join(path.trim_start_matches('/')))
        .map_err(|error| {
            ToolResult::err(
                format!("Invalid GitHub API URL: {error}"),
                crate::types::error_codes::INVALID_INPUT,
                start.elapsed().as_millis() as u64,
            )
        })?;
    {
        let mut pairs = url.query_pairs_mut();
        for (key, value) in query {
            pairs.append_pair(key, value);
        }
    }

    let mut headers = github_headers();
    if let Some(token) = github_token() {
        let bearer = format!("Bearer {token}");
        match HeaderValue::from_str(&bearer) {
            Ok(value) => {
                headers.insert(AUTHORIZATION, value);
            }
            Err(_) => {
                return Err(ToolResult::err(
                    "GitHub token contains invalid header characters".to_string(),
                    crate::types::error_codes::INVALID_INPUT,
                    start.elapsed().as_millis() as u64,
                ))
            }
        }
    }

    let response = client.get(url).headers(headers).send().map_err(|error| {
        ToolResult::err(
            describe_github_request_error(error),
            crate::types::error_codes::EXECUTION_ERROR,
            start.elapsed().as_millis() as u64,
        )
    })?;

    let status = response.status();
    let body = response.text().map_err(|error| {
        ToolResult::err(
            format!("GitHub response read failed: {error}"),
            crate::types::error_codes::EXECUTION_ERROR,
            start.elapsed().as_millis() as u64,
        )
    })?;
    let duration_ms = start.elapsed().as_millis() as u64;

    if !status.is_success() {
        let message = serde_json::from_str::<Value>(&body)
            .ok()
            .and_then(|value| value["message"].as_str().map(ToString::to_string))
            .unwrap_or_else(|| status.to_string());
        return Err(ToolResult::err(
            format!("GitHub API request failed ({status}): {message}"),
            crate::types::error_codes::EXECUTION_ERROR,
            duration_ms,
        ));
    }

    let body = serde_json::from_str::<Value>(&body).map_err(|error| {
        ToolResult::err(
            format!("GitHub response was not JSON: {error}"),
            crate::types::error_codes::EXECUTION_ERROR,
            duration_ms,
        )
    })?;

    Ok(GitHubResponse { body, duration_ms })
}

fn github_headers() -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.insert(USER_AGENT, HeaderValue::from_static("Epistemos/1.0"));
    headers.insert(
        ACCEPT,
        HeaderValue::from_static("application/vnd.github+json"),
    );
    headers.insert(
        "X-GitHub-Api-Version",
        HeaderValue::from_static(API_VERSION),
    );
    headers
}

fn github_token() -> Option<String> {
    std::env::var("GITHUB_TOKEN")
        .ok()
        .or_else(|| std::env::var("GH_TOKEN").ok())
        .map(|token| token.trim().to_string())
        .filter(|token| !token.is_empty())
}

fn parse_args(args_json: &str) -> Result<Value, ToolResult> {
    serde_json::from_str(args_json).map_err(|error| {
        ToolResult::err(
            format!("Invalid GitHub tool arguments JSON: {error}"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        )
    })
}

fn reject_token_args(args: &Value) -> Result<(), ToolResult> {
    for key in ["token", "authToken", "githubToken", "accessToken"] {
        if args.get(key).is_some() {
            return Err(ToolResult::err(
                "GitHub credentials must come from Keychain-backed environment injection (GITHUB_TOKEN or GH_TOKEN), not tool arguments".to_string(),
                crate::types::error_codes::INVALID_INPUT,
                0,
            ));
        }
    }
    Ok(())
}

fn repo_args(args: &Value) -> Result<RepoArgs, ToolResult> {
    let owner = required_slug(args, "owner", SlugKind::Owner)?;
    let repo = required_slug(args, "repo", SlugKind::Repo)?;
    Ok(RepoArgs { owner, repo })
}

#[derive(Debug, Clone, Copy)]
enum SlugKind {
    Owner,
    Repo,
}

fn required_slug(args: &Value, field: &str, kind: SlugKind) -> Result<String, ToolResult> {
    let Some(value) = args.get(field).and_then(Value::as_str) else {
        return Err(ToolResult::err(
            format!("GitHub argument '{field}' is required"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    };
    validate_slug(value, field, kind)?;
    Ok(value.to_string())
}

fn validate_slug(value: &str, field: &str, kind: SlugKind) -> Result<(), ToolResult> {
    let max_len = match kind {
        SlugKind::Owner => 39,
        SlugKind::Repo => 100,
    };
    if value.is_empty() || value.chars().count() > max_len {
        return Err(ToolResult::err(
            format!("GitHub argument '{field}' must be 1..={max_len} characters"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    }
    if value.starts_with('-') || value.ends_with('-') || value.contains("..") {
        return Err(ToolResult::err(
            format!("GitHub argument '{field}' is not a valid repository identifier"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    }
    let valid = value.chars().all(|ch| match kind {
        SlugKind::Owner => ch.is_ascii_alphanumeric() || ch == '-',
        SlugKind::Repo => ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_' | '.'),
    });
    if !valid {
        return Err(ToolResult::err(
            format!("GitHub argument '{field}' contains unsupported characters"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    }
    Ok(())
}

fn enum_arg(
    args: &Value,
    field: &str,
    allowed: &[&str],
    default: &str,
) -> Result<String, ToolResult> {
    let value = args
        .get(field)
        .and_then(Value::as_str)
        .unwrap_or(default)
        .to_ascii_lowercase();
    if allowed.contains(&value.as_str()) {
        Ok(value)
    } else {
        Err(ToolResult::err(
            format!(
                "GitHub argument '{field}' must be one of: {}",
                allowed.join("|")
            ),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ))
    }
}

fn optional_filter(args: &Value, field: &str) -> Result<Option<String>, ToolResult> {
    let Some(value) = args.get(field) else {
        return Ok(None);
    };
    let Some(text) = value.as_str() else {
        return Err(ToolResult::err(
            format!("GitHub argument '{field}' must be a string"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    };
    if text.chars().count() > MAX_FILTER_CHARS || text.contains('\0') || text.contains('\n') {
        return Err(ToolResult::err(
            format!("GitHub argument '{field}' is not a safe query filter"),
            crate::types::error_codes::INVALID_INPUT,
            0,
        ));
    }
    let trimmed = text.trim();
    if trimmed.is_empty() {
        Ok(None)
    } else {
        Ok(Some(trimmed.to_string()))
    }
}

fn bounded_u64(args: &Value, field: &str, default: u64, min: u64, max: u64) -> u64 {
    args.get(field)
        .or_else(|| snake_case_alias(args, field).and_then(|alias| args.get(alias)))
        .and_then(Value::as_u64)
        .unwrap_or(default)
        .clamp(min, max)
}

fn snake_case_alias<'a>(_args: &'a Value, field: &str) -> Option<&'a str> {
    match field {
        "perPage" => Some("per_page"),
        _ => None,
    }
}

fn normalize_repo(repo: &Value) -> Value {
    json!({
        "id": repo["id"],
        "name": repo["name"],
        "full_name": repo["full_name"],
        "html_url": repo["html_url"],
        "description": limited(repo["description"].as_str()),
        "default_branch": repo["default_branch"],
        "private": repo["private"],
        "fork": repo["fork"],
        "archived": repo["archived"],
        "stargazers_count": repo["stargazers_count"],
        "forks_count": repo["forks_count"],
        "open_issues_count": repo["open_issues_count"],
        "license": repo["license"].as_object().map(|_| json!({
            "key": repo["license"]["key"],
            "name": repo["license"]["name"],
            "spdx_id": repo["license"]["spdx_id"],
        })).unwrap_or(Value::Null),
        "created_at": repo["created_at"],
        "updated_at": repo["updated_at"],
        "pushed_at": repo["pushed_at"],
    })
}

fn normalize_issues(value: &Value) -> Value {
    let Some(items) = value.as_array() else {
        return Value::Array(Vec::new());
    };
    Value::Array(
        items
            .iter()
            .filter(|item| item.get("pull_request").is_none())
            .map(normalize_issue)
            .collect(),
    )
}

fn normalize_issue(issue: &Value) -> Value {
    json!({
        "number": issue["number"],
        "title": issue["title"],
        "state": issue["state"],
        "html_url": issue["html_url"],
        "user": issue["user"]["login"],
        "labels": label_names(issue),
        "comments": issue["comments"],
        "body": limited(issue["body"].as_str()),
        "created_at": issue["created_at"],
        "updated_at": issue["updated_at"],
        "closed_at": issue["closed_at"],
    })
}

fn normalize_pulls(value: &Value) -> Value {
    let Some(items) = value.as_array() else {
        return Value::Array(Vec::new());
    };
    Value::Array(items.iter().map(normalize_pull).collect())
}

fn normalize_pull(pull: &Value) -> Value {
    json!({
        "number": pull["number"],
        "title": pull["title"],
        "state": pull["state"],
        "draft": pull["draft"],
        "html_url": pull["html_url"],
        "user": pull["user"]["login"],
        "head": {
            "ref": pull["head"]["ref"],
            "sha": pull["head"]["sha"],
            "repo": pull["head"]["repo"]["full_name"],
        },
        "base": {
            "ref": pull["base"]["ref"],
            "sha": pull["base"]["sha"],
            "repo": pull["base"]["repo"]["full_name"],
        },
        "body": limited(pull["body"].as_str()),
        "created_at": pull["created_at"],
        "updated_at": pull["updated_at"],
        "closed_at": pull["closed_at"],
        "merged_at": pull["merged_at"],
    })
}

fn normalize_releases(value: &Value) -> Value {
    let Some(items) = value.as_array() else {
        return Value::Array(Vec::new());
    };
    Value::Array(items.iter().map(normalize_release).collect())
}

fn normalize_release(release: &Value) -> Value {
    json!({
        "id": release["id"],
        "tag_name": release["tag_name"],
        "name": release["name"],
        "html_url": release["html_url"],
        "draft": release["draft"],
        "prerelease": release["prerelease"],
        "immutable": release["immutable"],
        "author": release["author"]["login"],
        "body": limited(release["body"].as_str()),
        "created_at": release["created_at"],
        "published_at": release["published_at"],
        "assets": release["assets"].as_array().map(|assets| {
            Value::Array(assets.iter().map(|asset| json!({
                "name": asset["name"],
                "label": asset["label"],
                "content_type": asset["content_type"],
                "size": asset["size"],
                "download_count": asset["download_count"],
                "browser_download_url": asset["browser_download_url"],
            })).collect())
        }).unwrap_or_else(|| Value::Array(Vec::new())),
    })
}

fn label_names(issue: &Value) -> Value {
    let Some(labels) = issue["labels"].as_array() else {
        return Value::Array(Vec::new());
    };
    Value::Array(
        labels
            .iter()
            .filter_map(|label| {
                label["name"]
                    .as_str()
                    .map(|name| Value::String(name.to_string()))
            })
            .collect(),
    )
}

fn limited(value: Option<&str>) -> Value {
    match value {
        Some(text) => Value::String(text.chars().take(MAX_TEXT_CHARS).collect()),
        None => Value::Null,
    }
}

fn describe_github_request_error(error: reqwest::Error) -> String {
    if error.is_timeout() {
        "GitHub API request timed out".to_string()
    } else if error.is_connect() {
        "GitHub API connection failed".to_string()
    } else {
        format!("GitHub API request failed: {error}")
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
    fn github_repo_endpoint_rejects_path_traversal_owner() {
        let result = execute_github_tool(
            "github.repo".to_string(),
            r#"{"owner":"../octocat","repo":"Hello-World"}"#.to_string(),
        );
        let json = parsed(&result);

        assert_eq!(json["success"], false);
        assert_eq!(json["error_code"], crate::types::error_codes::INVALID_INPUT);
    }

    #[test]
    fn github_issues_normalization_filters_pull_requests() {
        let api = json!([
            {
                "number": 7,
                "title": "real issue",
                "state": "open",
                "html_url": "https://github.com/octocat/Hello-World/issues/7",
                "user": { "login": "octocat" },
                "labels": [{ "name": "bug" }],
                "created_at": "2026-05-01T00:00:00Z",
                "updated_at": "2026-05-02T00:00:00Z"
            },
            {
                "number": 8,
                "title": "pull request masquerading as issue",
                "state": "open",
                "html_url": "https://github.com/octocat/Hello-World/pull/8",
                "pull_request": { "url": "https://api.github.com/repos/octocat/Hello-World/pulls/8" }
            }
        ]);

        let normalized = normalize_issues(&api);
        assert_eq!(normalized.as_array().unwrap().len(), 1);
        assert_eq!(normalized[0]["number"], 7);
        assert_eq!(normalized[0]["labels"][0], "bug");
    }

    #[test]
    fn github_unknown_tool_returns_not_found() {
        let result = execute_github_tool("github.delete_repo".to_string(), "{}".to_string());
        let json = parsed(&result);

        assert_eq!(json["success"], false);
        assert_eq!(json["error_code"], crate::types::error_codes::NOT_FOUND);
    }

    #[test]
    fn github_credentials_are_rejected_in_tool_args() {
        let result = execute_github_tool(
            "github.repo".to_string(),
            r#"{"owner":"octocat","repo":"Hello-World","token":"secret"}"#.to_string(),
        );
        let json = parsed(&result);

        assert_eq!(json["success"], false);
        assert_eq!(json["error_code"], crate::types::error_codes::INVALID_INPUT);
        assert!(!json["error"].as_str().unwrap().contains("secret"));
    }
}
