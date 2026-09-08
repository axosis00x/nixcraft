return {
  "mrcjkb/rustaceanvim",
  lazy = false,
  require("lspconfig").qmlls.setup({}),
  require("lspconfig").gopls.setup({}),
  require("lspconfig").vtsls.setup({}),
  require("lspconfig").clangd.setup({}),
}
