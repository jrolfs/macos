{ ... }:

# Plex Media Server, native rather than in Docker.
#
# This runs beside the QPKG install on Leia, not instead of it: a separate,
# freshly claimed server reading the same media over NFS
# (hosts/irulan/default.nix mounts it read-only at /mnt/nas/media). The library
# database and transcode cache stay on the local SSD under dataDir. Whether
# Irulan later takes over Leia's library, watch state included, is a decision
# for the Plex phase of documentation/IRULAN-MIGRATION.md.
#
# Hardware transcoding needs Plex Pass, the "Use hardware acceleration when
# available" setting, and access to /dev/dri. The module's default
# accelerationDevices already lets the unit see every device; the groups below
# grant the permission on the render node itself.

{
  services.plex = {
    enable = true;
    # 32400 for clients, plus the GDM discovery ports that let apps on the LAN
    # find the server without going through plex.tv.
    openFirewall = true;
  };

  users.users.plex.extraGroups = [ "render" "video" ];
}
