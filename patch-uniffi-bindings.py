#!/usr/bin/env python3
"""Patch UniFFI-generated Swift for SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.

Only four fixes needed:
1. pointer property -> nonisolated(unsafe) (deinit accesses it from nonisolated context)
2. deinit body -> keep direct rustCall now that generated helpers are nonisolated,
   and snapshot the object pointer into a nonisolated(unsafe) local before free
3. errorDescription -> nonisolated (generated LocalizedError conformances are otherwise main-actor isolated)
4. declarations -> nonisolated/nonisolated(unsafe) so generated wrappers compile under Swift 6 default MainActor isolation
"""

import sys
import re

def patch_file(path):
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

    with open(path, 'w') as f:
        f.write(content)

if __name__ == '__main__':
    for path in sys.argv[1:]:
        patch_file(path)
        print(f'Patched: {path}')
