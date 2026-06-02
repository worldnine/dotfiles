-- Markdown/Text では補完の自動ポップアップを無効化（blink.cmp）
-- LazyVim 現行の補完エンジンは blink.cmp。nvim-cmp 向けの設定は効かないため blink 側で制御する。
-- 自動ポップアップだけ止め、手動トリガー（<C-Space>）では出せるようにする。
return {
  {
    "saghen/blink.cmp",
    opts = {
      completion = {
        menu = {
          auto_show = function(_)
            return not vim.tbl_contains({ "markdown", "text" }, vim.bo.filetype)
          end,
        },
      },
    },
  },
}
