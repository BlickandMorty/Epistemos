# Hermes Wire Protocol

## Overview
Defines the structure for Swift-to-Hermes and Hermes-to-Swift remote procedure calls traversing local `127.0.0.1`.

## Bootstrapping Stage
**POST** `/v1/epistemos/bootstrap`
**Headers:** 
`Authorization: Bearer <swift_csprng_token>`
`Host: 127.0.0.1`

**Body:**
```json
{
  "vaultRoot": "/Users/user/Vaults/Default",
  "mcpEndpoint": "http://127.0.0.1:55432",
  "presetPaths": ["..."],
  "allowedTools": ["browser_action", "fs_scoped_read", "vault_memory"],
  "modelConfig": { ... }
}
```

## SSE Event Stream
Event types streaming from the Hermes subprocess to Swift UI state:
- `task.start`: Indicates agent initialization, populates `SDHermesTask`.
- `thought.append`: Streaming chunks of reasoning for the Think block.
- `tool_call.begin / tool_call.progress / tool_call.end`: Yields payloads for `ToolCallCard`. 
- `approval.require`: Requires Swift layer intervention, pushes modal to user.
- `task.done`: Indicates structural completion, triggers `UNUserNotificationCenter` if >20 seconds passed.
