local config = require("joplin.nvim.config")

local M = {}

local NOTE_FIELDS = "id,title,updated_time,parent_id,is_todo,todo_completed"
local NOTE_FIELDS_WITH_BODY = NOTE_FIELDS .. ",body"

--- URL-encode a string value
---@param str string
---@return string
local function url_encode(str)
  str = tostring(str)
  str = str:gsub("([^%w%-_.~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return str
end

--- Build a full URL with query parameters
---@param path string
---@param params? table<string, string|number>
---@return string
local function build_url(path, params)
  local cfg = config.get()
  local url = cfg.base_url .. path
  local query_parts = { "token=" .. url_encode(cfg.token or "") }
  if params then
    for k, v in pairs(params) do
      table.insert(query_parts, url_encode(k) .. "=" .. url_encode(v))
    end
  end
  return url .. "?" .. table.concat(query_parts, "&")
end

--- Build curl arguments for a request
---@param method string
---@param url string
---@param json_body? string
---@return string[]
local function build_curl_args(method, url, json_body)
  local args = { "curl", "-s", "-m", "10" }
  if method ~= "GET" then
    table.insert(args, "-X")
    table.insert(args, method)
  end
  if json_body then
    table.insert(args, "-H")
    table.insert(args, "Content-Type: application/json")
    table.insert(args, "-d")
    table.insert(args, json_body)
  end
  table.insert(args, url)
  return args
end

--- Parse a curl response
---@param obj vim.SystemCompleted
---@return string? err
---@return table? data
local function parse_response(obj)
  if obj.code ~= 0 then
    return "curl failed (exit code " .. obj.code .. "): " .. (obj.stderr or ""), nil
  end
  if not obj.stdout or obj.stdout == "" then
    return nil, {}
  end
  local ok, decoded = pcall(vim.json.decode, obj.stdout)
  if not ok then
    return "JSON decode error: " .. tostring(decoded), nil
  end
  if decoded.error then
    return "Joplin API error: " .. tostring(decoded.error), nil
  end
  return nil, decoded
end

--- Make an HTTP request to the Joplin API.
--- If callback is provided, runs async. Otherwise runs sync and returns (err, data).
---@param method string
---@param path string
---@param params? table<string, string|number>
---@param body? table
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M._request(method, path, params, body, callback)
  local url = build_url(path, params)
  local json_body = body and vim.json.encode(body) or nil
  local args = build_curl_args(method, url, json_body)

  if callback then
    vim.system(args, { text = true }, function(obj)
      vim.schedule(function()
        local err, data = parse_response(obj)
        callback(err, data)
      end)
    end)
  else
    local obj = vim.system(args, { text = true }):wait()
    return parse_response(obj)
  end
end

--- Health check: GET /ping
---@param callback? fun(err: string?, data: string?)
function M.ping(callback)
  local cfg = config.get()
  local url = cfg.base_url .. "/ping"
  local args = { "curl", "-s", "-m", "5", url }

  if callback then
    vim.system(args, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          callback("curl failed", nil)
        else
          callback(nil, obj.stdout)
        end
      end)
    end)
  else
    local obj = vim.system(args, { text = true }):wait()
    if obj.code ~= 0 then
      return "curl failed", nil
    end
    return nil, obj.stdout
  end
end

--- List notes (paginated)
---@param page? number
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M.list_notes(page, callback)
  return M._request("GET", "/notes", {
    fields = NOTE_FIELDS,
    order_by = "updated_time",
    order_dir = "DESC",
    page = page or 1,
    limit = config.get().page_size,
  }, nil, callback)
end

--- Get a single note with body
---@param id string
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M.get_note(id, callback)
  return M._request("GET", "/notes/" .. id, {
    fields = NOTE_FIELDS_WITH_BODY,
  }, nil, callback)
end

--- Update a note
---@param id string
---@param data table
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M.update_note(id, data, callback)
  return M._request("PUT", "/notes/" .. id, nil, data, callback)
end

--- Create a note
---@param data table
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M.create_note(data, callback)
  return M._request("POST", "/notes", nil, data, callback)
end

--- Delete a note
---@param id string
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M.delete_note(id, callback)
  return M._request("DELETE", "/notes/" .. id, nil, nil, callback)
end

--- List all folders/notebooks (paginated)
---@param page? number
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M.list_folders(page, callback)
  return M._request("GET", "/folders", {
    fields = "id,title,parent_id",
    page = page or 1,
    limit = config.get().page_size,
  }, nil, callback)
end

--- Create a folder/notebook
---@param data table
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M.create_folder(data, callback)
  return M._request("POST", "/folders", nil, data, callback)
end

--- Delete a folder/notebook
---@param id string
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M.delete_folder(id, callback)
  return M._request("DELETE", "/folders/" .. id, nil, nil, callback)
end

--- List notes in a specific folder/notebook
---@param folder_id string
---@param page? number
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M.list_folder_notes(folder_id, page, callback)
  return M._request("GET", "/folders/" .. folder_id .. "/notes", {
    fields = NOTE_FIELDS,
    order_by = "updated_time",
    order_dir = "DESC",
    page = page or 1,
    limit = config.get().page_size,
  }, nil, callback)
end

--- Search notes
---@param query string
---@param page? number
---@param callback? fun(err: string?, data: table?)
---@return string? err
---@return table? data
function M.search(query, page, callback)
  return M._request("GET", "/search", {
    query = query,
    fields = NOTE_FIELDS,
    order_by = "updated_time",
    order_dir = "DESC",
    page = page or 1,
    limit = config.get().page_size,
  }, nil, callback)
end

return M
