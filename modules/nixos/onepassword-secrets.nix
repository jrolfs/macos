{ config, lib, pkgs, ... }:

# Service secrets rendered from 1Password at boot, so a service's credentials
# live in exactly one place and nothing secret is committed to this public
# repo, not even encrypted. A template in the repo holds `op://` references
# and `op inject` fills them in, authenticated by a service account token that
# bootstrap installs root-only.
#
# The rendered copy is kept on disk rather than in /run, and a failed fetch
# falls back to it. After a power cut with the internet still down, 1Password
# is unreachable at exactly the moment every service starts; without the
# fallback none of them would come up.
#
# Rendering happens at boot and on switch, never on a consumer's restart. A
# Family-plan service account has the tightest rate limits 1Password sets, and
# a crash-looping consumer re-fetching on every attempt would exhaust them.
# A value changed in 1Password therefore reaches a running system with
# `systemctl restart onepassword-render-<name>`, which also restarts the
# services listed as consumers.

let
  inherit (lib) mkOption types;

  cfg = config.onepassword;

  root = "/var/lib/onepassword";
  rendered = "${root}/rendered";

  renderScript = name: template: pkgs.writeShellScript "onepassword-render-${name}" ''
    set -uo pipefail

    destination=${lib.escapeShellArg "${rendered}/${name}"}
    token=${lib.escapeShellArg cfg.tokenFile}

    fallback() {
      if [ -e "$destination" ]; then
        echo "$1; keeping the copy rendered last time" >&2
        exit 0
      fi

      echo "$1, and there is no earlier copy to fall back on" >&2
      exit 1
    }

    [ -r "$token" ] || fallback "no service account token at $token"

    OP_SERVICE_ACCOUNT_TOKEN="$(< "$token")"
    export OP_SERVICE_ACCOUNT_TOKEN

    staging="$(mktemp "$destination.XXXXXX")"
    trap 'rm -f "$staging"' EXIT

    ${lib.getExe cfg.package} inject --force \
      --in-file ${template.template} --out-file "$staging" \
      || fallback "1Password could not render ${name}"

    chown ${template.owner}:${template.group} "$staging"
    chmod ${template.mode} "$staging"
    mv -f "$staging" "$destination"
  '';
in
{
  options.onepassword = {
    package = mkOption {
      type = types.package;
      default = config.programs._1password.package;
      defaultText = lib.literalExpression "config.programs._1password.package";
      description = "The 1Password CLI used to render templates.";
    };

    tokenFile = mkOption {
      type = types.str;
      default = "${root}/service-account-token";
      description = ''
        Root-only file holding the service account token. Placed by
        bootstrap, never by this configuration, since the token is the one
        credential that can't come from 1Password itself.
      '';
    };

    templates = mkOption {
      default = { };
      description = ''
        Files to render from 1Password. Each is available to services at
        `config.onepassword.templates.<name>.path`.
      '';
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          template = mkOption {
            type = types.path;
            description = "Template containing `{{ op://… }}` references.";
          };

          owner = mkOption {
            type = types.str;
            default = "root";
          };

          group = mkOption {
            type = types.str;
            default = "root";
          };

          mode = mkOption {
            type = types.str;
            default = "0400";
          };

          consumers = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              systemd services that read this file. They start after it is
              rendered, refuse to start if it can't be, and restart when it is
              rendered again.
            '';
          };

          path = mkOption {
            type = types.str;
            readOnly = true;
            default = "${rendered}/${name}";
          };
        };
      }));
    };
  };

  config = lib.mkIf (cfg.templates != { }) {
    systemd.tmpfiles.rules = [
      # Traversable but not listable, so a service can open its own rendered
      # file by name without being able to see which others exist.
      "d ${root} 0711 root root - -"
      "d ${rendered} 0711 root root - -"
      # `op` refuses a config directory anyone else can read.
      "d ${root}/config 0700 root root - -"
    ];

    systemd.services = lib.mkMerge (lib.mapAttrsToList
      (name: template: {
        "onepassword-render-${name}" = {
          description = "Render ${name} from 1Password";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" "systemd-tmpfiles-setup.service" ];
          environment.OP_CONFIG_DIR = "${root}/config";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = renderScript name template;
          };
        };
      } // lib.genAttrs template.consumers (_: {
        requires = [ "onepassword-render-${name}.service" ];
        after = [ "onepassword-render-${name}.service" ];
        partOf = [ "onepassword-render-${name}.service" ];
      }))
      cfg.templates);
  };
}
