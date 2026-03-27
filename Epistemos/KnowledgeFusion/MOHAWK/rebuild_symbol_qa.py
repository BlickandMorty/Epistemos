#!/usr/bin/env python3
"""
Rebuild symbol_qa from scratch — correct ownership via brace-depth parsing.

The old generator assigned functions to the FIRST type in the file.
This one tracks brace depth to determine the ACTUAL enclosing type.

Usage:
    python rebuild_symbol_qa.py --output ./epistemos_training_data_validated
"""

import json, os, re, hashlib, random
from pathlib import Path

CODEBASE = os.path.expanduser("~/Downloads/Epistemos")
SYSTEM_PROMPT = """You are Epistemos-Nano, an AI that deeply understands the Epistemos app.
You know every view, every state class, every service, every model.
You answer questions about the app with precision and cite specific files."""


def parse_swift_ownership(filepath: str) -> list:
    """Parse a Swift file and return (func_name, params, return_type, enclosing_type, subsystem) tuples
    using brace-depth tracking for correct ownership."""
    with open(filepath, 'r', errors='replace') as f:
        content = f.read()

    rel = os.path.relpath(filepath, CODEBASE)

    # Determine subsystem
    subsystem = "unknown"
    if "Views/Notes" in rel: subsystem = "note_editor"
    elif "Views/Graph" in rel: subsystem = "graph"
    elif "Views/Landing" in rel: subsystem = "landing"
    elif "Views/Settings" in rel: subsystem = "settings"
    elif "Views/Shell" in rel: subsystem = "shell"
    elif "Views/Chat" in rel: subsystem = "chat"
    elif "Views/Omega" in rel: subsystem = "omega_ui"
    elif "Views/Shared" in rel: subsystem = "shared_ui"
    elif "Views/MiniChat" in rel: subsystem = "mini_chat"
    elif "Views/Onboarding" in rel: subsystem = "onboarding"
    elif "Views/" in rel: subsystem = "views"
    elif "Intents/" in rel: subsystem = "intents"
    elif "State/" in rel: subsystem = "state"
    elif "Engine/" in rel: subsystem = "ai_pipeline"
    elif "Graph/" in rel: subsystem = "graph"
    elif "Models/" in rel: subsystem = "models"
    elif "Sync/" in rel: subsystem = "sync"
    elif "Omega/" in rel: subsystem = "omega"
    elif "Theme/" in rel: subsystem = "theme"
    elif "KnowledgeFusion/" in rel: subsystem = "training"
    elif "App/" in rel: subsystem = "app_bootstrap"
    elif "Extensions/" in rel: subsystem = "extensions"
    elif "Helpers/" in rel: subsystem = "helpers"

    results = []
    lines = content.split('\n')
    type_stack = []  # Stack of (type_name, brace_depth)
    brace_depth = 0

    for line in lines:
        stripped = line.strip()

        # Skip comments
        if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue

        # Track type declarations
        type_match = re.match(r'(?:public\s+|private\s+|internal\s+|fileprivate\s+)?(?:final\s+)?'
                             r'(class|struct|enum|actor|protocol)\s+(\w+)', stripped)
        if type_match:
            type_kind = type_match.group(1)
            type_name = type_match.group(2)
            type_stack.append((type_name, brace_depth, type_kind))

        # Track function declarations
        func_match = re.match(r'(?:public\s+|private\s+|internal\s+|fileprivate\s+)?'
                             r'(?:static\s+|class\s+|override\s+|nonisolated\s+)?'
                             r'(?:@\w+\s+)*'
                             r'func\s+(\w+)\s*(\([^)]*\))?(?:\s*(?:async\s+)?(?:throws\s+)?->\s*(\S+))?', stripped)
        if func_match:
            func_name = func_match.group(1)
            params_raw = func_match.group(2) or "()"
            return_type = func_match.group(3) or "Void"

            # Skip trivial/private functions
            if func_name.startswith("_") or len(func_name) < 3:
                continue

            # Clean params
            params = re.findall(r'(\w+)\s*:\s*([^,)]+)', params_raw)
            params_str = ", ".join(f"`{p}: {t.strip()}`" for p, t in params[:5]) if params else "none"

            # Find enclosing type from stack
            enclosing = "top-level"
            enclosing_kind = ""
            for type_name, depth, kind in reversed(type_stack):
                if depth < brace_depth:
                    enclosing = type_name
                    enclosing_kind = kind
                    break

            # Skip if enclosing type is private and tiny
            results.append({
                "func": func_name,
                "params": params_str,
                "return_type": return_type.rstrip('{').strip(),
                "enclosing": enclosing,
                "enclosing_kind": enclosing_kind,
                "file": rel,
                "subsystem": subsystem,
            })

        # Track braces
        brace_depth += stripped.count('{') - stripped.count('}')

        # Pop types that have closed
        while type_stack and type_stack[-1][1] >= brace_depth:
            type_stack.pop()

    return results


