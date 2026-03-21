local config = require("joplin.nvim.config")

local M = {}

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

function M.new()
  require("joplin.nvim.picker").pick_notebook(function(folder_id)
    require("joplin.nvim.picker").create_note_in_folder(folder_id)
  end)
end

function M.delete()
  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local note_id = require("joplin.nvim.buffer").id_from_bufname(bufname)
  if not note_id then
    vim.notify("[joplin.nvim] Current buffer is not a Joplin note", vim.log.levels.WARN)
    return
  end
  if require("joplin.nvim.picker").confirm_delete_note(note_id) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

return M
