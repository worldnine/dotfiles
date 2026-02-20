#!/usr/bin/env bash
# Minimal git status summary for tmux status line.
# Usage: git-statusline.sh [PATH]

set -uo pipefail

path_input=${1:-$PWD}

# Resolve to absolute path to avoid surprises with '..'
if ! repo_path=$(cd "$path_input" 2>/dev/null && pwd); then
  exit 0
fi

# Check if inside a git work tree
if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$branch" = "HEAD" ] || [ -z "$branch" ]; then
  branch=$(git -C "$repo_path" rev-parse --short HEAD 2>/dev/null)
fi

root_path=$(git -C "$repo_path" rev-parse --show-toplevel 2>/dev/null)
common_dir=$(git -C "$repo_path" rev-parse --git-common-dir 2>/dev/null)
actual_git_dir=$(git -C "$repo_path" rev-parse --git-dir 2>/dev/null)

worktree_prefix=""
if [ -n "$common_dir" ] && [ -n "$actual_git_dir" ] && [ "$common_dir" != "$actual_git_dir" ]; then
  worktree_prefix="[WT]"
fi

upstream_segment=""
if git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  read -r behind ahead < <(git -C "$repo_path" rev-list --left-right --count '@{u}'...HEAD 2>/dev/null || echo "0 0")
  if [ "${behind:-0}" -gt 0 ]; then
    upstream_segment+="↓$behind"
  fi
  if [ "${ahead:-0}" -gt 0 ]; then
    [ -n "$upstream_segment" ] && upstream_segment+=" "
    upstream_segment+="↑$ahead"
  fi
fi

parse_shortstat() {
  local output="$1"
  local insertions=0 deletions=0
  if [[ $output =~ ([0-9]+)[[:space:]]+insertion ]]; then
    insertions=${BASH_REMATCH[1]}
  fi
  if [[ $output =~ ([0-9]+)[[:space:]]+deletion ]]; then
    deletions=${BASH_REMATCH[1]}
  fi
  printf '%s %s' "$insertions" "$deletions"
}

read staged_insert staged_delete < <(
  parse_shortstat "$(git -C "$repo_path" diff --cached --shortstat 2>/dev/null)"
)
read unstaged_insert unstaged_delete < <(
  parse_shortstat "$(git -C "$repo_path" diff --shortstat 2>/dev/null)"
)

untracked=$(git -C "$repo_path" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

# 差分を合算（staged + unstaged）
total_insert=$((${staged_insert:-0} + ${unstaged_insert:-0}))
total_delete=$((${staged_delete:-0} + ${unstaged_delete:-0}))

segments=()

# ブランチ名（ワークツリーの場合はプレフィックス付き）
segments+=("${worktree_prefix}${branch}")

if [ -n "$upstream_segment" ]; then
  segments+=("$upstream_segment")
fi

# 差分表示（+X -Y 形式）
if [ "$total_insert" -gt 0 ] || [ "$total_delete" -gt 0 ]; then
  segments+=("+$total_insert -$total_delete")
fi

if [ "${untracked:-0}" -gt 0 ]; then
  segments+=("?:$untracked")
fi

printf '%s' "${segments[*]}"
