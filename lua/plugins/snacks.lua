return {
  -- snacks.nvim の explorer を右側に表示
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {
        replace_netrw = true,
      },
      picker = {
        sources = {
          explorer = {
            layout = {
              layout = {
                position = "right",
                width = 40,
              },
            },
            hidden = true, -- 隠しファイルを表示
            ignored = true, -- gitignore されたファイルを表示
          },
        },
      },
    },
    keys = {
      {
        "<leader>e",
        function()
          Snacks.explorer()
        end,
        desc = "Explorer",
      },
    },
  },
}
