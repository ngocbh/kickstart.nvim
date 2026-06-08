# ngocbh's Neovim config

Personal fork of [nvim-lua/kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) with a LunarVim-flavoured workflow on top (file-tree sidebar, top buffer bar, Claude Code integration, Python tooling, etc).

Upstream kickstart's pedagogical README is preserved at [KICKSTART.md](KICKSTART.md).
A detailed "what was changed and why" log is at [SETUP.md](SETUP.md) — useful if you ever need to rebuild from scratch.

---

## Quick install on a new server

Tested on RHEL 8.10 (glibc 2.28). Adjust the Neovim download URL for your OS.

```bash
# 1. Clone the config
git clone git@github.com:ngocbh/kickstart.nvim.git ~/.config/nvim

# 2. Neovim 0.12+ (glibc-aware build for older RHEL/CentOS)
mkdir -p ~/apps && cd ~/apps
wget https://github.com/neovim/neovim-releases/releases/download/v0.12.2/nvim-linux-x86_64.tar.gz
tar -xzf nvim-linux-x86_64.tar.gz && mv nvim-linux-x86_64 nvim-linux64 && rm nvim-linux-x86_64.tar.gz
echo 'export PATH="$HOME/apps/nvim-linux64/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 3. tree-sitter CLI (parsers compile from source on first run; needs rustc 1.87+)
rustup update stable    # or install rustup first via https://rustup.rs
BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/gcc/x86_64-redhat-linux/8/include -I/usr/include" \
  cargo install tree-sitter-cli --locked

# 4. Claude Code CLI (optional, only if you want the claudecode.nvim plugin)
#    Follow https://docs.claude.com/en/docs/claude-code/setup ; the binary must
#    land somewhere on PATH (e.g. ~/.local/bin/claude).

# 5. First launch — vim.pack auto-installs plugins, Mason auto-installs LSPs.
nvim
```

On modern Linux (glibc ≥ 2.31), the official `neovim/neovim` nightly tarball works too — replace step 2's URL with the standard nightly release.

### What happens on first launch
- `vim.pack` clones every plugin into `~/.local/share/nvim/site/pack/core/opt/`
- `mason.nvim` installs the LSPs declared in [`init.lua`](init.lua) (`lua_ls`, `basedpyright`, `stylua`)
- `nvim-treesitter` compiles parsers for: bash, c, css, html, java, javascript, json, lua, luadoc, markdown, python, rust, tsx, typescript, vim, vimdoc, yaml, etc.

If the LSP for Python doesn't attach, run `:Mason` and confirm `basedpyright` is installed.

---

## Cheatsheet (the LunarVim-flavoured customizations)

