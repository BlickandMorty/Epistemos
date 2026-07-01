use std::collections::BTreeMap;
use std::env;
use std::ffi::OsString;
use std::fs;
use std::io::Read;
#[cfg(unix)]
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};

use serde::Deserialize;
use tokio::process::Command;

use super::registry::ToolError;

const BROWSER_USE_AGENT_BROWSER_ENV: &str = "EPISTEMOS_BROWSER_USE_AGENT_BROWSER";
const BROWSER_USE_VENDOR_ROOT_ENV: &str = "EPISTEMOS_BROWSER_USE_VENDOR_ROOT";
const BROWSER_USE_CDP_URL_ENV: &str = "EPISTEMOS_BROWSER_USE_CDP_URL";
const BROWSER_USE_ADAPTER_FILENAME: &str = "epistemos_agent_browser.py";
const MAX_PATH_DIAGNOSTIC_CHARS: usize = 160;
const MAX_SIGNATURE_MANIFEST_BYTES: u64 = 1024 * 1024;
const MAX_SIGNATURE_PAYLOAD_FILE_COUNT: u64 = 250_000;
const EXPECTED_SIGNATURE_SCHEMA_VERSION: u64 = 1;
const EXPECTED_SIGNATURE_PACKAGE_NAME: &str = "BrowserUsePro";
const EXPECTED_SIGNATURE_RUNTIME_LANE: &str = "pro-developer-id-only";
const EXPECTED_SIGNATURE_PAYLOAD_ROOT: &str = "Contents/Resources/BrowserUsePro";
const EXPECTED_PYTHON_VERSION_PREFIX: &str = "Python 3.11.";
const EXPECTED_BROWSER_USE_PACKAGE_VERSION: &str = "0.13.2";
const EXPECTED_CODESIGN_CONTRACT: &str = "BrowserUsePro.bundle must pass codesign --verify --deep --strict before bundling and strict Security.framework validation at runtime.";
const ALLOWED_SIGNATURE_TYPES: &[&str] = &["ad-hoc", "apple-development", "developer-id"];

struct RequiredSignatureComponent {
    name: &'static str,
    repo: &'static str,
    commit: &'static str,
    package_version: Option<&'static str>,
}

const REQUIRED_SIGNATURE_COMPONENTS: &[RequiredSignatureComponent] = &[
    RequiredSignatureComponent {
        name: "browser-use",
        repo: "https://github.com/browser-use/browser-use.git",
        commit: "2454d3e2551705232333c906ded8fc31ab0fc9f2",
        package_version: Some("0.13.2"),
    },
    RequiredSignatureComponent {
        name: "web-ui",
        repo: "https://github.com/browser-use/web-ui.git",
        commit: "61962296c38a0d064e0ba02c827192b7a81d1819",
        package_version: None,
    },
    RequiredSignatureComponent {
        name: "cdp-use",
        repo: "https://github.com/browser-use/cdp-use.git",
        commit: "a318684daab5ab3a9a516fcab447ed4bdfb92be9",
        package_version: Some("1.4.5"),
    },
];

struct RequiredPlaywrightRevision {
    name: &'static str,
    revision: &'static str,
}

