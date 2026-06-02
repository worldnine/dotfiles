-- マークダウンのテーブルを入力しながら自動整列する（vim-table-mode）
-- テーブルモードON中に | を打つと列幅が自動再計算され、生ソースの | が揃う。
-- 表示は render-markdown が担当、こちらは「生ソースの整形」担当。
return {
  "dhruvasagar/vim-table-mode",
  ft = { "markdown", "text" },
  cmd = { "TableModeToggle", "TableModeEnable", "TableModeDisable", "Tableize", "TableModeRealign" },
  init = function()
    -- GitHub Flavored Markdown 互換の区切り（| ---- | スタイル）にする
    vim.g.table_mode_corner = "|"
  end,
  keys = {
    { "<leader>tm", "<cmd>TableModeToggle<cr>", desc = "Table Mode: トグル", ft = { "markdown", "text" } },
    { "<leader>tr", "<cmd>TableModeRealign<cr>", desc = "Table Mode: 再整列", ft = { "markdown", "text" } },
    { "<leader>tt", "<cmd>Tableize<cr>", mode = { "n", "v" }, desc = "Table Mode: テキストをテーブル化", ft = { "markdown", "text" } },
  },
}
