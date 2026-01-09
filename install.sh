#!/bin/bash
# dotfiles インストールスクリプト

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_DIR"

# stowがインストールされているか確認
if ! command -v stow &> /dev/null; then
    echo "GNU stow がインストールされていません"
    echo "インストール: brew install stow"
    exit 1
fi

# 利用可能なパッケージ
PACKAGES=(
    "zsh"
    "git"
    "starship"
    "ghostty"
    "claude"
    "gemini"
    "codex"
    "nvim"
    "tmux"
)

# 全パッケージをインストール
echo "dotfiles をインストールしています..."
for pkg in "${PACKAGES[@]}"; do
    if [ -d "$pkg" ]; then
        echo "  $pkg をリンク中..."
        stow -v "$pkg"
    fi
done

# TPMのインストール（tmux）
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "TPM (Tmux Plugin Manager) をインストール中..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

echo ""
echo "インストール完了！"
echo ""
echo "次のステップ:"
echo "  1. .gitconfig の name と email を設定してください"
echo "  2. tmux で prefix + I を押してプラグインをインストール"
