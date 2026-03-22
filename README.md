# joplin.nvim

A Neovim plugin for [Joplin](https://joplinapp.org) that uses [fzf-lua](https://github.com/ibhagwan/fzf-lua) as its picker interface.

Browse, search, create, edit, and delete Joplin notes and todos without leaving Neovim.

## Requirements

- Neovim 0.10+
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- `curl`
- Joplin desktop app running with Web Clipper enabled

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "deathmaz/joplin-nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    require("joplin.nvim").setup({
      -- token = "your-api-token",  -- or set JOPLIN_TOKEN env var
      -- port = 41184,              -- default Joplin API port
    })
  end,
}
```

## Configuration

```lua
require("joplin.nvim").setup({
  token = nil,      -- API token (defaults to $JOPLIN_TOKEN env var)
  port = 41184,     -- Joplin Web Clipper port
  page_size = 100,  -- notes per API request (max 100)
  winbar = true,    -- show notebook/type info in winbar (set false to disable)
})
```

### Getting your API token

1. Open Joplin desktop
2. Go to **Tools > Options > Web Clipper**
3. Enable the Web Clipper service
4. Copy the API token

## Commands

### Browsing

| Command | Description |
|---|---|
| `:Joplin` | Browse all notes and todos |
| `:JoplinSearch [query]` | Search notes using Joplin's full-text search (searches inside note bodies) |
| `:JoplinNotebook` | Pick a notebook, then browse its notes |
| `:JoplinTags` | Pick a tag, then browse its notes |
| `:JoplinTodos` | Browse todos with completion status |

### Creating

| Command | Description |
|---|---|
| `:JoplinNewNote` | Create a new note (picks notebook, then prompts for title) |
| `:JoplinNewTodo` | Create a new todo (picks notebook, then prompts for title) |

### Managing (current buffer)

| Command | Description |
|---|---|
| `:JoplinDelete` | Delete the note in the current buffer |
| `:JoplinTag` | Manage tags on the current note (toggle on/off) |
| `:JoplinToggleTodo` | Toggle todo completion (incomplete/completed) |
| `:JoplinConvertTodo` | Convert note to todo or todo to note |
| `:JoplinMove` | Move the current note to a different notebook |
| `:JoplinLink` | Insert a link to another Joplin note at cursor |
| `:JoplinFollowLink` | Follow the Joplin link under cursor |
| `:JoplinPasteImage` | Paste clipboard image as Joplin attachment |

## Picker keybindings

### Notes picker (`:Joplin`, `:JoplinSearch`, `:JoplinNotebook`, `:JoplinTags`)

| Key | Action |
|---|---|
| `Enter` | Open the selected note |
| `alt-n` | Create a new note (with notebook selection) |
| `ctrl-x` | Delete the selected note |
| `ctrl-t` | Manage tags on the selected note |
| `alt-m` | Move the selected note to a different notebook |

### Todos picker (`:JoplinTodos`)

| Key | Action |
|---|---|
| `Enter` | Open the selected todo |
| `ctrl-d` | Toggle todo completion |
| `alt-n` | Create a new todo (with notebook selection) |
| `ctrl-x` | Delete the selected todo |
| `ctrl-t` | Manage tags on the selected todo |
| `alt-m` | Move the selected todo to a different notebook |

### Notebook picker (`:JoplinNotebook`, `:JoplinNewNote`, `:JoplinNewTodo`)

| Key | Action |
|---|---|
| `Enter` | Select the notebook |
| `alt-n` | Create a new notebook |
| `ctrl-x` | Delete the selected notebook |

### Tag picker (`:JoplinTags`)

| Key | Action |
|---|---|
| `Enter` | Browse notes with the selected tag |
| `alt-n` | Create a new tag |
| `ctrl-x` | Delete the selected tag |

### Tag manager (`:JoplinTag`, `ctrl-t` in notes picker)

| Key | Action |
|---|---|
| `Enter` | Toggle selected tag(s) on/off (supports multi-select) |
| `alt-n` | Create a new tag and apply it |

## How it works

- Notes are opened in Neovim buffers with `buftype=acwrite` and `filetype=markdown`, so treesitter highlighting and markdown LSP work normally.
- Saving with `:w` syncs the buffer content back to Joplin via its REST API.
- Running `:e` on an open note re-fetches the content from Joplin.
- Buffer names use the `joplin://` scheme (e.g. `joplin://abc123/My-Note.md`).
- Todos show `[x]`/`[ ]` completion status in all pickers.
- Picker entries show the notebook name (e.g. `My Notebook > Note Title`).
- **Note linking**: `:JoplinLink` inserts a `[title](:/id)` reference to another note. Press `gd` on a Joplin link to open the linked note.
- A **winbar** shows the notebook name and note type (e.g. `My Notebook  >  Note Title` or `My Notebook  >  ⬜ Todo Title`). Disable with `winbar = false` in setup.

### Buffer variables for statusline integration

When a Joplin note is open, these buffer-local variables are available:

| Variable | Type | Description |
|---|---|---|
| `vim.b.joplin_note_id` | string | The Joplin note ID |
| `vim.b.joplin_title` | string | Note title |
| `vim.b.joplin_notebook` | string | Notebook name |
| `vim.b.joplin_type` | string | `"note"` or `"todo"` |
| `vim.b.joplin_todo_completed` | boolean | Whether the todo is completed |

Example lualine component:

```lua
{
  function()
    return vim.b.joplin_notebook or ""
  end,
  cond = function() return vim.b.joplin_note_id ~= nil end,
}
```

## License

MIT
