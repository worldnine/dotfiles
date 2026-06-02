-- render-markdown のテーブル表示をキレイにする
-- 生ソースは触らず、表示時に全角幅で桁揃え＋角丸の枠を描画する。
return {
  "MeanderingProgrammer/render-markdown.nvim",
  opts = {
    pipe_table = {
      enabled = true,
      preset = "round", -- 角丸の枠（╭ ╮ ╰ ╯）
      style = "full", -- 枠線をしっかり描く
      cell = "padded", -- セルを表示幅（全角=2）で揃える
      alignment_indicator = "─",
      padding = 1,
    },
  },
}