const REQUIRED_PLAYWRIGHT_REVISIONS: &[RequiredPlaywrightRevision] = &[
    RequiredPlaywrightRevision {
        name: "chromium",
        revision: "1223",
    },
    RequiredPlaywrightRevision {
        name: "chromium_headless_shell",
        revision: "1223",
    },
    RequiredPlaywrightRevision {
        name: "ffmpeg",
        revision: "1011",
    },
];

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct SignatureManifest {
    schema_version: u64,
    package_name: String,
    runtime_lane: String,
    signature_type: String,
    signing_identity: String,
    payload_root: String,
    file_count: u64,
    python: String,
    browser_use_version: String,
    component_repos: BTreeMap<String, String>,
    component_commits: BTreeMap<String, String>,
    component_versions: BTreeMap<String, Option<String>>,
    playwright_revisions: BTreeMap<String, String>,
    created_utc: String,
    codesign_contract: String,
}

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
                        "EPISTEMOS_BROWSER_USE_ENV_FILE",
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
        return require_explicit_executable_browser(path, BROWSER_USE_AGENT_BROWSER_ENV);
    }

    if let Some(root) = browser_use_vendor_root {
        return require_vendor_root_browser(root);
    }

    for candidate in packaged_agent_browser_candidates() {
        if is_executable(&candidate) {
            let BrowserExecutable::Direct(candidate) =
                require_explicit_executable_browser(candidate, "BrowserUsePro.bundle")?;
            require_packaged_browser_use_bundle_evidence(&candidate)?;
            return Ok(BrowserExecutable::Direct(candidate));
        }
    }

    for candidate in search_dirs {
        let path = candidate.join("agent-browser");
        if is_executable(&path) {
            return Ok(BrowserExecutable::Direct(path));
        }
    }

    Err(ToolError::ExecutionFailed(
        "browser-use adapter not found. Install agent-browser on PATH or bundle BrowserUsePro.bundle with the Pro app.".into(),
    ))
}

fn require_explicit_executable_browser(
    path: PathBuf,
    source: &'static str,
) -> Result<BrowserExecutable, ToolError> {
    require_absolute_path(&path, source)?;
    reject_symlinked_parent_components(&path, source)?;
    reject_final_symlink(&path, source)?;
    require_executable_browser(path, source)
}

fn require_vendor_root_browser(root: PathBuf) -> Result<BrowserExecutable, ToolError> {
    require_absolute_path(&root, BROWSER_USE_VENDOR_ROOT_ENV)?;
    reject_symlinked_parent_components(&root, BROWSER_USE_VENDOR_ROOT_ENV)?;
    reject_final_symlink(&root, BROWSER_USE_VENDOR_ROOT_ENV)?;

    let metadata = fs::metadata(&root).map_err(|error| {
        ToolError::ExecutionFailed(format!(
            "{} resolved to '{}', but it could not be inspected: {error}",
            BROWSER_USE_VENDOR_ROOT_ENV,
            path_diagnostic(&root)
        ))
    })?;
    if !metadata.is_dir() {
        return Err(ToolError::ExecutionFailed(format!(
            "{} resolved to '{}', but it is not a directory",
            BROWSER_USE_VENDOR_ROOT_ENV,
            path_diagnostic(&root)
        )));
    }

    require_explicit_executable_browser(
        root.join(BROWSER_USE_ADAPTER_FILENAME),
        BROWSER_USE_VENDOR_ROOT_ENV,
    )
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
        path_diagnostic(&path)
    )))
}

fn require_packaged_browser_use_bundle_evidence(adapter_path: &Path) -> Result<(), ToolError> {
    let payload_root = adapter_path.parent().ok_or_else(|| {
        ToolError::ExecutionFailed(
            "BrowserUsePro.bundle adapter resolved without a payload root".into(),
        )
    })?;
    let bundle_dir = require_packaged_payload_root_layout(payload_root)?;
    for required in [
        payload_root.join("VENDOR_MANIFEST.json"),
        payload_root.join("BUILD_MANIFEST.json"),
    ] {
        require_regular_packaged_file(&required)?;
    }

    let signature_manifest = payload_root.join("SIGNATURE_MANIFEST.json");
    require_regular_packaged_file(&signature_manifest)?;
    let manifest = read_bounded_signature_manifest(&signature_manifest)?;
    require_signature_manifest_evidence(&manifest)?;
    require_packaged_bundle_signature(&bundle_dir)
}

fn require_packaged_payload_root_layout(payload_root: &Path) -> Result<PathBuf, ToolError> {
    let Some(resources_dir) = payload_root.parent() else {
        return Err(packaged_payload_root_problem());
    };
    let Some(contents_dir) = resources_dir.parent() else {
        return Err(packaged_payload_root_problem());
    };
    let Some(bundle_dir) = contents_dir.parent() else {
        return Err(packaged_payload_root_problem());
    };

    if path_file_name_eq(payload_root, "BrowserUsePro")
        && path_file_name_eq(resources_dir, "Resources")
        && path_file_name_eq(contents_dir, "Contents")
        && path_file_name_eq(bundle_dir, "BrowserUsePro.bundle")
    {
        return Ok(bundle_dir.to_path_buf());
    }

    Err(packaged_payload_root_problem())
}

