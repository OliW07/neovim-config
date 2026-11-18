Run `python3 tests/run.py` from the installed config repository. Requires Neovim
0.12, the configured plugins, Mason's Lua language server, `make`, `cmake`, and a
POSIX shell. Tests use temporary projects and local processes.

Coverage includes formatter ownership in nested projects and monorepos, lint
debouncing, large-file limits, asynchronous Make jobs and errors, paths containing
spaces, quickfix/location-list editing, lazy plugin loading, debugger configuration,
search/format key prefixes, and LSP highlight lifecycle. Integration tests perform
a real Lua definition lookup, CMake configure/build, and local Git Diffview opening
and cleanup. Full debugger sessions are not launched by this suite.

The upstream smoke test also checks that machine-specific SQL and PR-review
workflows are absent. Those workflows and their tests live only on `mac-work`.
