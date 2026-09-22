-- 本文の飾り。バッファは書き換えず、extmark で見た目だけ整える
--   * 段落の間に余白（virt_lines）を入れる。見出しの後は広めに空け、見出しレベル 1 の上も大きく空ける
--   * 見出しの `# ` を隠し、箇条書きの `- ` を「・」、引用の `> ` を縦線で表示する
local M = {}

local ns = vim.api.nvim_create_namespace("yohaku_decor")

-- バッファごとの、1 行目の上に足した空行の数
---@type table<integer, integer>
local top_fill = {}

local function is_heading(line)
  return line:match("^#+%s") ~= nil
end

-- 行ごとに余白を入れると崩れるもの（リスト・引用・表・コードの囲み）
local function is_block(line)
  return line:match("^%s*[-*+] ")
    or line:match("^%s*%d+[.)] ")
    or line:match("^%s*>")
    or line:match("^%s*|")
    or line:match("^%s*```")
end

local function gap_lines(n)
  local virt = {}
  for _ = 1, n do
    table.insert(virt, { { " ", "Normal" } })
  end
  return virt
end

---@alias yohaku.DecorOpts {paragraph_gap: integer, heading_gap: integer, h1_gap: integer}

-- 1 行目の上に足した空行は、Neovim では gg などで先頭に戻ると隠れてしまう（topfill が 0 に戻る）。
-- 先頭を表示しているときは、足した分がすべて見えるように戻す
---@param win integer
function M.show_top(win)
  local need = top_fill[vim.api.nvim_win_get_buf(win)] or 0
  if need == 0 then
    return
  end
  vim.api.nvim_win_call(win, function()
    local view = vim.fn.winsaveview()
    if view.topline == 1 and view.topfill < need then
      vim.fn.winrestview({ topline = 1, topfill = need })
    end
  end)
end

---@param buf integer
---@param opts yohaku.DecorOpts
local function render(buf, opts)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  top_fill[buf] = 0
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- 入力中に改行した直後の空行にも余白を入れる（1 文字目を打った瞬間に行が跳ねないように）
  local cursor_row
  if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" and vim.api.nvim_get_current_buf() == buf then
    cursor_row = vim.api.nvim_win_get_cursor(0)[1]
  end

  local in_code = false
  local in_front_matter = lines[1] == "---"
  for i, line in ipairs(lines) do
    local row = i - 1
    if in_front_matter then
      in_front_matter = not (i > 1 and line == "---")
    else
      if line:match("^%s*```") then
        in_code = not in_code
      end

      if not in_code then
        if line:match("^#%s") and opts.h1_gap > 0 then
          vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { virt_lines = gap_lines(opts.h1_gap), virt_lines_above = true })
          if row == 0 then
            top_fill[buf] = opts.h1_gap
          end
        end
        local marker = line:match("^#+%s+")
        if marker then
          vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { end_col = #marker, conceal = "" })
        end
        local indent, bullet = line:match("^(%s*)([-*+] )")
        if bullet then
          vim.api.nvim_buf_set_extmark(buf, ns, row, #indent, {
            virt_text = { { "・", "YohakuBullet" } },
            virt_text_pos = "overlay",
          })
        end
        local quote = line:match("^>%s?")
        if quote then
          vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
            virt_text = { { "│ ", "YohakuBullet" } },
            virt_text_pos = "overlay",
          })
        end

        local next_line = lines[i + 1]
        local gap = is_heading(line) and opts.heading_gap or opts.paragraph_gap
        if
          gap > 0
          and next_line
          and line:match("%S")
          and (next_line:match("%S") or i + 1 == cursor_row)
          and not is_block(line)
          and not is_block(next_line)
        then
          vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { virt_lines = gap_lines(gap) })
        end
      end
    end
  end
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    M.show_top(win)
  end
end

---@param buf integer
---@param opts yohaku.DecorOpts
function M.attach(buf, opts)
  local group = vim.api.nvim_create_augroup("yohaku_decor_" .. buf, { clear = true })
  local function update()
    if vim.api.nvim_buf_is_valid(buf) then
      render(buf, opts)
    end
  end
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertEnter" }, {
    group = group,
    buffer = buf,
    callback = update,
  })
  -- InsertLeave の時点ではまだ挿入モード扱いなので、抜けてから描き直す
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    buffer = buf,
    callback = function()
      vim.schedule(update)
    end,
  })
  update()
end

---@param buf integer
function M.detach(buf)
  pcall(vim.api.nvim_del_augroup_by_name, "yohaku_decor_" .. buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  top_fill[buf] = nil
end

return M
