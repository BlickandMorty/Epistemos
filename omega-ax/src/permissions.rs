// Permission checker using macOS AXIsProcessTrusted API.
// Checks Accessibility permission status without prompting the user.

use crate::types::{PermissionState, PermissionStatus};
use crate::ax_ffi;

/// Check all relevant macOS permissions.
pub fn check_permissions() -> PermissionStatus {
    let accessibility = check_accessibility();

    PermissionStatus {
        accessibility,
        // Screen Recording and Automation permissions require different APIs
        // that we'll check via Swift side (ScreenCaptureKit, NSAppleScript).
        // For now, report them as Unknown from Rust.
        screen_recording: PermissionState::Unknown,
        automation: PermissionState::Unknown,
    }
}

/// Check if the process has Accessibility permission granted.
fn check_accessibility() -> PermissionState {
    // SAFETY: AXIsProcessTrusted is a safe C function that returns a Boolean.
    let trusted = unsafe { ax_ffi::AXIsProcessTrusted() };
    if trusted != 0 {
        PermissionState::Granted
    } else {
        PermissionState::Denied
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_check_permissions_returns_valid_state() {
        let status = check_permissions();
        // Accessibility will be either Granted or Denied depending on test environment
        assert!(
            status.accessibility == PermissionState::Granted
                || status.accessibility == PermissionState::Denied
        );
        // Screen recording and automation are Unknown from Rust
        assert_eq!(status.screen_recording, PermissionState::Unknown);
        assert_eq!(status.automation, PermissionState::Unknown);
    }
}
