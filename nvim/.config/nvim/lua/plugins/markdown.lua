return {
  -- markdown のリスト編集：Enter で自動的に次の項目を挿入
  {
    "gaoDean/autolist.nvim",
    ft = "markdown",
    config = function()
      require("autolist").setup({
        colon = false,
        indent = { tabstop = 2, shiftwidth = 2 },
      })
    end,
  },

  -- markdownlint を無効化（MDxxx の警告がうざいので）
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        markdown = {},
      },
    },
  },
}
