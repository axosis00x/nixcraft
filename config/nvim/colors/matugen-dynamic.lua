-- matugen-dynamic: generated from the active dynamic wallpaper by matugen.
-- Palette shared with kitty/tmux/yazi/hyprland's dynamic theme.

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end
vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.colors_name = "matugen-dynamic"

local p = {
  bg = "#0c160e",
  bg_float = "#18221a",
  bg_highlight = "#222c24",
  bg_visual = "#2d372e",
  bg_search = "#2d372e",
  border = "#3f4940",

  fg = "#dae6d9",
  fg_dark = "#becabd",
  fg_dim = "#899488",
  comment = "#899488",
  disabled = "#3f4940",

  blue = "#00e47c",
  blue2 = "#5eff9c",
  cyan = "#a4d0bc",
  teal = "#c0ecd7",
  green = "#005048",
  purple = "#8dd4c7",
  magenta = "#a9f0e3",
  red = "#ffb4ab",
  orange = "#005229",
  yellow = "#264e3f",

  none = "NONE",
}

local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor UI
hl("Normal", { fg = p.fg, bg = p.bg })
hl("NormalNC", { fg = p.fg, bg = p.bg })
hl("NormalFloat", { fg = p.fg, bg = p.bg_float })
hl("FloatBorder", { fg = p.border, bg = p.bg_float })
hl("FloatTitle", { fg = p.blue, bg = p.bg_float })
hl("Cursor", { fg = p.bg, bg = p.blue })
hl("CursorLine", { bg = p.bg_highlight })
hl("CursorLineNr", { fg = p.blue, bold = true })
hl("LineNr", { fg = p.disabled })
hl("SignColumn", { bg = p.bg })
hl("FoldColumn", { fg = p.comment, bg = p.bg })
hl("Folded", { fg = p.fg_dim, bg = p.bg_highlight })
hl("ColorColumn", { bg = p.bg_highlight })
hl("Visual", { bg = p.bg_visual })
hl("VisualNOS", { bg = p.bg_visual })
hl("Search", { fg = p.bg, bg = p.yellow })
hl("IncSearch", { fg = p.bg, bg = p.orange })
hl("CurSearch", { fg = p.bg, bg = p.orange })
hl("Substitute", { fg = p.bg, bg = p.red })
hl("MatchParen", { fg = p.blue, bold = true })
hl("EndOfBuffer", { fg = p.bg })
hl("NonText", { fg = p.disabled })
hl("Whitespace", { fg = p.disabled })
hl("SpecialKey", { fg = p.disabled })
hl("Directory", { fg = p.blue })
hl("Title", { fg = p.blue, bold = true })
hl("ErrorMsg", { fg = p.red, bold = true })
hl("WarningMsg", { fg = p.orange, bold = true })
hl("MoreMsg", { fg = p.green })
hl("ModeMsg", { fg = p.fg_dim })
hl("Question", { fg = p.blue })
hl("Pmenu", { fg = p.fg, bg = p.bg_float })
hl("PmenuSel", { fg = p.bg, bg = p.blue })
hl("PmenuSbar", { bg = p.bg_highlight })
hl("PmenuThumb", { bg = p.border })
hl("WildMenu", { fg = p.bg, bg = p.blue })
hl("StatusLine", { fg = p.fg_dim, bg = p.bg_highlight })
hl("StatusLineNC", { fg = p.comment, bg = p.bg_float })
hl("TabLine", { fg = p.fg_dim, bg = p.bg_float })
hl("TabLineFill", { bg = p.bg })
hl("TabLineSel", { fg = p.bg, bg = p.blue })
hl("WinSeparator", { fg = p.border })
hl("VertSplit", { fg = p.border })
hl("SpellBad", { sp = p.red, undercurl = true })
hl("SpellCap", { sp = p.orange, undercurl = true })
hl("SpellRare", { sp = p.purple, undercurl = true })
hl("SpellLocal", { sp = p.cyan, undercurl = true })
hl("QuickFixLine", { bg = p.bg_highlight })
hl("Conceal", { fg = p.comment })

