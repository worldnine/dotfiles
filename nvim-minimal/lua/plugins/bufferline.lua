return {
  'akinsho/bufferline.nvim',
  event = 'VeryLazy',
  dependencies = { 'echasnovski/mini.icons' },
  keys = {
    { '<Tab>', '<cmd>BufferLineCycleNext<cr>', desc = 'Next buffer' },
    { '<S-Tab>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev buffer' },
  },
  opts = {
    options = {
      mode = 'buffers',
      diagnostics = false,
      always_show_bufferline = false,
      show_buffer_close_icons = false,
      show_close_icon = false,
    },
  },
}
