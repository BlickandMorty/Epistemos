use std::fs;
#[cfg(unix)]
use std::os::unix::fs::{DirBuilderExt, MetadataExt, PermissionsExt};
use std::path::Path;

use super::registry::ToolError;

pub(crate) fn create_private_browser_dir(path: &Path) -> Result<(), ToolError> {
    reject_browser_dir_symlink(path)?;

    #[cfg(unix)]
    {
        let mut builder = fs::DirBuilder::new();
        builder.recursive(true).mode(0o700);
        builder.create(path).map_err(|e| {
            ToolError::ExecutionFailed(format!(
                "create private browser directory '{}': {e}",
                path.display()
            ))
        })?;
    }

    #[cfg(not(unix))]
    fs::create_dir_all(path).map_err(|e| {
        ToolError::ExecutionFailed(format!(
            "create private browser directory '{}': {e}",
            path.display()
        ))
    })?;

    reject_browser_dir_symlink(path)?;

    #[cfg(unix)]
    validate_private_browser_dir_owner(path)?;

    #[cfg(unix)]
    {
        let mut permissions = fs::metadata(path)
            .map_err(|e| {
                ToolError::ExecutionFailed(format!(
                    "inspect private browser directory '{}': {e}",
                    path.display()
                ))
            })?
            .permissions();
        if permissions.mode() & 0o077 != 0 {
            permissions.set_mode(0o700);
            fs::set_permissions(path, permissions).map_err(|e| {
                ToolError::ExecutionFailed(format!(
                    "harden private browser directory '{}': {e}",
                    path.display()
                ))
            })?;
        }
    }

    Ok(())
}

fn reject_browser_dir_symlink(path: &Path) -> Result<(), ToolError> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.file_type().is_symlink() => {
            Err(ToolError::ExecutionFailed(format!(
                "private browser directory '{}' must not be a symlink",
                path.display()
            )))
        }
        Ok(_) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(ToolError::ExecutionFailed(format!(
            "inspect private browser directory '{}': {error}",
            path.display()
        ))),
    }
}

#[cfg(unix)]
fn validate_private_browser_dir_owner(path: &Path) -> Result<(), ToolError> {
    let metadata = fs::metadata(path).map_err(|error| {
        ToolError::ExecutionFailed(format!(
            "inspect private browser directory '{}': {error}",
            path.display()
        ))
    })?;
    let current_uid = unsafe { libc::geteuid() };
    if metadata.uid() != current_uid {
        return Err(ToolError::ExecutionFailed(format!(
            "private browser directory '{}' must be owned by the current user",
            path.display()
        )));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(unix)]
    #[test]
    fn browser_private_directories_are_owner_only() {
        let temp = tempfile::tempdir().unwrap();
        let directory = temp.path().join("browser-session");
        fs::create_dir_all(&directory).unwrap();

        let mut permissions = fs::metadata(&directory).unwrap().permissions();
        permissions.set_mode(0o755);
        fs::set_permissions(&directory, permissions).unwrap();

        create_private_browser_dir(&directory).unwrap();

        let mode = fs::metadata(&directory).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o700);
    }

    #[cfg(unix)]
    #[test]
    fn browser_private_directories_reject_symlink_targets() {
        let temp = tempfile::tempdir().unwrap();
        let target = temp.path().join("target");
        let link = temp.path().join("browser-session-link");
        fs::create_dir_all(&target).unwrap();

        let mut permissions = fs::metadata(&target).unwrap().permissions();
        permissions.set_mode(0o755);
        fs::set_permissions(&target, permissions).unwrap();

        std::os::unix::fs::symlink(&target, &link).unwrap();

        let err = create_private_browser_dir(&link).unwrap_err();
        assert!(format!("{err}").contains("must not be a symlink"));
        let target_mode = fs::metadata(&target).unwrap().permissions().mode() & 0o777;
        assert_eq!(target_mode, 0o755);
    }
}
