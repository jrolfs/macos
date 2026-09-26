{ hostname, ... }:

# M5 MacBook Air, 32 GB — work machine, replacing newt. MDM-managed, so some
# apps arrive from device management rather than from here; those go in
# modules/darwin/excluded-apps.nix as they turn up. Only Xcode is listed for
# now, to keep the first bootstrap short.
#
# Unlike newt, this one needs no `ids.gids.nixbld`: its Nix install is new
# enough to use the current group ID, same as ala.

{
  networking.hostName = hostname;
  networking.computerName = "Adrian";
  networking.localHostName = hostname;

  # adrian-specific darwin options go here as they come up.
}
