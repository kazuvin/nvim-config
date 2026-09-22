return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  config = function()
    require("copilot").setup({
      suggestions = { enable = false },
      panels = { enable = false },
      server_opts_overrides = {
        trace = "verbose",
        cmd = {
          vim.fn.expand("~/.local/share/nvim/mason/bin/copilot-language-server"),
          "--stdio",
        },
      },
      filetypes = { ["*"] = true },
    })
  end,
}
