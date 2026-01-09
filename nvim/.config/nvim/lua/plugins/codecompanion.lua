return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    -- GitHub Copilotのトークンパスを設定
    vim.env["CODECOMPANION_TOKEN_PATH"] = vim.fn.expand("~/.config")

    require("codecompanion").setup({
      adapters = {
        -- Claude Code: ACP経由（Maxプラン適用）
        -- HOME環境変数を渡すことで ~/.claude.json を読めるようにする
        claude_code = function()
          return require("codecompanion.adapters").extend("claude_code", {
            env = {
              HOME = vim.fn.getenv("HOME"),
              PATH = vim.fn.getenv("PATH"),
              USER = vim.fn.getenv("USER"),
            },
          })
        end,
        -- Gemini CLI: ACP経由
        gemini_cli = function()
          return require("codecompanion.adapters").extend("gemini_cli", {
            -- gemini cliの認証を使用
          })
        end,
        -- Copilot: copilot.vimの認証を自動的に使用
      },
      strategies = {
        chat = { adapter = "claude_code" },   -- チャットはClaude Code（Maxプラン内）
        inline = { adapter = "copilot" },     -- インライン補完はCopilot
        agent = { adapter = "claude_code" },  -- エージェントもClaude Code
      },
    })
  end,
  keys = {
    { "<leader>aa", ":CodeCompanionActions<CR>", mode = { "n", "v" }, desc = "Code Companion Actions" },
    { "<leader>ac", ":CodeCompanionChat Toggle<CR>", mode = { "n", "v" }, desc = "Code Companion Chat" },
    { "<leader>ai", ":CodeCompanion<CR>", mode = { "n", "v" }, desc = "Code Companion Inline" },
  },
}
