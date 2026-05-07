#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d /tmp/epistemos-metal-compile.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

shader_roots=(
  "$repo_root/Epistemos/Shaders"
  "$repo_root/agent_core/metal"
)

# HELIOS-V6-TARGET-ONLY-KERNEL-GUARD
#
# V6.1/V6.2 names these as canonical kernel targets, not as shipped
# implementations. If one appears in a compiled shader root, the kernel
# and its M2 Pro falsifier must be promoted together instead of letting
# this broad compile smoke test quietly bless it as complete.
target_only_kernels=(
  "SemiseparableBlockScan.metal"
  "LocalRecallIsland.metal"
  "PageGather.metal"
  "ControllerKernelPack.metal"
  "PacketRouter1bit.metal"
  "InterruptScore.metal"
)

for shader_root in "${shader_roots[@]}"; do
  for kernel in "${target_only_kernels[@]}"; do
    candidate="$shader_root/$kernel"
    if [[ -e "$candidate" ]]; then
      rel="${candidate#"$repo_root/"}"
      echo "FAIL $rel is V6.1/V6.2 target-only until its real kernel and M2 Pro falsifier are promoted together"
      exit 1
    fi
  done
done

shaders=()
while IFS= read -r shader; do
  shaders+=("$shader")
done < <(find "${shader_roots[@]}" -type f -name '*.metal' | sort)

if [[ "${#shaders[@]}" -eq 0 ]]; then
  echo "FAIL no Metal shaders found"
  exit 1
fi

for shader in "${shaders[@]}"; do
  rel="${shader#"$repo_root/"}"
  out="$tmpdir/${rel//[\/ ]/__}.air"
  xcrun -sdk macosx metal -std=metal3.1 -c "$shader" -o "$out" >/dev/null
  echo "PASS $rel"
done

echo "OK ${#shaders[@]} Metal shaders compile"
