#!/usr/bin/env zsh
# Simple non-interactive test harness for zsh-vi-mode modularized loader
# Exits with status 0 on success, non-zero if any required function is missing.

set -euo pipefail

ZVM_ROOT="${0:A:h}/.."
# Source loader (safe guard for interactive prompts)
if [[ -f "$ZVM_ROOT/lib/loader.zsh" ]]; then
  source "$ZVM_ROOT/lib/loader.zsh"
else
  echo "ERROR: loader.zsh not found at $ZVM_ROOT/lib/loader.zsh"
  exit 2
fi

# List of functions we expect to exist after loading modules
required_funcs=(
  zvm_init
  zvm_open_under_cursor
  zvm_is_url
  zvm_is_path
  zvm_vi_edit_command_line
  zvm_highlight
  zvm_clipboard_copy_buffer
  zvm_change_surround
  zvm_switch_keyword
)

missing=()
for f in "${required_funcs[@]}"; do
  if ! command -v "$f" >/dev/null 2>&1; then
    missing+=("$f")
  fi
done

if (( ${#missing[@]} )); then
  echo "MISSING FUNCTIONS: ${missing[*]}"
  exit 3
fi

echo "ALL CHECKS: OK"
exit 0
