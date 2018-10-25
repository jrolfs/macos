#
# nix-darwin

nix_darwin_init=/etc/static/zshrc

if [ -f $nix_darwin_init ]; then
  source $nix_darwin_init
fi


#
# Functions

function nix-search {
  nix-env -qa ".*$1.*"
}

function nix-rip {
  rg -g "**/*$1*/**/default.nix" --files --hidden ~/.nix-defexpr/nixpkgs/pkgs
}

function reset-host {
  host=$(hostname -s)

  echo "Setting HostName to ${host}"
  sudo scutil --set HostName $host
  echo "Setting LocalHostName to ${host}"
  sudo scutil --set LocalHostName $host
  echo "Setting ComputerName to ${host}"
  sudo scutil --set ComputerName $host

  echo "Flushing DNS cache..."
  sudo killall -HUP mDNSResponder
}

function set-gui-title {
    echo -ne "\033]$1;$2\007"
}

function set-title { set-gui-title 0 $@; }
function set-title-tab { set-gui-title 1 $@; }
function set-title-window () { set-gui-title 2 $@; }
