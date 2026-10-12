# shellcheck shell=bash
# Sourced into the catppuccin tmux plugin (modules/user/shell/tmux.nix).
#
# The plugin only knows its four built-in flavours, so a nixcraft theme
# would get a broken status bar. This builds its palette from the active
# theme's own colors instead (the @thm_* options its tmux.conf sets, see
# config/themes/<name>/tmux.conf), one accent per theme like the rest of the
# desktop. With no theme colors set it falls back to a built-in flavour.
nixcraft_palette() {
    local bg
    bg="$(get_tmux_option "@thm_bar_bg" "")"
    [ -n "$bg" ] || bg="$(get_tmux_option "@thm_bg" "")"
    if [ -z "$bg" ]; then
        local file="${PLUGIN_DIR}/catppuccin-$1.tmuxtheme"
        [ -f "$file" ] || file="${PLUGIN_DIR}/catppuccin-mocha.tmuxtheme"
        cat "$file"
        return
    fi

    local fg accent muted surface low outline alert
    fg="$(get_tmux_option "@thm_fg" "#cdd6f4")"
    accent="$(get_tmux_option "@thm_primary" "$fg")"
    muted="$(get_tmux_option "@thm_text_variant" "$fg")"
    surface="$(get_tmux_option "@thm_surface_variant" "$bg")"
    low="$(get_tmux_option "@thm_surface_low" "$bg")"
    outline="$(get_tmux_option "@thm_outline" "$muted")"
    # The session pill while the prefix key is held.
    alert="$(get_tmux_option "@thm_alert" "$fg")"

    # Lowercase: the plugin can't take capital letters in hex colors.
    printf 'thm_%s="%s"\n' \
        bg "${bg,,}" \
        fg "${fg,,}" \
        gray "${surface,,}" \
        black "${low,,}" \
        black4 "${outline,,}" \
        blue "${muted,,}" \
        orange "${accent,,}" \
        pink "${accent,,}" \
        green "${accent,,}" \
        cyan "${accent,,}" \
        magenta "${accent,,}" \
        yellow "${accent,,}" \
        red "${alert,,}"
}
