--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know the Neovim basics, you can skip this step.)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

-- ============================================================
-- SECTION 1: FOUNDATION
-- Core Neovim settings, leaders, options, basic keymaps, basic autocmds
-- ============================================================
do
  -- Enable faster startup by caching compiled Lua modules
  vim.loader.enable()

  -- Set <space> as the leader key
  -- See `:help mapleader`
  --  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  -- Set to true if you have a Nerd Font installed and selected in the terminal
  vim.g.have_nerd_font = true

  -- [[ Setting options ]]
  --  See `:help vim.o`
  -- NOTE: You can change these options as you wish!
  --  For more options, you can see `:help option-list`

  -- Make line numbers default
  vim.o.number = true
  -- You can also add relative line numbers, to help with jumping.
  --  Experiment for yourself to see if you like it!
  -- vim.o.relativenumber = true

  -- Enable mouse mode, can be useful for resizing splits for example!
  vim.o.mouse = 'a'

  -- Don't show the mode, since it's already in the status line
  vim.o.showmode = false

  -- Reclaim the bottom row: hide the command line until it's actually needed
  -- (typing `:`, a search, or a message). With cmdheight=1 (the default) that row
  -- sits empty below the statusline. Set to 1 if you prefer a persistent cmdline.
  vim.o.cmdheight = 0

  -- Sync clipboard between OS and Neovim.
  --  Schedule the setting after `UiEnter` because it can increase startup-time.
  --  Remove this option if you want your OS clipboard to remain independent.
  --  See `:help 'clipboard'`
  --
  -- On headless hosts (SSH/devserver) there is no DISPLAY and no xclip/xsel/wl-copy,
  -- so nvim has no clipboard provider and yanks to `+` silently go nowhere. Force the
  -- built-in OSC 52 provider so the terminal (tmux/iTerm/Kitty/WezTerm/Ghostty/etc.)
  -- forwards yanks to the host clipboard over the escape-sequence channel. Paste from
  -- the OS clipboard via the terminal's own paste (Cmd/Ctrl-V) -- OSC 52 read is
  -- blocked by most terminals for security, so we stub paste to the unnamed register.
  vim.schedule(function()
    vim.o.clipboard = 'unnamedplus'
    -- Yanks to `+` need to reach the laptop clipboard. On this headless host
    -- there is no DISPLAY/Wayland and no xclip/wl-copy, so the only path is
    -- OSC 52 forwarded through tmux to the outer terminal (Ghostty here).
    --
    -- Key gotchas hit while wiring this up:
    --   * On this Meta-patched nvim AppImage, `/dev/tty` is not openable from
    --     the nvim process. Use stdout (which IS the controlling pty) instead.
    --   * Some terminals only honor OSC 52 when terminated with BEL (\007),
    --     not ST (\e\). nvim's built-in osc52 provider uses ST, which Ghostty
    --     does not honor over tmux passthrough -- so the bytes arrive at the
    --     terminal and are silently dropped. We emit with BEL.
    --   * `tmux load-buffer -w` would normally also forward as OSC 52, but on
    --     this server it intermittently returns "server exited unexpectedly".
    --     We skip tmux and write directly through nvim's stdout; tmux still
    --     passes the sequence through to Ghostty (set-clipboard=external).
    --
    -- OSC 52 *read* (paste from system clipboard to nvim) is intentionally a
    -- no-op: most terminals block it for security, and the wait-for-reply call
    -- freezes nvim for ~1s on every `"+p`. Use the terminal's own paste
    -- (Cmd/Ctrl-V) for OS->nvim direction.
    local function copy(reg)
      local target = reg == '+' and 'c' or 'p'
      return function(lines)
        local s = table.concat(lines, '\n')
        local seq = string.format('\027]52;%s;%s\007', target, vim.base64.encode(s))
        io.stdout:write(seq)
        io.stdout:flush()
      end
    end
    local function paste(reg)
      return function() return vim.split(vim.fn.getreg(reg, 1, true) or '', '\n') end
    end
    vim.g.clipboard = {
      name = 'OSC 52 (BEL via stdout)',
      copy = { ['+'] = copy '+', ['*'] = copy '*' },
      paste = { ['+'] = paste '+', ['*'] = paste '*' },
    }
  end)

  -- Enable break indent
  vim.o.breakindent = true

  -- Enable undo/redo changes even after closing and reopening a file
  vim.o.undofile = true

  -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
  vim.o.ignorecase = true
  vim.o.smartcase = true

  -- Keep signcolumn on by default
  vim.o.signcolumn = 'yes'

  -- Decrease update time
  vim.o.updatetime = 250

  -- Decrease mapped sequence wait time
  vim.o.timeoutlen = 300

  -- Configure how new splits should be opened
  vim.o.splitright = true
  vim.o.splitbelow = true

  -- Sets how neovim will display certain whitespace characters in the editor.
  --  See `:help 'list'`
  --  and `:help 'listchars'`
  --
  --  Notice listchars is set using `vim.opt` instead of `vim.o`.
  --  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
  --   See `:help lua-options`
  --   and `:help lua-guide-options`
  vim.o.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

  -- Preview substitutions live, as you type!
  vim.o.inccommand = 'split'

  -- Show which line your cursor is on
  vim.o.cursorline = true

  -- Minimal number of screen lines to keep above and below the cursor.
  vim.o.scrolloff = 10

  -- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
  -- instead raise a dialog asking if you wish to save the current file(s)
  -- See `:help 'confirm'`
  vim.o.confirm = true

  -- [[ Basic Keymaps ]]
  --  See `:help vim.keymap.set()`

  -- Clear highlights on search when pressing <Esc> in normal mode
  --  See `:help hlsearch`
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Diagnostic Config & Keymaps
  --  See `:help vim.diagnostic.Opts`
  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },

    -- Can switch between these as you prefer
    virtual_text = true, -- Text shows up at the end of the line
    virtual_lines = false, -- Text shows up underneath the line, with virtual lines

    -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }
      end,
    },
  }

  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

  -- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
  -- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
  -- is not what someone will guess without a bit more experience.
  --
  -- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
  -- or just use <C-\><C-n> to exit terminal mode
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
  -- <C-q> also exits terminal mode, matching Claude's terminal where <Esc> is taken
  -- by Claude itself. Keeps a single, consistent exit key across every terminal.
  vim.keymap.set('t', '<C-q>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- TIP: Disable arrow keys in normal mode
  -- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
  -- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
  -- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
  -- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

  -- Keybinds to make split navigation easier.
  --  Use CTRL+<hjkl> to switch between windows
  --
  --  See `:help wincmd` for a list of all window commands
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- Split resize: arrow direction always points the way the controlled boundary moves.
  -- Controls the RIGHT edge of the current window (or LEFT edge if rightmost).
  -- Same idea for vertical: bottom edge (or top edge if bottommost).
  local function resize_horizontal(step)
    -- step > 0 → boundary moves right; < 0 → boundary moves left
    local cur = vim.api.nvim_get_current_win()
    if vim.fn.winnr 'l' ~= vim.fn.winnr() then
      vim.fn.win_move_separator(cur, step) -- our right separator
    else
      local left = vim.fn.win_getid(vim.fn.winnr 'h')
      if left ~= cur then vim.fn.win_move_separator(left, step) end -- the left neighbor's right separator = our left edge
    end
  end
  local function resize_vertical(step)
    local cur = vim.api.nvim_get_current_win()
    if vim.fn.winnr 'j' ~= vim.fn.winnr() then
      vim.fn.win_move_statusline(cur, step) -- our bottom statusline
    else
      local above = vim.fn.win_getid(vim.fn.winnr 'k')
      if above ~= cur then vim.fn.win_move_statusline(above, step) end -- our top edge
    end
  end
  vim.keymap.set('n', '<C-Left>', function() resize_horizontal(-5) end, { desc = 'Drag controlled edge left' })
  vim.keymap.set('n', '<C-Right>', function() resize_horizontal(5) end, { desc = 'Drag controlled edge right' })
  vim.keymap.set('n', '<C-Up>', function() resize_vertical(-3) end, { desc = 'Drag controlled edge up' })
  vim.keymap.set('n', '<C-Down>', function() resize_vertical(3) end, { desc = 'Drag controlled edge down' })

  -- Auto-reload buffers when the file on disk changes (e.g. Claude edits a file
  -- in another window). Without these autocmds, autoread doesn't actually fire
  -- until you focus the buffer; we poll on idle + focus to pick changes up
  -- immediately and avoid the W12 "file changed" prompt.
  vim.opt.autoread = true
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
    pattern = '*',
    callback = function()
      if vim.fn.mode() ~= 'c' then vim.cmd 'checktime' end
    end,
  })
  vim.api.nvim_create_autocmd('FileChangedShellPost', {
    pattern = '*',
    callback = function() vim.notify('File reloaded from disk', vim.log.levels.INFO) end,
  })

  -- VS-Code-style Ctrl+/ to toggle comment (most terminals send <C-_>).
  vim.keymap.set('n', '<C-_>', 'gcc', { remap = true, desc = 'Toggle comment line' })
  vim.keymap.set('v', '<C-_>', 'gc', { remap = true, desc = 'Toggle comment selection' })

  -- Soft-wrap: wrap long lines at word boundaries and move cursor by visual line.
  vim.opt.wrap = true
  vim.opt.linebreak = true
  vim.opt.showbreak = '↪  '
  for _, m in ipairs { 'n', 'v' } do
    vim.keymap.set(m, 'j', 'gj', { desc = 'Down (visual line)' })
    vim.keymap.set(m, 'k', 'gk', { desc = 'Up (visual line)' })
    vim.keymap.set(m, '$', 'g$', { desc = 'End of visual line' })
    vim.keymap.set(m, '^', 'g^', { desc = 'First non-blank of visual line' })
    vim.keymap.set(m, '0', 'g0', { desc = 'Start of visual line' })
  end

  -- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
  -- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
  -- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
  -- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
  -- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`

  -- Highlight when yanking (copying) text
  --  Try it with `yap` in normal mode
  --  See `:help vim.hl.on_yank()`
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })
end

-- ============================================================
-- SECTION 2: PLUGIN MANAGER INTRO
-- vim.pack intro, build hooks
-- ============================================================
do
  -- [[ Intro to `vim.pack` ]]
  -- `vim.pack` is a new plugin manager built into Neovim,
  --  which provides a Lua interface for installing and managing plugins.
  --
  --  See `:help vim.pack`, `:help vim.pack-examples` or the
  --  excellent blog post from the creator of vim.pack and mini.nvim:
  --  https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack
  --
  --  To inspect plugin state and pending updates, run
  --    :lua vim.pack.update(nil, { offline = true })
  --
  --  To update plugins, run
  --    :lua vim.pack.update()
  --
  --
  --  Throughout the rest of the config there will be examples
  --  of how to install and configure plugins using `vim.pack`.
  --
  --  In this section we set up some autocommands to run build
  --  steps for certain plugins after they are installed or updated.

  local function run_build(name, cmd, cwd)
    local result = vim.system(cmd, { cwd = cwd }):wait()
    if result.code ~= 0 then
      local stderr = result.stderr or ''
      local stdout = result.stdout or ''
      local output = stderr ~= '' and stderr or stdout
      if output == '' then output = 'No output from build command.' end
      vim.notify(('Build failed for %s:\n%s'):format(name, output), vim.log.levels.ERROR)
    end
  end

  -- This autocommand runs after a plugin is installed or updated and
  --  runs the appropriate build command for that plugin if necessary.
  --
  -- See `:help vim.pack-events`
  vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
      local name = ev.data.spec.name
      local kind = ev.data.kind
      if kind ~= 'install' and kind ~= 'update' then return end

      if name == 'telescope-fzf-native.nvim' and vim.fn.executable 'make' == 1 then
        run_build(name, { 'make' }, ev.data.path)
        return
      end

      if name == 'LuaSnip' then
        if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then run_build(name, { 'make', 'install_jsregexp' }, ev.data.path) end
        return
      end

      if name == 'nvim-treesitter' then
        if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
        vim.cmd 'TSUpdate'
        return
      end
    end,
  })
end

---Because most plugins are hosted on GitHub, you can use the helper
---function to have less repetition in the following sections.
---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- SECTION 3: UI / CORE UX PLUGINS
-- guess-indent, gitsigns, which-key, colorscheme, todo-comments, mini modules
-- ============================================================
do
  -- [[ Installing and Configuring Plugins ]]
  --
  -- To install a plugin simply call `vim.pack.add` with its git url.
  -- This will download the default branch of the plugin, which will usually be `main` or `master`
  -- You can also have more advanced specs, which we will talk about later.
  --
  -- For most plugins its not enough to install them, you also need to call their `.setup()` to start them.
  --
  -- For example, lets say we want to install `guess-indent.nvim` - a plugin for
  -- automatically detecting and setting the indentation.
  --
  -- We first install it from https://github.com/NMAC427/guess-indent.nvim
  -- and then call its `setup()` function to start it with default settings.
  vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
  require('guess-indent').setup {}

  -- Because lua is a real programming language, you can also have some logic to your installation -
  -- like only installing a plugin if a condition is met.
  --
  -- Here we only install `nvim-web-devicons` (which adds pretty icons) if we have a Nerd Font,
  -- since otherwise the icons won't display properly.
  if vim.g.have_nerd_font then vim.pack.add { gh 'nvim-tree/nvim-web-devicons' } end

  -- File explorer sidebar (replicates LunarVim's nvim-tree setup).
  -- Disable netrw recommended by nvim-tree before the plugin loads.
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1
  vim.pack.add { gh 'nvim-tree/nvim-tree.lua' }
  require('nvim-tree').setup {
    view = { side = 'left', width = 30, preserve_window_proportions = true },
    actions = { open_file = { resize_window = false } },
    renderer = {
      icons = { show = { git = false } },
      highlight_git = 'name', -- color the filename by git status (greys out gitignored)
    },
    git = { enable = true },
    filters = { dotfiles = false, git_ignored = false },
    -- Highlight & reveal the currently focused buffer in the tree.
    update_focused_file = { enable = true, update_root = false },
    -- nvim-tree's default <C-t> opens a file in a new tab — override so it stays
    -- consistent with the global <C-t> terminal toggle everywhere.
    on_attach = function(bufnr)
      local api = require 'nvim-tree.api'
      api.config.mappings.default_on_attach(bufnr)
      vim.keymap.del('n', '<C-t>', { buffer = bufnr })
      vim.keymap.set('n', '<C-t>', function() _G.TermToggle() end, { buffer = bufnr, desc = 'Toggle terminal ({count}; 2 = Claude)' })
      -- <leader>ac copies a Claude @-mention of the node under the cursor to the
      -- clipboard (to paste into any other Claude Code). Mirrors the global map
      -- below; _G.ClaudeCopyMention is defined in the Claude Code section.
      vim.keymap.set('n', '<leader>ac', function()
        local node = api.tree.get_node_under_cursor()
        _G.ClaudeCopyMention(node and node.absolute_path)
      end, { buffer = bufnr, desc = '[A]I [C]opy @-mention of file for Claude' })
    end,
  }
  vim.keymap.set('n', '<leader>e', '<cmd>NvimTreeToggle<cr>', { desc = 'Toggle file [E]xplorer' })
  vim.keymap.set('n', '<leader>o', '<cmd>NvimTreeFocus<cr>', { desc = 'Focus file explorer' })

  -- Top buffer bar (LunarVim-style). Cycle buffers with <S-h>/<S-l>, close with <leader>c.
  vim.pack.add { gh 'akinsho/bufferline.nvim' }
  require('bufferline').setup {
    options = {
      diagnostics = 'nvim_lsp',
      offsets = { { filetype = 'NvimTree', text = 'File Explorer', separator = true, text_align = 'left' } },
      -- Hide unnamed buffers (the "[No Name]" entries) from the top bar.
      custom_filter = function(buf_number) return vim.api.nvim_buf_get_name(buf_number) ~= '' end,
    },
  }
  vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Prev buffer' })
  vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Next buffer' })
  vim.keymap.set('n', '<leader>c', function()
    local cur = vim.api.nvim_get_current_buf()
    -- Skip non-file buffers (nvim-tree, terminal, help, etc.)
    if vim.bo[cur].buftype ~= '' then return end
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if b ~= cur and vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted then
        vim.cmd 'bprevious'
        break
      end
    end
    if vim.api.nvim_buf_is_valid(cur) then vim.api.nvim_buf_delete(cur, {}) end
  end, { desc = '[C]lose buffer' })

  -- Git diff viewer. Plenary already comes in via telescope.
  vim.pack.add { gh 'sindrets/diffview.nvim' }
  require('diffview').setup {}
  vim.keymap.set('n', '<leader>gd', '<cmd>DiffviewOpen<cr>', { desc = '[G]it [D]iffview open' })
  vim.keymap.set('n', '<leader>gc', '<cmd>DiffviewClose<cr>', { desc = '[G]it diffview [C]lose' })
  vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', { desc = '[G]it file [H]istory' })
  vim.keymap.set('n', '<leader>gH', '<cmd>DiffviewFileHistory<cr>', { desc = '[G]it repo [H]istory' })

  -- Terminal in a togglable pane (LunarVim's <C-t> behavior). Backed by
  -- Snacks.terminal, which is already a dependency (claudecode uses it), so no
  -- separate terminal plugin is needed. Snacks keys terminals by `count`, so each
  -- slot is its own persistent terminal.
  -- A bufferline-style tab bar (winbar) sits at the top of every terminal float,
  -- on its own row just under the border, listing every open terminal -- `[1] Term`,
  -- `[2] Claude`, ... -- with the focused tab highlighted and its own background so
  -- it reads separately from the terminal output below. Tabs are clickable, and
  -- `{count}<C-t>` also switches. `%!` re-evaluates it on each redraw. See
  -- _G.TermWinbar below.
  local term_winbar = '%!v:lua.TermWinbar()'
  local claude_float = {
    snacks_win_opts = {
      position = 'float',
      width = 0.95,
      height = 0.95,
      border = 'rounded',
      wo = { winbar = term_winbar },
    },
  }

  ---Snacks terminal options for a numbered slot (floating, 95% — matches the Claude float).
  ---@param slot integer
  local function term_opts(slot)
    return {
      count = slot,
      win = {
        position = 'float',
        width = 0.95,
        height = 0.95,
        border = 'rounded',
        wo = { winbar = term_winbar },
      },
    }
  end

  ---True if `buf` is the dedicated claudecode.nvim pane (always dispatcher slot 2).
  ---Identified ONLY by filetype -- never by buffer name, which is `term://<cwd>//...`
  ---and so contains "claude" for *any* terminal opened in a claude-named directory
  ---(that false-match put ordinary terminals on slot 2 and broke <C-t> close).
  local function term_is_claude_pane(buf) return vim.bo[buf].filetype == 'claudecode' end

  ---True if the Claude CLI is running in `buf` -- either the dedicated pane, or
  ---`claude` launched inside an ordinary shell terminal (which gets the "Claude"
  ---label in the bar). The latter is detected by the Claude TUI footer *text* only --
  ---NOT the buffer name/title, which contain the cwd and so falsely match in a
  ---claude-named directory.
  local function term_running_claude(buf)
    if term_is_claude_pane(buf) then return true end
    if vim.bo[buf].buftype ~= 'terminal' then return false end
    local n = vim.api.nvim_buf_line_count(buf)
    local bottom = table.concat(vim.api.nvim_buf_get_lines(buf, math.max(0, n - 12), n, false), '\n'):lower()
    return bottom:find('esc to interrupt', 1, true) ~= nil or bottom:find('? for shortcuts', 1, true) ~= nil or bottom:find('to navigate', 1, true) ~= nil
  end

  ---The dispatcher slot for a terminal buffer: the claudecode pane is always slot 2,
  ---a Snacks terminal is its `count`. Returns nil for non-terminal buffers.
  local function term_slot_of(buf)
    if term_is_claude_pane(buf) then return 2 end
    local meta = vim.b[buf].snacks_terminal
    if meta and meta.id then return meta.id end
    return nil
  end

  ---Hide whichever terminal owns `buf` (the claudecode pane or a Snacks slot).
  local function term_hide_buf(buf)
    if term_is_claude_pane(buf) then
      require('claudecode.terminal').simple_toggle(claude_float)
      return true
    end
    for _, term in pairs(Snacks.terminal.list()) do
      if term.buf == buf then
        term:hide()
        return true
      end
    end
    return false
  end

  ---Open terminals as a slot-sorted list of { slot, buf, claude }. `claude` is true
  ---for the dedicated pane AND any Snacks terminal currently running the Claude CLI.
  local function term_open_slots()
    local slots = {}
    for _, term in pairs(Snacks.terminal.list()) do
      if vim.api.nvim_buf_is_valid(term.buf) then
        local slot = term_slot_of(term.buf)
        if slot then slots[slot] = { buf = term.buf, claude = term_running_claude(term.buf) } end
      end
    end
    -- Capture the claudecode pane even if claudecode manages it outside Snacks' list.
    if not slots[2] then
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and term_is_claude_pane(buf) then
          slots[2] = { buf = buf, claude = true }
          break
        end
      end
    end
    local keys = vim.tbl_keys(slots)
    table.sort(keys)
    local out = {}
    for _, slot in ipairs(keys) do
      out[#out + 1] = { slot = slot, buf = slots[slot].buf, claude = slots[slot].claude }
    end
    return out
  end

  -- Distinct bar colors (tokyonight-night palette) so the tab bar separates from
  -- the terminal output below: a solid bg strip, with the active tab a blue chip.
  vim.api.nvim_set_hl(0, 'TermBarActive', { fg = '#16161e', bg = '#7aa2f7', bold = true })
  vim.api.nvim_set_hl(0, 'TermBarInactive', { fg = '#a9b1d6', bg = '#292e42' })
  vim.api.nvim_set_hl(0, 'TermBarFill', { fg = '#565f89', bg = '#292e42' })
  -- The right-edge terminal box uses its own palette: a dark panel/gap (`TermRbarFill`)
  -- with each terminal a fully-colored chip on top. The grey (idle) chip is lighter
  -- than the panel so chips stay distinct with just a dark gap between them.
  vim.api.nvim_set_hl(0, 'TermRbarFill', { bg = '#16161e' })
  vim.api.nvim_set_hl(0, 'TermRbarTerm', { fg = '#c0caf5', bg = '#292e42' })
  ---Switch to terminal `slot`: hide the current terminal float first (so floats
  ---don't stack), then toggle the target open. Used by `{count}<C-t>` and clicks.
  function _G.TermGoto(slot)
    local cur = vim.api.nvim_get_current_buf()
    if vim.bo[cur].buftype == 'terminal' then term_hide_buf(cur) end
    _G.TermToggle(slot)
  end

  ---Winbar renderer: a filled, bufferline-style bar of every open terminal --
  ---`[1] Term`, `[2] Claude`, ... -- with the focused tab highlighted. Each tab is
  ---a clickable region (mouse is enabled) routing to _G.TermBarClick.
  function _G.TermWinbar()
    local items = term_open_slots()
    if #items == 0 then return '' end
    -- The window this winbar is being drawn for tells us which slot is focused.
    local sw = vim.g.statusline_winid
    local curbuf = (sw and sw ~= 0 and vim.api.nvim_win_is_valid(sw)) and vim.api.nvim_win_get_buf(sw) or vim.api.nvim_get_current_buf()
    local parts = {}
    for _, it in ipairs(items) do
      local active = it.buf == curbuf
      local hl = active and '%#TermBarActive#' or '%#TermBarInactive#'
      local label = it.claude and 'Claude' or 'Term'
      parts[#parts + 1] = hl .. '%' .. it.slot .. '@v:lua.TermBarClick@ [' .. it.slot .. '] ' .. label .. ' %X'
    end
    return table.concat(parts) .. '%#TermBarFill#'
  end

  ---Tab-bar click handler: `minwid` is the slot encoded into each tab above.
  function _G.TermBarClick(slot) _G.TermGoto(slot) end

  -- Thin vertical terminal bar on the right edge, shown while editing: one cell per
  -- open terminal, labelled compactly `1T` / `2C` (slot + Term/Claude). Hidden inside
  -- terminal floats (those show the top winbar) and when no terminals are open. Plain
  -- buffer + per-line extmark highlights; display-only -- switch with `{count}<C-t>`.
  -- Avoids touching the statusline / tabline / laststatus, so nothing else changes.
  -- (Claude run-state is now shown by the external `claude-tmux` package, not here.)
  local rbar = {}
  local rbar_ns = vim.api.nvim_create_namespace 'term_rbar'
  local function rbar_hide()
    if rbar.win and vim.api.nvim_win_is_valid(rbar.win) then pcall(vim.api.nvim_win_close, rbar.win, true) end
    rbar.win = nil
  end
  local function rbar_refresh()
    local cur = vim.api.nvim_get_current_buf()
    if vim.bo[cur].buftype == 'terminal' or vim.fn.getcmdwintype() ~= '' then return rbar_hide() end
    local items = term_open_slots()
    if #items == 0 then return rbar_hide() end
    -- Compact labels (`1T`, `2C`), their highlight, and slot.
    local labels, lhls, slots, maxlen = {}, {}, {}, 0
    for i, it in ipairs(items) do
      labels[i] = it.slot .. (it.claude and 'C' or 'T')
      slots[i] = it.slot
      maxlen = math.max(maxlen, #labels[i])
      lhls[i] = 'TermRbarTerm'
    end
    -- Lay out as fully-colored 1-row chips with a plain dark gap between them (no
    -- gap before the first or after the last, so the last chip has no leftover).
    -- `line_slot` maps each row (1-based) to a slot so clicks switch terminals.
    local cw = maxlen + 2
    local blank = string.rep(' ', cw)
    local lines, line_hl = {}, {}
    rbar.line_slot = {}
    for i, lab in ipairs(labels) do
      if i > 1 then
        lines[#lines + 1] = blank -- dark gap (Normal:TermRbarFill); no highlight
        rbar.line_slot[#lines] = slots[i - 1]
      end
      local pad = cw - #lab
      local left = math.floor(pad / 2)
      lines[#lines + 1] = string.rep(' ', left) .. lab .. string.rep(' ', pad - left)
      line_hl[#lines] = lhls[i]
      rbar.line_slot[#lines] = slots[i]
    end
    if not (rbar.buf and vim.api.nvim_buf_is_valid(rbar.buf)) then
      rbar.buf = vim.api.nvim_create_buf(false, true)
      vim.bo[rbar.buf].bufhidden = 'hide'
    end
    vim.api.nvim_buf_set_lines(rbar.buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(rbar.buf, rbar_ns, 0, -1)
    for ln, hl in pairs(line_hl) do
      pcall(vim.api.nvim_buf_set_extmark, rbar.buf, rbar_ns, ln - 1, 0, { end_col = #lines[ln], hl_group = hl })
    end
    local cfg = {
      relative = 'editor',
      anchor = 'NE',
      row = 1,
      col = vim.o.columns,
      width = cw,
      height = #lines,
      focusable = true,
      style = 'minimal',
      zindex = 35,
      noautocmd = true,
    }
    if rbar.win and vim.api.nvim_win_is_valid(rbar.win) then
      pcall(vim.api.nvim_win_set_config, rbar.win, cfg)
    else
      rbar.win = vim.api.nvim_open_win(rbar.buf, false, cfg)
      vim.wo[rbar.win].winhighlight = 'Normal:TermRbarFill,NormalNC:TermRbarFill'
    end
  end
  _G.TermRbarRefresh = rbar_refresh

  -- Click a cell in the right-edge bar to switch to that terminal. A global
  -- <LeftMouse> handler checks (via getmousepos) whether the click landed on the
  -- bar; if so it routes to that slot and consumes the click, otherwise it passes
  -- the click through unchanged.
  vim.keymap.set('n', '<LeftMouse>', function()
    local pos = vim.fn.getmousepos()
    if rbar.win and vim.api.nvim_win_is_valid(rbar.win) and pos.winid == rbar.win then
      local slot = rbar.line_slot and rbar.line_slot[pos.line]
      if slot then
        vim.schedule(function() _G.TermGoto(slot) end)
        return ''
      end
    end
    return '<LeftMouse>'
  end, { expr = true, desc = 'Click terminal bar to switch (else normal click)' })
  vim.api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter', 'WinClosed', 'TermClose', 'VimResized', 'TabEnter', 'CmdlineLeave' }, {
    desc = 'Refresh the vertical terminal bar',
    callback = function() vim.schedule(rbar_refresh) end,
  })

  -- Terminal dispatcher. Slot 2 = claudecode.nvim (floating); every other slot is
  -- a Snacks terminal. {count}<C-t> switches to terminal #count (TermGoto hides the
  -- current float first, so they don't stack); bare <C-t> toggles the last-used one.
  local term_last_slot = 1
  function _G.TermToggle(slot)
    slot = slot or (vim.v.count ~= 0 and vim.v.count) or term_last_slot
    term_last_slot = slot
    if slot == 2 then
      require('claudecode.terminal').simple_toggle(claude_float)
    else
      Snacks.terminal.toggle(nil, term_opts(slot))
    end
  end

  vim.keymap.set('n', '<C-t>', function()
    if vim.v.count ~= 0 then
      _G.TermGoto(vim.v.count) -- {count}<C-t> -> switch to that terminal
    else
      _G.TermToggle() -- bare <C-t> -> toggle the last-used terminal
    end
  end, { desc = 'Terminal: {count} switches to slot N (2 = Claude); bare toggles last' })
  -- From inside a terminal, <C-t> hides whichever terminal you are in (counts don't
  -- work in terminal mode; drop to normal mode for {count}<C-t> to switch).
  vim.keymap.set('t', '<C-t>', function() term_hide_buf(vim.api.nvim_get_current_buf()) end, { desc = 'Hide current terminal' })

  -- GitHub Copilot (vimscript plugin; no setup() call needed).
  vim.pack.add { gh 'github/copilot.vim' }

  -- Visual indent guides.
  vim.pack.add { gh 'lukas-reineke/indent-blankline.nvim' }
  require('ibl').setup {}

  -- Better Python indentation than treesitter's (used because TS python indent is disabled above).
  vim.pack.add { gh 'Vimjas/vim-python-pep8-indent' }

  -- Claude Code CLI integration. Requires the `claude` CLI to be installed and on PATH.
  -- snacks.nvim is claudecode's recommended terminal-UI dependency (nicer pane styling).
  vim.pack.add { gh 'folke/snacks.nvim', gh 'coder/claudecode.nvim' }
  require('snacks').setup {}
  -- `terminal_cmd` is the base command the plugin launches; flags such as
  -- `--resume` / `--continue` (see the <leader>a* maps below) are appended after it.
  -- We default to --dangerously-skip-permissions so Claude never stops to ask.
  require('claudecode').setup { terminal_cmd = 'claude --dangerously-skip-permissions' }

  -- <C-q> leaves terminal mode here without colliding with Claude's own
  -- <Esc>/<Esc><Esc> bindings (interrupt and rewind) — it is mapped globally for
  -- all terminals in section 1, so no buffer-local override is needed.
  -- Darker background for the Claude pane so it visually separates from the editor.
  vim.api.nvim_set_hl(0, 'ClaudeBg', { bg = '#0d0e16' })
  local function is_claude_buf(buf) return vim.bo[buf].filetype == 'claudecode' end
  local function style_claude_win(win) vim.wo[win].winhighlight = 'Normal:ClaudeBg,NormalNC:ClaudeBg,SignColumn:ClaudeBg,EndOfBuffer:ClaudeBg' end

  vim.api.nvim_create_autocmd('TermOpen', {
    pattern = '*',
    callback = function(args)
      if not is_claude_buf(args.buf) then return end
      -- Close the Claude pane outright from terminal mode (single keystroke).
      vim.keymap.set('t', '<M-q>', [[<C-\><C-n><cmd>ClaudeCodeClose<cr>]], { buffer = args.buf, desc = 'Close Claude pane' })
      -- In normal mode of the Claude buffer, plain `q` closes the pane (no recording macros here).
      vim.keymap.set('n', 'q', '<cmd>ClaudeCodeClose<cr>', { buffer = args.buf, desc = 'Close Claude pane' })
      vim.keymap.set('n', '<leader>al', function()
        vim.cmd 'redraw!'
        local job = vim.b[args.buf].terminal_job_id
        if job then vim.fn.chansend(job, '\012') end -- ^L = redraw to most TUIs
      end, { buffer = args.buf, desc = '[A]I claude re[L]oad screen' })
      style_claude_win(vim.api.nvim_get_current_win())

      -- `:q` typed inside the Claude pane hides the pane instead of killing the window.
      -- (`:q!` still works as a real force-quit if you need it.)
      vim.cmd 'cabbrev <buffer> q ClaudeCodeClose'

      -- When the Claude process exits (e.g. Ctrl-C twice), wipe the terminal buffer
      -- instead of leaving a "[Process exited 0]" zombie.
      vim.api.nvim_create_autocmd('TermClose', {
        buffer = args.buf,
        callback = function()
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then vim.api.nvim_buf_delete(args.buf, { force = true }) end
          end)
        end,
      })
    end,
  })

  -- Re-apply darker bg AND force Claude's TUI to repaint whenever its buffer
  -- enters a window. Claude (React Ink) only fully redraws on a terminal-resize
  -- (SIGWINCH), so we briefly nudge the window width by 1 col and restore it —
  -- each change resizes the PTY and triggers a clean repaint.
  vim.api.nvim_create_autocmd('BufWinEnter', {
    pattern = '*',
    callback = function(args)
      if not is_claude_buf(args.buf) then return end
      local win = vim.api.nvim_get_current_win()
      style_claude_win(win)
      -- Re-assert the terminal tab bar. claudecode only applies the winbar from
      -- snacks_win_opts on first creation; after the pane is wiped on exit and
      -- recreated (2<C-t>), the window-local option is lost, so the bar vanishes.
      -- Setting it on every BufWinEnter keeps `[2] Claude` showing across recreates.
      vim.wo[win].winbar = '%!v:lua.TermWinbar()'
      vim.defer_fn(function()
        if not (vim.api.nvim_buf_is_valid(args.buf) and vim.api.nvim_win_is_valid(win)) then return end
        if vim.api.nvim_win_get_buf(win) ~= args.buf then return end
        local w = vim.api.nvim_win_get_width(win)
        pcall(vim.api.nvim_win_set_width, win, w - 1)
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_set_width, win, w) end
          vim.cmd 'redraw!'
        end)
      end, 80)
    end,
  })

  -- Nudge any visible terminal to redraw when nvim itself is resized.
  vim.api.nvim_create_autocmd('VimResized', { callback = function() vim.cmd 'redraw!' end })
  -- Copy a claudecode-style @-mention of the current location to the system
  -- clipboard, so it can be pasted into ANY other Claude Code instance (e.g. one
  -- running in another tmux pane) — they no longer have to live inside nvim.
  -- The format mirrors what claudecode.nvim sends over its websocket (its
  -- `_format_path_for_at_mention` + the at_mention lineStart/lineEnd params):
  --   * path is relative to cwd when the file is under it, else absolute;
  --   * a directory keeps a trailing '/';
  --   * line info is appended as #L<line> (single line) or #L<start>-<end> (range).
  -- Claude Code parses `@path` mentions out of pasted text and pulls the file into
  -- context (see its docs); the #L suffix tells it which lines to focus on.
  _G.ClaudeCopyMention = function(abs_path, start_line, end_line)
    if not abs_path or abs_path == '' then
      vim.notify('Claude: no file to copy a mention for', vim.log.levels.WARN)
      return
    end
    abs_path = vim.fn.fnamemodify(abs_path, ':p')
    local is_dir = vim.fn.isdirectory(abs_path) == 1
    local clean = is_dir and (abs_path:gsub('/$', '')) or abs_path
    local cwd = vim.fn.getcwd()
    local path = clean
    if clean == cwd then
      path = './'
    elseif vim.startswith(clean, cwd .. '/') then
      path = clean:sub(#cwd + 2)
    end
    if is_dir then
      if not path:match '/$' then path = path .. '/' end
      start_line, end_line = nil, nil -- line numbers are meaningless for a directory
    end
    local mention = '@' .. path
    if start_line then
      mention = mention .. '#L' .. start_line
      if end_line and end_line ~= start_line then mention = mention .. '-' .. end_line end
    end
    vim.fn.setreg('+', mention) -- system clipboard (clipboard=unnamedplus / OSC52 over SSH)
    vim.notify('Copied for Claude: ' .. mention)
  end
  -- <leader>ac copies a Claude @-mention to the clipboard: the current file+line in
  -- normal mode, the selected range in visual mode, the node under cursor in
  -- NvimTree. It no longer toggles Claude — that is 2<C-t> (terminal dispatcher).
  vim.keymap.set(
    'n',
    '<leader>ac',
    function() _G.ClaudeCopyMention(vim.api.nvim_buf_get_name(0), vim.fn.line '.') end,
    { desc = '[A]I [C]opy @-mention (file:line) for Claude' }
  )
  vim.keymap.set('v', '<leader>ac', function()
    local s, e = vim.fn.line 'v', vim.fn.line '.'
    if s > e then
      s, e = e, s
    end
    _G.ClaudeCopyMention(vim.api.nvim_buf_get_name(0), s, e)
    -- Leave visual mode afterwards, the way `y` clears the selection once done.
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
  end, { desc = '[A]I [C]opy @-mention (selection) for Claude' })
  -- Claude as a floating window is reachable via 2<C-t> (see the terminal dispatcher).
  vim.keymap.set('n', '<leader>af', '<cmd>ClaudeCodeFocus<cr>', { desc = '[A]I claude [F]ocus' })
  vim.keymap.set('n', '<leader>ar', '<cmd>ClaudeCode --resume<cr>', { desc = '[A]I claude [R]esume' })
  vim.keymap.set('n', '<leader>aC', '<cmd>ClaudeCode --continue<cr>', { desc = '[A]I claude [C]ontinue' })
  vim.keymap.set('n', '<leader>am', '<cmd>ClaudeCodeSelectModel<cr>', { desc = '[A]I claude select [M]odel' })
  vim.keymap.set('n', '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>', { desc = '[A]I claude add [B]uffer' })
  vim.keymap.set('v', '<leader>as', '<cmd>ClaudeCodeSend<cr>', { desc = '[A]I claude [S]end selection' })
  -- In NvimTree / netrw / oil, <leader>as adds the highlighted file or dir to Claude's context.
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'NvimTree', 'neo-tree', 'oil', 'minifiles', 'netrw' },
    callback = function(args) vim.keymap.set('n', '<leader>as', '<cmd>ClaudeCodeTreeAdd<cr>', { buffer = args.buf, desc = '[A]I claude add file from tree' }) end,
  })
  vim.keymap.set('n', '<leader>aa', '<cmd>ClaudeCodeDiffAccept<cr>', { desc = '[A]I claude diff [A]ccept' })
  vim.keymap.set('n', '<leader>ad', '<cmd>ClaudeCodeDiffDeny<cr>', { desc = '[A]I claude diff [D]eny' })

  -- Here is a more advanced configuration example that passes options to `gitsigns.nvim`
  --
  -- See `:help gitsigns` to understand what each configuration key does.
  -- Adds git related signs to the gutter, as well as utilities for managing changes
  vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
  require('gitsigns').setup {
    signs = {
      add = { text = '+' }, ---@diagnostic disable-line: missing-fields
      change = { text = '~' }, ---@diagnostic disable-line: missing-fields
      delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
      topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
      changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
    },
  }

  -- Useful plugin to show you pending keybinds.
  vim.pack.add { gh 'folke/which-key.nvim' }
  require('which-key').setup {
    preset = 'modern', -- rounded borders + arrow-style layout (LazyVim look)
    delay = 500,
    -- Only pop the menu when <leader> is explicitly pressed — never on mode entry,
    -- mouse-driven visual mode, idle pauses, etc.
    triggers = {
      { '<leader>', mode = { 'n', 'v' } },
    },
    icons = { mappings = vim.g.have_nerd_font },
    -- Document existing key chains
    spec = {
      { '<leader>a', group = 'AI / Claude' },
      { '<leader>g', group = 'Git' },
      { '<leader>s', group = 'Search', mode = { 'n', 'v' } },
      { '<leader>t', group = 'Trouble / Toggle' },
      { '<leader>h', group = 'Git Hunk', mode = { 'n', 'v' } }, -- Enable gitsigns recommended keymaps first
      { 'gr', group = 'LSP Actions', mode = { 'n' } },
    },
  }

  -- [[ Colorscheme ]]
  -- You can easily change to a different colorscheme.
  -- Change the name of the colorscheme plugin below, and then
  -- change the command under that to load whatever the name of that colorscheme is.
  --
  -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
  vim.pack.add { gh 'folke/tokyonight.nvim' }
  ---@diagnostic disable-next-line: missing-fields
  require('tokyonight').setup {
    styles = {
      comments = { italic = false }, -- Disable italics in comments
    },
  }

  -- Load the colorscheme here.
  -- Like many other themes, this one has different styles, and you could load
  -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
  vim.cmd.colorscheme 'tokyonight-night'

  -- Highlight todo, notes, etc in comments
  vim.pack.add { gh 'folke/todo-comments.nvim' }
  require('todo-comments').setup { signs = false }

  -- [[ mini.nvim ]]
  --  A collection of various small independent plugins/modules
  vim.pack.add { gh 'nvim-mini/mini.nvim' }

  -- Better Around/Inside textobjects
  --
  -- Examples:
  --  - va)  - [V]isually select [A]round [)]paren
  --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
  --  - ci'  - [C]hange [I]nside [']quote
  require('mini.ai').setup {
    -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
    mappings = {
      around_next = 'aa',
      inside_next = 'ii',
    },
    n_lines = 500,
  }

  -- Add/delete/replace surroundings (brackets, quotes, etc.)
  --
  -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
  -- - sd'   - [S]urround [D]elete [']quotes
  -- - sr)'  - [S]urround [R]eplace [)] [']
  require('mini.surround').setup()

  -- Simple and easy statusline.
  --  You could remove this setup call if you don't like it,
  --  and try some other statusline plugin
  local statusline = require 'mini.statusline'
  -- Set `use_icons` to true if you have a Nerd Font
  statusline.setup { use_icons = vim.g.have_nerd_font }

  -- You can configure sections in the statusline by overriding their
  -- default behavior. For example, here we set the section for
  -- cursor location to LINE:COLUMN
  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_location = function() return '%2l:%-2v' end

  -- ... and there is more!
  --  Check out: https://github.com/nvim-mini/mini.nvim
