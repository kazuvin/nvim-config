-- 画面の見た目: 背景を透かす下敷きウィンドウと、中央の本文ウィンドウ（どちらもフロート）
local decor = require("yohaku.decor")

local M = {}

local hl_ns = vim.api.nvim_create_namespace("yohaku")
local augroup = vim.api.nvim_create_augroup("yohaku_view", { clear = true })

---@class yohaku.ViewState
---@field cfg yohaku.Config
---@field parent integer 元のウィンドウ
---@field win integer 本文のフロート
---@field backdrop integer 画面全体を覆う下敷きのフロート
---@field bufs table<integer, {diagnostics: boolean, completion: any, render_markdown: boolean}> 変更したバッファと元の設定
---@field last {buf: integer, cursor: integer[]} 閉じたときに元のウィンドウへ戻す位置
---@field guicursor string 元のカーソルの形

---@type yohaku.ViewState?
local S = nil

---@param a string "#rrggbb"
---@param b string "#rrggbb"
---@param t number b の割合（0〜1）
local function blend(a, b, t)
  local function channel(hex, i)
    return tonumber(hex:sub(i, i + 1), 16)
  end
  local out = "#"
  for _, i in ipairs({ 2, 4, 6 }) do
    out = out .. ("%02x"):format(math.floor(channel(a, i) * (1 - t) + channel(b, i) * t + 0.5))
  end
  return out
end

local CURSORS = {
  bar = "n-v-c-sm:ver20,i-ci-ve:ver20-blinkwait400-blinkon500-blinkoff500,r-cr-o:hor10",
  underline = "n-v-c-sm-r-cr-o:hor10,i-ci-ve:hor10-blinkwait400-blinkon500-blinkoff500",
}

-- Ghostty 1.3 までは縦棒カーソルの高さがマスの高さに固定されていて、行間を広げると伸びる
-- （adjust-cursor-height も効かない。https://github.com/ghostty-org/ghostty/pull/13225 で修正）。
-- 1.4.0 以降の正式版と、tip などの開発版（版番号が 1.2.3 の形でない）は修正済みとみなす
---@param cfg yohaku.Config
local function cursor_style(cfg)
  if cfg.cursor ~= "auto" then
    return CURSORS[cfg.cursor]
  end
  if not (cfg.ghostty.enabled and cfg.ghostty.cell_height) then
    return CURSORS.bar
  end
  local stable = (vim.env.TERM_PROGRAM_VERSION or ""):match("^(%d+%.%d+%.%d+)$")
  if stable and not vim.version.ge(stable, "1.4.0") then
    return CURSORS.underline
  end
  return CURSORS.bar
end

---@param cfg yohaku.Config
local function layout(cfg)
  local cols = vim.o.columns
  local rows = vim.o.lines - vim.o.cmdheight
  local width = math.min(cfg.width, cols - 4)
  -- 本文は画面の上端から下端まで使う。固定の余白を取ると、スクロールした本文がそこで途切れて
  -- 見える。文書の先頭の余白は、見出しレベル 1 の上に足す空行（decor.lua）で取る
  local top = math.min(cfg.top_margin, rows - 1)
  return {
    backdrop = { relative = "editor", row = 0, col = 0, width = cols, height = rows },
    text = {
      relative = "editor",
      row = top,
      col = math.floor((cols - width) / 2),
      width = width,
      height = rows - top,
    },
  }
end

local function relayout()
  if not S then
    return
  end
  local l = layout(S.cfg)
  if vim.api.nvim_win_is_valid(S.backdrop) then
    vim.api.nvim_win_set_config(S.backdrop, l.backdrop)
  end
  if vim.api.nvim_win_is_valid(S.win) then
    vim.api.nvim_win_set_config(S.win, l.text)
  end
end

-- バッファを切り替えると window-local オプションが戻ることがあるので、その都度かけ直す
local function set_text_opts(win)
  local wo = vim.wo[win]
  wo.wrap = true
  -- linebreak は空白でしか折り返さないので、空白のない和文だと直前の英単語の後ろで
  -- 折れてしまう（「AI 時代の…」が「AI」で改行される）。和文は 1 文字ずつ折り返せばよいので切る
  wo.linebreak = false
  wo.breakindent = false
  wo.smoothscroll = true
  wo.scrolloff = S.cfg.typewriter and 999 or 3
  wo.conceallevel = 2
  wo.concealcursor = "nc" -- カーソル行でも、入力中以外は見出しの `# ` などを隠したままにする
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.statuscolumn = ""
  wo.cursorline = false
  wo.colorcolumn = ""
  wo.spell = false
  wo.list = false
  wo.fillchars = "eob: "
end

-- 見出しの帯やアイコンなどの飾りは decor.lua で最小限に描くので、render-markdown は止める
---@param buf integer
---@param enable boolean
---@return boolean? 操作できたか（render-markdown が読み込まれていなければ nil）
local function set_render_markdown(buf, enable)
  local rm = package.loaded["render-markdown"]
  if not rm then
    return nil
  end
  return pcall(vim.api.nvim_buf_call, buf, enable and rm.buf_enable or rm.buf_disable)
end

-- 書くことに集中できるよう、診断（markdownlint など）と補完ポップアップを止める
local function enter_buf(buf)
  if S.bufs[buf] then
    return
  end
  S.bufs[buf] = {
    diagnostics = vim.diagnostic.is_enabled({ bufnr = buf }),
    completion = vim.b[buf].completion,
    render_markdown = set_render_markdown(buf, false) == true,
  }
  vim.diagnostic.enable(false, { bufnr = buf })
  vim.b[buf].completion = false -- blink.cmp（Copilot の候補を含む）
  decor.attach(buf, { paragraph_gap = S.cfg.paragraph_gap, heading_gap = S.cfg.heading_gap, h1_gap = S.cfg.h1_gap })
