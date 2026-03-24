// Raw FFI bindings to macOS Accessibility APIs (ApplicationServices/HIServices).
// These are C-level function declarations — used by ax_tree.rs and permissions.rs.

#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(dead_code)]

use core_foundation::base::{CFTypeRef, Boolean};
use core_foundation::string::CFString;

/// Opaque AXUIElementRef type.
pub type AXUIElementRef = CFTypeRef;

/// AXError codes.
pub type AXError = i32;
pub const kAXErrorSuccess: AXError = 0;
pub const kAXErrorFailure: AXError = -25200;
pub const kAXErrorIllegalArgument: AXError = -25201;
pub const kAXErrorInvalidUIElement: AXError = -25202;
pub const kAXErrorCannotComplete: AXError = -25204;
pub const kAXErrorAttributeUnsupported: AXError = -25205;
pub const kAXErrorNotImplemented: AXError = -25208;
pub const kAXErrorAPIDisabled: AXError = -25211;

#[link(name = "ApplicationServices", kind = "framework")]
extern "C" {
    /// Check if the process is trusted for accessibility.
    pub fn AXIsProcessTrusted() -> Boolean;

    /// Check if trusted, optionally prompting the user.
    pub fn AXIsProcessTrustedWithOptions(options: CFTypeRef) -> Boolean;

    /// Create an AXUIElement for the system-wide element.
    pub fn AXUIElementCreateSystemWide() -> AXUIElementRef;

    /// Create an AXUIElement for a specific application by PID.
    pub fn AXUIElementCreateApplication(pid: i32) -> AXUIElementRef;

    /// Copy an attribute value from an AXUIElement.
    pub fn AXUIElementCopyAttributeValue(
        element: AXUIElementRef,
        attribute: CFTypeRef, // CFStringRef
        value: *mut CFTypeRef,
    ) -> AXError;

    /// Get the number of values for an array attribute.
    pub fn AXUIElementGetAttributeValueCount(
        element: AXUIElementRef,
        attribute: CFTypeRef,
        count: *mut i64,
    ) -> AXError;

    /// Copy multiple attribute values (for array attributes like children).
    pub fn AXUIElementCopyAttributeValues(
        element: AXUIElementRef,
        attribute: CFTypeRef,
        index: i64,
        max_values: i64,
        values: *mut CFTypeRef, // CFArrayRef
    ) -> AXError;

    /// Perform an action on an AXUIElement (e.g., AXPress).
    pub fn AXUIElementPerformAction(
        element: AXUIElementRef,
        action: CFTypeRef, // CFStringRef
    ) -> AXError;

    /// Set an attribute value.
    pub fn AXUIElementSetAttributeValue(
        element: AXUIElementRef,
        attribute: CFTypeRef,
        value: CFTypeRef,
    ) -> AXError;

    /// Get the PID of the application that owns this element.
    pub fn AXUIElementGetPid(
        element: AXUIElementRef,
        pid: *mut i32,
    ) -> AXError;

    /// Get the value from an AXValueRef (CGPoint, CGSize, CGRect, etc.).
    pub fn AXValueGetValue(
        value: AXUIElementRef, // Actually AXValueRef
        value_type: AXValueType,
        value_ptr: *mut std::ffi::c_void,
    ) -> Boolean;
}

/// AXValue type constants.
pub type AXValueType = u32;
pub const kAXValueTypeCGPoint: AXValueType = 1;
pub const kAXValueTypeCGSize: AXValueType = 2;
pub const kAXValueTypeCGRect: AXValueType = 3;

/// CGPoint (matching CoreGraphics layout).
#[repr(C)]
#[derive(Debug, Clone, Copy, Default)]
pub struct CGPoint {
    pub x: f64,
    pub y: f64,
}

/// CGSize (matching CoreGraphics layout).
#[repr(C)]
#[derive(Debug, Clone, Copy, Default)]
pub struct CGSize {
    pub width: f64,
    pub height: f64,
}

// AX attribute name constants
pub fn ax_attr(name: &str) -> CFString {
    CFString::new(name)
}

// Common attribute names
pub const AX_ROLE: &str = "AXRole";
pub const AX_TITLE: &str = "AXTitle";
pub const AX_VALUE: &str = "AXValue";
pub const AX_DESCRIPTION: &str = "AXDescription";
pub const AX_CHILDREN: &str = "AXChildren";
pub const AX_POSITION: &str = "AXPosition";
pub const AX_SIZE: &str = "AXSize";
pub const AX_FOCUSED_APPLICATION: &str = "AXFocusedApplication";
pub const AX_FOCUSED_UI_ELEMENT: &str = "AXFocusedUIElement";
pub const AX_WINDOWS: &str = "AXWindows";
pub const AX_ROLE_DESCRIPTION: &str = "AXRoleDescription";
pub const AX_SUBROLE: &str = "AXSubrole";
pub const AX_ENABLED: &str = "AXEnabled";

// Common roles that indicate interactivity
pub const INTERACTIVE_ROLES: &[&str] = &[
    "AXButton", "AXTextField", "AXTextArea", "AXCheckBox",
    "AXRadioButton", "AXPopUpButton", "AXComboBox", "AXSlider",
    "AXMenuItem", "AXMenuButton", "AXLink", "AXTabGroup",
    "AXList", "AXTable", "AXOutline", "AXDisclosureTriangle",
    "AXIncrementor", "AXColorWell", "AXSegmentedControl",
];
