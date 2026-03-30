#!/bin/bash
# EPISTEMOS AGENT SYSTEM — AUTO-INSTALL
# Run this from the Epistemos project root.
# It copies all architecture docs from ~/Downloads/release/for codex/
# into the correct project locations, then sets up hooks and directories.
#
# Usage: cd /path/to/epistemos && bash docs/agent-system/install.sh

set -euo pipefail

PROJECT_ROOT="$(pwd)"
SOURCE_DIR="$HOME/Downloads/release/for codex"

echo "══════════════════════════════════════════════════════════════"
echo "  EPISTEMOS AGENT SYSTEM — AUTO-INSTALL"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "Project root:  $PROJECT_ROOT"
echo "Source files:   $SOURCE_DIR"
echo ""

# ── Verify we're in the right place ─────────────────────────────────────
if [ ! -d "Epistemos" ] && [ ! -f "project.yml" ]; then
    echo "ERROR: Run this from the Epistemos project root."
    echo "  cd /path/to/epistemos && bash docs/agent-system/install.sh"
    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Source directory not found at: $SOURCE_DIR"
    echo "  Make sure the downloaded files are at ~/Downloads/release/for codex/"
    exit 1
fi

# ── Create directory structure ───────────────────────────────────────────
echo "Creating directories..."
mkdir -p docs/agent-system
mkdir -p docs/sprint-sessions
mkdir -p docs/audit-prompts
mkdir -p .claude
mkdir -p agent_core/src/providers
mkdir -p agent_core/src/tools
mkdir -p agent_core/src/storage
mkdir -p Epistemos/Bridge
mkdir -p Epistemos/ViewModels
mkdir -p Epistemos/Views
mkdir -p Epistemos/LocalAgent
mkdir -p Epistemos/ComputerUse
echo "  ✅ All directories created"
echo ""

# ── Backup existing files ────────────────────────────────────────────────
BACKUP_SUFFIX="backup.$(date +%Y%m%d-%H%M%S)"

backup_if_exists() {
    if [ -f "$1" ]; then
        cp "$1" "$1.$BACKUP_SUFFIX"
        echo "  📦 Backed up: $1 → $1.$BACKUP_SUFFIX"
    fi
}

echo "Backing up existing files..."
backup_if_exists "CLAUDE.md"
backup_if_exists ".claude/settings.json"
backup_if_exists ".claude/context-essentials.txt"
echo ""

# ── Copy files from source directory ─────────────────────────────────────
echo "Copying files from $SOURCE_DIR..."

copy_file() {
    local src="$1"
    local dst="$2"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        echo "  ✅ $dst"
    else
        echo "  ⚠️  Not found: $src (skipping)"
    fi
}

# Root-level files
copy_file "$SOURCE_DIR/CLAUDE.md" "CLAUDE.md"

# .claude/ hook files
copy_file "$SOURCE_DIR/.claude/settings.json" ".claude/settings.json"
copy_file "$SOURCE_DIR/.claude/context-essentials.txt" ".claude/context-essentials.txt"

# docs/ — bootstrap prompt and progress tracker
copy_file "$SOURCE_DIR/docs/CODEX_AGENT_BOOTSTRAP.md" "docs/CODEX_AGENT_BOOTSTRAP.md"
copy_file "$SOURCE_DIR/docs/AGENT_PROGRESS.md" "docs/AGENT_PROGRESS.md"

# docs/agent-system/ — architecture and gap analysis
# These come from the previous session's output files
copy_file "$SOURCE_DIR/docs/agent-system/install.sh" "docs/agent-system/install.sh"

# Sprint files
copy_file "$SOURCE_DIR/docs/sprint-sessions/sprint-agent-1-living-loop.md" "docs/sprint-sessions/sprint-agent-1-living-loop.md"

# ── Handle the architecture docs ─────────────────────────────────────────
# The full agent architecture spec (previously output as CLAUDE.md from the
# first session) needs to be placed at docs/agent-system/AGENT_ARCHITECTURE.md.
# The gap analysis goes to docs/agent-system/GAP_ANALYSIS.md.
# Check multiple possible filenames from the source directory.

echo ""
echo "Looking for architecture docs..."

# Try to find and copy the agent architecture doc
for candidate in \
    "$SOURCE_DIR/epistemos-agent-core/CLAUDE.md" \
    "$SOURCE_DIR/AGENT_ARCHITECTURE.md" \
    "$SOURCE_DIR/docs/agent-system/AGENT_ARCHITECTURE.md"; do
    if [ -f "$candidate" ]; then
        cp "$candidate" "docs/agent-system/AGENT_ARCHITECTURE.md"
        echo "  ✅ docs/agent-system/AGENT_ARCHITECTURE.md (from $candidate)"
        break
    fi
done
[ ! -f "docs/agent-system/AGENT_ARCHITECTURE.md" ] && echo "  ⚠️  AGENT_ARCHITECTURE.md not found — see instructions below"

# Try to find and copy the gap analysis
for candidate in \
    "$SOURCE_DIR/epistemos-agent-core/EPISTEMOS_GAP_ANALYSIS.md" \
    "$SOURCE_DIR/GAP_ANALYSIS.md" \
    "$SOURCE_DIR/EPISTEMOS_GAP_ANALYSIS.md" \
    "$SOURCE_DIR/docs/agent-system/GAP_ANALYSIS.md"; do
    if [ -f "$candidate" ]; then
        cp "$candidate" "docs/agent-system/GAP_ANALYSIS.md"
        echo "  ✅ docs/agent-system/GAP_ANALYSIS.md (from $candidate)"
        break
    fi
