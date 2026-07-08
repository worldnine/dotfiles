return {
  'echasnovski/mini.icons',
  lazy = true,
  opts = {},
  init = function()
    -- nvim-web-devicons を期待するプラグイン（fzf-lua 等）向けの互換シム
    package.preload['nvim-web-devicons'] = function()
      require('mini.icons').mock_nvim_web_devicons()
      return package.loaded['nvim-web-devicons']
    end
  end,
}
