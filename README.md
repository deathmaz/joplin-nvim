# joplin.nvim

A Neovim plugin for [Joplin](https://joplinapp.org) that uses [fzf-lua](https://github.com/ibhagwan/fzf-lua) as its picker interface.

Browse, search, create, edit, and delete Joplin notes without leaving Neovim.

## Requirements

- Neovim 0.10+
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- `curl`
- Joplin desktop app running with Web Clipper enabled

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-user/joplin.nvim",
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
})
```

### Getting your API token

1. Open Joplin desktop
2. Go to **Tools > Options > Web Clipper**
3. Enable the Web Clipper service
4. Copy the API token

## Commands

| Command | Description |
|---|---|
| `:Joplin` | Browse all notes with fzf-lua |
| `:JoplinSearch [query]` | Search notes using Joplin's full-text search (searches inside note bodies) |
| `:JoplinNotebook` | Pick a notebook, then browse its notes |
| `:JoplinNew` | Create a new note (picks notebook, then prompts for title) |
| `:JoplinDelete` | Delete the note in the current buffer |

## Picker keybindings

### Notes picker (`:Joplin`, `:JoplinSearch`, `:JoplinNotebook`)

| Key | Action |
|---|---|
| `Enter` | Open the selected note |
| `ctrl-n` | Create a new note (with notebook selection) |
| `ctrl-x` | Delete the selected note |

### Notebook picker (`:JoplinNotebook`, `:JoplinNew`, `ctrl-n` in notes picker)

| Key | Action |
|---|---|
| `Enter` | Select the notebook |
| `ctrl-n` | Create a new notebook |
| `ctrl-x` | Delete the selected notebook |

## How it works

- Notes are opened in Neovim buffers with `buftype=acwrite` and `filetype=markdown`, so treesitter highlighting and markdown LSP work normally.
- Saving with `:w` syncs the buffer content back to Joplin via its REST API.
- Running `:e` on an open note re-fetches the content from Joplin.
- Buffer names use the `joplin://` scheme (e.g. `joplin://abc123/My-Note.md`).

## License

MIT
