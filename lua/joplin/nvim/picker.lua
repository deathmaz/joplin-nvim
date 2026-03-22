local api = require("joplin.nvim.api")
local buffer = require("joplin.nvim.buffer")

local M = {}

local FZF_OPTS = {
  ["--delimiter"] = "\t",
  ["--with-nth"] = "2..",
  ["--ansi"] = "",
}

---@param entry string
---@return string
local function extract_id(entry)
  return entry:match("^([^\t]+)")
end

--- Extract id from fzf selected array, with guards
---@param selected string[]?
---@return string?
local function selected_id(selected)
  if not selected or #selected == 0 then
    return nil
  end
  return extract_id(selected[1])
end

--- Fetch all pages of a paginated API synchronously
---@param fetch_fn fun(page: number): string?, table?
---@return table[]
local function fetch_all_sync(fetch_fn)
  local all = {}
  local page = 1
  while true do
    local err, result = fetch_fn(page)
    if err or not result then
      break
    end
    local items = result.items or result
    for _, item in ipairs(items) do
      table.insert(all, item)
    end
    if not result.has_more then
      break
    end
    page = page + 1
  end
  return all
end

-- Notebook lookup: parent_id -> title (refreshed per picker session)
local notebook_map = {}

local function refresh_notebook_map()
  notebook_map = {}
  local folders = fetch_all_sync(function(page)
    return api.list_folders(page)
  end)
  for _, folder in ipairs(folders) do
    notebook_map[folder.id] = folder.title or "(untitled)"
  end
end

local fzf_utils = require("fzf-lua.utils")

---@param item table
---@return string
local function format_folder_entry(item)
  return item.id .. "\t" .. (item.title or "(untitled)")
end

local function format_entry(item)
  local title = item.title or "(untitled)"
  local notebook = notebook_map[item.parent_id] or ""
  local prefix = ""
  if item.is_todo == 1 then
    local icon = (item.todo_completed and item.todo_completed ~= 0) and "✅ " or "⬜ "
    prefix = icon
  end
  if notebook ~= "" then
    return item.id .. "\t" .. prefix .. fzf_utils.ansi_codes.green(notebook) .. " > " .. fzf_utils.ansi_codes.yellow(title)
  end
  return item.id .. "\t" .. prefix .. fzf_utils.ansi_codes.yellow(title)
end

--- Build a paginated async fzf content source
---@param fetch_fn fun(page: number, cb: fun(err: string?, data: table?))
---@param formatter? fun(item: table): string
---@return fun(cb: fun(entry?: string))
local function paginated_source(fetch_fn, formatter)
  formatter = formatter or format_entry
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
          cb(formatter(item))
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

--- Confirm and delete a resource via the API
---@param prompt string
---@param delete_fn fun(): string?
---@param success_msg string
---@return boolean
local function confirm_delete(prompt, delete_fn, success_msg)
  local confirm = vim.fn.confirm(prompt, "&Yes\n&No", 2)
  if confirm ~= 1 then
    return false
  end
  local err = delete_fn()
  if err then
    vim.notify("[joplin.nvim] Delete failed: " .. err, vim.log.levels.ERROR)
    return false
  end
  vim.notify("[joplin.nvim] " .. success_msg, vim.log.levels.INFO)
  return true
end

---@param note_id string
---@return boolean
function M.confirm_delete_note(note_id)
  return confirm_delete("Delete this note?", function()
    return api.delete_note(note_id)
  end, "Note deleted")
end

local function action_open(selected)
  local note_id = selected_id(selected)
  if note_id then
    buffer.open(note_id)
  end
end

local function action_delete(selected)
  local note_id = selected_id(selected)
  if note_id then
    M.confirm_delete_note(note_id)
  end
end

--- Create a note or todo in a folder and open it
---@param folder_id? string
---@param opts? { is_todo?: boolean }
function M.create_in_folder(folder_id, opts)
  opts = opts or {}
  local kind = opts.is_todo and "todo" or "note"
  local title = vim.fn.input("New " .. kind .. " title: ")
  if title == "" then
    return
  end
  local data = { title = title, body = "" }
  if opts.is_todo then
    data.is_todo = 1
  end
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

