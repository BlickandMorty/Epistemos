# Hermes Bundling Build Phase

## Overview
The bundling procedure handles freezing Hermes and a macOS-native Python environment into a self-contained runtime layer for the Epistemos DD build.

## Build Steps
1. **Fetch Standalone Archive:** Download `python-build-standalone` (`20251031`, CPython 3.12) matching target architecture.
2. **Universal Fat Binary Generation:** Fuse `x86_64` and `aarch64` architectures using `lipo` to maintain a unified runtime layer.
3. **Dependency Resolution:** Execute `uv pip compile --generate-hashes` for Hermes + required tool transitive dependencies (Playwright, pypdf, markitdown, etc). Install flattened packages via `only-binary=:all:` to explicitly block building sdists.
4. **Site-package flattening:** Clean testing artifacts, pycache directories, and standard lib unnecessary files to reduce bloat.
5. **Inner Code Signing (Inside-out pass):**
   * Apply `-s "Developer ID Application"` 
   * Pass `--options runtime`
   * Provide custom hermes entitlements (`allow-jit`, `disable-library-validation`). DO NOT include `allow-unsigned-executable-memory`.
6. Package final structure into `Epistemos.app/Contents/Resources/hermes-runtime/`.
