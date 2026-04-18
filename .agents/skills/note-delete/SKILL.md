---
name: "Note Delete"
description: "Use when the user explicitly wants a note removed from the vault."
category: "notes"
tags: ["notes", "vault", "delete"]
---

# Note Delete

Use this skill only for explicit deletion requests.

## Workflow

1. Resolve the note path with `vault_search`, `vault_navigate`, or `vault_read`.
2. Confirm the exact target note before destructive action.
3. Use `delete_file` only after the target path is certain and the user has asked for deletion.

## Guardrails

- Never delete based on a guessed title or fuzzy match alone.
- Prefer asking for confirmation if more than one note could match.
- Do not use this skill for archiving, moving, or normal edits.
