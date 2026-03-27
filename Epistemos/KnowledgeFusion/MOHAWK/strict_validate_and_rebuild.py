#!/usr/bin/env python3
"""
Strict Training Data Validator & Rebuilder
===========================================

Aggressively filters symbol_qa and code_grounded against live source.
Rejects:
  - Any "Void)?" hallucinated return type
  - Wrong "Part of" ownership (enum cited as class, param type cited as owner)
  - References to deleted views (NoteTabView, etc.)
  - Garbage strings in ownership ("Part of `that`")

Then rebuilds train.jsonl/eval.jsonl from ONLY clean data.

Usage:
    python strict_validate_and_rebuild.py --codebase ~/Downloads/Epistemos
"""

import json, os, re, hashlib, random, sys
from pathlib import Path
from collections import Counter

CODEBASE = os.environ.get("EPISTEMOS_ROOT", os.path.expanduser("~/Downloads/Epistemos"))
DATA_DIR = Path(__file__).parent / "epistemos_training_data_validated"
OUTPUT_DIR = DATA_DIR  # overwrite in place

# ─── Patterns to REJECT ────────────────────────────────────────

REJECT_PATTERNS = [
    # Hallucinated return types
    (r'Void\)\?', "HALLUCINATED_RETURN: contains 'Void)?'"),
    # Garbage ownership
    (r"Part of [`']that[`']", "GARBAGE_OWNERSHIP: 'Part of that'"),
    (r"Part of [`'][a-z]", "LOWERCASE_OWNERSHIP: Part of lowercase (likely wrong)"),
]

# Known enums that should NOT appear as "Part of `EnumName`" for functions
KNOWN_ENUMS = {
    "KFTrainingState", "RiskLevel", "EscalationReason", "DeviceActionType",
    "LocalModelKind", "AutoresearchProgress", "GatewayError",
    "KFTrainingPhase", "NotesOperation",
}

# Known param/return types that should NOT appear as "Part of" owners
KNOWN_PARAM_TYPES = {
    "LocalMLXRequest", "AdapterMetadata", "TierConfig", "AgentStep",
    "AgentStepResult", "TrainingExample", "ParsedToolCall",
}

# Deleted views/types
DELETED_SYMBOLS = {"NoteTabView"}


def scan_live_classes(codebase: str) -> dict:
    """Scan codebase and categorize symbols as class/struct/enum/protocol."""
    symbols = {}
    swift_dir = os.path.join(codebase, "Epistemos")
    for root, dirs, files in os.walk(swift_dir):
        dirs[:] = [d for d in dirs if d not in {".build", "DerivedData", ".git"}]
        for fn in files:
            if not fn.endswith(".swift"):
                continue
            try:
                with open(os.path.join(root, fn), 'r', errors='replace') as f:
                    content = f.read()
                for match in re.finditer(r'(class|struct|enum|protocol|actor)\s+(\w+)', content):
                    kind, name = match.group(1), match.group(2)
                    symbols[name] = kind
            except Exception:
                pass
    return symbols


def validate_line(text: str, symbols: dict) -> list:
    """Return list of issues found in the text."""
    issues = []

    # Check reject patterns
    for pattern, msg in REJECT_PATTERNS:
        if re.search(pattern, text):
            issues.append(msg)

    # Check "Part of `X`" claims
    for match in re.finditer(r"Part of [`'](\w+)[`']", text):
        claimed = match.group(1)
        if claimed in KNOWN_ENUMS:
            issues.append(f"ENUM_AS_OWNER: 'Part of {claimed}' but {claimed} is an enum")
        if claimed in KNOWN_PARAM_TYPES:
            issues.append(f"PARAM_AS_OWNER: 'Part of {claimed}' but {claimed} is a param/return type")
        if claimed in DELETED_SYMBOLS:
            issues.append(f"DELETED_SYMBOL: 'Part of {claimed}' but {claimed} doesn't exist")
        # Check against live source
        if claimed in symbols and symbols[claimed] == "enum":
            issues.append(f"LIVE_ENUM_AS_OWNER: 'Part of {claimed}' but live source shows it's an enum")

    # Check for deleted view references in code-grounded
    for deleted in DELETED_SYMBOLS:
        if deleted in text:
            issues.append(f"STALE_REF: references '{deleted}' which is deleted")

    return issues


def main():
    print(f"\n{'='*60}")
    print(f"  Strict Validator & Rebuilder")
    print(f"  Codebase: {CODEBASE}")
    print(f"  Data: {DATA_DIR}")
    print(f"{'='*60}\n")

    # Scan live symbols
    print("Scanning live codebase for type classifications...")
    symbols = scan_live_classes(CODEBASE)
    enums_found = [k for k, v in symbols.items() if v == "enum"]
    print(f"  {len(symbols)} symbols, {len(enums_found)} enums\n")

    stats = Counter()
    all_clean = []
    all_rejected = []

    for jsonl_file in sorted(DATA_DIR.glob("[0-9]*.jsonl")):
        clean = []
        rejected = []

        with open(jsonl_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    ex = json.loads(line)
                except:
                    stats["parse_error"] += 1
                    continue

                stats["total"] += 1
                full_text = " ".join(m.get("content", "") for m in ex.get("messages", []))
                issues = validate_line(full_text, symbols)

                if issues:
                    rejected.append({"example": ex, "issues": issues})
                    stats["rejected"] += 1
                    for i in issues:
                        stats[i.split(":")[0]] += 1
                else:
                    clean.append(ex)
                    stats["clean"] += 1

        # Overwrite with clean data only
        with open(jsonl_file, 'w', encoding='utf-8') as f:
            for ex in clean:
                f.write(json.dumps(ex, ensure_ascii=False) + "\n")

        all_clean.extend(clean)
        all_rejected.extend(rejected)

        rej_count = len(rejected)
        status = "✅" if rej_count == 0 else f"🔴 {rej_count} rejected"
        print(f"  {jsonl_file.name}: {len(clean)} clean, {rej_count} rejected {status}")

    # Write quarantine
    quarantine_dir = DATA_DIR / "quarantined"
    os.makedirs(quarantine_dir, exist_ok=True)
    with open(quarantine_dir / "strict_rejects.jsonl", 'w') as f:
        for r in all_rejected:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    # Rebuild train.jsonl / eval.jsonl
    random.seed(42)
    random.shuffle(all_clean)
    split = int(len(all_clean) * 0.9)

    with open(DATA_DIR / "train.jsonl", 'w', encoding='utf-8') as f:
        for ex in all_clean[:split]:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    with open(DATA_DIR / "eval.jsonl", 'w', encoding='utf-8') as f:
        for ex in all_clean[split:]:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    # Category breakdown
    cats = Counter()
    for ex in all_clean:
        cats[ex.get("category", "unknown")] += 1

    print(f"\n{'='*60}")
    print(f"  STRICT VALIDATION COMPLETE")
    print(f"  Total: {stats['total']} | Clean: {stats['clean']} | Rejected: {stats['rejected']}")
    print(f"  Train: {split} | Eval: {len(all_clean) - split}")
    if stats["rejected"] > 0:
        print(f"\n  Rejection reasons:")
        for key in sorted(stats.keys()):
            if key not in ("total", "clean", "rejected", "parse_error"):
                if stats[key] > 0:
                    print(f"    {key}: {stats[key]}")
    print(f"\n  Category breakdown (clean only):")
    for c, n in cats.most_common():
        print(f"    {c}: {n}")
    print(f"\n  Quarantined: {quarantine_dir}/strict_rejects.jsonl ({len(all_rejected)} examples)")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
