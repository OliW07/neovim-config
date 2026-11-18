"""Offline regression tests; requires the config's installed Neovim plugins."""
from pathlib import Path
import os
import subprocess
import tempfile

config = Path(__file__).resolve().parents[1]

def run(args, cwd=config, env=None):
    result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True, timeout=30)
    if result.returncode or 'Error in command line' in result.stderr:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout + result.stderr

for test in ['sql_diagnostics.lua', 'sql_safety.lua', 'projects.lua', 'lint.lua', 'editor_tasks.lua', 'review_data.lua', 'review_safety.lua', 'review_lsp.lua', 'review_lsp_navigation.lua']:
    print(run(['nvim', '--headless', '-u', 'NONE', '-i', 'NONE', '-l', 'tests/' + test]).strip())
for test in ['config_smoke.lua', 'lsp_integration.lua', 'cmake_integration.lua', 'sql_integration.lua', 'sql_words.lua', 'sql_values.lua', 'sql_scope.lua', 'sql_words_blink.lua', 'sql_cte_blink.lua', 'sql_signature_blink.lua']:
    command = f'lua local ok,err=pcall(dofile,"tests/{test}"); if not ok then print(err); vim.cmd("cquit 1") end'
    print(run(['nvim', '--headless', '-i', 'NONE', '-c', command]).strip())
with tempfile.TemporaryDirectory(prefix='nvim-review-test-') as folder:
    base = Path(folder)
    source, checkout = base / 'source', base / 'checkout'
    source.mkdir()
    def git(*args):
        return run(['git', *args], source)
    git('init', '-b', 'production')
    git('config', 'user.name', 'Review Test')
    git('config', 'user.email', 'review-test@example.invalid')
    (source / 'sample.txt').write_text('base\n')
    git('add', '.')
    git('-c', 'commit.gpgsign=false', 'commit', '-m', 'base')
    git('update-ref', 'refs/pull/2/head', 'HEAD')
    (source / 'sample.txt').write_text('base\nfeature\n')
    git('-c', 'commit.gpgsign=false', 'commit', '-am', 'feature')
    git('update-ref', 'refs/pull/1/head', 'HEAD')
    git('reset', '--hard', 'HEAD~1')
    run(['git', 'clone', str(source), str(checkout)])
    result_file = base / 'result.txt'
    env = dict(os.environ, REVIEW_TEST_RESULT=str(result_file))
    try:
        run(['nvim', '--headless', '-i', 'NONE', 'sample.txt', '-c',
             f'lua dofile("{config}/tests/review_integration.lua")'], checkout, env)
    finally:
        if result_file.exists():
            print(result_file.read_text().strip())
