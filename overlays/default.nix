inputs:

self: super:

let
  # Pin packages whose current-revision build isn't in the binary cache yet.
  # `pin` prints the live cache status on each rebuild (see pin.nix) so we know
  # when a pin is safe to remove. Currently no active pins — the mise pin was
  # dropped 2026-08-12 once cache.nixos.org caught up (the helper reported it
  # safe to remove). Kept imported for the next time a build lags the cache.
  pin = import ./pin.nix super;

  # Install packages from the `nixpkgs/master` branch via `masterPkgs`,
  # pinned by the `nixpkgs-master` flake input (bump with
  # `nix flake update nixpkgs-master`). Replaces the previous npins-based
  # pin now that everything is flake-managed.
  #
  # NOTE: packages installed from `master` are often not cached in
  # Cachix, so install from `masterPkgs` may often result in building
  # a bunch of stuff from source.
  masterPkgs = import inputs.nixpkgs-master {
    localSystem = super.stdenv.hostPlatform.system;
    inherit (super) config;
  };
in

{
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
  # the `zshcs` flake input (flake = false); bump with `nix flake update zshcs`.
  # Reuses upstream flake.nix's build recipe: a plain buildRustPackage with
  # checks disabled (its tests need a pty unavailable in the Nix sandbox).
  # The server spawns `zsh` at runtime for completions, so wrap it to guarantee
  # zsh is on PATH even when launched by a GUI editor with a minimal environment
  # (--suffix keeps the user's own environment/commands ahead of it).
  zshcs = super.rustPlatform.buildRustPackage {
    pname = "zshcs";
    version = "0.1.0";
    src = inputs.zshcs;
    cargoLock.lockFile = "${inputs.zshcs}/Cargo.lock";
    doCheck = false;
    nativeBuildInputs = [ super.makeWrapper ];
    postInstall = ''
      wrapProgram $out/bin/zshcs \
        --suffix PATH : ${super.lib.makeBinPath [ super.zsh ]}
    '';
  };

  # claude-sync — end-to-end-encrypted sync of Claude Code session state
  # (github:tawanorg/claude-sync). Not in nixpkgs, and upstream ships no
  # license, so it couldn't be upstreamed as-is. The npm package of the same
  # name is only a prebuilt-binary shim; this builds from the Go source pinned
  # by the `claude-sync` flake input (bump with `nix flake update claude-sync`).
  claude-sync = super.buildGoModule {
    pname = "claude-sync";
    version = "0.4.0";
    src = inputs.claude-sync;
    vendorHash = "sha256-VLqVk5bhM+WoEbP+agFpm1LjzI2qFWlWQZB8yV2vbOU=";
    subPackages = [ "cmd/claude-sync" ];
    meta.mainProgram = "claude-sync";
  };

  # The Claude Code helper scripts kept in dotfiles/home/.claude/bin, built into
  # a package so they land on PATH with the rest of the profile instead of
  # needing ~/.claude/bin added to it.
  #
  # patchShebangs rewrites their `env python3` to the store python3 below, which
  # is the other half of the reason to package them: `env` would otherwise find
  # /usr/bin/python3, a Command Line Tools shim that prompts to install Xcode on
  # a machine that hasn't, and is gone entirely on some macOS releases.
  claude-helpers = super.runCommandLocal "claude-helpers"
    { nativeBuildInputs = [ super.python3 ]; }
    ''
      install -d $out/bin
      find ${../dotfiles/home/.claude/bin} -maxdepth 1 -type f \
        -exec install -m755 -t $out/bin {} +
      patchShebangs --build $out/bin
    '';

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
