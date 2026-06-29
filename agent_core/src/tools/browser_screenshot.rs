use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use uuid::Uuid;

use super::browser_private::create_private_browser_dir;
use super::registry::ToolError;

pub(crate) const AGENT_BROWSER_SCREENSHOT_DIR_ENV: &str = "AGENT_BROWSER_SCREENSHOT_DIR";

pub(crate) fn next_screenshot_path() -> Result<PathBuf, ToolError> {
    let directory = screenshot_directory()?;
    Ok(directory.join(format!("browser-{}.png", Uuid::new_v4().simple())))
}

pub(crate) fn screenshot_directory() -> Result<PathBuf, ToolError> {
    let directory = if cfg!(target_os = "macos") {
        PathBuf::from("/tmp/epistemos-browser-screenshots")
    } else {
        env::temp_dir().join("epistemos-browser-screenshots")
    };
    create_private_browser_dir(&directory)?;
    Ok(directory)
}

pub(crate) fn path_resolves_inside(path: &Path, root: &Path) -> bool {
    let Ok(resolved_path) = fs::canonicalize(path) else {
        return false;
    };
    let Ok(resolved_root) = fs::canonicalize(root) else {
        return false;
    };
    resolved_path == resolved_root || resolved_path.starts_with(&resolved_root)
}

pub(crate) fn cleanup_screenshot_file(path: &Path) -> Result<(), ToolError> {
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(ToolError::ExecutionFailed(format!(
            "browser screenshot cleanup failed: {error}"
        ))),
    }
}

pub(crate) fn extract_screenshot_path(text: &str) -> Option<String> {
    text.split_whitespace()
        .filter_map(normalize_screenshot_path_token)
        .find(|token| token.starts_with('/') && token.ends_with(".png"))
}

fn normalize_screenshot_path_token(token: &str) -> Option<String> {
    let normalized = token.trim_matches(|ch| {
        matches!(
            ch,
            '\'' | '"' | '`' | ',' | ';' | ':' | '(' | ')' | '[' | ']'
        )
    });
    if normalized.is_empty() {
        None
    } else {
        Some(normalized.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn browser_vision_screenshot_paths_must_resolve_inside_private_directory() {
        let temp = tempfile::tempdir().unwrap();
        let root = temp.path().join("screenshots");
        let outside = temp.path().join("outside.png");
        let inside = root.join("inside.png");
        fs::create_dir_all(&root).unwrap();
        fs::write(&inside, b"inside").unwrap();
        fs::write(&outside, b"outside").unwrap();

        assert!(path_resolves_inside(&inside, &root));
        assert!(!path_resolves_inside(&outside, &root));

        #[cfg(unix)]
        {
            let symlink = root.join("escape.png");
            std::os::unix::fs::symlink(&outside, &symlink).unwrap();
            assert!(!path_resolves_inside(&symlink, &root));
        }
    }

    #[test]
    fn browser_screenshot_extracts_quoted_or_punctuated_png_tokens() {
        assert_eq!(
            extract_screenshot_path("saved screenshot at '/tmp/browser-a.png',"),
            Some("/tmp/browser-a.png".to_string())
        );
        assert_eq!(
            extract_screenshot_path("saved screenshot at (`/tmp/browser-b.png`);"),
            Some("/tmp/browser-b.png".to_string())
        );
        assert_eq!(extract_screenshot_path("saved /tmp/browser.txt"), None);
        assert_eq!(
            extract_screenshot_path("saved path=/tmp/browser-c.png"),
            None
        );
    }

    #[test]
    fn browser_screenshot_cleanup_removes_file_without_requiring_existing_path() {
        let temp = tempfile::tempdir().unwrap();
        let screenshot = temp.path().join("cleanup.png");
        fs::write(&screenshot, b"png").unwrap();

        cleanup_screenshot_file(&screenshot).unwrap();
        assert!(!screenshot.exists());
        cleanup_screenshot_file(&screenshot).unwrap();
    }
}
