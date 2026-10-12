{ config, lib, hostname, inputs, ... }:

# The commands for working on this configuration from a shell: nix-switch,
# nix-rebuild, nix-update and nix-search. One definition for every machine,
# written to ~/.config/zsh/init/nix.zsh (which .zshrc sources), with each
# platform supplying only what differs: how it rebuilds, and on macOS the
# Homebrew flags. The two used to be separate hand-written copies, and drifted:
# Linux had a bare alias with none of the flags.
#
# nix-switch takes:
#
#   --pull              fast-forward the configuration repo first, from any
#                       directory
#   --update            refresh flake.lock first, all inputs or, with
#   --update=<input>    --update=nixpkgs, just that one (repeat for several)
#
# plus whatever the platform adds, and passes anything else through to the
# rebuild. --update has to be asked for: the rebuild only ever reads the lock,
# which is what makes a bare nix-switch reproducible, so moving inputs
# underneath it silently would cost more than the keystrokes save. The lock
# change is left uncommitted on purpose, to be reviewed with the switch that
# used it.

let
  inherit (lib) mkOption types;

  cfg = config.nixCommands;

  # Baked in rather than read from $NIX_CONFIG_DIR and $(hostname -s) when the
  # shell starts. That variable is a home.sessionVariables entry, which lands in
  # hm-session-vars.sh, which nothing here sources — nix-darwin's /etc/zshenv
  # reads only its own set-environment, and home-manager's zsh integration is
  # inert while .zshrc is a lifted dotfile. The aliases were expanding to
  # `--flake #ala`.
  #
  # The hostname is the one this configuration was evaluated for, and it is what
  # selected this configuration in the first place, so asking the running system
  # was only ever a slower route to the same answer — and a wrong one if the
  # machine is mid-rename.
  directory = "${config.home.homeDirectory}/.config/system";
  flake = "${directory}#${hostname}";

  # Every flake input, for completing --update=<input> and nix-update's
  # arguments. Taken from the flake that built this configuration, so it's
  # exactly the set flake.lock knows about.
  inputNames = lib.concatStringsSep " "
    (builtins.attrNames (removeAttrs inputs [ "self" ]));

  flagSpecs = lib.concatMapStrings
    (flag: " \\\n          '${flag.pattern}[${flag.description}]'")
    cfg.flags;

  flagCases = lib.concatMapStrings
    (flag: "      ${flag.pattern}) ${flag.action} ;;\n")
    cfg.flags;
in
{
  options.nixCommands = {
    switch = mkOption {
      type = types.str;
      description = "Command line that switches to the flake, before `--flake`.";
    };

    build = mkOption {
      type = types.str;
      description = "Command line that builds the flake, before `--flake`.";
    };

    locals = mkOption {
      type = types.str;
      default = "";
      description = "Extra `name=value` locals for nix-switch, for platform flags to set.";
    };

    flags = mkOption {
      default = [ ];
      description = "Platform flags for nix-switch, each a case pattern and the zsh it runs.";
      type = types.listOf (types.submodule {
        options = {
          pattern = mkOption { type = types.str; };
          action = mkOption { type = types.str; };
          description = mkOption {
            type = types.str;
            description = "Shown beside the flag when completing.";
          };
        };
      });
    };

    beforeSwitch = mkOption {
      type = types.lines;
      default = "";
      description = "zsh run after --pull and --update, just before the switch.";
    };
  };

  # On fpath through ~/.config/zsh/completions, so compinit finds it by its
  # #compdef line. It can't be registered from nix.zsh: that is sourced before
  # compinit runs, when compdef doesn't exist yet.
  config.xdg.configFile."zsh/completions/_nix-switch".text = # zsh
    ''
      #compdef nix-switch nix-update

      case $service in
        nix-update)
          _arguments '*:flake input:(${inputNames})'
          ;;
        nix-switch)
          _arguments \
            '--pull[fast-forward ~/.config/system first]' \
            '*--update=-[refresh flake.lock first, all inputs or the one named]::flake input:(${inputNames})'${flagSpecs}
          ;;
      esac
    '';

  # Quoted wherever the flake reference appears: unquoted, zsh's extendedglob
  # reads the `#` in `system#<host>` as a pattern operator, finds no file
  # matching it, and refuses to run the command.
  config.xdg.configFile."zsh/init/nix.zsh".text = # zsh
    ''
      alias nix-search="nix search nixpkgs"
      alias nix-rebuild="${cfg.build} --flake '${flake}' --show-trace"

      # --flake takes the directory, not the #hostname reference the rebuild
      # wants. Naming inputs updates only those: `nix-update nixpkgs`.
      alias nix-update="nix flake update --flake '${directory}'"

      function nix-switch {
        local update=no pull=no ${cfg.locals}
        local -a rest inputs

        for argument in "$@"; do
          case "$argument" in
            --pull) pull=yes ;;
            --update) update=yes ;;
            --update=*) update=yes; inputs+=("''${argument#--update=}") ;;
      ${flagCases}      *) rest+=("$argument") ;;
          esac
        done

        # Before --update: the update rewrites flake.lock, which a pull
        # afterwards would collide with.
        if [[ $pull == yes ]]; then
          git -C '${directory}' pull --ff-only || return
        fi

        if [[ $update == yes ]]; then
          nix flake update --flake '${directory}' "''${inputs[@]}" || return
        fi

      ${cfg.beforeSwitch}
        ${cfg.switch} --flake '${flake}' --show-trace "''${rest[@]}"
      }
    '';
}
