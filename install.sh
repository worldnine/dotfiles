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

# stow で管理するパッケージ（codex/gemini は個別管理のため除外）
PACKAGES=(
    "zsh"
    "git"
    "starship"
    "ghostty"
    "claude"
    "nvim"
    "tmux"
)

# codex: 安定ファイルはシンボリックリンク、CLI自動書き込み対象はコピー
install_codex() {
    echo "  codex をセットアップ中..."
    # 既存の stow リンクがあれば解除
    if [ -L "$HOME/.codex" ]; then
        echo "    既存のディレクトリシンボリックリンクを解除..."
        rm "$HOME/.codex"
    fi
    mkdir -p "$HOME/.codex"
    # 安定ファイル → シンボリックリンク
    ln -sf "$DOTFILES_DIR/codex/.codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
    ln -sf "$DOTFILES_DIR/codex/.codex/notify_macos.sh" "$HOME/.codex/notify_macos.sh"
    # CLI自動書き込み対象 → コピー（既存があればスキップ）
    if [ ! -f "$HOME/.codex/config.toml" ]; then
        cp "$DOTFILES_DIR/codex/.codex/config.toml" "$HOME/.codex/config.toml"
        echo "    config.toml をコピーしました"
    else
        echo "    config.toml は既存のためスキップ"
    fi
}

# gemini: 安定ファイルはシンボリックリンク、CLI自動書き込み対象はコピー
install_gemini() {
    echo "  gemini をセットアップ中..."
    # 既存の stow リンクがあれば解除
    if [ -L "$HOME/.gemini" ]; then
        echo "    既存のディレクトリシンボリックリンクを解除..."
        rm "$HOME/.gemini"
    fi
    mkdir -p "$HOME/.gemini"
    # 安定ファイル → シンボリックリンク
    ln -sf "$DOTFILES_DIR/gemini/.gemini/GEMINI.md" "$HOME/.gemini/GEMINI.md"
    # CLI自動書き込み対象 → コピー（既存があればスキップ）
    if [ ! -f "$HOME/.gemini/settings.json" ]; then
        cp "$DOTFILES_DIR/gemini/.gemini/settings.json" "$HOME/.gemini/settings.json"
        echo "    settings.json をコピーしました"
    else
        echo "    settings.json は既存のためスキップ"
    fi
}

# 全パッケージをインストール
echo "dotfiles をインストールしています..."
for pkg in "${PACKAGES[@]}"; do
    if [ -d "$pkg" ]; then
        echo "  $pkg をリンク中..."
        stow -v "$pkg"
    fi
done

# codex/gemini は個別にセットアップ
install_codex
install_gemini

# oh-my-tmux のインストール
if [ ! -d "$HOME/.config/tmux/oh-my-tmux" ]; then
    echo "oh-my-tmux をインストール中..."
    git clone https://github.com/gpakosz/.tmux.git "$HOME/.config/tmux/oh-my-tmux"
fi
# oh-my-tmux の tmux.conf へのシンボリックリンクを作成
if [ ! -L "$HOME/.config/tmux/tmux.conf" ]; then
    ln -sf "$HOME/.config/tmux/oh-my-tmux/.tmux.conf" "$HOME/.config/tmux/tmux.conf"
    echo "  tmux.conf → oh-my-tmux/.tmux.conf のリンクを作成しました"
fi

# TPM のインストール（tmux）
if [ ! -d "$HOME/.config/tmux/plugins/tpm" ]; then
    echo "TPM (Tmux Plugin Manager) をインストール中..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
fi

echo ""
echo "インストール完了！"
echo ""
echo "次のステップ:"
echo "  1. .gitconfig の name と email を設定してください"
echo "  2. tmux で prefix + I を押してプラグインをインストール"
