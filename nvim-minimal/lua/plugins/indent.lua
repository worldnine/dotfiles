return {
  'lukas-reineke/indent-blankline.nvim',
  main = 'ibl',
  event = { 'BufReadPost', 'BufNewFile' },
  opts = {
    indent = { char = '│' },
    -- スコープハイライトはカーソル移動のたびに再描画が走るため無効化
    scope = { enabled = false },
  },
}
