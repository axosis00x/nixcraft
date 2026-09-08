return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    require("toggleterm").setup({
      size = 4,
      open_mapping = [[<c-\>]], -- Ctrl+\ to toggle
      direction = "horizontal", -- bottom split
      shade_terminals = true,
    })
  end,
}
