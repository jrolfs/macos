{ pkgs, hostname, ... }:

{
  networking.hostName = hostname;
  networking.computerName = "Ala";
  networking.localHostName = hostname;

  # ala-specific darwin options go here as they come up.
}
