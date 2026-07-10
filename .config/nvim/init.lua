-- plugin management (native vim.pack, requires Neovim 0.12+)
vim.pack.add({
  'https://github.com/nvim-tree/nvim-tree.lua',
  'https://github.com/nvim-tree/nvim-web-devicons',
  { src = 'https://github.com/nvim-telescope/telescope.nvim', version = '0.1.5' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/windwp/nvim-autopairs',
  'https://github.com/numToStr/Comment.nvim',
  'https://github.com/vague2k/vague.nvim',
})

vim.cmd("colorscheme vague")
-- basic settings
vim.opt.termguicolors = true
vim.opt.backupcopy = "yes"
-- line numbers
vim.o.number = true
vim.o.relativenumber = true

-- indentation
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.smartindent = true

-- search
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.hlsearch = true
vim.o.incsearch = true

-- editor behavior
vim.o.wrap = false
vim.o.swapfile = false
vim.o.backup = false
vim.o.scrolloff = 8
vim.o.signcolumn = "yes"
vim.o.updatetime = 50

-- split behavior
vim.o.splitright = true
vim.o.splitbelow = true

-- mouse support
vim.o.mouse = 'a'

-- keymaps
vim.g.mapleader = " "

-- config management
vim.keymap.set('n', '<leader>o', ':update<CR> :source %<CR>', { desc = "save and source config" })
vim.keymap.set('n', '<leader>pu', ':lua vim.pack.update()<CR>', { desc = "update plugins" })

-- file operations
vim.keymap.set('n', '<leader>w', ':write<CR>', { desc = "save file" })
vim.keymap.set('n', '<leader>q', ':quit<CR>', { desc = "quit" })
vim.keymap.set('n', '<leader>Q', ':qall<CR>', { desc = "quit all" })

-- clipboard
vim.keymap.set({'n', 'v', 'x'}, '<leader>y', '"+y', { desc = "copy to clipboard" })
vim.keymap.set({'n', 'v', 'x'}, '<leader>p', '"+p', { desc = "paste from clipboard" })

-- clear search highlighting
vim.keymap.set('n', '<leader>h', ':nohlsearch<CR>', { desc = "clear search highlight" })

-- better window navigation
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = "window left" })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = "window down" })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = "window up" })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = "window right" })

-- move lines up/down in visual mode
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = "move line down" })
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = "move line up" })

-- keep cursor centered when scrolling
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = "scroll down centered" })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = "scroll up centered" })

-- file explorer
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { desc = "toggle file explorer" })

-- plugin configurations

-- autopairs
require('nvim-autopairs').setup({
  check_ts = false,  -- don't check treesitter
})

-- comments
require('Comment').setup()

-- file explorer
require('nvim-tree').setup({
  view = {
    width = 30,
  },
  renderer = {
    icons = {
      show = {
        file = true,
        folder = true,
        folder_arrow = true,
        git = true,
      },
    },
  },
})

-- telescope (fuzzy finder) - if installed
local telescope_ok, telescope = pcall(require, 'telescope')
if telescope_ok then
  telescope.setup()
  vim.keymap.set('n', '<leader>ff', '<cmd>Telescope find_files<cr>', { desc = "find files" })
  vim.keymap.set('n', '<leader>fg', '<cmd>Telescope live_grep<cr>', { desc = "live grep" })
  vim.keymap.set('n', '<leader>fb', '<cmd>Telescope buffers<cr>', { desc = "find buffers" })
end

-- auto commands

-- highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- remove trailing whitespace on save
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*',
  callback = function()
    local save_cursor = vim.fn.getpos('.')
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos('.', save_cursor)
  end,
})

-- notes
-- after editing this file:
-- 1. new plugins listed in vim.pack.add() install automatically on next launch/source
-- 2. restart nvim or press <space>o to reload
-- 3. press <space>pu (or run :lua vim.pack.update()) to update installed plugins
-- 4. to remove a plugin: delete it from vim.pack.add() above, then run
--    :lua vim.pack.del({'plugin-name'}) to clean it off disk
