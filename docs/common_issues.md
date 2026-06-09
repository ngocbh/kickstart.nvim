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

---

## `LSP[pyright] error ... INVALID_SERVER_MESSAGE id=N jsonrpc=2.0` spam

**Symptom:** A steady stream of error echoes while editing Python (the `id`
climbs by one every second or two), e.g.

```
LSP[pyright]: Error INVALID_SERVER_MESSAGE: { id = 12, jsonrpc = "2.0" }
```

The same error also fires for `basedpyright` and `GitHub Copilot` — that it spans
multiple unrelated servers is the tell that it is **not** a per-server config bug.

**Root cause:** a bug in the **Meta-patched** Neovim build, *not* this config and
*not* pyright. pyright sends spec-valid empty replies of the form
`{"jsonrpc":"2.0","id":N,"result":null}` — most often to
`textDocument/documentHighlight`, which `init.lua` fires on every `CursorHold`;
pyright returns `result: null` whenever the cursor isn't on a symbol (hence the
once-per-second cadence). The `-- START: Meta specific patch.` block in
`/usr/share/nvim/runtime/lua/vim/lsp/rpc.lua` converts `decoded.result` from
`vim.NIL` → `nil` **before** the response-validity check that requires
`result ~= nil`. Stock Neovim relied on `vim.NIL` being truthy there; the patch
nils it first, so the valid null-result reply matches neither "response" nor
"notification" and falls through to `INVALID_SERVER_MESSAGE`, which
`Client:write_error` echoes unconditionally (a per-server `on_error` can't stop
it). Net effect is mostly cosmetic, but `documentHighlight` silently does nothing
for Python because its reply is discarded instead of dispatched.

**Proper fix (Meta build, needs root):** delete the three-line
`if decoded.result == vim.NIL then decoded.result = nil end` block in that
`rpc.lua` (the `error` → nil conversion just above it is fine). The file is
root-owned and is overwritten on the next nvim package update, so this is worth
reporting to whoever owns the Meta nvim package rather than hand-patching.

**Workaround in this config:** the `LspAttach` handler in `init.lua` (SECTION 5)
wraps each client's `write_error` to swallow **only** `INVALID_SERVER_MESSAGE`
and pass every other error through. This fully silences the noise for all servers
while keeping real errors visible. Remove that block once the upstream `rpc.lua`
patch is fixed.

**How to confirm it's this and not something else:**

```sh
grep INVALID_SERVER_MESSAGE ~/.local/state/nvim/lsp.log | tail
```

Multiple distinct `LSP[...]` server names with the same code = the build bug above.
