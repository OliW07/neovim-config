"""Offline regression tests; requires the config's installed Neovim plugins."""
from pathlib import Path
import subprocess

config = Path(__file__).resolve().parents[1]

def run(args, cwd=config, env=None):
    result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True, timeout=30)
    if result.returncode or 'Error in command line' in result.stderr:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout + result.stderr

for test in ['projects.lua', 'lint.lua', 'editor_tasks.lua']:
    print(run(['nvim', '--headless', '-u', 'NONE', '-i', 'NONE', '-l', 'tests/' + test]).strip())
for test in ['config_smoke.lua', 'lsp_integration.lua', 'cmake_integration.lua', 'git_integration.lua']:
    command = f'lua local ok,err=pcall(dofile,"tests/{test}"); if not ok then print(err); vim.cmd("cquit 1") end'
    print(run(['nvim', '--headless', '-i', 'NONE', '-c', command]).strip())
