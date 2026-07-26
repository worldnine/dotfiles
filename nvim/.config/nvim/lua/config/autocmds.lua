-- Disable spell check on all buffers (overrides LazyVim defaults)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt_local.spell = false
  end,
})

-- InsertLeave で自動的に英数入力に戻す（日本語IME対策: leaderキーが効かなくなるのを防ぐ）
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  callback = function()
    vim.fn.system("/Users/nagata/.local/bin/macism com.apple.keylayout.ABC")
  end,
})
