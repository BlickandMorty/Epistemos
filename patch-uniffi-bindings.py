#!/usr/bin/env python3
"""Patch UniFFI-generated Swift for SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.

Only two fixes needed:
1. pointer property -> nonisolated(unsafe) (deinit accesses it from nonisolated context)
2. deinit body -> wrapped in MainActor.assumeIsolated (calls @MainActor rustCall)
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

    # 2. Wrap deinit body in MainActor.assumeIsolated
    # Pattern: deinit { guard let pointer ... try! rustCall { uniffi_xxx_fn_free_xxx(pointer, $0) } }
    content = re.sub(
        r'(    deinit \{\n        guard let pointer = pointer else \{\n            return\n        \}\n\n)        (try! rustCall \{ .+? \})',
        r'\1        MainActor.assumeIsolated {\n            \2\n        }',
        content,
        flags=re.DOTALL
    )

    with open(path, 'w') as f:
        f.write(content)

if __name__ == '__main__':
    for path in sys.argv[1:]:
        patch_file(path)
        print(f'Patched: {path}')
