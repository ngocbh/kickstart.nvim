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
| `nvim-tree/nvim-tree.lua` | File-tree sidebar | `view.side = 'left'`, `width = 30`, `git icons off`, `git_ignored = false` (show ignored), `highlight_git = 'name'` (grey them), `update_focused_file.enable = true` (sidebar auto-tracks the focused buffer), `on_attach` override to remap `<C-t>` → terminal toggle, disable netrw before loading |
| `akinsho/bufferline.nvim` | Top buffer bar | `diagnostics = 'nvim_lsp'`, offset for NvimTree, `custom_filter` hides unnamed `[No Name]` buffers |
| `sindrets/diffview.nvim` | Git diff viewer | Default setup |
| `github/copilot.vim` | Copilot AI suggestions | No setup() needed (vimscript plugin). One-time `:Copilot setup` after install |
| `lukas-reineke/indent-blankline.nvim` | Indent guides | `require('ibl').setup{}` |
| `Vimjas/vim-python-pep8-indent` | Better Python indent | No setup; takes effect via ftplugin |
| `folke/snacks.nvim` | Terminal UI (the `<C-t>` dispatcher) + required by claudecode | `require('snacks').setup{}`. Replaced `toggleterm.nvim` — the `<C-t>` dispatcher now uses `Snacks.terminal`, keyed by `count` (see below) |
| `coder/claudecode.nvim` | Claude Code integration | `terminal_cmd = 'claude --dangerously-skip-permissions'` (so the embedded Claude never stops to ask); keymaps registered manually |

## 3. LSP / formatter changes

- `vim.g.have_nerd_font` flipped to `true`.
- `pyright` is the Python LSP in the `servers` table. ⚠️ pyright installs via
  Mason using `npm`/Node — make sure Node is on the host. This fork originally
  used `basedpyright` (pip-installable via Mason) because the target HPC has no
  `npm`; if pyright won't install there, switch back to basedpyright.
- pyright settings trim the noisiest checks:

  ```lua
  pyright = {
    settings = {
      python = {
        analysis = {
          typeCheckingMode = 'standard',
          diagnosticSeverityOverrides = {
            reportMissingTypeStubs = 'none',
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
-- <leader>ac COPY @-mention to clipboard (file:line / selection / tree node, via
--   _G.ClaudeCopyMention — paste into any other Claude Code; does NOT toggle),
-- <leader>af focus, <leader>ar resume, <leader>aC continue,
-- <leader>am select model, <leader>ab add buffer, <leader>as send/tree-add,
-- <leader>aa accept diff, <leader>ad deny diff
```

## 6b. Terminal dispatcher (`<C-t>`)

`<C-t>` is bound to a `_G.TermToggle(slot)` dispatcher (init.lua) that routes by
`vim.v.count`. Terminals are backed by `Snacks.terminal` (no dedicated terminal
plugin — Snacks is already a claudecode dependency):

