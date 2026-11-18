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

# Neovim loads its config from stdpath, regardless of the test process cwd.
# Reuse installed plugins/tools, but give each run its own editor state.
with tempfile.TemporaryDirectory(prefix='nvim-config-test-') as folder:
    profile = Path(folder)
    (profile / 'config' / 'nvim').parent.mkdir()
    (profile / 'config' / 'nvim').symlink_to(config, target_is_directory=True)
    os.environ.update(NVIM_APPNAME='nvim', XDG_CONFIG_HOME=str(profile / 'config'),
                      XDG_CACHE_HOME=str(profile / 'cache'), XDG_STATE_HOME=str(profile / 'state'))
    for test in ['projects.lua', 'lint.lua', 'editor_tasks.lua']:
        print(run(['nvim', '--headless', '-u', 'NONE', '-i', 'NONE', '-l', 'tests/' + test]).strip())
    for test in ['config_smoke.lua', 'lsp_integration.lua', 'cmake_integration.lua', 'python_integration.lua', 'git_integration.lua', 'git_history.lua']:
        command = f'lua local ok,err=pcall(dofile,"tests/{test}"); if not ok then print(err); vim.cmd("cquit 1") end'
        print(run(['nvim', '--headless', '-i', 'NONE', '-c', command]).strip())
