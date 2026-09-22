-- 書く用の Ghostty ウィンドウ。
-- Ghostty の設定はアプリ全体で共通なので、書く用の設定だけを持つ Ghostty を別プロセスで起動する。
-- ふだんの Ghostty には一切影響しない。
--
--   window-<id>.conf  起動時だけ使う設定（最初に開くコマンド、環境変数、閉じたら終了する等）
--   mood-<id>.conf    見た目の設定。ムードを変えたら書き換えて、この Ghostty にだけ SIGUSR2 を送る
local M = {}

local HEADER = "# yohaku.nvim が作った書く用ウィンドウの設定（このウィンドウの Ghostty にだけ効く）"
local APP = "/Applications/Ghostty.app"

local function write(path, lines)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(lines, path)
end

-- /bin/sh 用に 1 引数としてクォートする（パスに空白が含まれてもよいように）
local function sh_quote(s)
  return "'" .. s:gsub("'", [['\'']]) .. "'"
end

---@param dir string
---@param id string
local function paths(dir, id)
  return { window = ("%s/window-%s.conf"):format(dir, id), mood = ("%s/mood-%s.conf"):format(dir, id) }
end

function M.available()
  return vim.fn.isdirectory(APP) == 1
end

---@param mood yohaku.Mood
---@param opts table `config.ghostty`
---@param colors {fg: string, dim: string}
local function mood_lines(mood, opts, colors)
  local lines = { HEADER }
  local function set(key, value)
    if value ~= nil then
      table.insert(lines, ("%s = %s"):format(key, tostring(value)))
    end
  end
  if mood.image then
    set("background-image", ('"%s"'):format(vim.fn.expand(mood.image)))
    set("background-image-fit", "cover")
  end
  set("background", mood.bg)
  set("cursor-color", colors.fg)
  if opts.font_family then
    set("font-family", '""') -- ふだんのフォント指定をいったん消してから並べ直す
    for _, family in ipairs(opts.font_family) do
      set("font-family", ('"%s"'):format(family))
    end
  end
  set("font-size", opts.font_size)
  set("font-thicken", opts.font_thicken)
  set("font-thicken-strength", opts.font_thicken_strength)
  set("adjust-cell-width", opts.cell_width)
  set("adjust-cell-height", opts.cell_height)
  return lines
end

-- 書く用ウィンドウを開き、その中の Neovim で file をライティングモードで開く
---@param file string
---@param mood_name string
---@param mood yohaku.Mood
---@param opts table `config.ghostty`
---@param colors {fg: string, dim: string}
function M.launch(file, mood_name, mood, opts, colors)
  local id = tostring(os.time()) .. "-" .. vim.fn.getpid()
  local p = paths(opts.dir, id)
  local nvim = vim.fn.exepath("nvim")
  if nvim == "" then
    nvim = vim.v.progpath
  end
  write(p.mood, mood_lines(mood, opts, colors))
  write(p.window, {
    HEADER,
    ("initial-command = shell:%s %s"):format(sh_quote(nvim), sh_quote(file)),
    ('working-directory = "%s"'):format(vim.fn.getcwd()),
    "env = YOHAKU_WINDOW=" .. id,
    "env = YOHAKU_MOOD=" .. mood_name,
    -- open で起動した Ghostty は PATH が最小限なので、今の PATH を引き継ぐ
    ('env = "PATH=%s"'):format(vim.env.PATH or ""),
    "quit-after-last-window-closed = true",
    "window-save-state = never",
    "background-opacity = 1", -- ふだんの半透明は macOS では起動時にしか変えられないが、別プロセスなので効く
    ("window-padding-y = %s"):format(opts.padding_y),
    ('config-file = "%s"'):format(p.mood),
  })
  vim.system({ "open", "-na", APP, "--args", "--config-file=" .. p.window }, {}, function(res)
    if res.code ~= 0 then
      vim.schedule(function()
        vim.notify("書く用のウィンドウを開けませんでした\n" .. (res.stderr or ""), vim.log.levels.ERROR, { title = "yohaku" })
      end)
    end
  end)
end

-- 書く用ウィンドウの中から呼ぶ。見た目を書き換えて、このウィンドウの Ghostty にだけ読み直させる
---@param mood yohaku.Mood
---@param opts table `config.ghostty`
---@param colors {fg: string, dim: string}
function M.update(mood, opts, colors)
  local id = vim.env.YOHAKU_WINDOW
  local p = paths(opts.dir, id)
  write(p.mood, mood_lines(mood, opts, colors))
  -- 起動引数に自分の設定ファイルを持つ Ghostty を探す（ほかの Ghostty には送らない）
  local ps = vim.system({ "ps", "-axo", "pid=,command=" }, { text = true }):wait()
  local needle = "--config-file=" .. p.window
  for line in (ps.stdout or ""):gmatch("[^\n]+") do
    local pid, command = line:match("^%s*(%d+)%s+(.*)$")
    if pid and command:find(needle, 1, true) and command:find("Ghostty", 1, true) then
      -- Ghostty は SIGUSR2 で設定を読み直す（ほかのシグナルは送らないこと）
      vim.uv.kill(tonumber(pid), "sigusr2")
    end
  end
end

-- 書く用ウィンドウを閉じるときに、そのウィンドウ用の設定ファイルを消す
---@param opts table `config.ghostty`
function M.cleanup(opts)
  local p = paths(opts.dir, vim.env.YOHAKU_WINDOW)
  vim.fn.delete(p.window)
  vim.fn.delete(p.mood)
end

return M