fn packaged_payload_root_problem() -> ToolError {
    ToolError::ExecutionFailed(
        "BrowserUsePro.bundle payload root path must be Contents/Resources/BrowserUsePro".into(),
    )
}

fn path_file_name_eq(path: &Path, expected: &str) -> bool {
    path.file_name().and_then(|name| name.to_str()) == Some(expected)
}

fn require_regular_packaged_file(path: &Path) -> Result<(), ToolError> {
    let metadata = fs::symlink_metadata(path).map_err(|error| {
        ToolError::ExecutionFailed(format!(
            "BrowserUsePro.bundle is missing required package evidence '{}': {error}",
            path_diagnostic(path)
        ))
    })?;
    if !metadata.file_type().is_file() {
        return Err(ToolError::ExecutionFailed(format!(
            "BrowserUsePro.bundle package evidence '{}' must be a regular file",
            path_diagnostic(path)
        )));
    }
    Ok(())
}

fn require_packaged_bundle_signature(bundle_dir: &Path) -> Result<(), ToolError> {
    #[cfg(target_os = "macos")]
    {
        let status = std::process::Command::new("/usr/bin/codesign")
            .arg("--verify")
            .arg("--deep")
            .arg("--strict")
            .arg("--verbose=2")
            .arg(bundle_dir)
            .env_clear()
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status()
            .map_err(|error| {
                ToolError::ExecutionFailed(format!(
                    "BrowserUsePro.bundle code signature could not be verified: {error}"
                ))
            })?;
        if !status.success() {
            return Err(ToolError::ExecutionFailed(
                "BrowserUsePro.bundle code signature verification failed".into(),
            ));
        }
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = bundle_dir;
    }
    Ok(())
}

fn read_bounded_signature_manifest(path: &Path) -> Result<String, ToolError> {
    let mut file = open_signature_manifest_file(path)?;
    let metadata = file.metadata().map_err(|error| {
        ToolError::ExecutionFailed(format!(
            "BrowserUsePro.bundle signature manifest could not be inspected: {error}"
        ))
    })?;
    if !metadata.file_type().is_file() {
        return Err(ToolError::ExecutionFailed(
            "BrowserUsePro.bundle signature manifest must be a regular file".into(),
        ));
    }
    if metadata.len() > MAX_SIGNATURE_MANIFEST_BYTES {
        return Err(ToolError::ExecutionFailed(
            "BrowserUsePro.bundle signature manifest is too large".into(),
        ));
    }
    let mut manifest = String::new();
    file.by_ref()
        .take(MAX_SIGNATURE_MANIFEST_BYTES + 1)
        .read_to_string(&mut manifest)
        .map_err(|error| {
            ToolError::ExecutionFailed(format!(
                "BrowserUsePro.bundle signature manifest could not be read: {error}"
            ))
        })?;
    if manifest.len() as u64 > MAX_SIGNATURE_MANIFEST_BYTES {
        return Err(ToolError::ExecutionFailed(
            "BrowserUsePro.bundle signature manifest is too large".into(),
        ));
    }
    Ok(manifest)
}

fn open_signature_manifest_file(path: &Path) -> Result<fs::File, ToolError> {
    let mut options = fs::OpenOptions::new();
    options.read(true);
    #[cfg(unix)]
    {
        options.custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC);
    }
    options.open(path).map_err(|error| {
        ToolError::ExecutionFailed(format!(
            "BrowserUsePro.bundle signature manifest could not be read: {error}"
        ))
    })
}

