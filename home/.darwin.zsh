# nix-darwin

nix_darwin_init=/etc/static/zshrc
[ -f $nix_darwin_init ] && source $nix_darwin_init

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
