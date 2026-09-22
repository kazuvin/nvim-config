-- 環境音。macOS の afplay にはループ機能がないので、終わるたびに再生し直す
local M = {}

---@type {token: table, proc?: vim.SystemObj}?
local current = nil

function M.stop()
  local c = current
  current = nil
  if c and c.proc then
    c.proc:kill(15)
  end
end

---@param file? string
---@param volume number
function M.play(file, volume)
  M.stop()
  file = file and vim.fn.expand(file)
  if not file or vim.fn.filereadable(file) == 0 then
    return
  end
  if vim.fn.executable("afplay") == 0 then
    vim.notify("afplay が見つからないため、環境音は再生できません", vim.log.levels.WARN, { title = "yohaku" })
    return
  end

  -- 止めたあとや別の音に切り替えたあとに、古いループが再開しないための目印
  local token = {}
  current = { token = token }
  local function loop()
    if not current or current.token ~= token then
      return
    end
    current.proc = vim.system({ "afplay", "-v", tostring(volume), file }, {}, function(res)
      vim.schedule(function()
        -- 自分で止めたとき（シグナルで終了）以外の失敗は、再生を諦める
        if res.code ~= 0 and res.signal == 0 then
          if current and current.token == token then
            current = nil
          end
          vim.notify("環境音を再生できませんでした: " .. file, vim.log.levels.WARN, { title = "yohaku" })
          return
        end
        loop()
      end)
    end)
  end
  loop()
end

return M
