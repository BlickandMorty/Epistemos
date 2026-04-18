---
name: "Note Create"
description: "Use when the user wants to create a new note, research memo, outline, or scratch document in the vault."
category: "notes"
tags: ["notes", "vault", "create"]
---

# Note Create

Use this skill when the task is to create a new note.

## Workflow

1. Decide the best vault-relative path from the user's request, nearby note structure, and vault navigation context.
2. If the target location is ambiguous, ask one short clarification question.
3. Create a new note with `vault_write` using full markdown content.
4. When useful, add lightweight frontmatter tags that match the user's request.

## Guardrails

- Prefer clear human-readable filenames.
- Do not create duplicate notes when an existing note is obviously the right target for an edit.
- For research tasks, gather sources first, then create a new note with the synthesized result.
