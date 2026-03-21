local api = require("joplin.nvim.api")
local buffer = require("joplin.nvim.buffer")

local M = {}

local FZF_OPTS = {
  ["--delimiter"] = "\t",
  ["--with-nth"] = "2..",
}

---@param entry string
---@return string
local function extract_id(entry)
  return entry:match("^([^\t]+)")
end

---@param item table
---@return string
local function format_entry(item)
  return item.id .. "\t" .. (item.title or "(untitled)")
end

--- Build a paginated async fzf content source
---@param fetch_fn fun(page: number, cb: fun(err: string?, data: table?))
---@return fun(cb: fun(entry?: string))
local function paginated_source(fetch_fn)
  return function(cb)
    local page = 1
    local function fetch_page()
      fetch_fn(page, function(err, result)
        if err or not result then
          cb()
          return
        end
        local items = result.items or result
        for _, item in ipairs(items) do
          cb(format_entry(item))
        end
        if result.has_more then
          page = page + 1
          fetch_page()
        else
          cb()
        end
      end)
    end
    fetch_page()
  end
end

-- Shared note actions
local function action_open(selected)
  if not selected or #selected == 0 then
    return
  end
  local note_id = extract_id(selected[1])
  if note_id then
    buffer.open(note_id)
  end
end

--- Confirm-and-delete a note, returns true on success
---@param note_id string
---@return boolean
function M.confirm_delete_note(note_id)
  local confirm = vim.fn.confirm("Delete this note?", "&Yes\n&No", 2)
  if confirm ~= 1 then
    return false
  end
  local err = api.delete_note(note_id)
  if err then
    vim.notify("[joplin.nvim] Delete failed: " .. err, vim.log.levels.ERROR)
    return false
  end
  vim.notify("[joplin.nvim] Note deleted", vim.log.levels.INFO)
  return true
end

local function action_delete(selected)
  if not selected or #selected == 0 then
    return
  end
  local note_id = extract_id(selected[1])
  if note_id then
    M.confirm_delete_note(note_id)
  end
end

--- Create a note in a folder and open it
---@param folder_id? string
function M.create_note_in_folder(folder_id)
  local title = vim.fn.input("New note title: ")
  if title == "" then
    return
  end
  local data = { title = title, body = "" }
  if folder_id then
    data.parent_id = folder_id
  end
  local err, note = api.create_note(data)
  if err then
    vim.notify("[joplin.nvim] Create failed: " .. err, vim.log.levels.ERROR)
    return
  end
  if note then
    buffer.open(note.id)
  end
end

-- Lazily created previewer class (created once, reused across picker sessions)
local JoplinPreviewer

local function get_previewer()
  if JoplinPreviewer then
    return JoplinPreviewer
  end
  local builtin = require("fzf-lua.previewer.builtin")
  JoplinPreviewer = builtin.base:extend()

  function JoplinPreviewer:new(o, opts, fzf_win)
    JoplinPreviewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, JoplinPreviewer)
    self._cache = {}
    return self
  end

  function JoplinPreviewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()
    local note_id = extract_id(entry_str)
    if not note_id then
      return
    end

    if self._cache[note_id] then
      vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, self._cache[note_id])
      vim.bo[tmpbuf].filetype = "markdown"
      self:set_preview_buf(tmpbuf)
      self.win:update_scrollbar()
      return
    end

    vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, { "Loading..." })
    self:set_preview_buf(tmpbuf)

    api.get_note(note_id, function(err, note)
      if err or not note then
        return
      end
      local lines = vim.split(note.body or "", "\n")
      self._cache[note_id] = lines
      if not self.win or not self.win:validate_preview() then
        return
      end
      local buf = self:get_tmp_buffer()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].filetype = "markdown"
      self:set_preview_buf(buf)
      self.win:update_scrollbar()
    end)
  end

  function JoplinPreviewer:gen_winopts()
    return vim.tbl_extend("force", self.winopts, { wrap = true, number = false })
  end

  return JoplinPreviewer
end

--- Open a note picker with standard actions
---@param source fun(cb: fun(entry?: string))
---@param opts { prompt: string, actions?: table }
local function note_picker(source, opts)
  local fzf_lua = require("fzf-lua")
  local actions = vim.tbl_extend("force", {
    ["default"] = action_open,
    ["ctrl-x"] = action_delete,
  }, opts.actions or {})

  fzf_lua.fzf_exec(source, {
    prompt = opts.prompt,
    previewer = get_previewer(),
    fzf_opts = FZF_OPTS,
    actions = actions,
  })
end

---@param on_select fun(folder_id: string?)
function M.pick_notebook(on_select)
  local fzf_lua = require("fzf-lua")

  fzf_lua.fzf_exec(paginated_source(function(page, cb)
    api.list_folders(page, cb)
  end), {
    prompt = "Notebook> ",
    fzf_opts = FZF_OPTS,
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        on_select(extract_id(selected[1]))
      end,
      ["ctrl-x"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        local folder_id = extract_id(selected[1])
        if not folder_id then
          return
        end
        local confirm = vim.fn.confirm("Delete this notebook and all its notes?", "&Yes\n&No", 2)
        if confirm == 1 then
          local err = api.delete_folder(folder_id)
          if err then
            vim.notify("[joplin.nvim] Delete notebook failed: " .. err, vim.log.levels.ERROR)
          else
            vim.notify("[joplin.nvim] Notebook deleted", vim.log.levels.INFO)
          end
        end
      end,
      ["ctrl-n"] = function()
        local title = vim.fn.input("New notebook name: ")
        if title == "" then
          return
        end
        local err, folder = api.create_folder({ title = title })
        if err then
          vim.notify("[joplin.nvim] Create notebook failed: " .. err, vim.log.levels.ERROR)
          return
        end
        if folder then
          vim.notify("[joplin.nvim] Notebook created: " .. title, vim.log.levels.INFO)
          on_select(folder.id)
        end
      end,
    },
  })
end

function M.browse()
  note_picker(paginated_source(function(page, cb)
    api.list_notes(page, cb)
  end), {
    prompt = "Joplin Notes> ",
    actions = {
      ["ctrl-n"] = function()
        M.pick_notebook(function(folder_id)
          M.create_note_in_folder(folder_id)
        end)
      end,
    },
  })
end

---@param opts? { query?: string }
function M.search(opts)
  opts = opts or {}
  local query = opts.query or vim.fn.input("Search Joplin: ")
  if query == "" then
    return
  end

  note_picker(paginated_source(function(page, cb)
    api.search(query, page, cb)
  end), {
    prompt = "Joplin Search [" .. query .. "]> ",
  })
end

function M.notebook()
  M.pick_notebook(function(folder_id)
    if not folder_id then
      return
    end
    note_picker(paginated_source(function(page, cb)
      api.list_folder_notes(folder_id, page, cb)
    end), {
      prompt = "Notebook Notes> ",
      actions = {
        ["ctrl-n"] = function()
          M.create_note_in_folder(folder_id)
        end,
      },
    })
  end)
end

return M
