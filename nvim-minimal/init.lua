-- herdr / file-viewer 用の軽量 nvim 設定
-- 普段の LazyVim のいいとこ取りだが、herdr（ターミナルマルチプレクサ的な環境）で
-- 描画が壊れやすいプラグイン分類は避ける方針で lazy.nvim を使う。
--
-- 意図的に入れていないもの（herdr 環境での描画崩れ・二重ハンドリングを避けるため）:
--   - 画像プロトコル系（snacks.image / image.nvim）… herdr がターミナル画像プロトコルを
--     プロキシしきれず表示が乱れる可能性が高い
--   - noice.nvim（ext_cmdline / ext_messages / ext_popupmenu）… herdr 越しだと
--     コマンドラインUIの再描画が崩れやすい
--   - snacks.nvim のダッシュボード・notifier・アニメーション系 … 高頻度再描画が
--     マルチプレクサ越しでちらつく/重くなる
--   - スムーズスクロール等のアニメーション系プラグイン全般
--   - OSC52 クリップボード系 … herdr 自体のクリップボード処理と衝突しうる。ローカル
--     macOS ターミナルなので unnamed（pbcopy）で足りる
--   - Copilot / CodeCompanion 等のAIエージェント統合 … 本体の LazyVim 設定側の役割

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- 本体 LazyVim の mason でインストール済みのフォーマッタ(stylua/shfmt/prettier等)を
-- 再利用する。nvim-minimal自体にmason.nvimは入れず軽量に保つための措置。
local mason_bin = vim.fn.expand('~/.local/share/nvim/mason/bin')
if vim.fn.isdirectory(mason_bin) == 1 then
  vim.env.PATH = mason_bin .. ':' .. vim.env.PATH
end

-- ── 表示 ──
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.cursorlineopt = 'number'
vim.opt.signcolumn = 'yes'
vim.opt.showmode = false
vim.opt.termguicolors = true
vim.opt.scrolloff = 4          -- カーソル上下に余白
vim.opt.sidescrolloff = 8

-- ── 編集 ──
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamed'
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
vim.opt.breakindent = true
vim.opt.linebreak = true       -- 単語の途中で折り返さない
vim.opt.wrap = false           -- 長い行は折り返さない
vim.opt.spell = false
vim.opt.spelllang = 'en,cjk'

-- ── 検索 ──
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true       -- 大文字含むときだけ case-sensitive

-- ── 分割ウィンドウ ──
vim.opt.splitright = true
vim.opt.splitbelow = true

-- ── パフォーマンス ──
vim.opt.swapfile = false
vim.opt.undofile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.updatetime = 300
vim.opt.timeoutlen = 500

-- ── その他 ──
vim.opt.hidden = true          -- 未保存バッファの切り替え許可
vim.opt.confirm = true         -- 保存せずに閉じるとき確認
vim.opt.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize', 'help', 'globals', 'skiprtp', 'folds' }
vim.opt.shada = ''             -- shada ファイルを作らない（プラグイン情報が保存されないように）
vim.opt.modeline = false

-- ── キーマップ ──
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<C-h>', '<C-w>h')
vim.keymap.set('n', '<C-j>', '<C-w>j')
vim.keymap.set('n', '<C-k>', '<C-w>k')
vim.keymap.set('n', '<C-l>', '<C-w>l')
vim.keymap.set('i', 'jj', '<Esc>')        -- jj でインサートモードを抜ける

-- ── 見た目（背景透過。herdr のテーマに馴染む。プラグイン未導入時のフォールバック）
vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none' })
vim.api.nvim_set_hl(0, 'LineNr', { fg = '#555577' })
vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#8888aa', bold = true })

