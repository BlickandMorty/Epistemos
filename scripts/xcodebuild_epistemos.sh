#!/bin/bash
set -euo pipefail

# Transitive SwiftLint build-tool plugins in CodeEditSourceEditor/CodeEditTextView
# still fail under Xcode 16 after successful linting because their prebuild
# command declares an Output directory they never create. The plugin only honors
# DISABLE_SWIFTLINT when it is present in the process environment, not as an
# xcodebuild build setting.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_model_sweep_override_file="/tmp/epi-local-model-sweep-models.txt"
local_model_sweep_override_backup=""
cleanup_deriveddata_epistemos=0
main_invocation_is_package_resolution=0
main_invocation_is_test_like=0
result_bundle_path=""
extra_xcodebuild_args=()
derived_data_path=""
cloned_source_packages_path=""

argument_present() {
  local expected="$1"
  shift
  local arg
  for arg in "$@"; do
    if [[ "${arg}" == "${expected}" ]]; then
      return 0
    fi
  done
  return 1
}

append_default_xcodebuild_arg() {
  local expected="$1"
  shift
  if argument_present "${expected}" "$@"; then
    return 0
  fi
  extra_xcodebuild_args+=("${expected}")
}

cleanup_deriveddata_epistemos_processes() {
  local pids
  local still_running

  pids="$(
    ps -axo pid=,command= \
      | awk '/\/DerivedData\/.*\/Epistemos\.app\/Contents\/MacOS\/Epistemos([[:space:]]|$)/ { print $1 }' \
      | sort -u \
      | tr '\n' ' '
  )"
  if [[ -z "${pids// }" ]]; then
    return
  fi

  echo "Cleaning stale DerivedData Epistemos test app processes:${pids}" >&2
  # shellcheck disable=SC2086
  kill ${pids} 2>/dev/null || true

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    still_running=""
    for pid in ${pids}; do
      if kill -0 "${pid}" 2>/dev/null; then
        still_running="${still_running} ${pid}"
      fi
    done

    if [[ -z "${still_running// }" ]]; then
      return
    fi
    sleep 0.2
  done

  echo "Force-killing stale DerivedData Epistemos test app processes:${still_running}" >&2
  # shellcheck disable=SC2086
  kill -9 ${still_running} 2>/dev/null || true
}

cleanup_model_sweep_override() {
  if [[ "${local_model_sweep_override_backup}" == "__REMOVE__" ]]; then
    rm -f "${local_model_sweep_override_file}"
    return
  fi

  if [[ -n "${local_model_sweep_override_backup}" && -f "${local_model_sweep_override_backup}" ]]; then
    mv "${local_model_sweep_override_backup}" "${local_model_sweep_override_file}"
  fi
}

cleanup_xcodebuild_wrapper_state() {
  cleanup_model_sweep_override
  if [[ "${cleanup_deriveddata_epistemos}" == "1" ]]; then
    cleanup_deriveddata_epistemos_processes
  fi
}

resolve_package_dependencies() {
  local args=("$@")
  local resolve_args=()
  local has_package_scope=0
  local index=0

  while [[ "${index}" -lt "${#args[@]}" ]]; do
    local arg="${args[${index}]}"
    case "${arg}" in
      -project|-workspace)
        resolve_args+=("${arg}")
        has_package_scope=1
        index=$((index + 1))
        if [[ "${index}" -lt "${#args[@]}" ]]; then
          resolve_args+=("${args[${index}]}")
        fi
        ;;
      -scheme|-derivedDataPath|-clonedSourcePackagesDirPath|-packageCachePath)
        resolve_args+=("${arg}")
        index=$((index + 1))
        if [[ "${index}" -lt "${#args[@]}" ]]; then
          resolve_args+=("${args[${index}]}")
        fi
        ;;
      -disableAutomaticPackageResolution|-onlyUsePackageVersionsFromResolvedFile|-skipPackagePluginValidation)
        resolve_args+=("${arg}")
        ;;
    esac
    index=$((index + 1))
  done

  if [[ "${has_package_scope}" != "1" ]]; then
    return
  fi

  xcodebuild "${resolve_args[@]}" -resolvePackageDependencies
}

