# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh"
# Amazon Q pre block. Keep at the top of this file.
# 一時的にコメントアウト（Ghosttyのパフォーマンス問題調査のため）
# [[ -f "${HOME}/Library/Application Support/amazon-q/shell/zprofile.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zprofile.pre.zsh"
emulate sh
source ~/.profile
emulate zsh

eval "$(/opt/homebrew/bin/brew shellenv)"

# Python 3.11 PATH削除: miseで管理しているため不要
# PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:${PATH}"
# export PATH

# Set MAMP's latest PHP version without 8
PHP_VERSION=$(ls /Applications/MAMP/bin/php/ | grep -E 'php8' | sort -V | tail -1)
export PATH=/Applications/MAMP/bin/php/php8.1.31/bin:$PATH
# Add support for MYSQL
export PATH=/Applications/MAMP/Library/bin:$PATH

# Amazon Q post block. Keep at the bottom of this file.
# 一時的にコメントアウト（Ghosttyのパフォーマンス問題調査のため）
# [[ -f "${HOME}/Library/Application Support/amazon-q/shell/zprofile.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zprofile.post.zsh"

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh"
