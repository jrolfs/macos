{ ... }:

# Disk layout for irulan, applied by disko during the nixos-anywhere install.
# This replaces both the hand-partitioning step and the `fileSystems` entries
# `nixos-generate-config` would have written, so hardware-configuration.nix is
# left with just CPU/kernel detail.
#
# WARNING: running disko *wipes* this device. That's the intent on a new
# machine (it ships with Windows), but it's why the device is named explicitly
# rather than discovered.
#
# Layout, on the single 500 GB NVMe:
#
#   1 MiB   BIOS boot stub — unused by systemd-boot, kept so the disk can also
#           be booted in legacy mode if the firmware ever falls back to it
#   1 GiB   ESP, vfat, mounted at /boot
#   rest    ext4, mounted at /
#
# No swap partition: zramSwap (see default.nix) gives compressed swap in RAM,
# which suits a container host better than writing to the SSD, and nothing here
# hibernates. No LUKS either — a headless box that must come up unattended
# after a power cut can't ask for a passphrase, and TPM-backed unlock is a
# project of its own rather than a checkbox.
#
# ext4 rather than btrfs: simplest thing that works, and the data worth
# snapshotting (media) lives on the NAS. Switching to btrfs subvolumes later is
# a reinstall, which disko makes cheap.

{
  disko.devices.disk.main = {
    # Verify against `lsblk` on the target before the first run. A Beelink
    # SEi 12's onboard SSD is NVMe, so this is almost certainly right — but an
    # incorrect device name here destroys the wrong disk.
    device = "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02";
        };
        esp = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
