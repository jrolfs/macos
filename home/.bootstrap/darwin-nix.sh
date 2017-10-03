#!/usr/bin/env bash

[ ! -L /run ] && sudo ln -s private/var/run /run

export NIX_PATH=darwin=$HOME/.nix-defexpr/darwin:\
nixpkgs=$HOME/.nix-defexpr/nixpkgs:\
darwin-config=$HOME/.nixpkgs/darwin-configuration.nix:\
/nix/var/nix/profiles/per-user/$USER/channels:\
$NIX_PATH

$(nix-build '<darwin>' -A system --no-out-link)/sw/bin/darwin-rebuild build
$(nix-build '<darwin>' -A system --no-out-link)/sw/bin/darwin-rebuild switch
