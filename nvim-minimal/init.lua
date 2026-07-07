-- herdr / file-viewer 用の軽量 nvim 設定
-- 普段の LazyVim のいいとこ取り（プラグイン不要なものだけ）

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

-- ── 見た目（背景透過。herdr のテーマに馴染む）
vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none' })
vim.api.nvim_set_hl(0, 'LineNr', { fg = '#555577' })
vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#8888aa', bold = true })
