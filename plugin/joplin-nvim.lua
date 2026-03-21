vim.api.nvim_create_user_command("Joplin", function()
  require("joplin.nvim").browse()
end, { desc = "Browse Joplin notes" })

vim.api.nvim_create_user_command("JoplinSearch", function(args)
  local query = args.args ~= "" and args.args or nil
  require("joplin.nvim").search({ query = query })
end, { nargs = "?", desc = "Search Joplin notes" })

vim.api.nvim_create_user_command("JoplinNotebook", function()
  require("joplin.nvim").notebook()
end, { desc = "Browse notes in a notebook" })

vim.api.nvim_create_user_command("JoplinNew", function()
  require("joplin.nvim").new()
end, { desc = "Create a new Joplin note" })

vim.api.nvim_create_user_command("JoplinDelete", function()
  require("joplin.nvim").delete()
end, { desc = "Delete the current Joplin note" })
