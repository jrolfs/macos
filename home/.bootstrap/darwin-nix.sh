#!/usr/bin/env bash

[ ! -L /run ] && sudo ln -s private/var/run /run

export NIX_PATH=darwin=$HOME/.nix-defexpr/darwin:darwin-config=$HOME/.nixpkgs/darwin-configuration.nix:$NIX_PATH

$(nix-build '<darwin>' -A system --no-out-link)/sw/bin/darwin-rebuild build
$(nix-build '<darwin>' -A system --no-out-link)/sw/bin/darwin-rebuild switch
