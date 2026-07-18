#!/usr/bin/env python3
"""Patch UniFFI-generated Swift for SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.

Only four general fixes are needed:
1. pointer property -> nonisolated(unsafe) (deinit accesses it from nonisolated context)
2. deinit body -> keep direct rustCall now that generated helpers are nonisolated,
   and snapshot the object pointer into a nonisolated(unsafe) local before free
3. errorDescription -> nonisolated (generated LocalizedError conformances are otherwise main-actor isolated)
4. declarations -> nonisolated/nonisolated(unsafe) so generated wrappers compile under Swift 6 default MainActor isolation

Free V1 builds additionally neutralize the unused generated RuntimeKind case
names. The Free V1 Swift backend is compiled out, but Swift otherwise retains
those paid-runtime case names in executable reflection metadata.
"""

import sys
import re

def neutralize_free_v1_runtime_kind(content):
    pattern = re.compile(
        r'nonisolated public enum RuntimeKind \{.*?'
        r'nonisolated extension RuntimeKind: Equatable, Hashable \{\}',
        flags=re.DOTALL,
    )
    match = pattern.search(content)
    if match is None:
        raise RuntimeError('generated RuntimeKind binding was not found')

    section = match.group(0)
    replacements = (
        ('gguf', 'unavailable'),
        ('mlx', 'reservedLocal'),
        ('remote', 'reservedExternal'),
    )
    for original, replacement in replacements:
        original_count = len(re.findall(rf'\b{original}\b', section))
        replacement_count = len(re.findall(rf'\b{replacement}\b', section))
        if original_count == 3 and replacement_count == 0:
            section = re.sub(rf'\b{original}\b', replacement, section)
        elif original_count != 0 or replacement_count != 3:
            raise RuntimeError(
                f'generated RuntimeKind.{original} binding shape changed'
            )

    return content[:match.start()] + section + content[match.end():]


def patch_file(path, free_v1=False):
    with open(path) as f:
        content = f.read()

    # 1. Make pointer nonisolated(unsafe)
    content = content.replace(
        'fileprivate let pointer: UnsafeMutableRawPointer!',
        'nonisolated(unsafe) fileprivate let pointer: UnsafeMutableRawPointer!'
    )
    content = re.sub(
        r'^(\s*)(?:nonisolated\(unsafe\)\s+)+fileprivate let pointer: UnsafeMutableRawPointer!$',
        r'\1nonisolated(unsafe) fileprivate let pointer: UnsafeMutableRawPointer!',
        content
        ,
        flags=re.MULTILINE
    )

    # 2. Normalize deinit bodies back to a direct rustCall now that the generated
    # helpers are explicitly nonisolated. Earlier MainActor wrapping becomes a
    # cross-isolation capture hazard under Swift 6.
    content = re.sub(
        r'        MainActor\.assumeIsolated \{\n            (try! rustCall \{ .+? \})\n        \}',
        r'        \1',
        content,
        flags=re.DOTALL
    )
    content = content.replace(
        '    deinit {\n        guard let pointer = pointer else {\n',
        '    deinit {\n        nonisolated(unsafe) let pointer = self.pointer\n        guard let pointer else {\n'
    )

    # 3. Generated LocalizedError conformances must be explicitly nonisolated
    content = re.sub(
        r'^(\s*)public var errorDescription: String\? \{$',
        r'\1nonisolated public var errorDescription: String? {',
        content,
        flags=re.MULTILINE
    )

    # 4a. Generated type declarations must be explicitly nonisolated under
    # SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
    content = re.sub(
        r'^(\s*)(?!nonisolated\b)((?:(?:open|public|private|fileprivate|internal|final|indirect)\s+)*)((?:class|struct|enum|protocol|extension)\b)',
        lambda match: f"{match.group(1)}nonisolated {match.group(2) or ''}{match.group(3)}",
        content,
        flags=re.MULTILINE
    )

    # 4b. Generated initializers and helpers must be explicitly nonisolated.
    content = re.sub(
        r'^(\s*)(?!nonisolated\b)((?:(?:open|public|private|fileprivate|internal|override|final)\s+)*)((?:static|class)\s+)?func\s',
        lambda match: f"{match.group(1)}nonisolated {match.group(2) or ''}{match.group(3) or ''}func ",
        content,
        flags=re.MULTILINE
    )
    content = re.sub(
        r'^(\s*)(?!nonisolated\b)((?:(?:required|convenience|override|public|private|fileprivate|internal)\s+)*)init\b',
        lambda match: f"{match.group(1)}nonisolated {match.group(2) or ''}init",
        content,
        flags=re.MULTILINE
    )

    # 4c. UniFFI handle maps are internally locked and need an explicit
    # unchecked Sendable conformance so nonisolated globals can store them.
    content = re.sub(
        r'^nonisolated fileprivate class UniffiHandleMap<([^>]+)> \{$',
        r'nonisolated fileprivate final class UniffiHandleMap<\1>: @unchecked Sendable {',
        content,
        flags=re.MULTILINE
    )

    # 4d. Mutable static globals inside generated types also need explicit
    # nonisolated(unsafe) under the app's default MainActor isolation.
    content = re.sub(
        r'^(\s*)(?!nonisolated(?:\(unsafe\))?\b)((?:(?:public|private|fileprivate|internal)\s+)*)static var\b',
        lambda match: f"{match.group(1)}nonisolated(unsafe) {match.group(2) or ''}static var",
        content,
        flags=re.MULTILINE
    )

    # 4e. Top-level constants and mutable globals must be explicitly marked so
    # nonisolated helpers can reference them.
    content = re.sub(
        r'^(?!\s)(?!nonisolated\b)((?:public|private|fileprivate|internal)\s+)?let\b',
        lambda match: f"nonisolated {match.group(1) or ''}let",
        content,
        flags=re.MULTILINE
    )
    content = re.sub(
        r'^(?!\s)(?!nonisolated(?:\(unsafe\))?\b)((?:public|private|fileprivate|internal)\s+)?var\b',
        lambda match: f"nonisolated(unsafe) {match.group(1) or ''}var",
        content,
        flags=re.MULTILINE
    )

    # 4f. UniFFI already emits Sendable extensions for these value types.
    # Older patcher revisions also added inline Sendable conformances, which
    # produced redundant-conformance warnings in MAS builds. Keep the generated
    # extension as the single conformance source and clean already-patched files
    # idempotently.
    for type_name in (
        "AgentConfigFfi",
        "ToolConfig",
        "ReasoningTrajectoryMetricsFfi",
        "AgentResultFfi",
    ):
        if re.search(rf'^nonisolated extension {type_name}: Sendable \{{\}}$', content, flags=re.MULTILINE):
            content = re.sub(
                rf'^nonisolated public struct {type_name}: Sendable \{{$',
                f'nonisolated public struct {type_name} {{',
                content,
                flags=re.MULTILINE
            )

    if free_v1:
        content = neutralize_free_v1_runtime_kind(content)

    with open(path, 'w') as f:
        f.write(content)

if __name__ == '__main__':
    free_v1 = '--free-v1' in sys.argv[1:]
    paths = [argument for argument in sys.argv[1:] if argument != '--free-v1']
    if not paths:
        raise SystemExit('usage: patch-uniffi-bindings.py [--free-v1] PATH...')
    for path in paths:
        patch_file(path, free_v1=free_v1)
        print(f'Patched: {path}')
