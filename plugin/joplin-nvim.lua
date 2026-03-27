vim.api.nvim_create_user_command("Joplin", function()
  require("joplin").browse()
end, { desc = "Browse Joplin notes" })

vim.api.nvim_create_user_command("JoplinSearch", function(args)
  local query = args.args ~= "" and args.args or nil
  require("joplin").search({ query = query })
end, { nargs = "?", desc = "Search Joplin notes" })

vim.api.nvim_create_user_command("JoplinNotebook", function()
  require("joplin").notebook()
end, { desc = "Browse notes in a notebook" })

vim.api.nvim_create_user_command("JoplinTag", function()
  require("joplin").tag()
end, { desc = "Manage tags on the current Joplin note" })

vim.api.nvim_create_user_command("JoplinTags", function()
  require("joplin").tags()
end, { desc = "Browse notes by tag" })

vim.api.nvim_create_user_command("JoplinTodos", function()
  require("joplin").todos()
end, { desc = "Browse Joplin todos" })

vim.api.nvim_create_user_command("JoplinConvertTodo", function()
  require("joplin").convert_todo()
end, { desc = "Convert note to todo or todo to note" })

vim.api.nvim_create_user_command("JoplinToggleTodo", function()
  require("joplin").toggle_todo()
end, { desc = "Toggle todo completion on the current note" })

vim.api.nvim_create_user_command("JoplinNewNote", function()
  require("joplin").new_note()
end, { desc = "Create a new Joplin note" })

vim.api.nvim_create_user_command("JoplinNewTodo", function()
  require("joplin").new_todo()
end, { desc = "Create a new Joplin todo" })

vim.api.nvim_create_user_command("JoplinNewNotebook", function()
  require("joplin").new_notebook()
end, { desc = "Create a new Joplin notebook" })

vim.api.nvim_create_user_command("JoplinRename", function()
  require("joplin").rename()
end, { desc = "Rename the current Joplin note" })

vim.api.nvim_create_user_command("JoplinMove", function()
  require("joplin").move()
end, { desc = "Move the current note to a different notebook" })

vim.api.nvim_create_user_command("JoplinLink", function()
  require("joplin").link()
end, { desc = "Insert a link to another Joplin note" })

vim.api.nvim_create_user_command("JoplinFollowLink", function()
  require("joplin").follow_link()
end, { desc = "Follow the Joplin link under cursor" })

vim.api.nvim_create_user_command("JoplinPasteImage", function()
  require("joplin").paste_image()
end, { desc = "Paste clipboard image as Joplin attachment" })

vim.api.nvim_create_user_command("JoplinDelete", function()
  require("joplin").delete()
end, { desc = "Delete the current Joplin note" })
