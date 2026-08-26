# Amazon Q pre block. Keep at the top of this file.
# 一時的にコメントアウト（Ghosttyのパフォーマンス問題調査のため）
# [[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# GOPATH
export GOPATH="$HOME/go"

# Starship: 非interactive環境での "can't change option: zle" エラーを防ぐ
if [[ -o interactive ]]; then
  eval "$(starship init zsh)"
fi

# Starshipのトグル機能 ターミナルでtoggle_starshipコマンドを実行することで、Starshipプロンプトの表示をオン/オフできるようになります。わいわい
function toggle_starship() {
  if [[ -z $STARSHIP_DISABLED ]]; then
    export STARSHIP_DISABLED=1
    export OLDPS1=$PS1
    export PS1='$ '
    echo "Starship無効化"
  else
    unset STARSHIP_DISABLED
    export PS1=$OLDPS1
    echo "Starship再有効化"
  fi
}

# PATH設定
export PATH="$HOME/.local/bin:$HOME/.bin:$HOME/.deno/bin:$GOPATH/bin:$PATH"
export PATH="/opt/homebrew/opt/ripgrep/bin:$PATH"

# volta（使用しない）
# export VOLTA_HOME="$HOME/.volta"
# export PATH="$VOLTA_HOME/bin:$PATH"

# HSTR
alias hh="hstr"
setopt histignorespace
export HSTR_CONFIG="hicolor"
bindkey -s "\C-r" "\C-a hstr -- \C-j"
export HSTR_TIOCSTI="y"

# 機密情報
if [ -f "$HOME/.env" ]; then
  set -a
  source "$HOME/.env"
  set +a
fi

# herdr: pane を他タブへ移動 (fzf で pane → タブの順に選択)
# - ~/.env の変数には依存しない。HERDR_* は herdr が pane ごとに注入するものを使う
# - herdr pane の外では no-op
# - 引数で pane_id を渡すと pane 選択をスキップ
# - タブ選択で「+ new tab」を選ぶと新規タブを作って移動
mvp() {
  [[ "${HERDR_ENV:-}" != "1" ]] && { echo "mvp: not in herdr" >&2; return 1; }
  local pane="$1" choice tab label
  if [[ "$pane" == "-n" ]]; then
    # mvp -n [label]: 今いる pane を新規タブへ即移動
    label="$2"
    pane="$(herdr pane current --current | jq -r .result.pane.pane_id)"
    if [[ -n "$label" ]]; then
      herdr pane move "$pane" --new-tab --label "$label"
    else
      herdr pane move "$pane" --new-tab
    fi
    return
  fi
  if [[ -z "$pane" ]]; then
    pane="$(herdr pane list --workspace "$HERDR_WORKSPACE_ID" | jq -r '.result.panes[] | [.pane_id, ((.label // "") + (if .agent then " [" + .agent + "]" else "" end)), (.tab_id // "")] | @tsv' \
      | fzf --prompt='move pane> ' --with-nth 2,3 --delimiter $'\t' --header 'label [agent]  tab' --layout=reverse-list \
          --preview 'herdr pane read {1} --source recent-unwrapped --lines 12 2>/dev/null' | cut -f1)"
  fi
  [[ -z "$pane" ]] && return 1
  choice="$({ printf '+ new tab\t__NEW__\n'; herdr tab list --workspace "$HERDR_WORKSPACE_ID" | jq -r '.result.tabs[] | "\(.label // "untitled")\t\(.tab_id)"' } \
    | fzf --prompt='move to tab> ' --with-nth 1 --delimiter $'\t' --layout=reverse-list --header 'Enter: 既存タブへ / + new tab: 新規タブ作成')"
  [[ -z "$choice" ]] && return 1
  if [[ "${choice#*$'\t'}" == "__NEW__" ]]; then
    read -r "label?new tab label (空なら自動命名): "
    if [[ -n "$label" ]]; then
      herdr pane move "$pane" --new-tab --label "$label"
    else
      herdr pane move "$pane" --new-tab
    fi
  else
    tab="${choice#*$'\t'}"
    herdr pane move "$pane" --tab "$tab" --split right
  fi
}

