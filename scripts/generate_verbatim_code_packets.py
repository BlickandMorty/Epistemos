#!/usr/bin/env python3
"""Generate markdown packets containing verbatim tracked text files.

This is a research-handoff utility. It intentionally works from `git ls-files`
so generated packets do not recursively include themselves, and so build output,
cache directories, and loose local files do not sneak into the corpus.
"""

from __future__ import annotations

import argparse
import math
import os
import subprocess
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path


BINARY_EXTENSIONS = {
    ".bin",
    ".comp",
    ".d",
    ".docx",
    ".gguf",
    ".gif",
    ".gz",
    ".icns",
    ".inp",
    ".jpg",
    ".jpeg",
    ".o",
    ".out",
    ".pdf",
    ".png",
    ".rlib",
    ".rmeta",
    ".timestamp",
    ".webp",
    ".woff",
    ".woff2",
    ".xcuserstate",
    ".zip",
}

EXCLUDED_PREFIXES = (
    ".derived-data",
    ".git/",
    ".spm-cache/",
    ".claude/logs/",
    ".claude/worktrees/",
    "artifacts/",
    "build/",
    "build-rust/",
    "docs/audits/codebase-verbatim-packets-",
    "docs/audits/COMPLETE_CODEBASE_RESEARCH_PACKET_",
    "docs/audits/CURRENT_APP_ARCHITECTURE_RESEARCH_PACKET_",
    "docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_",
)

EXCLUDED_PATH_PARTS = (
    "/.build/",
    "/DerivedData/",
    "/node_modules/",
    "/target/",
)

LANG_BY_EXTENSION = {
    ".c": "c",
    ".cl": "opencl",
    ".cmake": "cmake",
    ".cpp": "cpp",
    ".css": "css",
    ".cu": "cuda",
    ".cuh": "cuda",
    ".entitlements": "xml",
    ".gbnf": "bnf",
    ".gitignore": "gitignore",
    ".glsl": "glsl",
    ".h": "c",
    ".hpp": "cpp",
    ".html": "html",
    ".js": "javascript",
    ".json": "json",
    ".jsonl": "jsonl",
    ".jsx": "jsx",
    ".kt": "kotlin",
    ".lean": "lean",
    ".m": "objective-c",
    ".md": "markdown",
    ".metal": "metal",
    ".mjs": "javascript",
    ".mm": "objective-c++",
    ".modulemap": "c",
    ".nix": "nix",
    ".pbxproj": "text",
    ".plist": "xml",
    ".py": "python",
    ".rs": "rust",
    ".sh": "bash",
    ".svelte": "svelte",
    ".swift": "swift",
    ".toml": "toml",
    ".ts": "typescript",
    ".tsx": "tsx",
    ".txt": "text",
    ".wgsl": "wgsl",
    ".xcfilelist": "text",
    ".xcscheme": "xml",
    ".xcworkspacedata": "xml",
    ".xml": "xml",
    ".yaml": "yaml",
    ".yml": "yaml",
}

LANG_BY_NAME = {
    "Dockerfile": "dockerfile",
    "Makefile": "makefile",
    "CMakeLists.txt": "cmake",
    "Package.swift": "swift",
}


@dataclass(frozen=True)
class FileRecord:
    path: str
    size: int
    lines: int
    text: str

    @property
    def top_level(self) -> str:
        return self.path.split("/", 1)[0]

    @property
    def language(self) -> str:
        name = Path(self.path).name
        if name in LANG_BY_NAME:
            return LANG_BY_NAME[name]
        return LANG_BY_EXTENSION.get(Path(self.path).suffix, "text")


@dataclass(frozen=True)
class SkippedRecord:
    path: str
    reason: str


def git_ls_files(repo: Path) -> list[str]:
    output = subprocess.check_output(["git", "ls-files", "-z"], cwd=repo)
    return [os.fsdecode(part) for part in output.split(b"\0") if part]


def should_exclude_path(path: str) -> str | None:
    if path.startswith(EXCLUDED_PREFIXES):
        return "excluded generated/build/audit prefix"
    normalized = f"/{path}"
    for part in EXCLUDED_PATH_PARTS:
        if part in normalized:
            return f"excluded path component {part.strip('/')}"
    if Path(path).suffix in BINARY_EXTENSIONS:
        return f"binary/generated extension {Path(path).suffix}"
    return None