-- Syntax
hl("Comment", { fg = p.comment, italic = true })
hl("Constant", { fg = p.orange })
hl("String", { fg = p.green })
hl("Character", { fg = p.green })
hl("Number", { fg = p.orange })
hl("Boolean", { fg = p.orange })
hl("Float", { fg = p.orange })
hl("Identifier", { fg = p.fg })
hl("Function", { fg = p.blue })
hl("Statement", { fg = p.purple })
hl("Conditional", { fg = p.purple })
hl("Repeat", { fg = p.purple })
hl("Label", { fg = p.purple })
hl("Operator", { fg = p.cyan })
hl("Keyword", { fg = p.purple })
hl("Exception", { fg = p.purple })
hl("PreProc", { fg = p.cyan })
hl("Include", { fg = p.cyan })
hl("Define", { fg = p.cyan })
hl("Macro", { fg = p.cyan })
hl("PreCondit", { fg = p.cyan })
hl("Type", { fg = p.teal })
hl("StorageClass", { fg = p.teal })
hl("Structure", { fg = p.teal })
hl("Typedef", { fg = p.teal })
hl("Special", { fg = p.blue2 })
hl("SpecialChar", { fg = p.blue2 })
hl("Tag", { fg = p.blue2 })
hl("Delimiter", { fg = p.fg_dim })
hl("SpecialComment", { fg = p.comment, italic = true })
hl("Debug", { fg = p.red })
hl("Underlined", { underline = true })
hl("Ignore", { fg = p.disabled })
hl("Error", { fg = p.red })
hl("Todo", { fg = p.bg, bg = p.yellow, bold = true })

-- Diff
hl("DiffAdd", { fg = p.green, bg = p.none })
hl("DiffChange", { fg = p.orange, bg = p.none })
hl("DiffDelete", { fg = p.red, bg = p.none })
hl("DiffText", { fg = p.blue, bg = p.none })

-- Diagnostics
hl("DiagnosticError", { fg = p.red })
hl("DiagnosticWarn", { fg = p.orange })
hl("DiagnosticInfo", { fg = p.blue })
hl("DiagnosticHint", { fg = p.teal })
hl("DiagnosticOk", { fg = p.green })
hl("DiagnosticUnderlineError", { sp = p.red, underline = true })
hl("DiagnosticUnderlineWarn", { sp = p.orange, underline = true })
hl("DiagnosticUnderlineInfo", { sp = p.blue, underline = true })
hl("DiagnosticUnderlineHint", { sp = p.teal, underline = true })
hl("DiagnosticVirtualTextError", { fg = p.red })
hl("DiagnosticVirtualTextWarn", { fg = p.orange })
hl("DiagnosticVirtualTextInfo", { fg = p.blue })
hl("DiagnosticVirtualTextHint", { fg = p.teal })

-- LSP
hl("LspReferenceText", { bg = p.bg_highlight })
hl("LspReferenceRead", { bg = p.bg_highlight })
hl("LspReferenceWrite", { bg = p.bg_highlight })
hl("LspSignatureActiveParameter", { fg = p.blue, bold = true })
hl("LspInlayHint", { fg = p.disabled, bg = p.bg_float })

-- Treesitter
hl("@variable", { fg = p.fg })
hl("@variable.builtin", { fg = p.red })
hl("@variable.parameter", { fg = p.fg_dark })
hl("@variable.member", { fg = p.blue2 })
hl("@constant", { fg = p.orange })
hl("@constant.builtin", { fg = p.orange })
hl("@module", { fg = p.blue2 })
hl("@string", { link = "String" })
hl("@string.escape", { fg = p.blue2 })
hl("@character", { link = "Character" })
hl("@number", { link = "Number" })
hl("@boolean", { link = "Boolean" })
hl("@function", { link = "Function" })
hl("@function.builtin", { fg = p.blue })
hl("@function.macro", { fg = p.cyan })
hl("@method", { link = "Function" })
hl("@constructor", { fg = p.teal })
hl("@keyword", { link = "Keyword" })
hl("@keyword.function", { fg = p.purple })
hl("@keyword.return", { fg = p.purple })
hl("@keyword.operator", { fg = p.purple })
hl("@conditional", { link = "Conditional" })
hl("@repeat", { link = "Repeat" })
hl("@type", { link = "Type" })
hl("@type.builtin", { fg = p.teal })
hl("@attribute", { fg = p.cyan })
hl("@property", { fg = p.blue2 })
hl("@punctuation.delimiter", { fg = p.fg_dim })
hl("@punctuation.bracket", { fg = p.fg_dim })
hl("@punctuation.special", { fg = p.blue2 })
hl("@comment", { link = "Comment" })
hl("@tag", { link = "Tag" })
hl("@tag.attribute", { fg = p.teal })
hl("@tag.delimiter", { fg = p.fg_dim })
hl("@markup.heading", { fg = p.blue, bold = true })
hl("@markup.strong", { bold = true })
hl("@markup.italic", { italic = true })
hl("@markup.link", { fg = p.blue2, underline = true })
hl("@markup.link.url", { fg = p.cyan, underline = true })
hl("@markup.raw", { fg = p.green })
hl("@markup.list", { fg = p.purple })
hl("@diff.plus", { link = "DiffAdd" })
hl("@diff.minus", { link = "DiffDelete" })
hl("@diff.delta", { link = "DiffChange" })

