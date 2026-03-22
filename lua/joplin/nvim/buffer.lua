local api = require("joplin.nvim.api")
local config = require("joplin.nvim.config")

local M = {}

--- Maps note_id -> bufnr
local note_bufs = {}
--- Maps bufnr -> note_id
local buf_notes = {}
--- Cache: parent_id -> notebook title
local notebook_cache = {}

--- Extract note_id from a joplin:// buffer name
---@param bufname string
---@return string?
function M.id_from_bufname(bufname)
  return bufname:match("^joplin://([^/]+)")
end

---@param bufnr number
---@param note_id string
local function track(bufnr, note_id)
  note_bufs[note_id] = bufnr
  buf_notes[bufnr] = note_id
  vim.api.nvim_create_autocmd("BufUnload", {
    buffer = bufnr,
    callback = function()
      note_bufs[note_id] = nil
      buf_notes[bufnr] = nil
    end,
  })
  -- gd: follow Joplin note link under cursor
  vim.keymap.set("n", "gd", function()
    require("joplin.nvim").follow_link()
  end, { buffer = bufnr, desc = "Follow Joplin link" })

  -- Winbar autocmd: created once per buffer, reads value from buffer variable
  vim.api.nvim_create_autocmd("BufWinEnter", {
    buffer = bufnr,
    callback = function()
      if not config.get().winbar then
        return
      end
      local wb = vim.b[bufnr].joplin_winbar
      if wb then
        vim.wo[vim.api.nvim_get_current_win()].winbar = wb
      end
    end,
  })
end

---@param parent_id? string
---@return string
local function resolve_notebook(parent_id)
  if not parent_id or parent_id == "" then
    return "(no notebook)"
  end
  if notebook_cache[parent_id] then
    return notebook_cache[parent_id]
  end
  local err, folder = api.get_folder(parent_id)
  if err or not folder then
    return "(unknown)"
  end
  local name = folder.title or "(untitled)"
  notebook_cache[parent_id] = name
  return name
end

---@param note table
---@return boolean
local function is_completed(note)
  return note.is_todo == 1 and (note.todo_completed or 0) ~= 0
end

---@param bufnr number
---@param note table
---@param notebook_name string
local function set_metadata(bufnr, note, notebook_name)
  vim.b[bufnr].joplin_note_id = note.id
  vim.b[bufnr].joplin_title = note.title or "untitled"
  vim.b[bufnr].joplin_notebook = notebook_name
  vim.b[bufnr].joplin_type = note.is_todo == 1 and "todo" or "note"
  vim.b[bufnr].joplin_todo_completed = is_completed(note)
end

---@param note table
---@param notebook_name string
---@return string
local function build_winbar(note, notebook_name)
  local title = note.title or "untitled"
  if note.is_todo == 1 then
    local icon = is_completed(note) and "✅" or "⬜"
    return notebook_name .. "  >  " .. icon .. " " .. title
  end
  return notebook_name .. "  >  " .. title
end

--- Update winbar on all windows showing this buffer
---@param bufnr number
---@param winbar string
local function apply_winbar(bufnr, winbar)
  -- Store in buffer var so BufWinEnter autocmd can read it
  vim.b[bufnr].joplin_winbar = winbar
  if not config.get().winbar then
    return
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      vim.wo[win].winbar = winbar
    end
  end
end

---@param bufnr number
---@param note table
local function apply_note_info(bufnr, note)
  local notebook_name = resolve_notebook(note.parent_id)
  set_metadata(bufnr, note, notebook_name)
  apply_winbar(bufnr, build_winbar(note, notebook_name))
end

--- Refresh metadata and winbar for a note if it has an open buffer
---@param note_id string
function M.refresh_note(note_id)
  local bufnr = note_bufs[note_id]
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local err, note = api.get_note_metadata(note_id)
  if err or not note then
    return
  end
  apply_note_info(bufnr, note)
end

-- Fields that affect displayed metadata (winbar, buffer vars).
-- Body-only updates (e.g. :w saves) skip the refresh.
local METADATA_KEYS = {
  is_todo = true, todo_completed = true, parent_id = true, title = true,
}

local function has_metadata_change(data)
  for k in pairs(data) do
    if METADATA_KEYS[k] then
      return true
    end
  end
  return false
end

-- Wrap api.update_note to auto-refresh buffer info when metadata changes.
-- Only triggers for updates that modify displayed fields (not body-only saves).
local _original_update_note = api.update_note
api.update_note = function(id, data, callback)
  if not has_metadata_change(data) then
    return _original_update_note(id, data, callback)
  end
  -- Invalidate notebook cache if parent changed
  if data.parent_id then
    notebook_cache[data.parent_id] = nil
  end
  if callback then
    return _original_update_note(id, data, function(err, result)
      if not err then
        vim.schedule(function() M.refresh_note(id) end)
      end
      callback(err, result)
    end)
  end
  local err, result = _original_update_note(id, data)
  if not err then
    M.refresh_note(id)
  end
  return err, result
end

-- Global autocmd: reload content on :e for joplin:// buffers
vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = "joplin://*",
  callback = function(ev)
    local note_id = M.id_from_bufname(ev.file)
    if not note_id then
      return
    end
    if not buf_notes[ev.buf] then
      track(ev.buf, note_id)
    end
    local err, note = api.get_note(note_id)
    if err then
      vim.notify("[joplin.nvim] Reload failed: " .. err, vim.log.levels.ERROR)
      return
    end
    if not note then
      return
    end
    local lines = vim.split(note.body or "", "\n")
    vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, lines)
    vim.bo[ev.buf].buftype = "acwrite"
    vim.bo[ev.buf].filetype = "markdown"
    vim.bo[ev.buf].modified = false
    apply_note_info(ev.buf, note)
  end,
})

---@param title string
---@return string
local function sanitize(title)
  local s = title:gsub("[^%w%-_. ]", "-")
  s = s:gsub("%s+", "-")
  s = s:gsub("%-+", "-")
  s = s:gsub("^%-", ""):gsub("%-$", "")
  if #s > 50 then
    s = s:sub(1, 50)
  end
  if s == "" then
    s = "untitled"
  end
  return s
end

---@param bufnr number
function M._save(bufnr)
  local note_id = buf_notes[bufnr]
  if not note_id then
    vim.notify("[joplin.nvim] No note associated with this buffer", vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local body = table.concat(lines, "\n")

  local err = api.update_note(note_id, { body = body })
  if err then
    vim.notify("[joplin.nvim] Save failed: " .. err, vim.log.levels.ERROR)
  else
    vim.bo[bufnr].modified = false
    vim.notify("[joplin.nvim] Saved to Joplin", vim.log.levels.INFO)
  end
end

---@param note_id string
function M.open(note_id)
  local existing = note_bufs[note_id]
  if existing and vim.api.nvim_buf_is_valid(existing) then
    vim.api.nvim_set_current_buf(existing)
    return
  end

  local err, note = api.get_note(note_id)
  if err then
    vim.notify("[joplin.nvim] Failed to load note: " .. err, vim.log.levels.ERROR)
    return
  end
  if not note then
    vim.notify("[joplin.nvim] Note not found", vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_create_buf(true, false)
  local safe_title = sanitize(note.title or "untitled")
  vim.api.nvim_buf_set_name(bufnr, "joplin://" .. note_id .. "/" .. safe_title .. ".md")

  local lines = vim.split(note.body or "", "\n")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].modified = false

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      M._save(bufnr)
    end,
  })

  track(bufnr, note_id)
  vim.api.nvim_set_current_buf(bufnr)
  apply_note_info(bufnr, note)
end

return M
