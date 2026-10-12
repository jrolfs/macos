{ pkgs, lib, config, hostname, ... }:

# Komodo, split into its two halves so a host can run either one.
#
# Every machine that Komodo deploys stacks to runs a Periphery, and exactly one
# machine runs Core. Core is on Leia today and stays there until its own
# migration phase (documentation/IRULAN-MIGRATION.md), so a NixOS host normally
# enables only the periphery.
#
# The periphery is nixpkgs' native systemd module rather than the container
# Leia runs. Komodo recommends systemd for it, and a containerised periphery
# has to see stack directories at the same path the host's docker daemon does,
# which is why Leia's is mounted at a mirrored /share/Docker/... path.

let
  cfg = config.komodo;

  coreStateDir = "/var/lib/komodo";
in
{
  options.komodo = {
    core.enable = lib.mkEnableOption ''
      Komodo Core and its MongoDB as containers. Before the first start, the
      environment files under /etc/komodo have to be placed by hand
    '';

    periphery = {
      enable = lib.mkEnableOption "the Komodo Periphery agent, connecting out to Core";

      coreAddress = lib.mkOption {
        type = lib.types.str;
        default = "https://komodo.rolfs.casa";
        description = ''
          Where Core is reachable from this host. The periphery dials out to it
          over a websocket, so nothing on this host listens for Core.
        '';
      };

      connectAs = lib.mkOption {
        type = lib.types.str;
        default = hostname;
        description = "The Server name this host appears as in Komodo.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.periphery.enable {
      # No onboarding key: the periphery generates its own key pair under
      # /var/lib/komodo-periphery/keys on first start, and Core records the
      # public half of an unrecognised connection as the server's attempted
      # key, to be accepted once in the UI. Nothing secret enters this config.
      # With an outbound core address the inbound server is off, so no port
      # is opened either.
      services.komodo-periphery = {
        enable = true;
        outbound = {
          inherit (cfg.periphery) coreAddress connectAs;
        };
      };
    })

    (lib.mkIf cfg.core.enable {
      systemd.tmpfiles.rules = [
        "d ${coreStateDir} 0750 root root - -"
        "d ${coreStateDir}/mongo-data 0750 root root - -"
        "d ${coreStateDir}/mongo-config 0750 root root - -"
        "d ${coreStateDir}/keys 0750 root root - -"
        "d ${coreStateDir}/backups 0750 root root - -"
      ];

      virtualisation.oci-containers = {
        backend = "docker";

        containers.komodo-mongo = {
          image = "mongo:4.4";
          autoStart = true;
          cmd = [ "--quiet" "--wiredTigerCacheSizeGB" "0.25" ];
          volumes = [
            "${coreStateDir}/mongo-data:/data/db"
            "${coreStateDir}/mongo-config:/data/configdb"
          ];
          # TODO(secrets): render from 1Password with onepassword.templates
          # when Core migrates. Until then this file is placed by hand.
          environmentFiles = [ "/etc/komodo/mongo.env" ];
          extraOptions = [ "--network=komodo" ];
        };

        containers.komodo-core = {
          image = "ghcr.io/moghtech/komodo-core:2";
          autoStart = true;
          dependsOn = [ "komodo-mongo" ];
          ports = [ "9120:9120" ];
          volumes = [
            "${coreStateDir}/keys:/config/keys"
            "${coreStateDir}/backups:/backups"
          ];
          environment = {
            KOMODO_DATABASE_ADDRESS = "komodo-mongo:27017";
          };
          environmentFiles = [ "/etc/komodo/core.env" ];
          extraOptions = [ "--network=komodo" "--init" ];
        };
      };

      # virtualisation.oci-containers doesn't manage networks itself.
      systemd.services.komodo-network = {
        description = "Create the komodo docker network";
        wantedBy = [ "multi-user.target" ];
        before = [
          "docker-komodo-mongo.service"
          "docker-komodo-core.service"
        ];
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.docker}/bin/docker network inspect komodo > /dev/null 2>&1 || \
            ${pkgs.docker}/bin/docker network create komodo
        '';
      };

      # Peripheries dial in to Core, and the UI is served from the same port.
      networking.firewall.allowedTCPPorts = [ 9120 ];
    })
  ];
}
