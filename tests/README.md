Run `python3 tests/run.py` from any checkout. The runner loads the checkout as its config,
reuses installed plugins and tools, and isolates its cache and editor state. Requires Neovim
0.12, the configured plugins, Mason's Lua language server, `make`, `cmake`, and a
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

The editor tests additionally cover asynchronous Make jobs and error output,
executable discovery in paths containing spaces, quickfix/location-list deletion,
formatter ownership in monorepos, large-file limits, lint debounce/save-only Go
checks, lazy plugin loading, independent debugger configuration, and LSP highlight
attachment/detachment. The full-config integration tests perform a real Lua
language-server definition lookup and a real CMake configure/build in a temporary
project (requires `make`, `cmake`, and a POSIX shell). Python/Go/LLDB debugger
configuration is checked, but full debug sessions are not launched by the suite.

Safety regressions additionally exercise repository-scoped drafts, submission
snapshots, duplicate-submit guards, pending-review retry, stale callback rejection,
explicit comment re-anchoring, failed note writes, paginated comments, Unicode LSP
positions, revision-isolated real language servers and cleanup. SQL checks cover
non-SQL completion bypass, mixed-case aliases, empty literal suggestions, shared
linear tokenization, filename dialects, large-file guards and validator cancellation.
