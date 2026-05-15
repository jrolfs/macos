{ pkgs, lib, ... }:

# Home Assistant native NixOS module. Migrated from a Docker container
# on QNAP. The container's config dir (mounted at /config inside the
# container, sourced from /share/Docker/Containers/home-assistant/config
# on the NAS) rsyncs to /var/lib/hass on Irulan.
#
# Approach for the migration: lift the existing configuration.yaml +
# automations.yaml + scripts.yaml + secrets.yaml as-is. The declarative
# `config` option below is intentionally left empty so HA reads the
# rsync'd YAML files directly. Translation to declarative attrs is a
# future cleanup, not blocking the migration.

{
  services.home-assistant = {
    enable = true;

    # All custom Python packages HA needs for integrations. Lift these
    # from the running container's requirements after migration; for
    # now, start with the common defaults the NixOS module pulls in.
    extraComponents = [
      # Core integrations from the existing setup land here as they
      # surface during testing. Examples:
      # "apple_tv" "hue" "matter" "mqtt" "spotify" "zwave_js"
    ];

    extraPackages = python3Packages: with python3Packages; [
      # Python deps required by custom_components or for direct config.
      # Add as integrations surface.
    ];

    # configDir defaults to /var/lib/hass. Override only if you want a
    # different layout. The rsync target during migration is this path.
    # configDir = "/var/lib/hass";

    # Empty declarative config means HA reads YAML from configDir.
    # Don't set this until you're ready to translate the YAML over.
    # config = { };

    # openFirewall = true requires a declarative `config` block (the
    # module needs to know which ports to open from `http.server_port`).
    # We're file-based for the migration, so open 8123 manually below.
  };

  # HA listens on 8123 by default. Traefik (Komodo-deployed) will proxy
  # https://homeassistant.rolfs.lan to http://irulan:8123 once it's up.
  networking.firewall.allowedTCPPorts = [ 8123 ];
}
