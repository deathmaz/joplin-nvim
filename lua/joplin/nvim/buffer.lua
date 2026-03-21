local api = require("joplin.nvim.api")

local M = {}

--- Maps note_id -> bufnr
local note_bufs = {}
--- Maps bufnr -> note_id
local buf_notes = {}

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
end

return M
