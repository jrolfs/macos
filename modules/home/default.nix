{ pkgs, lib, hostname, userName, config, inputs, ... }:

let
  dotfiles = ../../dotfiles/home;
  repoRoot = ../..;
in
{
  imports = lib.optional (builtins.pathExists ./hosts/${hostname}.nix) ./hosts/${hostname}.nix;

  home.username = userName;
  home.stateVersion = "24.05";

  home.sessionVariables = {
    NIX_CONFIG_DIR = "${config.home.homeDirectory}/.config/system";
    HOMESHICK_KINGDOM = "${config.home.homeDirectory}/.homesick/repos";
  };

  programs.home-manager.enable = true;

  # Top-level shell dotfiles. The .zshrc still has its
  # `source ~/.zshrc.<platform>` lookup; modules/home/darwin.nix provides
  # ~/.zshrc.darwin so that path resolves on macOS, nothing on linux.
  home.file = {
    ".zshenv".source = "${dotfiles}/.zshenv";
    ".zshrc".source = "${dotfiles}/.zshrc";
    ".zprofile".source = "${dotfiles}/.zprofile";
    ".zlogin".source = "${dotfiles}/.zlogin";
    ".zlogout".source = "${dotfiles}/.zlogout";
    ".agignore".source = "${dotfiles}/.agignore";
    ".editorconfig".source = "${dotfiles}/.editorconfig";

    # zinit comes from the flake input, not from the old
    # $HOMESHICK_KINGDOM/dot/zinit submodule path. The .zshrc was updated
    # to source $XDG_DATA_HOME/zinit/zinit.zsh accordingly.
    ".local/share/zinit".source = inputs.zinit;
  };

  # XDG config directories. Each lifts an entire subtree from
  # dotfiles/home/.config/ except where the app writes back to its dir
  # — those use mkOutOfStoreSymlink so the link target stays mutable.
  xdg.configFile = {
    "zsh".source = "${dotfiles}/.config/zsh";
    "git".source = "${dotfiles}/.config/git";
    "atuin".source = "${dotfiles}/.config/atuin";
    "bat".source = "${dotfiles}/.config/bat";
    "direnv".source = "${dotfiles}/.config/direnv";
    "kitty".source = "${dotfiles}/.config/kitty";
    "mise".source = "${dotfiles}/.config/mise";
    "k9s".source = "${dotfiles}/.config/k9s";
    "tridactyl".source = "${dotfiles}/.config/tridactyl";
    "worktrunk".source = "${dotfiles}/.config/worktrunk";
    "tabtab".source = "${dotfiles}/.config/tabtab";
    "starship".source = "${dotfiles}/.config/starship";
    "starship.toml".source = "${dotfiles}/.config/starship.toml";
    "spicetify".source = "${dotfiles}/.config/spicetify";
    "glide".source = "${dotfiles}/.config/glide";

    # zed writes back into its config dir (settings.json, keymap.json
    # change from the UI) — mkOutOfStoreSymlink points at the real
    # working copy so writes land in the repo where they can be committed.
    "zed".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/system/dotfiles/home/.config/zed";

    # nvim comes from the dedicated neovim flake input. recursive = true
    # makes each file an individual symlink so nvim can drop runtime
    # files (lazy-lock.json, shada, vim.pack state, …) alongside the
    # config without the whole dir being read-only.
    "nvim" = {
      source = "${inputs.neovim-config}/home/.config/nvim";
      recursive = true;
    };
  };
}
