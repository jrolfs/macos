{ config, lib, pkgs, userName, ... }:

# greetd on tty1, showing ReGreet, a GTK greeter, rather than a text one:
# a text greeter draws in the console font, so nothing about it could match
# the palette and typefaces the desktop behind it uses.
#
# By default it shows the login screen. desktop.autoLogin skips it, and even
# then `initial_session` is only a default, for whatever owns the choice of
# what the machine boots into (sessions.boot) to override.

let
  palette = (import ../../theme/palette.nix).dark.soft;
  fonts = import ../../theme/fonts.nix;
  fontPackage = font: lib.getAttrFromPath (lib.splitString "." font.package) pkgs;

  radius = "10px";
in
lib.mkIf config.desktop.enable {
  # The session uwsm generates for Hyprland. Named rather than spelled out as
  # a command so it matches what ReGreet lists after a logout.
  services.greetd.settings.initial_session = lib.mkIf config.desktop.autoLogin
    (lib.mkDefault {
      user = userName;
      command = "${lib.getExe config.programs.uwsm.package} start hyprland-uwsm.desktop";
    });

  services.displayManager.regreet = {
    enable = true;

    font = {
      name = fonts.sans.family;
      package = fontPackage fonts.sans;
      size = 14;
    };

    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };

    settings = {
      GTK.application_prefer_dark_theme = true;
      appearance.greeting_msg = "";
      widget.clock.format = "%a %b %-d  %-I:%M %p";
    };

    # Over Adwaita-dark rather than a whole theme: the greeter is a handful of
    # stock widgets, so restyling the stock widget types covers all of it.
    extraCss = ''
      window {
        background-color: ${palette.bg_dim};
        color: ${palette.fg0};
      }

      frame {
        background-color: ${palette.bg0};
        border: 1px solid ${palette.bg3};
        border-radius: ${radius};
      }

      entry, button, dropdown > button, combobox > box > button {
        background-color: ${palette.bg1};
        color: ${palette.fg1};
        border-radius: ${radius};
      }

      button.suggested-action {
        background-color: ${palette.green};
        color: ${palette.bg0};
      }

      button.destructive-action {
        background-color: ${palette.red};
        color: ${palette.bg0};
      }

      .error {
        color: ${palette.red};
      }
    '';
  };
}
