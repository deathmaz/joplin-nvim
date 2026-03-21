local M = {}

local defaults = {
  token = nil,
  port = 41184,
  base_url = nil,
  page_size = 100,
  winbar = true,
}

local state = {}

function M.setup(opts)
  state = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  state.token = state.token or vim.env.JOPLIN_TOKEN
  state.base_url = state.base_url or ("http://localhost:" .. state.port)

  if not state.token then
    vim.notify(
      "[joplin.nvim] No token configured. Set JOPLIN_TOKEN env var or pass token in setup().",
      vim.log.levels.WARN
    )
  end
end

function M.get()
  return state
end

return M
