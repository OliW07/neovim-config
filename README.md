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
- `-` opens Oil. `gf` opens a WYA issue under the
  cursor or uses normal go-to-file behaviour.

The previous `b`/`B`, `yp`, and `c` mappings moved to `bb`/`bB`, `Y`, and `xc` so
an operator/action no longer doubles as a longer mapping's prefix. Formatting
uses `cf` so `f` is exclusively the search prefix.

## Performance and project behaviour

Builds, blame lookups and project formatting use asynchronous processes. Paths
are passed as arguments rather than interpolated into shell commands. Telescope,
formatting, debugging, CMake and language support load when needed.

LSP and formatting share project rules in `lua/config/projects.lua`. Package-local
Biome config selects Biome and suppresses ESLint; other JS/TS packages use Prettier
and their ESLint config. A workspace-root Biome config does not automatically claim
every package in a pnpm monorepo. TypeScript uses the package's installed SDK.

Linters debounce rapid events, skip unchanged buffers and never lint scratch
buffers. Go staticcheck runs at package scope on save; Lua Selene runs only where
there is a `selene.toml`. Files over 1 MiB or 20,000 lines skip automatic LSP,
Treesitter highlighting, linting and format-on-save. Thresholds live in
`lua/config/buffer.lua`. Explicit formatting remains available.

## Layout and tests

`lua/plugins/` contains plugin declarations and loading triggers. `lua/config/`
contains editor settings and focused modules for projects, LSP, lint, debugger,
and build tasks. `work.lua` keeps the local Flutter PATH and Linear mapping.

Run `python3 tests/run.py` from this directory. Tests use temporary projects,
local Git repositories, and real Neovim plugins and language-server processes.
See [tests/README.md](tests/README.md) for prerequisites and coverage.

## Branch scope

SQL and PR-review workflows belong only to `mac-work`. Start shared editor changes
from upstream `master`; do not open upstream PRs directly from `mac-work`.
