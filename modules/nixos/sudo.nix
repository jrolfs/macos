{ config, lib, userName, ... }:

# sudo without typing a password, the way Touch ID does it on the Macs: a
# YubiKey tap at the machine, or the SSH key in a forwarded agent over SSH.
# The password still works whenever neither is available.

let
  # The authentication subkey of the GPG key, as an SSH key
  # (`gpg --export-ssh-key 91C155A78968EEE863ED8B22626AE770762AC2F3`). gpg-agent
  # serves it as the SSH identity on every machine.
  #
  # Committed here even though ssh.nix derives ~/.ssh/authorized_keys from the
  # GPG key on each machine instead: sudo must only trust a key list the user
  # can't edit, or anything running as the user could add a key and give itself
  # root. NixOS writes this one to /etc/ssh/authorized_keys.d, owned by root.
  # It's a public key, so publishing it costs nothing.
  sshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCcgXoRTqCy5CFerA6v6nkKKCTTWdJxlJwaof3y4xf5dydXkmyDYYDrRZFOrEvhSqttlW0Fqxol1Ji6DQNr0qaDgdm0OPGYo7gDiu5W1knK59OL/f5p8jgQI0sZ13W9BBj6elhrCcAXdrsCZhPEdmzA1wj7j3a8gtcVL/OGSAEuPOLhu3YXg6TP5zI92hSvUhKjZFAOgAp1IYCmFU6Rwi/QDo/HiyZLJz4DX32tdWcrzsUkWTKrr/tURrkx1TM5K24lC0H0dLZAIq+x2nPAsRpkkBe6+WB4PZPwj92pGE+MafoJJYoLbt5QBHF/HWGiEmo4FNqFd+Y9FSVimebGyNRrEZ8paMSHMR9Hq57HzvE3uU06MfDD+ih3jO4xwdzfoFnxaAkZYUFGwvPc9x6oo9ApV1ZXeLV8dWJgGx/jvTwa3vQXWWPN6gf3t6EuMpKR0YJMe1jeYXUUmyCUu+x4WBqJdtIxgqonNeT/Yv71EcQciHQVXBUx1OageOMxd+3TGHaaGvOLeRsYJPObo2LHcNwcvCbLLcCu67pFV+WZ70l1CNKaZV8jV/UyA9af0Q84tbzonrKdOfwtXxn9KHGCAgWbrL82cbnDZkY+ptjagHDVmxMeCcgIm92lJ4uNo1jlJ9rrnq1je3xrcYW+IPOI2rcswDxayJuIfK9y/jiumQsl/Q== openpgp:0xF9A2A98C";

  # Registered YubiKeys, one line of `pamu2fcfg` output each (key handle and
  # public key, not secrets). Generate on any machine with the key plugged in:
  #
  #   nix shell nixpkgs#pam_u2f -c pamu2fcfg -n -o pam://${userName} -i pam://${userName}
  #
  # The fixed origin is what lets one registration work on every host; by
  # default pam_u2f binds a key to the hostname it was registered on.
  yubikeys = [
    # USB-C Nano, registered 2026-10-12
    "Iv7NJzYfGczhtVBNcEk/yiwYY4y2Kbr8LZ8xK24I81xyVFi8mUEMoBhcs/sWE9n8X9T2Bcjgm6tmJmEeW9hv6g==,yjw4b6sC/7cVLf4UV6tVztdWuolALvEXVgmZ2OhnTJBRX/kj4uoqQEM3QkRiujlSJWmXgUCdvMoczJlDW7/jwQ==,es256,+presence"
  ];

  origin = "pam://${userName}";
in
{
  # Agent forwarding is what makes this work over SSH, so the client has to
  # forward (`ssh -A`, or ForwardAgent for the host). It also means root on this
  # machine can use the forwarded agent while you're connected, which is fine
  # for machines you own and a reason not to forward to ones you don't.
  security.pam.sshAgentAuth.enable = true;
  users.users.${userName}.openssh.authorizedKeys.keys = [ sshKey ];

  # sudo only. pam_u2f's global switch would also let a tap stand in for the
  # password at the login prompt, which isn't the point.
  security.pam.services.sudo.u2fAuth = yubikeys != [ ];
  security.pam.u2f = lib.mkIf (yubikeys != [ ]) {
    control = "sufficient";
    settings = {
      inherit origin;
      appid = origin;
      cue = true;
      authfile = builtins.toFile "u2f-keys"
        "${userName}:${lib.concatStringsSep ":" yubikeys}\n";
    };
  };
}
