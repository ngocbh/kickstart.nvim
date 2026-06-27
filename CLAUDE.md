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
5. LSP — Mason + lspconfig; servers: `lua_ls`, `pyright`, `stylua`
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

- **pyright** is the Python LSP (`servers` table in the LSP section). NOTE: pyright installs via
  Mason using `npm`/Node, which must be present on the host — this fork previously used `basedpyright`
  (pip-installable) precisely because `npm` isn't on the target HPC, so on that host pyright may fail
  to install (fall back to basedpyright if so). Strict noise is trimmed via
  `python.analysis.diagnosticSeverityOverrides` (currently `reportMissingTypeStubs = 'none'`,
  `typeCheckingMode = 'standard'`) — preserve/extend those when touching Python LSP config.
- **`gr*` keymaps have global no-LSP fallbacks.** The `gr*` family (`grd`/`grr`/`gri`/`grt`/`grn`/
  `gra`/`grD`) is set buffer-locally only on `LspAttach` (section 4 telescope autocmd + section 5).
  Without an LSP those keys would fall through to vanilla `gr{char}` (virtual-replace) and clobber the
  char under the cursor — so section 5 registers **global** fallbacks via a `lsp_fallback` helper that
  the buffer-local LSP maps shadow when a server attaches. No-LSP behavior: degrade to an in-file
  builtin where one fits (`grd`→`gd`, `grD`→`gD`, `grr`→`*`), else just notify; always emit an
  `LSP not attached` message. Don't drop these globals — they're what stops the destructive default.
- **`<C-t>` is a count-aware terminal dispatcher**, not a plain toggle: `N<C-t>` toggles
  `Snacks.terminal` slot N (each `count` is its own persistent terminal, shown as tab `[N] Term` in the
  bar), and slot 2 is reserved for Claude Code as a floating window. There is no dedicated terminal
  plugin — Snacks is reused (it is already a claudecode dependency), so don't reintroduce toggleterm.
- **Terminal floats have a bufferline-style winbar** (`_G.TermWinbar`, set via each float's
  `win.wo.winbar = '%!v:lua.TermWinbar()'`): a filled top row of numbered, clickable tabs `[1] Term` /
  `[2] Claude` for every open terminal. Clicks route through `_G.TermBarClick` → `_G.TermGoto`;
  `{count}<C-t>` switches the same way (hides the current float, then opens the target). The focused tab is
  the blue `TermBarActive` chip, the rest are `TermBarInactive`, on a `#292e42` `TermBarFill` strip (all
  tokyonight-night). A terminal **running the `claude` CLI** (the slot-2 pane OR `claude` started in an
  ordinary Snacks terminal) is just labelled `[N] Claude` instead of `[N] Term` — claude-ness
  (`term_running_claude`, via `b:term_title`/filetype) is decoupled from the slot (`term_slot_of`; only the
  pane, `term_is_claude_pane`, is pinned to slot 2). Helpers `term_is_claude_pane` / `term_running_claude` /
  `term_slot_of` / `term_open_slots` / `term_hide_buf` back the bar and the terminal-mode `<C-t>` map. While
  editing (no terminal float focused), `rbar_refresh` (`_G.TermRbarRefresh`) shows a small vertical box on
  the right edge — one neutral (`TermRbarTerm`) clickable chip per terminal labelled `1T`/`2C` on a dark
  `TermRbarFill` panel, via global `<LeftMouse>` → `getmousepos` → `TermGoto` — so you can see open terminals
  while coding without touching the statusline/tabline/laststatus. All terminal floats are 95% size.
- **Claude run-state is NOT tracked inside nvim.** The old machinery — a 500 ms poll (`term_claude_state`
  scraping the TUI footer), the orange/red `TermBarClaude*` tab/rbar colors, the `^L` auto-repaint on state
  change, and the mirroring of state onto nvim's tmux window tab via `window-status-style` — was **removed**.
  Claude's run-state is now surfaced by the external **`claude-tmux`** package (repo `~/workspace/claude-tmux`
  → `github.com/ngocbh/claude-tmux`; installs scripts to `~/.local/bin`, a tmux snippet, and
  `~/.claude/settings.json` hooks) which colors the tmux window tab + a status-right chip from Claude Code
  hooks. **Do not re-add the nvim poll/mirroring — it conflicts with the package** (both set
  `window-status-style` and fight).
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
