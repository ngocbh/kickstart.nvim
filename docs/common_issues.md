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

---

## pyright fails to start/install — `node: symbol lookup error ... undefined symbol: sqlite3session_attach`

**Symptom:** Opening a Python file, pyright never attaches; the message area /
`:messages` (or wherever the LSP/Mason error surfaces) shows something like:

```
/home/<you>/.conda/envs/<env>/bin/node: symbol lookup error:
.../lib/libnode.so.147: undefined symbol: sqlite3session_attach
```

pyright is a Node program, so this fires when Mason tries to **install** or **run**
pyright-langserver. It only happens when nvim is launched with a conda env active
whose `node` is broken.

**Root cause:** **not** this config and **not** pyright — a broken `libsqlite3` in
the active conda env. Modern Node (v22.5+) bundles the built-in `node:sqlite`
module, whose `libnode.so` dynamically links `libsqlite3.so.0` and needs the
SQLite **session** extension symbols (`sqlite3session_*`). If the env's
`libsqlite3` was built **without** `SQLITE_ENABLE_SESSION`, those symbols are
missing and `node` aborts at load time on *every* invocation. (The env's *Python*
sqlite is unaffected — Python's `_sqlite3` doesn't use the session API.)

Seen on this host: env `hstu` had `libsqlite 3.53.2 h0c1763c_0` whose on-disk
`libsqlite3.so.3.53.2` was a wrong/corrupt copy (1,510,904 B, no session symbol),
while env `ide` had the **same** conda build string with the correct artifact
(1,766,648 B, session symbol present). Same package record, different file.

**How to diagnose:**

```sh
ENV=~/.conda/envs/<env>
$ENV/bin/node --version                                   # crashes = broken
nm -D $ENV/lib/libsqlite3.so.3.53.2 | grep -c sqlite3session_attach   # 0 = no session
# find a healthy node/libsqlite in another env to copy from:
for f in ~/.conda/envs/*/lib/libsqlite3.so.3.*; do
  echo -n "$f: "; nm -D "$f" 2>/dev/null | grep -c sqlite3session_attach
done
```

**Fix (surgical, offline, no dependency changes)** — if another env has the
*same* `libsqlite` build with the correct (session-enabled) file, drop it in over
the broken one. Touches exactly one file, no solver, no risk to pinned packages:

```sh
H=~/.conda/envs/hstu/lib/libsqlite3.so.3.53.2     # broken
I=~/.conda/envs/ide/lib/libsqlite3.so.3.53.2      # good (same conda build)
mv "$H" "$H.broken-nosession.bak"                 # reversible backup
cp -p "$I" "$H"
nm -D "$H" | grep -c sqlite3session_attach        # expect 1
~/.conda/envs/hstu/bin/node --version             # now works
```

Restart nvim **with the env active**; Mason installs pyright cleanly. (Alternative
proper fix: `conda install -n <env> --force-reinstall libsqlite` — slower, needs
network, and conda 4.x's classic solver may propose extra changes.)

**Related:** the LSP note in `CLAUDE.md` covers the basedpyright fallback for
hosts where node/npm is unavailable entirely; that's a different failure (no node)
than this (node present but broken).

---

## Treesitter parser build fails — `tree-sitter: /lib64/libc.so.6: version 'GLIBC_2.xx' not found`

**Symptom:** Installing/updating any parser (`:TSUpdate`, `:TSInstall <lang>`, or
the auto-install on first open) fails at the compile step. The error names the
`tree-sitter` CLI binary and a string of missing glibc versions, e.g.:

```
[nvim-treesitter/install/groovy] error: Error during "tree-sitter build":
.../tree-sitter-cli/tree-sitter: /lib64/libm.so.6: version `GLIBC_2.29' not found
.../tree-sitter-cli/tree-sitter: /lib64/libc.so.6: version `GLIBC_2.34' not found
...
```

**Root cause:** **not** this config — a host/glibc mismatch. nvim-treesitter is
pinned to `main`, which compiles parsers from source by shelling out to the
`tree-sitter` CLI. The CLI binary (installed via npm into the conda env at
`.conda/envs/<env>/lib/node_modules/tree-sitter-cli/tree-sitter`) was built
against a **newer glibc than this HPC node provides**. Seen on radev: node glibc
is **2.28** (`ldd --version`), but the prebuilt `tree-sitter` imports symbols up
to **GLIBC_2.34**, so it can't even start — every parser build dies before doing
any work.

**How to diagnose:**

```sh
ldd --version | head -1                                   # host glibc (e.g. 2.28)
BIN=~/.conda/envs/ide/lib/node_modules/tree-sitter-cli/tree-sitter
"$BIN" --version                                          # crashes with the GLIBC error
```

**Fix (offline, no reinstall):** patch the binary's glibc symbol imports down to
a version the host satisfies, using
[`polyfill-glibc`](https://github.com/corsix/polyfill-glibc) (a local build lives
at `~/radev/trimkv/src/polyfill-glibc/polyfill-glibc`):

```sh
PFG=~/radev/trimkv/src/polyfill-glibc/polyfill-glibc
BIN=~/.conda/envs/ide/lib/node_modules/tree-sitter-cli/tree-sitter
cp -n "$BIN" "$BIN.orig"                                  # reversible backup
"$PFG" --target-glibc=2.17 "$BIN"                         # rewrite imports to 2.17
"$PFG" --print-imports "$BIN" | grep -E 'GLIBC_2\.(29|3[0-9])'   # expect: nothing
"$BIN" --version                                          # now prints e.g. tree-sitter 0.25.3
```

Then re-run the install (`:TSUpdate` / `:TSInstall <lang>`) — it compiles cleanly.

**Caveat:** this patches the binary **in place inside the conda env**. Any
`npm install`/upgrade of `tree-sitter-cli` overwrites it and the error returns —
just re-run the `polyfill-glibc --target-glibc=2.17` step on the new binary. The
original is kept at `tree-sitter.orig` alongside it.
