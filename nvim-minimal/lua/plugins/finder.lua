return {
  -- floating window の透過(winblend)がマルチプレクサ越しに崩れやすい telescope ではなく、
  -- 実ターミナルの fzf プロセスに委譲する fzf-lua を採用（herdr 環境での安定性重視）
  'ibhagwan/fzf-lua',
  dependencies = { 'echasnovski/mini.icons' },
  cmd = 'FzfLua',
  keys = {
    { '<leader><space>', '<cmd>FzfLua files<cr>', desc = 'Find Files' },
    { '<leader>/', '<cmd>FzfLua live_grep<cr>', desc = 'Grep' },
    { '<leader>,', '<cmd>FzfLua buffers<cr>', desc = 'Buffers' },
  },
  opts = {},
}
