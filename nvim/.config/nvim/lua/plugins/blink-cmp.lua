return {
  {
    "saghen/blink.cmp",
    opts = {
      -- markdown と text では補完を無効化
      enabled = function()
        local ft = vim.bo.filetype
        return ft ~= "markdown" and ft ~= "text"
      end,
    },
  },
}
