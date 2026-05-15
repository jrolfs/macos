{ pkgs, hostname, userName, ... }:

# NixOS NUC — phase 2 stub. Filled in when the hardware is provisioned.

{
  networking.hostName = hostname;

  users.users.${userName} = {
    isNormalUser = true;
    home = "/home/${userName}";
    extraGroups = [ "wheel" ];
  };

  # Allow nix flake check to evaluate this configuration with a
  # placeholder fileSystems and bootloader. Real values land when the
  # NUC is ready to install.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
