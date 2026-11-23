Run `python3 tests/run.py` from any checkout. The runner loads the checkout as its config,
reuses installed plugins and tools, and isolates its cache and editor state. Requires Neovim
0.12, the configured plugins, Mason's Lua language server, Python 3, a C compiler, `make`, `cmake`, and a
POSIX shell. Tests use temporary projects and local processes.
The PR integration uses a temporary Git remote and checkout with stubbed GitHub responses.

Coverage: persistent repository-scoped list and summary caching, expiry, empty
results, fetched-ref reuse, missing refs, stale advertised SHAs, in-flight sharing, cancellation,
picker-to-open handoff, explicit refresh, error recovery, actual Diffview opening
with changed and empty PRs, file navigation after the overview, and overlapping
open requests. The 1.9-second assertion catches the former fixed two-second wait;
printed timings use local Git and mocked GitHub, not real-network benchmarks.

LSP coverage also checks package-root callbacks, linked-worktree paths, excluded
lint servers, duplicate attachment, deferred visible-buffer attachment, and `gd`
against the real Mason-installed Lua language server. Install that server before
running the suite. No fixture language server accesses GitHub.

SQL integration requires `python3 scripts/install-sql-lsp.py` first. It checks the
real offline SQL server for table/column completion, quoted ClickHouse fields,
schema reload after save, and isolation between repositories. It does not query
ClickHouse or execute the schema's SQL.

The real Telescope picker is also exercised through immediate description
preview, early-close cancellation, background Git prefetch, and selection without
a duplicate fetch. Long-description checks cover wrapping, preview paging,
start/end controls, and quiet successful navigation. Unit tests verify bounded prefetch concurrency, latest-row
queue replacement, foreground adoption, and recovery after background errors. A
late direct-number metadata response cannot replace a newer review selection.

The editor tests cover asynchronous tasks, quickfix and location lists, formatter
ownership in monorepos, large-file limits, linting and LSP attachment. They run
an interactive Python script in its project virtualenv, build and run a CMake
executable and check Python and LLDB debugger configuration.

Safety regressions additionally exercise repository-scoped drafts, submission
snapshots, duplicate-submit guards, pending-review retry, stale callback rejection,
explicit comment re-anchoring, failed note writes, paginated comments, Unicode LSP
positions, revision-isolated real language servers and cleanup. SQL checks cover the Blink menu, filename dialects, large-file guards and validator cancellation.
