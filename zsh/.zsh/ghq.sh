#!/usr/bin/env zsh
# ghq + gwq + try + fzf の統合ワークフロー
#
# 役割分担:
#   - try : 実験部屋 (GitHubに上げないスクラッチ; date-prefixed)
#   - ghq : 本棚     (正本クローン; URL正本)
#   - gwq : 並列作業机 (worktree; 機能ブランチ・AIエージェント並列)
#   - fzf : 全層共通の絞り込みUI
#
# このファイルで足すのは ghq/try の間を埋める関数のみ。
# gwq は純正コマンドが強力なので alias 経由で薄く呼ぶ。

# g: ghq 配下を fzf で絞り込んで cd (本棚を引く)
g() {
  local dir
  dir=$(ghq list --full-path | fzf --prompt='ghq> ' --preview 'ls -la {}') || return
  cd "$dir"
}

# tryon: ghq の正本を選び、その上で try . で実験 worktree を切る
# (本棚→実験部屋。既存ライブラリを使って何か試したい時)
tryon() {
  local repo dir
  repo=$(ghq list | fzf --prompt='tryon> ') || return
  dir="$(ghq root)/$repo"
  cd "$dir" || return
  try . "$@"
}

# j: ghq の正本と ~/src/tries の実験を横断する汎用 jump
j() {
  local target tries_dir
  tries_dir="${TRY_PATH:-$HOME/src/tries}"
  target=$( {
    ghq list --full-path
    [ -d "$tries_dir" ] && find "$tries_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
  } | fzf --prompt='jump> ' --preview 'ls -la {}') || return
  cd "$target"
}

# gwq が入っていれば薄いショートカットを生やす
if command -v gwq &>/dev/null; then
  alias gw='gwq cd'    # worktree に cd (fzf統合は gwq 純正)
  alias gwa='gwq add'  # worktree 作成
  alias gwl='gwq list' # 一覧
  alias gws='gwq status' # ステータスダッシュボード
fi
