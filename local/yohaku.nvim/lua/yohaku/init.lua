local view = require("yohaku.view")
local ghostty = require("yohaku.ghostty")
local sound = require("yohaku.sound")

local M = {}

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
local function asset(path)
  return root .. "/" .. path
end

---@class yohaku.Mood
---@field label string 選択時に表示する名前
---@field image? string 背景画像（ぼかし済みの JPEG / PNG）
---@field sound? string 環境音（afplay で再生できる形式）
---@field bg string 画像の下地の色（画像の平均的な暗い色。選択範囲の混色にも使う）

---@class yohaku.Config
local defaults = {
  -- 本文の幅（マス数。全角はこの半分の字数）。既定のフォント設定ではマス幅が約 7.6px なので、
  -- 78 マス ≈ 590px（全角 39 字）。フォントや字送りを変えたら合わせて変える
  width = 78,
  paragraph_gap = 1, -- 段落の間に足す見た目上の行数
  heading_gap = 2, -- 見出しの後に足す行数
  h1_gap = 3, -- 見出しレベル 1（`# `）の上に足す行数。文書の先頭の余白もこれで取る
  top_margin = 0, -- 本文ウィンドウの上に固定で空ける行数（スクロールしても動かない余白）
  typewriter = false, -- true ならカーソル行を常に画面の中央に保つ
  -- 色は白に近い本文と灰色の見出しだけ（しずかなインターネットより少し白く）
  colors = {
    fg = "#f5f5f5",
    dim = "#bdbdbd",
  },
  -- 書いている間のカーソル: "auto" / "bar"（常に縦棒）/ "underline"（常に下線）。
  -- Ghostty 1.3 までは箱型・縦棒がマスの高さいっぱいに描かれる不具合があり、行間を広げると背が高くなる
  -- （1.4.0 で修正、開発版の tip には修正済み）。"auto" は修正済みの Ghostty ならふだんのカーソル
  -- （ノーマルモードは箱型、入力モードは縦棒）のまま、そうでなければ文字のすぐ下に付く下線にする
  cursor = "auto",
  mood = "river", -- 初回のムード（以降は最後に選んだものを覚える）
  ---@type table<string, yohaku.Mood>
  moods = {
    river = {
      label = "川",
      image = asset("backgrounds/river.jpg"),
      sound = asset("sounds/river.m4a"),
      bg = "#0a1211",
    },
    mountain = {
      label = "山",
      image = asset("backgrounds/mountain.jpg"),
      sound = asset("sounds/mountain.m4a"),
      bg = "#23130d",
    },
    rain = {
      label = "雨",
      image = asset("backgrounds/rain.jpg"),
      sound = asset("sounds/rain.m4a"),
      bg = "#0e0f0f",
    },
  },
  sound = {
    enabled = true,
    volume = 0.4, -- afplay の音量（0〜1）
  },
  -- :Writing で書く用の Ghostty ウィンドウを別に開き、見た目の設定はそのウィンドウにだけ効かせる。
  -- false（または Ghostty がない）なら、今のウィンドウの中でライティングモードにする
  ghostty = {
    enabled = true,
    dir = vim.fn.stdpath("state") .. "/yohaku", -- 書く用ウィンドウの設定ファイルを置く場所
    padding_y = "20,0", -- ウィンドウ上端（,下端）の余白（pt）。文字が上端に貼りつかないように
    -- 英数字は Hack、和文はしずかなインターネットと同じヒラギノ角ゴシック。Ghostty は
    -- 1 番目のフォントに合わせて和文を拡大するので、Hack だと和文は英数字の約 1.04 倍になる。
    -- 以下の値はそれを前提に計算したもの（フォントを変えたら計算し直しが必要）
    font_family = { "Hack Nerd Font Mono", "Hiragino Sans" },
    font_size = 14, -- 和文は約 14.5pt
    -- ヒラギノ W3 は細く、背景の上だと沈むので、いちばん弱い強さで少しだけ太らせる
    font_thicken = true,
    font_thicken_strength = 0, -- 0〜255（0 でも太らせないわけではなく、いちばん弱い太らせ方）
    -- 和文の字送りを約 1.05em（字間 0.05em）にする。マス幅は 14 × 0.602 × 0.9 ≈ 7.6px。
    -- これ以上詰めると英数字どうしがくっつく
    cell_width = "-10%",
    -- 行送りを和文の約 2.3 倍にする。文字はマスの縦中央に置かれ、上下が余白になる。
    -- カーソルの高さは文字の高さのまま（ライティングモード中は縦棒のカーソルにする）
    cell_height = "105%",
  },
}

