-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Disable spell check on all buffers (overrides LazyVim defaults)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt_local.spell = false
  end,
})

-- Also disable for current buffer
vim.opt.spell = false

-- 補完の自動ポップアップ制御は lua/plugins/cmp.lua（blink.cmp）側で行う。
-- ここに nvim-cmp 向けの設定を書いても現行エンジンでは効かないため削除した。
