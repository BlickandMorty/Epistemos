#!/bin/zsh

set +e

backup_root=/Volumes/treasure
core_script="$backup_root/create-epistemos-codex-restore-backup.zsh"

if [[ ! -x "$core_script" ]]; then
  print -u2 "Backup script missing: $core_script"
  print "Press Return to close this window."
  read -r
  exit 1
fi

"$core_script"
exit_code=$?

if (( exit_code == 0 )); then
  print "Backup completed and verified."
else
  print -u2 "Backup did not run or did not verify (exit code $exit_code)."
fi

print "Press Return to close this window."
read -r
exit "$exit_code"
