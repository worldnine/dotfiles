-- markdownlint(nvim-lint) を cwd に依存せず確実に効かせる
--
-- 背景: LazyVim の nvim-lint は markdownlint-cli2 を stdin 渡し(args={"-"})で呼ぶ。
--       stdin 渡しだと markdownlint-cli2 は cwd 直下しか設定を探さず（上方向に
--       たどらない）、プロジェクトの .markdownlint.jsonc を取りこぼして MD013 等が
--       復活する。そこで --config でグローバル設定を明示し、どこで開いても効くようにする。
return {
  "mfussenegger/nvim-lint",
  opts = {
    linters = {
      ["markdownlint-cli2"] = {
        -- 既定の {"-"}(stdin) を保ちつつ、先頭にグローバル設定を明示
        args = {
          "--config",
          vim.fn.stdpath("config") .. "/markdownlint-global.jsonc",
          "-",
        },
      },
    },
  },
}
