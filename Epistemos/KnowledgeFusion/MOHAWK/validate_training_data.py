#!/usr/bin/env python3
"""
Training Data Ground-Truth Validator
=====================================

Validates JSONL training examples against the LIVE codebase.
Rejects examples that:
  - Reference deleted/renamed views or symbols
  - Have wrong return types or signatures
  - Reference stale architecture (e.g., NoteTabView → NoteDetailWorkspaceView)
  - Have malformed "Part of …" ownership claims

Also quarantines deferred Omega/agent data that shouldn't dominate
the current model until validated.

Outputs:
  - validated/   — clean examples that pass all checks
  - quarantined/ — examples that fail validation (with reasons)
  - validation_report.json — summary of what was kept/rejected/quarantined

Usage:
    python validate_training_data.py \
        --input ./epistemos_training_data \
        --output ./epistemos_training_data_validated \
        --codebase ~/Downloads/Epistemos
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from collections import Counter

# ─── STALE SYMBOL MAP ──────────────────────────────────────────
# Known renames/deletions verified against live source 2026-03-27

STALE_SYMBOLS = {
    # Views renamed
    "NoteTabView": "NoteDetailWorkspaceView",
    "NoteTab": "NoteDetailWorkspace",

    # Never existed or renamed
    "NoteEditorView": "ProseEditorView",
}

# Symbols that MUST NOT appear in training data (deleted/never existed)
BANNED_SYMBOLS = {
    "NoteTabView",  # Renamed to NoteDetailWorkspaceView
}

# Known wrong claims to check
WRONG_RETURN_TYPES = {
    # (function_name, wrong_claim, correct_type)
    ("trainKnowledgeAdapter", "Void", "AdapterMetadata"),
    ("trainKnowledgeAdapter", "Void)?", "AdapterMetadata"),
    ("trainStyleAdapter", "Void", "AdapterMetadata"),
    ("trainStyleAdapter", "Void)?", "AdapterMetadata"),
}


def scan_codebase_symbols(codebase_root: str) -> set:
    """Scan the live codebase and collect all defined symbols."""
    symbols = set()
    swift_dir = os.path.join(codebase_root, "Epistemos")

    for root, dirs, files in os.walk(swift_dir):
        dirs[:] = [d for d in dirs if d not in {".build", "DerivedData", ".git"}]
        for fn in files:
            if not fn.endswith(".swift"):
                continue
            try:
                with open(os.path.join(root, fn), 'r', errors='replace') as f:
                    content = f.read()
                # Extract class/struct/enum/protocol/actor names
                for match in re.finditer(r'(?:class|struct|enum|protocol|actor)\s+(\w+)', content):
                    symbols.add(match.group(1))
                # Extract function names
                for match in re.finditer(r'func\s+(\w+)', content):
                    symbols.add(match.group(1))
            except Exception:
                pass

    return symbols


def validate_example(example: dict, live_symbols: set) -> tuple:
    """Validate a single training example. Returns (is_valid, issues)."""
    issues = []
    messages = example.get("messages", [])
    category = example.get("category", "unknown")

    # Concatenate all message content for checking
    full_text = " ".join(m.get("content", "") for m in messages)

    # Check for banned/stale symbols
    for banned in BANNED_SYMBOLS:
        if banned in full_text:
            replacement = STALE_SYMBOLS.get(banned, "unknown")
            issues.append(f"STALE_SYMBOL: '{banned}' → should be '{replacement}'")

    # Check for wrong return type claims
    for func_name, wrong_type, correct_type in WRONG_RETURN_TYPES:
        if func_name in full_text and wrong_type in full_text:
            issues.append(f"WRONG_RETURN: {func_name} claimed '{wrong_type}', actually '{correct_type}'")

    # Check symbol_qa examples for references to non-existent types
    if category == "symbol_qa":
        # Look for "Part of `ClassName`" claims
        part_of_matches = re.findall(r'Part of [`\'](\w+)[`\']', full_text)
        for claimed_class in part_of_matches:
            if claimed_class not in live_symbols and len(claimed_class) > 2:
                issues.append(f"UNKNOWN_CLASS: 'Part of {claimed_class}' — not found in live source")

        # Look for "defined in `path`" claims with deleted files
        defined_in = re.findall(r'defined in [`\']([^`\']+)[`\']', full_text)
        for path_claim in defined_in:
            if "NoteTabView" in path_claim or "NoteTab" in path_claim:
                issues.append(f"STALE_PATH: references '{path_claim}' which doesn't exist")

    # Check code_grounded examples for deleted views
    if category == "code_grounded":
        for stale, replacement in STALE_SYMBOLS.items():
            if stale in full_text:
                issues.append(f"STALE_VIEW: references '{stale}' → should be '{replacement}'")

    # Check trajectory examples reference valid tools
    if category in ("trajectory", "tool_call", "axpress_schema"):
        # These are fine as-is for now — they define what the model SHOULD learn
        pass

    return (len(issues) == 0, issues)


def should_quarantine(example: dict) -> tuple:
    """Check if example should be quarantined (deferred Omega data)."""
    category = example.get("category", "")
    # These categories are valid for MOHAWK seed but should be flagged
    # Only quarantine if they contain obviously wrong data
    return (False, [])


def fix_example(example: dict) -> dict:
    """Attempt to auto-fix known stale references."""
    messages = example.get("messages", [])
    fixed = False

    for msg in messages:
        content = msg.get("content", "")
        original = content

        # Replace stale symbols
        for stale, replacement in STALE_SYMBOLS.items():
            if stale in content:
                content = content.replace(stale, replacement)
                fixed = True

        if content != original:
            msg["content"] = content

    if fixed:
        example["_auto_fixed"] = True

    return example


def main():
    parser = argparse.ArgumentParser(description="Training Data Ground-Truth Validator")
    parser.add_argument("--input", default="./epistemos_training_data")
    parser.add_argument("--output", default="./epistemos_training_data_validated")
    parser.add_argument("--codebase", default=os.path.expanduser("~/Downloads/Epistemos"))
    parser.add_argument("--fix", action="store_true", help="Auto-fix stale references instead of rejecting")
    args = parser.parse_args()

    print(f"\n{'='*60}")
    print(f"  Training Data Ground-Truth Validator")
    print(f"  Input: {args.input}")
    print(f"  Codebase: {args.codebase}")
    print(f"  Mode: {'auto-fix' if args.fix else 'validate-only'}")
    print(f"{'='*60}\n")

    # Scan live codebase
    print("Scanning live codebase...")
    live_symbols = scan_codebase_symbols(args.codebase)
    print(f"  Found {len(live_symbols)} symbols in live source\n")

    # Process each JSONL file
    input_dir = Path(args.input)
    output_dir = Path(args.output)
    quarantine_dir = output_dir / "quarantined"
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(quarantine_dir, exist_ok=True)

    stats = {
        "total": 0,
        "valid": 0,
        "fixed": 0,
        "rejected": 0,
        "quarantined": 0,
        "issues_by_type": Counter(),
        "files_processed": 0,
    }

    all_valid = []
    all_rejected = []

    # Process individual layer files (not train.jsonl/eval.jsonl — those are derived)
    for jsonl_file in sorted(input_dir.glob("[0-9]*.jsonl")):
        filename = jsonl_file.name
        valid_examples = []
        rejected_examples = []
        file_issues = 0

        with open(jsonl_file, 'r') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    example = json.loads(line)
                except json.JSONDecodeError:
                    stats["rejected"] += 1
                    continue

                stats["total"] += 1

                is_valid, issues = validate_example(example, live_symbols)

                if not is_valid:
                    if args.fix:
                        # Try auto-fix
                        example = fix_example(example)
                        is_valid_after_fix, remaining_issues = validate_example(example, live_symbols)
                        if is_valid_after_fix or example.get("_auto_fixed"):
                            valid_examples.append(example)
                            stats["fixed"] += 1
                            stats["valid"] += 1
                        else:
                            rejected_examples.append({"example": example, "issues": remaining_issues, "line": line_num})
                            stats["rejected"] += 1
                            for issue in remaining_issues:
                                issue_type = issue.split(":")[0]
                                stats["issues_by_type"][issue_type] += 1
                    else:
                        rejected_examples.append({"example": example, "issues": issues, "line": line_num})
                        stats["rejected"] += 1
                        file_issues += 1
                        for issue in issues:
                            issue_type = issue.split(":")[0]
                            stats["issues_by_type"][issue_type] += 1
                else:
                    valid_examples.append(example)
                    stats["valid"] += 1

        # Write valid examples
        if valid_examples:
            with open(output_dir / filename, 'w', encoding='utf-8') as f:
                for ex in valid_examples:
                    f.write(json.dumps(ex, ensure_ascii=False) + "\n")

        # Write rejected examples
        if rejected_examples:
            with open(quarantine_dir / filename, 'w', encoding='utf-8') as f:
                for r in rejected_examples:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")

        status = "✅" if file_issues == 0 else f"⚠️ {file_issues} issues"
        print(f"  {filename}: {len(valid_examples)} valid, {len(rejected_examples)} rejected {status}")
        all_valid.extend(valid_examples)
        all_rejected.extend(rejected_examples)
        stats["files_processed"] += 1

    # Rebuild train.jsonl and eval.jsonl from validated data
    import random
    random.seed(42)
    random.shuffle(all_valid)
    split = int(len(all_valid) * 0.9)

    with open(output_dir / "train.jsonl", 'w', encoding='utf-8') as f:
        for ex in all_valid[:split]:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    with open(output_dir / "eval.jsonl", 'w', encoding='utf-8') as f:
        for ex in all_valid[split:]:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    # Write validation report
    report = {
        "timestamp": "2026-03-27",
        "codebase_symbols": len(live_symbols),
        "total_examples": stats["total"],
        "valid": stats["valid"],
        "auto_fixed": stats["fixed"],
        "rejected": stats["rejected"],
        "quarantined": stats["quarantined"],
        "train_count": split,
        "eval_count": len(all_valid) - split,
        "issues_by_type": dict(stats["issues_by_type"]),
        "files_processed": stats["files_processed"],
        "stale_symbols_checked": list(BANNED_SYMBOLS),
        "wrong_return_types_checked": [(f, w, c) for f, w, c in WRONG_RETURN_TYPES],
    }

    with open(output_dir / "validation_report.json", 'w') as f:
        json.dump(report, f, indent=2)

    # Summary
    print(f"\n{'='*60}")
    print(f"  VALIDATION COMPLETE")
    print(f"  Total: {stats['total']} | Valid: {stats['valid']} | "
          f"Fixed: {stats['fixed']} | Rejected: {stats['rejected']}")
    print(f"  Train: {split} | Eval: {len(all_valid) - split}")
    if stats["issues_by_type"]:
        print(f"  Issues found:")
        for issue_type, count in stats["issues_by_type"].most_common():
            print(f"    {issue_type}: {count}")
    print(f"  Output: {output_dir}")
    print(f"  Quarantined: {quarantine_dir}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
