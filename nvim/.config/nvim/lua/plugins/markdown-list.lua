-- マークダウン等でリストの連続入力を快適にする（autolist.nvim）
-- Enter で次のマーカーを自動挿入／空行で自動削除／番号付きリストの自動リナンバー等。
--
-- 注意: LazyVim の補完エンジン blink.cmp が <CR>/<Tab> を使うため、
--       キーマップは markdown/text 系バッファだけに buffer-local で張り、
--       他ファイルタイプの補完操作を壊さないようにする。
return {
  "gaoDean/autolist.nvim",
  ft = { "markdown", "text", "tex", "plaintex", "norg" },
  config = function()
    require("autolist").setup()

    local filetypes = { "markdown", "text", "tex", "plaintex", "norg" }

    local function set_keymaps(buf)
      local opts = { buffer = buf }
      -- 入力中: Enter で次のマーカー、Tab/S-Tab でインデント増減
      vim.keymap.set("i", "<CR>", "<CR><cmd>AutolistNewBullet<cr>", opts)
      vim.keymap.set("i", "<Tab>", "<cmd>AutolistTab<cr>", opts)
      vim.keymap.set("i", "<S-Tab>", "<cmd>AutolistShiftTab<cr>", opts)
      -- ノーマル: o / O で新規マーカー行
      vim.keymap.set("n", "o", "o<cmd>AutolistNewBullet<cr>", opts)
      vim.keymap.set("n", "O", "O<cmd>AutolistNewBulletBefore<cr>", opts)
      -- 番号付きリストの再計算（削除や並べ替え後の振り直し）
      vim.keymap.set("n", "<C-r>", "<cmd>AutolistRecalculate<cr>", opts)
      vim.keymap.set("n", "dd", "dd<cmd>AutolistRecalculate<cr>", opts)
      vim.keymap.set("v", "d", "d<cmd>AutolistRecalculate<cr>", opts)
      -- チェックボックス - [ ] のトグル
      vim.keymap.set("n", "<leader>x", "<cmd>AutolistToggleCheckbox<cr>", opts)
    end

    -- 以後開く markdown/text バッファに自動で張る
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("autolist_keymaps", { clear = true }),
      pattern = filetypes,
      callback = function(ev)
        set_keymaps(ev.buf)
      end,
    })

    -- config 実行時点で既に開いている markdown/text バッファにも張る
    if vim.tbl_contains(filetypes, vim.bo.filetype) then
      set_keymaps(0)
    end
  end,
}
