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

# zsh補完: bunや他のcompdef呼び出しより前にcompinitを初期化。
# キャッシュ(.zcompdump)が24時間以内なら-Cでセキュリティ監査をスキップして高速起動。
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

# デフォルトエディタ（herdr サーバー含むすべてのプロセスで使われる）
export EDITOR="nvim -u ~/.config/nvim-minimal/init.lua"
export VISUAL="nvim -u ~/.config/nvim-minimal/init.lua"

# herdr 内では TUI エディタを使う（prefix+e でのスクロールバック表示用）
# -> デフォルトを nvim-minimal にしたのでこの分岐は不要。コードは残しておく
if [[ -n "$HERDR_ENV" ]]; then
  export EDITOR="nvim -u ~/.config/nvim-minimal/init.lua"
  export VISUAL="nvim -u ~/.config/nvim-minimal/init.lua"
else
  export EDITOR="nvim -u ~/.config/nvim-minimal/init.lua"
  export VISUAL="nvim -u ~/.config/nvim-minimal/init.lua"
fi



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