end

-- ============================================================
-- SECTION 4: SEARCH & NAVIGATION
-- Telescope setup, keymaps, LSP picker mappings
-- ============================================================
do
  -- [[ Fuzzy Finder (files, lsp, etc) ]]
  --
  -- Telescope is a fuzzy finder that comes with a lot of different things that
  -- it can fuzzy find! It's more than just a "file finder", it can search
  -- many different aspects of Neovim, your workspace, LSP, and more!
  --
  -- There are lots of other alternative pickers (like snacks.picker, or fzf-lua)
  -- so feel free to experiment and see what you like!
  --
  -- The easiest way to use Telescope, is to start by doing something like:
  --  :Telescope help_tags
  --
  -- After running this command, a window will open up and you're able to
  -- type in the prompt window. You'll see a list of `help_tags` options and
  -- a corresponding preview of the help.
  --
  -- Two important keymaps to use while in Telescope are:
  --  - Insert mode: <c-/>
  --  - Normal mode: ?
  --
  -- This opens a window that shows you all of the keymaps for the current
  -- Telescope picker. This is really useful to discover what Telescope can
  -- do as well as how to actually do it!

  ---@type (string|vim.pack.Spec)[]
  local telescope_plugins = {
    gh 'nvim-lua/plenary.nvim',
    gh 'nvim-telescope/telescope.nvim',
    gh 'nvim-telescope/telescope-ui-select.nvim',
  }
  if vim.fn.executable 'make' == 1 then table.insert(telescope_plugins, gh 'nvim-telescope/telescope-fzf-native.nvim') end

  -- NOTE: You can install multiple plugins at once
  vim.pack.add(telescope_plugins)

  -- See `:help telescope` and `:help telescope.setup()`
  require('telescope').setup {
    -- You can put your default mappings / updates / etc. in here
    --  All the info you're looking for is in `:help telescope.setup()`
    --
    -- defaults = {
    --   mappings = {
    --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
    --   },
    -- },
    -- pickers = {}
    extensions = {
      ['ui-select'] = { require('telescope.themes').get_dropdown() },
    },
  }

  -- Enable Telescope extensions if they are installed
  pcall(require('telescope').load_extension, 'fzf')
  pcall(require('telescope').load_extension, 'ui-select')

  -- See `:help telescope.builtin`
  local builtin = require 'telescope.builtin'
  vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
  vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
  vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
  vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
  vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
  vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
  vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
  vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

  -- Add Telescope-based LSP pickers when an LSP attaches to a buffer.
  -- If you later switch picker plugins, this is where to update these mappings.
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
    callback = function(event)
      local buf = event.buf

      -- Find references for the word under your cursor.
      vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })

      -- Jump to the implementation of the word under your cursor.
      -- Useful when your language has ways of declaring types without an actual implementation.
      vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })

      -- Jump to the definition of the word under your cursor.
      -- This is where a variable was first declared, or where a function is defined, etc.
      -- To jump back, press <C-t>.
      vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })

      -- Fuzzy find all the symbols in your current document.
      -- Symbols are things like variables, functions, types, etc.
      vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })

      -- Fuzzy find all the symbols in your current workspace.
      -- Similar to document symbols, except searches over your entire project.
      vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })

      -- Jump to the type of the word under your cursor.
      -- Useful when you're not sure what type a variable is and you want to see
      -- the definition of its *type*, not where it was *defined*.
      vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
    end,
  })

  -- Override default behavior and theme when searching
  vim.keymap.set('n', '<leader>/', function()
    -- You can pass additional configuration to Telescope to change the theme, layout, etc.
    builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
      winblend = 10,
      previewer = false,
    })
  end, { desc = '[/] Fuzzily search in current buffer' })

  -- It's also possible to pass additional configuration options.
  --  See `:help telescope.builtin.live_grep()` for information about particular keys
  vim.keymap.set(
    'n',
    '<leader>s/',
    function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end,
    { desc = '[S]earch [/] in Open Files' }
  )

  -- Shortcut for searching your Neovim configuration files
  vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
