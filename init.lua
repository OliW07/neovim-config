-- Use user config when running with sudo
if vim.env.SUDO_USER then
  local home = vim.fn.expand('~' .. vim.env.SUDO_USER)
  if home ~= '' and home ~= ('~' .. vim.env.SUDO_USER) then
    vim.env.XDG_CONFIG_HOME = home .. '/.config'
    vim.env.XDG_DATA_HOME = home .. '/.local/share'
    vim.env.XDG_STATE_HOME = home .. '/.local/state'
    vim.env.XDG_CACHE_HOME = home .. '/.cache'
  end
end

-- Prefer rustup-managed toolchains (cargo, rustfmt, rust-analyzer, ...) over
-- distro-packaged binaries so tools respect the project's rust-toolchain.toml.
local cargo_bin = os.getenv 'HOME' .. '/.cargo/bin'
if vim.fn.isdirectory(cargo_bin) == 1 then
  vim.env.PATH = cargo_bin .. ':' .. vim.env.PATH
end

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'config.work'

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  require 'plugins.lsp',
  require 'plugins.ui',
  require 'plugins.tools',
  require 'plugins.editor',
  require 'plugins.work',
}, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

if vim.fn.executable 'win32yank.exe' == 1 then
  vim.g.clipboard = {
    name = 'win32yank-wsl',
    copy = {
      ['+'] = 'win32yank.exe -i --crlf',
      ['*'] = 'win32yank.exe -i --crlf',
    },
    paste = {
      ['+'] = 'win32yank.exe -o --lf',
      ['*'] = 'win32yank.exe -o --lf',
    },
    cache_enabled = 0,
  }
end
