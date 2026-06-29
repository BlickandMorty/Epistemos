use serde_json::json;

pub fn browser_navigate_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_navigate".to_string(),
        description: "Navigate the shared browser session to a URL. Call this before snapshot/click/type tools."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "url": { "type": "string", "description": "HTTP or HTTPS URL to open." }
            },
            "required": ["url"]
        }),
    }
}

pub fn browser_snapshot_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_snapshot".to_string(),
        description: "Return the current page accessibility snapshot. compact mode is default; full=true returns the full snapshot."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "full": { "type": "boolean", "default": false }
            }
        }),
    }
}

pub fn browser_click_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_click".to_string(),
        description: "Click an element by ref id from browser_snapshot (for example '@e5')."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "ref": { "type": "string" }
            },
            "required": ["ref"]
        }),
    }
}

pub fn browser_type_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_type".to_string(),
        description: "Fill an input by ref id from browser_snapshot.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "ref": { "type": "string" },
                "text": { "type": "string" }
            },
            "required": ["ref", "text"]
        }),
    }
}

pub fn browser_scroll_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_scroll".to_string(),
        description: "Scroll the current page up or down.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "direction": { "type": "string", "enum": ["up", "down"] }
            },
            "required": ["direction"]
        }),
    }
}

pub fn browser_back_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_back".to_string(),
        description: "Navigate back in the current browser history.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {}
        }),
    }
}

pub fn browser_press_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_press".to_string(),
        description: "Press a keyboard key in the browser (for example 'Enter' or 'Tab')."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "key": { "type": "string" }
            },
            "required": ["key"]
        }),
    }
}

pub fn browser_close_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_close".to_string(),
        description: "Close the shared browser session and clean up its local daemon/socket state."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {}
        }),
    }
}

pub fn browser_get_images_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_get_images".to_string(),
        description: "List the current page images using in-page JavaScript evaluation."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {}
        }),
    }
}

pub fn browser_vision_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_vision".to_string(),
        description:
            "Take a browser screenshot and analyze it with the existing vision model routing."
                .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "question": { "type": "string" },
                "allow_cloud_external_requests": {
                    "type": "boolean",
                    "description": "Required because browser_vision captures the page and sends the screenshot to an external vision provider."
                },
                "provider": { "type": "string", "enum": ["claude", "openai", "gpt-4v"], "default": "claude" },
                "annotate": { "type": "boolean", "default": false }
            },
            "required": ["question", "allow_cloud_external_requests"]
        }),
    }
}

pub fn browser_console_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "browser_console".to_string(),
        description: "Read browser console messages and JS errors. Optionally evaluate a JavaScript expression first."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "clear": { "type": "boolean", "default": false },
                "expression": { "type": "string", "description": "Optional JavaScript expression to evaluate." }
            }
        }),
    }
}
