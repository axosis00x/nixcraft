return {
  { "folke/tokyonight.nvim", lazy = false },
  {
    "bluz71/vim-moonfly-colors",
    name = "moonfly",
    lazy = false,
    init = function()
      -- Window separators as a thin line, not moonfly's default solid block.
      vim.g.moonflyWinSeparator = 2
    end,
  },
  { "zenbones-theme/zenbones.nvim", dependencies = "rktjmp/lush.nvim", lazy = false },
  { "ellisonleao/gruvbox.nvim", lazy = false },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = { transparent_background = false },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        return vim.g.lazyvim_colorscheme or "tokyonight"
      end,
    },
  },
}
