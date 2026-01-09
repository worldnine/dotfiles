return {
  -- TokyoNightの背景を透過
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },

  -- 追加テーマ（必要なら）
  -- { "catppuccin/nvim", name = "catppuccin" },
  -- { "rebelot/kanagawa.nvim" },
}
