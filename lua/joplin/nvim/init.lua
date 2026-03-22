local config = require("joplin.nvim.config")

local M = {}

--- Get note_id from current buffer, or nil with a warning
---@return string?
local function current_note_id()
  local bufname = vim.api.nvim_buf_get_name(0)
  local note_id = require("joplin.nvim.buffer").id_from_bufname(bufname)
  if not note_id then
    vim.notify("[joplin.nvim] Current buffer is not a Joplin note", vim.log.levels.WARN)
  end
  return note_id
end

--- Strip characters that break markdown link syntax
---@param text string
---@return string
local function sanitize_link_text(text)
  return text:gsub("[%]%)]", "")
end

---@param opts? table
function M.setup(opts)
  config.setup(opts)

  local api = require("joplin.nvim.api")
  api.ping(function(err, result)
    if err or not result or not result:match("JoplinClipperServer") then
      vim.notify(
        "[joplin.nvim] Cannot reach Joplin. Is the desktop app running with Web Clipper enabled?",
        vim.log.levels.WARN
      )
    end
  end)
end

function M.browse()
  require("joplin.nvim.picker").browse()
end

---@param opts? { query?: string }
function M.search(opts)
  require("joplin.nvim.picker").search(opts)
end

function M.notebook()
  require("joplin.nvim.picker").notebook()
end

function M.tags()
  require("joplin.nvim.picker").tags()
end

function M.tag()
  local note_id = current_note_id()
  if not note_id then return end
  require("joplin.nvim.picker").manage_note_tags(note_id)
end

function M.todos()
  require("joplin.nvim.picker").todos()
end

function M.toggle_todo()
  local note_id = current_note_id()
  if not note_id then return end
  require("joplin.nvim.picker").toggle_todo(note_id)
end

function M.convert_todo()
  local note_id = current_note_id()
  if not note_id then return end
  require("joplin.nvim.picker").convert_todo(note_id)
end

function M.move()
  local note_id = current_note_id()
  if not note_id then return end
  require("joplin.nvim.picker").move_note(note_id)
end

function M.new_note()
  require("joplin.nvim.picker").pick_notebook(function(folder_id)
    require("joplin.nvim.picker").create_in_folder(folder_id)
  end)
end

function M.new_todo()
  require("joplin.nvim.picker").pick_notebook(function(folder_id)
    require("joplin.nvim.picker").create_in_folder(folder_id, { is_todo = true })
  end)
end

--- Detect the clipboard image command for the current platform
---@return string[]?
local function clipboard_image_cmd()
  if vim.fn.has("mac") == 1 then
    return { "pngpaste", "-" }
  end
  if vim.env.WAYLAND_DISPLAY then
    return { "wl-paste", "--type", "image/png" }
  end
  return { "xclip", "-selection", "clipboard", "-t", "image/png", "-o" }
end

function M.paste_image()
  if not current_note_id() then return end

  local cmd = clipboard_image_cmd()
  local tmpfile = vim.fn.tempname() .. ".png"

  local result = vim.system(cmd, { text = false }):wait()
  if result.code ~= 0 or not result.stdout or #result.stdout == 0 then
    vim.notify("[joplin.nvim] No image in clipboard", vim.log.levels.WARN)
    return
  end

  local f = io.open(tmpfile, "wb")
  if not f then
    vim.notify("[joplin.nvim] Failed to write temp file", vim.log.levels.ERROR)
    return
  end
  local ok, write_err = pcall(function()
    f:write(result.stdout)
    f:close()
  end)
  if not ok then
    f:close()
    os.remove(tmpfile)
    vim.notify("[joplin.nvim] Failed to write temp file: " .. tostring(write_err), vim.log.levels.ERROR)
    return
  end

  local title = vim.fn.input("Image title (optional): ")
  if title == "" then
    title = "pasted-image-" .. os.date("%Y%m%d-%H%M%S")
  end

  local api = require("joplin.nvim.api")
  local err, resource = api.upload_resource(tmpfile, title)
  os.remove(tmpfile)

  if err then
    vim.notify("[joplin.nvim] Upload failed: " .. err, vim.log.levels.ERROR)
    return
  end
  if not resource or not resource.id then
    vim.notify("[joplin.nvim] Upload failed: no resource ID returned", vim.log.levels.ERROR)
    return
  end

  local safe_title = sanitize_link_text(title)
  local line = string.format("![%s](:/%s)", safe_title, resource.id)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, { line })
  vim.notify("[joplin.nvim] Image attached", vim.log.levels.INFO)
end

function M.link()
  if not current_note_id() then return end

  local picker = require("joplin.nvim.picker")
  picker.pick_note_for_link(function(note_id, note_title)
    local safe_title = sanitize_link_text(note_title)
    local link = string.format("[%s](:/%s)", safe_title, note_id)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local cur_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
    local new_line = cur_line:sub(1, col) .. link .. cur_line:sub(col + 1)
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
    vim.api.nvim_win_set_cursor(0, { row, col + #link })
  end)
end

function M.follow_link()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  local start = 1
  while true do
    local s, e, note_id = line:find("%[.-%]%(:/([%x]+)%)", start)
    if not s then break end
    if col >= s and col <= e then
      require("joplin.nvim.buffer").open(note_id)
      return
    end
    start = e + 1
  end

  vim.notify("[joplin.nvim] No Joplin link under cursor", vim.log.levels.WARN)
end

function M.delete()
  local note_id = current_note_id()
  if not note_id then return end
  if require("joplin.nvim.picker").confirm_delete_note(note_id) then
    vim.api.nvim_buf_delete(vim.api.nvim_get_current_buf(), { force = true })
  end
end

return M