---@type yohaku.Config
M.config = vim.deepcopy(defaults)

local state = { active = false, mood = defaults.mood, sound = true }
local mood_file = vim.fn.stdpath("state") .. "/yohaku/mood"

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "yohaku" })
end

local function load_mood()
  local ok, lines = pcall(vim.fn.readfile, mood_file)
  local name = ok and lines[1] or nil
  return (name and M.config.moods[name]) and name or M.config.mood
end

local function save_mood(name)
  vim.fn.mkdir(vim.fn.fnamemodify(mood_file, ":h"), "p")
  vim.fn.writefile({ name }, mood_file)
end

local function mood_names()
  local names = vim.tbl_keys(M.config.moods)
  table.sort(names)
  return names
end

local function apply_sound()
  local mood = M.config.moods[state.mood]
  if state.active and state.sound then
    sound.play(mood.sound, M.config.sound.volume)
  else
    sound.stop()
  end
end

-- 書く用の Ghostty ウィンドウの中で動いている Neovim か
local function in_window()
  return vim.env.YOHAKU_WINDOW ~= nil and vim.env.YOHAKU_WINDOW ~= ""
end

-- 書く用ウィンドウを開くか（ふだんの Neovim から :Writing したとき）
local function use_window()
  return M.config.ghostty.enabled and ghostty.available() and not in_window()
end

local function apply()
  local mood = M.config.moods[state.mood]
  view.set_style(M.config.colors, mood)
  if in_window() then
    ghostty.update(mood, M.config.ghostty, M.config.colors)
  end
  apply_sound()
end

-- 今のファイルを保存して、書く用ウィンドウで開く
local function open_window()
  local file = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= "" or file == "" then
    notify("ファイルを開いてから（名前のないバッファは保存してから）実行してください", vim.log.levels.WARN)
    return
  end
  if vim.bo.modified then
    vim.cmd("write")
  end
  ghostty.launch(file, state.mood, M.config.moods[state.mood], M.config.ghostty, M.config.colors)
end

function M.enable()
  if state.active then
    return
  end
  if use_window() then
    return open_window()
  end
  if vim.bo.buftype ~= "" then
    notify("通常のバッファで実行してください", vim.log.levels.WARN)
    return
  end
  state.active = true
  view.open(M.config, M.disable)
  apply()
end

function M.disable()
  if not state.active then
    return
  end
  state.active = false
  view.close()
  sound.stop()
  -- 書く用ウィンドウは書くためだけのものなので、モードを抜けたら閉じる（未保存なら確認する）
  if in_window() then
    vim.schedule(function()
      vim.cmd("confirm qall")
    end)
  end
end

function M.toggle()
  if state.active then
    M.disable()
  else
    M.enable()
  end
end

---@param name string
function M.set_mood(name)
  if not M.config.moods[name] then
    notify(("ムード `%s` はありません（%s）"):format(name, table.concat(mood_names(), ", ")), vim.log.levels.ERROR)
    return
  end
  state.mood = name
  save_mood(name)
  if state.active then
    apply()
  else
    M.enable()
  end
end

function M.select_mood()
  vim.ui.select(mood_names(), {
    prompt = "Mood",
    format_item = function(name)
      return ("%s  %s"):format(M.config.moods[name].label or name, name)
    end,
  }, function(name)
    if name then
      M.set_mood(name)
    end
  end)
