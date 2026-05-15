{ lib, pkgs, config, userName, ... }:

# Darwin-only home-manager shared module. Loaded automatically for every
# darwinConfiguration via home-manager.sharedModules in flake.nix.

let
  dotfiles = ../../dotfiles/home;
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

  # gnupg: gpg-agent.conf + scdaemon.conf + gpg.conf. recursive = true
  # because the user's gnupg dir also holds keys/state at runtime
  # alongside these config files.
  home.file.".gnupg" = {
    source = "${dotfiles}/.gnupg";
    recursive = true;
  };

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
