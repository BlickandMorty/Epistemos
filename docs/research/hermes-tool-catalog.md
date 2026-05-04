# Hermes Tool Catalog

> **Index status**: CANONICAL-RESEARCH — Hermes integration research (Phase D + K reference).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/hermes_research/`.



## Core Tooling & Approval Matrix

| Tool Subgroup | Endpoint Pattern | Description | Approval Level | MAS Impact |
| --- | --- | --- | --- | --- |
| **Vault Memory** | `vault_*` | Interacts strictly with `__hermes__/memory` notes | Implicit | Normal |
| **Browser Context** | `browser_*` | Headless Chromium CDP interaction via embedded Playwright | Implicit | Normal |
| **Shell Tools** | `shell_*` | `PATH` scrubbed POSIX bash context executing bounded instructions | Approvals | Unlikely MAS |
| **Web Search** | `web_search` | External search capability mapping to Tavily/SearxNG | Implicit | Normal |
| **Code Runner** | `execute_code` | 256MB capped runtime bound `subprocess` for single-shot python | Approvals | Unlikely MAS |
| **Document Reader**| `doc_extract` | pypdf, python-docx, markitdown bundled for text parsing | Implicit | Normal |
| **Computer Use**   | `desktop_*`  | Bridges Hermes into Epistemos `DeviceAgentService` payload | Heavy Approvals | Rejected MAS |

## Tool Injection & Sandboxing Context
Tools are injected statically under `.venv` site-packages upon packaging.
Tools impacting local files outside of `__hermes__` directory strictly generate an SSE `approval.require` blocking signal back to the UI interface, pausing loop logic until users accept or reject execution.
