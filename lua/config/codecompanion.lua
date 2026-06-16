require("codecompanion").setup({
  adapters = {
    acp = {
      claude_code = function()
        return require("codecompanion.adapters").extend("claude_code", {
          env = {
            CLAUDE_CODE_OAUTH_TOKEN = "CLAUDE_CODE_OAUTH_TOKEN",
          },
        })
      end,
    },
  },
  interactions = {
    chat = {
      adapter = "claude_code",
    },
  },
})
