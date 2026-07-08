return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'master',
  build = ':TSUpdate',
  event = { 'BufReadPost', 'BufNewFile' },
  opts = {
    ensure_installed = {
      'lua', 'vim', 'vimdoc', 'query',
      'bash', 'json', 'yaml', 'toml',
      'markdown', 'markdown_inline',
      'python', 'javascript', 'typescript', 'tsx',
      'rust', 'go',
      'diff', 'gitcommit',
    },
    highlight = { enable = true },
    indent = { enable = true },
  },
  config = function(_, opts)
    require('nvim-treesitter.configs').setup(opts)
  end,
}
