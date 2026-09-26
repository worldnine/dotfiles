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
# (昇格済みの try は tries 側がシンボリックリンクになるので、それも拾う)
j() {
  local target tries_dir
  tries_dir="${TRY_PATH:-$HOME/src/tries}"
  target=$( {
    ghq list --full-path
    [ -d "$tries_dir" ] && find "$tries_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null
  } | fzf --prompt='jump> ' --preview 'ls -la {}/') || return
  cd "$target"
}

# tryup: 続けることにした try を ghq の本棚へ昇格する (実験部屋→本棚)
# - 引数なしなら今いる try、引数があればその try (名前かパス) が対象
# - origin があれば ghq と同じく URL から <host>/<owner>/<repo> を決める
# - origin がなければ owner を fzf で選ぶ (worldnine / infosign を先頭に、~/ghq/github.com の既存 owner も並べる。
#   一覧に無い owner は入力して Enter)。リポジトリ名の初期値は try 名から日付を外したもの
# - git 管理下でなければ git init する (ghq list や g に出すため)
# - tries 側にはシンボリックリンクを残す (try の Ctrl-G と同じ。try の一覧や j から辿れる)
# - gh repo create は外部に公開する操作なので実行せず、コマンドを表示するだけ
# - tryon で作った worktree は mv すると壊れるので対象外 (try の Ctrl-G か gwq を使う)
tryup() {
  local tries_dir src name url rel owner repo dest here back
  tries_dir="${${TRY_PATH:-$HOME/src/tries}:A}"
  if [[ -n "$1" && "$1" != . ]]; then
    src="$tries_dir/${${1%/}:t}"
  else
    [[ ${PWD:A} == $tries_dir/* ]] || { echo "tryup: try の中で実行するか、try を引数で指定してください" >&2; return 1; }
    here=${${PWD:A}#$tries_dir/}
    src="$tries_dir/${here%%/*}"
  fi
  name=${src:t}
  if [[ -L $src ]]; then
    echo "tryup: $name は昇格済みです (→ ${src:A})" >&2; return 1
  elif [[ ! -d $src ]]; then
    echo "tryup: try が見つかりません: $src" >&2; return 1
  elif [[ -f $src/.git ]]; then
    echo "tryup: $name は worktree なので対象外です (try の Ctrl-G か gwq を使ってください)" >&2; return 1
  fi

  url=$(git -C "$src" remote get-url origin 2>/dev/null)
  if [[ -n $url ]]; then
    # git@github.com:o/r.git / https://github.com/o/r / ssh://git@github.com/o/r.git → github.com/o/r
    rel=${${url%.git}#*://}
    rel=${rel#*@}
    rel=${rel/://}
  else
    owner=$( { print -l worldnine infosign; ls -1 "$(ghq root)/github.com" 2>/dev/null } | awk '!seen[$0]++' \
      | fzf --prompt='owner> ' --header="github.com/<owner> を選択 (一覧に無ければ入力して Enter)" \
          --bind 'enter:accept-or-print-query' --layout=reverse-list) || return 1
    [[ -n $owner && $owner != */* ]] || { echo "tryup: owner が不正です: $owner" >&2; return 1; }
    repo=${name#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-}
    vared -p "repo name: github.com/$owner/" repo || return 1
    [[ -n $repo && $repo != */* ]] || { echo "tryup: リポジトリ名が不正です: $repo" >&2; return 1; }
    rel="github.com/$owner/$repo"
  fi
  dest="$(ghq root)/$rel"
  [[ -e $dest ]] && { echo "tryup: 移動先がすでにあります: $dest" >&2; return 1; }

  print -r -- "昇格: $src"
  print -r -- "  → $dest"
  read -q "?実行しますか? [y/N] " || { echo; return 1; }
  echo

  [[ -e $src/.git ]] || git -C "$src" init -q || return 1
  # 今いる場所が昇格する try の中なら、移動後も同じ位置へ cd し直す
  here=${PWD:A}
  [[ $here == $src || $here == $src/* ]] && back=$dest${here#$src}
  mkdir -p "${dest:h}" && mv "$src" "$dest" && ln -s "$dest" "$src" || return 1
  [[ -n $back ]] && cd "$back"
  print -r -- "昇格しました: $dest"
  if [[ -z $url ]]; then
    print -r -- "GitHub に上げるなら (公開範囲を確認してから実行):"
    print -r -- "  gh repo create $owner/$repo --private --source ${(q)dest} --remote origin"
  fi
}

# gwq が入っていれば薄いショートカットを生やす
if command -v gwq &>/dev/null; then
  alias gw='gwq cd'    # worktree に cd (fzf統合は gwq 純正)
  alias gwa='gwq add'  # worktree 作成
  alias gwl='gwq list' # 一覧
  alias gwst='gwq status' # ステータスダッシュボード（gws は Google Workspace CLI と衝突するため gwst）
fi
