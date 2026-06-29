use std::env;
use std::fs;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use tokio::process::Command;

use super::registry::ToolError;

const BROWSER_USE_AGENT_BROWSER_ENV: &str = "EPISTEMOS_BROWSER_USE_AGENT_BROWSER";
const BROWSER_USE_VENDOR_ROOT_ENV: &str = "EPISTEMOS_BROWSER_USE_VENDOR_ROOT";
const BROWSER_USE_CDP_URL_ENV: &str = "EPISTEMOS_BROWSER_USE_CDP_URL";
const BROWSER_USE_ADAPTER_FILENAME: &str = "epistemos_agent_browser.py";

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) enum BrowserExecutable {
    Direct(PathBuf),
}

impl BrowserExecutable {
    pub(crate) fn into_command(self) -> Command {
        match self {
            Self::Direct(path) => {
                // The `agent-browser` binary is a user-installed automation
                // harness running arbitrary scripts, same risk surface as MCP
                // servers. Apply doctrine subprocess hardening.
                let mut cmd = Command::new(path);
                crate::security::harden_cli_subprocess_extending(
                    &mut cmd,
                    &[
                        "FAKE_BROWSER_LOG",
                        "HTTP_PROXY",
                        "HTTPS_PROXY",
                        "NO_PROXY",
                        "http_proxy",
                        "https_proxy",
                        "no_proxy",
                    ],
                );
                cmd
            }
        }
    }
}

pub(crate) fn find_agent_browser() -> Result<BrowserExecutable, ToolError> {
    resolve_agent_browser(
        env_path(BROWSER_USE_AGENT_BROWSER_ENV),
        env_path(BROWSER_USE_VENDOR_ROOT_ENV),
        executable_search_dirs(),
    )
}

fn resolve_agent_browser(
    browser_use_adapter: Option<PathBuf>,
    browser_use_vendor_root: Option<PathBuf>,
    search_dirs: Vec<PathBuf>,
) -> Result<BrowserExecutable, ToolError> {
    if let Some(path) = browser_use_adapter {
        return require_executable_browser(path, BROWSER_USE_AGENT_BROWSER_ENV);
    }

    if let Some(root) = browser_use_vendor_root {
        return require_executable_browser(
            root.join(BROWSER_USE_ADAPTER_FILENAME),
            BROWSER_USE_VENDOR_ROOT_ENV,
        );
    }

    for candidate in search_dirs {
        let path = candidate.join("agent-browser");
        if is_executable(&path) {
            return Ok(BrowserExecutable::Direct(path));
        }
    }

    Err(ToolError::ExecutionFailed(
        "agent-browser CLI not found. Install it and ensure it is on PATH.".into(),
    ))
}

fn require_executable_browser(
    path: PathBuf,
    source: &'static str,
) -> Result<BrowserExecutable, ToolError> {
    if is_executable(&path) {
        return Ok(BrowserExecutable::Direct(path));
    }

    Err(ToolError::ExecutionFailed(format!(
        "{source} resolved to '{}', but it is not an executable file",
        path.display()
    )))
}

fn env_path(key: &str) -> Option<PathBuf> {
    env::var_os(key).and_then(|value| {
        if value.as_os_str().is_empty() {
            None
        } else {
            Some(PathBuf::from(value))
        }
    })
}

pub(crate) fn cdp_url_from_env() -> Result<Option<String>, ToolError> {
    let Some(value) = env::var_os(BROWSER_USE_CDP_URL_ENV) else {
        return Ok(None);
    };
    if value.as_os_str().is_empty() {
        return Ok(None);
    }

    let value = value.to_string_lossy();
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }
    validate_cdp_url(trimmed)?;
    Ok(Some(trimmed.to_string()))
}

fn validate_cdp_url(raw: &str) -> Result<(), ToolError> {
    let parsed = reqwest::Url::parse(raw).map_err(|_| {
        ToolError::InvalidArguments(format!("{BROWSER_USE_CDP_URL_ENV} must be a valid URL"))
    })?;
    if !matches!(parsed.scheme(), "http" | "https" | "ws" | "wss") {
        return Err(ToolError::InvalidArguments(format!(
            "{BROWSER_USE_CDP_URL_ENV} must use http, https, ws, or wss"
        )));
    }
    let Some(host) = parsed.host_str() else {
        return Err(ToolError::InvalidArguments(format!(
            "{BROWSER_USE_CDP_URL_ENV} must include a loopback host"
        )));
    };
    if !matches!(host, "127.0.0.1" | "localhost" | "::1") {
        return Err(ToolError::InvalidArguments(format!(
            "{BROWSER_USE_CDP_URL_ENV} must point at localhost, 127.0.0.1, or [::1]"
        )));
    }
    Ok(())
}

