// Input simulation using CGEvent APIs.
// Provides click, type text, and key press simulation.

use crate::types::{InputEvent, AutomationResult};
use core_graphics::event::{CGEvent, CGEventType, CGMouseButton, CGEventTapLocation};
use core_graphics::event_source::{CGEventSource, CGEventSourceStateID};
use core_graphics::geometry::CGPoint;
use std::time::Instant;

/// Execute a simulated input event using CGEvent APIs.
pub fn execute_input(event: &InputEvent) -> AutomationResult {
    let start = Instant::now();

    let result = match event {
        InputEvent::Click { x, y } => simulate_click(*x, *y),
        InputEvent::DoubleClick { x, y } => simulate_double_click(*x, *y),
        InputEvent::TypeText { text } => simulate_type_text(text),
        InputEvent::KeyPress { key_code, modifiers } => simulate_key_press(*key_code, *modifiers),
        InputEvent::MouseMove { x, y } => simulate_mouse_move(*x, *y),
    };

    let duration_ms = start.elapsed().as_millis() as u64;

    match result {
        Ok(()) => AutomationResult {
            success: true,
            error: None,
            duration_ms,
        },
        Err(e) => AutomationResult {
            success: false,
            error: Some(e),
            duration_ms,
        },
    }
}

fn simulate_click(x: f64, y: f64) -> Result<(), String> {
    let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState)
        .map_err(|_| "Failed to create event source".to_string())?;
    let point = CGPoint::new(x, y);

    let mouse_down = CGEvent::new_mouse_event(
        source.clone(),
        CGEventType::LeftMouseDown,
        point,
        CGMouseButton::Left,
    ).map_err(|_| "Failed to create mouse down event".to_string())?;

    let mouse_up = CGEvent::new_mouse_event(
        source,
        CGEventType::LeftMouseUp,
        point,
        CGMouseButton::Left,
    ).map_err(|_| "Failed to create mouse up event".to_string())?;

    mouse_down.post(CGEventTapLocation::HID);
    mouse_up.post(CGEventTapLocation::HID);

    Ok(())
}

fn simulate_double_click(x: f64, y: f64) -> Result<(), String> {
    let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState)
        .map_err(|_| "Failed to create event source".to_string())?;
    let point = CGPoint::new(x, y);

    let event = CGEvent::new_mouse_event(
        source.clone(),
        CGEventType::LeftMouseDown,
        point,
        CGMouseButton::Left,
    ).map_err(|_| "Failed to create mouse event".to_string())?;

    event.set_integer_value_field(1, 2); // click count = 2
    event.post(CGEventTapLocation::HID);

    let up = CGEvent::new_mouse_event(
        source,
        CGEventType::LeftMouseUp,
        point,
        CGMouseButton::Left,
    ).map_err(|_| "Failed to create mouse up event".to_string())?;
    up.set_integer_value_field(1, 2);
    up.post(CGEventTapLocation::HID);

    Ok(())
}

fn simulate_mouse_move(x: f64, y: f64) -> Result<(), String> {
    let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState)
        .map_err(|_| "Failed to create event source".to_string())?;
    let point = CGPoint::new(x, y);

    let event = CGEvent::new_mouse_event(
        source,
        CGEventType::MouseMoved,
        point,
        CGMouseButton::Left,
    ).map_err(|_| "Failed to create mouse move event".to_string())?;

    event.post(CGEventTapLocation::HID);
    Ok(())
}

fn simulate_type_text(text: &str) -> Result<(), String> {
    let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState)
        .map_err(|_| "Failed to create event source".to_string())?;

    // Use CGEvent keyboard event with Unicode string insertion
    for ch in text.chars() {
        let event = CGEvent::new_keyboard_event(source.clone(), 0, true)
            .map_err(|_| "Failed to create keyboard event".to_string())?;

        let mut buf = [0u16; 2];
        let encoded = ch.encode_utf16(&mut buf);
        event.set_string_from_utf16_unchecked(encoded);
        event.post(CGEventTapLocation::HID);

        // Key up
        let up = CGEvent::new_keyboard_event(source.clone(), 0, false)
            .map_err(|_| "Failed to create key up event".to_string())?;
        up.post(CGEventTapLocation::HID);
    }

    Ok(())
}

fn simulate_key_press(key_code: u16, modifiers: u64) -> Result<(), String> {
    let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState)
        .map_err(|_| "Failed to create event source".to_string())?;

    let key_down = CGEvent::new_keyboard_event(source.clone(), key_code, true)
        .map_err(|_| "Failed to create key down event".to_string())?;

    if modifiers != 0 {
        key_down.set_flags(core_graphics::event::CGEventFlags::from_bits_truncate(modifiers));
    }
    key_down.post(CGEventTapLocation::HID);

    let key_up = CGEvent::new_keyboard_event(source, key_code, false)
        .map_err(|_| "Failed to create key up event".to_string())?;
    if modifiers != 0 {
        key_up.set_flags(core_graphics::event::CGEventFlags::from_bits_truncate(modifiers));
    }
    key_up.post(CGEventTapLocation::HID);

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_click_constructs_result() {
        // CGEvent creation may fail in CI without accessibility permission,
        // but the function should not panic
        let result = execute_input(&InputEvent::Click { x: 100.0, y: 100.0 });
        // Result is either success or a descriptive error — never a panic
        assert!(result.success || result.error.is_some());
    }

    #[test]
    fn test_type_text_constructs_result() {
        let result = execute_input(&InputEvent::TypeText { text: "hello".to_string() });
        assert!(result.success || result.error.is_some());
    }

    #[test]
    fn test_key_press_constructs_result() {
        let result = execute_input(&InputEvent::KeyPress { key_code: 36, modifiers: 0 });
        assert!(result.success || result.error.is_some());
    }

    #[test]
    fn test_mouse_move_constructs_result() {
        let result = execute_input(&InputEvent::MouseMove { x: 200.0, y: 200.0 });
        assert!(result.success || result.error.is_some());
    }
}
