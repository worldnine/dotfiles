# Amazon Q pre block. Keep at the top of this file.
# 一時的にコメントアウト（Ghosttyのパフォーマンス問題調査のため）
# [[ -f "${HOME}/Library/Application Support/amazon-q/shell/zprofile.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zprofile.pre.zsh"
emulate sh
source ~/.profile
emulate zsh

# brew shellenv は毎回約80msかかるので、出力をキャッシュして読む（~/.zsh/init-cache.zsh）。
# PATH が既に brew のパスで始まっていると何も出力しない仕様なので、クリーンな環境で生成する。
(( $+functions[_zsh_init_cache] )) || source ~/.zsh/init-cache.zsh
_zsh_init_cache brew-shellenv /opt/homebrew/Library/Homebrew/cmd/shellenv.sh \
  'env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin /opt/homebrew/bin/brew shellenv zsh' \
  && source $REPLY || eval "$(/opt/homebrew/bin/brew shellenv)"

# Python 3.11 PATH削除: miseで管理しているため不要
# PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:${PATH}"
# export PATH

# MAMP の PHP（php8.1.31 固定。最新版を探していた PHP_VERSION はどこでも使われていなかったので削除）
export PATH=/Applications/MAMP/bin/php/php8.1.31/bin:$PATH
# Add support for MYSQL
export PATH=/Applications/MAMP/Library/bin:$PATH

# mise shims は .zshenv で設定済み（全シェルタイプで有効にするため）

# Amazon Q post block. Keep at the bottom of this file.
# 一時的にコメントアウト（Ghosttyのパフォーマンス問題調査のため）
# [[ -f "${HOME}/Library/Application Support/amazon-q/shell/zprofile.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zprofile.post.zsh"
