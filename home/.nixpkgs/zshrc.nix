config: lib:

lib.mkForce ''
    # /etc/static/zshrc

    # - Read-only for ❄ Nix configuration
    # - This file is read for interactive shells
    # - Please *do not edit* this file

    # Only execute this file once per shell
    if [ -n "$NIX_ZSHRC_SOURCED" ]; then return; fi; NIX_ZSHRC_SOURCED=1

    bindkey -e

    # Add Nix bin directories to $PATH
    path=(${config.environment.systemPath} $path)

    # Environment
    ${config.system.build.setEnvironment.text}
    ${config.system.build.setAliases.text}
    ${config.environment.extraInit}

    # Add completions to Zsh function path
    for profile in ''${(z)NIX_PROFILES}; do
      fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions)
    done
  ''