patch_mlx_package_checkouts() {
  local build_dir="${BUILD_DIR:-}"
  local source_packages_dir="${cloned_source_packages_path}"

  if [[ -n "${derived_data_path}" ]]; then
    build_dir="${derived_data_path}"
    if [[ -z "${source_packages_dir}" ]]; then
      source_packages_dir="${derived_data_path}/SourcePackages"
    fi
  fi

  BUILD_DIR="${build_dir}" \
    EPISTEMOS_CLONED_SOURCE_PACKAGES_DIR="${source_packages_dir}" \
    bash "${ROOT_DIR}/scripts/patch_mlx_metal_warnings.sh"
}

index=0
args=("$@")
while [[ "${index}" -lt "${#args[@]}" ]]; do
  case "${args[${index}]}" in
    -derivedDataPath)
      index=$((index + 1))
      if [[ "${index}" -lt "${#args[@]}" ]]; then
        derived_data_path="${args[${index}]}"
      fi
      ;;
    -clonedSourcePackagesDirPath)
      index=$((index + 1))
      if [[ "${index}" -lt "${#args[@]}" ]]; then
        cloned_source_packages_path="${args[${index}]}"
      fi
      ;;
  esac
  index=$((index + 1))
done

for arg in "$@"; do
  if [[ "${arg}" == "-resolvePackageDependencies" ]]; then
    main_invocation_is_package_resolution=1
  fi
  if [[ "${arg}" == "test" || "${arg}" == "build-for-testing" || "${arg}" == "test-without-building" ]]; then
    main_invocation_is_test_like=1
  fi
  if [[ "${arg}" == *"LocalModelReleaseSweepTests"* ]]; then
    cleanup_deriveddata_epistemos=1
  fi
done

if [[ -n "${EPI_LOCAL_MODEL_SWEEP_MODELS:-}" ]]; then
  cleanup_deriveddata_epistemos=1
  if [[ -f "${local_model_sweep_override_file}" ]]; then
    local_model_sweep_override_backup="$(mktemp /tmp/epi-local-model-sweep-models.backup.XXXXXX)"
    cp "${local_model_sweep_override_file}" "${local_model_sweep_override_backup}"
  else
    local_model_sweep_override_backup="__REMOVE__"
  fi
  printf '%s\n' "${EPI_LOCAL_MODEL_SWEEP_MODELS}" > "${local_model_sweep_override_file}"
fi

trap cleanup_xcodebuild_wrapper_state EXIT

if [[ "${cleanup_deriveddata_epistemos}" == "1" ]]; then
  cleanup_deriveddata_epistemos_processes
fi

export DISABLE_SWIFTLINT=1

if [[ "${main_invocation_is_package_resolution}" != "1" ]]; then
  append_default_xcodebuild_arg "-disableAutomaticPackageResolution" "$@"
  append_default_xcodebuild_arg "-onlyUsePackageVersionsFromResolvedFile" "$@"
  append_default_xcodebuild_arg "-skipPackagePluginValidation" "$@"
  append_default_xcodebuild_arg "-skipMacroValidation" "$@"
  append_default_xcodebuild_arg "-hideShellScriptEnvironment" "$@"
fi

if [[ "${main_invocation_is_test_like}" == "1" ]]; then
  if ! argument_present "-collect-test-diagnostics" "$@"; then
    extra_xcodebuild_args+=("-collect-test-diagnostics" "never")
  fi
fi

if [[ "${main_invocation_is_test_like}" == "1" ]] && ! argument_present "-resultBundlePath" "$@"; then
  mkdir -p "${ROOT_DIR}/build/xcode-results"
  result_bundle_path="${ROOT_DIR}/build/xcode-results/$(date +%F-%H%M%S)-$$.xcresult"
  rm -rf "${result_bundle_path}"
  extra_xcodebuild_args+=("-resultBundlePath" "${result_bundle_path}")
fi

if [[ "${main_invocation_is_package_resolution}" != "1" ]]; then
  resolve_package_dependencies "$@"
  patch_mlx_package_checkouts
fi

if [[ "${#extra_xcodebuild_args[@]}" -gt 0 ]]; then
  xcodebuild "$@" "${extra_xcodebuild_args[@]}"
else
  xcodebuild "$@"
fi
