# Personal Neovim config

This config targets Neovim 0.12 and uses lazy.nvim. Plugin versions remain pinned
in `lazy-lock.json`. Restart Neovim after changing the config; sourcing the whole
init file is not a supported plugin reload mechanism.

## Setup

Use `sudoedit` to edit privileged files with your usual plugins. Directly running
this config as root through sudo skips plugin loading.

Search uses `rg`. The native Telescope sorter needs a C compiler and CMake or
Make. Run `:Lazy build telescope-fzf-native.nvim` after installing the tools.

Open `:Lazy` to install plugins. Use `:MasonToolsInstall` to install the configured
language servers, formatters, linters and the debugpy Python debugger. Run
`:TSInstallCommon` once to install the configured Treesitter parsers. Tool/parser updates and
installs are explicit so normal startup does not launch tool downloads.

C/C++ debugging additionally needs an LLVM `lldb-dap` executable. The config looks
on PATH and in common macOS LLVM locations. On macOS, CMake debug sessions
use LLDB’s internal console. Choose **Run** for an interactive terminal.
Install C/C++ linting with your system package manager (`brew install cppcheck` on macOS).
Rust needs a rustup toolchain with `rust-analyzer`, `rustfmt`, and `clippy`;
Install these components with rustup so the project's toolchain selects its analyzer. Python uses the
active virtual environment, a project's `.venv` or `venv`, then Python on PATH. Flutter's Dart is preferred when available.

## SQL with a local schema

Run `python3 scripts/install-sql-lsp.py` once to install RainLib's `sql-lsp`
v0.1.3 (release checksum verified) and SQLGlot 28.0.0 in Neovim's data directory.
Restart Neovim, then open a `.sql` file. The `sql_schema` LSP supplies SQL
completion through Blink without connecting to a database or executing SQL.

For Lumin, run `:SqlSchemaSync` in a SQL buffer to fetch visible table and
column metadata through `chq`. The LSP loads the per-repository cache on future
starts, including offline. Run the command again after schema changes.
The cache takes precedence over `schema.sql`. A failed sync keeps the last successful catalog.

For an offline DDL catalog, put `schema.sql` at the nearest Git repository root. Queries in subdirectories
use that file; nested repositories do not inherit an outer repository's schema.
Outside Git, the nearest ancestor containing `schema.sql` is used. The file must
contain `CREATE TABLE` definitions with explicit columns. ClickHouse exports
with one CREATE per line and no semicolons are supported. Queries default to the
ClickHouse dialect; explicit server-supported suffixes such as `.postgres.sql`
select that dialect. This is an offline editing aid, not server-side SQL validation.

When using the DDL catalog, saving `schema.sql` reloads completion metadata. After external edits, run
`:SqlSchemaReload`. Check attachment with `:checkhealth vim.lsp`; press `Ctrl-Space`
in Insert mode for completion. Missing schemas leave keyword completion available;
invalid schemas produce an error and clear stale completion metadata. Schema
inference and advanced alias resolution are limited by the upstream server.
Query syntax diagnostics use the local SQLGlot parser and the selected filename
dialect (ClickHouse, PostgreSQL, MySQL or Hive). Redis uses the upstream server.
The root `schema.sql` is validated separately by the metadata loader. Validation
cancels obsolete requests and skips large buffers.

Blink uses the SQL server's table and column suggestions directly. To complete
a qualified table, start typing its name immediately after `FROM` and accept
the full suggestion. Quote column names containing spaces when using them in SQL.

In a SQL buffer, press `<leader>kq` to run the buffer or its visual selection.
Dadbod displays the result in a split. The default Lumin adapter submits one
statement per request to ClickHouse Cloud through the authenticated `clickhousectl`
CLI. For dbt models, compile the model first and run its generated SQL.
The shell command `chq query.sql` uses the same adapter script. It also accepts
piped SQL. Running `chq` interactively opens a scratch file in the current schema-enabled checkout, or in the analysis repo.
Install the command with `install -m 755 ~/.config/nvim/scripts/chq ~/.local/bin/chq`.

## Keys

Leader is **Space**. Which-key shows groups as you type.

