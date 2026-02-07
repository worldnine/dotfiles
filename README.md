# dotfiles

開発環境の設定ファイル（macOS）

## 含まれる設定

### stow 管理（ディレクトリ丸ごとシンボリックリンク）

- **zsh** - シェル設定（Starship, mise, fzf）
- **git** - Git設定
- **starship** - プロンプト
- **ghostty** - ターミナルエミュレータ
- **claude** - Claude Code
- **nvim** - Neovim (LazyVim)
- **tmux** - tmux + TPM

### 個別管理（シンボリックリンク + コピー）

CLIが設定ファイルに自動書き込みするため、stow ではなくファイル単位で管理。

- **codex** - OpenAI Codex
  - `AGENTS.md`, `notify_macos.sh` → シンボリックリンク
  - `config.toml` → コピー（CLI自動書き込み対象）
- **gemini** - Gemini CLI
  - `GEMINI.md` → シンボリックリンク
  - `settings.json` → コピー（CLI自動書き込み対象）

## インストール

```bash
# リポジトリをクローン
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles

# stowをインストール（未インストールの場合）
brew install stow

# 全ての設定をインストール
./install.sh

# または個別にインストール（stow管理パッケージのみ）
stow zsh
stow nvim
# 注意: codex/gemini は stow ではなく install.sh で管理
```

## インストール後

1. `.gitconfig` の `name` と `email` を編集
2. tmux で `prefix + I` を押してプラグインをインストール
