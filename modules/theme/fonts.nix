# Typefaces, beside palette.nix and read the same way: anything themed takes
# its font family names from here rather than spelling them out, so changing a
# face is one edit. Plain data, importable from any module system; each entry
# carries the nixpkgs attribute name so modules can install what they name.

{
  # Interface text: bars, launchers, menus, the game shelf.
  sans = {
    family = "Geist";
    package = "geist-font";
  };

  # Code and terminals. Matches kitty and Zed on the Macs.
  mono = {
    family = "JetBrains Mono";
    package = "jetbrains-mono";
  };

  # The same face patched with Nerd Font glyphs, for places that render icons
  # inline with monospaced text.
  monoNerd = {
    family = "JetBrainsMono Nerd Font";
    package = "nerd-fonts.jetbrains-mono";
  };
}
