#!/bin/zsh

set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
if [[ -f "$script_dir/SHA256SUMS.txt" ]]; then
  backup_dir="$script_dir"
else
  backup_dirs=("$script_dir"/Epistemos-Codex-Restore-*(N/))
  (( ${#backup_dirs[@]} == 1 )) || {
    print -u2 "Place this script beside exactly one Epistemos-Codex-Restore backup folder."
    exit 1
  }
  backup_dir=${backup_dirs[1]%/}
fi

archive_paths=("$backup_dir"/*.tar(N))
(( ${#archive_paths[@]} == 1 )) || {
  print -u2 "Expected exactly one .tar archive in $backup_dir"
  exit 1
}
archive_path=$archive_paths[1]

require_closed() {
  local pattern
  for pattern in \
    'ChatGPT.app' \
    'Xcode.app/Contents/MacOS/Xcode' \
    'Simulator.app/Contents/MacOS/Simulator'; do
    if pgrep -f "$pattern" >/dev/null; then
      print -u2 "Quit ChatGPT/Codex, Xcode, and Simulator before restoring."
      exit 1
    fi
  done
}

require_closed
(
  cd "$backup_dir"
  shasum -a 256 -c SHA256SUMS.txt
)

print "This will replace the backed-up Codex, Epistemos, Xcode-user-data, and workspace paths under $HOME."
print "Your current copies will be moved to a timestamped rollback folder first."
read -r "confirmation?Type RESTORE to continue: "
[[ "$confirmation" == "RESTORE" ]] || {
  print "Restore cancelled."
  exit 1
}

stage_dir=$(mktemp -d "${TMPDIR:-/private/tmp}/Epistemos-Codex-Restore-Stage-XXXXXX")
rollback_dir="$HOME/Epistemos-Codex-Restore-Rollback-$(date +%Y%m%d-%H%M%S)"
cleanup() {
  [[ -d "$stage_dir" ]] && rm -rf -- "$stage_dir"
}
trap cleanup EXIT

print "Extracting to a temporary staging folder."
bsdtar -xpf "$archive_path" --directory="$stage_dir"

source_home="$stage_dir/Users/jojo"
[[ -d "$source_home" ]] || {
  print -u2 "Archive does not contain the expected user data."
  exit 1
}

relative_paths=(
  .codex
  .cache/codex-runtimes
  'Downloads/Epistemos'
  'Downloads/epistemos_mas_master_canon_2026_07_08'
  'Downloads/epistemos_mas_master_canon_2026_07_08.zip'
  'Downloads/epistemos_mas_low_ram_preparation_2026_07_11'
  'Library/Application Support/Codex'
  'Library/Application Support/com.openai.codex'
  'Library/Application Support/OpenAI'
  'Library/Application Support/com.openai.chat'
  'Library/Application Support/Epistemos'
  'Library/Application Support/Epistemos-Recovery'
  'Library/Application Support/com.epistemos.appstore'
  'Library/Caches/com.openai.chat'
  'Library/Caches/com.openai.codex'
  'Library/Caches/com.openai.sky.CUAService'
  'Library/Caches/com.openai.sky.CUAService.cli'
  'Library/Containers/com.openai.chat.Widgets'
  'Library/Containers/com.epistemos.appstore'
  'Library/Group Containers/2DC432GLL2.com.openai.codex.notifications'
  'Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService'
  'Library/Group Containers/group.com.openai.chat'
  'Library/Group Containers/group.com.epistemos.shared'
  'Library/Developer/Xcode/UserData'
  'Library/Developer/CoreSimulator'
  'Library/Preferences/com.apple.dt.Xcode.plist'
  'Library/Preferences/com.openai.chat.RemoteFeatureFlags.686f10c3-19f2-4702-90b8-6f5952d0bd99.plist'
  'Library/Preferences/com.openai.chat.StatsigService.plist'
  'Library/Preferences/com.openai.chat.plist'
  'Library/Preferences/com.openai.codex.plist'
  'Library/Preferences/com.openai.sky.CUAService.cli.plist'
  'Library/Preferences/com.openai.sky.CUAService.plist'
)

mkdir -p "$rollback_dir"
for relative_path in "${relative_paths[@]}"; do
  staged_path="$source_home/$relative_path"
  target_path="$HOME/$relative_path"
  rollback_path="$rollback_dir/$relative_path"
  [[ -e "$staged_path" ]] || continue
  mkdir -p "$(dirname "$rollback_path")" "$(dirname "$target_path")"
  [[ -e "$target_path" ]] && mv "$target_path" "$rollback_path"
  ditto "$staged_path" "$target_path"
done

if [[ -d "$stage_dir/Applications/ChatGPT.app" ]]; then
  mkdir -p "$rollback_dir/Applications"
  if [[ -d /Applications/ChatGPT.app ]]; then
    sudo mv /Applications/ChatGPT.app "$rollback_dir/Applications/ChatGPT.app"
  fi
  sudo ditto "$stage_dir/Applications/ChatGPT.app" /Applications/ChatGPT.app
fi

git -C "$HOME/Downloads/Epistemos" status -sb
print "Restore complete. Previous local data is at: $rollback_dir"
print "Sign in to ChatGPT/Codex and provision Apple signing credentials again if macOS requests it."
