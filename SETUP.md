# SETUP — rebuild from scratch

This file documents every customization that was layered on top of upstream
[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim). Use it if you
ever lose this fork and need to recreate it by hand.

## 0. Prerequisites (host-level, RHEL 8.10 example)

- **Neovim 0.12+**. RHEL 8's glibc 2.28 can't run the official `neovim/neovim`
  nightly tarball — use [`neovim/neovim-releases`](https://github.com/neovim/neovim-releases)
  which ships glibc-aware builds. Place under `~/apps/nvim-linux64/` and put
  `~/apps/nvim-linux64/bin` on `PATH`.
- **`tree-sitter` CLI** — required because `nvim-treesitter`'s `main` branch
  (which kickstart now pins) compiles parsers from source.
  - `rustc ≥ 1.87` needed; if older, `rustup update stable` first.
  - On RHEL 8 bindgen needs explicit clang includes:
    ```bash
    BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/gcc/x86_64-redhat-linux/8/include -I/usr/include" \
      cargo install tree-sitter-cli --locked
    ```
- **`claude` CLI** (optional) — installed at `~/.local/bin/claude` for the
  `claudecode.nvim` plugin. Without it, the claudecode integration loads
  but `:ClaudeCode` won't start anything.

## 1. Start from upstream kickstart

```bash
git clone https://github.com/nvim-lua/kickstart.nvim.git ~/.config/nvim
```

## 2. Plugins added on top of upstream

All added via `vim.pack.add { gh '<repo>' }` in [`init.lua`](init.lua) (in the
existing plugins section, roughly between the gitsigns block and the treesitter
block). See the file for current line numbers.

| Plugin | Purpose | Setup notes |
|---|---|---|
| `nvim-tree/nvim-tree.lua` | File-tree sidebar | `view.side = 'left'`, `width = 30`, `git icons off`, `git_ignored = false` (show ignored), `highlight_git = 'name'` (grey them), `update_focused_file.enable = true` (sidebar auto-tracks the focused buffer), `on_attach` override to remap `<C-t>` → `ToggleTerm`, disable netrw before loading |
| `akinsho/bufferline.nvim` | Top buffer bar | `diagnostics = 'nvim_lsp'`, offset for NvimTree, `custom_filter` hides unnamed `[No Name]` buffers |
| `sindrets/diffview.nvim` | Git diff viewer | Default setup |
| `akinsho/toggleterm.nvim` | Togglable terminal | `direction = 'float'` (95% size, rounded border), `start_in_insert = true`. No `open_mapping` — `<C-t>` is a custom dispatcher (see below) |
| `github/copilot.vim` | Copilot AI suggestions | No setup() needed (vimscript plugin). One-time `:Copilot setup` after install |
| `lukas-reineke/indent-blankline.nvim` | Indent guides | `require('ibl').setup{}` |
| `Vimjas/vim-python-pep8-indent` | Better Python indent | No setup; takes effect via ftplugin |
| `folke/snacks.nvim` | Required by claudecode for terminal UI | `require('snacks').setup{}` |
| `coder/claudecode.nvim` | Claude Code integration | Default setup; keymaps registered manually |

## 3. LSP / formatter changes

- `vim.g.have_nerd_font` flipped to `true`.
- `basedpyright` added to the `servers` table (instead of `pyright` — pyright
  needs `npm` which isn't on the HPC, basedpyright installs via Mason with pip).
- Custom basedpyright settings to silence the noisiest strict checks:

  ```lua
  basedpyright = {
    settings = {
      basedpyright = {
        analysis = {
          typeCheckingMode = 'standard',
          diagnosticSeverityOverrides = {
            reportAny = 'none',
            reportExplicitAny = 'none',
            reportImplicitOverride = 'none',
            reportUnusedCallResult = 'none',
            reportMissingTypeStubs = 'none',
            reportUnknownArgumentType = 'none',
            reportUnknownMemberType = 'none',
            reportUnknownVariableType = 'none',
            reportUnknownParameterType = 'none',
            reportMissingParameterType = 'none',
          },
        },
      },
    },
  },
  ```

## 4. Treesitter

- Extended parsers list to: `bash, c, diff, html, lua, luadoc, markdown,
  markdown_inline, query, vim, vimdoc, python, javascript, typescript, tsx,
  json, yaml, css, rust, java`.
- Disabled treesitter indent for Python (vim-python-pep8-indent handles it):

  ```lua
  if has_indent_query and language ~= 'python' then
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
  ```

## 5. UI customizations

- **Soft-wrap on by default**: `vim.opt.wrap = true`, `linebreak = true`,
  `showbreak = '↪  '`. Plus `j/k/$/^/0` remapped to their `g`-prefixed versions
  in normal + visual mode.
- **which-key**: switched to `preset = 'modern'`. Registered groups for
  `<leader>a` (AI / Claude), `<leader>g` (Git), `<leader>s` (Search),
  `<leader>t` (Trouble / Toggle), `<leader>h` (Git Hunk).
  `triggers` restricted to `{ '<leader>', mode = { 'n', 'v' } }` and
  `delay = 500` so the popup never fires on mode-entry, mouse-driven
  visual mode, or idle pauses — only when `<leader>` is explicitly held.
- **Claude pane styling**: darker `Normal` background (`#0d0e16`) for the
  Claude buffer via a `ClaudeBg` highlight group and `winhighlight` set in a
  `BufWinEnter` + `TermOpen` autocmd, so the pane visually separates from the
  tokyonight editor background.
- **`vim.g.have_nerd_font = true`** to enable icons across nvim-tree,
  bufferline, which-key, and statusline. Requires a Nerd Font on the terminal.

## 6. Keymaps added

```lua
-- VS-Code-style comment toggle (terminals send Ctrl+/ as <C-_>)
vim.keymap.set('n', '<C-_>', 'gcc', { remap = true })
vim.keymap.set('v', '<C-_>', 'gc',  { remap = true })

-- Smart split resize (LunarVim-style chord). The arrow direction is *where the
-- controlled boundary moves*. We use win_move_separator / win_move_statusline
-- so the boundary moves directly without Vim picking which neighbor.
-- <C-Left>/<C-Right>:  current window's right edge (or its left edge if rightmost)
-- <C-Up>/<C-Down>:     current window's bottom edge (or top edge if bottommost)
-- See init.lua for the full helper function.

-- File tree
vim.keymap.set('n', '<leader>e', '<cmd>NvimTreeToggle<cr>')
vim.keymap.set('n', '<leader>o', '<cmd>NvimTreeFocus<cr>')

-- Bufferline
vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>')
vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>')

-- Smart close current buffer (skips non-file buffers, validates before delete)
vim.keymap.set('n', '<leader>c', function()
  local cur = vim.api.nvim_get_current_buf()
  if vim.bo[cur].buftype ~= '' then return end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= cur and vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted then
      vim.cmd 'bprevious'
      break
    end
  end
  if vim.api.nvim_buf_is_valid(cur) then vim.api.nvim_buf_delete(cur, {}) end
end)

-- Diffview
vim.keymap.set('n', '<leader>gd', '<cmd>DiffviewOpen<cr>')
vim.keymap.set('n', '<leader>gc', '<cmd>DiffviewClose<cr>')
vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory %<cr>')
vim.keymap.set('n', '<leader>gH', '<cmd>DiffviewFileHistory<cr>')

-- Claude Code (full set under <leader>a*)
-- <leader>ac toggle, <leader>af focus, <leader>ar resume, <leader>aC continue,
-- <leader>am select model, <leader>ab add buffer, <leader>as send/tree-add,
-- <leader>aa accept diff, <leader>ad deny diff
```

## 6b. Terminal dispatcher (`<C-t>`)

`<C-t>` is not bound to ToggleTerm directly. Instead a `_G.TermToggle(slot)`
dispatcher (init.lua) routes by `vim.v.count`:

- `{count}<C-t>` toggles that numbered terminal; bare `<C-t>` reopens the
  last-used slot.
- **Slot 2 is reserved for claudecode.nvim** — `2<C-t>` calls
  `require('claudecode.terminal').simple_toggle{ snacks_win_opts = { position =
  'float', width = 0.95, height = 0.95, border = 'rounded' } }`, giving Claude a
  floating window instead of the sidebar.
- Every other slot is a normal ToggleTerm terminal (`{slot}ToggleTerm`).
- A terminal-mode `<C-t>` toggles whichever terminal you're currently inside
  (Claude buffer → claude float; otherwise the ToggleTerm with that
  `toggle_number`).

`<leader>ac` still opens Claude in the right **sidebar**; the float route is
`2<C-t>`.

## 7. Claude pane autocmds

Inside `TermOpen`, when the buffer is Claude's terminal (filetype `claudecode`
or buffer name contains `claude`):

- `<C-q>` (terminal mode) → exit to normal mode
- `<M-q>` (terminal mode) → close the Claude pane
- `q` (normal mode) → close the Claude pane
- `<leader>al` (normal mode) → force redraw both nvim and Claude TUI (`^L` to PTY)
- `:q` cabbrev → expands to `ClaudeCodeClose` so accidental quits hide the pane
  instead of killing the window
- `TermClose` autocmd → auto-wipes the buffer when the Claude process exits

Plus a `VimResized` autocmd that calls `:redraw!` to keep TUIs in sync.

## 7b. Auto-reload buffers when files change on disk

For workflows where Claude (or any external process) edits files while nvim is
open, `autoread` alone isn't enough — Vim only checks the on-disk timestamp on
certain events. We poll on idle + focus + buffer entry:

```lua
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
  pattern = '*',
  callback = function() if vim.fn.mode() ~= 'c' then vim.cmd 'checktime' end end,
})
vim.api.nvim_create_autocmd('FileChangedShellPost', {
  pattern = '*',
  callback = function() vim.notify('File reloaded from disk', vim.log.levels.INFO) end,
})
```

Caveat: if you have *unsaved* changes in the buffer when the file is also
edited on disk, Vim still shows the `W12` conflict prompt because no setting
can decide what to do in that case.

## 8. Untracked → tracked

- Removed `nvim-pack-lock.json` from `.gitignore`. The lockfile is committed so
  plugin versions are pinned across machines. See `:help vim.pack-lockfile`.

## 9. Outside this repo

- `~/.tmux.conf` — appended `set-option -ga terminal-overrides ",*:RGB"` so
  truecolor works inside tmux.
- `~/apps/nvim-linux64/` is the Neovim 0.12+ install (0.10.2 backed up as
  `~/apps/nvim-linux64-0-10-2/`).
- `~/.cargo/bin/tree-sitter` — the CLI used by nvim-treesitter (built with
  `BINDGEN_EXTRA_CLANG_ARGS` on RHEL 8, see prerequisites).

## 10. Rebuild order if everything is gone

1. Install Neovim 0.12+, tree-sitter CLI, claude CLI (per prerequisites).
2. `git clone git@github.com:ngocbh/kickstart.nvim.git ~/.config/nvim`.
3. `nvim` — vim.pack auto-installs everything from `nvim-pack-lock.json`.
4. `:Mason` and confirm `lua-language-server`, `basedpyright`, `stylua` are
   installed. If not: `:MasonInstall basedpyright stylua lua-language-server`.
5. (Optional) `:Copilot setup` to auth Copilot.

You're back.
