# Personal Neovim config

This config targets Neovim 0.12 and uses lazy.nvim. Plugin versions remain pinned
in `lazy-lock.json`. Restart Neovim after changing the config; sourcing the whole
init file is not a supported plugin reload mechanism.

## Setup

Open `:Lazy` to install plugins. Use `:MasonToolsInstall` to install the configured
language servers, formatters, linters and Python/Go debug adapters. Run
`:TSInstallCommon` once to install the configured Treesitter parsers. Tool/parser updates and
installs are explicit so normal startup does not launch tool downloads.

C/C++ debugging additionally needs an LLVM `lldb-dap` executable. The config looks
on PATH and in common macOS LLVM locations. Missing LLDB does not prevent Python
or Go debugging. Python uses the active virtual environment, a project's `.venv`
or `venv`, then Python on PATH. Flutter's Dart is preferred when available.

## Keys

Leader is **Space**. Which-key shows groups as you type.

- Search: `ff` files in the current Oil directory (or current file's directory),
  `fF` files across the working directory, `fg` grep, `fb` buffers, `fh` help,
  `fr` resume, `fc` themes.
- Buffers/debug: `bd` close buffer, `bb` toggle breakpoint, `bB` conditional breakpoint;
  F5 continues/starts debugging, F1/F2/F3 step, F7 toggles the debugger UI.
- Editing: `w` save, `f` format buffer, `y` yank to clipboard, `Y` copy file path,
  `p` paste from clipboard, `d`/`D` delete without yanking, `xc` change without yanking.
- Diagnostics: `q` current-buffer location list, `Q` workspace quickfix list.
  `dd` removes an entry from whichever list is open.
- Git: `gs` status, `gl` log, `gc` commit, `gp` pull, `gP` push, `gF` fetch,
  `gb` blame, `gS` show the line's commit. `hs`/`hr` stage/reset hunks.
- Make: `mb` build, `mr` build/run, `md` build/debug. Executable choices are remembered
  per project. Failed commands put their output in quickfix.
- CMake: `cc` or `cg` configure, `cb` build, `cr` run, `cd` debug, `ct` build type,
  `cs` build target, `cl` launch target, `cT` tests. These use cmake-tools exclusively
  and set the current tab's cwd to the nearest CMake project. F5 remains general DAP.
- C/C++: `F` formats the Git project's `src/` and `tools/` files asynchronously.
- Markdown: `mp` preview, `mn` stop preview, `mz` zen mode, `me` pencil mode.
- `so` sources the current buffer. `-` opens Oil. `gf` opens a WYA issue under the
  cursor or uses normal go-to-file behaviour.

The previous `b`/`B`, `yp`, and `c` mappings moved to `bb`/`bB`, `Y`, and `xc` so
an operator/action no longer doubles as a longer mapping's prefix.


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
Treesitter, indent guides, linting and format-on-save. Thresholds live in
`lua/config/buffer.lua`. Explicit formatting remains available.

## Layout and tests

`lua/plugins/` contains plugin declarations and loading triggers. `lua/config/`
contains editor settings and focused modules for projects, LSP, lint, debugger,
build tasks and PR review. `work.lua` keeps the local Flutter PATH and Linear mapping.

Run `python3 tests/run.py` from this directory. Tests use temporary projects,
mock GitHub responses, and real local Neovim plugins and language-server processes.
See [tests/README.md](tests/README.md) for prerequisites and coverage.
