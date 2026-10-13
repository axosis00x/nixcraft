local function current_theme_name()
  local f = io.open(vim.fn.stdpath("config") .. "/theme_name.txt", "r")
  if not f then
    return nil
  end

  local name = f:read("*all"):gsub("%s+", "")
  f:close()

  return name ~= "" and name or nil
end

local ryo_theme = {
  normal = {
    a = { fg = "#000000", bg = "#bb9af7", gui = "bold" },
    b = { fg = "#eef5f7", bg = "#101018" },
    c = { fg = "#c9d1d9", bg = "#0a0a10" },
  },
  insert = {
    a = { fg = "#000000", bg = "#8ff0c7", gui = "bold" },
    b = { fg = "#eef5f7", bg = "#101018" },
    c = { fg = "#c9d1d9", bg = "#0a0a10" },
  },
  visual = {
    a = { fg = "#000000", bg = "#8bd5ff", gui = "bold" },
    b = { fg = "#eef5f7", bg = "#101018" },
    c = { fg = "#c9d1d9", bg = "#0a0a10" },
  },
  replace = {
    a = { fg = "#000000", bg = "#f7768e", gui = "bold" },
    b = { fg = "#eef5f7", bg = "#101018" },
    c = { fg = "#c9d1d9", bg = "#0a0a10" },
  },
  command = {
    a = { fg = "#000000", bg = "#f5c97f", gui = "bold" },
    b = { fg = "#eef5f7", bg = "#101018" },
    c = { fg = "#c9d1d9", bg = "#0a0a10" },
  },
  inactive = {
    a = { fg = "#566678", bg = "#0a0a10" },
    b = { fg = "#566678", bg = "#0a0a10" },
    c = { fg = "#566678", bg = "#0a0a10" },
  },
}

local gruvbox_theme = {
  normal = {
    a = { fg = "#1d2021", bg = "#83a598", gui = "bold" },
    b = { fg = "#ebdbb2", bg = "#3c3836" },
    c = { fg = "#d5c4a1", bg = "#1d2021" },
  },
  insert = {
    a = { fg = "#1d2021", bg = "#b8bb26", gui = "bold" },
    b = { fg = "#ebdbb2", bg = "#3c3836" },
    c = { fg = "#d5c4a1", bg = "#1d2021" },
  },
  visual = {
    a = { fg = "#1d2021", bg = "#d3869b", gui = "bold" },
    b = { fg = "#ebdbb2", bg = "#3c3836" },
    c = { fg = "#d5c4a1", bg = "#1d2021" },
  },
  replace = {
    a = { fg = "#1d2021", bg = "#fb4934", gui = "bold" },
    b = { fg = "#ebdbb2", bg = "#3c3836" },
    c = { fg = "#d5c4a1", bg = "#1d2021" },
  },
  command = {
    a = { fg = "#1d2021", bg = "#fabd2f", gui = "bold" },
    b = { fg = "#ebdbb2", bg = "#3c3836" },
    c = { fg = "#d5c4a1", bg = "#1d2021" },
  },
  inactive = {
    a = { fg = "#a89984", bg = "#1d2021" },
    b = { fg = "#a89984", bg = "#1d2021" },
    c = { fg = "#a89984", bg = "#1d2021" },
  },
}

-- Per-theme lualine color overrides, keyed by the exact name written to
-- theme_name.txt (see each theme's config/themes/<name>/neovim.lua). Themes
-- not listed here just use their colorscheme plugin's own lualine "auto"
-- theme.
local theme_overrides = {
  ryo = ryo_theme,
  gruvbox = gruvbox_theme,
}
-- Layout: [mode] file  branch ............ diagnostics  LSP ~ servers  [folder][line:col]
-- Blocks are slanted "/" where they meet each other, and square at the two
-- ends of the line so it sits flush with the window edges.
local function lsp_names()
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if client.name ~= "copilot" then
      table.insert(names, client.name)
    end
  end
  return #names > 0 and ("LSP ~ " .. table.concat(names, ", ")) or ""
end

return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.component_separators = ""
      opts.options.section_separators = { left = "", right = "" }
      opts.options.globalstatus = true
      local override = theme_overrides[current_theme_name()]
      if override then
        opts.options.theme = override
      end
      opts.sections = {
        lualine_a = {
          {
            "mode",
            icon = "",
            -- Square at the window edge, slanted where it meets the next block.
            separator = { left = "", right = "" },
            padding = { left = 1, right = 1 },
          },
        },
        lualine_b = {
          { "filetype", icon_only = true, padding = { left = 1, right = 0 } },
          {
            "filename",
            path = 0,
            symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]", newfile = "[New]" },
            padding = { left = 0, right = 1 },
          },
        },
        lualine_c = {
          { "branch", icon = "", padding = { left = 1, right = 1 } },
        },
        lualine_x = {
          -- Macro recording ("recording @q"), search count, etc. — driven by
          -- noice's status API.
          {
            function()
              return require("noice").api.status.command.get()
            end,
            cond = function()
              return package.loaded["noice"] and require("noice").api.status.command.has()
            end,
            color = function()
              return { fg = Snacks.util.color("Statement") }
            end,
            padding = { left = 0, right = 1 },
          },
          {
            function()
              return require("noice").api.status.mode.get()
            end,
            cond = function()
              return package.loaded["noice"] and require("noice").api.status.mode.has()
            end,
            color = function()
              return { fg = Snacks.util.color("Constant") }
            end,
            padding = { left = 0, right = 1 },
          },
          {
            "diagnostics",
            symbols = { error = "󰅚 ", warn = "󰀪 ", info = " ", hint = "󰌶 " },
            padding = { left = 0, right = 1 },
          },
          {
            lsp_names,
            icon = "",
            color = function()
              return { fg = Snacks.util.color("Function") }
            end,
            padding = { left = 1, right = 1 },
          },
        },
        lualine_y = {
          {
            function()
              return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
            end,
            icon = "󰉋",
            separator = { left = "", right = "" },
            padding = { left = 1, right = 1 },
          },
        },
        lualine_z = {
          {
            "location",
            icon = "",
            -- Slanted where it meets the folder block, square at the window edge.
            separator = { left = "", right = "" },
            padding = { left = 1, right = 1 },
          },
        },
      }
    end,
  },
}
