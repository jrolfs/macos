# Gruvbox Material, the one palette every themed thing on every machine reads:
# Hyprland, the bar, the launcher, the game menu, and in time the Macs too.
#
# Plain data rather than a module so any of nix-darwin, NixOS or home-manager
# can `import` it. Values are from gruvbox-material's own palette
# (autoload/gruvbox_material.vim): the dark "soft" background set with the
# "material" foreground set, which is what Neovim and kitty already use.
#
# A light variant would be a sibling attribute with the same names, so
# switching is choosing which attribute a host reads.

{
  dark.soft = {
    # Backgrounds, darkest to lightest. bg0 is the main surface; bg_dim sits
    # behind it (a window's backdrop, the bar's base before translucency).
    bg_dim = "#252423";
    bg0 = "#32302f";
    bg1 = "#3c3836";
    bg2 = "#3c3836";
    bg3 = "#504945";
    bg4 = "#504945";
    bg5 = "#665c54";

    # Tinted backgrounds for selections and highlighted rows.
    bg_visual_red = "#543937";
    bg_visual_yellow = "#574833";
    bg_visual_green = "#424a3e";
    bg_visual_blue = "#404946";
    bg_visual_purple = "#4b3e45";
    bg_current_word = "#45403d";

    fg0 = "#d4be98";
    fg1 = "#ddc7a1";

    grey0 = "#7c6f64";
    grey1 = "#928374";
    grey2 = "#a89984";

    red = "#ea6962";
    orange = "#e78a4e";
    yellow = "#d8a657";
    green = "#a9b665";
    aqua = "#89b482";
    blue = "#7daea3";
    purple = "#d3869b";
  };
}
