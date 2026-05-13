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
| `<space>e` | Toggle file-tree sidebar (nvim-tree) |
| `<space>o` | Focus the file-tree |
| `<S-h>` / `<S-l>` | Previous / next buffer (bufferline) |
| `<space>c` | Close current buffer (keeps the window open) |
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

### Terminal
| Key | Action |
|---|---|
| `<C-t>` | ToggleTerm — open/close a horizontal terminal |
| `<Esc><Esc>` | Exit terminal mode (kickstart default) |

### Claude Code (AI / Claude prefix)
| Key | Action |
|---|---|
| `<space>ac` | Toggle Claude pane |
| `<space>af` | Focus the Claude pane |
| `<space>ar` | Resume previous session |
| `<space>aC` | Continue last conversation |
| `<space>am` | Select model |
| `<space>ab` | Add current buffer to Claude's context |
| `<space>as` | Send visual selection (visual mode) — or add file (in NvimTree) |
| `<space>aa` / `<space>ad` | Accept / deny pending diff |
| `<space>al` | Force redraw the Claude pane |
| Inside the Claude TUI: | |
| `<C-q>` | Exit terminal mode (then `:q` hides the pane) |
| `<M-q>` | Close the pane outright |
| `q` (in normal mode) | Close the pane |

### Other
| Key | Action |
|---|---|
| `<space>q` | Diagnostic quickfix list |
| `<space>f` | Format buffer (conform.nvim) |
| `<space><leader>` (hold) | Show which-key menu (modern preset) |

---

## Updating

```bash
cd ~/.config/nvim
git pull                           # pull latest config
nvim --headless "+lua vim.pack.update()" +qa   # update plugins
```

The `nvim-pack-lock.json` is committed (see `.gitignore` — kickstart's default ignores it; this fork tracks it), so plugin versions are reproducible across machines.
