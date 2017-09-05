#
# nix-darwin

nix_darwin_init=/etc/static/zshrc

if [ -f $nix_darwin_init ]; then
  source $nix_darwin_init
fi

#
# Functions

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

function pbsend {
  ssh $1 "cat | pbcopy"
}
