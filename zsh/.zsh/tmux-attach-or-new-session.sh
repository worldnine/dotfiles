function tmux-attach-or-new-session() {
  local raw base session
  raw="${PWD##*/}"
  # 記号や空白を _ に
  session="$(printf '%s' "$raw" | tr -c 'A-Za-z0-9_-' '_')"

  if [ -n "$TMUX" ]; then
    # 既に tmux 内 → そのクライアントを対象セッションに切り替え
    tmux switch-client -t "$session" 2>/dev/null \
      || { tmux -u new-session -Ad -s "$session" -c "$PWD" && tmux switch-client -t "$session"; }
  else
    # tmux 外 → attach/new を一発（UTF-8モード強制）
    tmux -u new-session -As "$session" -c "$PWD"
  fi
}