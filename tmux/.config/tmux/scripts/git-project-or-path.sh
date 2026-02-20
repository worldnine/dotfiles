#!/usr/bin/env bash
set -uo pipefail

path_input=${1:-$PWD}
if ! abs_path=$(cd "$path_input" 2>/dev/null && pwd -P); then
  exit 0
fi

repo_root=$(git -C "$abs_path" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$repo_root" ]; then
  printf '%s' "${repo_root##*/}"
  exit 0
fi

if [ -n "${HOME:-}" ] && [ "${abs_path#"$HOME"}" != "$abs_path" ]; then
  printf '~%s' "${abs_path#"$HOME"}"
else
  printf '%s' "$abs_path"
fi
