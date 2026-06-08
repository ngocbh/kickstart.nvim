# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal Neovim configuration — a fork of [nvim-lua/kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)
with a LunarVim-flavoured workflow layered on top. There is no application to build; "running"
the code means launching `nvim` and observing behavior. The whole config is Lua.

## Commands

- **Format (required before commit):** `stylua .` — CI runs `stylua --check .` and will fail the
  PR if formatting differs. Style is pinned in `.stylua.toml` (160-col width, 2-space indent,
  single quotes, no call parens, collapse simple statements).
- **Sanity-check after a change:** `nvim --headless -u init.lua -c 'qa'` — surfaces Lua errors at
  startup without an interactive session. For deeper checks, run a small Lua snippet via
  `nvim --headless -u init.lua -c 'lua ...' -c 'qa'`.
- **Health / diagnostics:** `:checkhealth` inside nvim (treesitter, LSP, providers).
- **Update parsers:** `:TSUpdate` (see treesitter note below).
- **Plugin lockfile:** `nvim-pack-lock.json` is *tracked* in this fork (upstream ignores it).
  Commit changes to it when plugins are added/updated.

There is no test suite. Verification is manual: launch nvim, open a relevant file, exercise the
keymap or feature that changed.

## Architecture

**Everything of substance lives in `init.lua` (~1270 lines).** It is a single file divided into 9
numbered sections, each wrapped in a `do ... end` block to scope locals:

1. FOUNDATION — options, globals, basic keymaps, autocmds (yank-highlight, etc.)
2. PLUGIN MANAGER INTRO — the `vim.pack` setup and `PackChanged` autocmd that runs post-install
   build steps (`make` for fzf-native, `TSUpdate` for treesitter, `make install_jsregexp` for LuaSnip)
3. UI / CORE UX PLUGINS — nvim-tree, bufferline, diffview, which-key, colorscheme,
   the `<C-t>` terminal dispatcher, the Claude-pane styling autocmds
4. SEARCH & NAVIGATION — Telescope
5. LSP — Mason + lspconfig; servers: `lua_ls`, `basedpyright`, `stylua`
6. FORMATTING — conform.nvim
7. AUTOCOMPLETE & SNIPPETS — blink/LuaSnip
8. TREESITTER — parser install + the `FileType` autocmd that attaches highlighting
9. OPTIONAL EXAMPLES — the upstream `kickstart.plugins.*` requires (all commented out)

When changing behavior, find the relevant numbered section in `init.lua` rather than expecting
per-feature files.

**Plugin manager is `vim.pack` (native Neovim 0.12+), NOT lazy.nvim.** Plugins are added with
`vim.pack.add { { src = gh '<owner>/<repo>' } }` (the `gh` helper prepends the GitHub URL). There
is no lazy-loading. Plugins clone into `~/.local/share/nvim/site/pack/core/opt/`.

**`nvim-treesitter` is pinned to its `main` branch**, which compiles parsers from source (requires
the `tree-sitter` CLI + a Rust toolchain on the host). A parser install does two things: build the
`.so` into `~/.local/share/nvim/site/parser/`, AND copy that language's query files into
`~/.local/share/nvim/site/queries/<lang>/`. If the query copy fails (e.g. a download interruption),
the parser loads but the file shows **no syntax colors** — see `docs/common_issues.md` for the full
diagnosis and fix. Only `site/queries/` is on the runtimepath; the plugin's bundled
`.../nvim-treesitter/runtime/queries/` is not.

**Custom plugin extension point:** any `.lua` file dropped into `lua/custom/plugins/` is
auto-`require`d by `lua/custom/plugins/init.lua` (though that loader is currently commented out in
`init.lua` at the section-9 examples). The `lua/kickstart/plugins/*` files are upstream optional
modules and are mostly disabled.

## Conventions specific to this fork

- **basedpyright, not pyright**, for Python (pyright needs `npm`, unavailable on the target HPC;
  basedpyright installs via Mason with pip). Several strict diagnostics are silenced via
  `diagnosticSeverityOverrides` in the LSP section — preserve those when touching Python LSP config.
- **`<C-t>` is a count-aware terminal dispatcher**, not a plain toggle: `N<C-t>` toggles
  `Snacks.terminal` slot N (each `count` is its own persistent terminal, shown as tab `[N] Term` in the
  bar), and slot 2 is reserved for Claude Code as a floating window. There is no dedicated terminal
  plugin — Snacks is reused (it is already a claudecode dependency), so don't reintroduce toggleterm.
