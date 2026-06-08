# Common Issues

A running log of problems hit with this Neovim config and how they were fixed.

---

## Shell scripts (`.sh`) / other filetypes show no syntax colors

**Symptom:** A `.sh` file opens with no syntax highlighting at all. The parser
seems present, but everything is monochrome. (Also observed for `typescript` and
`tsx`.)

**Root cause:** With nvim-treesitter's `main` branch, installing a parser does
two things:

1. compiles/installs the parser `.so` → `~/.local/share/nvim/site/parser/<lang>.so`
2. copies that language's query files (`highlights.scm`, `indents.scm`, ...) →
   `~/.local/share/nvim/site/queries/<lang>/`

Only `site/queries/` is on the runtimepath — the plugin's own
`.../nvim-treesitter/runtime/queries/` is **not**. If step 2 fails (e.g. the
parser source download 403s / is interrupted mid-install), you end up with the
`.so` present but **no query files**. Treesitter then attaches a highlighter
with zero highlight rules, so the file parses but shows no colors.

This was introduced during the June 2026 migration to `vim.pack`: bash,
typescript, and tsx had their `.so` installed but their query copy never
completed.

**How to diagnose:**

```vim
:checkhealth nvim-treesitter
```

or, in Lua:

```lua
-- nil means no highlight rules for this language
:lua = vim.treesitter.query.get('bash', 'highlights')

-- empty/0 means the query files aren't on the runtimepath
:lua = #vim.api.nvim_get_runtime_file('queries/bash/highlights.scm', true)
```

Compare installed parsers vs. installed query dirs:

```sh
ls ~/.local/share/nvim/site/parser/      # one <lang>.so per parser
ls ~/.local/share/nvim/site/queries/     # should have a dir per parser
```

A parser whose name is in the first list but missing from the second is broken.

**Fix (normal machine, has network):**

```vim
:TSUpdate bash typescript tsx
```

This re-runs the full install (download → compile → copy queries).

**Fix (offline / download blocked by 403):** the query files are already bundled
with the plugin, so just copy them into the site dir — no download needed:

```sh
SRC=~/.local/share/nvim/site/pack/core/opt/nvim-treesitter/runtime/queries
DST=~/.local/share/nvim/site/queries
for lang in bash typescript tsx; do
  cp -r "$SRC/$lang" "$DST/$lang"
done
```

Reopen the file; colors return immediately (no restart needed).
