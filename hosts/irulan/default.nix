{ pkgs, lib, hostname, userName, ... }:

# Beelink SEi 12 Mini PC — i5-12450H, 16 GB RAM, 500 GB SSD.
# Home-infra host: native Home Assistant + Plex + step-ca; bootstrap-tier
# Komodo containers; everything else lives in the compose repo and is
# deployed via Komodo periphery.
#
# hardware-configuration.nix is NOT imported here yet — it gets generated
# by `nixos-generate-config --root /mnt` during the install on real
# hardware and lands at /etc/nixos/hardware-configuration.nix. After the
# install, copy it into hosts/irulan/ and add the import line below.

{
  imports = [
    # ./hardware-configuration.nix              # TODO: add after install

    ../../modules/nixos/services/home-assistant.nix
    ../../modules/nixos/services/plex.nix
    ../../modules/nixos/services/step-ca.nix
    ../../modules/nixos/services/komodo.nix
  ];

  networking.hostName = hostname;
  networking.useDHCP = lib.mkDefault true;  # static IP TBD; DHCP for now.
  networking.firewall.enable = true;

  users.users.${userName} = {
    isNormalUser = true;
    home = "/home/${userName}";
    shell = pkgs.zsh;
    # video + render: Plex hardware transcoding via Quick Sync.
    # docker: invoke docker without sudo (Komodo periphery + ad-hoc).
    extraGroups = [ "wheel" "video" "render" "docker" ];
  };

  # Intel UHD Graphics (12th-gen) hardware video decode + encode for Plex.
  # intel-media-driver covers Broadwell+ (the i5-12450H's iGPU); the
  # legacy intel-vaapi-driver is unnecessary on this chip.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  # Docker daemon for the bootstrap-tier Komodo containers (see
  # modules/nixos/services/komodo.nix). Komodo manages its own
  # containers via the docker socket.
  virtualisation.docker.enable = true;

  # SSH for `nixos-rebuild switch --target-host jamie@irulan` from
  # another machine. Keys flow in via home-manager (private castle).
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  # NFS mount of the QNAP media share. Plex / media services read from
  # here; library DB (services.plex.dataDir) is on the local SSD.
  # x-systemd.automount + noauto: don't block boot if NAS is down;
  # mount on first access; remount cleanly when network comes back.
  # TODO: confirm export path on QNAP (currently /share/Media exposed
  # via NFS on the NAS — adjust if QNAP exports a different path).
  fileSystems."/mnt/nas/media" = {
    device = "qnap.lan:/share/Media";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "_netdev"
      "nfsvers=4.2"
      "soft"
      "intr"
    ];
  };

  # Placeholder root + boot until hardware-configuration.nix lands.
  # Lets `nix flake check` evaluate the host without real hardware.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
