return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'master',
  build = ':TSUpdate',
  event = { 'BufReadPost', 'BufNewFile' },
  dependencies = {
    -- textobjects.scm queries were split out of nvim-treesitter master into
    -- this companion plugin; mini.ai's ai.gen_spec.treesitter() needs it.
    { 'nvim-treesitter/nvim-treesitter-textobjects', branch = 'master' },
  },
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
