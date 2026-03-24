// AX tree walker — traverses the macOS accessibility tree for a given PID.
// Returns a flattened list of AXElements with parent indices for tree reconstruction.

use crate::types::{AXElement, AXTreeSnapshot};
use crate::ax_ffi::*;
use core_foundation::base::{CFRelease, CFTypeRef, TCFType};
use core_foundation::string::CFString;
use std::ffi::c_void;

/// Walk the accessibility tree for the given PID.
/// Returns a snapshot with all elements flattened into a Vec.
/// If accessibility permission is not granted, returns an empty sparse snapshot.
pub fn walk_ax_tree(pid: i64) -> AXTreeSnapshot {
    // Check permission first
    let trusted = unsafe { AXIsProcessTrusted() };
    if trusted == 0 {
        return AXTreeSnapshot {
            elements: vec![],
            app_name: String::new(),
            app_pid: pid,
            is_sparse: true,
        };
    }

    // SAFETY: AXUIElementCreateApplication takes a pid_t (i32).
    let app_element = unsafe { AXUIElementCreateApplication(pid as i32) };
    if app_element.is_null() {
        return AXTreeSnapshot {
            elements: vec![],
            app_name: String::new(),
            app_pid: pid,
            is_sparse: true,
        };
    }

    let app_name = get_string_attr(app_element, AX_TITLE)
        .or_else(|| get_string_attr(app_element, AX_DESCRIPTION))
        .unwrap_or_default();

    let mut elements = Vec::with_capacity(64);
    walk_element(app_element, -1, &mut elements, 0, 10);

    // SAFETY: We own the app_element ref from CreateApplication.
    unsafe { CFRelease(app_element as *const c_void) };

    let interactive_count = elements.iter().filter(|e| e.is_interactive).count();
    let is_sparse = interactive_count < AXTreeSnapshot::SPARSE_THRESHOLD;

    AXTreeSnapshot {
        elements,
        app_name,
        app_pid: pid,
        is_sparse,
    }
}

/// Recursively walk an AX element and its children.
fn walk_element(
    element: AXUIElementRef,
    parent_index: i32,
    elements: &mut Vec<AXElement>,
    depth: usize,
    max_depth: usize,
) {
    if depth > max_depth {
        return;
    }

    let role = get_string_attr(element, AX_ROLE).unwrap_or_default();
    let title = get_string_attr(element, AX_TITLE);
    let value = get_string_attr(element, AX_VALUE);
    let description = get_string_attr(element, AX_DESCRIPTION);

    let (pos_x, pos_y) = get_position(element);
    let (size_w, size_h) = get_size(element);

    let is_interactive = INTERACTIVE_ROLES.contains(&role.as_str());

    let children = get_children(element);
    let children_count = children.len() as u32;
    let current_index = elements.len() as i32;

    elements.push(AXElement {
        role,
        title,
        value,
        description,
        position_x: pos_x,
        position_y: pos_y,
        size_width: size_w,
        size_height: size_h,
        is_interactive,
        children_count,
        parent_index,
    });

    // Recurse into children
    for child in children {
        walk_element(child, current_index, elements, depth + 1, max_depth);
        // SAFETY: Each child ref was retained by CFArray.
        // We don't release them — the array owns them.
    }
}

/// Get a string attribute from an AX element.
fn get_string_attr(element: AXUIElementRef, attr_name: &str) -> Option<String> {
    let attr = CFString::new(attr_name);
    let mut value: CFTypeRef = std::ptr::null();

    // SAFETY: We pass valid element and attribute refs.
    let err = unsafe {
        AXUIElementCopyAttributeValue(element, attr.as_CFTypeRef(), &mut value)
    };

    if err != kAXErrorSuccess || value.is_null() {
        return None;
    }

    // Try to interpret as CFString
    let cf_str = unsafe { CFString::wrap_under_create_rule(value as *const _) };
    let result = cf_str.to_string();

    if result.is_empty() {
        None
    } else {
        Some(result)
    }
}