-- ── markdown injections クエリの上書き（nvim-treesitter master と Neovim 0.12 コアの非互換の回避）──
-- nvim-treesitter（branch=master, 固定コミット）が同梱する queries/markdown/injections.scm は、
-- 言語タグ付きフェンスコードブロック（```lua など）に対して独自の
-- `#set-lang-from-info-string!` ディレクティブを使う。このディレクティブのハンドラ
-- （nvim-treesitter/lua/nvim-treesitter/query_predicates.lua）が
-- vim.treesitter.get_node_text() を呼ぶが、Neovim 0.12.2 コアの
-- vim.treesitter.query._apply_directives / languagetree.lua の注入解決との間で
-- ノードの :range() が取得できず nil メソッド呼び出しでクラッシュする
-- （E5108, "attempt to call method 'range' (a nil value)"）。
-- 言語タグなしのフェンスや他の言語には影響しないが、言語タグ付きコードブロックを含む
-- markdown を開くたびに再描画のたびクラッシュし続ける（render-markdown.nvim 経由でも、
-- 素の vim.treesitter.start でも再現）。
--
-- nvim-treesitter 側のクエリファイルを直接編集せず、Neovim コア同梱の
-- $VIMRUNTIME/queries/markdown/injections.scm （こちらはカスタムディレクティブを
-- 使わずシンプルに @injection.language を直接キャプチャするだけで、この非互換が
-- 発生しない）の内容をそのまま vim.treesitter.query.set() で明示登録し、
-- markdown の injections クエリだけを上書きする。branch=master のピン留めはそのまま維持し、
-- markdown/markdown_inline のパーサや highlights 等の他クエリには手を加えない。
vim.treesitter.query.set('markdown', 'injections', [[
(fenced_code_block
  (info_string
    (language) @injection.language)
  (code_fence_content) @injection.content)

((html_block) @injection.content
  (#set! injection.language "html")
  (#set! injection.combined)
  (#set! injection.include-children))

((minus_metadata) @injection.content
  (#set! injection.language "yaml")
  (#offset! @injection.content 1 0 -1 0)
  (#set! injection.include-children))

((plus_metadata) @injection.content
  (#set! injection.language "toml")
  (#offset! @injection.content 1 0 -1 0)
  (#set! injection.include-children))

([
  (inline)
  (pipe_table_cell)
] @injection.content
  (#set! injection.language "markdown_inline"))
]])

-- ── lazy.nvim ブートストラップ ──
-- NVIM_APPNAME=nvim-minimal を付け忘れて `nvim -u .../init.lua` のように
-- -u だけで起動された場合（実際に herdr の古いペインが握っていた stale な
-- EDITOR 文字列で発生した）、stdpath('data')/stdpath('config') が本体の
-- nvim と同じ場所になってしまい、本体 LazyVim の lua/plugins/*.lua
-- （nvim-lint 等）を誤って巻き込んで壊れる事故が起きた。
-- そのため stdpath() に頼らず、このファイル自身の場所を自己特定して
-- プラグイン一覧の読み込み元とデータ領域を明示的に固定する。
local this_dir = vim.fn.fnamemodify((debug.getinfo(1, 'S').source):sub(2), ':h')

local data_dir = vim.fn.stdpath('data')
if vim.fn.fnamemodify(data_dir, ':t') ~= 'nvim-minimal' then
  -- NVIM_APPNAME が効いていない(本体と同じ data dir になっている)場合の保険
  data_dir = data_dir:gsub('/nvim$', '/nvim-minimal')
end

local lazypath = data_dir .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- runtimepath 経由の 'plugins' インポートだと、本体 nvim の lua/plugins が
-- rtp に残っている場合に二重に読み込まれてしまうため、このディレクトリの
-- lua/plugins/*.lua を直接 dofile して spec を組み立てる（rtp に依存しない）
local plugin_specs = {}
for _, f in ipairs(vim.fn.glob(this_dir .. '/lua/plugins/*.lua', false, true)) do
  table.insert(plugin_specs, dofile(f))
end

require('lazy').setup(plugin_specs, {
  root = data_dir .. '/lazy',
  lockfile = this_dir .. '/lazy-lock.json',
  checker = { enabled = false },
  change_detection = { notify = false },
})
