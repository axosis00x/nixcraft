-- Transparent: dim, frosted "liquid glass".
--
-- Blur behind the shell's own layers (bar, panels, dock, OSD) so their
-- translucent surfaces read as frosted glass. Declared here rather than in
-- the shared config so it only applies while this theme is active; pixels
-- fainter than ignore_alpha (empty overlay space, the modal dim) stay
-- unblurred.
hl.layer_rule({
    name = "transparent-glass",
    match = { namespace = "quickshell.*" },
    blur = true,
    ignore_alpha = 0.35,
})

return {
    outline = { colors = { "rgba(ffffff66)", "rgba(9ecbff55)" }, angle = 45 },
    outline_variant = "rgba(ffffff22)",
    primary = "rgb(9ecbff)",
    tertiary = "rgb(c9b8ff)",
}