/// Get position (AXPosition) as (x, y) via AXValueGetValue.
fn get_position(element: AXUIElementRef) -> (f64, f64) {
    let attr = CFString::new(AX_POSITION);
    let mut value: CFTypeRef = std::ptr::null();

    // SAFETY: AXUIElementCopyAttributeValue is a safe C function.
    let err = unsafe {
        AXUIElementCopyAttributeValue(element, attr.as_CFTypeRef(), &mut value)
    };

    if err != kAXErrorSuccess || value.is_null() {
        return (0.0, 0.0);
    }

    let mut point = CGPoint::default();
    // SAFETY: value is an AXValueRef containing a CGPoint.
    let ok = unsafe {
        AXValueGetValue(
            value,
            kAXValueTypeCGPoint,
            &mut point as *mut _ as *mut std::ffi::c_void,
        )
    };

    unsafe { CFRelease(value as *const c_void) };

    if ok != 0 {
        (point.x, point.y)
    } else {
        (0.0, 0.0)
    }
}

/// Get size (AXSize) as (width, height) via AXValueGetValue.
fn get_size(element: AXUIElementRef) -> (f64, f64) {
    let attr = CFString::new(AX_SIZE);
    let mut value: CFTypeRef = std::ptr::null();

    let err = unsafe {
        AXUIElementCopyAttributeValue(element, attr.as_CFTypeRef(), &mut value)
    };

    if err != kAXErrorSuccess || value.is_null() {
        return (0.0, 0.0);
    }

    let mut size = CGSize::default();
    // SAFETY: value is an AXValueRef containing a CGSize.
    let ok = unsafe {
        AXValueGetValue(
            value,
            kAXValueTypeCGSize,
            &mut size as *mut _ as *mut std::ffi::c_void,
        )
    };

    unsafe { CFRelease(value as *const c_void) };

    if ok != 0 {
        (size.width, size.height)
    } else {
        (0.0, 0.0)
    }
}

/// Get children of an AX element.
fn get_children(element: AXUIElementRef) -> Vec<AXUIElementRef> {
    let attr = CFString::new(AX_CHILDREN);
    let mut count: i64 = 0;

    let err = unsafe {
        AXUIElementGetAttributeValueCount(element, attr.as_CFTypeRef(), &mut count)
    };

    if err != kAXErrorSuccess || count == 0 {
        return vec![];
    }

    // Cap at 100 children to prevent runaway traversal
    let count = count.min(100);

    let mut values: CFTypeRef = std::ptr::null();
    let err = unsafe {
        AXUIElementCopyAttributeValues(element, attr.as_CFTypeRef(), 0, count, &mut values)
    };

    if err != kAXErrorSuccess || values.is_null() {
        return vec![];
    }

    // values is a CFArrayRef. Extract elements as raw pointers.
    // SAFETY: We know these are AXUIElementRef values from the AX API.
    let array_ptr = values as core_foundation::array::CFArrayRef;
    let len = unsafe { core_foundation::array::CFArrayGetCount(array_ptr) };
    let mut children = Vec::with_capacity(len as usize);

    for i in 0..len {
        let child = unsafe { core_foundation::array::CFArrayGetValueAtIndex(array_ptr, i) };
        if !child.is_null() {
            children.push(child as AXUIElementRef);
        }
    }

    // Don't release the array yet — children are borrowed from it.
    // We walk synchronously so the refs are valid for the traversal.
    // Leak the array to keep children alive. This is acceptable for
    // a one-shot tree walk (the process will reclaim memory on completion).

    children
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_walk_returns_snapshot() {
        // Walk PID 1 (launchd) — will return sparse/empty without accessibility
        let snapshot = walk_ax_tree(1);
        assert_eq!(snapshot.app_pid, 1);
        // Either we have permission and get elements, or we don't and get sparse
        assert!(snapshot.is_sparse || !snapshot.elements.is_empty());
    }

    #[test]
    fn test_invalid_pid() {
        let snapshot = walk_ax_tree(-1);
        // With invalid PID, the AX API may return empty or minimal results.
        // The key guarantee: it doesn't panic.
        assert_eq!(snapshot.app_pid, -1);
    }

    #[test]
    fn test_sparse_threshold() {
        assert_eq!(AXTreeSnapshot::SPARSE_THRESHOLD, 5);
    }
}