end

-- ============================================================
-- SECTION 5: LSP
-- LSP keymaps, server configuration, Mason tools installations
-- ============================================================
do
  -- [[ LSP Configuration ]]
  -- Brief aside: **What is LSP?**
  --
  -- LSP is an initialism you've probably heard, but might not understand what it is.
  --
  -- LSP stands for Language Server Protocol. It's a protocol that helps editors
  -- and language tooling communicate in a standardized fashion.
  --
  -- In general, you have a "server" which is some tool built to understand a particular
  -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
  -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
  -- processes that communicate with some "client" - in this case, Neovim!
  --
  -- LSP provides Neovim with features like:
  --  - Go to definition
  --  - Find references
  --  - Autocompletion
  --  - Symbol Search
  --  - and more!
  --
  -- Thus, Language Servers are external tools that must be installed separately from
  -- Neovim. This is where `mason` and related plugins come into play.
  --
  -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
  -- and elegantly composed help section, `:help lsp-vs-treesitter`

  -- Useful status updates for LSP.
  vim.pack.add { gh 'j-hui/fidget.nvim' }
  require('fidget').setup {}

  -- Global fallbacks for the `gr*` LSP keymaps.
  -- The LspAttach autocmds below (and the telescope-lsp-attach autocmd in section 4)
  -- install buffer-local `gr*` maps that shadow these whenever a language server is
  -- attached. Without an LSP, these globals fire instead — which stops vanilla
  -- `gr{char}` (virtual-replace, which silently overwrites the character under the
  -- cursor) from clobbering text. Where an in-file builtin exists we degrade to it
  -- (grd -> gd, grD -> gD, grr -> *); otherwise we just emit a notice.
  local function lsp_fallback(keys, label)
    return function()
      if keys then
        vim.notify('LSP not attached — falling back to `' .. keys .. '` (' .. label .. ')', vim.log.levels.WARN)
        vim.cmd('normal! ' .. keys)
      else
        vim.notify('LSP not attached — ' .. label .. ' needs a language server', vim.log.levels.WARN)
      end
    end
  end

  vim.keymap.set('n', 'grd', lsp_fallback('gd', 'definition in file'), { desc = 'LSP: [G]oto [D]efinition (fallback: gd)' })
  vim.keymap.set('n', 'grD', lsp_fallback('gD', 'declaration in file'), { desc = 'LSP: [G]oto [D]eclaration (fallback: gD)' })
  vim.keymap.set('n', 'grr', lsp_fallback('*', 'search word in file'), { desc = 'LSP: [G]oto [R]eferences (fallback: *)' })
  vim.keymap.set('n', 'gri', lsp_fallback(nil, '[G]oto [I]mplementation'), { desc = 'LSP: [G]oto [I]mplementation (needs LSP)' })
  vim.keymap.set('n', 'grt', lsp_fallback(nil, '[G]oto [T]ype Definition'), { desc = 'LSP: [G]oto [T]ype Definition (needs LSP)' })
  vim.keymap.set('n', 'grn', lsp_fallback(nil, '[R]e[n]ame'), { desc = 'LSP: [R]e[n]ame (needs LSP)' })
  vim.keymap.set({ 'n', 'x' }, 'gra', lsp_fallback(nil, 'Code [A]ction'), { desc = 'LSP: Code [A]ction (needs LSP)' })

  --  This function gets run when an LSP attaches to a particular buffer.
  --    That is to say, every time a new file is opened that is associated with
  --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
  --    function will be executed to configure the current buffer
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
    callback = function(event)
      -- NOTE: Remember that Lua is a real programming language, and as such it is possible
      -- to define small helper and utility functions so you don't have to repeat yourself.
      --
      -- In this case, we create a function that lets us more easily define mappings specific
      -- for LSP related items. It sets the mode, buffer and description for us each time.
      local map = function(keys, func, desc, mode)
        mode = mode or 'n'
        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
      end

      -- Rename the variable under your cursor.
      --  Most Language Servers support renaming across files, etc.
      map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

      -- Execute a code action, usually your cursor needs to be on top of an error
      -- or a suggestion from your LSP for this to activate.
      map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

      -- WARN: This is not Goto Definition, this is Goto Declaration.
      --  For example, in C this would take you to the header.
      map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

      -- The following two autocommands are used to highlight references of the
      -- word under your cursor when your cursor rests there for a little while.
      --    See `:help CursorHold` for information about when this is executed
      --
      -- When you move your cursor, the highlights will be cleared (the second autocommand).
      local client = vim.lsp.get_client_by_id(event.data.client_id)

      -- WORKAROUND: this host runs a Meta-patched nvim whose vim/lsp/rpc.lua nils out
      -- `result` (vim.NIL -> nil) before its response-validity check, so spec-valid
      -- `{"id":N,"result":null}` replies (e.g. pyright's documentHighlight when off a symbol)
      -- get flagged as INVALID_SERVER_MESSAGE and echoed as an error. Client:write_error runs
      -- unconditionally (a per-server on_error can't stop it), so we wrap it per client to
      -- swallow ONLY that false positive and pass every other error through. See
      -- docs/common_issues.md. Remove once the upstream rpc.lua patch is fixed.
      if client and not client._suppress_invalid_msg then
        client._suppress_invalid_msg = true
        local write_error = client.write_error
        client.write_error = function(self, code, err)
          if vim.lsp.rpc.client_errors[code] == 'INVALID_SERVER_MESSAGE' then return end
          return write_error(self, code, err)
        end
      end

      if client and client:supports_method('textDocument/documentHighlight', event.buf) then
        local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.clear_references,
        })

        vim.api.nvim_create_autocmd('LspDetach', {
          group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
          callback = function(event2)
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
          end,
        })
      end

      -- The following code creates a keymap to toggle inlay hints in your
      -- code, if the language server you are using supports them
      --
      -- This may be unwanted, since they displace some of your code
      if client and client:supports_method('textDocument/inlayHint', event.buf) then
        map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
      end
    end,
  })

  -- Enable the following language servers
  --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
  --  See `:help lsp-config` for information about keys and how to configure
  ---@type table<string, vim.lsp.Config>
  local servers = {
    -- clangd = {},
    -- gopls = {},
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
    -- rust_analyzer = {},
    --
    -- Some languages (like typescript) have entire language plugins that can be useful:
    --    https://github.com/pmizio/typescript-tools.nvim
    --
    -- But for many setups, the LSP (`ts_ls`) will work just fine
    -- ts_ls = {},

    stylua = {}, -- Used to format Lua code

    -- Special Lua Config, as recommended by neovim help docs
    lua_ls = {
      on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
        end

        client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
          runtime = {
            version = 'LuaJIT',
            path = { 'lua/?.lua', 'lua/?/init.lua' },
          },
          workspace = {
            checkThirdParty = false,
            -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
            --  See https://github.com/neovim/nvim-lspconfig/issues/3189
            library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
              '${3rd}/luv/library',
              '${3rd}/busted/library',
            }),
          },
        })
      end,
      ---@type lspconfig.settings.lua_ls
      settings = {
        Lua = {
          format = { enable = false }, -- Disable formatting (formatting is done by stylua)
        },
      },
    },
  }

  vim.pack.add {
    gh 'neovim/nvim-lspconfig',
    gh 'mason-org/mason.nvim',
    gh 'mason-org/mason-lspconfig.nvim',
    gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
  }

  -- Automatically install LSPs and related tools to stdpath for Neovim
  require('mason').setup {}

  -- Ensure the servers and tools above are installed
  --
  -- To check the current status of installed tools and/or manually install
  -- other tools, you can run
  --    :Mason
  --
  -- You can press `g?` for help in this menu.
  local ensure_installed = vim.tbl_keys(servers or {})
  vim.list_extend(ensure_installed, {
    -- You can add other tools here that you want Mason to install
  })

  require('mason-tool-installer').setup { ensure_installed = ensure_installed }

  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end
