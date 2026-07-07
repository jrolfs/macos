{ pkgs, ... }:

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

    # stay = {
    #   path = [ "/Applications/Stay.app" ];
    #   serviceConfig = {
    #     Label = "com.cordlessdog.stay";
    #     ProgramArguments = [ "/Applications/Stay.app/Contents/MacOS/Stay" ];
    #     KeepAlive = true;
    #     RunAtLoad = true;
    #   };
    # };

    # moom = {
    #   path = [ "/Applications/Moom.app" ];
    #   serviceConfig = {
    #     Label = "com.manytricks.Moom";
    #     ProgramArguments = [ "/Applications/Moom.app/Contents/MacOS/Moom" ];
    #     KeepAlive = true;
    #     RunAtLoad = true;
    #   };
    # };
  };
}