--- Toggle todo completion status
---@param note_id string
---@return boolean success
function M.toggle_todo(note_id)
  local err, note = api.get_note(note_id)
  if err or not note then
    vim.notify("[joplin.nvim] Failed to load note: " .. (err or ""), vim.log.levels.ERROR)
    return false
  end
  if note.is_todo ~= 1 then
    vim.notify("[joplin.nvim] This note is not a todo", vim.log.levels.WARN)
    return false
  end
  local new_completed = (note.todo_completed and note.todo_completed ~= 0) and 0
    or (os.time() * 1000)
  local update_err = api.update_note(note_id, { todo_completed = new_completed })
  if update_err then
    vim.notify("[joplin.nvim] Toggle failed: " .. update_err, vim.log.levels.ERROR)
    return false
  end
  local status = new_completed ~= 0 and "completed" or "incomplete"
  vim.notify("[joplin.nvim] Todo marked " .. status, vim.log.levels.INFO)
  return true
end

--- Convert a note to a todo or a todo to a note
---@param note_id string
---@return boolean success
function M.convert_todo(note_id)
  local err, note = api.get_note(note_id)
  if err or not note then
    vim.notify("[joplin.nvim] Failed to load note: " .. (err or ""), vim.log.levels.ERROR)
    return false
  end
  local new_is_todo = note.is_todo == 1 and 0 or 1
  local update_err = api.update_note(note_id, { is_todo = new_is_todo, todo_completed = 0 })
  if update_err then
    vim.notify("[joplin.nvim] Convert failed: " .. update_err, vim.log.levels.ERROR)
    return false
  end
  local kind = new_is_todo == 1 and "todo" or "note"
  vim.notify("[joplin.nvim] Converted to " .. kind, vim.log.levels.INFO)
  return true
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

