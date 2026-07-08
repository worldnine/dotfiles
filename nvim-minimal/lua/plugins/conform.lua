return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  opts = {
    -- 本体 LazyVim の mason でインストール済みの実行ファイルを PATH 経由で利用する
    -- (init.lua で ~/.local/share/nvim/mason/bin を PATH に追加済み)
    formatters_by_ft = {
      lua = { 'stylua' },
      sh = { 'shfmt' },
      json = { 'prettier' },
      yaml = { 'prettier' },
      markdown = { 'prettier' },
    },
    format_on_save = {
      timeout_ms = 500,
      lsp_format = 'fallback',
    },
  },
}
