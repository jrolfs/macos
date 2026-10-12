{ lib, pkgs, config, userName, hostname, ... }:

# Linux-only home-manager shared module. Loaded automatically for every
# nixosConfiguration via home-manager.sharedModules in flake.nix.
#
# Counterpart to modules/home/darwin.nix. Provides Linux-specific
# environment tweaks; the bulk of the shell config is shared via
# modules/home/default.nix and works on both OSes.

let
  # Baked in for the same reason as the darwin counterpart: $NIX_CONFIG_DIR
  # comes from home.sessionVariables and nothing sources hm-session-vars.sh, so
  # the alias was expanding to `--flake #irulan`.
  configDirectory = "${config.home.homeDirectory}/.config/system";
  flake = "${configDirectory}#${hostname}";
in
{
  # ~/.zshrc.linux is sourced by ~/.zshrc when uname is Linux.
  # Mirrors the .zshrc.darwin pattern from darwin.nix; the existing
  # dotfiles/home/.zshrc has the platform-rc lookup that picks the
  # right file based on uname.
  home.file.".zshrc.linux".text = # zsh
    ''
      #
      #
      # Aliases ----------------------------------------------------------------------

      # Quoted wherever the flake reference appears: unquoted, zsh's
      # extendedglob reads the `#` in `system#irulan` as a pattern operator,
      # finds no file matching it, and refuses to run the command.
      alias nix-rebuild="sudo -E nixos-rebuild build --flake '${flake}' --show-trace"

      # The darwin function's flags, minus the Homebrew ones.
      function nix-switch {
        local update=no pull=no
        local -a rest inputs

        for argument in "''$@"; do
          case "''$argument" in
            --pull)     pull=yes ;;
            --update)   update=yes ;;
            --update=*) update=yes; inputs+=("''${argument#--update=}") ;;
            *)          rest+=("''$argument") ;;
          esac
        done

        # Before --update: the update rewrites flake.lock, which a pull
        # afterwards would collide with.
        if [[ ''$pull == yes ]]; then
          git -C "${configDirectory}" pull --ff-only || return
        fi

        if [[ ''$update == yes ]]; then
          nix flake update --flake "${configDirectory}" "''${inputs[@]}" || return
        fi

        sudo -E nixos-rebuild switch --flake "${flake}" --show-trace "''${rest[@]}"
      }
      alias nix-search="nix search nixpkgs"
    '';

  # Declared inline rather than lifted from the dotfiles tree because the
  # macOS copy names pinentry-mac, which doesn't exist here. Irulan is
  # headless, so curses is the only pinentry that can work.
  #
  # enable-ssh-support is not optional on this host: the shared git config
  # rewrites every github.com URL to SSH via insteadOf, and the shared .zshenv
  # points SSH_AUTH_SOCK at ~/.gnupg/S.gpg-agent.ssh — a socket gpg-agent only
  # creates when asked. Without it there is no agent and no key on disk, so
  # every fetch fails.
  home.file.".gnupg/gpg-agent.conf".text = ''
    enable-ssh-support
    pinentry-program ${pkgs.pinentry-curses}/bin/pinentry-curses
    default-cache-ttl 60480000
    max-cache-ttl 60480000
  '';

  # Linux-side packages on top of the system-wide environment.systemPackages
  # in modules/nixos/default.nix. User-installed via home-manager profile.
  home.packages = with pkgs; [
    # Currently empty — add as Linux-only personal tools surface.
  ];
}
