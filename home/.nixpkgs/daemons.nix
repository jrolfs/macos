{ pkgs, ... }:

{
  launchd.user.agents = {
    # Enable the sunset-to-sunrise schedule, then set the warmth.
    #
    # These go through `script` rather than a hand-written ProgramArguments so
    # nix-darwin wraps them in `/bin/wait4path /nix/store`. /nix is a separate
    # APFS volume and isn't mounted yet when RunAtLoad fires at login, so the
    # hand-written version exited 127 and, having no KeepAlive, never retried.
    nightlight = {
      serviceConfig = {
        Label = "com.github.smudge.nightlight";
        RunAtLoad = true;
      };

      script = ''
        set -e
        ${pkgs.nightlight}/bin/nightlight schedule start
        ${pkgs.nightlight}/bin/nightlight temp 75
      '';
    };
  };
}
