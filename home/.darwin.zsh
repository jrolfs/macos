#
# nix-darwin

nix_darwin_init=/etc/static/zshrc

if [ -f $nix_darwin_init ]; then
  export NIX_CONF_DIR="/etc/nix"
  export NIX_OTHER_STORES="/run/nix/remote-stores/*/nix"
  export NIX_PATH="darwin=$HOME/.nix-defexpr/darwin:darwin-config=$HOME/.nixpkgs/darwin-configuration.nix:nixpkgs=$HOME/.nix-defexpr/channels/nixpkgs:$HOME/.nix-defexpr/channels"
  export NIX_USER_PROFILE_DIR="/nix/var/nix/profiles/per-user/$USER"
  export NIX_PROFILES="/nix/var/nix/profiles/default /run/current-system/sw $HOME/.nix-profile"

  export NIX_SSL_CERT_FILE="$(grep -o '".*\.crt"' $nix_darwin_init | tr -d '"')"

  path=(
    /run/current-system/sw/bin
    /nix/var/nix/profiles/default/bin
    $HOME/.nix-profile/bin
    $path
  )
fi

#
# Functions

function reset-host {
  host=$(hostname)

  echo "Setting HostName to ${host}"
  sudo scutil --set HostName $host
  echo "Setting LocalHostName to ${host}"
  sudo scutil --set LocalHostName $host
  echo "Setting ComputerName to ${host}"
  sudo scutil --set ComputerName $host

  echo "Flushing DNS cache..."
  sudo killall -HUP mDNSResponder
}