fn require_signature_manifest_evidence(manifest: &str) -> Result<(), ToolError> {
    let manifest: SignatureManifest = serde_json::from_str(manifest).map_err(|error| {
        ToolError::ExecutionFailed(format!(
            "BrowserUsePro.bundle signature manifest could not be decoded: {error}"
        ))
    })?;

    if manifest.schema_version != EXPECTED_SIGNATURE_SCHEMA_VERSION {
        return Err(signature_manifest_problem("schema_version mismatch"));
    }
    if manifest.package_name != EXPECTED_SIGNATURE_PACKAGE_NAME {
        return Err(signature_manifest_problem("package_name mismatch"));
    }
    if manifest.runtime_lane != EXPECTED_SIGNATURE_RUNTIME_LANE {
        return Err(signature_manifest_problem("runtime_lane mismatch"));
    }
    if !ALLOWED_SIGNATURE_TYPES.contains(&manifest.signature_type.as_str()) {
        return Err(signature_manifest_problem("signature_type is unsupported"));
    }
    if manifest.signing_identity.trim().is_empty() {
        return Err(signature_manifest_problem("signing_identity is empty"));
    }
    if manifest.payload_root != EXPECTED_SIGNATURE_PAYLOAD_ROOT {
        return Err(signature_manifest_problem("payload_root mismatch"));
    }
    if manifest.file_count == 0 || manifest.file_count > MAX_SIGNATURE_PAYLOAD_FILE_COUNT {
        return Err(signature_manifest_problem("file_count is out of range"));
    }
    if !manifest.python.starts_with(EXPECTED_PYTHON_VERSION_PREFIX) {
        return Err(signature_manifest_problem("python mismatch"));
    }
    if manifest.browser_use_version != EXPECTED_BROWSER_USE_PACKAGE_VERSION {
        return Err(signature_manifest_problem("browser_use_version mismatch"));
    }
    if !is_second_precision_utc_timestamp(&manifest.created_utc) {
        return Err(signature_manifest_problem("created_utc mismatch"));
    }
    if manifest.codesign_contract != EXPECTED_CODESIGN_CONTRACT {
        return Err(signature_manifest_problem("codesign_contract mismatch"));
    }

    require_known_component_keys(&manifest.component_repos, "component_repos")?;
    require_known_component_keys(&manifest.component_commits, "component_commits")?;
    require_known_component_keys(&manifest.component_versions, "component_versions")?;

    for component in REQUIRED_SIGNATURE_COMPONENTS {
        require_component_value(
            &manifest.component_repos,
            "component_repos",
            component.name,
            "repo",
            component.repo,
        )?;
        require_component_value(
            &manifest.component_commits,
            "component_commits",
            component.name,
            "commit",
            component.commit,
        )?;
        require_component_package_version(&manifest.component_versions, component)?;
    }

    require_known_playwright_revision_keys(&manifest.playwright_revisions)?;
    for revision in REQUIRED_PLAYWRIGHT_REVISIONS {
        require_playwright_revision(&manifest.playwright_revisions, revision)?;
    }

    Ok(())
}

fn signature_manifest_problem(message: &'static str) -> ToolError {
    ToolError::ExecutionFailed(format!("BrowserUsePro.bundle signature manifest {message}"))
}

fn is_second_precision_utc_timestamp(value: &str) -> bool {
    let bytes = value.trim().as_bytes();
    if bytes.len() != 20 {
        return false;
    }
    for (index, byte) in bytes.iter().enumerate() {
        match index {
            4 | 7 => {
                if *byte != b'-' {
                    return false;
                }
            }
            10 => {
                if *byte != b'T' {
                    return false;
                }
            }
            13 | 16 => {
                if *byte != b':' {
                    return false;
                }
            }
            19 => {
                if *byte != b'Z' {
                    return false;
                }
            }
            _ => {
                if !byte.is_ascii_digit() {
                    return false;
                }
            }
        }
    }
    true
}

fn require_known_component_keys<T>(
    evidence: &BTreeMap<String, T>,
    label: &'static str,
) -> Result<(), ToolError> {
    for name in evidence.keys() {
        if !REQUIRED_SIGNATURE_COMPONENTS
            .iter()
            .any(|component| component.name == name.as_str())
        {
            return Err(ToolError::ExecutionFailed(format!(
                "BrowserUsePro.bundle signature manifest {label} has unexpected component {name}"
            )));
        }
    }
    Ok(())
}

