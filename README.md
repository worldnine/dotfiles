# dotfiles

開発環境の設定ファイル（macOS）

## 含まれる設定

- **zsh** - シェル設定（Starship, mise, fzf）
- **git** - Git設定
- **starship** - プロンプト
- **ghostty** - ターミナルエミュレータ
- **claude** - Claude Code
- **gemini** - Gemini CLI
- **codex** - OpenAI Codex
- **nvim** - Neovim (LazyVim)
- **tmux** - tmux + TPM

## インストール

```bash
# リポジトリをクローン
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles

# stowをインストール（未インストールの場合）
brew install stow

# 全ての設定をインストール
./install.sh

# または個別にインストール
stow zsh
stow nvim
```

## インストール後

1. `.gitconfig` の `name` と `email` を編集
2. tmux で `prefix + I` を押してプラグインをインストール