end

-- ============================================================
-- SECTION 6: FORMATTING
-- conform.nvim setup and keymap
-- ============================================================
do
  -- [[ Formatting ]]
  vim.pack.add { gh 'stevearc/conform.nvim' }
  require('conform').setup {
    notify_on_error = false,
    format_on_save = function(bufnr)
      -- You can specify filetypes to autoformat on save here:
      local enabled_filetypes = {
        -- lua = true,
        -- python = true,
      }
      if enabled_filetypes[vim.bo[bufnr].filetype] then
        return { timeout_ms = 500 }
      else
        return nil
      end
    end,
    default_format_opts = {
      lsp_format = 'fallback', -- Use external formatters if configured below, otherwise use LSP formatting. Set to `false` to disable LSP formatting entirely.
    },
    -- You can also specify external formatters in here.
    formatters_by_ft = {
      -- rust = { 'rustfmt' },
      -- Conform can also run multiple formatters sequentially
      -- python = { "isort", "black" },
      --
      -- You can use 'stop_after_first' to run the first available formatter from the list
      -- javascript = { "prettierd", "prettier", stop_after_first = true },
    },
  }

  vim.keymap.set({ 'n', 'v' }, '<leader>f', function() require('conform').format { async = true } end, { desc = '[F]ormat buffer' })