- `{count}<C-t>` switches to terminal #count via `_G.TermGoto(slot)`, which hides
  the current terminal float first (so floats don't stack) then toggles the target
  open. Bare `<C-t>` toggles the last-used slot. Snacks keys terminals by `count`,
  so each slot is its own persistent terminal. Floats are 95% size (same as the
  Claude float), rounded border; identity is shown by the tab bar (see below).
- **Slot 2 is reserved for claudecode.nvim** — `2<C-t>` calls
  `require('claudecode.terminal').simple_toggle{ snacks_win_opts = { position =
  'float', width = 0.95, height = 0.95, border = 'rounded', wo = { winbar = … } } }`,
  giving Claude a floating window instead of the sidebar.
- Every other slot is a `Snacks.terminal.toggle(nil, { count = slot, win = {...} })`.
- A terminal-mode `<C-t>` hides whichever terminal you're currently inside (counts
  don't work in terminal mode — drop to normal mode for `{count}<C-t>` to switch).
- Terminal mode is exited with either `<Esc><Esc>` (kickstart default) or `<C-q>`.
  `<C-q>` is mapped globally (section 1) so the same key works in the Claude TUI,
  where `<Esc>`/`<Esc><Esc>` are taken by Claude's own interrupt/rewind bindings.

### Terminal tab bar (bufferline-style winbar)

Every terminal float carries a `winbar` set to `%!v:lua.TermWinbar()` (passed via
each float's `win.wo`, and `snacks_win_opts.wo` for the Claude float). `%!` makes
Neovim re-evaluate it on every redraw, so the bar stays current as terminals
open/close. It sits on its own row at the top of the float, just under the border,
and looks like the editor's bufferline: a filled bar of tabs `[1] Term`, `[2] Claude`, ….

- `_G.TermWinbar()` builds the bar from `term_open_slots()` (which walks
  `Snacks.terminal.list()`, maps each buffer to its slot via `term_slot_of` —
  `vim.b[buf].snacks_terminal.id`, with the claudecode pane pinned to slot 2),
  highlighting the focused tab (resolved from `vim.g.statusline_winid`).
- **Claude detection is decoupled from the slot.** `term_is_claude_pane()` matches
  only the dedicated claudecode.nvim pane (slot 2). `term_running_claude()` is the
  broader check used for the label: it is true for the pane *and* for any ordinary
  Snacks terminal currently running the `claude` CLI — detected by the terminal title
  (`b:term_title` contains "claude") or filetype. So launching `claude` in slot 1/3/…
  relabels that tab `[N] Claude` (keeping its real slot number).
- Tabs are **clickable**: each is wrapped in a `%<slot>@v:lua.TermBarClick@…%X` click
  region. `_G.TermBarClick(slot)` → `_G.TermGoto(slot)`, which hides the current
  terminal float (so floats don't stack) then toggles the target open. `{count}<C-t>`
  switches the same way.
- Highlights are explicit tokyonight-night colors (not links) so the bar has its own
  background, distinct from the terminal output: `TermBarActive` is a blue chip
  (`#7aa2f7` bg), `TermBarInactive` / `TermBarFill` are a dim `#292e42` strip.
- The Claude tab is **no longer colored by run-state** — the focused tab is the blue
  `TermBarActive` chip, every other tab (Claude or not) is the grey `TermBarInactive`
  chip. The orange/red state coloring, the `term_claude_state()` poll, and the tmux
  window-tab mirroring were removed (see the note at the end of this section).
- **Vertical right bar while editing.** `rbar_refresh()` (alias `_G.TermRbarRefresh`)
  draws a small floating box on the right edge (`relative=editor`, `anchor=NE`,
  `row=1`, `col=columns`): a padded, centered cell per terminal labelled `1T` / `2C`
  (slot + Term/Claude) as a 1-row chip, with a plain dark gap between chips (none
  before the first or after the last); width = longest label + 2, height = 2·terminals
  − 1. Palette: a dark panel/gap `TermRbarFill` (`#16161e`) with neutral chips
  `TermRbarTerm` (`#292e42`). Colors applied via per-line extmarks; the float background
  is `Normal:TermRbarFill`. Each cell is **clickable**: a global `<LeftMouse>` handler
  checks `getmousepos()` against the bar window, maps the clicked row to its slot via
  `rbar.line_slot`, and calls `_G.TermGoto` (passing the click through unchanged when it
  lands elsewhere). You can also switch with `{count}<C-t>`. It hides when the focused
  buffer is a terminal (the float's winbar shows the full bar) or when no terminals are
  open. Refreshed on `WinEnter`/`BufWinEnter`/`WinClosed`/`TermClose`/`VimResized`/
  `TabEnter`/`CmdlineLeave`. Caveat: being a float, it overlays the rightmost columns of
  editor content rather than reserving space.
- Helpers `term_is_claude_pane`, `term_running_claude`, `term_slot_of`,
  `term_open_slots`, `term_hide_buf`, `rbar_refresh`, and `_G.TermGoto` (init.lua) back
  the bar, the `{count}<C-t>` switch, and the terminal-mode `<C-t>` (which calls
  `term_hide_buf`).

> **Claude run-state coloring moved out to tmux.** The 500 ms poll (`term_claude_state`
> scraping the Claude TUI footer), the orange/red `TermBarClaude*` tab + rbar colors,
> the on-state-change `^L` auto-repaint, and the mirroring of state onto nvim's tmux
> window tab via `window-status-style` (`tmux_notify`) were all **removed** from
> init.lua. Claude's run-state is now surfaced by the standalone
> [`claude-tmux`](https://github.com/ngocbh/claude-tmux) package (repo
> `~/workspace/claude-tmux`; installs scripts to `~/.local/bin`, a tmux snippet, and
> `~/.claude/settings.json` hooks) — a tmux window-tab tint + a status-right chip driven
> by Claude Code hooks, for **any** Claude running in tmux. Don't re-add the nvim
> poll/mirroring: both set `window-status-style` and would fight.

`<leader>ac` no longer opens Claude — it **copies a `@`-mention to the clipboard**
(`_G.ClaudeCopyMention`): the current file+line (normal), the selected range
(visual, `#L<start>-<end>`), or the NvimTree node under the cursor. The path is
cwd-relative when under cwd / absolute otherwise, matching the format
claudecode.nvim sends over its websocket — so it pastes cleanly into any other
Claude Code (e.g. another tmux pane). Toggling Claude is now `2<C-t>` (float).

## 7. Claude pane autocmds

Inside `TermOpen`, when the buffer is Claude's terminal (filetype `claudecode`
or buffer name contains `claude`):

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
4. `:Mason` and confirm `lua-language-server`, `pyright`, `stylua` are
   installed. If not: `:MasonInstall pyright stylua lua-language-server`
   (pyright needs Node/`npm` on the host).
5. (Optional) `:Copilot setup` to auth Copilot.

You're back.
