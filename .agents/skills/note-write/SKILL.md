---
name: "Note Write"
description: "Use when the user wants to revise, append to, or restructure an existing note in the vault."
category: "notes"
tags: ["notes", "vault", "write"]
---

# Note Write

Use this skill for safe note editing.

## Workflow

1. Resolve the target note with `vault_search`, `vault_navigate`, graph context, or an explicit attachment.
2. Read the existing note with `vault_read` before changing it.
3. Write changes back with `vault_write`.
4. Preserve user structure unless they explicitly ask for a rewrite.

## Guardrails

- Never overwrite a note you have not read in the same turn.
- Prefer append mode for small additions.
- If the requested edit could delete or replace substantial content, ask before proceeding.
- Keep note paths vault-relative.
