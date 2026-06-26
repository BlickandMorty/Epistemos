#!/bin/bash
set -euo pipefail

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]; then
    exit 0
fi

RESOURCES_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
EDITOR_SOURCE_DIR="$SRCROOT/Epistemos/Resources/Editor"
EDITOR_BUNDLE_DIR="$RESOURCES_DIR/Editor"
DEFAULT_SKILLS_SOURCE_DIR="$SRCROOT/.agents/skills"
DEFAULT_SKILLS_DIR="$RESOURCES_DIR/DefaultSkills"

bundle_editor_resources() {
    if [ ! -d "$EDITOR_SOURCE_DIR" ]; then
        return
    fi

    mkdir -p "$EDITOR_BUNDLE_DIR"
    rsync -a --delete "$EDITOR_SOURCE_DIR/" "$EDITOR_BUNDLE_DIR/"

    # Xcode's synchronized resource groups flatten generated editor files
    # into Contents/Resources. Keep the canonical Resources/Editor tree and
    # remove the duplicate root-level copies so the bundle stays small.
    while IFS= read -r -d '' source_file; do
        rm -f "$RESOURCES_DIR/$(basename "$source_file")"
    done < <(find "$EDITOR_SOURCE_DIR" -type f -print0)
}

bundle_default_skills() {
    if [ ! -d "$DEFAULT_SKILLS_SOURCE_DIR" ]; then
        rm -rf "$DEFAULT_SKILLS_DIR"
        return
    fi

    mkdir -p "$DEFAULT_SKILLS_DIR"
    rsync -a --delete --prune-empty-dirs \
        --include='*/' \
        --include='SKILL.md' \
        --exclude='*' \
        "$DEFAULT_SKILLS_SOURCE_DIR/" \
        "$DEFAULT_SKILLS_DIR/"
}

bundle_editor_resources
bundle_default_skills
