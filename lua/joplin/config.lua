local M = {}

local defaults = {
  token = nil,
  port = 41184,
  base_url = nil,
  page_size = 100,
  winbar = true,
}

local state = nil

function M.setup(opts)
  state = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  state.token = state.token or vim.env.JOPLIN_TOKEN
  state.base_url = state.base_url or ("http://localhost:" .. state.port)
end

function M.get()
  if not state then
    M.setup()
  end
  return state
end

return M