def decode_text(data: bytes) -> str | None:
    if b"\0" in data[:8192]:
        return None
    for encoding in ("utf-8", "utf-16"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return None


def collect_files(repo: Path, max_file_bytes: int) -> tuple[list[FileRecord], list[SkippedRecord]]:
    records: list[FileRecord] = []
    skipped: list[SkippedRecord] = []
    for rel in git_ls_files(repo):
        exclusion = should_exclude_path(rel)
        if exclusion:
            skipped.append(SkippedRecord(rel, exclusion))
            continue
        path = repo / rel
        if path.is_dir():
            skipped.append(SkippedRecord(rel, "gitlink/submodule directory"))
            continue
        try:
            data = path.read_bytes()
        except OSError as exc:
            skipped.append(SkippedRecord(rel, f"read error: {exc}"))
            continue
        if len(data) > max_file_bytes:
            skipped.append(SkippedRecord(rel, f"too large for markdown packet: {len(data)} bytes"))
            continue
        text = decode_text(data)
        if text is None:
            skipped.append(SkippedRecord(rel, "binary or non-text"))
            continue
        records.append(FileRecord(rel, len(data), text.count("\n") + (0 if text.endswith("\n") else 1), text))
    return sorted(records, key=lambda rec: subsystem_sort_key(rec.path)), skipped


def subsystem_sort_key(path: str) -> tuple[int, str]:
    order = [
        "AGENTS.md",
        "CLAUDE.md",
        "project.yml",
        "Epistemos/",
        "EpistemosTests/",
        "XPCServices/",
        "EpistemosWidgets/",
        "EpistemosNightBrainHelper/",
        "graph-engine/",
        "graph-engine-bridge/",
        "agent_core/",
        "omega-mcp/",
        "omega-ax/",
        "epistemos-core/",
        "epistemos-shadow/",
        "epistemos-code-index/",
        "substrate-core/",
        "substrate-rt/",
        "syntax-core/",
        "syntax-core-bridge/",
        "LocalPackages/",
        "js-editor/",
        "scripts/",
        "Tools/",
        "bench/",
        "benchmarks/",
        ".github/",
        "docs/",
        "lean/",
        "epistemos-research/",
        "epistemos-vault/",
    ]
    for idx, prefix in enumerate(order):
        if path == prefix.rstrip("/") or path.startswith(prefix):
            return idx, path
    return len(order), path


def chunk_records(records: list[FileRecord], packet_count: int) -> list[list[FileRecord]]:
    total = sum(record.size for record in records)
    target = max(1, total / packet_count)
    chunks: list[list[FileRecord]] = []
    current: list[FileRecord] = []
    cumulative_size = 0
    next_threshold = target
    for idx, record in enumerate(records):
        should_cut = (
            current
            and len(chunks) < packet_count - 1
            and cumulative_size >= next_threshold
            and (len(records) - idx) >= (packet_count - len(chunks) - 1)
        )
        if should_cut:
            chunks.append(current)
            current = []
            next_threshold = target * (len(chunks) + 1)
        current.append(record)
        cumulative_size += record.size
    if current:
        chunks.append(current)
    return chunks


def markdown_link(path: str) -> str:
    return path.replace(" ", "%20")


def fence_for(text: str) -> str:
    longest = 0
    current = 0
    for char in text:
        if char == "`":
            current += 1
            longest = max(longest, current)
        else:
            current = 0
    return "`" * max(4, longest + 1)


def write_packet(out_dir: Path, packet_number: int, total_packets: int, records: list[FileRecord]) -> str:
    name = f"{packet_number:02d}_CODE_PACKET.md"
    path = out_dir / name
    top_counts = Counter(record.top_level for record in records)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(f"# Code Packet {packet_number:02d} of {total_packets:02d}\n\n")
        handle.write("This packet contains verbatim tracked text/code files. Generated build outputs, binaries, model weights, media, and recursive audit packets are excluded by the generator and summarized in `00_INDEX.md`.\n\n")
        handle.write("## Packet Outline\n\n")
        handle.write(f"- Files: {len(records)}\n")
        handle.write(f"- Bytes: {sum(record.size for record in records):,}\n")
        handle.write(f"- Lines: {sum(record.lines for record in records):,}\n")
        handle.write("- Primary areas: " + ", ".join(f"{name} ({count})" for name, count in top_counts.most_common(8)) + "\n\n")
        handle.write("## Files In This Packet\n\n")
        for idx, record in enumerate(records, 1):
            handle.write(f"{idx}. `{record.path}` ({record.lines:,} lines, {record.size:,} bytes)\n")
        handle.write("\n")
        for idx, record in enumerate(records, 1):
            fence = fence_for(record.text)
            handle.write(f"## File {idx}: `{record.path}`\n\n")
            handle.write(f"- Top-level area: `{record.top_level}`\n")
            handle.write(f"- Lines: {record.lines:,}\n")
            handle.write(f"- Bytes: {record.size:,}\n")
            handle.write(f"- Language fence: `{record.language}`\n\n")
            handle.write(f"{fence}{record.language}\n")
            handle.write(record.text)
            if record.text and not record.text.endswith("\n"):
                handle.write("\n")
            handle.write(f"{fence}\n\n")
    return name


def write_index(
    out_dir: Path,
    records: list[FileRecord],
    skipped: list[SkippedRecord],
    packet_names: list[str],
    chunks: list[list[FileRecord]],
    packet_count: int,
    generated_date: str,
) -> None:
    top_counts: dict[str, int] = defaultdict(int)
    top_bytes: dict[str, int] = defaultdict(int)
    for record in records:
        top_counts[record.top_level] += 1
        top_bytes[record.top_level] += record.size

    skipped_reasons = Counter(record.reason for record in skipped)
    index_path = out_dir / "00_INDEX.md"
    with index_path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write("# Verbatim Codebase Markdown Packets\n\n")
        handle.write(f"Generated: {generated_date}\n\n")
        handle.write("This bundle converts the git-tracked, text-readable source corpus into markdown packets for external research. Each packet begins with an outline and then includes verbatim fenced file contents.\n\n")
        handle.write("## Scope\n\n")
        handle.write("- Source of truth: `git ls-files` from the current workspace.\n")
        handle.write(f"- Requested packet count: {packet_count}\n")
        handle.write(f"- Actual code packets: {len(packet_names)}\n")
        handle.write(f"- Included files: {len(records):,}\n")
        handle.write(f"- Included bytes: {sum(record.size for record in records):,}\n")
        handle.write(f"- Included lines: {sum(record.lines for record in records):,}\n")
        handle.write(f"- Skipped tracked files: {len(skipped):,}\n\n")
        handle.write("## Exclusion Policy\n\n")
        handle.write("Skipped files are build outputs, binary/model/media assets, generated artifacts, recursive audit packets, or text files larger than the configured per-file cap. This keeps the markdown corpus useful for code research without embedding object files, model weights, images, or generated build state.\n\n")
        handle.write("### Skipped Reasons\n\n")
        for reason, count in skipped_reasons.most_common():
            handle.write(f"- {reason}: {count:,}\n")
        handle.write("\n")
        handle.write("## Top-Level Coverage\n\n")
        for area, count in sorted(top_counts.items(), key=lambda item: (-top_bytes[item[0]], item[0])):
            handle.write(f"- `{area}`: {count:,} files, {top_bytes[area]:,} bytes\n")
        handle.write("\n")
        handle.write("## Packet Map\n\n")
        handle.write("| Packet | Files | Bytes | Lines | Main Areas |\n")
        handle.write("|---|---:|---:|---:|---|\n")
        for name, chunk in zip(packet_names, chunks):
            area_counts = Counter(record.top_level for record in chunk)
            areas = ", ".join(f"`{area}` ({count})" for area, count in area_counts.most_common(5))
            handle.write(
                f"| [{name}]({markdown_link(name)}) | {len(chunk):,} | {sum(record.size for record in chunk):,} | {sum(record.lines for record in chunk):,} | {areas} |\n"
            )
        handle.write("\n")
        handle.write("## Research Notes\n\n")
        handle.write("- Use `00_INDEX.md` first to understand which packets contain which top-level systems.\n")
        handle.write("- Packet order roughly follows product architecture first, tests/runtime next, package/runtime crates next, scripts/tools/docs later.\n")
        handle.write("- Every file body is verbatim; only packet headings and metadata are generated.\n")
        handle.write("- To regenerate, run `python3 scripts/generate_verbatim_code_packets.py --packets 40` from the repo root.\n\n")


def clean_output_dir(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for path in out_dir.glob("*.md"):
        path.unlink()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packets", type=int, default=40, help="target number of code packet markdown files")
    parser.add_argument("--max-file-bytes", type=int, default=2_000_000, help="skip individual text files larger than this")
    parser.add_argument(
        "--out-dir",
        default="docs/audits/codebase-verbatim-packets-2026-05-09",
        help="output directory for packet markdown files",
    )
    parser.add_argument("--generated-date", default=date.today().isoformat(), help="date to write in 00_INDEX.md")
    args = parser.parse_args()

    repo = Path.cwd()
    out_dir = repo / args.out_dir
    records, skipped = collect_files(repo, args.max_file_bytes)
    chunks = chunk_records(records, args.packets)
    clean_output_dir(out_dir)
    packet_names = [write_packet(out_dir, idx, len(chunks), chunk) for idx, chunk in enumerate(chunks, 1)]
    write_index(out_dir, records, skipped, packet_names, chunks, args.packets, args.generated_date)
    print(f"Wrote {len(packet_names)} packets plus 00_INDEX.md to {out_dir}")
    print(f"Included {len(records)} files, {sum(record.size for record in records):,} bytes")
    print(f"Skipped {len(skipped)} tracked files")


if __name__ == "__main__":
    main()
