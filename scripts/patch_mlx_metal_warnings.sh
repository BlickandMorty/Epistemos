#!/bin/bash
set -euo pipefail

if [[ "${EPISTEMOS_PATCH_MLX_METAL_WARNINGS:-1}" == "0" ]]; then
  exit 0
fi

readonly relative_path="Source/Cmlx/mlx-generated/metal/steel/attn/kernels/steel_attention.metal"
readonly jit_relative_path="Source/Cmlx/mlx/mlx/backend/cpu/jit_compiler.cpp"
readonly warning_flag="-Wc++17-extensions"
readonly jit_disabled_marker="Epistemos patch: MLX CPU JIT disabled."

candidate_files=()
candidate_jit_files=()
candidate_swiftlint_plugin_roots=()

add_candidate_checkout_dir() {
  local checkout_dir="$1"
  if [[ -n "${checkout_dir}" ]]; then
    candidate_files+=("${checkout_dir}/mlx-swift/${relative_path}")
    candidate_jit_files+=("${checkout_dir}/mlx-swift/${jit_relative_path}")
  fi
}

add_candidate_root() {
  local root="$1"
  if [[ -n "${root}" && "${root}" != "/" ]]; then
    add_candidate_checkout_dir "${root}/SourcePackages/checkouts"
    candidate_swiftlint_plugin_roots+=("${root}/Build/Intermediates.noindex/BuildToolPluginIntermediates")
  fi
}

add_build_dir_candidate() {
  local suffix="$1"
  local root
  root="$(cd "${BUILD_DIR}/${suffix}" 2>/dev/null && pwd -P || true)"
  add_candidate_root "${root}"
}

if [[ -n "${BUILD_DIR:-}" ]]; then
  add_candidate_root "${BUILD_DIR}"
  if [[ "${BUILD_DIR}" != "/" ]]; then
    candidate_swiftlint_plugin_roots+=("${BUILD_DIR}/../Intermediates.noindex/BuildToolPluginIntermediates")
  fi
  add_build_dir_candidate "../.."
  add_build_dir_candidate "../../.."
fi

if [[ -n "${EPISTEMOS_CLONED_SOURCE_PACKAGES_DIR:-}" ]]; then
  cloned_root="$(cd "${EPISTEMOS_CLONED_SOURCE_PACKAGES_DIR}" 2>/dev/null && pwd -P || true)"
  if [[ -n "${cloned_root}" ]]; then
    add_candidate_checkout_dir "${cloned_root}/checkouts"
    add_candidate_checkout_dir "${cloned_root}"
  fi
fi

while IFS= read -r file; do
  candidate_files+=("${file}")
done < <(/usr/bin/find "${HOME}/Library/Developer/Xcode/DerivedData" \
  -path "*/SourcePackages/checkouts/mlx-swift/${relative_path}" \
  -print 2>/dev/null || true)

while IFS= read -r file; do
  candidate_jit_files+=("${file}")
done < <(/usr/bin/find "${HOME}/Library/Developer/Xcode/DerivedData" \
  -path "*/SourcePackages/checkouts/mlx-swift/${jit_relative_path}" \
  -print 2>/dev/null || true)

patch_file() {
  local file="$1"
  local tmp

  [[ -f "${file}" ]] || return 1

  if /usr/bin/grep -Fq -- "${warning_flag}" "${file}"; then
    return 0
  fi

  /bin/chmod u+w "${file}" 2>/dev/null || true
  tmp="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/mlx-metal-warning.XXXXXX")"

  if /usr/bin/awk '
    BEGIN { inserted = 0 }
    {
      print
      if (inserted == 0 && $0 == "// clang-format off") {
        print "#pragma clang diagnostic push"
        print "#pragma clang diagnostic ignored \"-Wc++17-extensions\""
        inserted = 1
        next
      }
      if (inserted == 1 && $0 == "#include \"../../../steel/attn/kernels/steel_attention.h\"") {
        print "#pragma clang diagnostic pop"
        inserted = 2
      }
    }
    END { if (inserted != 2) exit 42 }
  ' "${file}" > "${tmp}"; then
    /bin/cp "${tmp}" "${file}"
    /bin/rm -f "${tmp}"
    echo "Patched MLX Metal warning: ${file}"
    return 0
  fi

  /bin/rm -f "${tmp}"
  echo "warning: could not patch MLX Metal warning in ${file}" >&2
  return 1
}

patch_jit_file() {
  local file="$1"
  local tmp

  [[ -f "${file}" ]] || return 1

  if /usr/bin/grep -Fq -- "${jit_disabled_marker}" "${file}"; then
    return 0
  fi

  if ! /usr/bin/grep -Fq -- "FILE* pipe = popen" "${file}"; then
    return 1
  fi

  /bin/chmod u+w "${file}" 2>/dev/null || true
  tmp="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/mlx-cpu-jit.XXXXXX")"

  if /usr/bin/awk -v marker="${jit_disabled_marker}" '
    BEGIN { in_exec = 0; saw_return = 0; replaced = 0 }
    $0 == "std::string JitCompiler::exec(const std::string& cmd) {" {
      print "std::string JitCompiler::exec(const std::string& cmd) {"
      print "  (void)cmd;"
      print "  throw std::runtime_error(\"" marker "\");"
      print "}"
      in_exec = 1
      replaced = 1
      next
    }
    in_exec == 1 {
      if ($0 == "  return ret;") {
        saw_return = 1
        next
      }
      if (saw_return == 1 && $0 == "}") {
        in_exec = 0
        saw_return = 0
      }
      next
    }
    { print }
    END { if (replaced != 1 || in_exec != 0) exit 42 }
  ' "${file}" > "${tmp}"; then
    /bin/cp "${tmp}" "${file}"
    /bin/rm -f "${tmp}"
    echo "Patched MLX CPU JIT shell helper: ${file}"
    return 0
  fi

  /bin/rm -f "${tmp}"
  echo "warning: could not patch MLX CPU JIT shell helper in ${file}" >&2
  return 1
}

prepare_swiftlint_plugin_output_dirs() {
  local root="$1"
  local target

  [[ -n "${root}" ]] || return 1
  for target in \
    "codeeditsourceeditor.output/CodeEditSourceEditor" \
    "codeeditsourceeditor.output/CodeEditSourceEditorTests" \
    "codeedittextview.output/CodeEditTextView" \
    "codeedittextview.output/CodeEditTextViewTests"
  do
    /bin/mkdir -p "${root}/${target}/SwiftLint/Output"
  done
}

patched_any=0
while IFS= read -r file; do
  if patch_file "${file}"; then
    patched_any=1
  fi
done < <(/usr/bin/printf '%s\n' "${candidate_files[@]}" | /usr/bin/sort -u)

while IFS= read -r file; do
  if patch_jit_file "${file}"; then
    patched_any=1
  fi
done < <(/usr/bin/printf '%s\n' "${candidate_jit_files[@]}" | /usr/bin/sort -u)

while IFS= read -r root; do
  if prepare_swiftlint_plugin_output_dirs "${root}"; then
    patched_any=1
  fi
done < <(/usr/bin/printf '%s\n' "${candidate_swiftlint_plugin_roots[@]}" | /usr/bin/sort -u)

if [[ "${patched_any}" == "0" ]]; then
  echo "MLX Metal warning patch: no mlx-swift checkout found yet"
fi