done
[ ! -f "docs/agent-system/GAP_ANALYSIS.md" ] && echo "  ⚠️  GAP_ANALYSIS.md not found — see instructions below"

# ── Copy Rust source files if they exist ─────────────────────────────────
echo ""
echo "Looking for pre-built Rust source files..."

for rs_file in lib.rs types.rs provider.rs agent_loop.rs bridge.rs error.rs prompts.rs session.rs routing.rs; do
    for candidate in \
        "$SOURCE_DIR/epistemos-agent-core/src/$rs_file" \
        "$SOURCE_DIR/src/$rs_file"; do
        if [ -f "$candidate" ]; then
            cp "$candidate" "agent_core/src/$rs_file"
            echo "  ✅ agent_core/src/$rs_file"
            break
        fi
    done
done

# Nested Rust files
for nested in providers/claude.rs tools/registry.rs storage/vault.rs storage/recipe_cache.rs; do
    for candidate in \
        "$SOURCE_DIR/epistemos-agent-core/src/$nested" \
        "$SOURCE_DIR/src/$nested"; do
        if [ -f "$candidate" ]; then
            cp "$candidate" "agent_core/src/$nested"
            echo "  ✅ agent_core/src/$nested"
            break
        fi
    done
done

# ── Copy Swift source files if they exist ────────────────────────────────
echo ""
echo "Looking for pre-built Swift source files..."

for swift_pair in \
    "OmegaPanel.swift:Epistemos/Views/OmegaPanel.swift" \
    "AgentViewModel.swift:Epistemos/ViewModels/AgentViewModel.swift" \
    "StreamingDelegate.swift:Epistemos/Bridge/StreamingDelegate.swift"; do
    IFS=':' read -r src_name dst_path <<< "$swift_pair"
    for candidate in \
        "$SOURCE_DIR/epistemos-agent-core/src/swift/$src_name" \
        "$SOURCE_DIR/src/swift/$src_name" \
        "$SOURCE_DIR/$src_name"; do
        if [ -f "$candidate" ]; then
            cp "$candidate" "$dst_path"
            echo "  ✅ $dst_path"
            break
        fi
    done
done

# ── Copy additional research/spec docs ───────────────────────────────────
echo ""
echo "Looking for additional spec documents..."

copy_file "$SOURCE_DIR/EPISTEMOS_FUSED_v3.md" "docs/EPISTEMOS_FUSED_v3.md"
copy_file "$SOURCE_DIR/epistemos-deep-analysis.md" "docs/epistemos-deep-analysis.md"
copy_file "$SOURCE_DIR/ANTI_DRIFT_SYSTEM.md" "docs/ANTI_DRIFT_SYSTEM.md"
copy_file "$SOURCE_DIR/Agent_Architecture_and_Implementation_Details.pdf" "docs/agent-system/Agent_Architecture_and_Implementation_Details.pdf"

# ── Append agent progress to PROGRESS.md if it exists ────────────────────
if [ -f "docs/PROGRESS.md" ] && [ -f "docs/AGENT_PROGRESS.md" ]; then
    if ! grep -q "Sprint Agent-1" docs/PROGRESS.md 2>/dev/null; then
        echo "" >> docs/PROGRESS.md
        echo "---" >> docs/PROGRESS.md
        echo "" >> docs/PROGRESS.md
        cat docs/AGENT_PROGRESS.md >> docs/PROGRESS.md
        echo "  ✅ Agent progress appended to docs/PROGRESS.md"
    else
        echo "  ℹ️  Agent progress already in docs/PROGRESS.md (skipping)"
    fi
fi

# ── Final verification ──────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  VERIFICATION"
echo "══════════════════════════════════════════════════════════════"
echo ""

check() {
    if [ -f "$1" ]; then
        echo "  ✅ $1"
    else
        echo "  ❌ $1  ← MISSING"
    fi
}

echo "Core config:"
check "CLAUDE.md"
check ".claude/settings.json"
check ".claude/context-essentials.txt"

echo ""
echo "Architecture docs:"
check "docs/agent-system/AGENT_ARCHITECTURE.md"
check "docs/agent-system/GAP_ANALYSIS.md"
check "docs/CODEX_AGENT_BOOTSTRAP.md"

echo ""
echo "Sprint files:"
check "docs/sprint-sessions/sprint-agent-1-living-loop.md"

echo ""
echo "Progress:"
check "docs/PROGRESS.md"

echo ""
echo "Spec docs:"
check "docs/EPISTEMOS_FUSED_v3.md"
check "docs/epistemos-deep-analysis.md"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  WHAT TO DO NEXT"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  1. Fix any ❌ MISSING items above by placing files manually"
echo ""
echo "  2. Open Codex and give it this EXACT prompt:"
echo ""
echo '     Read docs/CODEX_AGENT_BOOTSTRAP.md and execute Phase 0'
echo '     (self-install verification), then Phase 1 (read architecture),'
echo '     then start Sprint Agent-1 by reading'
echo '     docs/sprint-sessions/sprint-agent-1-living-loop.md.'
echo '     Execute all tasks in order. Run verification after each task.'
echo '     Update docs/PROGRESS.md when done.'
echo ""
echo "  3. After Sprint Agent-1 completes, start a FRESH session for"
echo "     Sprint Agent-2. The sprint files and PROGRESS.md carry state"
echo "     across sessions automatically."
echo ""
echo "══════════════════════════════════════════════════════════════"