### Navigation & buffers
| Key | Action |
|---|---|
| `<space>e` | Toggle file-tree sidebar (shows gitignored entries in dim/grey; sidebar auto-follows the focused buffer) |
| `<space>o` | Focus the file-tree |
| `I` (inside the tree) | Toggle visibility of gitignored entries |
| `<S-h>` / `<S-l>` | Previous / next buffer (bufferline; unnamed buffers are hidden) |
| `<space>c` | Close current buffer (keeps the window open) |
| `<C-Left>` / `<C-Right>` | Drag the right edge of the current split left/right (drags the *left* edge if you're in the rightmost split). 5 cols per press. |
| `<C-Up>` / `<C-Down>` | Same idea for the bottom edge (or top edge if bottommost). 3 rows per press. |
| `<space><space>` | Telescope: list open buffers |
| `<space>sf` | Telescope: find file in project |
| `<space>sg` | Telescope: live grep in project |
| `<space>sw` | Telescope: grep word under cursor |

### Movement (soft-wrap aware)
`j` / `k` / `$` / `^` / `0` are remapped to `gj` / `gk` / `g$` / `g^` / `g0` in normal + visual mode, so cursor moves by *visual line*. Lines wrap at word boundaries with the `↪` showbreak prefix.

### LSP (Python via basedpyright, Lua via lua_ls)
| Key | Action |
|---|---|
| `grd` | Go to definition |
| `grr` | List references (Telescope) |
| `gri` | Go to implementation |
| `grt` | Go to type definition |
| `gra` | Code actions |
| `grn` | Rename symbol |
| `K` | Hover docs |

### Git
| Key | Action |
|---|---|
| `<space>gd` | Diffview: open diff vs HEAD |
| `<space>gc` | Diffview: close |
| `<space>gh` | Diffview: file history (current file) |
| `<space>gH` | Diffview: repo history |
| `<space>h…` | Gitsigns hunk actions |

### Terminal — `<C-t>` dispatcher
`<C-t>` is a count-aware dispatcher backed by `Snacks.terminal` (floating, rounded border; terminals
are 95% size, same as the Claude float). Every terminal float shows a **bufferline-style tab bar** at its
top (its own row, distinct background) listing all open terminals — `[1] Term`, `[2] Claude`, … — with
the focused one highlighted. Each tab is **clickable** to switch, or use `{count}<C-t>`. Any terminal
**running the `claude` CLI** (the dedicated slot-2 pane, *or* `claude` started inside an ordinary
terminal) is labelled `[N] Claude` and, when **not focused**, changes color by state — dark orange while
Claude is working, red while it's asking you a question, normal grey when idle/finished — while the
focused tab is always blue.

While you're **editing (no terminal float open)**, a small vertical bar/box appears on the **right edge**
with a small cell per terminal — `1T`, `2C` (slot + Term/Claude), each a fully-colored chip on a dark
panel (with a gap between) — colored by Claude's state (orange working, red asking, grey idle), so you can
watch terminals without opening one. **Click a cell** to switch to that terminal (or use `{count}<C-t>`). It hides itself inside terminal floats (which show the full tab bar as their winbar) and when
no terminals are open.

| Key | Action |
|---|---|
| `<C-t>` | Toggle the last-used terminal (defaults to slot 1) |
| `1<C-t>`, `3<C-t>`, … | Switch to Snacks terminal #N (each count is its own terminal, shown as tab `[N] Term` in the bar) |
| `2<C-t>` | Switch to Claude as a **floating** window (slot 2 is reserved for claudecode.nvim) |
| `<C-t>` inside a terminal | Hide the terminal you're currently in (then `{count}<C-t>` from normal mode to switch) |
| `<Esc><Esc>` | Exit terminal mode (kickstart default) |
| `<C-q>` | Exit terminal mode (consistent with the Claude TUI, where `<Esc>` is taken) |

### Claude Code (AI / Claude prefix)
| Key | Action |
|---|---|
| `<space>ac` | Toggle Claude in the **right sidebar** |
| `2<C-t>` | Toggle Claude as a **floating** window (see terminal dispatcher above) |
| `<space>af` | Focus the Claude pane |
| `<space>ar` | Resume previous session |
| `<space>aC` | Continue last conversation |
| `<space>am` | Select model |
| `<space>ab` | Add current buffer to Claude's context |
| `<space>as` | Send visual selection (visual mode) — or add file (in NvimTree) |
| `<space>aa` / `<space>ad` | Accept / deny pending diff |
| `<space>al` | Force redraw the Claude pane |
| Inside the Claude TUI: | |
| `<C-q>` | Exit terminal mode (global mapping; here `<Esc>` is taken by Claude) |
| `<M-q>` | Close the pane outright |
| `q` (in normal mode) | Close the pane |

### Other
| Key | Action |
|---|---|
| `<space>q` | Diagnostic quickfix list |
| `<space>f` | Format buffer (conform.nvim) |
| `<C-/>` (terminal sends `<C-_>`) | Toggle comment on current line (or selection in visual mode). `gcc` / `gc` also work. |
| `<space>` (hold ~500ms) | Show which-key menu (modern preset). Restricted to `<leader>` only — never pops up from mouse clicks or visual-mode entry. |
| (auto) | Buffers auto-reload when their file changes on disk (e.g. Claude edits it). A `File reloaded from disk` notification flashes when this happens. |

---

## Updating

```bash
cd ~/.config/nvim
git pull                           # pull latest config
nvim --headless "+lua vim.pack.update()" +qa   # update plugins
```

The `nvim-pack-lock.json` is committed (see `.gitignore` — kickstart's default ignores it; this fork tracks it), so plugin versions are reproducible across machines.