-- GitSigns
hl("GitSignsAdd", { fg = p.green })
hl("GitSignsChange", { fg = p.orange })
hl("GitSignsDelete", { fg = p.red })

-- Telescope
hl("TelescopeNormal", { fg = p.fg, bg = p.bg_float })
hl("TelescopeBorder", { fg = p.border, bg = p.bg_float })
hl("TelescopePromptNormal", { fg = p.fg, bg = p.bg_highlight })
hl("TelescopePromptBorder", { fg = p.border, bg = p.bg_highlight })
hl("TelescopePromptPrefix", { fg = p.blue })
hl("TelescopeSelection", { bg = p.bg_visual })
hl("TelescopeMatching", { fg = p.blue, bold = true })

-- NeoTree / Snacks explorer
hl("NeoTreeNormal", { fg = p.fg, bg = p.bg })
hl("NeoTreeNormalNC", { fg = p.fg, bg = p.bg })
hl("NeoTreeDirectoryIcon", { fg = p.blue })
hl("NeoTreeDirectoryName", { fg = p.blue })
hl("NeoTreeRootName", { fg = p.blue, bold = true })
hl("NeoTreeGitAdded", { fg = p.green })
hl("NeoTreeGitModified", { fg = p.orange })
hl("NeoTreeGitDeleted", { fg = p.red })
hl("SnacksIndent", { fg = p.disabled })
hl("SnacksPicker", { fg = p.fg, bg = p.bg })
hl("SnacksPickerBorder", { fg = p.border, bg = p.bg })
hl("SnacksNotifierInfo", { fg = p.blue })
hl("SnacksNotifierWarn", { fg = p.orange })
hl("SnacksNotifierError", { fg = p.red })

-- WhichKey
hl("WhichKeyNormal", { fg = p.fg, bg = p.bg_float })
hl("WhichKeyBorder", { fg = p.border, bg = p.bg_float })
hl("WhichKey", { fg = p.blue })
hl("WhichKeyGroup", { fg = p.purple })
hl("WhichKeyDesc", { fg = p.fg })
hl("WhichKeySeparator", { fg = p.comment })

-- Blink/nvim-cmp completion menu
hl("BlinkCmpMenu", { fg = p.fg, bg = p.bg_float })
hl("BlinkCmpMenuBorder", { fg = p.border, bg = p.bg_float })
hl("BlinkCmpMenuSelection", { bg = p.bg_visual })
hl("BlinkCmpDoc", { fg = p.fg, bg = p.bg_float })
hl("BlinkCmpDocBorder", { fg = p.border, bg = p.bg_float })
hl("CmpItemAbbrMatch", { fg = p.blue, bold = true })
hl("CmpItemKindFunction", { fg = p.blue })
hl("CmpItemKindVariable", { fg = p.fg })
hl("CmpItemKindKeyword", { fg = p.purple })

-- Noice
hl("NoiceCmdlinePopup", { fg = p.fg, bg = p.bg_float })
hl("NoiceCmdlinePopupBorder", { fg = p.border, bg = p.bg_float })

-- Terminal colors
vim.g.terminal_color_0 = "#071009"
vim.g.terminal_color_1 = "#ffb4ab"
vim.g.terminal_color_2 = "#005048"
vim.g.terminal_color_3 = "#264e3f"
vim.g.terminal_color_4 = "#00e47c"
vim.g.terminal_color_5 = "#8dd4c7"
vim.g.terminal_color_6 = "#a4d0bc"
vim.g.terminal_color_7 = "#dae6d9"
vim.g.terminal_color_8 = "#899488"
vim.g.terminal_color_9 = "#ffdad6"
vim.g.terminal_color_10 = "#a9f0e3"
vim.g.terminal_color_11 = "#c0ecd7"
vim.g.terminal_color_12 = "#5eff9c"
vim.g.terminal_color_13 = "#005229"
vim.g.terminal_color_14 = "#93000a"
vim.g.terminal_color_15 = "#dae6d9"