end

---@param s yohaku.ViewState
local function restore_bufs(s)
  for buf, saved in pairs(s.bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.diagnostic.enable(saved.diagnostics, { bufnr = buf })
      vim.b[buf].completion = saved.completion
      decor.detach(buf)
      if saved.render_markdown then
        set_render_markdown(buf, true)
      end
    end
  end
end

local function remember()
  if S and vim.api.nvim_get_current_win() == S.win then
    S.last = { buf = vim.api.nvim_get_current_buf(), cursor = vim.api.nvim_win_get_cursor(S.win) }
    decor.show_top(S.win)
  end
end

---@param cfg yohaku.Config
---@param on_close fun() 本文ウィンドウが閉じられたときに呼ぶ
function M.open(cfg, on_close)
  local parent = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(parent)
  local l = layout(cfg)

  local backdrop_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[backdrop_buf].bufhidden = "wipe"
  local backdrop = vim.api.nvim_open_win(
    backdrop_buf,
    false,
    vim.tbl_extend("force", l.backdrop, { style = "minimal", focusable = false, zindex = 40, noautocmd = true })
  )
  local win = vim.api.nvim_open_win(buf, true, vim.tbl_extend("force", l.text, { style = "minimal", zindex = 41 }))

  S = {
    cfg = cfg,
    parent = parent,
    win = win,
    backdrop = backdrop,
    bufs = {},
    last = { buf = buf, cursor = cursor },
    guicursor = vim.o.guicursor,
  }
  vim.o.guicursor = cursor_style(cfg)
  vim.api.nvim_win_set_hl_ns(backdrop, hl_ns)
  vim.api.nvim_win_set_hl_ns(win, hl_ns)
  set_text_opts(win)
  vim.api.nvim_win_set_cursor(win, cursor)
  enter_buf(buf)

  vim.api.nvim_create_autocmd("VimResized", { group = augroup, callback = relayout })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, { group = augroup, callback = remember })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    callback = function(ev)
      if S and vim.api.nvim_get_current_win() == S.win then
        set_text_opts(S.win)
        enter_buf(ev.buf)
        remember()
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(win),
    callback = function()
      vim.schedule(on_close)
    end,
  })
  -- 下に隠れた通常ウィンドウへ移ったら、見えないまま編集しないようにモードを抜ける
  vim.api.nvim_create_autocmd("WinEnter", {
    group = augroup,
    callback = function()
      local w = vim.api.nvim_get_current_win()
      if S and w ~= S.win and vim.api.nvim_win_get_config(w).relative == "" then
        vim.schedule(on_close)
      end
    end,
  })
end

function M.close()
  if not S then
    return
  end
  local s = S
  S = nil
  vim.api.nvim_clear_autocmds({ group = augroup })
  vim.o.guicursor = s.guicursor
  -- :q で閉じられた場合は本文ウィンドウがもうないので、最後に記録した位置を使う
  if vim.api.nvim_win_is_valid(s.win) then
    s.last = { buf = vim.api.nvim_win_get_buf(s.win), cursor = vim.api.nvim_win_get_cursor(s.win) }
  end
  restore_bufs(s)
  if vim.api.nvim_win_is_valid(s.parent) and vim.api.nvim_buf_is_valid(s.last.buf) then
    vim.api.nvim_win_set_buf(s.parent, s.last.buf)
    pcall(vim.api.nvim_win_set_cursor, s.parent, s.last.cursor)
  end
  for _, w in ipairs({ s.win, s.backdrop }) do
    if vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
    end
  end
  if vim.api.nvim_win_is_valid(s.parent) then
    vim.api.nvim_set_current_win(s.parent)
  end
end

-- 本文ウィンドウだけに効くハイライト。背景は透明にして、ターミナルの背景画像を見せる。
-- しずかなインターネットに合わせ、色はほぼ白の本文と灰色の見出しだけにする
---@param colors {fg: string, dim: string}
---@param mood yohaku.Mood
function M.set_style(colors, mood)
  local text = { fg = colors.fg }
  local dim = { fg = colors.dim }
  local groups = {
    Normal = text,
    NormalFloat = text,
    NormalNC = text,
    Visual = { bg = blend(mood.bg, colors.fg, 0.28) },
    -- 英数字が混ざって和文が半マスずれると、行末に全角が収まらず Neovim が NonText で「>」を出す。
    -- 文字は次の行に送られているだけなので、下地の色にして見えなくする
    NonText = { fg = mood.bg },
    Conceal = dim,
    YohakuBullet = dim,
    ["@markup.heading"] = dim,
    ["@markup.strong"] = { fg = colors.fg, bold = true },
    ["@markup.italic"] = { fg = colors.fg, italic = true },
    ["@markup.list"] = dim,
    ["@markup.quote"] = dim,
    ["@markup.raw"] = dim,
    ["@markup.link"] = { fg = colors.fg, underline = true },
    ["@markup.link.label"] = { fg = colors.fg, underline = true },
    ["@markup.link.url"] = { fg = colors.dim, underline = true },
    ["@punctuation.special"] = dim,
  }
  for i = 1, 6 do
    groups["@markup.heading." .. i] = dim
    groups["@markup.heading." .. i .. ".markdown"] = dim
  end
  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(hl_ns, name, spec)
  end
end

return M