end

---@param on boolean
function M.set_sound(on)
  state.sound = on
  apply_sound()
end

---@param choices string[]
local function complete(choices)
  return function(lead)
    return vim.tbl_filter(function(c)
      return vim.startswith(c, lead)
    end, choices)
  end
end

---@param opts? yohaku.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  -- リストは要素ごとに混ざらないよう、指定されたものでまるごと置き換える
  if opts and opts.ghostty and opts.ghostty.font_family then
    M.config.ghostty.font_family = opts.ghostty.font_family
  end
  state.mood = load_mood()
  state.sound = M.config.sound.enabled

  vim.api.nvim_create_user_command("Writing", function(cmd)
    local action = ({ [""] = M.toggle, toggle = M.toggle, on = M.enable, off = M.disable })[cmd.args]
    if not action then
      return notify("使い方: :Writing [on|off|toggle]", vim.log.levels.ERROR)
    end
    action()
  end, { nargs = "?", complete = complete({ "on", "off", "toggle" }), desc = "ライティングモード" })

  vim.api.nvim_create_user_command("Mood", function(cmd)
    if cmd.args == "" then
      M.select_mood()
    else
      M.set_mood(cmd.args)
    end
  end, {
    nargs = "?",
    complete = function(lead)
      return complete(mood_names())(lead)
    end,
    desc = "ライティングモードのムードを選ぶ",
  })

  vim.api.nvim_create_user_command("WritingSound", function(cmd)
    local on = ({ [""] = not state.sound, toggle = not state.sound, on = true, off = false })[cmd.args]
    if on == nil then
      return notify("使い方: :WritingSound [on|off|toggle]", vim.log.levels.ERROR)
    end
    M.set_sound(on)
  end, { nargs = "?", complete = complete({ "on", "off", "toggle" }), desc = "環境音の切り替え" })

  local group = vim.api.nvim_create_augroup("yohaku", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      sound.stop()
      if in_window() then
        ghostty.cleanup(M.config.ghostty)
      end
    end,
  })

  -- 書く用ウィンドウの中では、起動したらすぐライティングモードにする
  if in_window() then
    -- ふだんの Neovim も同じファイルを開いているので、スワップファイルの警告を出さない
    vim.opt.shortmess:append("A")
    -- 書く用ウィンドウを赤いボタンなどで閉じると Neovim が強制終了され、スワップファイルが残る。
    -- 残ったスワップファイルがあると、ふだんの Neovim で開いたときに確認が出て、既定の
    -- 「読み取り専用で開く」を選ぶと保存できなくなるので、スワップファイルは作らない。
    -- 代わりに書いた内容はこまめに自動保存する
    vim.o.swapfile = false
    local function save(buf)
      if
        vim.api.nvim_buf_is_valid(buf)
        and vim.bo[buf].buftype == ""
        and vim.bo[buf].modified
        and not vim.bo[buf].readonly
        and vim.api.nvim_buf_get_name(buf) ~= ""
      then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("silent! update")
        end)
      end
    end
    vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost" }, {
      group = group,
      callback = function(ev)
        save(ev.buf)
      end,
    })
    -- 入力中は、手が 1 秒止まったら保存する
    local pending = 0
    vim.api.nvim_create_autocmd("TextChangedI", {
      group = group,
      callback = function(ev)
        pending = pending + 1
        local mine = pending
        vim.defer_fn(function()
          if mine == pending then
            save(ev.buf)
          end
        end, 1000)
      end,
    })
    if M.config.moods[vim.env.YOHAKU_MOOD or ""] then
      state.mood = vim.env.YOHAKU_MOOD
    end
    if vim.v.vim_did_enter == 1 then
      M.enable()
    else
      vim.api.nvim_create_autocmd("VimEnter", { group = group, once = true, callback = M.enable })
    end
  end
end

return M
