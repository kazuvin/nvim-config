-- 日記・エッセイ用のライティングモード（local/yohaku.nvim）
--   :Writing [on|off|toggle]   書く用の Ghostty ウィンドウを開く（<leader>uW）。中で実行すると閉じる
--   :Mood [name]               ムードを選ぶ。引数なしなら一覧から選ぶ
--   :WritingSound [on|off]     環境音の切り替え

-- 書く用ウィンドウの中の Neovim は、起動時に読み込んですぐライティングモードにする
local in_window = (vim.env.YOHAKU_WINDOW or "") ~= ""

return {
  {
    dir = vim.fn.stdpath("config") .. "/local/yohaku.nvim",
    name = "yohaku.nvim",
    main = "yohaku",
    lazy = not in_window,
    cmd = { "Writing", "Mood", "WritingSound" },
    keys = {
      { "<leader>uW", "<cmd>Writing<cr>", desc = "Writing Mode" },
    },
    opts = {},
  },
}
