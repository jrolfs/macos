{ pkgs, lib, hostname, userName, config, inputs, ... }:

let
  dotfiles = ../../dotfiles/home;
  repoRoot = ../..;

  # The working tree as it exists on the machine, as opposed to the store copy
  # of it that `dotfiles` refers to.
  live = "${config.home.homeDirectory}/.config/system/dotfiles/home";

  # Per-file out-of-store symlinks mirroring the structure of a directory under
  # dotfiles/home/.config. Two properties a single directory symlink can't
  # have at once: edits land in the next shell rather than the next switch, and
  # the directory stays a real one, so the private castle's files (zsh/keys.zsh,
  # zsh/init/keys.zsh) can sit alongside the managed ones.
  #
  # Adding a *new* file still needs a switch, since the tree is walked at
  # evaluation time — only the contents of existing files are live.
  liveConfig = name:
    let
      walk = relative:
        lib.concatMapAttrs
          (entry: type:
            let path = "${relative}/${entry}"; in
            if type == "directory" then
              walk path
            else {
              "${name}${path}".source =
                config.lib.file.mkOutOfStoreSymlink "${live}/.config/${name}${path}";
            })
          (builtins.readDir "${dotfiles}/.config/${name}${relative}");
    in
    walk "";
in
{
  imports = [ ./neovim.nix ]
    ++ lib.optional (builtins.pathExists ./hosts/${hostname}.nix) ./hosts/${hostname}.nix;

  home.username = userName;
  home.stateVersion = "24.05";

  home.sessionVariables = {
    NIX_CONFIG_DIR = "${config.home.homeDirectory}/.config/system";
    HOMESHICK_KINGDOM = "${config.home.homeDirectory}/.homesick/repos";
  };

  programs.home-manager.enable = true;

  # nix-direnv replaces direnv's built-in `use flake` with a version that
  # caches the dev shell and keeps a GC root, so entering a project is instant
  # after the first time instead of re-evaluating the flake on every cd.
  #
  # The zsh hook stays in .zshrc under zinit's `nocd` (home-manager's would go
  # into programs.zsh.initContent, which is inert while .zshrc is a lifted
  # dotfile) — enabling both would just eval the hook twice.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = false;
  };

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

    # default-key, keyserver and no-emit-version say nothing about the
    # platform, and irulan needs them to sign commits as the same identity.
    # gpg-agent.conf is the part that differs, so each platform module declares
    # its own.
    ".gnupg/gpg.conf".source = "${dotfiles}/.gnupg/gpg.conf";

    # zinit comes from the flake input, not from the old
    # $HOMESHICK_KINGDOM/dot/zinit submodule path.
    #
    # The zinit.git/ subdirectory is not cosmetic: zinit resolves
    # ZINIT[HOME_DIR] to $XDG_DATA_HOME/zinit whenever that exists and writes
    # plugins/, snippets/, completions/ and polaris/ into it. Linking the
    # source there directly makes the directory zinit wants to own read-only,
    # so every plugin install fails. Upstream's own install puts the checkout
    # in a zinit.git/ subdirectory for exactly this reason, which leaves
    # ~/.local/share/zinit a real directory (and matches where newt's existing
    # plugin cache already lives).
    ".local/share/zinit/zinit.git".source = inputs.zinit;
  };

  # gpg refuses to use a home directory that is readable by anyone else, and
  # the one home-manager creates on its way to linking gpg.conf gets the
  # default 755.
  home.activation.gnupgPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run chmod 700 "${config.home.homeDirectory}/.gnupg"
  '';

  # XDG config directories. Each lifts an entire subtree from
  # dotfiles/home/.config/ except where the app writes back to its dir
  # — those use mkOutOfStoreSymlink so the link target stays mutable.
  xdg.configFile = lib.mkMerge [
    # Edited far too often to want a rebuild in the loop: prompt, aliases,
    # functions and the zinit snippets under init/ are all sourced fresh by
    # every new shell, so a live link means editing one is just editing a file.
    (liveConfig "zsh")

    {
    # git is recursive rather than a single directory symlink because the
    # private homeshick castle plants git/authors.yml inside it and bootstrap
    # links the castle before the first switch. A directory symlink would put
    # that file in the way on every fresh machine, and once the store link won
    # that fight there'd be nowhere writable for homeshick to put it back.
    # (zsh has the same overlap, handled by liveConfig above.)
    "git" = {
      source = "${dotfiles}/.config/git";
      recursive = true;
    };

    "atuin".source = "${dotfiles}/.config/atuin";
    "bat".source = "${dotfiles}/.config/bat";
    # Only the toml, not the whole dir — programs.direnv.nix-direnv writes
    # direnv/lib/hm-nix-direnv.sh into this same tree, and a single symlink
    # for the directory would collide with it.
    "direnv/direnv.toml".source = "${dotfiles}/.config/direnv/direnv.toml";
    "kitty".source = "${dotfiles}/.config/kitty";
    "mise".source = "${dotfiles}/.config/mise";
    "k9s".source = "${dotfiles}/.config/k9s";
    "tridactyl".source = "${dotfiles}/.config/tridactyl";
    "worktrunk".source = "${dotfiles}/.config/worktrunk";
    "tabtab".source = "${dotfiles}/.config/tabtab";
    "starship".source = "${dotfiles}/.config/starship";
    "starship.toml".source = "${dotfiles}/.config/starship.toml";

    # zed writes back into its config dir (settings.json, keymap.json
    # change from the UI) — mkOutOfStoreSymlink points at the real
    # working copy so writes land in the repo where they can be committed.
    "zed".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/system/dotfiles/home/.config/zed";

    # Same as zed: the spicetify-watcher agent runs `spicetify backup apply`
    # on every Spotify update, which rewrites config-xpui.ini (and creates
    # CustomApps/ and Extensions/) in this directory.
    "spicetify".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/system/dotfiles/home/.config/spicetify";

    # Same as zed, three times over: Glide regenerates glide.d.ts into this
    # directory, it's a pnpm project (node_modules), and its .envrc has direnv
    # writing .direnv/ there. All three need a writable path.
    "glide".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/system/dotfiles/home/.config/glide";

    # nvim comes from the dedicated neovim flake input. recursive = true
    # makes each file an individual symlink so nvim can drop runtime
    # files (lazy-lock.json, shada, vim.pack state, …) alongside the
    # config without the whole dir being read-only.
    "nvim" = {
      source = "${inputs.neovim-config}/home/.config/nvim";
      recursive = true;
    };
    }
  ];
}