- **Terminal floats have a bufferline-style winbar** (`_G.TermWinbar`, set via each float's
  `win.wo.winbar = '%!v:lua.TermWinbar()'`): a filled top row of numbered, clickable tabs `[1] Term` /
  `[2] Claude` for every open terminal. Clicks route through `_G.TermBarClick`
  → `_G.TermGoto`; `{count}<C-t>` switches the same way (hides the current float, then opens the target).
  Any terminal **running the `claude` CLI** (the dedicated slot-2 pane OR `claude` started in an ordinary
  Snacks terminal) is labelled `[N] Claude` and gets the state colors — claude-ness (`term_running_claude`,
  via `b:term_title`/TUI footer) is decoupled from the slot (`term_slot_of`; only the pane, `term_is_claude_pane`,
  is pinned to slot 2). The `TermBarActive`/`TermBarInactive`/`TermBarFill` highlights are explicit
  tokyonight-night colors (a blue active chip on a `#292e42` strip). The **inactive Claude tab
  is colored by state** (focused tab stays blue) — when unfocused: `TermBarClaudeRunning` (orange) while
  working, `TermBarClaudeAsking` (red) while asking a question, else the normal grey when idle — inferred by
  `term_claude_state()` scanning the Claude buffer's bottom lines (`esc to interrupt` -> running, a selection-menu
  footer `to navigate`/`to select` -> asking; claudecode.nvim exposes no state API; heuristic, may break if the
  TUI text changes), kept fresh by a 500 ms
  state-poll timer that `redrawstatus` on change and, when the focused terminal is the one that changed, sends
  `^L` to repaint its TUI (React Ink leaves stale cells when a menu changes its height — auto-fix for the
  non-refreshed screen, same as `<leader>al`). Helpers `term_is_claude_pane` / `term_running_claude` /
  `term_slot_of` / `term_open_slots` / `term_hide_buf` /
  `term_claude_state` back the bar and the terminal-mode `<C-t>` map. While editing (no terminal float
  focused), `rbar_refresh` (`_G.TermRbarRefresh`) shows a small vertical box on the right edge with a padded
  fully-colored chip per terminal labelled `1T`/`2C` (slot + Term/Claude) on a dark panel (`TermRbar*`, gap between chips), colored by Claude state, clickable (global `<LeftMouse>` -> `getmousepos` -> `TermGoto`),
  so you can watch terminals/Claude-state while coding (a right-edge float; avoids statusline/tabline/laststatus). All terminal
  floats are 95% size.
- **Movement keys are soft-wrap aware:** `j k $ ^ 0` are remapped to their `g`-prefixed visual-line
  variants in normal + visual mode.

## Reference docs in this repo

- `README.md` — install-on-a-new-server guide + the full keymap cheatsheet.
- `SETUP.md` — "rebuild from scratch" log: every customization layered on upstream and *why*.
- `KICKSTART.md` — upstream kickstart's original pedagogical README (untouched).
- `docs/common_issues.md` — troubleshooting log (currently: treesitter missing-query-files issue).

### Documentation upkeep (required)

The docs above are hand-maintained and drift easily. **Any change to behavior must update the
affected docs in the same change** — treat them as part of the change, not a follow-up. Map of what
to touch:

| If you change… | Update |
|---|---|
| A keymap or the `<C-t>` dispatcher | `README.md` cheatsheet + the relevant note in this file + `SETUP.md` §6b |
| Add / remove / swap a plugin | `nvim-pack-lock.json` (via `vim.pack`), `SETUP.md` plugin table, and any mention in `README.md` / this file. Removing a plugin: use `vim.pack.del({...})` so the dir *and* lockfile are cleaned — hand-editing the lockfile alone won't stick (vim.pack rewrites it from installed plugins on startup). |
| LSP servers, formatters, or their settings | `SETUP.md` §3 + the LSP note in this file |
| The section layout of `init.lua` | the numbered list in the Architecture section above |
| Hit a non-obvious failure + fix | add an entry to `docs/common_issues.md` |

After editing, grep the repo for stale references (e.g. the old plugin/keymap name) and run the
sanity-check + `stylua --check .` before considering the change done. KICKSTART.md is the only doc
that is never edited.
