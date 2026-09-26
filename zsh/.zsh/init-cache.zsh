# init 系コマンドの出力をファイルにキャッシュする（起動のたびに外部コマンドを叩かないため）。
# 使い方: _zsh_init_cache <名前> <依存ファイル> <コマンド文字列> && source $REPLY
# - 依存ファイルの実体（シンボリックリンクの解決先）が変わるか、キャッシュより新しくなったら作り直す
#   （brew upgrade で Cellar のバージョンが変わった場合も拾える）。コマンド文字列を変えた場合も作り直す
# - 依存ファイルが無ければ失敗を返す（呼び出し側は source しない）
# - source は呼び出し側で行う（関数内で source すると typeset や setopt が関数スコープに閉じるため）
# - 手動で作り直すときは rm -rf ~/.cache/zsh-init
_zsh_init_cache() {
  setopt local_options pipe_fail
  local dep=${2:A} stamp tmp want
  REPLY=${XDG_CACHE_HOME:-$HOME/.cache}/zsh-init/$1.zsh
  [[ -e $dep ]] || return 1
  want="# dep: $dep | cmd: ${3//$'\n'/ }"
  [[ -s $REPLY ]] && read -r stamp < $REPLY
  [[ $stamp == "$want" && ! $dep -nt $REPLY ]] && return 0
  # herdr の復元などでシェルが同時に起動しても壊れないよう、一時ファイルに書いてから mv する
  mkdir -p ${REPLY:h}
  tmp=$REPLY.$$.tmp
  if ! { print -r -- $want; eval "$3" } >| $tmp; then
    rm -f $tmp
    return 1
  fi
  mv -f $tmp $REPLY
}
