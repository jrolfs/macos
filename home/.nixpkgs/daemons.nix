{ ... }:

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
