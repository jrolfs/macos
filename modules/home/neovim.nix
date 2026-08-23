{ pkgs, lib, config, ... }:

# Neovim installs its own plugins: `vim.pack.add` clones whatever is missing
# when the config loads, so a fresh machine sits at zero plugins until the
# first interactive launch. This boots each entry point once, headlessly, so
# the machine arrives warm.
#
# Both entry points are needed and neither substitutes for the other: init.vim
# and init-kitty.vim (kitty's scrollback pager) declare different plugin sets
# in lua/packages/, and each is only ever loaded by its own host application.
# They do write into one shared pack directory, which is what lets the guard
# below be a single emptiness check.

let
  entryPoints = [ "init.vim" "init-kitty.vim" ];

  warmUp = pkgs.writeShellScript "neovim-pack-warmup" ''
    set -uo pipefail

    export PATH=${lib.makeBinPath [ pkgs.git pkgs.openssh pkgs.coreutils ]}:$PATH

    # Plugin repositories are public, so clone them over plain HTTPS: the
    # user's git config rewrites github.com to SSH, and activation is the wrong
    # place to depend on a key being present and unlocked. GIT_TERMINAL_PROMPT
    # matters more than it looks — without it a credential prompt would hang
    # the switch indefinitely, with nothing on screen to explain why.
    export GIT_CONFIG_GLOBAL=/dev/null
    export GIT_TERMINAL_PROMPT=0

    status=0

    # -c runs after the config is sourced, so this overrides init.vim's
    # `let g:session_autosave = 'yes'` — otherwise a warm-up would overwrite
    # the saved default session on its way out.
    boot() {
      # Same reasoning as the prompt: a wedged clone should fail the step, not
      # stall the switch behind it.
      timeout 600 ${pkgs.neovim}/bin/nvim --headless \
        -u "${config.xdg.configHome}/nvim/$1" \
        -c 'let g:session_autosave = "no"' -c 'qa'
    }

    for entry in ${lib.escapeShellArgs entryPoints}; do
      echo "neovim: installing plugins for $entry"

      # Two passes. The first is expected to be noisy: plugins are cloned
      # while the config is already running, so anything the config `require`s
      # from a plugin that did not exist yet fails on the way past. The second
      # pass is the one whose exit status means something.
      boot "$entry" || true
      boot "$entry" || status=1
    done

    exit $status
  '';
in
{
  # Runs on every activation rather than only when the pack directory is empty.
  # `vim.pack.add` is a no-op for plugins that are already cloned, so the cost
  # of the warm case is two nvim boots — and gating on emptiness would mean a
  # plugin added to the config after the first switch never got installed by
  # one, which is the case this module exists to cover.
  home.activation.neovimPack = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${warmUp} \
      || warnEcho "neovim: plugin install did not complete — :checkhealth vim.pack in an interactive session"
  '';
}