fn require_component_value(
    evidence: &BTreeMap<String, String>,
    evidence_name: &'static str,
    component_name: &'static str,
    label: &'static str,
    expected: &'static str,
) -> Result<(), ToolError> {
    let actual = evidence
        .get(component_name)
        .ok_or_else(|| {
            ToolError::ExecutionFailed(format!(
                "BrowserUsePro.bundle signature manifest is missing {component_name} {label} evidence in {evidence_name}"
            ))
        })?;
    if actual.as_str() == expected {
        return Ok(());
    }
    Err(ToolError::ExecutionFailed(format!(
        "BrowserUsePro.bundle signature manifest {component_name} {label} evidence mismatch"
    )))
}

fn require_component_package_version(
    evidence: &BTreeMap<String, Option<String>>,
    component: &RequiredSignatureComponent,
) -> Result<(), ToolError> {
    let actual = evidence.get(component.name).ok_or_else(|| {
        ToolError::ExecutionFailed(format!(
            "BrowserUsePro.bundle signature manifest is missing {} package version evidence",
            component.name
        ))
    })?;
    match (component.package_version, actual.as_deref()) {
        (Some(expected), Some(actual)) if actual == expected => Ok(()),
        (None, None) => Ok(()),
        _ => Err(ToolError::ExecutionFailed(format!(
            "BrowserUsePro.bundle signature manifest {} package version evidence mismatch",
            component.name
        ))),
    }
}

fn require_known_playwright_revision_keys(
    evidence: &BTreeMap<String, String>,
) -> Result<(), ToolError> {
    for name in evidence.keys() {
        if !REQUIRED_PLAYWRIGHT_REVISIONS
            .iter()
            .any(|revision| revision.name == name.as_str())
        {
            return Err(ToolError::ExecutionFailed(format!(
                "BrowserUsePro.bundle signature manifest has unexpected Playwright revision {name}"
            )));
        }
    }
    Ok(())
}

fn require_playwright_revision(
    evidence: &BTreeMap<String, String>,
    revision: &RequiredPlaywrightRevision,
) -> Result<(), ToolError> {
    let actual = evidence.get(revision.name).ok_or_else(|| {
        ToolError::ExecutionFailed(format!(
            "BrowserUsePro.bundle signature manifest is missing {} Playwright revision evidence",
            revision.name
        ))
    })?;
    if actual.as_str() == revision.revision {
        return Ok(());
    }
    Err(ToolError::ExecutionFailed(format!(
        "BrowserUsePro.bundle signature manifest {} Playwright revision mismatch",
        revision.name
    )))
}

fn require_absolute_path(path: &Path, source: &'static str) -> Result<(), ToolError> {
    if path.is_absolute() {
        return Ok(());
    }

    Err(ToolError::ExecutionFailed(format!(
        "{source} resolved to '{}', but explicit browser-use paths must be absolute",
        path_diagnostic(path)
    )))
}

fn reject_symlinked_parent_components(path: &Path, source: &'static str) -> Result<(), ToolError> {
    let Some(parent) = path.parent() else {
        return Ok(());
    };

    let mut cursor = PathBuf::new();
    for component in parent.components() {
        cursor.push(component.as_os_str());
        if allowed_macos_compat_symlink(&cursor) {
            continue;
        }

        match fs::symlink_metadata(&cursor) {
            Ok(metadata) if metadata.file_type().is_symlink() => {
                return Err(ToolError::ExecutionFailed(format!(
                    "{source} path must not include symlink component '{}'",
                    path_diagnostic(&cursor)
                )));
            }
            Ok(_) => {}
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(()),
            Err(error) => {
                return Err(ToolError::ExecutionFailed(format!(
                    "inspect {source} path component '{}': {error}",
                    path_diagnostic(&cursor)
                )));
            }
        }
    }
    Ok(())
}

fn reject_final_symlink(path: &Path, source: &'static str) -> Result<(), ToolError> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.file_type().is_symlink() => {
            Err(ToolError::ExecutionFailed(format!(
                "{source} resolved to '{}', but it must not be a symlink",
                path_diagnostic(path)
            )))
        }
        Ok(_) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(ToolError::ExecutionFailed(format!(
            "inspect {source} path '{}': {error}",
            path_diagnostic(path)
        ))),
    }
}

