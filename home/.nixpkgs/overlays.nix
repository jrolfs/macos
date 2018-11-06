self: super:

rec {
  chunkwm = super.recurseIntoAttrs (super.callPackage (super.fetchFromGitHub {
    owner = "jrolfs";
    repo = "chunkwm.nix";
    sha256 = "6a21e807785515a1f3607f5e65a4adbe641010db";
    rev = "0.1";
  }) {
    inherit (super.darwin.apple_sdk.frameworks) Carbon Cocoa ApplicationServices;
  });

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
