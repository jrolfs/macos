{ lib, pkgs, config, userName, ... }:

# Darwin-only home-manager shared module. Loaded automatically for every
# darwinConfiguration via home-manager.sharedModules in flake.nix.

let
  dotfiles = ../../dotfiles/home;

  # gpg-agent execs pinentry-program fresh for every passphrase prompt, so
  # dispatching at that moment is what lets the `pin` toggle
  # (dotfiles/home/.config/zsh/init/gpg.zsh) be a one-line state file write with
  # no agent reload — and lets gpg-agent.conf stay a read-only store symlink
  # rather than something sed rewrites in place, which is what it used to be.
  #
  # Curses is the default, and it is the default by omission: anything other
  # than "mac" selects it, so there is nothing to initialize and an empty or
  # truncated state file degrades to the terminal prompt rather than to nothing.
  #
  # XDG_STATE_HOME is honoured if gpg-agent happens to have it, but the fallback
  # is an absolute path rather than $HOME/… — gpg-agent hands its child a
  # controlled environment, and a missing HOME here would silently mean "not
  # mac" forever.
  pinentry = pkgs.writeShellScript "pinentry-dispatch" ''
    state="''${XDG_STATE_HOME:-${config.home.homeDirectory}/.local/state}/pinentry"

    if [ "$(cat "$state" 2>/dev/null)" = mac ]; then
      exec ${pkgs.pinentry_mac}/bin/pinentry-mac "$@"
    fi

    exec ${pkgs.pinentry-curses}/bin/pinentry-curses "$@"
  '';
in
{
  # Provide ~/.zshrc.darwin — sourced by ~/.zshrc when uname is Darwin.
  # NIX_PATH export is gone (the flake handles that via the system
  # nix.nixPath + registry entries in modules/darwin/default.nix).
  # nix-switch / nix-rebuild aliases now use --flake; icn points at the
  # consolidated repo's icons/ dir.
  home.file.".zshrc.darwin".text = ''
    #
    #
    # Aliases ----------------------------------------------------------------------

    alias mkbk="mackup backup -f && mackup uninstall -f"
    alias mkrs="mackup restore -f && mackup uninstall -f"

    alias icn="(cd $NIX_CONFIG_DIR/icons && sudo ./apply.sh)"

    alias nix-switch="sudo -E darwin-rebuild switch --flake $NIX_CONFIG_DIR#$(hostname -s) --show-trace"
    alias nix-rebuild="sudo -E darwin-rebuild build --flake $NIX_CONFIG_DIR#$(hostname -s) --show-trace"
    alias nix-search="nix search nixpkgs"

    alias spoon="$(brew --prefix)/bin/hs"


    #
    #
    # Functions --------------------------------------------------------------------

    function reset-host {
      host=$(hostname -s)

      echo "Setting HostName to ''${host}"
      sudo scutil --set HostName $host
      echo "Setting LocalHostName to ''${host}"
      sudo scutil --set LocalHostName $host
      echo "Setting ComputerName to ''${host}"
      sudo scutil --set ComputerName $host

      echo "Flushing DNS cache..."
      sudo killall -HUP mDNSResponder
    }

    #
    # GitHub CLI → Raycast

    source "$XDG_CONFIG_HOME/zsh/github-to-raycast.zsh"
  '';

  # system.defaults.screencapture.location points here, and screencapture
  # silently falls back to the desktop if the directory is missing — as it is on
  # a fresh machine. The dock also carries a tile for it, which would render as
  # a "?" placeholder.
  home.activation.screenshotsDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Images/Screenshots"
  '';

  # karabiner writes back to its config dir (and we want the file
  # editable via the Karabiner-Elements UI too) — point at the live
  # working tree via an out-of-store symlink.
  xdg.configFile."karabiner" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/system/karabiner";
  };

  # hammerspoon: lift-and-shift the entire ~/.hammerspoon tree.
  # recursive = true keeps individual file symlinks so hammerspoon's
  # Spoons can drop state files alongside the Lua modules.
  home.file.".hammerspoon" = {
    source = "${dotfiles}/.hammerspoon";
    recursive = true;
  };

  # mackup config + database — kept on macOS so Homebrew-installed app
  # prefs that home-manager can't manage continue to sync.
  home.file.".mackup.cfg".source = "${dotfiles}/.mackup.cfg";
  home.file.".mackup" = {
    source = "${dotfiles}/.mackup";
    recursive = true;
  };

  # docker config (lift-and-shift; auth tokens get written here by
  # docker login — recursive so individual file overwrites work).
  home.file.".docker" = {
    source = "${dotfiles}/.docker";
    recursive = true;
  };

  # The two gnupg files that are macOS-specific: the pinentry choice only
  # arises here, and scdaemon is about a smartcard reader. gpg.conf is shared,
  # in modules/home/default.nix. Declared per file rather than as a directory so
  # that ~/.gnupg stays writable for the keyrings and agent sockets that live
  # alongside them.
  #
  # Generated rather than lifted from the dotfiles tree because
  # pinentry-program has to name a store path; the other four lines are
  # verbatim from the dotfile this replaced.
  home.file.".gnupg/gpg-agent.conf".text = ''
    enable-ssh-support
    default-cache-ttl 600
    max-cache-ttl 7200
    pinentry-program ${pinentry}
    allow-preset-passphrase
  '';
  home.file.".gnupg/scdaemon.conf".source = "${dotfiles}/.gnupg/scdaemon.conf";

  # Raycast scripts (the personal "scripts" folder Raycast users
  # register). Preferences are untouched — those live in Library and
  # Raycast manages them itself.
  home.file.".local/share/raycast" = {
    source = "${dotfiles}/.local/share/raycast";
    recursive = true;
  };

  # VSCode and Cursor settings sync — both edit/write to the same
  # underlying repo at ~/.config/vscode-sync-settings/. mkOutOfStoreSymlink
  # points the Application Support dirs there so the sync-settings
  # extension can commit changes back to a real working tree (not the
  # nix store).
  home.file."Library/Application Support/Code/User" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/vscode-sync-settings/profiles/main";
  };
  home.file."Library/Application Support/Cursor/User" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/vscode-sync-settings/profiles/main";
  };

  # Tridactyl native messaging host (Firefox extension talks to the
  # native helper via this manifest).
  home.file."Library/Application Support/Mozilla/NativeMessagingHosts/tridactyl.json".source =
    "${dotfiles}/Library/Application Support/Mozilla/NativeMessagingHosts/tridactyl.json";

  # Tridactyl native-main script (the actual helper binary referenced
  # by the JSON above).
  home.file.".local/share/tridactyl/native_main.py".source =
    "${dotfiles}/.local/share/tridactyl/native_main.py";
}