def generate_examples(all_funcs: list) -> list:
    """Generate symbol_qa training examples from parsed functions."""
    examples = []
    seen = set()

    for f in all_funcs:
        # Skip duplicates
        key = f"{f['func']}_{f['file']}"
        if key in seen:
            continue
        seen.add(key)

        # Build answer
        enclosing_str = f"Part of `{f['enclosing']}`" if f['enclosing'] != "top-level" else "Top-level function"
        ret_str = f" Returns `{f['return_type']}`." if f['return_type'] != "Void" else ""

        answer = (f"`{f['func']}()` is defined in `{f['file']}` ({f['subsystem']} subsystem). "
                 f"Parameters: {f['params']}.{ret_str} {enclosing_str}.")

        examples.append({
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"What does `{f['func']}()` in `{f['file']}` do?"},
                {"role": "assistant", "content": answer}
            ],
            "category": "symbol_qa",
            "layer": 2,
            "quality": 1.0
        })

    return examples


def main():
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--output", default="./epistemos_training_data_validated")
    args = p.parse_args()

    print(f"\n{'='*60}")
    print(f"  Rebuilding symbol_qa with correct ownership")
    print(f"{'='*60}\n")

    # Parse all Swift files
    all_funcs = []
    swift_dir = os.path.join(CODEBASE, "Epistemos")
    file_count = 0
    for root, dirs, files in os.walk(swift_dir):
        dirs[:] = [d for d in dirs if d not in {".build", "DerivedData", ".git"}]
        for fn in files:
            if fn.endswith(".swift"):
                filepath = os.path.join(root, fn)
                funcs = parse_swift_ownership(filepath)
                all_funcs.extend(funcs)
                file_count += 1

    print(f"  Parsed {file_count} Swift files, found {len(all_funcs)} functions")

    # Check ownership distribution
    from collections import Counter
    owners = Counter(f['enclosing'] for f in all_funcs)
    print(f"  Top enclosing types:")
    for name, count in owners.most_common(10):
        print(f"    {name}: {count}")

    # Generate examples
    examples = generate_examples(all_funcs)
    print(f"  Generated {len(examples)} symbol_qa examples")

    # Write
    output_path = os.path.join(args.output, "02_symbol_qa.jsonl")
    with open(output_path, 'w', encoding='utf-8') as f:
        for ex in examples:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")
    print(f"  Written: {output_path}")

    # Rebuild train/eval
    all_files = sorted(Path(args.output).glob("[0-9]*.jsonl"))
    all_examples = []
    for jf in all_files:
        with open(jf) as fh:
            for line in fh:
                line = line.strip()
                if line:
                    try:
                        all_examples.append(json.loads(line))
                    except:
                        pass

    random.seed(42)
    random.shuffle(all_examples)
    split = int(len(all_examples) * 0.9)

    with open(os.path.join(args.output, "train.jsonl"), 'w') as f:
        for ex in all_examples[:split]:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")
    with open(os.path.join(args.output, "eval.jsonl"), 'w') as f:
        for ex in all_examples[split:]:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    # Update validation_report.json
    cats = Counter(ex.get("category", "unknown") for ex in all_examples)
    report = {
        "timestamp": "2026-03-27T14:00:00",
        "generator": "rebuild_symbol_qa.py + strict_validate_and_rebuild.py",
        "total_examples": len(all_examples),
        "train_count": split,
        "eval_count": len(all_examples) - split,
        "symbol_qa_rebuilt": True,
        "ownership_method": "brace-depth parsing (not first-type-in-file)",
        "categories": dict(cats.most_common()),
    }
    with open(os.path.join(args.output, "validation_report.json"), 'w') as f:
        json.dump(report, f, indent=2)

    print(f"\n  FINAL: {len(all_examples)} total | train: {split} | eval: {len(all_examples) - split}")
    for c, n in cats.most_common():
        print(f"    {c}: {n}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