fn executable_search_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    if let Some(path) = env::var_os("PATH") {
        for item in env::split_paths(&path) {
            push_unique_path(&mut dirs, item);
        }
    }
    push_unique_path(&mut dirs, PathBuf::from("/opt/homebrew/bin"));
    push_unique_path(&mut dirs, PathBuf::from("/usr/local/bin"));
    if let Some(home) = dirs::home_dir() {
        push_unique_path(&mut dirs, home.join(".hermes/node/bin"));
    }
    dirs
}

fn push_unique_path(paths: &mut Vec<PathBuf>, candidate: PathBuf) {
    if !candidate.as_os_str().is_empty() && !paths.iter().any(|path| path == &candidate) {
        paths.push(candidate);
    }
}

fn is_executable(path: &Path) -> bool {
    if !path.is_file() {
        return false;
    }
    #[cfg(unix)]
    {
        fs::metadata(path)
            .map(|metadata| metadata.permissions().mode() & 0o111 != 0)
            .unwrap_or(false)
    }
    #[cfg(not(unix))]
    {
        true
    }
}

pub(crate) fn extended_path() -> String {
    let mut values = Vec::new();
    if let Some(path) = env::var_os("PATH") {
        for item in env::split_paths(&path) {
            if !item.as_os_str().is_empty() {
                values.push(item);
            }
        }
    }
    push_unique_path(&mut values, PathBuf::from("/opt/homebrew/bin"));
    push_unique_path(&mut values, PathBuf::from("/usr/local/bin"));
    if let Some(home) = dirs::home_dir() {
        push_unique_path(&mut values, home.join(".hermes/node/bin"));
    }
    env::join_paths(values)
        .ok()
        .and_then(|joined| joined.into_string().ok())
        .unwrap_or_else(|| "/usr/local/bin:/usr/bin:/bin".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mark_executable(path: &Path) {
        #[cfg(unix)]
        {
            let mut permissions = fs::metadata(path).unwrap().permissions();
            permissions.set_mode(0o755);
            fs::set_permissions(path, permissions).unwrap();
        }
    }

    fn write_executable_stub(path: &Path) {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(
            path,
            "#!/bin/sh\nprintf '{\"success\":true,\"data\":{}}\\n'\n",
        )
        .unwrap();
        mark_executable(path);
    }

    fn make_fake_browser(temp_root: &Path) -> PathBuf {
        let bin_dir = temp_root.join("bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let script_path = bin_dir.join("agent-browser");
        fs::write(
            &script_path,
            "#!/bin/sh\nprintf '{\"success\":true,\"data\":{}}\\n'\n",
        )
        .unwrap();
        mark_executable(&script_path);
        script_path
    }

    #[test]
    fn browser_use_agent_browser_override_wins_before_path_search() {
        let temp = tempfile::tempdir().unwrap();
        let adapter = temp.path().join("epistemos_agent_browser.py");
        write_executable_stub(&adapter);
        let fallback = make_fake_browser(temp.path());

        let resolved = resolve_agent_browser(
            Some(adapter.clone()),
            None,
            vec![fallback.parent().unwrap().to_path_buf()],
        )
        .unwrap();

        assert_eq!(resolved, BrowserExecutable::Direct(adapter));
    }

    #[test]
    fn browser_use_vendor_root_discovers_bundled_adapter() {
        let temp = tempfile::tempdir().unwrap();
        let vendor_root = temp.path().join("browser-use");
        let adapter = vendor_root.join(BROWSER_USE_ADAPTER_FILENAME);
        write_executable_stub(&adapter);

        let resolved = resolve_agent_browser(None, Some(vendor_root), Vec::new()).unwrap();

        assert_eq!(resolved, BrowserExecutable::Direct(adapter));
    }

    #[test]
    fn browser_use_explicit_adapter_rejects_non_executable_without_fallback() {
        let temp = tempfile::tempdir().unwrap();
        let adapter = temp.path().join("epistemos_agent_browser.py");
        fs::write(&adapter, "#!/bin/sh\nexit 0\n").unwrap();
        let fallback = make_fake_browser(temp.path());

        let err = resolve_agent_browser(
            Some(adapter),
            None,
            vec![fallback.parent().unwrap().to_path_buf()],
        )
        .unwrap_err();
        let message = format!("{err}");

        assert!(message.contains(BROWSER_USE_AGENT_BROWSER_ENV));
        assert!(message.contains("not an executable file"));
    }

    #[test]
    fn browser_cdp_url_env_accepts_only_loopback_urls() {
        for allowed in [
            "http://127.0.0.1:9222",
            "http://localhost:9222/json/version",
            "ws://127.0.0.1:9222/devtools/browser/session",
            "ws://[::1]:9222/devtools/browser/session",
        ] {
            validate_cdp_url(allowed).unwrap();
        }

        for rejected in [
            "file:///tmp/browser",
            "http://192.168.0.2:9222",
            "ws://example.com/devtools/browser/session",
            "not a url",
        ] {
            let err = validate_cdp_url(rejected).unwrap_err();
            assert!(format!("{err}").contains(BROWSER_USE_CDP_URL_ENV));
        }
    }
}
