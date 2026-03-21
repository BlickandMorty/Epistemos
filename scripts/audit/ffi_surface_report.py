#!/usr/bin/env python3

from __future__ import annotations

import re
import subprocess
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path


EXPORT_PATTERN = re.compile(r"\b(graph_engine_[A-Za-z0-9_]+)\s*\(")


def exported_symbols(header_text: str) -> list[str]:
    ordered: list[str] = []
    seen: set[str] = set()
    for line in header_text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("typedef "):
            continue
        match = EXPORT_PATTERN.search(stripped)
        if match is None:
            continue
        symbol = match.group(1)
        if symbol in seen:
            continue
        seen.add(symbol)
        ordered.append(symbol)
    return ordered


def rg_hits(root: Path, symbol: str) -> list[str]:
    command = [
        "rg",
        "-n",
        symbol,
        str(root / "Epistemos"),
        str(root / "EpistemosTests"),
        str(root / "graph-engine-bridge"),
        "--glob",
        "!graph-engine-bridge/graph_engine.h",
    ]
    result = subprocess.run(command, cwd=root, text=True, capture_output=True, check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr.strip() or f"rg failed for {symbol}")
    return [line for line in result.stdout.splitlines() if line]


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    report_path = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else root / "docs" / "audits" / f"ffi-surface-report-{date.today():%F}.md"
    )
    report_path.parent.mkdir(parents=True, exist_ok=True)

    header_path = root / "graph-engine-bridge" / "graph_engine.h"
    symbols = exported_symbols(header_path.read_text(encoding="utf-8"))
    hits_by_symbol: dict[str, list[str]] = {}
    file_counts: dict[str, int] = defaultdict(int)

    for symbol in symbols:
        hits = rg_hits(root, symbol)
        hits_by_symbol[symbol] = hits
        for hit in hits:
            file_counts[hit.split(":", 1)[0]] += 1

    unused = [symbol for symbol, hits in hits_by_symbol.items() if not hits]
    lines = [
        "# FFI Surface Report",
        "",
        f"- Generated: {date.today():%F}",
        f"- Root: `{root}`",
        f"- Export count: {len(symbols)}",
        "",
        "## Candidate Unused FFI Exports",
    ]
    if unused:
        lines.extend(f"- `{symbol}`" for symbol in unused)
    else:
        lines.append("- none")

    lines.extend([
        "",
        "## Export Coverage Samples",
    ])
    for symbol in symbols:
        hits = hits_by_symbol[symbol]
        if not hits:
            continue
        lines.append(f"- `{symbol}`")
        lines.extend(f"  - `{hit}`" for hit in hits[:3])

    lines.extend([
        "",
        "## Notes",
        "- This scan reports symbols exported from `graph_engine.h` with no caller hits in Swift, tests, or the bridge layer.",
        "- Treat candidate unused exports as audit leads, not auto-delete proof.",
    ])

    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
