self: super:

let
  # Pin packages whose current-revision build isn't in the binary cache yet.
  # `pin` prints the live cache status on each rebuild (see pin.nix) so we know
  # when a pin is safe to remove.
  # pin = import ./pin.nix super;

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
  # NOTE: leaving this as an example usage of `pin`
  # mise = pin {
  #   name = "mise";
  #   rev = "baf9fac791ea8173567a01ac2b21c96806c63b05";
  #   sha256 = "02k7092jj3qql9hxl7zawxi89917kbyjk6a17mf118hicq1cp84y";
  # };

  spicetify-cli = masterPkgs.spicetify-cli;

  # mcp-nixos runs its pytest suite at build time. `test_read_text_file`
  # picks an arbitrary small text file out of the live /nix/store, reads it,
  # and asserts the output contains no "Error" — but plenty of store files
  # legitimately contain that substring (e.g. highlight.pack.js's minified
  # JS: SyntaxError, etc.), so the test fails non-deterministically depending
  # on which store path it happens to land on. The read itself works fine;
  # the assertion is just naive. Drop this once upstream fixes the test.
  mcp-nixos = super.mcp-nixos.overridePythonAttrs (old: {
    disabledTests = (old.disabledTests or [ ]) ++ [ "test_read_text_file" ];
  });

  # worktrunk's test suite includes two tests that probe the OS process table
  # (reading its own PID and a spawned child `sh`), which the Nix build sandbox
  # on darwin doesn't expose — they panic with "own pid must be readable from
  # the process table" / "child sh must be visible to the probe". The package
  # already skips other sandbox-hostile tests via checkFlags; append these two.
  # Drop once upstream gates them on process-table availability.
  worktrunk = super.worktrunk.overrideAttrs (old: {
    checkFlags = (old.checkFlags or [ ]) ++ [
      "--skip=shell::utils::tests::test_process_name_and_ppid_self"
      "--skip=shell::utils::tests::test_probe_reports_invoked_name_for_sh"
    ];
  });

  # zshcs — Zsh LSP server (github:yuys13/zshcs), not in nixpkgs. Pinned via
  # `pkgs.npins` (see npins/sources.json); update with `npins update zshcs`.
  # Reuses upstream flake.nix's build recipe: a plain buildRustPackage with
  # checks disabled (its tests need a pty unavailable in the Nix sandbox).
  # The server spawns `zsh` at runtime for completions, so wrap it to guarantee
  # zsh is on PATH even when launched by a GUI editor with a minimal environment
  # (--suffix keeps the user's own environment/commands ahead of it).
  zshcs = super.rustPlatform.buildRustPackage {
    pname = "zshcs";
    version = "0.1.0";
    src = sources.zshcs;
    cargoLock.lockFile = "${sources.zshcs}/Cargo.lock";
    doCheck = false;
    nativeBuildInputs = [ super.makeWrapper ];
    postInstall = ''
      wrapProgram $out/bin/zshcs \
        --suffix PATH : ${super.lib.makeBinPath [ super.zsh ]}
    '';
  };

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