fn path_diagnostic(path: &Path) -> String {
    let label = path
        .file_name()
        .and_then(|value| value.to_str())
        .filter(|value| !value.trim().is_empty())
        .unwrap_or("[path]");
    if label.chars().count() <= MAX_PATH_DIAGNOSTIC_CHARS {
        return label.to_string();
    }
    label
        .chars()
        .take(MAX_PATH_DIAGNOSTIC_CHARS.saturating_sub(3))
        .chain("...".chars())
        .collect()
}

fn allowed_macos_compat_symlink(path: &Path) -> bool {
    matches!(path.to_str(), Some("/etc") | Some("/tmp") | Some("/var"))
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

fn packaged_agent_browser_candidates() -> Vec<PathBuf> {
    let mut candidates = Vec::new();
    let Ok(executable) = env::current_exe() else {
        return candidates;
    };

    if let Some(contents_dir) = executable
        .parent()
        .filter(|parent| parent.file_name().and_then(|name| name.to_str()) == Some("MacOS"))
        .and_then(Path::parent)
    {
        push_packaged_agent_browser_candidate(&mut candidates, &contents_dir.join("Resources"));
    }

    for ancestor in executable.ancestors().take(8) {
        push_packaged_agent_browser_candidate(&mut candidates, ancestor);
        push_packaged_agent_browser_candidate(
            &mut candidates,
            &ancestor.join("build/browser-use-pro"),
        );
    }
    candidates
}

fn push_packaged_agent_browser_candidate(candidates: &mut Vec<PathBuf>, bundle_parent: &Path) {
    push_unique_path(
        candidates,
        bundle_parent
            .join("BrowserUsePro.bundle")
            .join("Contents")
            .join("Resources")
            .join("BrowserUsePro")
            .join(BROWSER_USE_ADAPTER_FILENAME),
    );
}

pub(crate) fn cdp_url_from_env() -> Result<Option<String>, ToolError> {
    let Some(value) = env::var_os(BROWSER_USE_CDP_URL_ENV) else {
        return Ok(None);
    };
    cdp_url_from_env_value(value)
}

fn cdp_url_from_env_value(value: OsString) -> Result<Option<String>, ToolError> {
    if value.as_os_str().is_empty() {
        return Ok(None);
    }

    let value = value.into_string().map_err(|_| {
        ToolError::InvalidArguments(format!("{BROWSER_USE_CDP_URL_ENV} must be valid UTF-8"))
    })?;
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
    if !matches!(host, "127.0.0.1" | "localhost" | "::1" | "[::1]") {
        return Err(ToolError::InvalidArguments(format!(
            "{BROWSER_USE_CDP_URL_ENV} must point at localhost, 127.0.0.1, or [::1]"
        )));
    }
    if !parsed.username().is_empty() || parsed.password().is_some() {
        return Err(ToolError::InvalidArguments(format!(
            "{BROWSER_USE_CDP_URL_ENV} must not include username or password credentials"
        )));
    }
    if parsed.query().is_some() {
        return Err(ToolError::InvalidArguments(format!(
            "{BROWSER_USE_CDP_URL_ENV} must not include a URL query"
        )));
    }
    if parsed.fragment().is_some() {
        return Err(ToolError::InvalidArguments(format!(
            "{BROWSER_USE_CDP_URL_ENV} must not include a URL fragment"
        )));
    }
    Ok(())
}

fn executable_search_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    if let Some(path) = env::var_os("PATH") {
        for item in env::split_paths(&path) {
            push_unique_absolute_path(&mut dirs, item);
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

fn push_unique_absolute_path(paths: &mut Vec<PathBuf>, candidate: PathBuf) {
    if candidate.is_absolute() {
        push_unique_path(paths, candidate);
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
            push_unique_absolute_path(&mut values, item);
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

    #[cfg(unix)]
    #[test]
    fn browser_use_explicit_adapter_rejects_symlink_routes() {
        let temp = tempfile::tempdir().unwrap();
        let real_parent = temp.path().join("real-parent");
        let adapter = real_parent.join("epistemos_agent_browser.py");
        write_executable_stub(&adapter);

        let final_link = temp.path().join("adapter-link.py");
        std::os::unix::fs::symlink(&adapter, &final_link).unwrap();
        let err = resolve_agent_browser(Some(final_link), None, Vec::new()).unwrap_err();
        let message = format!("{err}");
        assert!(message.contains(BROWSER_USE_AGENT_BROWSER_ENV));
        assert!(message.contains("must not be a symlink"));

        let parent_link = temp.path().join("parent-link");
        std::os::unix::fs::symlink(&real_parent, &parent_link).unwrap();
        let err = resolve_agent_browser(
            Some(parent_link.join("epistemos_agent_browser.py")),
            None,
            Vec::new(),
        )
        .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains(BROWSER_USE_AGENT_BROWSER_ENV));
        assert!(message.contains("path must not include symlink component"));
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn browser_use_packaged_adapter_requires_codesign_verification() {
        let temp = tempfile::tempdir().unwrap();
        let bundle_dir = temp.path().join("BrowserUsePro.bundle");
        let payload_root = bundle_dir
            .join("Contents")
            .join("Resources")
            .join("BrowserUsePro");
        let adapter = payload_root.join(BROWSER_USE_ADAPTER_FILENAME);
        fs::create_dir_all(&payload_root).unwrap();
        write_executable_stub(&adapter);
        fs::write(payload_root.join("VENDOR_MANIFEST.json"), "{}\n").unwrap();
        fs::write(payload_root.join("BUILD_MANIFEST.json"), "{}\n").unwrap();
        fs::write(
            payload_root.join("SIGNATURE_MANIFEST.json"),
            r#"{
  "schema_version": 1,
  "package_name": "BrowserUsePro",
  "runtime_lane": "pro-developer-id-only",
  "signature_type": "ad-hoc",
  "signing_identity": "-",
  "payload_root": "Contents/Resources/BrowserUsePro",
  "file_count": 1,
  "python": "Python 3.11.15",
  "browser_use_version": "0.13.2",
  "component_repos": {
    "browser-use": "https://github.com/browser-use/browser-use.git",
    "web-ui": "https://github.com/browser-use/web-ui.git",
    "cdp-use": "https://github.com/browser-use/cdp-use.git"
  },
  "component_commits": {
    "browser-use": "2454d3e2551705232333c906ded8fc31ab0fc9f2",
    "web-ui": "61962296c38a0d064e0ba02c827192b7a81d1819",
    "cdp-use": "a318684daab5ab3a9a516fcab447ed4bdfb92be9"
  },
  "component_versions": {
    "browser-use": "0.13.2",
    "web-ui": null,
    "cdp-use": "1.4.5"
  },
  "playwright_revisions": {
    "chromium": "1223",
    "chromium_headless_shell": "1223",
    "ffmpeg": "1011"
  },
  "created_utc": "2026-06-30T00:00:00Z",
  "codesign_contract": "BrowserUsePro.bundle must pass codesign --verify --deep --strict before bundling and strict Security.framework validation at runtime."
}
"#,
        )
        .unwrap();

        let err = require_packaged_browser_use_bundle_evidence(&adapter).unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("code signature verification failed"));
    }

    #[cfg(unix)]
    #[test]
    fn browser_cdp_url_env_rejects_non_utf8_values() {
        use std::os::unix::ffi::OsStringExt;

        let err = cdp_url_from_env_value(OsString::from_vec(vec![0xff, 0xfe])).unwrap_err();
        assert!(format!("{err}").contains("must be valid UTF-8"));
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
            "http://user:pass@127.0.0.1:9222",
            "http://127.0.0.1:9222/json/version?token=secret",
            "ws://127.0.0.1:9222/devtools/browser/session#token",
            "not a url",
        ] {
            let err = validate_cdp_url(rejected).unwrap_err();
            assert!(format!("{err}").contains(BROWSER_USE_CDP_URL_ENV));
        }
    }
}