# zsh補完: bunや他のcompdef呼び出しより前にcompinitを初期化。
# キャッシュ(.zcompdump)が24時間以内なら-Cでセキュリティ監査をスキップして高速起動。
fpath=(~/.zfunc $fpath)
autoload -Uz compinit
if [[ -n ${HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# bun completions（PATH設定は.zshenvに移動済み）
[ -s "/Users/nagata/.bun/_bun" ] && source "/Users/nagata/.bun/_bun"

# avr-gcc@8: 存在しないパスのためコメントアウト
# export PATH="/usr/local/opt/avr-gcc@8/bin:$PATH"

# tmuxのアタッチまたは新規セッション作成スクリプト
# ~/.zsh/tmux-attach-or-new-session.shを作成しておくこと
# tを実行するとtmuxが起動する。セッションがなければ新規作成、あればアタッチする
[ -f /Users/nagata/.zsh/tmux-attach-or-new-session.sh ] && \
  source ~/.zsh/tmux-attach-or-new-session.sh

# ghq + gwq + try + fzf 統合ワークフロー
# - g     : ghq 配下を fzf で絞り込んで cd（本棚）
# - tryon : ghq の正本を選び、その上で try . で実験 worktree を切る
# - j     : ghq と ~/src/tries を横断する汎用 jump
# - gw/gwa/gwl/gwst : gwq の薄い alias（cd/add/list/status）
[ -f /Users/nagata/.zsh/ghq.sh ] && source ~/.zsh/ghq.sh

# VS Code統合ターミナルではTMUX変数をクリアしてから実行
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  alias t='(unset TMUX; tmux-attach-or-new-session)'
else
  alias t='tmux-attach-or-new-session'
fi

export PATH="$HOME/bin:$PATH"
# gh copilot alias: 遅延ロード化（初回使用時に初期化）
ghcs() { unset -f ghcs ghce; eval "$(gh copilot alias -- zsh)"; ghcs "$@"; }
ghce() { unset -f ghcs ghce; eval "$(gh copilot alias -- zsh)"; ghce "$@"; }

# miseを使ったNodeのバージョン管理（Homebrewより優先）
eval "$(/Users/nagata/.local/bin/mise activate zsh --shims)"

# Homebrewのnodeはアンインストール推奨（不要な場合）
# export PATH="/opt/homebrew/opt/node@22/bin:$PATH"

# グローバルNodeの設定（miseで管理するためコメントアウト）
# export PATH="/opt/homebrew/opt/node@22/bin:$PATH"

# Added by Windsurf
export PATH="/Users/nagata/.codeium/windsurf/bin:$PATH"

# fzf
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
export FZF_TMUX_OPTS="-p 80%"


# VS Code シェル統合
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  # code-insidersが存在するか確認
  if command -v code-insiders &> /dev/null; then
    . "$(code-insiders --locate-shell-integration-path zsh)"
  else
    . "$(code --locate-shell-integration-path zsh)"
  fi
fi

# デフォルトエディタ（herdr サーバー含むすべてのプロセスで使われる）。Zed を使う。
# --wait がないと呼び出し元が即終了扱いになり、herdr のスクロールバック編集などで
# 一時ファイルがエディタ起動前に削除されてしまう。
export EDITOR="micro"
export VISUAL="micro"
# 戻すときは zed --wait（--wait がないと呼び出し元が即終了扱いになり、
# herdr のスクロールバック編集などで一時ファイルがエディタ起動前に削除される）

# 軽量な nvim-minimal プロファイルを明示的に使いたいときの別名
# NVIM_APPNAME で切り替えることで、素の `nvim` コマンド（本体の LazyVim）とは
# 設定・プラグイン・lazy-lock を完全に分離する（`-u` だと stdpath('data') が
# 本体と共有されてしまい、lazy.nvim 導入時に競合するため env prefix 方式にした）
alias nvmin="env NVIM_APPNAME=nvim-minimal nvim"



# fzf: 非TTY環境でのzleエラーを抑制
if [[ -o interactive ]]; then
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
fi
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

eval "$(/Users/nagata/.local/share/mise/shims/ruby ~/.local/try.rb init ~/src/tries | sed 's|/usr/bin/env ruby|/Users/nagata/.local/share/mise/shims/ruby|g')"

# Amazon Q post block. Keep at the bottom of this file.
# 一時的にコメントアウト（Ghosttyのパフォーマンス問題調査のため）
# [[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"

# tryj: 使用していないためコメントアウト
# eval "$($HOME/.local/tryj init ~/src/tries)"

# Added by Antigravity
export PATH="/Users/nagata/.antigravity/antigravity/bin:$PATH"

# OpenCode Go API for Pi & LLM tools
export OPENAI_BASE_URL=https://opencode.ai/zen/go/v1

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<

# opencode
export PATH=/Users/nagata/.opencode/bin:$PATH

# ashiato 補完: 「open 」等と打って Ctrl-G → 日時順ファイルを選んで挿入
# （ashiato: 時間順ファイルピッカー。--files で fzf にデータソースを渡す）
ashiato-complete-widget() {
  local selected
  selected=$(ashiato . --files --format tsv 2>/dev/null | fzf --multi --delimiter $'\t' \
    --with-nth 1..2 --preview 'bat --color=always {3}' --header "$PWD" \
    --bind 'ctrl-a:select-all' --layout=reverse-list)
  if [[ -n "$selected" ]]; then
    local paths=("${(@f)selected}")
    paths=("${paths[@]##*$'\t'}")
    local rel
    for p in "${paths[@]}"; do
      rel="${p/#$PWD\//}"
      LBUFFER="${LBUFFER}${rel} "
    done
  fi
  zle reset-prompt
}
zle -N ashiato-complete-widget
bindkey '^G' ashiato-complete-widget