--- Move a note to a different notebook
---@param note_id string
function M.move_note(note_id)
  M.pick_notebook(function(folder_id)
    if not folder_id then
      return
    end
    local err = api.update_note(note_id, { parent_id = folder_id })
    if err then
      vim.notify("[joplin.nvim] Move failed: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("[joplin.nvim] Note moved", vim.log.levels.INFO)
    end
  end)
end

---@param note_id string
function M.manage_note_tags(note_id)
  local all_tags = fetch_all_sync(function(page)
    return api.list_tags(page)
  end)

  local err_note, note_tags_result = api.get_note_tags(note_id)
  if err_note or not note_tags_result then
    vim.notify("[joplin.nvim] Failed to load note tags: " .. (err_note or ""), vim.log.levels.ERROR)
    return
  end
  local note_tags = note_tags_result.items or note_tags_result

  local current = {}
  for _, tag in ipairs(note_tags) do
    current[tag.id] = true
  end

  table.sort(all_tags, function(a, b)
    local a_sel = current[a.id] and 0 or 1
    local b_sel = current[b.id] and 0 or 1
    if a_sel ~= b_sel then
      return a_sel < b_sel
    end
    return (a.title or ""):lower() < (b.title or ""):lower()
  end)

  local entries = {}
  for _, tag in ipairs(all_tags) do
    local prefix = current[tag.id] and "[x]" or "[ ]"
    table.insert(entries, tag.id .. "\t" .. prefix .. " " .. tag.title)
  end

  local fzf_lua = require("fzf-lua")
  fzf_lua.fzf_exec(entries, {
    prompt = "Tags (enter=toggle)> ",
    fzf_opts = vim.tbl_extend("force", FZF_OPTS, { ["--multi"] = "" }),
    actions = {
      ["default"] = function(selected)
        if not selected then
          return
        end
        for _, sel in ipairs(selected) do
          local tag_id = extract_id(sel)
          if tag_id then
            if current[tag_id] then
              local err = api.untag_note(tag_id, note_id)
              if err then
                vim.notify("[joplin.nvim] Untag failed: " .. err, vim.log.levels.ERROR)
              end
            else
              local err = api.tag_note(tag_id, note_id)
              if err then
                vim.notify("[joplin.nvim] Tag failed: " .. err, vim.log.levels.ERROR)
              end
            end
          end
        end
        vim.notify("[joplin.nvim] Tags updated", vim.log.levels.INFO)
      end,
      ["alt-n"] = function()
        local title = vim.fn.input("New tag name: ")
        if title == "" then
          return
        end
        local err, tag = api.create_tag({ title = title })
        if err then
          vim.notify("[joplin.nvim] Create tag failed: " .. err, vim.log.levels.ERROR)
          return
        end
        if tag then
          local tag_err = api.tag_note(tag.id, note_id)
          if tag_err then
            vim.notify("[joplin.nvim] Tag failed: " .. tag_err, vim.log.levels.ERROR)
          else
            vim.notify("[joplin.nvim] Created and applied tag: " .. title, vim.log.levels.INFO)
          end
        end
      end,
    },
  })
end

local function action_manage_tags(selected)
  local note_id = selected_id(selected)
  if note_id then
    M.manage_note_tags(note_id)
  end
end

local function action_move(selected)
  local note_id = selected_id(selected)
  if note_id then
    M.move_note(note_id)
  end
end

--- Open a note picker with standard actions
---@param source fun(cb: fun(entry?: string))
---@param opts { prompt: string, actions?: table }
local function note_picker(source, opts)
  refresh_notebook_map()
  local fzf_lua = require("fzf-lua")
  local actions = vim.tbl_extend("force", {
    ["default"] = action_open,
    ["ctrl-x"] = action_delete,
    ["ctrl-t"] = action_manage_tags,
    ["alt-m"] = action_move,
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
  end, format_folder_entry), {
    prompt = "Notebook> ",
    fzf_opts = FZF_OPTS,
    actions = {
      ["default"] = function(selected)
        local folder_id = selected_id(selected)
        if folder_id then
          on_select(folder_id)
        end
      end,
      ["ctrl-x"] = function(selected)
        local folder_id = selected_id(selected)
        if folder_id then
          confirm_delete("Delete this notebook and all its notes?", function()
            return api.delete_folder(folder_id)
          end, "Notebook deleted")
        end
      end,
      ["alt-n"] = function()
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

--- Pick a note and return its id and title via callback
---@param on_select fun(note_id: string, title: string)
function M.pick_note_for_link(on_select)
  refresh_notebook_map()
  local fzf_lua = require("fzf-lua")

  fzf_lua.fzf_exec(paginated_source(function(page, cb)
    api.list_notes(page, cb)
  end), {
    prompt = "Link to> ",
    previewer = get_previewer(),
    fzf_opts = FZF_OPTS,
    actions = {
      ["default"] = function(selected)
        local note_id = selected_id(selected)
        if not note_id then return end
        local err, note = api.get_note_metadata(note_id)
        if err or not note then return end
        on_select(note_id, note.title or "untitled")
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
      ["alt-n"] = function()
        M.pick_notebook(function(folder_id)
          M.create_in_folder(folder_id)
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
        ["alt-n"] = function()
          M.create_in_folder(folder_id)
        end,
      },
    })
  end)
end

function M.tags()
  local fzf_lua = require("fzf-lua")

  fzf_lua.fzf_exec(paginated_source(function(page, cb)
    api.list_tags(page, cb)
  end, format_folder_entry), {
    prompt = "Tag> ",
    fzf_opts = FZF_OPTS,
    actions = {
      ["default"] = function(selected)
        local tag_id = selected_id(selected)
        if not tag_id then
          return
        end
        note_picker(paginated_source(function(page, cb)
          api.list_tag_notes(tag_id, page, cb)
        end), {
          prompt = "Tagged Notes> ",
        })
      end,
      ["alt-n"] = function()
        local title = vim.fn.input("New tag name: ")
        if title == "" then
          return
        end
        local err = api.create_tag({ title = title })
        if err then
          vim.notify("[joplin.nvim] Create tag failed: " .. err, vim.log.levels.ERROR)
        else
          vim.notify("[joplin.nvim] Tag created: " .. title, vim.log.levels.INFO)
        end
      end,
      ["ctrl-x"] = function(selected)
        local tag_id = selected_id(selected)
        if tag_id then
          confirm_delete("Delete this tag?", function()
            return api.delete_tag(tag_id)
          end, "Tag deleted")
        end
      end,
    },
  })
end

function M.todos()
  note_picker(paginated_source(function(page, cb)
    api.search("type:todo", page, cb)
  end), {
    prompt = "Todos> ",
    actions = {
      ["ctrl-d"] = function(selected)
        local note_id = selected_id(selected)
        if note_id then
          M.toggle_todo(note_id)
        end
      end,
      ["alt-n"] = function()
        M.pick_notebook(function(folder_id)
          M.create_in_folder(folder_id, { is_todo = true })
        end)
      end,
    },
  })
end

return M
