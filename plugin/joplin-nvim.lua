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

vim.api.nvim_create_user_command("JoplinTag", function()
  require("joplin.nvim").tag()
end, { desc = "Manage tags on the current Joplin note" })

vim.api.nvim_create_user_command("JoplinTags", function()
  require("joplin.nvim").tags()
end, { desc = "Browse notes by tag" })

vim.api.nvim_create_user_command("JoplinTodos", function()
  require("joplin.nvim").todos()
end, { desc = "Browse Joplin todos" })

vim.api.nvim_create_user_command("JoplinConvertTodo", function()
  require("joplin.nvim").convert_todo()
end, { desc = "Convert note to todo or todo to note" })

vim.api.nvim_create_user_command("JoplinToggleTodo", function()
  require("joplin.nvim").toggle_todo()
end, { desc = "Toggle todo completion on the current note" })

vim.api.nvim_create_user_command("JoplinNewNote", function()
  require("joplin.nvim").new_note()
end, { desc = "Create a new Joplin note" })

vim.api.nvim_create_user_command("JoplinNewTodo", function()
  require("joplin.nvim").new_todo()
end, { desc = "Create a new Joplin todo" })

vim.api.nvim_create_user_command("JoplinMove", function()
  require("joplin.nvim").move()
end, { desc = "Move the current note to a different notebook" })

vim.api.nvim_create_user_command("JoplinLink", function()
  require("joplin.nvim").link()
end, { desc = "Insert a link to another Joplin note" })

vim.api.nvim_create_user_command("JoplinFollowLink", function()
  require("joplin.nvim").follow_link()
end, { desc = "Follow the Joplin link under cursor" })

vim.api.nvim_create_user_command("JoplinPasteImage", function()
  require("joplin.nvim").paste_image()
end, { desc = "Paste clipboard image as Joplin attachment" })

vim.api.nvim_create_user_command("JoplinDelete", function()
  require("joplin.nvim").delete()
end, { desc = "Delete the current Joplin note" })
