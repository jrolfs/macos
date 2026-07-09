self: super:

let
  # Pin packages whose current-revision build isn't in the binary cache yet.
  # `pin` prints the live cache status on each rebuild (see pin.nix) so we know
  # when a pin is safe to remove. As of 6-28-2026 on nixpkgs@89570f,
  # mise@2026.6.11 isn't cached for aarch64-darwin, so pin it to the latest
  # cached build (2026.6.5, from nixpkgs@baf9fac).
  pin = import ./pin.nix super;

  # Support installing packages from the `nixpkgs/master` branch via
  # `masterPkgs`, but pin `nixpkgs/master` revision in npins/sources.json
  # via `pkgs.npins`. Update the lockfile via `npins update nixpkgs`.
  #
  # NOTE: packages installed from `master` are often not cached in
  # Cachix, so install from `masterPkgs`  may often result in building
  # a bunch of stuff from source.

  sources = import ./npins;
  masterPkgs = import sources.nixpkgs {
    localSystem = super.stdenv.hostPlatform.system;
    inherit (super) config;
  };
in

{
  mise = pin {
    name = "mise";
    rev = "baf9fac791ea8173567a01ac2b21c96806c63b05";
    sha256 = "02k7092jj3qql9hxl7zawxi89917kbyjk6a17mf118hicq1cp84y";
  };

  spicetify-cli = masterPkgs.spicetify-cli;

  darwin-zsh-completions = super.runCommandNoCC "darwin-zsh-completions-0.0.0"
    { preferLocalBuild = true; }
    ''
      mkdir -p $out/share/zsh/site-functions
      cat <<-'EOF' > $out/share/zsh/site-functions/_darwin-rebuild
      #compdef darwin-rebuild
      #autoload
      _nix-common-options
      local -a _1st_arguments
      _1st_arguments=(
        'switch:Build, activate, and update the current generation'\
        'build:Build without activating or updating the current generation'\
        'check:Build and run the activation sanity checks'\
        'changelog:Show most recent entries in the changelog'\
      )
      _arguments \
        '--list-generations[Print a list of all generations in the active profile]'\
        '--rollback[Roll back to the previous configuration]'\
        {--switch-generation,-G}'[Activate specified generation]'\
        '(--profile-name -p)'{--profile-name,-p}'[Profile to use to track current and previous system configurations]:Profile:_nix_profiles'\
        '1:: :->subcmds' && return 0
      case $state in
        subcmds)
          _describe -t commands 'darwin-rebuild subcommands' _1st_arguments
        ;;
      esac
      EOF
    '';
}
