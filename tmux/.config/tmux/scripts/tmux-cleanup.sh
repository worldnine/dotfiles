#!/usr/bin/env bash
# tmux セッション & resurrect ファイルの自動クリーンアップ
#
# - 一定日数操作のないセッションを自動 kill
# - 古い resurrect 保存ファイルを削除（最新N個を保持）

set -euo pipefail

# --- 設定 ---
INACTIVE_DAYS="${TMUX_CLEANUP_INACTIVE_DAYS:-7}"       # 非アクティブセッションの閾値（日数）
KEEP_RESURRECT="${TMUX_CLEANUP_KEEP_RESURRECT:-5}"     # 保持する resurrect ファイル数
RESURRECT_DIR="${HOME}/.local/share/tmux/resurrect"

# --- 非アクティブセッションの自動キル ---
cleanup_sessions() {
  # tmux サーバーが起動していなければスキップ
  tmux list-sessions >/dev/null 2>&1 || return 0

  local threshold
  threshold=$(( $(date +%s) - INACTIVE_DAYS * 86400 ))

  tmux list-sessions -F '#{session_name} #{session_activity}' | while read -r name activity; do
    if [ "$activity" -lt "$threshold" ]; then
      echo "tmux-cleanup: セッション '$name' を終了（${INACTIVE_DAYS}日以上非アクティブ）"
      tmux kill-session -t "$name"
    fi
  done
}

# --- 古い resurrect ファイルの削除 ---
cleanup_resurrect_files() {
  [ -d "$RESURRECT_DIR" ] || return 0

  local count
  count=$(find "$RESURRECT_DIR" -name 'tmux_resurrect_*.txt' -type f | wc -l | tr -d ' ')

  if [ "$count" -le "$KEEP_RESURRECT" ]; then
    return 0
  fi

  echo "tmux-cleanup: resurrect ファイルを整理（${count}個 → 最新${KEEP_RESURRECT}個を保持）"
  ls -t "$RESURRECT_DIR"/tmux_resurrect_*.txt | tail -n +"$(( KEEP_RESURRECT + 1 ))" | xargs rm -f

  # last シンボリックリンクが壊れていたら修正
  local last_link="$RESURRECT_DIR/last"
  if [ -L "$last_link" ] && [ ! -e "$last_link" ]; then
    local newest
    newest=$(ls -t "$RESURRECT_DIR"/tmux_resurrect_*.txt 2>/dev/null | head -1)
    if [ -n "$newest" ]; then
      ln -sf "$(basename "$newest")" "$last_link"
      echo "tmux-cleanup: last リンクを再設定 → $(basename "$newest")"
    fi
  fi
}

# --- メイン ---
cleanup_sessions
cleanup_resurrect_files
