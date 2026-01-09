# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"
# Amazon Q pre block. Keep at the top of this file.
# 一時的にコメントアウト（Ghosttyのパフォーマンス問題調査のため）
# [[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# GOPATH
export GOPATH="$HOME/go"

# Starship
eval "$(starship init zsh)"

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
export PATH="$HOME/.bin:$HOME/.deno/bin:$GOPATH/bin:$PATH"
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

# bun completions
[ -s "/Users/nagata/.bun/_bun" ] && source "/Users/nagata/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# avr-gccのバージョンを固定
export PATH="/usr/local/opt/avr-gcc@8/bin:$PATH"

# tmuxのアタッチまたは新規セッション作成スクリプト
# ~/.zsh/tmux-attach-or-new-session.shを作成しておくこと
# tを実行するとtmuxが起動する。セッションがなければ新規作成、あればアタッチする
[ -f /Users/nagata/.zsh/tmux-attach-or-new-session.sh ] && \
  source ~/.zsh/tmux-attach-or-new-session.sh

# VS Code統合ターミナルではTMUX変数をクリアしてから実行
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  alias t='(unset TMUX; tmux-attach-or-new-session)'
else
  alias t='tmux-attach-or-new-session'
fi

export PATH="$HOME/bin:$PATH"
eval "$(gh copilot alias -- zsh)"

# miseを使ったNodeのバージョン管理（Homebrewより優先）
eval "$(/Users/nagata/.local/bin/mise activate zsh)"

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

export EDITOR="/usr/local/bin/code --wait"
export VISUAL="/usr/local/bin/code --wait"


[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

eval "$(ruby ~/.local/try.rb init ~/src/tries)"

# Amazon Q post block. Keep at the bottom of this file.
# 一時的にコメントアウト（Ghosttyのパフォーマンス問題調査のため）
# [[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"

# tryj (LLM連携版try)
eval "$($HOME/.local/tryj init ~/src/tries)"

# Added by Antigravity
export PATH="/Users/nagata/.antigravity/antigravity/bin:$PATH"

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