- Search: `ff` files in the current Oil directory (or current file's directory),
  `fF` files across the working directory, `fg` grep, `fb` buffers, `fh` help,
  `fr` resume, `fc` themes.
- Buffers/debug: `bd` close buffer, `bb` toggle breakpoint, `bB` conditional breakpoint;
  F5 continues/starts debugging, F1/F2/F3 step, F7 toggles the debugger UI.
- Editing: `w` save, `cf` format buffer, `y` yank to clipboard, `Y` copy file path,
  `p` paste from clipboard, `d`/`D` delete without yanking, `xc` change without yanking.
- Diagnostics: `q` current-buffer location list, `Q` diagnostic float, `xq` workspace quickfix list.
  `dd` removes an entry from whichever list is open. `gK` (without Leader) shows LSP hover; `K` moves to the window above.
- Git: `gs` status, `gl` log, `gc` commit, `gp` pull, `gP` push, `gF` fetch,
  `gb` blame, `gS` show the current buffer line's commit. In a Fugitive log,
  `gD` opens the commit under the cursor in Diffview. Enter keeps Fugitive's normal navigation. `hs`/`hr` stage/reset hunks.
- Press `Space r` in a Python file to **Run** it in an interactive terminal or
  **Debug** it with breakpoints. Both use the project interpreter and working
  directory. Standalone scripts run from their own directory.
- In C/C++ sources, headers, and CMake files, `Space r` offers **Build**, **Run**,
  and **Debug** for the CMake project. Choose a target when prompted.
- CMake: `cc` or `cg` configure, `cb` build, `cr` run, `cd` debug, `ct` build type,
  `cs` build target, `cl` launch target, `cT` tests. These use cmake-tools exclusively
  and set the tab cwd to the source root. Nested CMakeLists files share their
  parent build. A preset or an explicit project directory (`:tcd` or
  `:CMakeSelectCwd`) can select an independent build. Builds save modified
  files within that project. F5 remains general DAP.
- C/C++: `F` formats the Git project's `src/` and `tools/` files asynchronously.
- Markdown: `mp` preview, `mn` stop preview.
- `so` sources the current buffer. `-` opens Oil. `gf` opens a WYA issue under the
  cursor or uses normal go-to-file behaviour.

The previous `b`/`B`, `yp`, and `c` mappings moved to `bb`/`bB`, `Y`, and `xc` so
an operator/action no longer doubles as a longer mapping's prefix. Formatting
uses `cf` so `f` is exclusively the search prefix.


## PR review drafts

Review keys live under `<leader>gr`. Notes and queued comments are stored per
repository and PR, so changing cwd or reviewing the same number in another
repository cannot mix drafts. Submissions keep newly queued comments and resume
a pending review after a failed final submission.

Old numbered drafts are preserved. Open the correct PR and run `:PRImportDraft`
to explicitly assign one to that repository. Use `:PRReanchor <n>` on the intended
diff line (or selection) to update an imported/stale queued comment. Comments
from different revisions must be re-anchored to one revision before submission.
Commit views retain their exact revision for right-side comments; left-side
comments must be anchored in the full PR diff because its base is different.
Navigation servers are isolated per revision and stop when no longer in use.

## Performance and project behaviour

Builds, blame lookups and project formatting use asynchronous processes. Paths
are passed as arguments rather than interpolated into shell commands. Telescope,
formatting, debugging, CMake and language support load when needed.

LSP and formatting share project rules in `lua/config/projects.lua`. Package-local
Biome config selects Biome and suppresses ESLint; other JS/TS packages use Prettier
and their ESLint config. A workspace-root Biome config does not automatically claim
every package in a pnpm monorepo. TypeScript uses the package's installed SDK.

Linters debounce rapid events, skip unchanged buffers and never lint review/scratch
buffers. Go staticcheck runs at package scope on save; Lua Selene runs only where
there is a `selene.toml`. Files over 1 MiB or 20,000 lines skip automatic LSP,
Treesitter highlighting, linting and format-on-save. Thresholds live in
`lua/config/buffer.lua`. Explicit formatting remains available.

## Layout and tests

`lua/plugins/` contains plugin declarations and loading triggers. `lua/config/`
contains editor settings and focused modules for projects, LSP, lint, debugger,
build tasks and PR review. `work.lua` keeps the local Flutter PATH and Linear mapping.

Run `python3 tests/run.py` from this directory. Tests use temporary projects,
mock GitHub responses, and real local Neovim plugins and language-server processes.
See [tests/README.md](tests/README.md) for prerequisites and coverage.

## Branch scope

SQL and PR-review workflows belong only to `mac-work`. Start shared editor changes
from upstream `master`; do not open upstream PRs directly from `mac-work`. When
syncing upstream, preserve these branch-specific modules and their integration.
