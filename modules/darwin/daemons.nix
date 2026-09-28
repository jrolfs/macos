{ pkgs, ... }:

# Headless things only. A GUI app started from here exec's the Mach-O inside
# its bundle and never becomes a registered app instance, which costs it its
# TCC grants. Those belong in login-items.nix, which explains why.
#
# Hammerspoon is the deliberate exception: KeepAlive restarts it after a crash
# and login items have no equivalent, so it stays here.

{
  launchd.user.agents = {
    hammerspoon = {
      path = [ "/Applications/Hammerspoon.app" ];
      serviceConfig = {
        Label = "org.hammerspoon.Hammerspoon";
        ProgramArguments = [ "/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon" ];
        KeepAlive = true;
        RunAtLoad = true;
      };
    };

    nightlight = {
      serviceConfig = {
        Label = "com.github.smudge.nightlight";
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "${pkgs.nightlight}/bin/nightlight schedule start && ${pkgs.nightlight}/bin/nightlight temp 75"
        ];
        RunAtLoad = true;
      };
    };

  };
}
