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

function M.delete()
  local note_id = current_note_id()
  if not note_id then return end
  if require("joplin.nvim.picker").confirm_delete_note(note_id) then
    vim.api.nvim_buf_delete(vim.api.nvim_get_current_buf(), { force = true })
  end
end

return M
