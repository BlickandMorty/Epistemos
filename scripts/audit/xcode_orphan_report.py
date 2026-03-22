#!/usr/bin/env python3

from __future__ import annotations

import sys
from datetime import date
from pathlib import Path


SOURCE_SUFFIXES = {".swift", ".m", ".mm", ".metal"}


def collect_candidates(root: Path, group: str) -> list[Path]:
    return sorted(
        path for path in (root / group).rglob("*")
        if path.is_file() and path.suffix in SOURCE_SUFFIXES
    )


def orphaned_files(root: Path, project_text: str, group: str) -> list[Path]:
    candidates = collect_candidates(root, group)
    return [path for path in candidates if path.name not in project_text]


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    report_path = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else root / "docs" / "audits" / f"xcode-orphan-report-{date.today():%F}.md"
    )
    report_path.parent.mkdir(parents=True, exist_ok=True)

    project_text = (root / "Epistemos.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    app_orphans = orphaned_files(root, project_text, "Epistemos")
    test_orphans = orphaned_files(root, project_text, "EpistemosTests")

    lines = [
        "# Xcode Orphan Report",
        "",
        f"- Generated: {date.today():%F}",
        f"- Root: `{root}`",
        "",
        "## App Source Files Missing From The Xcode Project",
    ]
    if app_orphans:
        lines.extend(f"- `{path.relative_to(root)}`" for path in app_orphans)
    else:
        lines.append("- none")

    lines.extend([
        "",
        "## Test Source Files Missing From The Xcode Project",
    ])
    if test_orphans:
        lines.extend(f"- `{path.relative_to(root)}`" for path in test_orphans)
    else:
        lines.append("- none")

    lines.extend([
        "",
        "## Notes",
        "- This scan uses filename presence in `project.pbxproj` as the membership check.",
        "- It is meant to catch real drifts like source files that exist on disk but are never compiled.",
    ])

    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
