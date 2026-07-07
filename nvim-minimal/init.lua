-- herdr / file-viewer 用の最小限 nvim 設定
-- プラグインゼロ、LSPなし、高速起動

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamed'
vim.opt.showmode = false
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.signcolumn = 'yes'
vim.opt.swapfile = false
vim.opt.undofile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.updatetime = 300
vim.opt.timeoutlen = 500

-- キーマップ（最低限）
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- カラースキーム（nvim 組み込みの default で OK、あるいは好みで）
-- vim.cmd.colorscheme('default')
