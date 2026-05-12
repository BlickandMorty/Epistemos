---
name: "Note Read"
description: "Use when the user wants to open, inspect, or quote a note from the vault without changing it."
category: "notes"
tags: ["notes", "vault", "read"]
---

# Note Read

Use this skill for note-first reading work.

## Workflow

1. Resolve the note with `vault.search`, `graph.vault_navigate`, graph context, or an explicit attachment.
2. Read the note with `vault.read` when you have a vault-relative path.
3. Prefer the note's actual contents over guessing from the title.
4. If the note cannot be resolved confidently, ask one short clarification question instead of inventing a path.

## Guardrails

- Stay read-only.
- Do not switch to generic `file.read` unless the note lives outside the vault or the user explicitly points to a filesystem path.
- Quote only the minimal note text needed to answer.