end

-- ============================================================
-- SECTION 7: AUTOCOMPLETE & SNIPPETS
-- blink.cmp and luasnip setup
-- ============================================================
do
  -- [[ Snippet Engine ]]

  -- NOTE: You can also specify plugin using a version range for its git tag.
  --  See `:help vim.version.range()` for more info
  vim.pack.add { { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' } }
  require('luasnip').setup {}

  -- `friendly-snippets` contains a variety of premade snippets.
  --    See the README about individual language/framework/plugin snippets:
  --    https://github.com/rafamadriz/friendly-snippets
  --
  -- vim.pack.add { gh 'rafamadriz/friendly-snippets' }
  -- require('luasnip.loaders.from_vscode').lazy_load()

  -- [[ Autocomplete Engine ]]
  vim.pack.add { { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' } }
  require('blink.cmp').setup {
    keymap = {
      -- 'default' (recommended) for mappings similar to built-in completions
      --   <c-y> to accept ([y]es) the completion.
      --    This will auto-import if your LSP supports it.
      --    This will expand snippets if the LSP sent a snippet.
      -- 'super-tab' for tab to accept
      -- 'enter' for enter to accept
      -- 'none' for no mappings
      --
      -- For an understanding of why the 'default' preset is recommended,
      -- you will need to read `:help ins-completion`
      --
      -- No, but seriously. Please read `:help ins-completion`, it is really good!
      --
      -- All presets have the following mappings:
      -- <tab>/<s-tab>: move to right/left of your snippet expansion
      -- <c-space>: Open menu or open docs if already open
      -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
      -- <c-e>: Hide menu
      -- <c-k>: Toggle signature help
      --
      -- See `:help blink-cmp-config-keymap` for defining your own keymap
      preset = 'default',

      -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
      --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
    },

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = 'mono',
    },

    completion = {
      -- By default, you may press `<c-space>` to show the documentation.
      -- Optionally, set `auto_show = true` to show the documentation after a delay.
      documentation = { auto_show = false, auto_show_delay_ms = 500 },
    },

    sources = {
      default = { 'lsp', 'path', 'snippets' },
    },

    snippets = { preset = 'luasnip' },

    -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
    -- which automatically downloads a prebuilt binary when enabled.
    --
    -- By default, we use the Lua implementation instead, but you may enable
    -- the rust implementation via `'prefer_rust_with_warning'`
    --
    -- See `:help blink-cmp-config-fuzzy` for more information
    fuzzy = { implementation = 'lua' },

    -- Shows a signature help window while you type arguments for a function
    signature = { enabled = true },
  }
end

-- ============================================================
-- SECTION 8: TREESITTER
-- Parser installation, syntax highlighting, folds, indentation
-- ============================================================
do
  -- [[ Configure Treesitter ]]
  --  Used to highlight, edit, and navigate code
  --
  --  See `:help nvim-treesitter-intro`

  -- NOTE: You can also specify a branch or a specific commit
  vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

  -- Ensure basic parsers are installed
  local parsers = {
    'bash',
    'c',
    'diff',
    'html',
    'lua',
    'luadoc',
    'markdown',
    'markdown_inline',
    'query',
    'vim',
    'vimdoc',
    'python',
    'javascript',
    'typescript',
    'tsx',
    'json',
    'yaml',
    'css',
    'rust',
    'java',
  }
  require('nvim-treesitter').install(parsers)

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    -- Check if a parser exists and load it
    if not vim.treesitter.language.add(language) then return end
    -- Enable syntax highlighting and other treesitter features
    vim.treesitter.start(buf, language)

    -- Enable treesitter based folds
    -- For more info on folds see `:help folds`
    -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    -- vim.wo.foldmethod = 'expr'

    -- Check if treesitter indentation is available for this language, and if so enable it
    -- in case there is no indent query, the indentexpr will fallback to the vim's built in one
    -- Disable treesitter indent for python; vim-python-pep8-indent handles it better.
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
    if has_indent_query and language ~= 'python' then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match

      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end

      local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

      if vim.tbl_contains(installed_parsers, language) then
        -- Enable the parser if it is already installed
        treesitter_try_attach(buf, language)
      elseif vim.tbl_contains(available_parsers, language) then
        -- If a parser is available in `nvim-treesitter`, auto-install it and enable it after the installation is done
        require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
      else
        -- Try to enable treesitter features in case the parser exists but is not available from `nvim-treesitter`
        treesitter_try_attach(buf, language)
      end
    end,
  })
end

-- ============================================================
-- SECTION 9: OPTIONAL EXAMPLES / NEXT STEPS
-- kickstart.plugins.* examples
-- ============================================================
do
  -- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug'
  -- require 'kickstart.plugins.indent_line'
  -- require 'kickstart.plugins.lint'
  -- require 'kickstart.plugins.autopairs'
  -- require 'kickstart.plugins.neo-tree'
  -- require 'kickstart.plugins.gitsigns' -- adds gitsigns recommended keymaps

  -- NOTE: You can add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  -- require 'custom.plugins'
end

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
